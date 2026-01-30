/// 空状态组件
library;

import 'package:flutter/material.dart';
import '../utils/sync_dialog_constants.dart';

/// 空状态组件
///
/// 用于显示无数据时的提示信息
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  /// 图标
  final IconData icon;

  /// 提示文本
  final String message;

  /// 可选的操作按钮
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: SyncDialogColor.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: SyncDialogTextStyle.emptyState,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
