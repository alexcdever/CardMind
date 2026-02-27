import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          const ListTile(title: Text('设备信息')),
          ListTile(title: const Text('创建或加入数据池'), onTap: () {}),
        ],
      ),
    );
  }
}
