import 'package:flutter/material.dart';

import 'package:cardmind/models/sync_status.dart';
import 'package:cardmind/bridge/third_party/cardmind_rust/api/sync.dart' as sync_api;

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

class SyncDetailsDialog extends StatefulWidget {
  const SyncDetailsDialog({
    super.key,
    required this.status,
  });

  /// 当前同步状态
  final SyncStatus status;

  @override
  State<SyncDetailsDialog> createState() => _SyncDetailsDialogState();
}

class _SyncDetailsDialogState extends State<SyncDetailsDialog> {
  /// 是否正在重试
  bool _isRetrying = false;

  /// 重试错误信息
  String? _retryError;

  /// 获取状态描述
  String _getStatusDescription() {
    switch (widget.status.state) {
      case SyncState.disconnected:
        return '当前没有连接到任何对等设备。请确保其他设备在同一网络中。';
      case SyncState.syncing:
        return '正在与 ${widget.status.syncingPeers} 台设备同步数据...';
      case SyncState.synced:
        if (widget.status.lastSyncTime != null) {
          final time = _formatTime(widget.status.lastSyncTime!);
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
    switch (widget.status.state) {
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
    switch (widget.status.state) {
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
    switch (widget.status.state) {
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
  Future<void> _handleRetry() async {
    // 设置重试状态
    setState(() {
      _isRetrying = true;
      _retryError = null;
    });

    try {
      // 调用 Rust API 重试同步
      await sync_api.retrySync();

      // 重试成功，关闭对话框
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // 重试失败，显示错误消息
      if (mounted) {
        setState(() {
          _isRetrying = false;
          _retryError = '重试失败：${e.toString()}';
        });
      }
    }
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
            if (widget.status.state == SyncState.syncing && widget.status.syncingPeers > 0) ...[
              const Text(
                '连接的设备：',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(
                widget.status.syncingPeers,
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
            if (widget.status.state == SyncState.failed &&
                widget.status.errorMessage != null) ...[
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
                        widget.status.errorMessage!,
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

            // 重试错误信息
            if (_retryError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _retryError!,
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 重试中的 loading 状态
            if (_isRetrying) ...[
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('正在重试同步...'),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        // 重试按钮（仅在 failed 状态显示）
        if (widget.status.state == SyncState.failed)
          TextButton.icon(
            onPressed: _isRetrying ? null : _handleRetry,
            icon: _isRetrying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(_isRetrying ? '重试中...' : '重试'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF00897B),
            ),
          ),
        // 关闭按钮
        TextButton(
          onPressed: _isRetrying ? null : () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
