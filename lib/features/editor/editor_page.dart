import 'package:flutter/material.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  bool _dirty = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _onBack),
        title: const Text('编辑卡片'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          onChanged: (_) => setState(() {
            _dirty = true;
          }),
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
