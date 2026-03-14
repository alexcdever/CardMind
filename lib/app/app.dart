// input: Flutter 框架调用 build(context) 构建已完成 app config 初始化后的根级应用配置。
// output: 返回 MaterialApp，并将 AppHomepagePage 设为首页。
// pos: Flutter 根应用配置文件，负责主题、标题与首屏路由。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 应用主页模块，负责导航与跨端布局。
import 'package:cardmind/app/navigation/app_homepage_page.dart';
import 'package:flutter/material.dart';

class CardMindApp extends StatelessWidget {
  const CardMindApp({super.key, this.appDataDir = ''});

  final String appDataDir;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CardMind',
      theme: ThemeData(useMaterial3: true),
      home: const AppHomepagePage(),
    );
  }
}
