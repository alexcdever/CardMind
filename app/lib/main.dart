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

/// 应用主入口
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 根据平台配置路由
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        // 卡片列表页面
        GoRoute(
          path: '/',
          builder: (context, state) => PlatformDetector.isDesktop
              ? const desktop.CardListScreen()
              : const mobile.CardListScreen(),
        ),
        // 新建卡片页面
        GoRoute(
          path: '/add',
          builder: (context, state) => PlatformDetector.isDesktop
              ? const desktop.DesktopCardEditScreen()
              : const mobile.MobileCardEditScreen(),
        ),
        // 编辑卡片页面
        GoRoute(
          path: '/edit/:id',
          builder: (context, state) {
            // 从路由参数获取卡片ID
            final id = int.parse(state.pathParameters['id']!);
            // 使用 Provider 获取卡片数据
            final card = ref.watch(cardByIdProvider(id));
            
            // 如果找不到卡片，返回列表页面
            if (card == null) {
              Future.microtask(() => context.go('/'));
              return const SizedBox.shrink();
            }

            // 根据平台返回对应的编辑界面
            return PlatformDetector.isDesktop
                ? desktop.DesktopCardEditScreen(card: card)
                : mobile.MobileCardEditScreen(card: card);
          },
        ),
      ],
    );

    return MaterialApp.router(
      title: 'CardMind',
      // 使用桌面端主题
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
