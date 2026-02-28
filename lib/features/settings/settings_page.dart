// input: 用户点击设置项“创建或加入数据池”。
// output: 渲染设置列表并导航到 PoolPage(notJoined) 页面。
// pos: 设置页面，负责展示设备信息与数据池入口。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
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
