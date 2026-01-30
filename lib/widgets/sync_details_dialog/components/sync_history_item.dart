/// 同步历史项组件
library;

import 'package:cardmind/bridge/api/sync.dart' as api;
import 'package:flutter/material.dart';

import '../utils/sync_dialog_constants.dart';
import '../utils/sync_dialog_formatters.dart';

/// 同步历史项
///
/// 显示单条同步历史记录
class SyncHistoryItem extends StatefulWidget {
  const SyncHistoryItem({super.key, required this.event});

  /// 历史事件
  final api.SyncHistoryEvent event;

  @override
  State<SyncHistoryItem> createState() => _SyncHistoryItemState();
}

class _SyncHistoryItemState extends State<SyncHistoryItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final semanticLabel =
        '${_getStatusText()}, 设备: ${widget.event.deviceName}, ${_getTimestampText()}';
    final semanticValue = widget.event.errorMessage;

    return Semantics(
      label: semanticLabel,
      value: semanticValue,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 状态图标
              Icon(
                _getStatusIcon(),
                size: SyncDialogIconSize.history,
                color: _getStatusColor(),
              ),
              const SizedBox(width: SyncDialogSpacing.iconText),
              // 历史信息
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
                            widget.event.deviceName,
                            style: SyncDialogTextStyle.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getStatusText(),
                          style: SyncDialogTextStyle.caption.copyWith(
                            color: _getStatusColor(),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // 时间戳
                    Text(
                      _getTimestampText(),
                      style: SyncDialogTextStyle.caption,
                    ),
                    // 错误消息（如果有）
                    if (widget.event.errorMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.event.errorMessage!,
                        style: SyncDialogTextStyle.caption.copyWith(
                          color: SyncDialogColor.error,
                        ),
                        maxLines: SyncDialogLimit.errorMessageMaxLines,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 获取状态图标
  IconData _getStatusIcon() {
    switch (widget.event.status) {
      case api.SyncState.syncing:
        return Icons.sync;
      case api.SyncState.synced:
        return Icons.check_circle;
      case api.SyncState.failed:
        return Icons.error;
      case api.SyncState.notYetSynced:
        return Icons.cloud_off;
    }
  }

  /// 获取状态颜色
  Color _getStatusColor() {
    switch (widget.event.status) {
      case api.SyncState.syncing:
        return SyncDialogColor.syncing;
      case api.SyncState.synced:
        return SyncDialogColor.success;
      case api.SyncState.failed:
        return SyncDialogColor.error;
      case api.SyncState.notYetSynced:
        return SyncDialogColor.textSecondary;
    }
  }

  /// 获取状态文本
  String _getStatusText() {
    return SyncDialogFormatters.formatSyncStatus(widget.event.status.name);
  }

  /// 获取时间戳文本
  String _getTimestampText() {
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      widget.event.timestamp,
    );
    return SyncDialogFormatters.formatRelativeTime(timestamp);
  }
}
