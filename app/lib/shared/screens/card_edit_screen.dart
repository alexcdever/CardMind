import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/card.dart' as domain;  // 使用 domain 前缀避免命名冲突
import '../services/card_service.dart';

/// 卡片编辑界面
/// 用于创建新卡片或编辑现有卡片
class CardEditScreen extends ConsumerStatefulWidget {
  /// 要编辑的卡片，如果为 null 则表示创建新卡片
  final domain.Card? card;

  const CardEditScreen({super.key, this.card});

  @override
  ConsumerState<CardEditScreen> createState() => _CardEditScreenState();
}

class _CardEditScreenState extends ConsumerState<CardEditScreen> {
  /// 标题控制器
  late final TextEditingController _titleController;
  
  /// 内容控制器
  late final TextEditingController _contentController;
  
  /// 卡片服务实例
  final _cardService = CardService();

  @override
  void initState() {
    super.initState();
    // 初始化控制器
    _titleController = TextEditingController(text: widget.card?.title ?? '');
    _contentController = TextEditingController(text: widget.card?.content ?? '');
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.card == null ? '新建卡片' : '编辑卡片'),
        actions: [
          // 保存按钮
          TextButton(
            onPressed: _saveCard,
            child: const Text('保存'),
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
                border: OutlineInputBorder(),
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 16),
            // 内容输入框
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: '内容',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: null,
              minLines: 10,
              textAlignVertical: TextAlignVertical.top,
            ),
          ],
        ),
      ),
    );
  }

  /// 保存卡片
  void _saveCard() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // 验证输入
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入标题')),
      );
      return;
    }

    try {
      if (widget.card == null) {
        // 创建新卡片
        await _cardService.createCard(title, content);
      } else {
        // 更新现有卡片
        final updatedCard = domain.Card(
          id: widget.card!.id,
          title: title,
          content: content,
          createdAt: widget.card!.createdAt,
          updatedAt: DateTime.now(),
          syncId: widget.card!.syncId,
        );
        await _cardService.updateCard(updatedCard);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    }
  }
}
