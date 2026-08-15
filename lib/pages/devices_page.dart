import 'package:flutter/material.dart';

import '../bridge/note_repository.dart';
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

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  List<PairedDeviceRow> _devices = [];
  bool _loading = true;
  String? _error;
  String _deviceName = '';
  String _deviceId = '';

  NoteRepository get _repository => widget.repository;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
  Future<void> _showMyCode() async {
    String code;
    try {
      code = await _repository.beginPairingAccept();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('生成配对码失败: $error')));
      }
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('等待对方输入此码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('在对方设备"添加设备"中输入以下 6 位码：'),
            const SizedBox(height: CardMindSpacing.lg),
            Text(
              code,
              key: const ValueKey('pair-code-display'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: context.cardMind.accent,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: CardMindSpacing.lg),
            Text(
              '等待对方确认后自动完成配对…',
              style: TextStyle(color: context.cardMind.mutedInk, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('pair-dialog-close'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 发起方：输入对方配对码（及对方设备 ID，可留空自动解析）→ 连接配对。
  Future<void> _enterPeerCode() async {
    final codeController = TextEditingController();
    final peerIdController = TextEditingController();
    String? submitError;
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
                  hintText: '留空时自动通过地址解析连接',
                ),
              ),
              if (submitError != null) ...[
                const SizedBox(height: CardMindSpacing.md),
                Text(
                  submitError!,
                  style: TextStyle(color: context.cardMind.danger, fontSize: 13),
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
                try {
                  final target = PairingTarget(
                    deviceId: peerIdController.text.trim(),
                    ips: const [],
                  );
                  final res = await _repository.beginPairingConnect(
                    code,
                    target,
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(res);
                  }
                } catch (error) {
                  setDialogState(() {
                    submitError = '配对失败: $error';
                  });
                }
              },
              child: const Text('确认配对'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('配对成功：${result.peerName}')),
    );
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
      children: [
        for (final device in _devices) _buildDeviceItem(device),
      ],
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
