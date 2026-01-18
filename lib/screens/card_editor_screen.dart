import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/card_editor_state.dart';
import '../adaptive/layouts/adaptive_scaffold.dart';
import '../adaptive/platform_detector.dart';
import '../adaptive/layouts/adaptive_padding.dart';

/// Card Editor Screen
///
/// 规格编号: SP-FLUT-009
/// 卡片编辑器界面，支持：
/// - 标题和内容输入
/// - 自动保存（500ms debounce）
/// - 手动保存（完成按钮）
/// - 错误处理和重试
/// - 返回确认对话框
class CardEditorScreen extends StatefulWidget {
  const CardEditorScreen({super.key});

  @override
  State<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _titleFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

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
    super.dispose();
  }

  // ========================================
  // 任务 4.7: 实现返回确认对话框
  // ========================================

  Future<bool> _onWillPop(CardEditorState state) async {
    // 如果没有未保存的更改，直接返回
    if (!state.hasUnsavedChanges) {
      return true;
    }

    // 显示确认对话框
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
            child: const Text('确定'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // ========================================
  // 任务 4.2: 实现 AppBar
  // ========================================

  @override
  Widget build(BuildContext context) {
    // 尝试从父级获取 CardEditorState，如果没有则创建新的
    final existingState = context.read<CardEditorState?>();

    if (existingState != null) {
      // 如果已经有 Provider，直接使用
      return Consumer<CardEditorState>(
        builder: (context, state, _) {
          return _buildEditor(context, state);
        },
      );
    }

    // 如果没有 Provider，创建新的
    return ChangeNotifierProvider(
      create: (_) => CardEditorState(),
      child: Consumer<CardEditorState>(
        builder: (context, state, _) {
          return _buildEditor(context, state);
        },
      ),
    );
  }

  Widget _buildEditor(BuildContext context, CardEditorState state) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final canPop = await _onWillPop(state);
        if (canPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: AdaptiveScaffold(
        appBar: AppBar(
          title: const Text('新建卡片'),
          leading: IconButton(
            key: const Key('back_button'),
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final canPop = await _onWillPop(state);
              if (canPop && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            // 任务 4.6: 实现完成按钮状态（启用/禁用）
            TextButton(
              key: const Key('complete_button'),
              onPressed: state.isTitleValid
                  ? () => _onCompletePressed(context, state)
                  : null,
              child: Text(
                PlatformDetector.isMobile ? '完成' : '保存',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 任务 4.5: 实现自动保存指示器
            _buildSaveIndicator(state),

            // 任务 4.3 和 4.4: 标题和内容输入框
            Padding(
              padding: AdaptivePadding.medium,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 任务 4.3: 实现标题输入框
                  _buildTitleField(state),
                  const SizedBox(height: 16),
                  // 任务 4.4: 实现内容输入框
                  _buildContentField(state),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // 任务 4.3: 实现标题输入框（TextField with controller）
  // ========================================

  Widget _buildTitleField(CardEditorState state) {
    return TextField(
      key: const Key('title_field'),
      controller: _titleController,
      focusNode: _titleFocusNode,
      decoration: const InputDecoration(
        hintText: '卡片标题',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      maxLength: 200,
      onChanged: (value) {
        state.updateTitle(value);
      },
    );
  }

  // ========================================
  // 任务 4.4: 实现内容输入框（多行 TextField）
  // ========================================

  Widget _buildContentField(CardEditorState state) {
    return TextField(
      key: const Key('content_field'),
      controller: _contentController,
      decoration: const InputDecoration(
        hintText: '输入内容（支持 Markdown）',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      style: const TextStyle(fontSize: 16),
      maxLines: null,
      minLines: 10,
      keyboardType: TextInputType.multiline,
      onChanged: (value) {
        state.updateContent(value);
      },
    );
  }

  // ========================================
  // 任务 4.5: 实现自动保存指示器
  // ========================================

  Widget _buildSaveIndicator(CardEditorState state) {
    if (state.isSaving) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: Colors.blue.shade50,
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('自动保存中...', style: TextStyle(fontSize: 14)),
          ],
        ),
      );
    }

    if (state.showSuccessIndicator) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: Colors.green.shade50,
        child: const Row(
          children: [
            Icon(Icons.check_circle, size: 16, color: Colors.green),
            SizedBox(width: 8),
            Text('已保存', style: TextStyle(fontSize: 14, color: Colors.green)),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ========================================
  // 完成按钮处理
  // ========================================

  Future<void> _onCompletePressed(
    BuildContext context,
    CardEditorState state,
  ) async {
    final navigator = Navigator.of(context);
    final success = await state.manualSave();

    if (success && mounted) {
      // 保存成功，返回主页
      navigator.pop();
    }
    // 如果失败，错误信息会通过 state.errorMessage 显示
  }
}
