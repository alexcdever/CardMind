import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/domain/models/card.dart' as domain;
import '../../shared/screens/card_edit_base.dart';

/// 移动端卡片编辑界面
class MobileCardEditScreen extends ConsumerStatefulWidget {
  /// 要编辑的卡片，如果为 null 则表示新建卡片
  final domain.Card? card;

  const MobileCardEditScreen({super.key, this.card});

  @override
  ConsumerState<MobileCardEditScreen> createState() => _MobileCardEditScreenState();
}

class _MobileCardEditScreenState extends ConsumerState<MobileCardEditScreen> {
  /// 是否处于预览模式
  bool _isPreview = false;

  /// 构建编辑器界面
  Widget _buildEditor(TextEditingController titleController, TextEditingController contentController) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题输入框
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextFormField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: '标题',
              hintText: '请输入卡片标题',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
        ),
        const Divider(height: 1),
        // 内容输入框
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
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
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const Divider(height: 1),
        // 内容预览（Markdown）
        Expanded(
          child: Markdown(
            data: content,
            selectable: true,
            padding: const EdgeInsets.all(16),
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
            actions: [
              // 预览/编辑切换按钮
              IconButton(
                icon: Icon(_isPreview ? Icons.edit : Icons.preview),
                tooltip: _isPreview ? '切换到编辑' : '切换到预览',
                onPressed: () => setState(() => _isPreview = !_isPreview),
              ),
              // 保存按钮
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: isValid ? saveCard : null,
              ),
            ],
          ),
          body: _isPreview
              ? _buildPreview(
                  titleController.text.trim(),
                  contentController.text.trim(),
                )
              : _buildEditor(titleController, contentController),
        );
      },
    );
  }
}
