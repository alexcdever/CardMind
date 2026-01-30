/// 设备列表项组件
library;

import 'package:cardmind/bridge/api/sync.dart' as api;
import 'package:flutter/material.dart';

import '../utils/sync_dialog_constants.dart';
import '../utils/sync_dialog_formatters.dart';

/// 设备列表项
///
/// 显示单个设备的信息（名称、状态、最后可见时间）
class DeviceListItem extends StatefulWidget {
  const DeviceListItem({super.key, required this.device});

  /// 设备信息
  final api.DeviceInfo device;

  @override
  State<DeviceListItem> createState() => _DeviceListItemState();
}

class _DeviceListItemState extends State<DeviceListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '设备: ${widget.device.deviceName}',
      value: '${_getStatusText()}, ${_getLastSeenText()}',
      button: false,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: SyncDialogDuration.hover,
          curve: SyncDialogCurve.hover,
          padding: const EdgeInsets.symmetric(
            horizontal: SyncDialogSpacing.itemHorizontal,
            vertical: SyncDialogSpacing.itemVertical,
          ),
          decoration: BoxDecoration(
            color: _isHovered
                ? SyncDialogColor.hoverBackground
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // 设备图标
              Icon(
                _getDeviceIcon(),
                size: SyncDialogIconSize.device,
                color: _getStatusColor(),
              ),
              const SizedBox(width: SyncDialogSpacing.iconText),
              // 设备信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 设备名称（带 Tooltip 处理溢出）
                    Tooltip(
                      message: widget.device.deviceName,
                      child: Text(
                        widget.device.deviceName,
                        style: SyncDialogTextStyle.body,
                        maxLines: SyncDialogLimit.deviceNameMaxLines,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // 最后可见时间
                    Text(
                      _getLastSeenText(),
                      style: SyncDialogTextStyle.caption,
                    ),
                  ],
                ),
              ),
              // 状态标签
              _buildStatusBadge(),
            ],
          ),
        ),
      ),
    );
  }

  /// 获取设备图标
  IconData _getDeviceIcon() {
    switch (widget.device.status) {
      case api.DeviceConnectionStatus.online:
        return Icons.devices;
      case api.DeviceConnectionStatus.syncing:
        return Icons.sync;
      case api.DeviceConnectionStatus.offline:
        return Icons.devices_other;
    }
  }

  /// 获取状态颜色
  Color _getStatusColor() {
    switch (widget.device.status) {
      case api.DeviceConnectionStatus.online:
        return SyncDialogColor.success;
      case api.DeviceConnectionStatus.syncing:
        return SyncDialogColor.syncing;
      case api.DeviceConnectionStatus.offline:
        return SyncDialogColor.textSecondary;
    }
  }

  /// 获取最后可见时间文本
  String _getLastSeenText() {
    final lastSeen = DateTime.fromMillisecondsSinceEpoch(
      widget.device.lastSeen,
    );
    return '最后可见: ${SyncDialogFormatters.formatRelativeTime(lastSeen)}';
  }

  /// 构建状态标签
  Widget _buildStatusBadge() {
    final statusText = _getStatusText();
    final statusColor = _getStatusColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: SyncDialogTextStyle.caption.copyWith(
          color: statusColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 获取状态文本
  String _getStatusText() {
    switch (widget.device.status) {
      case api.DeviceConnectionStatus.online:
        return '在线';
      case api.DeviceConnectionStatus.syncing:
        return '同步中';
      case api.DeviceConnectionStatus.offline:
        return '离线';
    }
  }
}
