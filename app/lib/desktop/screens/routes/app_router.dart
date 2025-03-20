import 'package:go_router/go_router.dart';
import '../card_list_screen.dart';
import '../../../shared/screens/card_edit_screen.dart';
import '../../../shared/screens/card_detail_screen.dart';
import '../../../shared/widgets/initialization_wrapper.dart';

/// 应用路由配置
final goRouter = GoRouter(
  initialLocation: '/cards',
  routes: [
    // 卡片列表页面
    GoRoute(
      path: '/cards',
      builder: (context, state) => const InitializationWrapper(
        child: CardListScreen(),
      ),
    ),
    // 新建卡片页面
    GoRoute(
      path: '/cards/new',
      builder: (context, state) => const InitializationWrapper(
        child: CardEditScreen(),
      ),
    ),
    // 编辑卡片页面
    GoRoute(
      path: '/cards/:id/edit',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return InitializationWrapper(
          child: CardEditScreen(cardId: id),
        );
      },
    ),
    // 查看卡片详情页面
    GoRoute(
      path: '/cards/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return InitializationWrapper(
          child: CardDetailScreen(cardId: id),
        );
      },
    ),
  ],
);
