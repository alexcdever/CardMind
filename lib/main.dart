import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'api/api_service.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化日志
  AppLogger().init();
  AppLogger().i('CardMind应用启动');
  
  // 初始化API服务
  final apiService = ApiService();
  await apiService.init();
  
  AppLogger().i('API服务初始化完成，准备启动应用');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CardMind',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}