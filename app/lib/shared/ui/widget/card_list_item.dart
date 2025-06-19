import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// 卡片列表项组件
/// 用于在列表中显示卡片的预览
class CardListItem extends StatelessWidget {
  /// 卡片标题
  final String title;

  /// 卡片内容
  final String content;

  /// 点击卡片时的回调
  final VoidCallback onTap;

  /// 点击编辑按钮时的回调
  final VoidCallback onEdit;

  /// 点击删除按钮时的回调
  final VoidCallback onDelete;

  /// 构造函数
  const CardListItem({
    super.key,
    required this.title,
    required this.content,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 编辑按钮
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: '编辑',
                    onPressed: onEdit,
                  ),
                  // 删除按钮
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: '删除',
                    color: Colors.red,
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              MarkdownBody(
                data: content,
                shrinkWrap: true,
                softLineBreak: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
