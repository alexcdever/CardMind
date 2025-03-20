import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shared/providers/service_provider.dart';
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

/// 初始化包装器
/// 用于确保服务在页面显示前完成初始化
class InitializationWrapper extends ConsumerWidget {
  /// 子组件
  final Widget child;

  /// 构造函数
  const InitializationWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听初始化状态
    final initializationState = ref.watch(serviceInitializerProvider);

    return initializationState.when(
      data: (_) => child,
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在初始化...'),
            ],
          ),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text('初始化失败: $error'),
            ],
          ),
        ),
      ),
    );
  }
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
