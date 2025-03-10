import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/domain/models/card.dart' as domain;
import '../providers/card_provider.dart';

/// 桌面端添加/编辑卡片页面
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
        centerTitle: false,
        actions: [
          // 取消按钮
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('取消'),
          ),
          const SizedBox(width: 8),
          // 保存按钮
          FilledButton(
            onPressed: _saveCard,
            child: const Text('保存'),
          ),
          const SizedBox(width: 24),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题输入框
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: '标题',
                        hintText: '请输入卡片标题',
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
                    const SizedBox(height: 24),
                    // 内容输入框
                    Expanded(
                      child: TextFormField(
                        controller: _contentController,
                        decoration: const InputDecoration(
                          labelText: '内容',
                          hintText: '请输入卡片内容',
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
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
      ref.read(cardListProvider.notifier).addCard(title, content);
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
