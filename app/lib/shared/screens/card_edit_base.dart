import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/card.dart' as domain;
import '../../desktop/providers/card_provider.dart';

/// 卡片编辑基础组件
/// 提供卡片编辑的核心功能和状态管理
class CardEditBase extends ConsumerStatefulWidget {
  /// 要编辑的卡片，如果为 null 则表示新建卡片
  final domain.Card? card;

  /// UI 构建器函数
  /// 允许不同平台提供自己的 UI 实现
  final Widget Function(
    BuildContext context,
    TextEditingController titleController,
    TextEditingController contentController,
    void Function() saveCard,
    bool isValid,
  ) builder;

  /// 保存成功后的回调
  final void Function()? onSaved;

  const CardEditBase({
    super.key,
    this.card,
    required this.builder,
    this.onSaved,
  });

  @override
  ConsumerState<CardEditBase> createState() => _CardEditBaseState();
}

class _CardEditBaseState extends ConsumerState<CardEditBase> {
  /// 标题控制器
  late final TextEditingController _titleController;
  
  /// 内容控制器
  late final TextEditingController _contentController;

  /// 表单是否有效
  bool get _isValid {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    return title.isNotEmpty && content.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    // 初始化控制器
    _titleController = TextEditingController(text: widget.card?.title);
    _contentController = TextEditingController(text: widget.card?.content);

    // 添加监听以触发重建
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    // 移除监听
    _titleController.removeListener(_onTextChanged);
    _contentController.removeListener(_onTextChanged);
    
    // 释放控制器
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// 文本变化时触发重建以更新保存按钮状态
  void _onTextChanged() {
    setState(() {});
  }

  /// 保存卡片
  Future<void> _saveCard() async {
    if (!_isValid) return;

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    try {
      final notifier = ref.read(cardListProvider.notifier);
      if (widget.card != null) {
        // 更新现有卡片
        final updatedCard = widget.card!.copyWith(
          title: title,
          content: content,
          updatedAt: DateTime.now(),
        );
        await notifier.updateCard(updatedCard);
      } else {
        // 创建新卡片
        await notifier.addCard(title, content);
      }

      // 调用保存成功回调
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 使用平台特定的构建器函数构建 UI
    return widget.builder(
      context,
      _titleController,
      _contentController,
      _saveCard,
      _isValid,
    );
  }
}
