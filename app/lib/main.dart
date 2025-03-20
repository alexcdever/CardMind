import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shared/utils/logger.dart';
import 'desktop/screens/routes/app_router.dart';

/// 主程序入口
void main() {
  // 初始化日志系统
  AppLogger.init();
  
  // 确保Flutter绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: CardMindApp(),
    ),
  );
}

/// 应用程序主入口
class CardMindApp extends StatelessWidget {
  /// 构造函数
  const CardMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CardMind',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: goRouter,
    );
  }
}
