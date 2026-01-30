import 'package:cardmind/models/device.dart';
import 'package:cardmind/utils/device_utils.dart';
import 'package:cardmind/widgets/current_device_card.dart';
import 'package:cardmind/widgets/device_list_item.dart';
import 'package:cardmind/widgets/pair_device_dialog.dart';
import 'package:flutter/material.dart';

/// 移动端设备管理页面
///
/// 专为移动端设计的设备管理界面，优化触摸交互。
/// 支持查看设备列表、配对新设备、编辑当前设备名称。
class MobileDeviceManagerPage extends StatefulWidget {
  const MobileDeviceManagerPage({
    super.key,
    required this.hasJoinedPool,
    required this.currentDevice,
    required this.pairedDevices,
    required this.poolId,
    required this.onDeviceNameChange,
    required this.onPairDevice,
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
  final void Function(String newName) onDeviceNameChange;

  /// 配对新设备回调
  final Future<bool> Function(String deviceId, String verificationCode)
  onPairDevice;

  @override
  State<MobileDeviceManagerPage> createState() =>
      _MobileDeviceManagerPageState();
}

class _MobileDeviceManagerPageState extends State<MobileDeviceManagerPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设备管理'), centerTitle: true),
      body: widget.hasJoinedPool
          ? _buildContent(context)
          : _buildNotInPoolState(context),
    );
  }

  /// 构建主内容
  Widget _buildContent(BuildContext context) {
    // 对设备列表进行排序（在线优先 + 最后在线时间倒序）
    final sortedDevices = DeviceUtils.sortDevices(widget.pairedDevices);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 当前设备卡片
        CurrentDeviceCard(
          device: widget.currentDevice,
          onDeviceNameChange: widget.onDeviceNameChange,
        ),
        const SizedBox(height: 16),

        // 设备列表标题和配对按钮
        _buildDeviceListHeader(context),
        const SizedBox(height: 12),

        // 已配对设备列表或空状态
        if (sortedDevices.isEmpty)
          _buildEmptyState(context)
        else
          ...sortedDevices.map(
            (device) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DeviceListItem(key: ValueKey(device.id), device: device),
            ),
          ),
      ],
    );
  }

  /// 构建设备列表标题和配对按钮
  Widget _buildDeviceListHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // 列表标题
        Text(
          '已配对设备 (${widget.pairedDevices.length})',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),

        // 配对设备按钮
        ElevatedButton.icon(
          onPressed: () => _showPairDeviceDialog(context),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('配对设备'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.wifi_off,
            size: 64,
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            '暂无配对设备',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '点击上方按钮配对新设备',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建未加入数据池状态
  Widget _buildNotInPoolState(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  '请先加入数据池',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
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
