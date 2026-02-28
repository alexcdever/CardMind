// input: lib/main.dart 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Flutter 客户端入口模块，负责应用启动与依赖接线。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 客户端入口模块，负责应用启动与依赖接线。
import 'package:cardmind/app/app.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const CardMindApp());
}
