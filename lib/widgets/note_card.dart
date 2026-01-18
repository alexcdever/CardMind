import 'package:flutter/material.dart';
import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:cardmind/adaptive/platform_detector.dart';

/// 现代化笔记卡片组件
///
/// 支持：
/// - 桌面端：内联编辑模式
/// - 移动端：点击打开全屏编辑器
/// - 标签管理
/// - 协作编辑标识
class NoteCard extends StatefulWidget {
  const NoteCard({
    super.key,
    required this.card,
    required this.currentDevice,
    required this.onUpdate,
    required this.onDelete,
    this.onTap,
  });

  final bridge.Card card;
  final String currentDevice;
  final Function(bridge.Card) onUpdate;
  final Function(String) onDelete;
  final VoidCallback? onTap;

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  bool _isEditing = false;
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  final TextEditingController _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.card.title);
    _contentController = TextEditingController(text: widget.card.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final updatedCard = bridge.Card(
      id: widget.card.id,
      title: _titleController.text,
      content: _contentController.text,
      createdAt: widget.card.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      deleted: widget.card.deleted,
      tags: widget.card.tags,
      lastEditDevice: widget.currentDevice,
    );
    widget.onUpdate(updatedCard);
    setState(() {
      _isEditing = false;
    });
  }

  void _handleCancel() {
    _titleController.text = widget.card.title;
    _contentController.text = widget.card.content;
    setState(() {
      _isEditing = false;
    });
  }

  void _handleAddTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !widget.card.tags.contains(tag)) {
      final updatedCard = bridge.Card(
        id: widget.card.id,
        title: widget.card.title,
        content: widget.card.content,
        createdAt: widget.card.createdAt,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        deleted: widget.card.deleted,
        tags: [...widget.card.tags, tag],
        lastEditDevice: widget.currentDevice,
      );
      widget.onUpdate(updatedCard);
      _tagController.clear();
    }
  }

  void _handleRemoveTag(String tag) {
    final updatedCard = bridge.Card(
      id: widget.card.id,
      title: widget.card.title,
      content: widget.card.content,
      createdAt: widget.card.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      deleted: widget.card.deleted,
      tags: widget.card.tags.where((t) => t != tag).toList(),
      lastEditDevice: widget.currentDevice,
    );
    widget.onUpdate(updatedCard);
  }

  bool get _isEditedByOther {
    return widget.card.lastEditDevice != null &&
        widget.card.lastEditDevice != widget.currentDevice;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = PlatformDetector.isMobile;

    return Card(
      elevation: _isEditing ? 4 : 2,
      child: InkWell(
        onTap: () {
          if (isMobile && widget.onTap != null) {
            widget.onTap!();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Expanded(
                    child: _isEditing
                        ? TextField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              hintText: '笔记标题',
                              border: OutlineInputBorder(),
                            ),
                            autofocus: true,
                          )
                        : Text(
                            widget.card.title.isEmpty
                                ? '无标题笔记'
                                : widget.card.title,
                            style: theme.textTheme.titleLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                  const SizedBox(width: 8),
                  if (_isEditedByOther)
                    Tooltip(
                      message: '最后编辑: ${widget.card.lastEditDevice}',
                      child: Icon(
                        Icons.people,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  if (_isEditing) ...[
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: _handleSave,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: _handleCancel,
                    ),
                  ] else if (!isMobile)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          setState(() {
                            _isEditing = true;
                          });
                        } else if (value == 'delete') {
                          widget.onDelete(widget.card.id);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('编辑'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('删除', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // 内容
              _isEditing
                  ? TextField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        hintText: '笔记内容',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                    )
                  : Text(
                      widget.card.content.isEmpty ? '空笔记' : widget.card.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
              const SizedBox(height: 12),

              // 标签
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...widget.card.tags.map(
                    (tag) => Chip(
                      label: Text(tag),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _handleRemoveTag(tag),
                    ),
                  ),
                  if (_isEditing)
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _tagController,
                        decoration: const InputDecoration(
                          hintText: '添加标签',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        onSubmitted: (_) => _handleAddTag(),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // 元数据
              Text(
                '${widget.card.lastEditDevice != null ? '设备: ${widget.card.lastEditDevice} · ' : ''}'
                '更新: ${_formatDate(widget.card.updatedAt)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} 分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} 小时前';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
}
