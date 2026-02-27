import 'package:cardmind/features/pool/pool_page.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          const ListTile(title: Text('设备信息')),
          ListTile(
            title: const Text('创建或加入数据池'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PoolPage(state: PoolState.notJoined()),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
