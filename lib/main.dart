// input: Dart 运行时调用 main() 启动应用进程。
// output: 执行 runApp(const CardMindApp()) 挂载根组件。
// pos: Flutter 应用入口文件，负责触发根组件启动。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 客户端入口模块，负责应用启动与依赖接线。
import 'package:cardmind/app/app.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const CardMindApp());
}
