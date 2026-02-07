/// 同步统计信息区域组件
library;

import 'package:cardmind/bridge/api/sync.dart' as api;
import 'package:flutter/material.dart';

import '../components/statistic_item.dart';
import '../utils/sync_dialog_constants.dart';
import '../utils/sync_dialog_formatters.dart';

/// 同步统计信息区域
///
/// 显示同步统计数据（卡片数、数据大小、成功/失败次数）
class SyncStatisticsSection extends StatelessWidget {
  const SyncStatisticsSection({
    super.key,
    required this.statistics,
    this.isLoading = false,
    this.error,
    this.onRetry,
  });

  /// 统计信息
  final api.SyncStatistics statistics;

  /// 是否正在加载
  final bool isLoading;

  /// 错误消息
  final String? error;

  /// 重试回调
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标题
        Semantics(
          header: true,
          child: const Text('同步统计', style: SyncDialogTextStyle.sectionTitle),
        ),
        const SizedBox(height: 12),
        // 内容
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (error != null)
          _buildErrorState()
        else
          _buildStatisticsGrid(),
      ],
    );
  }

  /// 构建错误状态
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: SyncDialogColor.error.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              error!,
              style: SyncDialogTextStyle.emptyState.copyWith(
                color: SyncDialogColor.error,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建统计信息网格
  Widget _buildStatisticsGrid() {
    return Wrap(
      spacing: SyncDialogSpacing.statisticGrid,
      runSpacing: SyncDialogSpacing.statisticGrid,
      children: [
        // 已同步卡片数
        StatisticItem(
          label: '已同步卡片',
          value: SyncDialogFormatters.formatCardCount(statistics.syncedCards),
          icon: Icons.style,
        ),
        // 同步数据大小
        StatisticItem(
          label: '同步数据大小',
          value: SyncDialogFormatters.formatBytes(statistics.syncedDataSize),
          icon: Icons.storage,
        ),
        // 成功次数
        StatisticItem(
          label: '成功次数',
          value: '${statistics.successfulSyncs} 次',
          icon: Icons.check_circle_outline,
        ),
        // 失败次数
        StatisticItem(
          label: '失败次数',
          value: '${statistics.failedSyncs} 次',
          icon: Icons.error_outline,
        ),
      ],
    );
  }
}
