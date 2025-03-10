import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'shared/utils/platform_detector.dart';
import 'desktop/screens/card_list_screen.dart' as desktop;
import 'desktop/screens/add_card_screen.dart' as desktop;
import 'mobile/screens/card_list_screen.dart' as mobile;
import 'mobile/screens/add_card_screen.dart' as mobile;
import 'shared/domain/models/card.dart' as domain;

/// 主程序入口
void main() {
  runApp(const ProviderScope(child: MyApp()));
}

/// 应用主入口
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 根据平台配置路由
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => PlatformDetector.isDesktop
              ? const desktop.CardListScreen()
              : const mobile.CardListScreen(),
        ),
        GoRoute(
          path: '/add',
          builder: (context, state) {
            final card = state.extra as domain.Card?;
            return PlatformDetector.isDesktop
                ? desktop.AddCardScreen(card: card)
                : mobile.AddCardScreen(card: card);
          },
        ),
      ],
    );

    return MaterialApp.router(
      title: 'CardMind',
      theme: ThemeData(
        // 主题配置
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        // 暗色主题配置
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
