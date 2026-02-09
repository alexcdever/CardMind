import 'dart:async';

import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:flutter/material.dart';

/// 移动端全屏笔记编辑器
///
/// 提供沉浸式的全屏编辑体验，包含：
/// - 自动保存机制（1秒防抖）
/// - 新建和编辑两种模式
/// - 确认对话框防止数据丢失
/// - 简化功能，专注于标题和内容编辑
///
/// 参考规格: openspec/specs/features/card_list/note_editor_fullscreen.md
class NoteEditorFullscreen extends StatefulWidget {
  const NoteEditorFullscreen({
    super.key,
    this.card,
    String? currentPeerId,
    @Deprecated('use currentPeerId') String? currentDevice,
    this.currentPoolId,
    required this.isOpen,
    required this.onClose,
    required this.onSave,
  }) : currentPeerId = currentPeerId ?? currentDevice ?? '';

  /// 卡片数据，null 表示新建模式，非 null 表示编辑模式
  final bridge.Card? card;

  /// 当前设备标识
  final String currentPeerId;

  /// 当前数据池 ID（未加入则为 null）
  final String? currentPoolId;

  /// 是否打开编辑器
  final bool isOpen;

  /// 关闭回调
  final VoidCallback onClose;

  /// 保存回调
  final void Function(bridge.Card card) onSave;

  @override
  State<NoteEditorFullscreen> createState() => _NoteEditorFullscreenState();
}

class _NoteEditorFullscreenState extends State<NoteEditorFullscreen>
    with SingleTickerProviderStateMixin {
  // 文本控制器
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  // 自动保存定时器
  Timer? _autoSaveTimer;

  // 状态标记
  bool _hasUnsavedChanges = false;
  bool _isAutoSaving = false;
  bool _isSaving = false;

  // 原始值（用于检测更改）
  String _originalTitle = '';
  String _originalContent = '';

  // 动画控制器
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // 初始化动画控制器
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

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

    // 如果编辑器打开，播放动画
    if (widget.isOpen) {
      _animationController.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 确保动画状态与 isOpen 同步
    if (widget.isOpen &&
        _animationController.status == AnimationStatus.dismissed) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(NoteEditorFullscreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 处理 isOpen 状态变化
    if (widget.isOpen && !oldWidget.isOpen) {
      _animationController.forward();
    } else if (!widget.isOpen && oldWidget.isOpen) {
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    // 取消自动保存定时器
    _autoSaveTimer?.cancel();

    // 释放控制器
    _titleController.dispose();
    _contentController.dispose();
    _animationController.dispose();

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

    // 触发自动保存
    _triggerAutoSave();
  }

  /// 触发自动保存（防抖）
  void _triggerAutoSave() {
    // 取消之前的定时器
    _autoSaveTimer?.cancel();

    // 设置新的定时器（1 秒延迟）
    setState(() {
      _isAutoSaving = true;
    });

    _autoSaveTimer = Timer(const Duration(seconds: 1), _performAutoSave);
  }

  /// 执行自动保存
  void _performAutoSave() {
    // 检查内容是否为空
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      // 空内容不保存
      setState(() {
        _isAutoSaving = false;
      });
      return;
    }

    // 执行保存
    _saveCard();

    // 更新原始值
    _originalTitle = _titleController.text;
    _originalContent = _contentController.text;

    // 清除未保存更改标记
    setState(() {
      _hasUnsavedChanges = false;
      _isAutoSaving = false;
    });
  }

  /// 保存卡片
  void _saveCard() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

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
        ownerType: widget.card!.ownerType,
        poolId: widget.card!.poolId,
        lastEditPeer: widget.currentPeerId,
      );
      widget.onSave(updatedCard);
    } else {
      // 新建模式：创建新卡片
      // 注意：这里需要生成 UUID，实际实现中应该调用 Rust 层的 API
      final poolId = widget.currentPoolId;
      final ownerType =
          poolId == null ? bridge.OwnerType.local : bridge.OwnerType.pool;
      final newCard = bridge.Card(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // 临时 ID
        title: finalTitle,
        content: content,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        deleted: false,
        ownerType: ownerType,
        poolId: poolId,
        lastEditPeer: widget.currentPeerId,
      );
      widget.onSave(newCard);
    }
  }

  /// 处理完成按钮点击
  Future<void> _handleComplete() async {
    if (_isSaving) return; // 防止重复点击

    setState(() {
      _isSaving = true;
    });

    // 取消自动保存定时器
    _autoSaveTimer?.cancel();

    // 验证内容
    final content = _contentController.text.trim();
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

    // 保存卡片
    _saveCard();

    // 更新原始值
    _originalTitle = _titleController.text;
    _originalContent = _contentController.text;

    setState(() {
      _hasUnsavedChanges = false;
      _isSaving = false;
    });

    // 关闭编辑器
    widget.onClose();
  }

  /// 处理关闭按钮点击
  Future<void> _handleClose() async {
    // 检查是否有未保存的更改
    final hasChanges = _hasUnsavedChanges || _isAutoSaving;

    // 新建模式下，如果内容为空，直接关闭
    if (widget.card == null && _contentController.text.trim().isEmpty) {
      widget.onClose();
      return;
    }

    if (!hasChanges) {
      // 没有未保存的更改，直接关闭
      widget.onClose();
      return;
    }

    // 有未保存的更改，显示确认对话框
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const UnsavedChangesDialog(),
    );

    if (!mounted) return;

    switch (result) {
      case 'save':
        // 保存并关闭
        await _handleSaveAndClose();
        break;
      case 'discard':
        // 放弃更改
        widget.onClose();
        break;
      case 'cancel':
      default:
        // 取消，继续编辑
        break;
    }
  }

  /// 保存并关闭
  Future<void> _handleSaveAndClose() async {
    // 验证内容
    final content = _contentController.text.trim();
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
      return;
    }

    // 保存卡片
    _saveCard();

    // 关闭编辑器
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // 工具栏
              _buildToolbar(context),

              // 编辑区域
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题输入框
                      _buildTitleInput(context),

                      // 分隔线
                      const Divider(),

                      // 内容输入框
                      _buildContentInput(context),

                      // 元数据区域（仅编辑模式）
                      if (widget.card != null) ...[
                        const Divider(),
                        _buildMetadata(context),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建工具栏
  Widget _buildToolbar(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      label: '编辑器工具栏',
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor.withValues(alpha: 0.95),
          border: Border(
            bottom: BorderSide(color: theme.dividerColor, width: 1),
          ),
        ),
        child: Row(
          children: [
            // 关闭按钮
            Semantics(
              button: true,
              label: '关闭编辑器',
              hint: '关闭当前笔记编辑器',
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _handleClose,
                tooltip: '关闭',
              ),
            ),

            const Spacer(),

            // 自动保存状态
            Semantics(
              label: '自动保存已启用',
              readOnly: true,
              child: Text(
                '自动保存',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // 完成按钮
            Semantics(
              button: true,
              label: '完成编辑',
              hint: '保存笔记并关闭编辑器',
              enabled: !_isSaving,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _handleComplete,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('完成'),
              ),
            ),

            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  /// 构建标题输入框
  Widget _buildTitleInput(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      textField: true,
      label: '笔记标题',
      hint: '输入笔记标题',
      child: TextField(
        controller: _titleController,
        decoration: const InputDecoration(
          hintText: '笔记标题',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        maxLines: null,
      ),
    );
  }

  /// 构建内容输入框
  Widget _buildContentInput(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Semantics(
      textField: true,
      label: '笔记内容',
      hint: '输入笔记内容',
      multiline: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: screenHeight * 0.6, // 60vh
        ),
        child: TextField(
          controller: _contentController,
          decoration: const InputDecoration(
            hintText: '开始写笔记...',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          style: theme.textTheme.bodyLarge,
          maxLines: null,
          keyboardType: TextInputType.multiline,
        ),
      ),
    );
  }

  /// 构建元数据区域
  Widget _buildMetadata(BuildContext context) {
    final theme = Theme.of(context);
    final card = widget.card!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '创建时间: ${_formatDate(card.createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '更新时间: ${_formatDate(card.updatedAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '最后编辑节点: ${card.lastEditPeer}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化日期
  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}/${date.month}/${date.day} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}:'
        '${date.second.toString().padLeft(2, '0')}';
  }
}

/// 未保存更改确认对话框
class UnsavedChangesDialog extends StatelessWidget {
  const UnsavedChangesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      namesRoute: true,
      scopesRoute: true,
      explicitChildNodes: true,
      label: '未保存更改确认对话框',
      child: AlertDialog(
        title: const Text('有未保存的更改'),
        content: const Text('是否保存更改？'),
        actions: [
          // 取消按钮
          Semantics(
            button: true,
            label: '取消',
            hint: '返回继续编辑',
            child: TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: const Text('取消'),
            ),
          ),

          // 放弃更改按钮
          Semantics(
            button: true,
            label: '放弃更改',
            hint: '放弃所有未保存的更改并关闭',
            child: TextButton(
              onPressed: () => Navigator.of(context).pop('discard'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('放弃更改'),
            ),
          ),

          // 保存并关闭按钮
          Semantics(
            button: true,
            label: '保存并关闭',
            hint: '保存更改并关闭编辑器',
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop('save'),
              child: const Text('保存并关闭'),
            ),
          ),
        ],
      ),
    );
  }
}
