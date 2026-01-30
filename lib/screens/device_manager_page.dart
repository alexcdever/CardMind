import 'package:cardmind/adaptive/platform_detector.dart';
import 'package:cardmind/models/device.dart';
import 'package:cardmind/widgets/current_device_card.dart';
import 'package:cardmind/widgets/device_list_item.dart';
import 'package:cardmind/widgets/pair_device_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 设备名称修改回调
typedef OnDeviceNameChange = void Function(String newName);

/// 配对设备回调
typedef OnPairDevice =
    Future<bool> Function(String deviceId, String verificationCode);

/// 移除设备回调
typedef OnRemoveDevice = Future<void> Function(String peerId);

/// 桌面端设备管理页面
///
/// 专为桌面端设计的设备管理界面，充分利用大屏幕空间。
class DeviceManagerPage extends StatefulWidget {
  const DeviceManagerPage({
    super.key,
    required this.hasJoinedPool,
    required this.currentDevice,
    required this.pairedDevices,
    required this.poolId,
    required this.onDeviceNameChange,
    required this.onPairDevice,
    required this.onRemoveDevice,
  });

  /// 是否已加入数据池
  final bool hasJoinedPool;

  /// 当前设备信息
  final Device currentDevice;

  /// 已配对设备列表
  final List<Device> pairedDevices;

  /// 数据池 ID
  final String poolId;

  /// 编辑设备名称回调
  final OnDeviceNameChange onDeviceNameChange;

  /// 配对新设备回调
  final OnPairDevice onPairDevice;

  /// 移除设备回调
  final OnRemoveDevice onRemoveDevice;

  @override
  State<DeviceManagerPage> createState() => _DeviceManagerPageState();
}

class _DeviceManagerPageState extends State<DeviceManagerPage> {
  final GlobalKey<CurrentDeviceCardState> _currentDeviceCardKey = GlobalKey();
  late FocusNode _pageFocusNode;

  @override
  void initState() {
    super.initState();
    _pageFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _pageFocusNode.dispose();
    super.dispose();
  }

  /// 处理键盘快捷键
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    // Ctrl+E: 编辑当前设备名称
    if (event.logicalKey == LogicalKeyboardKey.keyE &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      _currentDeviceCardKey.currentState?.startEditing();
      return KeyEventResult.handled;
    }

    // Ctrl+N: 配对新设备
    if (event.logicalKey == LogicalKeyboardKey.keyN &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      if (widget.hasJoinedPool) {
        _showPairDeviceDialog(context);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// 处理移除设备
  Future<void> _handleRemoveDevice(String peerId) async {
    try {
      await widget.onRemoveDevice(peerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('设备已移除'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('移除设备失败: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 确保只在桌面端使用
    assert(PlatformDetector.isDesktop, 'DeviceManagerPage 仅支持桌面端平台');

    // 获取屏幕宽度以实现响应式布局
    final screenWidth = MediaQuery.of(context).size.width;

    // 根据屏幕宽度调整最大宽度和间距
    final maxWidth = screenWidth > 1200 ? 1000.0 : 800.0;
    final horizontalPadding = screenWidth > 1200 ? 32.0 : 24.0;
    final verticalPadding = screenWidth > 1200 ? 32.0 : 24.0;
    final cardPadding = screenWidth > 1200 ? 32.0 : 24.0;

    return Focus(
      focusNode: _pageFocusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('设备管理'),
          centerTitle: false,
          actions: [
            // 显示快捷键提示
            if (widget.hasJoinedPool)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Tooltip(
                  message: '快捷键：Ctrl+E 编辑设备名称，Ctrl+N 配对新设备',
                  child: Icon(
                    Icons.keyboard,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: widget.hasJoinedPool
                ? _buildContent(
                    context,
                    horizontalPadding,
                    verticalPadding,
                    cardPadding,
                  )
                : _buildNotInPoolState(
                    context,
                    horizontalPadding,
                    verticalPadding,
                  ),
          ),
        ),
      ),
    );
  }

  /// 构建主内容
  Widget _buildContent(
    BuildContext context,
    double horizontalPadding,
    double verticalPadding,
    double cardPadding,
  ) {
    // 根据屏幕宽度调整元素间距
    final screenWidth = MediaQuery.of(context).size.width;
    final itemSpacing = screenWidth > 1200 ? 32.0 : 24.0;

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: ListView(
          children: [
            // 当前设备卡片
            CurrentDeviceCard(
              key: _currentDeviceCardKey,
              device: widget.currentDevice,
              onDeviceNameChange: widget.onDeviceNameChange,
            ),
            SizedBox(height: itemSpacing),

            // 配对新设备按钮
            _buildPairDeviceButton(context),
            SizedBox(height: itemSpacing),

            // 已配对设备列表
            _buildPairedDevicesList(context, itemSpacing),
          ],
        ),
      ),
    );
  }

  /// 构建配对新设备按钮
  Widget _buildPairDeviceButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showPairDeviceDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('配对新设备'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  /// 构建已配对设备列表
  Widget _buildPairedDevicesList(BuildContext context, double itemSpacing) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final listItemSpacing = screenWidth > 1200 ? 12.0 : 8.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 列表标题
        Row(
          children: [
            Text(
              '已配对设备',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${widget.pairedDevices.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: itemSpacing * 0.67), // 16px for 24px spacing
        // 设备列表或空状态
        if (widget.pairedDevices.isEmpty)
          _buildEmptyState(context)
        else
          // 使用 ListView.builder 实现虚拟滚动
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.pairedDevices.length,
            itemBuilder: (context, index) {
              final device = widget.pairedDevices[index];
              return Padding(
                padding: EdgeInsets.only(bottom: listItemSpacing),
                child: DeviceListItem(
                  key: ValueKey(device.id), // 使用 ValueKey 优化性能
                  device: device,
                  onRemove: () => _handleRemoveDevice(device.id),
                ),
              );
            },
          ),
      ],
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(Icons.wifi_off, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            '暂无配对设备',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '配对新设备开始同步数据',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建未加入数据池状态
  Widget _buildNotInPoolState(
    BuildContext context,
    double horizontalPadding,
    double verticalPadding,
  ) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final cardPadding = screenWidth > 1200 ? 64.0 : 48.0;

    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      child: Center(
        child: Card(
          margin: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: screenWidth > 1200 ? 72 : 64,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  '请先加入数据池',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '设备管理功能需要先加入一个数据池',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 显示配对设备对话框
  void _showPairDeviceDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => PairDeviceDialog(
        currentDevice: widget.currentDevice,
        poolId: widget.poolId,
        onPairDevice: widget.onPairDevice,
      ),
    );
  }
}
