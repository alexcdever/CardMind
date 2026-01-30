/// 统计项组件
library;

import 'package:flutter/material.dart';
import '../utils/sync_dialog_constants.dart';

/// 统计项组件
///
/// 用于显示单个统计数据（标签 + 数值）
class StatisticItem extends StatelessWidget {
  const StatisticItem({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  /// 标签
  final String label;

  /// 数值
  final String value;

  /// 图标（可选）
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      value: value,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: SyncDialogColor.textSecondary),
                const SizedBox(width: 4),
              ],
              Text(label, style: SyncDialogTextStyle.caption),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: SyncDialogTextStyle.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
