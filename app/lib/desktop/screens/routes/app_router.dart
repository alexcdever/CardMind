import 'package:go_router/go_router.dart';
import '../card_edit_screen.dart';
import '../card_list_screen.dart';

/// 应用路由配置
final goRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/cards',
      builder: (context, state) => const CardListScreen(),
    ),
    GoRoute(
      path: '/add',
      builder: (context, state) => const DesktopCardEditScreen(),
    ),
    GoRoute(
      path: '/edit/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return DesktopCardEditScreen(cardId: id);
      },
    ),
  ],
);
