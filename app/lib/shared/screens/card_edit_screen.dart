import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/card_provider.dart';
import '../services/card_service.dart';
import '../domain/models/card.dart' as domain;

/// 卡片编辑界面
/// 用于创建新卡片或编辑现有卡片
class CardEditScreen extends ConsumerStatefulWidget {
  /// 卡片ID，如果为空则表示新建卡片
  final int? cardId;

  /// 构造函数
  const CardEditScreen({
    super.key,
    this.cardId,
  });

  @override
  ConsumerState<CardEditScreen> createState() => _CardEditScreenState();
}

/// 卡片编辑界面状态
class _CardEditScreenState extends ConsumerState<CardEditScreen> {
  /// 标题控制器
  final _titleController = TextEditingController();
  /// 内容控制器
  final _contentController = TextEditingController();
  /// 是否正在加载
  bool _isLoading = false;
  /// 是否正在保存
  bool _isSaving = false;
  /// 当前编辑的卡片
  domain.Card? _card;

  @override
  void initState() {
    super.initState();
    _loadCard();
  }

  /// 加载卡片数据
  Future<void> _loadCard() async {
    if (widget.cardId == null) return;

    setState(() => _isLoading = true);
    try {
      // 使用 CardService 加载卡片数据
      _card = await CardService.instance.getCardById(widget.cardId!);
      if (_card != null && mounted) {
        setState(() {
          _titleController.text = _card!.title;
          _contentController.text = _card!.content;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 保存卡片
  Future<void> _saveCard() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入标题')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(cardListProvider.notifier);
      if (_card != null) {
        // 更新现有卡片
        await notifier.updateCard(
          _card!.id,
          _titleController.text,
          _contentController.text,
        );
      } else {
        // 创建新卡片
        await notifier.addCard(
          _titleController.text,
          _contentController.text,
        );
      }
      if (mounted) {
        // 返回卡片列表页面
        context.go('/cards');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    // 释放控制器
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cardId == null ? '新建卡片' : '编辑卡片'),
        actions: [
          // 保存按钮
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveCard,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 标题输入框
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                hintText: '请输入卡片标题',
              ),
            ),
            const SizedBox(height: 16),
            // 内容输入框
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: '内容',
                hintText: '请输入卡片内容（支持 Markdown 格式）',
                alignLabelWithHint: true,
              ),
              maxLines: null,
              minLines: 10,
            ),
          ],
        ),
      ),
    );
  }
}
