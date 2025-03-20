import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../shared/providers/card_provider.dart';

/// 桌面端卡片编辑界面
class DesktopCardEditScreen extends ConsumerStatefulWidget {
  /// 卡片ID，如果为null则表示新建卡片
  final int? cardId;

  /// 构造函数
  const DesktopCardEditScreen({super.key, this.cardId});

  @override
  ConsumerState<DesktopCardEditScreen> createState() => _DesktopCardEditScreenState();
}

class _DesktopCardEditScreenState extends ConsumerState<DesktopCardEditScreen> {
  /// 标题控制器
  final _titleController = TextEditingController();
  /// 内容控制器
  final _contentController = TextEditingController();
  /// 是否处于预览模式
  bool _isPreview = false;

  @override
  void initState() {
    super.initState();
    _loadCard();
  }

  /// 加载卡片数据
  Future<void> _loadCard() async {
    if (widget.cardId != null) {
      final card = await ref.read(cardServiceProvider).getCardById(widget.cardId!);
      if (card != null) {
        setState(() {
          _titleController.text = card.title;
          _contentController.text = card.content;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// 构建编辑器界面
  Widget _buildEditor() {
    return Column(
      children: [
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: '标题',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TextField(
            controller: _contentController,
            decoration: const InputDecoration(
              labelText: '内容（支持 Markdown）',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: null,
            expands: true,
          ),
        ),
      ],
    );
  }

  /// 构建预览界面
  Widget _buildPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _titleController.text.trim(),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const Divider(),
        Expanded(
          child: Markdown(
            data: _contentController.text.trim(),
            selectable: true,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cardId == null ? '新建卡片' : '编辑卡片'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/cards'),
        ),
        actions: [
          // 预览/编辑切换按钮
          IconButton(
            icon: Icon(_isPreview ? Icons.edit : Icons.preview),
            tooltip: _isPreview ? '编辑' : '预览',
            onPressed: () {
              setState(() {
                _isPreview = !_isPreview;
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: _isPreview ? _buildPreview() : _buildEditor(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveCard,
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  /// 保存卡片
  Future<void> _saveCard() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标题和内容不能为空')),
      );
      return;
    }

    try {
      final notifier = ref.read(cardListProvider.notifier);
      if (widget.cardId != null) {
        await notifier.updateCard(widget.cardId!, title, content);
      } else {
        await notifier.addCard(title, content);
      }
      if (mounted) {
        context.go('/cards');
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
