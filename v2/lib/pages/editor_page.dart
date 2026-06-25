import 'package:flutter/material.dart';

class EditorPage extends StatelessWidget {
  final int? noteId;

  const EditorPage({super.key, this.noteId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新笔记'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          '编辑器区域（后续集成 appflowy_editor）',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }
}
