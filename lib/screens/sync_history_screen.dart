import 'package:cardmind/models/sync_history_entry.dart';
import 'package:cardmind/utils/time_formatter.dart';
import 'package:flutter/material.dart';

/// 同步历史屏幕
///
/// 显示同步统计概览、同步历史列表和冲突记录。
///
/// ## 功能特性
/// - 同步统计概览（总次数、成功次数、失败次数）
/// - 同步历史列表（时间、状态、设备、数据量）
/// - 冲突记录显示
/// - 清除历史功能
/// - 按时间排序的历史记录
/// - 支持查看详情
///
/// ## 使用示例
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => const SyncHistoryScreen(),
///   ),
/// );
/// ```
///
/// ## 数据流
/// - 历史记录从本地存储加载
/// - 统计数据实时计算
/// - 清除操作需要用户确认
class SyncHistoryScreen extends StatefulWidget {
  /// 创建同步历史屏幕
  const SyncHistoryScreen({super.key});

  @override
  State<SyncHistoryScreen> createState() => _SyncHistoryScreenState();
}

class _SyncHistoryScreenState extends State<SyncHistoryScreen> {
  /// 模拟同步历史数据（实际应从存储加载）
  late List<SyncHistoryEntry> _syncHistory;

  /// 模拟冲突记录（实际应从存储加载）
  late List<ConflictRecord> _conflicts;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// 加载数据（模拟数据）
  void _loadData() {
    // TODO: 从实际存储加载同步历史
    _syncHistory = _getMockSyncHistory();
    _conflicts = _getMockConflicts();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('同步历史'),
        actions: [
          // 清除历史按钮
          if (_syncHistory.isNotEmpty)
            TextButton.icon(
              onPressed: () => _showClearHistoryDialog(context),
              icon: const Icon(Icons.delete_outline),
              label: const Text('清除'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 同步统计概览
          _buildStatsCard(context),
          const SizedBox(height: 16),

          // 冲突记录（如果有）
          if (_conflicts.isNotEmpty) ...[
            _buildConflictsCard(context),
            const SizedBox(height: 16),
          ],

          // 同步历史列表标题
          Text(
            '历史记录',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // 同步历史列表
          if (_syncHistory.isEmpty)
            _buildEmptyState()
          else
            ..._syncHistory.map(_buildHistoryItem),
        ],
      ),
    );
  }

  /// 构建统计卡片
  Widget _buildStatsCard(BuildContext context) {
    final theme = Theme.of(context);
    final totalSyncs = _syncHistory.length;
    final successCount = _syncHistory.where((e) => e.isSuccess).length;
    final failedCount = _syncHistory.where((e) => e.isFailed).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('同步统计', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  '总次数',
                  totalSyncs.toString(),
                  Icons.sync,
                  Colors.blue,
                ),
                _buildStatItem(
                  context,
                  '成功',
                  successCount.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildStatItem(
                  context,
                  '失败',
                  failedCount.toString(),
                  Icons.error_outline,
                  Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建统计项
  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  /// 构建冲突记录卡片
  Widget _buildConflictsCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  '冲突记录',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.orange,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_conflicts.length} 条',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._conflicts.take(3).map(_buildConflictItem),
            if (_conflicts.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: TextButton(
                    onPressed: () {
                      // TODO: 导航到冲突详情页面
                    },
                    child: const Text('查看全部'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建冲突项
  Widget _buildConflictItem(ConflictRecord conflict) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conflict.cardTitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${conflict.resolvedAt} · ${conflict.resolvedBy}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建历史记录项
  Widget _buildHistoryItem(SyncHistoryEntry entry) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: entry.status.color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(entry.status.icon, color: entry.status.color, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                entry.deviceName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              entry.status.displayName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: entry.status.color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              TimeFormatter.formatTime(entry.timestamp),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (entry.errorMessage != null) ...[
              const SizedBox(height: 2),
              Text(
                entry.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              entry.formattedDataTransferred,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        onTap: () {
          // TODO: 显示同步详情
          _showSyncDetailsDialog(entry);
        },
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text(
              '暂无同步历史',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.disabledColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '同步操作完成后会显示在这里',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.disabledColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 显示清除历史确认对话框
  void _showClearHistoryDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除历史'),
        content: const Text('确定要清除所有同步历史记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _syncHistory.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('同步历史已清除'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }

  /// 显示同步详情对话框
  void _showSyncDetailsDialog(SyncHistoryEntry entry) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('同步详情'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('设备', entry.deviceName),
              _buildDetailRow('设备ID', entry.deviceId),
              _buildDetailRow('时间', TimeFormatter.formatTime(entry.timestamp)),
              _buildDetailRow('状态', entry.status.displayName),
              _buildDetailRow('数据量', entry.formattedDataTransferred),
              if (entry.errorMessage != null)
                _buildDetailRow('错误', entry.errorMessage!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 构建详情行
  Widget _buildDetailRow(String label, String value) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  /// 生成模拟同步历史数据
  List<SyncHistoryEntry> _getMockSyncHistory() {
    return [
      SyncHistoryEntry(
        id: '1',
        timestamp: DateTime.now()
            .subtract(const Duration(minutes: 5))
            .millisecondsSinceEpoch,
        status: SyncHistoryStatus.success,
        deviceId: 'device-123',
        deviceName: '我的笔记本电脑',
        dataTransferred: 1024 * 512,
      ),
      SyncHistoryEntry(
        id: '2',
        timestamp: DateTime.now()
            .subtract(const Duration(hours: 2))
            .millisecondsSinceEpoch,
        status: SyncHistoryStatus.success,
        deviceId: 'device-456',
        deviceName: '我的手机',
        dataTransferred: 1024 * 1024 * 2,
      ),
      SyncHistoryEntry(
        id: '3',
        timestamp: DateTime.now()
            .subtract(const Duration(days: 1))
            .millisecondsSinceEpoch,
        status: SyncHistoryStatus.failed,
        deviceId: 'device-789',
        deviceName: '工作电脑',
        dataTransferred: 0,
        errorMessage: '连接超时',
      ),
    ];
  }

  /// 生成模拟冲突记录
  List<ConflictRecord> _getMockConflicts() {
    return const [
      ConflictRecord(
        id: '1',
        cardId: 'card-123',
        cardTitle: '项目笔记',
        resolvedAt: '2小时前',
        resolvedBy: '自动解决',
      ),
      ConflictRecord(
        id: '2',
        cardId: 'card-456',
        cardTitle: '会议记录',
        resolvedAt: '昨天',
        resolvedBy: '手动合并',
      ),
    ];
  }
}

/// 冲突记录模型
class ConflictRecord {
  /// 创建冲突记录
  const ConflictRecord({
    required this.id,
    required this.cardId,
    required this.cardTitle,
    required this.resolvedAt,
    required this.resolvedBy,
  });

  /// 冲突记录唯一标识
  final String id;

  /// 卡片ID
  final String cardId;

  /// 卡片标题
  final String cardTitle;

  /// 解决时间
  final String resolvedAt;

  /// 解决方式（自动/手动）
  final String resolvedBy;
}
