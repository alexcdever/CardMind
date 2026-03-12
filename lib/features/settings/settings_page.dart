// input: 用户进入设置分区。
// output: 渲染空白设置页占位（当前版本无配置项）。
// pos: 设置页面，当前仅提供空白占位。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/shared/testing/semantic_ids.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Semantics(
        container: true,
        explicitChildNodes: true,
        identifier: SemanticIds.settingsPage,
        label: '设置页',
        child: const SizedBox.expand(key: ValueKey('settings.page')),
      ),
    );
  }
}
