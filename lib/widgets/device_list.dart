import 'package:cardmind/bridge/api/sync.dart';
import 'package:cardmind/utils/time_formatter.dart';
import 'package:flutter/material.dart';

/// 设备列表组件
///
/// 显示已连接设备列表，支持响应式布局（移动端列表，桌面端网格）。
/// 每个设备项显示设备信息、在线状态、最后同步时间，并提供断开连接按钮。
class DeviceList extends StatelessWidget {
  const DeviceList({
    super.key,
    required this.devices,
    required this.onDisconnect,
  });

  /// 设备列表
  final List<DeviceInfo> devices;

  /// 断开设备连接回调
  final void Function(String) onDisconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    // 响应式布局：桌面端（>1200px）使用网格，移动端使用列表
    if (screenWidth > 1200) {
      return _buildGridView(context, theme, screenWidth);
    } else {
      return _buildListView(context, theme);
    }
  }

  /// 构建网格布局（桌面端）
  Widget _buildGridView(
    BuildContext context,
    ThemeData theme,
    double screenWidth,
  ) {
    // 根据屏幕宽度调整列数和间距
    final crossAxisCount = screenWidth > 1600 ? 3 : 2;
    final spacing = screenWidth > 1600 ? 24.0 : 16.0;

    if (devices.isEmpty) {
      return _buildEmptyState(context, theme, isDesktop: true);
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: 2.5,
      ),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        return _DeviceCard(
          device: device,
          onDisconnect: () => onDisconnect(device.deviceId),
        );
      },
    );
  }

  /// 构建列表布局（移动端）
  Widget _buildListView(BuildContext context, ThemeData theme) {
    if (devices.isEmpty) {
      return _buildEmptyState(context, theme, isDesktop: false);
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: devices.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final device = devices[index];
        return _DeviceListItem(
          device: device,
          onDisconnect: () => onDisconnect(device.deviceId),
        );
      },
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(
    BuildContext context,
    ThemeData theme, {
    required bool isDesktop,
  }) {
    final padding = isDesktop ? 64.0 : 48.0;
    final iconSize = isDesktop ? 72.0 : 64.0;

    return Container(
      padding: EdgeInsets.all(padding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices_outlined,
            size: iconSize,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无设备',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '等待其他设备连接',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// 设备卡片（桌面端网格项）
class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.onDisconnect});

  final DeviceInfo device;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 设备图标和状态指示器
            _buildDeviceIcon(context, theme),

            const SizedBox(width: 16),

            // 设备信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 设备名称
                  Text(
                    device.deviceName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // 最后同步时间
                  Text(
                    '最后同步：${TimeFormatter.formatTime(device.lastSeen.toInt())}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // 断开连接按钮
            IconButton(
              icon: const Icon(Icons.link_off),
              tooltip: '断开连接',
              color: theme.colorScheme.error,
              onPressed: () => _confirmDisconnect(context),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建设备图标
  Widget _buildDeviceIcon(BuildContext context, ThemeData theme) {
    return Stack(
      children: [
        // 设备图标
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getDeviceIcon(),
            color: theme.colorScheme.onPrimaryContainer,
            size: 28,
          ),
        ),

        // 在线状态指示器
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _getStatusColor(theme),
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.surface, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  /// 获取设备图标
  IconData _getDeviceIcon() {
    // 根据设备名称判断设备类型
    final name = device.deviceName.toLowerCase();
    if (name.contains('phone') || name.contains('手机')) {
      return Icons.smartphone;
    } else if (name.contains('tablet') || name.contains('平板')) {
      return Icons.tablet;
    } else {
      return Icons.laptop;
    }
  }

  /// 获取状态颜色
  Color _getStatusColor(ThemeData theme) {
    switch (device.status) {
      case DeviceConnectionStatus.online:
        return Colors.green;
      case DeviceConnectionStatus.offline:
        return Colors.grey;
      case DeviceConnectionStatus.syncing:
        return theme.colorScheme.primary;
    }
  }

  /// 确认断开连接
  void _confirmDisconnect(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('断开连接'),
        content: Text('确定要断开与 "${device.deviceName}" 的连接吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDisconnect();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('断开'),
          ),
        ],
      ),
    );
  }
}

/// 设备列表项（移动端）
class _DeviceListItem extends StatelessWidget {
  const _DeviceListItem({required this.device, required this.onDisconnect});

  final DeviceInfo device;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 设备图标和状态指示器
          _buildDeviceIcon(context, theme),

          const SizedBox(width: 16),

          // 设备信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 设备名称和状态
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        device.deviceName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(theme),
                  ],
                ),
                const SizedBox(height: 4),

                // 设备 ID（截断显示）
                Text(
                  _formatDeviceId(device.deviceId),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // 最后同步时间
                Text(
                  '最后同步：${TimeFormatter.formatTime(device.lastSeen.toInt())}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // 断开连接按钮
          IconButton(
            icon: const Icon(Icons.link_off),
            tooltip: '断开连接',
            color: theme.colorScheme.error,
            onPressed: () => _confirmDisconnect(context),
          ),
        ],
      ),
    );
  }

  /// 构建设备图标
  Widget _buildDeviceIcon(BuildContext context, ThemeData theme) {
    return Stack(
      children: [
        // 设备图标
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getDeviceIcon(),
            color: theme.colorScheme.onPrimaryContainer,
            size: 28,
          ),
        ),

        // 在线状态指示器
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _getStatusColor(theme),
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.surface, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建状态徽章
  Widget _buildStatusBadge(ThemeData theme) {
    String label;
    Color color;

    switch (device.status) {
      case DeviceConnectionStatus.online:
        label = '在线';
        color = Colors.green;
        break;
      case DeviceConnectionStatus.offline:
        label = '离线';
        color = Colors.grey;
        break;
      case DeviceConnectionStatus.syncing:
        label = '同步中';
        color = theme.colorScheme.primary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 获取设备图标
  IconData _getDeviceIcon() {
    // 根据设备名称判断设备类型
    final name = device.deviceName.toLowerCase();
    if (name.contains('phone') || name.contains('手机')) {
      return Icons.smartphone;
    } else if (name.contains('tablet') || name.contains('平板')) {
      return Icons.tablet;
    } else {
      return Icons.laptop;
    }
  }

  /// 获取状态颜色
  Color _getStatusColor(ThemeData theme) {
    switch (device.status) {
      case DeviceConnectionStatus.online:
        return Colors.green;
      case DeviceConnectionStatus.offline:
        return Colors.grey;
      case DeviceConnectionStatus.syncing:
        return theme.colorScheme.primary;
    }
  }

  /// 格式化设备 ID（截断显示）
  String _formatDeviceId(String deviceId) {
    if (deviceId.length <= 20) {
      return deviceId;
    }
    return '${deviceId.substring(0, 10)}...${deviceId.substring(deviceId.length - 7)}';
  }

  /// 确认断开连接
  void _confirmDisconnect(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('断开连接'),
        content: Text('确定要断开与 "${device.deviceName}" 的连接吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDisconnect();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('断开'),
          ),
        ],
      ),
    );
  }
}
