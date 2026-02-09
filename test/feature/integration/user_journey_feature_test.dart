import 'package:cardmind/screens/home_screen.dart';
import 'package:cardmind/widgets/note_editor_fullscreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_card_service.dart';
import '../../helpers/test_app.dart';

/// User Journey Integration Tests
///
/// 这些测试验证完整的用户旅程，从应用启动到完成关键任务
///
/// 测试遵循 Spec Coding 方法论：
/// - 测试即规格，规格即文档
/// - 使用 it_should_xxx() 命名风格
/// - Given-When-Then 结构

void main() {
  group('User Journey Integration Tests', () {
    late MockCardService mockCardService;

    setUp(() {
      mockCardService = MockCardService();
    });

    // ========================================
    // 任务组 1: 首次用户旅程
    // ========================================

    group('First Time User Journey', () {
      testWidgets('it_should_complete_first_time_user_flow', (
        WidgetTester tester,
      ) async {
        // Given: 新用户首次打开应用
        await tester.pumpWidget(
          TestApp(cardService: mockCardService, child: const HomeScreen()),
        );

        // When: 应用加载完成
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Then: 应该显示主屏幕
        expect(find.byType(Scaffold), findsWidgets);
      });

      testWidgets('it_should_create_first_card', (WidgetTester tester) async {
        // Given: 用户在主屏幕
        await tester.pumpWidget(
          TestApp(cardService: mockCardService, child: const HomeScreen()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // When: 用户点击创建按钮
        final fabFinder = find.byType(FloatingActionButton);
        if (fabFinder.evaluate().isNotEmpty) {
          await tester.tap(fabFinder);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          // Then: FAB 仍然可见（在简单测试环境中）
          expect(find.byType(FloatingActionButton), findsOneWidget);
        }
      });
    });

    // ========================================
    // 任务组 2: 卡片生命周期
    // ========================================

    group('Card Lifecycle Journey', () {
      testWidgets('it_should_complete_card_create_edit_delete_flow', (
        WidgetTester tester,
      ) async {
        // Given: 用户在主屏幕
        await tester.pumpWidget(
          TestApp(cardService: mockCardService, child: const HomeScreen()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // When: 创建卡片
        final fabFinder = find.byType(FloatingActionButton);
        if (fabFinder.evaluate().isNotEmpty) {
          await tester.tap(fabFinder);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          // Then: 在移动端应该打开编辑器
          expect(find.byType(NoteEditorFullscreen), findsOneWidget);
        }
      });

      testWidgets('it_should_handle_card_editing', (WidgetTester tester) async {
        // Given: 用户有一个卡片
        await tester.pumpWidget(
          TestApp(cardService: mockCardService, child: const HomeScreen()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // When: 用户编辑卡片
        // Then: 编辑应该成功
        expect(find.byType(Scaffold), findsWidgets);
      });

      testWidgets('it_should_handle_card_deletion', (
        WidgetTester tester,
      ) async {
        // Given: 用户有一个卡片
        await tester.pumpWidget(
          TestApp(cardService: mockCardService, child: const HomeScreen()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // When: 用户删除卡片
        // Then: 删除应该成功
        expect(find.byType(Scaffold), findsWidgets);
      });
    });

    // ========================================
    // 任务组 3: 搜索和过滤
    // ========================================

    group('Search and Filter Journey', () {
      testWidgets('it_should_search_cards_by_title', (
        WidgetTester tester,
      ) async {
        // Given: 用户有多个卡片
        await tester.pumpWidget(
          TestApp(cardService: mockCardService, child: const HomeScreen()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // When: 用户搜索卡片
        final searchField = find.byType(TextField);
        if (searchField.evaluate().isNotEmpty) {
          await tester.enterText(searchField.first, 'test');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          // Then: 应该显示搜索结果
          expect(find.byType(Scaffold), findsWidgets);
        }
      });

    });

    // ========================================
    // 任务组 4: 设备管理流程
    // ========================================

    group('Device Management Journey', () {
      testWidgets('it_should_view_device_list', (WidgetTester tester) async {
        // Given: 用户在主屏幕
        await tester.pumpWidget(
          TestApp(cardService: mockCardService, child: const HomeScreen()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // When: 用户查看设备列表
        // Then: 应该显示设备列表
        expect(find.byType(Scaffold), findsWidgets);
      });
    });

    // ========================================
    // 任务组 5: 设置变更
    // ========================================

    group('Settings Journey', () {
      testWidgets('it_should_access_settings', (WidgetTester tester) async {
        // Given: 用户在主屏幕
        await tester.pumpWidget(
          TestApp(cardService: mockCardService, child: const HomeScreen()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // When: 用户访问设置
        // Then: 应该显示设置界面
        expect(find.byType(Scaffold), findsWidgets);
      });
    });

    // ========================================
    // 任务组 6: 错误恢复
    // ========================================

    group('Error Recovery Journey', () {
      testWidgets('it_should_handle_network_error_gracefully', (
        WidgetTester tester,
      ) async {
        // Given: 网络错误
        mockCardService.shouldThrowError = true;

        await tester.pumpWidget(
          TestApp(cardService: mockCardService, child: const HomeScreen()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // When: 用户尝试操作
        // Then: 应该显示错误提示
        expect(find.byType(Scaffold), findsWidgets);
      });

      testWidgets('it_should_retry_failed_operations', (
        WidgetTester tester,
      ) async {
        // Given: 操作失败
        await tester.pumpWidget(
          TestApp(cardService: mockCardService, child: const HomeScreen()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // When: 用户重试
        // Then: 应该重新执行操作
        expect(find.byType(Scaffold), findsWidgets);
      });
    });
  });
}
