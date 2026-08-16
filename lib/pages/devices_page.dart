import 'dart:async';

import 'package:flutter/material.dart';

import '../bridge/debug_log.dart';
import '../bridge/note_repository.dart';
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
  const DevicesPage({super.key, required this.repository});

  final NoteRepository repository;

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

  @override
  void initState() {
    super.initState();
    _load();
    // 后台状态变化后刷新（不阻塞首次加载；dispose 后不再刷新）
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
      // 后台刷新：不闪 loading、不覆盖错误状态，仅静默更新数据
      try {
        final devices = await _repository.listPairedDevices();
        if (!mounted) return;
        setState(() {
          _devices = devices;
        });
        DebugLogger.instance.event(
          'devices.online_refresh',
          'devices.online_refresh',
          fields: {
            'action': 'background_refresh',
            'online_count':
                '${devices.where((d) => _isOnline(d)).length}',
          },
        );
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

  /// 最后同步相对时间（"3 分钟前"）。
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

  /// 解除配对：确认弹窗 → remove_paired_device → 列表刷新。
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

  /// 添加设备：两步配对流程（第一步选模式，第二步展示码或输入框）。
  Future<void> _startPairing() async {
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
              subtitle: const Text('对方输入我屏幕上的 6 位码'),
              onTap: () => Navigator.of(dialogContext).pop('show'),
            ),
            ListTile(
              key: const ValueKey('pair-mode-enter'),
              leading: const Icon(Icons.keyboard),
              title: const Text('我输入对方的码'),
              subtitle: const Text('输入对方设备显示的 6 位码'),
              onTap: () => Navigator.of(dialogContext).pop('enter'),
            ),
          ],
        ),
      ),
    );
    if (mode == null || !mounted) return;
    if (mode == 'show') {
      await _showMyCode();
    } else {
      await _enterPeerCode();
    }
  }

  /// 确认方：展示本机配对码（等待对方输入确认）。
  ///
  /// 任务 J：显示码的同时启动 mDNS 广播（Rust 组合 API，码与广播同一调用
  /// 内完成——保证配对期间广播一定在）；弹窗关闭（含取消/异常路径）后停止
  /// 广播，避免本机在配对结束后继续被局域网发现。
  ///
  /// 任务 M：显示码的同时进入确认方等待状态——[_PairingAcceptDialog] 在弹窗
  /// 生命周期内调用 [NoteRepository.acceptPairingRequestWithTimeout]（有界等待，
  /// 见决策点 1）启动接收器；收到请求后以显示的码调用 `confirmPairing`；
  /// 成功则关闭弹窗并刷新设备列表，超时/异常显示可读错误并停止广播，
  /// 取消/关闭不留下永久阻塞任务。
  Future<void> _showMyCode() async {
    final log = DebugLogger.instance;
    String code;
    // 事件 #5：显示配对码——开始
    log.event('pairing.show_code', 'pairing.show_code',
        fields: const {'action': 'start'});
    final sw = Stopwatch()..start();
    try {
      code = await _repository.beginPairingAcceptAndAdvertise();
      // 事件 #5：显示配对码 + 广播启动成功（组合 API 返回即广播已在 Rust 侧启动）
      log.event('pairing.show_code', 'pairing.show_code',
          fields: const {'action': 'success', 'broadcast': 'true'},
          duration: sw.elapsed);
      log.event('pairing.advertise', 'pairing.advertise',
          fields: const {'action': 'start'});
    } catch (error) {
      // 事件 #5：显示配对码失败（错误链；不得记录码本身）
      log.event(
        'pairing.show_code',
        'pairing.show_code',
        fields: const {'action': 'failed'},
        error: error.runtimeType.toString(),
        errorChain: error.toString(),
        duration: sw.elapsed,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('生成配对码失败: $error')));
      }
      return;
    }
    try {
      if (!mounted) return;
      final result = await showDialog<PairingResult>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _PairingAcceptDialog(
          code: code,
          repository: _repository,
          acceptTimeout: DevicesPage.pairingAcceptTimeout,
        ),
      );
      // 配对成功：弹窗以结果关闭 → 提示 + 刷新设备列表（对方设备立即可见）
      if (result == null || !mounted) {
        // 事件 #6：显示码弹窗被取消/关闭（未配对）
        log.event('pairing.show_code', 'pairing.show_code',
            fields: const {'action': 'cancelled'});
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('配对成功：${result.peerName}')));
      await _load();
    } finally {
      // 弹窗关闭（含取消/成功/异常路径）→ 停止 mDNS 广播（清理事件 #11）
      try {
        await _repository.stopPairingAdvertising();
        log.event('pairing.advertise', 'pairing.advertise',
            fields: const {'action': 'stop', 'ok': 'true'});
      } catch (error) {
        log.event(
          'pairing.advertise',
          'pairing.advertise',
          fields: const {'action': 'stop', 'ok': 'false'},
          error: error.runtimeType.toString(),
          errorChain: error.toString(),
        );
      }
    }
  }

  /// 发起方：输入对方配对码（及对方设备 ID，可留空自动解析）→ 连接配对。
  ///
  /// 任务 J：设备 ID 留空时先做 mDNS 扫描（约 3 秒），命中一台自动填充
  /// target（device_id + ip:port 直连地址）；无结果/多台歧义时给出友好提示，
  /// 不向用户展示裸 AnyhowException（技术细节留 debugPrint）。
  Future<void> _enterPeerCode() async {
    final codeController = TextEditingController();
    final peerIdController = TextEditingController();
    String? submitError;
    bool discovering = false;
    final result = await showDialog<PairingResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('输入对方配对码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('pair-code-input'),
                controller: codeController,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '6 位配对码',
                  hintText: '如 123456',
                ),
              ),
              const SizedBox(height: CardMindSpacing.md),
              TextField(
                key: const ValueKey('pair-peer-id-input'),
                controller: peerIdController,
                decoration: const InputDecoration(
                  labelText: '对方设备 ID（可选）',
                  hintText: '留空时自动通过局域网发现（mDNS）连接',
                ),
              ),
              if (discovering) ...[
                const SizedBox(height: CardMindSpacing.md),
                Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: CardMindSpacing.sm),
                    Text(
                      '正在搜索局域网设备…',
                      style: TextStyle(
                        color: context.cardMind.mutedInk,
                        fontSize: 13,
                      ),
                    ),
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
              onPressed: () async {
                final code = codeController.text.trim();
                if (code.isEmpty) return;
                setDialogState(() {
                  submitError = null;
                  discovering = false;
                });
                try {
                  final log = DebugLogger.instance;
                  final manualId = peerIdController.text.trim();
                  PairingTarget target;
                  if (manualId.isNotEmpty) {
                    // 手动填写优先：跳过 mDNS 扫描
                    // 事件 #6：手动 ID 路径明确记录跳过 mDNS（脱敏目标 id）
                    log.event(
                      'pairing.discovery',
                      'pairing.discovery',
                      deviceIds: [manualId],
                      fields: const {'action': 'bypassed', 'mdns_skipped': 'true'},
                    );
                    target = PairingTarget(deviceId: manualId, ips: const []);
                  } else {
                    // mDNS 自动发现（设备 ID 留空）
                    // 事件 #4：mDNS 扫描开始
                    log.event('pairing.discovery', 'pairing.discovery',
                        fields: const {'action': 'start', 'mdns': 'true'});
                    setDialogState(() {
                      discovering = true;
                    });
                    final discoverSw = Stopwatch()..start();
                    List<PeerInfo> peers;
                    try {
                      peers = await _repository.discoverPeers();
                      log.event(
                        'pairing.discovery',
                        'pairing.discovery',
                        fields: {'action': 'result', 'count': '${peers.length}'},
                        duration: discoverSw.elapsed,
                      );
                    } catch (error) {
                      // 扫描失败按无结果处理（友好提示）；细节进结构化日志
                      log.event(
                        'pairing.discovery',
                        'pairing.discovery',
                        fields: const {'action': 'failed'},
                        error: error.runtimeType.toString(),
                        errorChain: error.toString(),
                        duration: discoverSw.elapsed,
                      );
                      peers = const [];
                    }
                    if (!dialogContext.mounted) return;
                    setDialogState(() {
                      discovering = false;
                    });
                    if (peers.isEmpty) {
                      setDialogState(() {
                        submitError = '未在局域网发现对方设备。请确认两台设备在同一网络，或手动填写对方设备 ID';
                      });
                      return;
                    }
                    if (peers.length > 1) {
                      // 需决策点 1：多台设备无法区分码的持有者，不静默取第一台
                      setDialogState(() {
                        submitError =
                            '在局域网发现多台 CardMind 设备，无法自动确定配对对象。请手动填写对方设备 ID';
                      });
                      return;
                    }
                    final peer = peers.single;
                    target = PairingTarget(
                      deviceId: peer.deviceId,
                      ips: peer.ip.isEmpty
                          ? const []
                          : ['${peer.ip}:${peer.port}'],
                    );
                  }
                  // 事件 #7：连接阶段开始（transport：direct vs relay_or_dns）
                  final connectSw = Stopwatch()..start();
                  log.event(
                    'pairing.connect',
                    'pairing.connect',
                    deviceIds: [target.deviceId],
                    fields: {
                      'action': 'start',
                      'transport': target.ips.isEmpty ? 'relay_or_dns' : 'direct',
                    },
                  );
                  try {
                    final res = await _repository.beginPairingConnect(
                      code,
                      target,
                    );
                    log.event(
                      'pairing.connect',
                      'pairing.connect',
                      deviceIds: [target.deviceId],
                      fields: {
                        'action': 'success',
                        'transport': target.ips.isEmpty ? 'relay_or_dns' : 'direct',
                        'peer_name': res.peerName,
                      },
                      duration: connectSw.elapsed,
                    );
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(res);
                    }
                  } catch (error) {
                    // 错误脱敏（任务 J）：不展示裸 AnyhowException，细节进结构化日志
                    log.event(
                      'pairing.connect',
                      'pairing.connect',
                      deviceIds: [target.deviceId],
                      fields: {
                        'action': 'failed',
                        'transport': target.ips.isEmpty ? 'relay_or_dns' : 'direct',
                      },
                      error: error.runtimeType.toString(),
                      errorChain: error.toString(),
                      duration: connectSw.elapsed,
                    );
                    setDialogState(() {
                      discovering = false;
                      submitError = '配对失败：无法连接到对方设备。请确认两台设备在同一网络后重试';
                    });
                  }
                } catch (error) {
                  // 外层兜底（target 构造等异常）：不展示裸异常，细节进结构化日志
                  DebugLogger.instance.event(
                    'pairing.connect',
                    'pairing.connect',
                    fields: const {'action': 'failed'},
                    error: error.runtimeType.toString(),
                    errorChain: error.toString(),
                  );
                  setDialogState(() {
                    discovering = false;
                    submitError = '配对失败：无法连接到对方设备。请确认两台设备在同一网络后重试';
                  });
                }
              },
              child: Text(discovering ? '正在搜索…' : '确认配对'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('配对成功：${result.peerName}')));
    await _load();
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

/// 显示码等待弹窗（任务 M）：在弹窗生命周期内运行确认方接收器。
///
/// 生命周期契约：
/// - 打开：调用 [NoteRepository.acceptPairingRequestWithTimeout]（**有界**等待，
///   超时返回 null——决策点 1 的落点，FRB opaque 上的阻塞等待必须有限界）
/// - 收到请求：以显示的码调用 `confirmPairing(code, requester)`；成功 pop 结果
///   关闭弹窗（页面随后刷新设备列表）
/// - 超时/异常：停止广播（设计目标 5）并显示可读错误，等待用户关闭后重试
/// - 取消/关闭：dispose 置 [_cancelled]；挂起的等待完成后不再 confirm，
///   也不向已卸载 widget 调 setState（mounted 守卫）
class _PairingAcceptDialog extends StatefulWidget {
  const _PairingAcceptDialog({
    required this.code,
    required this.repository,
    required this.acceptTimeout,
  });

  final String code;
  final NoteRepository repository;
  final Duration acceptTimeout;

  @override
  State<_PairingAcceptDialog> createState() => _PairingAcceptDialogState();
}

class _PairingAcceptDialogState extends State<_PairingAcceptDialog> {
  String? _error;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _runAccept();
  }

  @override
  void dispose() {
    // 取消/关闭：标记后，挂起的等待完成时不再 confirm / setState
    _cancelled = true;
    super.dispose();
  }

  /// 停止 mDNS 广播（超时/异常路径立即停止；幂等——页面 finally 兜底再停一次）。
  Future<void> _stopAdvertisingQuietly() async {
    try {
      await widget.repository.stopPairingAdvertising();
      // 清理事件 #11：停止广播成功
      DebugLogger.instance.event('pairing.advertise', 'pairing.advertise',
          fields: const {'action': 'stop', 'ok': 'true'});
    } catch (error) {
      // 清理事件 #11：停止广播异常
      DebugLogger.instance.event(
        'pairing.advertise',
        'pairing.advertise',
        fields: const {'action': 'stop', 'ok': 'false'},
        error: error.runtimeType.toString(),
        errorChain: error.toString(),
      );
    }
  }

  /// 确认方等待 + 确认流程。每个 await 之后都有 mounted/_cancelled 守卫：
  /// 不向已卸载 widget 调 setState，取消后不 confirm。
  Future<void> _runAccept() async {
    final log = DebugLogger.instance;
    // 事件 #5：确认方 accept loop 启动
    log.event('pairing.accept', 'pairing.accept',
        fields: {'action': 'start', 'timeout_ms': '${widget.acceptTimeout.inMilliseconds}'});
    PairingRequest? request;
    try {
      request = await widget.repository.acceptPairingRequestWithTimeout(
        widget.acceptTimeout,
      );
    } catch (error) {
      // 事件 #6：accept 失败（错误链）
      log.event(
        'pairing.accept',
        'pairing.accept',
        fields: const {'action': 'failed'},
        error: error.runtimeType.toString(),
        errorChain: error.toString(),
      );
      await _stopAdvertisingQuietly();
      if (!mounted || _cancelled) return;
      setState(() {

        _error = '等待配对请求失败，请关闭后重试';
      });
      return;
    }
    if (!mounted || _cancelled) return;
    if (request == null) {
      // 事件 #6：accept 超时（有界等待到点）
      log.event('pairing.accept', 'pairing.accept',
          fields: const {'action': 'timeout'});
      // 有界等待超时：结束等待 + 停止广播（设计目标 5）
      await _stopAdvertisingQuietly();
      if (!mounted || _cancelled) return;
      setState(() {

        _error = '等待配对超时，请关闭后重新发起';
      });
      return;
    }
    // 事件 #8：请求接收（脱敏对端 id）
    log.event('pairing.request', 'pairing.request',
        deviceIds: [request.deviceId],
        fields: {'action': 'received', 'peer_name': request.deviceName});
    try {
      // 事件 #8：confirm 开始
      log.event('pairing.confirm', 'pairing.confirm',
          deviceIds: [request.deviceId],
          fields: const {'action': 'start'});
      final confirmSw = Stopwatch()..start();
      final result = await widget.repository.confirmPairing(
        widget.code,
        request,
      );
      // 事件 #8：confirm 成功
      log.event('pairing.confirm', 'pairing.confirm',
          deviceIds: [result.peerId],
          fields: {'action': 'success', 'peer_name': result.peerName},
          duration: confirmSw.elapsed);
      if (!mounted || _cancelled) return;
      // 配对成功：以结果关闭弹窗（页面显示成功提示 + 刷新设备列表）
      Navigator.of(context).pop(result);
    } catch (error) {
      // 事件 #8：confirm 失败（错误链 + 耗时）
      log.event(
        'pairing.confirm',
        'pairing.confirm',
        deviceIds: [request.deviceId],
        fields: const {'action': 'failed'},
        error: error.runtimeType.toString(),
        errorChain: error.toString(),
      );
      await _stopAdvertisingQuietly();
      if (!mounted || _cancelled) return;
      setState(() {

        _error = '配对失败，请关闭后重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('等待对方输入此码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('在对方设备"添加设备"中输入以下 6 位码：'),
          const SizedBox(height: CardMindSpacing.lg),
          Text(
            widget.code,
            key: const ValueKey('pair-code-display'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: context.cardMind.accent,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: CardMindSpacing.lg),
          if (_error != null)
            Text(
              _error!,
              key: const ValueKey('pair-accept-error'),
              style: TextStyle(color: context.cardMind.danger, fontSize: 13),
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
