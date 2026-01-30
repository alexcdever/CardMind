/// 同步历史区域组件
library;

import 'package:cardmind/bridge/api/sync.dart' as api;
import 'package:flutter/material.dart';

import '../components/empty_state_widget.dart';
import '../components/sync_history_item.dart';
import '../utils/sync_dialog_constants.dart';

/// 同步历史区域
///
/// 显示最近的同步历史记录（最多 20 条）
class SyncHistorySection extends StatelessWidget {
  const SyncHistorySection({
    super.key,
    required this.history,
    this.isLoading = false,
    this.error,
    this.onRetry,
  });

  /// 历史记录列表
  final List<api.SyncHistoryEvent> history;

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
          child: const Text('同步历史', style: SyncDialogTextStyle.sectionTitle),
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
        else if (history.isEmpty)
          const EmptyStateWidget(icon: Icons.history, message: '暂无同步历史记录')
        else
          _buildHistoryList(),
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
              color: SyncDialogColor.error.withOpacity(0.5),
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

  /// 构建历史列表
  Widget _buildHistoryList() {
    // 限制显示最近 20 条记录
    final limitedHistory = history
        .take(SyncDialogLimit.historyMaxCount)
        .toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: limitedHistory.length,
      separatorBuilder: (context, index) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        return SyncHistoryItem(event: limitedHistory[index]);
      },
    );
  }
}
