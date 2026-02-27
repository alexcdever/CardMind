// input: editor interactions (typing, shortcut save, back navigation)
// output: editable note UI with save feedback and leave guard decisions
// pos: card editor page; 修改本文件需同步更新文件头与所属 DIR.md
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cardmind/features/editor/editor_controller.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final EditorController _controller = EditorController();

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
                      onChanged: (_) => setState(() {
                        _controller.onContentChanged();
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
                        onChanged: (_) => setState(() {
                          _controller.onContentChanged();
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
    }

    Navigator.of(context).pop();
  }
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}

enum _ExitDecision { save, discard, cancel }
