import 'dart:async';

import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:flutter/material.dart';

/// 移动端全屏笔记编辑器
///
/// 提供沉浸式编辑体验，包含：
/// - 自动保存草稿
/// - 键盘优化
class FullscreenEditor extends StatefulWidget {
  const FullscreenEditor({
    super.key,
    required this.card,
    required this.currentPeerId,
    required this.onSave,
    required this.onCancel,
  });

  final bridge.Card card;
  final String currentPeerId;
  final void Function(bridge.Card) onSave;
  final VoidCallback onCancel;

  @override
  State<FullscreenEditor> createState() => _FullscreenEditorState();
}

class _FullscreenEditorState extends State<FullscreenEditor> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.card.title);
    _contentController = TextEditingController(text: widget.card.content);

    // 监听输入变化，触发自动保存
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
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
      ownerType: widget.card.ownerType,
      poolId: widget.card.poolId,
      lastEditPeer: widget.currentPeerId,
    );
    widget.onSave(updatedCard);
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

              // 元数据
              Text(
                '创建时间: ${_formatDate(widget.card.createdAt)}',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                '最后编辑节点: ${widget.card.lastEditPeer}',
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
