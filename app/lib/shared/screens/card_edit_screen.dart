import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/card_provider.dart';
import '../providers/service_provider.dart'; 
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
    // 不在 initState 中使用 Provider
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCard();
  }

  /// 加载卡片数据
  Future<void> _loadCard() async {
    if (widget.cardId == null) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      // 使用异步方式获取卡片服务，避免在 initState 中使用 Provider
      final cardService = await ref.read(cardServiceProvider.future);
      
      // 根据 ID 获取卡片
      final card = await cardService.getCardById(widget.cardId!);
      
      if (card != null && mounted) {
        setState(() {
          _card = card;
          _titleController.text = card.title;
          _contentController.text = card.content;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      // 处理加载过程中的错误
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载卡片失败: $e')),
        );
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
          _contentController.text
        );
      } else {
        // 创建新卡片
        await notifier.createCard(
          _titleController.text,
          _contentController.text
        );
      }
      if (mounted) {
        // 显示成功消息
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
        // 返回卡片列表页面
        context.go('/cards');
      }
    } catch (e) {
      // 显示错误消息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
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
