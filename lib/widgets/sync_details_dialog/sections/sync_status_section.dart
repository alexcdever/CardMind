/// 同步状态区域组件
library;

import 'package:cardmind/bridge/api/sync.dart' as api;
import 'package:flutter/material.dart';

import '../components/sync_status_icon.dart';
import '../utils/sync_dialog_constants.dart';
import '../utils/sync_dialog_formatters.dart';

/// 同步状态区域
///
/// 显示当前同步状态、图标和最后同步时间
class SyncStatusSection extends StatelessWidget {
  const SyncStatusSection({super.key, required this.status});

  /// 同步状态
  final api.SyncStatus status;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '同步状态: ${_getStatusText()}',
      value: _getSubtitleText(),
      child: Container(
        padding: const EdgeInsets.all(SyncDialogSpacing.itemHorizontal),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // 状态图标（带旋转动画）
            SyncStatusIcon(
              status: _getStatusString(),
              size: SyncDialogIconSize.status,
            ),
            const SizedBox(width: SyncDialogSpacing.iconText),
            // 状态文本
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_getStatusText(), style: SyncDialogTextStyle.title),
                  const SizedBox(height: 4),
                  Text(_getSubtitleText(), style: SyncDialogTextStyle.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 获取状态字符串
  String _getStatusString() {
    switch (status.state) {
      case api.SyncUiState.notYetSynced:
        return 'idle';
      case api.SyncUiState.syncing:
        return 'syncing';
      case api.SyncUiState.synced:
        return 'synced';
      case api.SyncUiState.failed:
        return 'failed';
    }
  }

  /// 获取状态文本
  String _getStatusText() {
    return SyncDialogFormatters.formatSyncStatus(_getStatusString());
  }

  /// 获取副标题文本
  String _getSubtitleText() {
    switch (status.state) {
      case api.SyncUiState.notYetSynced:
        return '尚未执行同步操作';
      case api.SyncUiState.syncing:
        return '正在与其他设备同步数据...';
      case api.SyncUiState.synced:
        final lastSyncTime = status.lastSyncTime != null
            ? DateTime.fromMillisecondsSinceEpoch(status.lastSyncTime!)
            : null;
        return '最后同步: ${SyncDialogFormatters.formatRelativeTime(lastSyncTime)}';
      case api.SyncUiState.failed:
        return status.errorMessage ?? '同步失败，请重试';
    }
  }

  /// 获取背景颜色
  Color _getBackgroundColor() {
    switch (status.state) {
      case api.SyncUiState.syncing:
        return SyncDialogColor.syncing.withValues(alpha: 0.1);
      case api.SyncUiState.synced:
        return SyncDialogColor.success.withValues(alpha: 0.1);
      case api.SyncUiState.failed:
        return SyncDialogColor.error.withValues(alpha: 0.1);
      case api.SyncUiState.notYetSynced:
        return Colors.transparent;
    }
  }
}
