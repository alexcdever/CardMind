// input: lib/app/app.dart 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Flutter 应用壳层模块，负责导航与跨端布局。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 应用壳层模块，负责导航与跨端布局。
import 'package:cardmind/features/onboarding/onboarding_page.dart';
import 'package:flutter/material.dart';

class CardMindApp extends StatelessWidget {
  const CardMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CardMind',
      theme: ThemeData(useMaterial3: true),
      home: const OnboardingPage(),
    );
  }
}
