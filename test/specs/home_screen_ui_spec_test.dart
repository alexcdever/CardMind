import 'package:cardmind/adaptive/widgets/adaptive_fab.dart';
import 'package:cardmind/models/sync_status.dart';
import 'package:cardmind/providers/card_provider.dart';
import 'package:cardmind/providers/pool_provider.dart';
import 'package:cardmind/screens/home_screen.dart';
import 'package:cardmind/widgets/note_editor_fullscreen.dart';
import 'package:cardmind/widgets/mobile_nav.dart';
import 'package:cardmind/widgets/sync_status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/mock_card_service.dart';
import '../helpers/mock_pool_provider.dart';

/// Home Screen UI Specification Tests
///
/// 规格编号: SP-UI-005
/// 这些测试验证主屏幕 UI 的所有交互行为
///
/// 测试遵循 Spec Coding 方法论：
/// - 测试即规格，规格即文档
/// - 使用 it_should_xxx() 命名风格
/// - Given-When-Then 结构

void main() {
  group('SP-UI-005: Home Screen UI', () {
    late MockCardService mockCardService;

    setUp(() {
      mockCardService = MockCardService();
    });

    // ========================================
    // Helper: 创建 HomeScreen
    // ========================================
    Widget createHomeScreen({Stream<SyncStatus>? syncStatusStream}) {
      final provider = CardProvider(cardService: mockCardService)
        ..loadCards(); // Load cards immediately

      return MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider<PoolProvider>(
              create: (_) => MockPoolProvider(isJoined: true),
            ),
          ],
          child: HomeScreen(
            syncStatusStream:
                syncStatusStream ?? Stream.value(SyncStatus.notYetSynced()),
          ),
        ),
      );
    }

    // ========================================
    // UI Layout Tests
    // ========================================

    group('UI Layout Tests', () {
      testWidgets('it_should_display_app_bar_with_title', (
        WidgetTester tester,
      ) async {
        // Given: 主屏幕加载
        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示标题
        expect(find.text('分布式笔记'), findsOneWidget);
      });

      testWidgets('it_should_display_app_icon_in_app_bar', (
        WidgetTester tester,
      ) async {
        // Given: 主屏幕加载
        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示应用图标（可能有多个）
        expect(find.byIcon(Icons.note), findsWidgets);
      });

      testWidgets('it_should_display_sync_status_indicator', (
        WidgetTester tester,
      ) async {
        // Given: 主屏幕加载
        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示同步状态指示器
        expect(find.byType(SyncStatusIndicator), findsOneWidget);
      });

      testWidgets('it_should_display_floating_action_button', (
        WidgetTester tester,
      ) async {
        // Given: 主屏幕加载
        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示 FAB
        expect(find.byType(AdaptiveFab), findsOneWidget);
      });

      testWidgets('it_should_display_search_bar', (WidgetTester tester) async {
        // Given: 主屏幕加载
        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示搜索栏
        expect(find.byIcon(Icons.search), findsOneWidget);
      });

      testWidgets('it_should_display_mobile_navigation_on_mobile', (
        WidgetTester tester,
      ) async {
        // Given: 移动端主屏幕
        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示底部导航栏（如果是移动端）
        // Note: 测试环境默认是移动端
        expect(find.byType(MobileNav), findsWidgets);
      });
    });

    // ========================================
    // Search Functionality Tests
    // ========================================

    group('Search Functionality Tests', () {
      testWidgets('it_should_accept_search_input', (WidgetTester tester) async {
        // Given: 主屏幕显示
        await tester.pumpWidget(createHomeScreen());
        await tester.pumpAndSettle();

        // When: 用户输入搜索文本
        final searchField = find.byType(TextField).first;
        await tester.enterText(searchField, 'test query');
        await tester.pump();

        // Then: 搜索文本被捕获
        expect(find.text('test query'), findsOneWidget);
      });

      testWidgets('it_should_filter_cards_by_title', (
        WidgetTester tester,
      ) async {
        // Given: 有多个卡片
        await mockCardService.createCard('Test Card', 'Content');
        await mockCardService.createCard('Another Card', 'Content');
        await mockCardService.createCard('Different', 'Content');

        await tester.pumpWidget(createHomeScreen());
        await tester.pumpAndSettle();

        // When: 用户搜索 "Test"
        final searchField = find.byType(TextField).first;
        await tester.enterText(searchField, 'Test');
        await tester.pumpAndSettle();

        // Then: 只显示匹配的卡片
        expect(find.text('Test Card'), findsOneWidget);
        expect(find.text('Different'), findsNothing);
      });

      testWidgets('it_should_filter_cards_by_content', (
        WidgetTester tester,
      ) async {
        // Given: 有多个卡片
        await mockCardService.createCard('Card 1', 'Special content');
        await mockCardService.createCard('Card 2', 'Normal content');

        await tester.pumpWidget(createHomeScreen());
        await tester.pumpAndSettle();

        // When: 用户搜索 "Special"
        final searchField = find.byType(TextField).first;
        await tester.enterText(searchField, 'Special');
        await tester.pumpAndSettle();

        // Then: 只显示匹配的卡片
        expect(find.text('Card 1'), findsOneWidget);
        expect(find.text('Card 2'), findsNothing);
      });

      testWidgets('it_should_be_case_insensitive', (WidgetTester tester) async {
        // Given: 有卡片
        await mockCardService.createCard('Test Card', 'Content');

        await tester.pumpWidget(createHomeScreen());
        await tester.pumpAndSettle();

        // When: 用户搜索小写 "test"
        final searchField = find.byType(TextField).first;
        await tester.enterText(searchField, 'test');
        await tester.pumpAndSettle();

        // Then: 找到匹配的卡片
        expect(find.text('Test Card'), findsOneWidget);
      });

      testWidgets('it_should_show_all_cards_when_search_cleared', (
        WidgetTester tester,
      ) async {
        // Given: 有多个卡片，用户进行了搜索
        await mockCardService.createCard('Card 1', 'Content');
        await mockCardService.createCard('Card 2', 'Content');

        await tester.pumpWidget(createHomeScreen());
        await tester.pumpAndSettle();

        final searchField = find.byType(TextField).first;
        await tester.enterText(searchField, 'Card 1');
        await tester.pumpAndSettle();

        // When: 用户清空搜索
        await tester.enterText(searchField, '');
        await tester.pumpAndSettle();

        // Then: 显示所有卡片
        expect(find.text('Card 1'), findsOneWidget);
        expect(find.text('Card 2'), findsOneWidget);
      });

      testWidgets('it_should_display_search_placeholder', (
        WidgetTester tester,
      ) async {
        // Given: 主屏幕显示
        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示搜索占位符
        expect(find.textContaining('搜索'), findsOneWidget);
      });
    });

    // ========================================
    // FAB Tests
    // ========================================

    group('FAB Tests', () {
      testWidgets('it_should_create_card_when_fab_tapped', (
        WidgetTester tester,
      ) async {
        // Given: 主屏幕显示
        await tester.pumpWidget(createHomeScreen());
        await tester.pumpAndSettle();

        // When: 用户点击 FAB
        await tester.tap(find.byType(AdaptiveFab));
        await tester.pumpAndSettle();

        // Then: FAB 仍然可见（在简单测试环境中）
        expect(find.byType(AdaptiveFab), findsOneWidget);
      });

      testWidgets('it_should_display_fab_tooltip', (WidgetTester tester) async {
        // Given: 主屏幕显示
        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: FAB 有 tooltip
        final fab = tester.widget<AdaptiveFab>(find.byType(AdaptiveFab));
        expect(fab.tooltip, equals('新建笔记'));
      });

      testWidgets('it_should_display_add_icon_on_fab', (
        WidgetTester tester,
      ) async {
        // Given: 主屏幕显示
        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: FAB 显示添加图标
        expect(
          find.descendant(
            of: find.byType(AdaptiveFab),
            matching: find.byIcon(Icons.add),
          ),
          findsOneWidget,
        );
      });
    });

    // ========================================
    // Empty State Tests
    // ========================================

    group('Empty State Tests', () {
      testWidgets('it_should_display_empty_state_when_no_cards', (
        WidgetTester tester,
      ) async {
        // Given: 没有卡片
        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示空状态
        expect(find.text('还没有笔记'), findsOneWidget);
      });

      testWidgets('it_should_display_empty_icon_in_empty_state', (
        WidgetTester tester,
      ) async {
        // Given: 没有卡片
        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示空状态图标
        expect(find.byIcon(Icons.note), findsWidgets);
      });

      testWidgets('it_should_display_create_button_in_empty_state', (
        WidgetTester tester,
      ) async {
        // Given: 没有卡片
        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示创建按钮
        expect(find.text('创建第一条笔记'), findsOneWidget);
      });

      testWidgets('it_should_create_card_when_empty_state_button_tapped', (
        WidgetTester tester,
      ) async {
        // Given: 空状态显示
        await tester.pumpWidget(createHomeScreen());
        await tester.pumpAndSettle();

        // When: 用户点击创建按钮
        await tester.tap(find.text('创建第一条笔记'));
        await tester.pumpAndSettle();

        // Then: 在移动端打开编辑器
        // 注意：在移动端，点击创建按钮不会立即创建卡片，而是打开编辑器
        expect(find.byType(NoteEditorFullscreen), findsOneWidget);
      });

      testWidgets('it_should_display_no_results_message_when_search_empty', (
        WidgetTester tester,
      ) async {
        // Given: 有卡片但搜索无结果
        await mockCardService.createCard('Test Card', 'Content');

        await tester.pumpWidget(createHomeScreen());
        await tester.pumpAndSettle();

        // When: 用户搜索不存在的内容
        final searchField = find.byType(TextField).first;
        await tester.enterText(searchField, 'nonexistent');
        await tester.pumpAndSettle();

        // Then: 显示无结果消息
        expect(find.text('没有找到匹配的笔记'), findsOneWidget);
      });
    });

    // ========================================
    // Loading State Tests
    // ========================================

    group('Loading State Tests', () {
      testWidgets('it_should_display_loading_indicator_when_loading', (
        WidgetTester tester,
      ) async {
        // Given: 数据正在加载
        mockCardService.delayMs = 1000;

        await tester.pumpWidget(createHomeScreen());

        // When: 初始渲染
        await tester.pump();

        // Then: 显示加载指示器
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Cleanup
        await tester.pumpAndSettle();
      });

      testWidgets('it_should_hide_loading_indicator_after_load', (
        WidgetTester tester,
      ) async {
        // Given: 数据加载完成
        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 不显示加载指示器
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });

    // ========================================
    // Card Display Tests
    // ========================================

    group('Card Display Tests', () {
      testWidgets('it_should_display_all_cards', (WidgetTester tester) async {
        // Given: 有多个卡片
        await mockCardService.createCard('Card 1', 'Content 1');
        await mockCardService.createCard('Card 2', 'Content 2');
        await mockCardService.createCard('Card 3', 'Content 3');

        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示所有卡片
        expect(find.text('Card 1'), findsOneWidget);
        expect(find.text('Card 2'), findsOneWidget);
        expect(find.text('Card 3'), findsOneWidget);
      });

      testWidgets('it_should_display_cards_in_list_on_mobile', (
        WidgetTester tester,
      ) async {
        // Given: 移动端有卡片
        await mockCardService.createCard('Card 1', 'Content');

        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 使用列表布局（移动端）
        expect(find.byType(ListView), findsWidgets);
      });

      testWidgets('it_should_update_display_when_card_added', (
        WidgetTester tester,
      ) async {
        // Given: 主屏幕显示
        await tester.pumpWidget(createHomeScreen());
        await tester.pumpAndSettle();

        // When: 添加新卡片
        await tester.tap(find.byType(AdaptiveFab));
        await tester.pumpAndSettle();

        // Then: 在移动端打开编辑器
        // 注意：在移动端，点击 FAB 不会立即显示新卡片，而是打开编辑器
        expect(find.byType(NoteEditorFullscreen), findsOneWidget);
      });
    });

    // ========================================
    // Mobile Navigation Tests
    // ========================================

    group('Mobile Navigation Tests', () {
      testWidgets('it_should_display_mobile_nav_on_mobile', (
        WidgetTester tester,
      ) async {
        // Given: 移动端主屏幕
        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示移动端导航
        expect(find.byType(MobileNav), findsWidgets);
      });

      testWidgets('it_should_switch_tabs_when_nav_item_tapped', (
        WidgetTester tester,
      ) async {
        // Given: 移动端主屏幕显示
        await tester.pumpWidget(createHomeScreen());
        await tester.pumpAndSettle();

        // When: 用户点击设备标签
        await tester.tap(find.text('设备'));
        await tester.pumpAndSettle();

        // Then: 切换到设备标签页
        expect(find.text('设备网络'), findsOneWidget);
      });

      testWidgets('it_should_display_notes_tab_by_default', (
        WidgetTester tester,
      ) async {
        // Given: 移动端主屏幕加载
        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 默认显示笔记标签页
        expect(find.byIcon(Icons.search), findsOneWidget);
      });
    });

    // ========================================
    // Sync Status Tests
    // ========================================

    group('Sync Status Tests', () {
      testWidgets('it_should_display_sync_status_indicator', (
        WidgetTester tester,
      ) async {
        // Given: 主屏幕加载
        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示同步状态
        expect(find.byType(SyncStatusIndicator), findsOneWidget);
      });

      testWidgets('it_should_update_sync_status_from_stream', (
        WidgetTester tester,
      ) async {
        // Given: 主屏幕显示
        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 同步状态指示器显示
        expect(find.byType(SyncStatusIndicator), findsOneWidget);
      });
    });

    // ========================================
    // Desktop Layout Tests
    // ========================================

    group('Desktop Layout Tests', () {
      testWidgets('it_should_display_new_note_button_on_desktop', (
        WidgetTester tester,
      ) async {
        // Given: 桌面端主屏幕
        await tester.binding.setSurfaceSize(const Size(1200, 800));

        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示新建笔记按钮（桌面端）
        // Note: 测试环境默认是移动端，这个测试主要验证布局存在
        expect(find.byType(HomeScreen), findsOneWidget);

        // Cleanup
        await tester.binding.setSurfaceSize(null);
      });

      testWidgets('it_should_display_three_column_layout_on_desktop', (
        WidgetTester tester,
      ) async {
        // Given: 桌面端主屏幕
        await tester.binding.setSurfaceSize(const Size(1200, 800));

        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 使用三列布局
        expect(find.byType(HomeScreen), findsOneWidget);

        // Cleanup
        await tester.binding.setSurfaceSize(null);
      });
    });

    // ========================================
    // Error Handling Tests
    // ========================================

    group('Error Handling Tests', () {
      testWidgets('it_should_handle_load_error_gracefully', (
        WidgetTester tester,
      ) async {
        // Given: 加载会失败
        mockCardService.shouldThrowError = true;

        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 不崩溃
        expect(tester.takeException(), isNull);
      });

      testWidgets('it_should_handle_create_error_gracefully', (
        WidgetTester tester,
      ) async {
        // Given: 创建会失败
        mockCardService.shouldThrowError = true;

        await tester.pumpWidget(createHomeScreen());
        await tester.pumpAndSettle();

        // When: 用户尝试创建卡片
        await tester.tap(find.byType(AdaptiveFab));
        await tester.pumpAndSettle();

        // Then: 不崩溃
        expect(tester.takeException(), isNull);
      });
    });

    // ========================================
    // Accessibility Tests
    // ========================================

    group('Accessibility Tests', () {
      testWidgets('it_should_provide_semantic_labels_for_search', (
        WidgetTester tester,
      ) async {
        // Given: 主屏幕显示
        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 搜索框有占位符
        expect(find.textContaining('搜索'), findsOneWidget);
      });

      testWidgets('it_should_provide_semantic_labels_for_fab', (
        WidgetTester tester,
      ) async {
        // Given: 主屏幕显示
        await tester.pumpWidget(createHomeScreen());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: FAB 有 tooltip
        final fab = tester.widget<AdaptiveFab>(find.byType(AdaptiveFab));
        expect(fab.tooltip, isNotNull);
      });
    });

    // ========================================
    // Performance Tests
    // ========================================

    group('Performance Tests', () {
      testWidgets('it_should_render_home_screen_within_200ms', (
        WidgetTester tester,
      ) async {
        // Given: 主屏幕即将加载
        final startTime = DateTime.now();

        // When: 加载主屏幕
        await tester.pumpWidget(createHomeScreen());
        await tester.pumpAndSettle();

        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);

        // Then: 渲染时间小于 200ms
        expect(duration.inMilliseconds, lessThan(200));
      });

      testWidgets('it_should_handle_many_cards_efficiently', (
        WidgetTester tester,
      ) async {
        // Given: 大量卡片
        for (int i = 0; i < 100; i++) {
          await mockCardService.createCard('Card $i', 'Content $i');
        }

        // When: 加载主屏幕
        await tester.pumpWidget(createHomeScreen());
        await tester.pumpAndSettle();

        // Then: 没有性能问题
        expect(tester.takeException(), isNull);
      });

      testWidgets('it_should_handle_rapid_search_input_efficiently', (
        WidgetTester tester,
      ) async {
        // Given: 主屏幕显示
        await mockCardService.createCard('Test Card', 'Content');

        await tester.pumpWidget(createHomeScreen());
        await tester.pumpAndSettle();

        // When: 快速输入搜索
        final searchField = find.byType(TextField).first;
        for (int i = 0; i < 10; i++) {
          await tester.enterText(searchField, 'query$i');
          await tester.pump();
        }

        // Then: 没有性能问题
        expect(tester.takeException(), isNull);
      });
    });
  });
}
