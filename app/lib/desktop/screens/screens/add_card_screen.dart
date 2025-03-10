import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../domain/models/card.dart' as domain;
import '../providers/card_provider.dart';

class AddCardScreen extends ConsumerStatefulWidget {
  final domain.Card? card;

  const AddCardScreen({super.key, this.card});

  @override
  ConsumerState<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends ConsumerState<AddCardScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _isPreview = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.card?.title);
    _contentController = TextEditingController(text: widget.card?.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveCard() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入卡片标题')),
      );
      return;
    }

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入卡片内容')),
      );
      return;
    }

    if (widget.card != null) {
      final updatedCard = widget.card!.copyWith(
        title: title,
        content: content,
        updatedAt: DateTime.now(),
      );
      ref.read(cardListProvider.notifier).updateCard(updatedCard);
    } else {
      ref.read(cardListProvider.notifier).addCard(title, content);
    }

    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.card == null ? '添加卡片' : '编辑卡片'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: Icon(_isPreview ? Icons.edit : Icons.preview),
            onPressed: () => setState(() => _isPreview = !_isPreview),
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveCard,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '标题',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: '输入卡片标题...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '内容',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (_isPreview)
                          Text(
                            '预览模式',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isPreview)
                      MarkdownBody(
                        data: _contentController.text,
                        selectable: true,
                      )
                    else
                      TextField(
                        controller: _contentController,
                        decoration: const InputDecoration(
                          hintText: '输入卡片内容（支持Markdown格式）...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 10,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
