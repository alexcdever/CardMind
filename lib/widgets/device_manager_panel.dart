import 'package:flutter/material.dart';

/// 设备类型枚举
enum DeviceType { phone, laptop, tablet }

/// 设备信息模型
class DeviceInfo {
  DeviceInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.isOnline,
    required this.lastSeen,
  });
  final String id;
  final String name;
  final DeviceType type;
  final bool isOnline;
  final DateTime lastSeen;
}

/// 设备管理面板
///
/// 显示当前设备和已配对设备列表
class DeviceManagerPanel extends StatefulWidget {
  const DeviceManagerPanel({
    super.key,
    required this.currentDevice,
    required this.pairedDevices,
    required this.onDeviceNameChange,
    required this.onAddDevice,
    required this.onRemoveDevice,
  });

  final DeviceInfo currentDevice;
  final List<DeviceInfo> pairedDevices;
  final void Function(String) onDeviceNameChange;
  final void Function(DeviceInfo) onAddDevice;
  final void Function(String) onRemoveDevice;

  @override
  State<DeviceManagerPanel> createState() => _DeviceManagerPanelState();
}

class _DeviceManagerPanelState extends State<DeviceManagerPanel> {
  bool _isEditingName = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentDevice.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleSaveName() {
    if (_nameController.text.trim().isNotEmpty) {
      widget.onDeviceNameChange(_nameController.text.trim());
      setState(() {
        _isEditingName = false;
      });
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  Icon(Icons.wifi, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('设备网络', style: theme.textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 16),

              // 当前设备
              Text(
                '当前设备',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getDeviceIcon(widget.currentDevice.type),
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _isEditingName
                          ? TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                              autofocus: true,
                            )
                          : Text(
                              widget.currentDevice.name,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    if (_isEditingName)
                      IconButton(
                        icon: const Icon(Icons.check, size: 20),
                        onPressed: _handleSaveName,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () {
                          setState(() {
                            _isEditingName = true;
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 已配对设备
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '已配对设备',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showAddDeviceDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('添加'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 设备列表
              if (widget.pairedDevices.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '暂无配对设备',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                )
              else
                ...widget.pairedDevices.map(
                  (device) => _buildDeviceItem(context, device),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceItem(BuildContext context, DeviceInfo device) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(_getDeviceIcon(device.type), color: theme.iconTheme.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.name, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      device.isOnline ? Icons.circle : Icons.circle_outlined,
                      size: 12,
                      color: device.isOnline ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      device.isOnline
                          ? '在线'
                          : '离线 · ${_formatLastSeen(device.lastSeen)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => widget.onRemoveDevice(device.id),
            color: theme.colorScheme.error,
          ),
        ],
      ),
    );
  }

  void _showAddDeviceDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加设备'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('扫码配对'),
              subtitle: const Text('扫描其他设备的二维码'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 实现扫码功能
              },
            ),
            ListTile(
              leading: const Icon(Icons.radar),
              title: const Text('局域网发现'),
              subtitle: const Text('自动发现局域网内的设备'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 实现局域网发现
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} 分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} 小时前';
    } else {
      return '${difference.inDays} 天前';
    }
  }
}
