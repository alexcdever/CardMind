import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/domain/models/card.dart' as domain;
import '../providers/card_provider.dart';

/// 移动端添加/编辑卡片页面
class AddCardScreen extends ConsumerStatefulWidget {
  /// 要编辑的卡片，如果为 null 则表示新建卡片
  final domain.Card? card;

  const AddCardScreen({super.key, this.card});

  @override
  ConsumerState<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends ConsumerState<AddCardScreen> {
  // 标题控制器
  late final TextEditingController _titleController;
  // 内容控制器
  late final TextEditingController _contentController;
  // 表单 key
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // 初始化控制器
    _titleController = TextEditingController(text: widget.card?.title);
    _contentController = TextEditingController(text: widget.card?.content);
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
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveCard,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 标题输入框
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入标题';
                }
                return null;
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            // 内容输入框
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: '内容',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入内容';
                }
                return null;
              },
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
  void _saveCard() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (widget.card == null) {
      // 创建新卡片
      ref.read(cardListProvider.notifier).createCard(title, content);
    } else {
      // 更新现有卡片
      final updatedCard = domain.Card(
        id: widget.card!.id,
        title: title,
        content: content,
        createdAt: widget.card!.createdAt,
        updatedAt: DateTime.now(),
      );
      ref.read(cardListProvider.notifier).updateCard(updatedCard);
    }

    // 返回列表页
    context.go('/');
  }
}
