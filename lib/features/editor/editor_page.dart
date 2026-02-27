import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  bool _dirty = false;
  bool _saved = false;

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
                _saved = true;
              });
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: _onBack),
              title: const Text('编辑卡片'),
            ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    onChanged: (_) => setState(() {
                      _dirty = true;
                    }),
                  ),
                  if (_saved) const Text('本地已保存'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onBack() async {
    if (!_dirty) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('保存并离开'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('放弃更改'),
            ),
          ],
        );
      },
    );
  }
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}
