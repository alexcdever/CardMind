import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../card_edit_screen.dart';
import '../screens/home_screen.dart';
import '../screens/card_list_screen.dart';
import '../screens/study_screen.dart';

/// 应用路由配置
final goRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/cards',
      builder: (context, state) => const CardListScreen(),
    ),
    GoRoute(
      path: '/study',
      builder: (context, state) => const StudyScreen(),
    ),
    GoRoute(
      path: '/add',
      builder: (context, state) => const DesktopCardEditScreen(),
    ),
    GoRoute(
      path: '/edit/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        // TODO: 从 Provider 获取卡片数据
        return DesktopCardEditScreen(
          // card: card,
        );
      },
    ),
  ],
);
