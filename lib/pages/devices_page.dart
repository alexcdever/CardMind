import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../bridge/debug_log.dart';
import '../bridge/note_repository.dart';
import '../bridge/pairing_credential_exception.dart';
import '../scanner/scanner_interface.dart';
import '../src/rust/discovery.dart';
import '../src/rust/store.dart';
import '../src/rust/sync.dart';
import '../ui/design_system/cardmind_theme.dart';
import '../ui/design_system/cardmind_widgets.dart';

/// 设备页（决策 13，两端共用组件）：
///
/// - 本机信息：设备名 + device_id 短显示（前 8 字符）
/// - "添加设备"：两步配对流程（我显示码 / 我输入对方的码）
/// - 已配对设备列表：名称 + 在线/离线状态 + 最后同步时间 + 解除配对
/// - 空状态引导
///
/// 在线/离线判定（决策 13 三要素）：`last_seen` 在最近 5 分钟内 → 在线；
/// 否则离线。`last_seen` 由 Rust 侧每次成功 push（含周期同步）更新，
/// 离线设备不会刷新 → 超过窗口即判离线。
class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key, required this.repository, this.scanner});

  final NoteRepository repository;
  final ScannerService? scanner;

  /// 在线判定窗口（最近同步过 = 在线）。
  static const Duration onlineWindow = Duration(minutes: 5);

  /// 确认方等待配对请求的总时限（任务 M）：显示码弹窗打开后，接收器
  /// [NoteRepository.acceptPairingRequestWithTimeout] 只等这么长；超时结束等待、
  /// 停止广播并显示可读错误。与配对码 10 分钟有效期对齐的保守上限。
  static const Duration pairingAcceptTimeout = Duration(minutes: 3);

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  List<PairedDeviceRow> _devices = [];
  bool _loading = true;
  String? _error;
  String _deviceName = '';
  String _deviceId = '';

  /// 后台状态刷新 Timer（任务 O 验收 15）：页面保持打开时周期性重读
  /// paired_devices，后台 last_seen 更新后 ≤5 秒内离线→在线；dispose 取消。
  Timer? _refreshTimer;

  NoteRepository get _repository => widget.repository;

  /// 后台刷新间隔（验收 15：≤5 秒内反映后台在线状态变化）。
  static const Duration _refreshInterval = Duration(seconds: 2);

  /// 6 位数字配对码（旧 6 位码路径）。凭证路径以 `cm1.` 开头。
  static final RegExp _sixDigitCode = RegExp(r'^\d{6}$');

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!mounted) return;
      _load(background: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    super.dispose();
  }

  Future<void> _load({bool background = false}) async {
    if (background) {
      try {
        final devices = await _repository.listPairedDevices();
        if (!mounted) return;
        setState(() {
          _devices = devices;
        });
      } catch (_) {
        // 后台刷新失败静默（下次周期重试）
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final devices = await _repository.listPairedDevices();
      final name = await _repository.deviceName();
      final id = await _repository.deviceId();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _deviceName = name;
        _deviceId = id;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '加载设备失败: $error';
      });
    }
  }

  static bool _isOnline(PairedDeviceRow device) {
    final lastSeen = device.lastSeen;
    if (lastSeen == null) return false;
    final time = DateTime.tryParse(lastSeen);
    if (time == null) return false;
    return DateTime.now().difference(time) <= DevicesPage.onlineWindow;
  }

  static String _relativeTime(String? lastSeen) {
    if (lastSeen == null) return '从未同步';
    final time = DateTime.tryParse(lastSeen);
    if (time == null) return '未知';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }

  Future<void> _confirmUnpair(PairedDeviceRow device) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('解除配对'),
        content: Text('解除后不再同步，已有笔记保留。确定解除与「${device.name}」的配对？'),
        actions: [
          TextButton(
            key: const ValueKey('unpair-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const ValueKey('unpair-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('解除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repository.removePairedDevice(device.peerId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('解除配对失败: $error')));
      }
      return;
    }
    if (!mounted) return;
    await _load();
  }

  Future<void> _startPairing() async {
    final scanner = widget.scanner ?? createPlatformScanner();
    final mode = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加设备'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('选择配对方式：'),
            const SizedBox(height: CardMindSpacing.md),
            ListTile(
              key: const ValueKey('pair-mode-show'),
              leading: const Icon(Icons.qr_code_2),
              title: const Text('我显示配对码'),
              subtitle: const Text('对方扫描我屏幕上的二维码'),
              onTap: () => Navigator.of(dialogContext).pop('show'),
            ),
            if (scanner.isSupported)
              ListTile(
                key: const ValueKey('pair-mode-scan'),
                leading: const Icon(Icons.qr_code_scanner),
                title: const Text('我扫描配对码'),
                subtitle: const Text('使用相机扫描对方设备二维码'),
                onTap: () => Navigator.of(dialogContext).pop('scan'),
              ),
            ListTile(
              key: const ValueKey('pair-mode-enter'),
              leading: const Icon(Icons.keyboard),
              title: const Text('我输入对方的码'),
              subtitle: const Text('输入或粘贴对方设备的配对信息'),
              onTap: () => Navigator.of(dialogContext).pop('enter'),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('pair-dialog-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (mode == null || !mounted) return;
    if (mode == 'show') {
      await _showMyCode();
    } else if (mode == 'scan') {
      await _scanPeerCredential(scanner);
    } else {
      await _enterPeerCode();
    }
  }

  Future<void> _scanPeerCredential(ScannerService scanner) async {
    ScanOutcome outcome;
    try {
      outcome = await scanner.scanCredential(context);
    } catch (_) {
      outcome = const ScanOutcome(error: '扫码失败，请检查相机权限后重试，或手动输入配对信息');
    }
    if (!mounted || outcome.cancelled) return;
    if (outcome.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(outcome.error!)));
      return;
    }
    final input = outcome.text?.trim() ?? '';
    if (!input.startsWith('cm1')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('扫码内容不是有效的配对信息，请重新扫描')));
      return;
    }
    try {
      final result = await _repository.beginPairingConnectWithCredential(input);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('配对成功：${result.peerName}')));
      await _load();
      } on PairingCredentialException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('配对失败：无法连接到对方设备，请稍后重试')));
        }
    }
  }

  /// 确认方：展示本机配对凭证（二维码 + 复制按钮 + 倒计时）。
  ///
  /// 任务 Q：显示凭证的同时启动 mDNS 广播（Rust 组合 API 生成凭证 + 广播
  /// 同一调用——保证配对期间广播一定在）。弹窗关闭（含取消/异常路径）后
  /// 停止广播。
  Future<void> _showMyCode() async {
    DebugLogger.instance.event(
      'pairing.show_code',
      'pairing.show_code',
      fields: const {'action': 'start'},
    );
    try {
      DebugLogger.instance.event(
        'pairing.advertise',
        'pairing.advertise',
        fields: const {'action': 'start'},
      );
      if (!mounted) return;
      final result = await showDialog<PairingResult>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _PairingAcceptDialog(
          repository: _repository,
          acceptTimeout: DevicesPage.pairingAcceptTimeout,
        ),
      );
      if (result == null || !mounted) {
        DebugLogger.instance.event(
          'pairing.show_code',
          'pairing.show_code',
          fields: const {'action': 'cancelled'},
        );
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('配对成功：${result.peerName}')));
      await _load();
      DebugLogger.instance.event(
        'pairing.show_code',
        'pairing.show_code',
        fields: const {'action': 'success'},
      );
    } finally {
      try {
        await _repository.stopPairingAdvertising();
        DebugLogger.instance.event(
          'pairing.advertise',
          'pairing.advertise',
          fields: const {'action': 'stop', 'ok': 'true'},
        );
      } catch (_) {
        DebugLogger.instance.event(
          'pairing.advertise',
          'pairing.advertise',
          fields: const {'action': 'stop', 'ok': 'false'},
        );
        // 幂等停广播失败忽略（弹窗已关）
      }
    }
  }

  /// 发起方：单一输入框（配对码或配对信息）→ 连接配对。
  ///
  /// 任务 Q：
  /// - 以 `cm1...` 开头 → 凭证垂直入口 [NoteRepository.beginPairingConnectWithCredential]
  ///   （禁止 mDNS 扫描）
  /// - 纯 6 位数字 → 旧 6 位码路径，mDNS 发现 + 直连
  /// - 其余 → 格式错误友好提示
  ///
  /// 凭证错误映射为 [PairingCredentialException] 的友好文案，不展示裸异常。
  Future<void> _enterPeerCode() async {
    final controller = TextEditingController();
    String? submitError;
    bool submitting = false;

    final result = await showDialog<PairingResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> submit(String raw) async {
            final input = raw.trim();
            if (input.isEmpty) return;
            setDialogState(() {
              submitError = null;
              submitting = true;
            });
            try {
              final PairingResult res;
              if (input.startsWith('cm1')) {
                DebugLogger.instance.event(
                  'pairing.discovery',
                  'pairing.discovery',
                  fields: const {'action': 'bypassed', 'mdns_skipped': 'true'},
                );
                final started = DateTime.now();
                DebugLogger.instance.event(
                  'pairing.connect',
                  'pairing.connect',
                  fields: const {'action': 'start', 'transport': 'credential'},
                );
                res = await _repository.beginPairingConnectWithCredential(
                  input,
                );
                DebugLogger.instance.event(
                  'pairing.connect',
                  'pairing.connect',
                  fields: const {
                    'action': 'success',
                    'transport': 'credential',
                  },
                  duration: DateTime.now().difference(started),
                );
              } else if (_sixDigitCode.hasMatch(input)) {
                res = await _connectWithSixDigitCode(input);
              } else {
                setDialogState(() {
                  submitError = '请输入 6 位配对码，或粘贴完整的配对信息（以 cm1 开头）';
                });
                return;
              }
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(res);
              }
            } on PairingCredentialException catch (e) {
              setDialogState(() {
                submitError = e.message;
              });
            } catch (e) {
              if (input.startsWith('cm1')) {
                DebugLogger.instance.event(
                  'pairing.connect',
                  'pairing.connect',
                  fields: const {'action': 'failed', 'transport': 'credential'},
                  error: e.runtimeType.toString(),
                  errorChain: e.toString(),
                );
              }
              DebugLogger.instance.event(
                'pairing.connect',
                'pairing.connect',
                fields: const {'action': 'failed'},
                error: e.runtimeType.toString(),
                errorChain: e.toString(),
              );
              setDialogState(() {
                submitError = '配对失败：无法连接到对方设备，请稍后重试';
              });
            } finally {
              setDialogState(() {
                submitting = false;
              });
            }
          }

          return AlertDialog(
            title: const Text('输入对方配对信息'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const ValueKey('pair-credential-input'),
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '配对码或配对信息',
                    hintText: '输入 6 位配对码，或粘贴以 cm1 开头的配对信息',
                  ),
                ),
                if (submitting) ...[
                  const SizedBox(height: CardMindSpacing.md),
                  const Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('正在连接…'),
                    ],
                  ),
                ],
                if (submitError != null) ...[
                  const SizedBox(height: CardMindSpacing.md),
                  Text(
                    submitError!,
                    key: const ValueKey('pair-submit-error'),
                    style: TextStyle(
                      color: context.cardMind.danger,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                key: const ValueKey('pair-cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                key: const ValueKey('pair-submit'),
                onPressed: submitting ? null : () => submit(controller.text),
                child: const Text('确认配对'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('配对成功：${result.peerName}')));
    await _load();
  }

  /// 6 位数字码：mDNS 发现唯一目标 → 直连。多台/无结果给友好提示。
  Future<PairingResult> _connectWithSixDigitCode(String code) async {
    final log = DebugLogger.instance;
    log.event(
      'pairing.discovery',
      'pairing.discovery',
      fields: const {'action': 'start'},
    );
    final started = DateTime.now();
    List<PeerInfo> peers;
    try {
      peers = await _repository.discoverPeers();
    } catch (e) {
      log.event(
        'pairing.discovery',
        'pairing.discovery',
        fields: const {'action': 'failed'},
        error: e.runtimeType.toString(),
        errorChain: e.toString(),
      );
      peers = const [];
    }
    if (peers.isEmpty) {
      log.event(
        'pairing.discovery',
        'pairing.discovery',
        fields: const {'action': 'result', 'count': '0'},
        duration: DateTime.now().difference(started),
      );
      throw const PairingCredentialException(
        kind: PairingCredentialErrorKind.unreachable,
        message: '未在局域网发现对方设备，请确认两台设备在同一网络',
      );
    }
    if (peers.length > 1) {
      log.event(
        'pairing.discovery',
        'pairing.discovery',
        fields: {'action': 'result', 'count': '${peers.length}'},
        duration: DateTime.now().difference(started),
      );
      throw const PairingCredentialException(
        kind: PairingCredentialErrorKind.unreachable,
        message: '在局域网发现多台 CardMind 设备，无法自动确定配对对象',
      );
    }
    final peer = peers.single;
    log.event(
      'pairing.discovery',
      'pairing.discovery',
      fields: {'action': 'result', 'count': '${peers.length}'},
      duration: DateTime.now().difference(started),
    );
    final target = PairingTarget(
      deviceId: peer.deviceId,
      ips: peer.ip.isEmpty ? const [] : ['${peer.ip}:${peer.port}'],
      nonce: peer.nonce,
    );
    final transport = target.ips.isEmpty ? 'relay_or_dns' : 'direct';
    final connectStarted = DateTime.now();
    log.event(
      'pairing.connect',
      'pairing.connect',
      fields: {'action': 'start', 'transport': transport},
    );
    try {
      final result = await _repository.beginPairingConnect(code, target);
      log.event(
        'pairing.connect',
        'pairing.connect',
        fields: {'action': 'success', 'transport': transport},
        duration: DateTime.now().difference(connectStarted),
      );
      return result;
    } catch (e) {
      log.event(
        'pairing.connect',
        'pairing.connect',
        fields: {'action': 'failed', 'transport': transport},
        error: e.runtimeType.toString(),
        errorChain: e.toString(),
        duration: DateTime.now().difference(connectStarted),
      );
      rethrow;
    }
  }

  Widget _buildDeviceList() {
    if (_devices.isEmpty) {
      return const CardMindEmptyState(
        icon: Icons.devices_outlined,
        title: '还没有配对设备',
        message: '点击"添加设备"，在另一台设备上显示配对码并互相确认，即可开始同步。',
      );
    }
    return ListView(
      children: [for (final device in _devices) _buildDeviceItem(device)],
    );
  }

  Widget _buildDeviceItem(PairedDeviceRow device) {
    final tokens = context.cardMind;
    final online = _isOnline(device);
    final relative = _relativeTime(device.lastSeen);
    return Container(
      key: ValueKey('device-${device.peerId}'),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.devices_other_outlined,
            size: 20,
            color: online ? tokens.accent : tokens.mutedInk,
          ),
          const SizedBox(width: CardMindSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: CardMindSpacing.xs),
                Text(
                  online ? '在线' : '离线 · $relative',
                  style: TextStyle(
                    color: online ? tokens.accent : tokens.mutedInk,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            key: ValueKey('unpair-${device.peerId}'),
            onPressed: () => _confirmUnpair(device),
            child: const Text('解除配对'),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalInfo() {
    final tokens = context.cardMind;
    final shortId = _deviceId.length <= 8
        ? _deviceId
        : '${_deviceId.substring(0, 8)}…';
    return Container(
      padding: const EdgeInsets.all(CardMindSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.surfaceLow,
        borderRadius: BorderRadius.circular(CardMindRadii.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tokens.accent,
              borderRadius: BorderRadius.circular(CardMindRadii.md),
            ),
            child: const Icon(
              Icons.desktop_windows_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: CardMindSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _deviceName.isEmpty ? '我的设备' : _deviceName,
                  key: const ValueKey('device-local-name'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: CardMindSpacing.xs),
                Text(
                  shortId,
                  key: const ValueKey('device-local-id'),
                  style: TextStyle(color: tokens.mutedInk, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return CardMindEmptyState(
        icon: Icons.error_outline,
        title: '设备页加载失败',
        message: _error!,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLocalInfo(),
              const SizedBox(height: CardMindSpacing.md),
              CardMindPrimaryButton(
                key: const ValueKey('devices-add'),
                label: '添加设备',
                icon: Icons.add,
                expanded: true,
                onPressed: _startPairing,
              ),
            ],
          ),
        ),
        Expanded(child: _buildDeviceList()),
      ],
    );
  }
}

/// 显示码等待弹窗（任务 M/Q）：生成凭证 + 启动有界 accept loop。
///
/// 生命周期契约：
/// - 打开：只生成一次 [NoteRepository.beginPairingCredential]（组合生成 + 广播），
///   成功后 set 显示数据并启动**单个**有界 accept loop
/// - 重新生成：轮次 token 递增 → 旧 loop 判废退出 → 生成新凭证 → 新 loop
/// - confirm 只用与当前显示 code 对应的请求
/// - 关闭：dispose 取消计时器 + 置 [_cancelled]；挂起等待完成后不再 confirm/setState
class _PairingAcceptDialog extends StatefulWidget {
  const _PairingAcceptDialog({
    required this.repository,
    required this.acceptTimeout,
  });

  final NoteRepository repository;
  final Duration acceptTimeout;

  @override
  State<_PairingAcceptDialog> createState() => _PairingAcceptDialogState();
}

class _PairingAcceptDialogState extends State<_PairingAcceptDialog> {
  String? _error;
  bool _cancelled = false;
  String? _credentialText;
  String? _expiresAt;
  String? _displayCode;

  /// 当前 generation 轮次 token；重新生成时递增，使旧 accept loop 判废。
  int _generation = 0;
  Future<void>? _acceptFuture;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  Future<void> _start() async {
    if (_generation != 0) return; // 只启动一次
    await _generateAndAccept();
  }

  Future<void> _generateAndAccept() async {
    final gen = ++_generation;
    try {
      final display = await widget.repository.beginPairingCredential();
      if (!mounted || _cancelled || gen != _generation) return;
      setState(() {
        _displayCode = display.code;
        _credentialText = display.credential;
        _expiresAt = display.expiresAt;
        _error = null;
      });
    } catch (e) {
      if (!mounted || _cancelled || gen != _generation) return;
      setState(() {
        _error = '生成配对信息失败，请关闭后重试';
      });
      return;
    }
    // 凭证就绪后启动有界 accept（同一时刻至多一个；旧 loop 由 token 判废）。
    _acceptFuture = _runAccept(gen);
    await _acceptFuture;
  }

  Future<void> _regenerate() async {
    // 旧轮次 token 递增 → 旧 accept loop 判废后自行退出；等待其结束再启动新轮次，
    // 避免同时运行两个 accept loop。
    _generation++;
    final old = _acceptFuture;
    if (old != null) {
      try {
        await old;
      } catch (_) {}
    }
    if (!mounted || _cancelled) return;
    await _generateAndAccept();
  }

  Future<void> _runAccept(int gen) async {
    final log = DebugLogger.instance;
    log.event(
      'pairing.accept',
      'pairing.accept',
      fields: {
        'action': 'start',
        'timeout_ms': '${widget.acceptTimeout.inMilliseconds}',
      },
    );

    PairingRequest? request;
    try {
      request = await widget.repository.acceptPairingRequestWithTimeout(
        widget.acceptTimeout,
      );
    } catch (e) {
      log.event(
        'pairing.accept',
        'pairing.accept',
        fields: const {'action': 'failed'},
        error: e.runtimeType.toString(),
        errorChain: e.toString(),
      );
      if (gen != _generation) return;
      await _stopAdvertisingQuietly();
      if (!mounted || _cancelled) return;
      setState(() {
        _error = '等待配对请求失败，请关闭后重试';
      });
      return;
    }

    // 轮次已失效（重新生成）或弹窗已关闭 → 不 confirm。
    if (gen != _generation || !mounted || _cancelled) return;

    if (request == null) {
      log.event(
        'pairing.accept',
        'pairing.accept',
        fields: const {'action': 'timeout'},
      );
      if (gen != _generation) return;
      await _stopAdvertisingQuietly();
      if (!mounted || _cancelled) return;
      setState(() {
        _error = '等待配对超时，请关闭后重新发起';
      });
      return;
    }

    log.event(
      'pairing.request',
      'pairing.request',
      fields: const {'action': 'received'},
    );

    // confirm 只用当前 display code；请求 code 必须与之一致（Rust 校验）。
    final code = _displayCode;
    if (code == null) return;
    try {
      log.event(
        'pairing.confirm',
        'pairing.confirm',
        fields: const {'action': 'start'},
      );
      final result = await widget.repository.confirmPairing(code, request);
      log.event(
        'pairing.confirm',
        'pairing.confirm',
        fields: const {'action': 'success'},
      );
      if (gen != _generation || !mounted || _cancelled) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      log.event(
        'pairing.confirm',
        'pairing.confirm',
        deviceIds: [request.deviceId],
        fields: const {'action': 'failed'},
        error: e.runtimeType.toString(),
        errorChain: e.toString(),
      );
      if (gen != _generation) return;
      await _stopAdvertisingQuietly();
      if (!mounted || _cancelled) return;
      setState(() {
        _error = '配对失败，请关闭后重试';
      });
    }
  }

  Future<void> _stopAdvertisingQuietly() async {
    try {
      await widget.repository.stopPairingAdvertising();
    } catch (_) {
      // 幂等停广播失败忽略
    }
  }

  @override
  Widget build(BuildContext context) {
    final codeDisplay = _displayCode ?? '';
    return AlertDialog(
      title: const Text('配对信息'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (codeDisplay.isNotEmpty) ...[
              const Text('在对方设备"添加设备"中输入以下 6 位码：'),
              const SizedBox(height: CardMindSpacing.lg),
              Text(
                codeDisplay,
                key: const ValueKey('pair-code-display'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: context.cardMind.accent,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: CardMindSpacing.md),
              const Divider(),
            ],
            const SizedBox(height: CardMindSpacing.md),
            const Text('扫描此二维码'),
            const SizedBox(height: CardMindSpacing.sm),
            if (_credentialText != null) ...[
              SizedBox(
                width: 200,
                height: 200,
                child: CustomPaint(
                  key: const ValueKey('pair-qr-image'),
                  painter: QrPainter(
                    data: _credentialText!,
                    version: QrVersions.auto,
                    gapless: false,
                  ),
                ),
              ),
              const SizedBox(height: CardMindSpacing.md),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: CardMindSpacing.sm,
                runSpacing: CardMindSpacing.xs,
                children: [
                  TextButton.icon(
                    key: const ValueKey('pair-copy-button'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _credentialText!));
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('已复制配对信息')));
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('复制配对信息'),
                  ),
                  TextButton.icon(
                    key: const ValueKey('pair-regenerate-button'),
                    onPressed: _regenerate,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('重新生成'),
                  ),
                ],
              ),
              const SizedBox(height: CardMindSpacing.sm),
              if (_expiresAt != null) _CountdownWidget(expiresAt: _expiresAt!),
            ] else if (_error == null) ...[
              const Text(
                '正在生成配对信息…',
                style: TextStyle(color: Color(0xFF6B6B6B), fontSize: 13),
              ),
            ],
            const SizedBox(height: CardMindSpacing.lg),
            if (_error != null)
              Text(
                _error!,
                key: const ValueKey('pair-accept-error'),
                style: TextStyle(color: context.cardMind.danger, fontSize: 13),
              )
            else if (_credentialText == null)
              const Text(
                '正在生成配对信息…',
                style: TextStyle(color: Color(0xFF6B6B6B), fontSize: 13),
              )
            else
              Text(
                '等待对方确认后自动完成配对…',
                style: TextStyle(
                  color: context.cardMind.mutedInk,
                  fontSize: 13,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('pair-dialog-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class _CountdownWidget extends StatefulWidget {
  const _CountdownWidget({required this.expiresAt});

  final String expiresAt;

  @override
  State<_CountdownWidget> createState() => _CountdownWidgetState();
}

class _CountdownWidgetState extends State<_CountdownWidget> {
  Duration? _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant _CountdownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    final expires = DateTime.tryParse(widget.expiresAt);
    if (expires == null) {
      setState(() => _remaining = null);
      return;
    }
    void tick(Timer _) {
      if (!mounted) return;
      final remaining = expires.difference(clock.now());
      setState(
        () => _remaining = remaining.isNegative ? Duration.zero : remaining,
      );
    }

    final remaining = expires.difference(clock.now());
    _remaining = remaining.isNegative ? Duration.zero : remaining;
    // Repaint more often than once per second while deriving every display
    // value from the absolute expiry. This avoids truncation hiding a
    // boundary tick in widget tests and keeps the countdown wall-clock exact.
    _timer = Timer.periodic(const Duration(milliseconds: 100), tick);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == null) return const SizedBox.shrink();
    final minutes = _remaining!.inMinutes;
    final seconds = _remaining!.inSeconds % 60;
    final text = _remaining!.inSeconds <= 0
        ? '已过期，请重新生成'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    return Text(
      text,
      key: const ValueKey('pair-code-countdown'),
      style: TextStyle(
        fontSize: 14,
        color: _remaining!.inSeconds <= 0
            ? context.cardMind.danger
            : context.cardMind.mutedInk,
      ),
    );
  }
}
