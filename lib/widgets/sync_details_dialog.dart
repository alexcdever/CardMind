import 'dart:async';

import 'package:flutter/material.dart';

import 'package:cardmind/bridge/api/sync.dart' as api_sync;
import 'package:cardmind/bridge/api/sync.dart' show DeviceInfo, SyncStatistics, SyncHistoryEvent, DeviceConnectionStatus;
import 'package:cardmind/bridge/third_party/cardmind_rust/api/sync.dart' as sync_api;
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

  /// 设备列表
  List<DeviceInfo>? _devices;

  /// 同步统计信息
  SyncStatistics? _statistics;

  /// 同步历史
  List<SyncHistoryEvent>? _history;

  /// 是否正在加载数据
  bool _isLoading = true;

  /// 定时器用于定期刷新数据
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // 每5秒刷新一次数据
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// 加载设备列表、统计信息和历史记录
  Future<void> _loadData() async {
    try {
      final devices = await sync_api.getDeviceList();
      final statistics = await sync_api.getSyncStatistics();
      final history = await sync_api.getSyncHistory();

      if (mounted) {
        setState(() {
          _devices = devices;
          _statistics = statistics;
          _history = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 获取状态描述
  String _getStatusDescription() {
    switch (widget.status.state) {
      case SyncState.notYetSynced:
        return '应用尚未执行过同步操作。请确保其他设备在同一网络中。';
      case SyncState.syncing:
        return '正在同步数据...';
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
      case SyncState.notYetSynced:
        return Icons.cloud_off;
      case SyncState.syncing:
        return Icons.refresh;
      case SyncState.synced:
        return Icons.check;
      case SyncState.failed:
        return Icons.error_outline;
    }
  }

  /// 获取状态颜色
  Color _getStatusColor() {
    switch (widget.status.state) {
      case SyncState.notYetSynced:
        return const Color(0xFF757575); // grey
      case SyncState.syncing:
        return const Color(0xFF00897B); // secondary color
      case SyncState.synced:
        return const Color(0xFF43A047); // green
      case SyncState.failed:
        return const Color(0xFFE53935); // red
    }
  }

  /// 获取状态标题
  String _getStatusTitle() {
    switch (widget.status.state) {
      case SyncState.notYetSynced:
        return '尚未同步';
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

  /// 构建设备列表项
  Widget _buildDeviceItem(DeviceInfo device) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (device.status) {
      case DeviceConnectionStatus.online:
        statusColor = const Color(0xFF43A047); // green
        statusIcon = Icons.check_circle;
        statusText = '在线';
        break;
      case DeviceConnectionStatus.offline:
        statusColor = const Color(0xFF757575); // grey
        statusIcon = Icons.circle_outlined;
        statusText = '离线';
        break;
      case DeviceConnectionStatus.syncing:
        statusColor = const Color(0xFF00897B); // secondary color
        statusIcon = Icons.sync;
        statusText = '同步中';
        break;
    }

    // 格式化最后可见时间
    final lastSeen = DateTime.fromMillisecondsSinceEpoch(device.lastSeen);
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    String lastSeenText;
    if (difference.inSeconds < 60) {
      lastSeenText = '刚刚';
    } else if (difference.inMinutes < 60) {
      lastSeenText = '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      lastSeenText = '${difference.inHours}小时前';
    } else {
      lastSeenText = '${difference.inDays}天前';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.deviceName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '上次可见：$lastSeenText',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建统计信息部分
  Widget _buildStatisticsSection(SyncStatistics stats) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          _buildStatItem('已同步卡片', '${stats.syncedCards}张'),
          const Divider(height: 16),
          _buildStatItem('同步数据大小', _formatBytes(stats.syncedDataSize)),
          const Divider(height: 16),
          _buildStatItem('成功次数', '${stats.successfulSyncs}次'),
          const Divider(height: 16),
          _buildStatItem('失败次数', '${stats.failedSyncs}次'),
        ],
      ),
    );
  }

  /// 构建统计项
  Widget _buildStatItem(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  /// 格式化字节大小
  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// 构建历史记录项
  Widget _buildHistoryItem(SyncHistoryEvent event) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (event.status) {
      case api_sync.SyncState.notYetSynced:
        statusColor = const Color(0xFF757575);
        statusIcon = Icons.cloud_off;
        statusText = '尚未同步';
        break;
      case api_sync.SyncState.syncing:
        statusColor = const Color(0xFF00897B);
        statusIcon = Icons.sync;
        statusText = '同步中';
        break;
      case api_sync.SyncState.synced:
        statusColor = const Color(0xFF43A047);
        statusIcon = Icons.check_circle;
        statusText = '已同步';
        break;
      case api_sync.SyncState.failed:
        statusColor = const Color(0xFFE53935);
        statusIcon = Icons.error;
        statusText = '失败';
        break;
    }

    // 格式化时间戳
    final timestamp = DateTime.fromMillisecondsSinceEpoch(event.timestamp);
    final timeStr = _formatTime(timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: statusColor,
                      ),
                    ),
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '设备：${event.deviceName}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
                if (event.errorMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '错误：${event.errorMessage}',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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

            // 同步进度指示器（syncing 状态）
            if (widget.status.state == SyncState.syncing) ...[
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('正在同步数据...'),
                ],
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

            // 设备列表
            if (_devices != null && _devices!.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                '已发现的设备',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              ..._devices!.map((device) => _buildDeviceItem(device)),
            ],

            // 同步统计信息
            if (_statistics != null) ...[
              const SizedBox(height: 24),
              const Text(
                '同步统计',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              _buildStatisticsSection(_statistics!),
            ],

            // 同步历史
            if (_history != null && _history!.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                '同步历史',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              ..._history!.map((event) => _buildHistoryItem(event)),
            ],

            // 加载指示器
            if (_isLoading) ...[
              const SizedBox(height: 16),
              const Center(
                child: CircularProgressIndicator(),
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
