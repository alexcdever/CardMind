import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../card_list_screen.dart';
import '../../../shared/screens/card_edit_screen.dart';
import '../../../shared/screens/card_detail_screen.dart';
import '../../../shared/widgets/initialization_wrapper.dart';

/// 应用路由配置
final goRouter = GoRouter(
  initialLocation: '/cards',
  // 错误页面配置
  errorBuilder: (context, state) => InitializationWrapper(
    child: Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('页面未找到'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/cards'),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    ),
  ),
  routes: [
    // 卡片列表页面
    GoRoute(
      path: '/cards',
      builder: (context, state) => const InitializationWrapper(
        child: CardListScreen(),
      ),
      routes: [
        // 新建卡片页面
        GoRoute(
          path: 'new',
          builder: (context, state) => const InitializationWrapper(
            child: CardEditScreen(),
          ),
        ),
        // 编辑卡片页面
        GoRoute(
          path: ':id/edit',
          builder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return InitializationWrapper(
              child: CardEditScreen(cardId: id),
            );
          },
        ),
        // 查看卡片详情页面
        GoRoute(
          path: ':id',
          builder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return InitializationWrapper(
              child: CardDetailScreen(cardId: id),
            );
          },
        ),
      ],
    ),
  ],
);
