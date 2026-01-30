import 'dart:async';

import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:flutter/material.dart';

/// 移动端全屏笔记编辑器
///
/// 提供沉浸式编辑体验，包含：
/// - 自动保存草稿
/// - 标签管理
/// - 键盘优化
class FullscreenEditor extends StatefulWidget {
  const FullscreenEditor({
    super.key,
    required this.card,
    required this.currentDevice,
    required this.onSave,
    required this.onCancel,
  });

  final bridge.Card card;
  final String currentDevice;
  final void Function(bridge.Card) onSave;
  final VoidCallback onCancel;

  @override
  State<FullscreenEditor> createState() => _FullscreenEditorState();
}

class _FullscreenEditorState extends State<FullscreenEditor> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  final TextEditingController _tagController = TextEditingController();
  Timer? _autoSaveTimer;
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.card.title);
    _contentController = TextEditingController(text: widget.card.content);
    _tags = List.from(widget.card.tags);

    // 监听输入变化，触发自动保存
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // 取消之前的定时器
    _autoSaveTimer?.cancel();
    // 2 秒后自动保存草稿
    _autoSaveTimer = Timer(const Duration(seconds: 2), _saveDraft);
  }

  void _saveDraft() {
    // 这里可以保存到本地存储
    debugPrint('自动保存草稿');
  }

  void _handleSave() {
    final updatedCard = bridge.Card(
      id: widget.card.id,
      title: _titleController.text,
      content: _contentController.text,
      createdAt: widget.card.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      deleted: widget.card.deleted,
      tags: _tags,
      lastEditDevice: widget.currentDevice,
    );
    widget.onSave(updatedCard);
  }

  void _handleAddTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
      });
      _tagController.clear();
    }
  }

  void _handleRemoveTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel,
        ),
        title: const Text('编辑笔记'),
        actions: [TextButton(onPressed: _handleSave, child: const Text('保存'))],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题输入框
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: '笔记标题',
                  border: InputBorder.none,
                ),
                style: theme.textTheme.headlineSmall,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
              ),
              const Divider(),
              const SizedBox(height: 8),

              // 内容输入框
              TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  hintText: '开始输入...',
                  border: InputBorder.none,
                ),
                style: theme.textTheme.bodyLarge,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),

              // 标签管理
              Text('标签', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._tags.map(
                    (tag) => Chip(
                      label: Text(tag),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _handleRemoveTag(tag),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _tagController,
                      decoration: InputDecoration(
                        hintText: '添加标签',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add, size: 20),
                          onPressed: _handleAddTag,
                        ),
                      ),
                      onSubmitted: (_) => _handleAddTag(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 元数据
              Text(
                '创建时间: ${_formatDate(widget.card.createdAt)}',
                style: theme.textTheme.bodySmall,
              ),
              if (widget.card.lastEditDevice != null)
                Text(
                  '最后编辑设备: ${widget.card.lastEditDevice}',
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
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
