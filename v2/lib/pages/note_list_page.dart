import 'package:flutter/material.dart';

class NoteListPage extends StatelessWidget {
  const NoteListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CardMind'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          '暂无笔记',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/editor');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
