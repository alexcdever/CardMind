import 'package:flutter/material.dart';

import 'package:cardmind/models/sync_status.dart';

/// Sync Details Dialog
///
/// 显示同步状态详情的对话框
///
/// 规格编号: SP-FLUT-010
/// 功能：
/// - 显示当前同步状态和描述
/// - 显示对等设备列表
/// - 显示错误信息（failed 状态）
/// - 提供重试按钮（failed 状态）

class SyncDetailsDialog extends StatelessWidget {
  const SyncDetailsDialog({
    super.key,
    required this.status,
  });

  /// 当前同步状态
  final SyncStatus status;

  /// 获取状态描述
  String _getStatusDescription() {
    switch (status.state) {
      case SyncState.disconnected:
        return '当前没有连接到任何对等设备。请确保其他设备在同一网络中。';
      case SyncState.syncing:
        return '正在与 ${status.syncingPeers} 台设备同步数据...';
      case SyncState.synced:
        if (status.lastSyncTime != null) {
          final time = _formatTime(status.lastSyncTime!);
          return '数据已同步，最后同步时间：$time';
        }
        return '数据已同步，所有设备数据一致。';
      case SyncState.failed:
        return '同步失败，请检查网络连接或重试。';
    }
  }

  /// 格式化时间
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  /// 获取状态图标
  IconData _getStatusIcon() {
    switch (status.state) {
      case SyncState.disconnected:
        return Icons.cloud_off;
      case SyncState.syncing:
        return Icons.sync;
      case SyncState.synced:
        return Icons.cloud_done;
      case SyncState.failed:
        return Icons.error_outline;
    }
  }

  /// 获取状态颜色
  Color _getStatusColor() {
    switch (status.state) {
      case SyncState.disconnected:
        return const Color(0xFF757575); // grey
      case SyncState.syncing:
        return const Color(0xFF00897B); // primary color
      case SyncState.synced:
        return const Color(0xFF43A047); // green
      case SyncState.failed:
        return const Color(0xFFFB8C00); // orange
    }
  }

  /// 获取状态标题
  String _getStatusTitle() {
    switch (status.state) {
      case SyncState.disconnected:
        return '未同步';
      case SyncState.syncing:
        return '同步中';
      case SyncState.synced:
        return '已同步';
      case SyncState.failed:
        return '同步失败';
    }
  }

  /// 处理重试
  void _handleRetry(BuildContext context) {
    // TODO: 调用 SyncApi.retrySync()
    // 暂时只关闭对话框
    Navigator.of(context).pop();
    debugPrint('Retry sync requested');
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final statusIcon = _getStatusIcon();
    final statusTitle = _getStatusTitle();
    final statusDescription = _getStatusDescription();

    return AlertDialog(
      title: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 28),
          const SizedBox(width: 12),
          Text(statusTitle),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 状态描述
            Text(
              statusDescription,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // 对等设备列表（syncing 状态）
            if (status.state == SyncState.syncing && status.syncingPeers > 0) ...[
              const Text(
                '连接的设备：',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(
                status.syncingPeers,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.devices, size: 16),
                      const SizedBox(width: 8),
                      Text('设备 ${index + 1}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 错误信息（failed 状态）
            if (status.state == SyncState.failed &&
                status.errorMessage != null) ...[
              const Text(
                '错误详情：',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status.errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        // 重试按钮（仅在 failed 状态显示）
        if (status.state == SyncState.failed)
          TextButton.icon(
            onPressed: () => _handleRetry(context),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF00897B),
            ),
          ),
        // 关闭按钮
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
