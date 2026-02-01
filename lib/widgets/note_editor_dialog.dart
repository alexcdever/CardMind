import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:flutter/material.dart';

/// 桌面端模态对话框笔记编辑器
///
/// 提供桌面端优化的编辑体验，包含：
/// - 模态对话框形式（800x600）
/// - 标题和内容编辑区域
/// - 手动保存按钮（无快捷键）
/// - 关闭时检测未保存的修改，提示确认
/// - 支持新建模式（card 为 null）和编辑模式（card 非 null）
class NoteEditorDialog extends StatefulWidget {
  const NoteEditorDialog({
    super.key,
    this.card,
    required this.currentDevice,
    required this.onSave,
    required this.onCancel,
  });

  /// 要编辑的卡片，null 表示新建模式
  final bridge.Card? card;

  /// 当前设备标识
  final String currentDevice;

  /// 保存回调
  final void Function(bridge.Card card) onSave;

  /// 取消回调
  final VoidCallback onCancel;

  @override
  State<NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<NoteEditorDialog> {
  // 文本控制器
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  // 状态标记
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;

  // 原始值（用于检测更改）
  String _originalTitle = '';
  String _originalContent = '';

  @override
  void initState() {
    super.initState();

    // 初始化文本控制器
    if (widget.card != null) {
      // 编辑模式：加载现有数据
      _titleController = TextEditingController(text: widget.card!.title);
      _contentController = TextEditingController(text: widget.card!.content);
      _originalTitle = widget.card!.title;
      _originalContent = widget.card!.content;
    } else {
      // 新建模式：空内容
      _titleController = TextEditingController();
      _contentController = TextEditingController();
    }

    // 监听输入变化
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    // 释放控制器
    _titleController.dispose();
    _contentController.dispose();

    super.dispose();
  }

  /// 文本变化处理
  void _onTextChanged() {
    // 检测是否有未保存的更改
    final hasChanges =
        _titleController.text != _originalTitle ||
        _contentController.text != _originalContent;

    if (hasChanges != _hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = hasChanges;
      });
    }
  }

  /// 处理保存按钮点击
  void _handleSave() {
    if (_isSaving) return; // 防止重复点击

    setState(() {
      _isSaving = true;
    });

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // 验证内容不能为空
    if (content.isEmpty) {
      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('内容不能为空'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      setState(() {
        _isSaving = false;
      });
      return;
    }

    // 处理空标题
    final finalTitle = title.isEmpty ? '无标题笔记' : title;

    if (widget.card != null) {
      // 编辑模式：更新现有卡片
      final updatedCard = bridge.Card(
        id: widget.card!.id,
        title: finalTitle,
        content: content,
        createdAt: widget.card!.createdAt,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        deleted: widget.card!.deleted,
        tags: widget.card!.tags,
        lastEditDevice: widget.currentDevice,
      );

      // 调用保存回调
      widget.onSave(updatedCard);
    } else {
      // 新建模式：创建新卡片
      final now = DateTime.now().millisecondsSinceEpoch;
      final newCard = bridge.Card(
        id: now.toString(), // 临时 ID，实际应该由后端生成
        title: finalTitle,
        content: content,
        createdAt: now,
        updatedAt: now,
        deleted: false,
        tags: [],
        lastEditDevice: widget.currentDevice,
      );

      // 调用保存回调
      widget.onSave(newCard);
    }

    setState(() {
      _isSaving = false;
    });

    // 关闭对话框
    Navigator.of(context).pop();
  }

  /// 处理取消按钮点击
  Future<void> _handleCancel() async {
    // 检查是否有未保存的更改
    if (!_hasUnsavedChanges) {
      // 没有未保存的更改，直接关闭
      widget.onCancel();
      Navigator.of(context).pop();
      return;
    }

    // 有未保存的更改，显示确认对话框
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('未保存的修改'),
        content: const Text('你有未保存的修改，确定要关闭吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('不保存并关闭'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (result == true) {
      // 用户确认放弃更改
      widget.onCancel();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Row(
              children: [
                Text(
                  '编辑笔记',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _handleCancel,
                  tooltip: '关闭',
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // 标题输入框
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              style: theme.textTheme.titleMedium,
            ),

            const SizedBox(height: 16),

            // 内容输入框
            Expanded(
              child: TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: '内容',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                  alignLabelWithHint: true,
                ),
                style: theme.textTheme.bodyLarge,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),

            const SizedBox(height: 16),

            // 元数据区域（仅编辑模式）
            if (widget.card != null)
              Text(
                '最后编辑: ${_formatDate(widget.card!.updatedAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // 按钮栏
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _handleCancel, child: const Text('取消')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 格式化日期
  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}/${date.month}/${date.day} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
