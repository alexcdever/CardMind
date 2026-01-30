import 'package:flutter/material.dart';
import '../../bridge/api/loro_export.dart';

/// 导入确认对话框
class ImportConfirmDialog extends StatelessWidget {
  const ImportConfirmDialog({super.key, required this.preview});

  /// 文件预览信息
  final FilePreview preview;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Import data confirmation dialog',
      child: AlertDialog(
        title: const Text('导入数据'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: 'File contains ${preview.cardCount} cards',
              child: Text('文件包含 ${preview.cardCount} 张卡片'),
            ),
            const SizedBox(height: 8),
            Text(
              '文件大小: ${_formatFileSize(preview.fileSize)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              '导入将合并数据，不会覆盖现有卡片。如果存在冲突，将保留最新的版本。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          Semantics(
            label: 'Cancel import',
            button: true,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
          ),
          Semantics(
            label: 'Confirm import',
            button: true,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('导入'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(BigInt bytes) {
    final bytesInt = bytes.toInt();
    if (bytesInt < 1024) {
      return '$bytesInt B';
    } else if (bytesInt < 1024 * 1024) {
      return '${(bytesInt / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytesInt / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// 显示对话框
  static Future<bool> show(BuildContext context, FilePreview preview) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ImportConfirmDialog(preview: preview),
    );
    return result ?? false;
  }
}
