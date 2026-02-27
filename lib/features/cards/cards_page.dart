import 'package:flutter/material.dart';

class CardsPage extends StatelessWidget {
  const CardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: const [
          TextField(decoration: InputDecoration(hintText: '搜索卡片')),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: null,
        child: const Icon(Icons.add),
      ),
    );
  }
}
