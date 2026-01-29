import 'package:flutter/material.dart';

/// 导出确认对话框
class ExportConfirmDialog extends StatelessWidget {
  /// 卡片数量
  final int cardCount;

  const ExportConfirmDialog({
    super.key,
    required this.cardCount,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Export data confirmation dialog',
      child: AlertDialog(
        title: const Text('导出数据'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: 'Will export $cardCount cards',
              child: Text('即将导出 $cardCount 张卡片'),
            ),
            const SizedBox(height: 16),
            const Text(
              '导出的文件将包含所有卡片数据（包括已删除的卡片）。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          Semantics(
            label: 'Cancel export',
            button: true,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
          ),
          Semantics(
            label: 'Confirm export',
            button: true,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('导出'),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示对话框
  static Future<bool> show(BuildContext context, int cardCount) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ExportConfirmDialog(cardCount: cardCount),
    );
    return result ?? false;
  }
}
