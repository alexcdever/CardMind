import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/domain/models/card.dart' as domain;
import '../../shared/screens/card_edit_base.dart';

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
  Widget _buildEditor(TextEditingController titleController, TextEditingController contentController) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题输入框
        TextFormField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: '标题',
            hintText: '请输入卡片标题',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        // 内容输入框
        Expanded(
          child: TextFormField(
            controller: contentController,
            decoration: const InputDecoration(
              labelText: '内容',
              hintText: '请输入卡片内容（支持 Markdown 格式）',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
          ),
        ),
      ],
    );
  }

  /// 构建预览界面
  Widget _buildPreview(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题预览
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const Divider(),
        const SizedBox(height: 16),
        // 内容预览（Markdown）
        Expanded(
          child: Markdown(
            data: content,
            selectable: true,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CardEditBase(
      card: widget.card,
      onSaved: () => context.go('/'),
      builder: (context, titleController, contentController, saveCard, isValid) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.card == null ? '新建卡片' : '编辑卡片'),
            centerTitle: false,
            actions: [
              // 预览/编辑切换按钮
              IconButton(
                icon: Icon(_isPreview ? Icons.edit : Icons.preview),
                tooltip: _isPreview ? '切换到编辑' : '切换到预览',
                onPressed: () => setState(() => _isPreview = !_isPreview),
              ),
              const SizedBox(width: 8),
              // 取消按钮
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              // 保存按钮
              FilledButton(
                onPressed: isValid ? saveCard : null,
                child: const Text('保存'),
              ),
              const SizedBox(width: 24),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _isPreview
                      ? _buildPreview(
                          titleController.text.trim(),
                          contentController.text.trim(),
                        )
                      : _buildEditor(titleController, contentController),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
