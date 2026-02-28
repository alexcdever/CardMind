// input: 用户键盘快捷键、文本输入、返回操作与保存按钮点击。
// output: 渲染编辑表单与离开确认弹窗，并调用控制器更新 dirty/saved 状态。
// pos: 卡片编辑页面，负责内容编辑、保存与离开拦截流程。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'package:cardmind/features/editor/editor_controller.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key, this.onSaved});

  final ValueChanged<EditorDraft>? onSaved;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final EditorController _controller = EditorController();
  static const Uuid _uuid = Uuid();

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyS, control: true): _SaveIntent(),
        SingleActivator(LogicalKeyboardKey.keyS, meta: true): _SaveIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SaveIntent: CallbackAction<_SaveIntent>(
            onInvoke: (_) {
              setState(() {
                _controller.saveLocal();
              });
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: PopScope<void>(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) {
                return;
              }
              await _onBack();
            },
            child: Scaffold(
              appBar: AppBar(
                leading: BackButton(onPressed: _onBack),
                title: const Text('编辑卡片'),
                actions: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _controller.saveLocal();
                      });
                      widget.onSaved?.call(_controller.draft());
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.save_outlined),
                  ),
                ],
              ),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(labelText: '标题'),
                      onChanged: (value) => setState(() {
                        _controller.setTitle(value);
                      }),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TextField(
                        expands: true,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                          labelText: '内容',
                          hintText: '输入卡片内容',
                        ),
                        onChanged: (value) => setState(() {
                          _controller.setBody(value);
                        }),
                      ),
                    ),
                    if (_controller.saved)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('本地已保存'),
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

  Future<void> _onBack() async {
    if (!_controller.dirty) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }

    final decision = await showDialog<_ExitDecision>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('离开编辑？'),
          content: const Text('你有未保存的更改。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(_ExitDecision.save),
              child: const Text('保存并离开'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_ExitDecision.discard),
              child: const Text('放弃更改'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_ExitDecision.cancel),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );

    if (!mounted || decision == null) {
      return;
    }

    if (decision == _ExitDecision.cancel) {
      return;
    }

    if (decision == _ExitDecision.save) {
      setState(() {
        _controller.saveLocal();
      });
      widget.onSaved?.call(_controller.draft());
    }

    Navigator.of(context).pop();
  }
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}

String generateNoteId() => _EditorPageState._uuid.v4();

enum _ExitDecision { save, discard, cancel }
