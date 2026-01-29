import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cardmind/models/device.dart';
import 'package:cardmind/utils/time_formatter.dart';

/// 设备列表项
///
/// 显示已配对设备的详细信息，包括设备名称、类型、状态和地址。
class DeviceListItem extends StatefulWidget {
  const DeviceListItem({super.key, required this.device, this.onRemove});

  final Device device;

  /// 移除设备回调
  final VoidCallback? onRemove;

  @override
  State<DeviceListItem> createState() => _DeviceListItemState();
}

class _DeviceListItemState extends State<DeviceListItem> {
  bool _isHovered = false;

  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.phone:
        return Icons.smartphone;
      case DeviceType.laptop:
        return Icons.laptop;
      case DeviceType.tablet:
        return Icons.tablet;
    }
  }

  String _getDeviceTypeText(DeviceType type) {
    switch (type) {
      case DeviceType.phone:
        return '手机';
      case DeviceType.laptop:
        return '笔记本';
      case DeviceType.tablet:
        return '平板';
    }
  }

  Color _getStatusColor(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.online:
        return Colors.green;
      case DeviceStatus.offline:
        return Colors.grey;
    }
  }

  String _getStatusText(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.online:
        return '在线';
      case DeviceStatus.offline:
        return '离线';
    }
  }

  /// 显示右键上下文菜单
  void _showContextMenu(BuildContext context, TapDownDetails details) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: [
        PopupMenuItem<String>(
          value: 'copy_peer_id',
          child: Row(
            children: [
              Icon(
                Icons.copy,
                size: 18,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              const Text('复制 PeerId'),
            ],
          ),
        ),
        if (widget.device.multiaddrs.isNotEmpty)
          PopupMenuItem<String>(
            value: 'copy_address',
            child: Row(
              children: [
                Icon(
                  Icons.link,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                const Text('复制地址'),
              ],
            ),
          ),
        PopupMenuItem<String>(
          value: 'view_details',
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              const Text('查看详情'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (widget.onRemove != null)
          PopupMenuItem<String>(
            value: 'remove',
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 12),
                Text(
                  '移除设备',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ),
          ),
      ],
    ).then((value) {
      if (value != null) {
        _handleMenuAction(context, value);
      }
    });
  }

  /// 处理菜单操作
  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'copy_peer_id':
        Clipboard.setData(ClipboardData(text: widget.device.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PeerId 已复制到剪贴板'),
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case 'copy_address':
        if (widget.device.multiaddrs.isNotEmpty) {
          final addresses = widget.device.multiaddrs.join('\n');
          Clipboard.setData(ClipboardData(text: addresses));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已复制 ${widget.device.multiaddrs.length} 个地址到剪贴板'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        break;
      case 'view_details':
        _showDeviceDetailsDialog(context);
        break;
      case 'remove':
        _confirmRemoveDevice(context);
        break;
    }
  }

  /// 显示设备详情对话框
  void _showDeviceDetailsDialog(BuildContext context) {
    final theme = Theme.of(context);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getDeviceIcon(widget.device.type),
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(widget.device.name, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('设备类型', _getDeviceTypeText(widget.device.type)),
              const SizedBox(height: 12),
              _buildDetailRow('状态', _getStatusText(widget.device.status)),
              const SizedBox(height: 12),
              _buildDetailRow(
                '最后在线',
                TimeFormatter.formatTime(
                  widget.device.lastSeen.millisecondsSinceEpoch,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'PeerId',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                widget.device.id,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (widget.device.multiaddrs.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '网络地址 (${widget.device.multiaddrs.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...widget.device.multiaddrs.map(
                  (addr) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SelectableText(
                      addr,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 构建详情行
  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  /// 确认移除设备
  void _confirmRemoveDevice(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除设备'),
        content: Text('确定要移除设备 "${widget.device.name}" 吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onRemove?.call();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('移除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    // 根据屏幕宽度调整布局参数
    final isLargeScreen = screenWidth > 1200;
    final containerPadding = isLargeScreen ? 20.0 : 16.0;
    final iconSize = isLargeScreen ? 56.0 : 48.0;
    final iconInnerSize = isLargeScreen ? 32.0 : 28.0;
    final horizontalSpacing = isLargeScreen ? 20.0 : 16.0;

    return Focus(
      child: GestureDetector(
        onSecondaryTapDown: (details) => _showContextMenu(context, details),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(containerPadding),
            decoration: BoxDecoration(
              color: _isHovered
                  ? theme.colorScheme.surfaceContainerHighest
                  : theme.colorScheme.surface,
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // 设备图标
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getDeviceIcon(widget.device.type),
                    color: theme.colorScheme.onPrimaryContainer,
                    size: iconInnerSize,
                  ),
                ),
                SizedBox(width: horizontalSpacing),

                // 设备信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 设备名称和类型
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.device.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: isLargeScreen ? 16 : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getDeviceTypeText(widget.device.type),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isLargeScreen ? 6 : 4),

                      // PeerId
                      Tooltip(
                        message: '点击复制 PeerId',
                        child: InkWell(
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: widget.device.id),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('PeerId 已复制到剪贴板'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 2,
                              horizontal: 4,
                            ),
                            child: Text(
                              widget.device.id,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: isLargeScreen ? 10 : 8),

                      // Multiaddr 地址列表
                      if (widget.device.multiaddrs.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: widget.device.multiaddrs
                              .take(3) // 最多显示 3 个地址
                              .map(
                                (addr) => _buildAddressChip(
                                  theme,
                                  addr,
                                  isLargeScreen,
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: horizontalSpacing),

                // 状态和最后在线时间
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 在线状态
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? 14 : 12,
                        vertical: isLargeScreen ? 7 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(widget.device.status),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getStatusText(widget.device.status),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 最后在线时间
                    Text(
                      '最后在线：${TimeFormatter.formatTime(widget.device.lastSeen.millisecondsSinceEpoch)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建地址芯片
  Widget _buildAddressChip(ThemeData theme, String addr, bool isLargeScreen) {
    // 简化地址显示（提取 IP 和端口）
    final simplified = _simplifyMultiaddr(addr);
    final chipPadding = isLargeScreen ? 10.0 : 8.0;
    final iconSize = isLargeScreen ? 14.0 : 12.0;

    return Tooltip(
      message: '完整地址: $addr\n点击复制',
      child: InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: addr));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('地址已复制到剪贴板'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: chipPadding, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getProtocolIcon(addr),
                size: iconSize,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 4),
              Text(
                simplified,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 简化 Multiaddr 显示
  String _simplifyMultiaddr(String addr) {
    // 示例: /ip4/192.168.1.100/tcp/4001 -> 192.168.1.100:4001
    final parts = addr.split('/');
    if (parts.length >= 5) {
      final ip = parts[2];
      final port = parts[4];
      return '$ip:$port';
    }
    return addr;
  }

  /// 获取协议图标
  IconData _getProtocolIcon(String addr) {
    if (addr.contains('/tcp/')) {
      return Icons.cable;
    } else if (addr.contains('/udp/') || addr.contains('/quic/')) {
      return Icons.speed;
    } else if (addr.contains('/ip6/')) {
      return Icons.language;
    }
    return Icons.wifi;
  }
}
