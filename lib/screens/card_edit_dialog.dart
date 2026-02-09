import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:flutter/material.dart';

/// 桌面端卡片编辑对话框
///
/// 提供模态对话框形式的编辑体验，包含：
/// - 标题和内容编辑字段
/// - 数据验证
/// - 保存和取消按钮
/// - ESC键关闭支持
/// - 未保存更改确认
class CardEditDialog extends StatefulWidget {
  const CardEditDialog({
    super.key,
    required this.card,
    required this.currentPeerId,
    required this.onSave,
  });

  final bridge.Card card;
  final String currentPeerId;
  final void Function(bridge.Card) onSave;

  @override
  State<CardEditDialog> createState() => _CardEditDialogState();
}

class _CardEditDialogState extends State<CardEditDialog> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late FocusNode _titleFocusNode;
  late FocusNode _contentFocusNode;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.card.title);
    _contentController = TextEditingController(text: widget.card.content);
    _titleFocusNode = FocusNode();
    _contentFocusNode = FocusNode();

    // 监听输入变化
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);

    // 自动聚焦标题字段
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasChanges =
        _titleController.text != widget.card.title ||
        _contentController.text != widget.card.content;

    if (hasChanges != _hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = hasChanges;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃更改？'),
        content: const Text('您有未保存的更改，确定要放弃吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _handleSave() {
    // 验证标题不为空
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标题不能为空'), duration: Duration(seconds: 2)),
      );
      return;
    }

    final updatedCard = bridge.Card(
      id: widget.card.id,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      createdAt: widget.card.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      deleted: widget.card.deleted,
      ownerType: widget.card.ownerType,
      poolId: widget.card.poolId,
      lastEditPeer: widget.currentPeerId,
    );

    widget.onSave(updatedCard);
    Navigator.of(context).pop();
  }

  void _handleCancel() async {
    final canPop = await _onWillPop();
    if (canPop && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final canPop = await _onWillPop();
        if (canPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: screenSize.width * 0.6,
          constraints: BoxConstraints(
            maxWidth: 800,
            maxHeight: screenSize.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 对话框标题栏
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '编辑笔记',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _handleCancel,
                      tooltip: '关闭 (ESC)',
                    ),
                  ],
                ),
              ),

              // 对话框内容区域
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 标题输入框
                      Text(
                        '标题',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _titleController,
                        focusNode: _titleFocusNode,
                        decoration: InputDecoration(
                          hintText: '输入笔记标题',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        style: theme.textTheme.titleMedium,
                        maxLength: 200,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) {
                          _contentFocusNode.requestFocus();
                        },
                      ),
                      const SizedBox(height: 24),

                      // 内容输入框
                      Text(
                        '内容',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _contentController,
                        focusNode: _contentFocusNode,
                        decoration: InputDecoration(
                          hintText: '输入笔记内容（支持 Markdown）',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        style: theme.textTheme.bodyLarge,
                        maxLines: null,
                        minLines: 10,
                        keyboardType: TextInputType.multiline,
                      ),
                    ],
                  ),
                ),
              ),

              // 对话框操作按钮
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(color: theme.dividerColor, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _handleCancel,
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _handleSave,
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
