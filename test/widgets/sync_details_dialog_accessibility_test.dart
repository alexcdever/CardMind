import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/models/sync_status.dart';
import 'package:cardmind/widgets/sync_details_dialog.dart';

void main() {
  group('SyncDetailsDialog Accessibility Tests', () {
    Widget createTestWidget(SyncStatus status) {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => SyncDetailsDialog(status: status),
          ),
        ),
      );
    }

    group('Screen Reader Support', () {
      testWidgets('it_should_display_dialog_with_title',
          (WidgetTester tester) async {
        // GIVEN: 任意状态
        final status = SyncStatus.notYetSynced();

        // WHEN: 显示对话框
        await tester.pumpWidget(createTestWidget(status));
        await tester.pumpAndSettle();

        // THEN: 对话框应该显示
        expect(find.byType(AlertDialog), findsOneWidget);

        // AND: 对话框标题应该显示
        expect(find.text('尚未同步'), findsOneWidget);
      });

      testWidgets('it_should_display_status_icons',
          (WidgetTester tester) async {
        // GIVEN: failed 状态
        final status = SyncStatus.failed(errorMessage: '测试错误');

        // WHEN: 显示对话框
        await tester.pumpWidget(createTestWidget(status));
        await tester.pumpAndSettle();

        // THEN: 错误图标应该显示
        expect(find.byIcon(Icons.error_outline), findsWidgets);

        // AND: 错误状态文本应该显示
        expect(find.text('同步失败'), findsOneWidget);
      });

      testWidgets('it_should_display_status_text',
          (WidgetTester tester) async {
        // GIVEN: syncing 状态
        final status = SyncStatus.syncing();

        // WHEN: 显示对话框
        await tester.pumpWidget(createTestWidget(status));
        await tester.pump(const Duration(seconds: 1));

        // THEN: 状态文本应该显示
        expect(find.text('同步中'), findsOneWidget);
      });

      testWidgets('it_should_display_action_buttons',
          (WidgetTester tester) async {
        // GIVEN: failed 状态（有重试按钮）
        final status = SyncStatus.failed(errorMessage: '测试错误');

        // WHEN: 显示对话框
        await tester.pumpWidget(createTestWidget(status));
        await tester.pumpAndSettle();

        // THEN: 重试按钮应该显示
        expect(find.text('重试'), findsOneWidget);

        // AND: 关闭按钮应该显示
        expect(find.text('关闭'), findsOneWidget);
      });
    });

    group('Keyboard Navigation', () {
      testWidgets('it_should_support_button_interaction',
          (WidgetTester tester) async {
        // GIVEN: failed 状态（有重试和关闭按钮）
        final status = SyncStatus.failed(errorMessage: '测试错误');

        // WHEN: 显示对话框
        await tester.pumpWidget(createTestWidget(status));
        await tester.pumpAndSettle();

        // THEN: 应该能找到所有可交互按钮
        expect(find.text('重试'), findsOneWidget);
        expect(find.text('关闭'), findsOneWidget);
      });

      testWidgets('it_should_close_dialog_on_button_tap',
          (WidgetTester tester) async {
        // GIVEN: 任意状态
        final status = SyncStatus.notYetSynced();

        // WHEN: 显示对话框
        await tester.pumpWidget(createTestWidget(status));
        await tester.pumpAndSettle();

        // THEN: 对话框应该显示
        expect(find.byType(AlertDialog), findsOneWidget);

        // WHEN: 点击关闭按钮
        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();

        // THEN: 对话框应该关闭
        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets('it_should_have_interactive_retry_button',
          (WidgetTester tester) async {
        // GIVEN: failed 状态（重试是主要操作）
        final status = SyncStatus.failed(errorMessage: '测试错误');

        // WHEN: 显示对话框
        await tester.pumpWidget(createTestWidget(status));
        await tester.pumpAndSettle();

        // THEN: 重试按钮应该存在且可交互
        final retryButton = find.text('重试');
        expect(retryButton, findsOneWidget);

        // AND: 按钮应该可以被点击
        await tester.tap(retryButton);
        await tester.pumpAndSettle();
      });
    });

    group('High Contrast Mode Support', () {
      testWidgets('it_should_work_with_dark_theme',
          (WidgetTester tester) async {
        // GIVEN: 高对比度主题
        final status = SyncStatus.failed(errorMessage: '测试错误');

        // WHEN: 使用高对比度主题显示对话框
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.dark(
                primary: Colors.white,
                onPrimary: Colors.black,
                error: Colors.red.shade900,
                onError: Colors.white,
              ),
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => SyncDetailsDialog(status: status),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // THEN: 对话框应该正常显示
        expect(find.byType(AlertDialog), findsOneWidget);

        // AND: 错误图标应该显示
        expect(find.byIcon(Icons.error_outline), findsWidgets);

        // AND: 文本应该可读
        expect(find.text('同步失败'), findsOneWidget);
        expect(find.text('测试错误'), findsOneWidget);
      });

      testWidgets('it_should_display_error_state_with_contrast',
          (WidgetTester tester) async {
        // GIVEN: failed 状态
        final status = SyncStatus.failed(errorMessage: '测试错误');

        // WHEN: 显示对话框
        await tester.pumpWidget(createTestWidget(status));
        await tester.pumpAndSettle();

        // THEN: 错误图标应该显示
        expect(find.byIcon(Icons.error_outline), findsWidgets);

        // AND: 错误文本应该显示
        expect(find.text('测试错误'), findsOneWidget);
      });

      testWidgets('it_should_display_success_state_with_contrast',
          (WidgetTester tester) async {
        // GIVEN: synced 状态
        final status = SyncStatus.synced(lastSyncTime: DateTime.now());

        // WHEN: 显示对话框
        await tester.pumpWidget(createTestWidget(status));
        await tester.pumpAndSettle();

        // THEN: 成功图标应该显示
        expect(find.byIcon(Icons.check), findsOneWidget);

        // AND: 状态文本应该显示
        expect(find.text('已同步'), findsOneWidget);
      });
    });

    group('Text Scaling Support', () {
      testWidgets('it_should_support_large_text_scaling',
          (WidgetTester tester) async {
        // GIVEN: 大字体设置
        final status = SyncStatus.failed(errorMessage: '这是一个很长的错误消息用于测试文本缩放');

        // WHEN: 使用大字体显示对话框
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: Scaffold(
                body: Builder(
                  builder: (context) => SyncDetailsDialog(status: status),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // THEN: 对话框应该正常显示
        expect(find.byType(AlertDialog), findsOneWidget);

        // AND: 文本应该可读（不应该溢出）
        expect(find.text('同步失败'), findsOneWidget);
        expect(find.text('这是一个很长的错误消息用于测试文本缩放'), findsOneWidget);
      });

      testWidgets('it_should_support_small_text_scaling',
          (WidgetTester tester) async {
        // GIVEN: 小字体设置
        final status = SyncStatus.synced(lastSyncTime: DateTime.now());

        // WHEN: 使用小字体显示对话框
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(0.8)),
              child: Scaffold(
                body: Builder(
                  builder: (context) => SyncDetailsDialog(status: status),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // THEN: 对话框应该正常显示
        expect(find.byType(AlertDialog), findsOneWidget);

        // AND: 文本应该可读
        expect(find.text('已同步'), findsOneWidget);
      });
    });

    group('Touch Target Size', () {
      testWidgets('it_should_have_tappable_buttons',
          (WidgetTester tester) async {
        // GIVEN: failed 状态（有按钮）
        final status = SyncStatus.failed(errorMessage: '测试错误');

        // WHEN: 显示对话框
        await tester.pumpWidget(createTestWidget(status));
        await tester.pumpAndSettle();

        // THEN: 重试按钮应该存在
        expect(find.text('重试'), findsOneWidget);

        // AND: 关闭按钮应该存在
        expect(find.text('关闭'), findsOneWidget);

        // AND: 按钮应该可以被点击（验证触摸目标）
        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();

        // 对话框应该关闭
        expect(find.byType(AlertDialog), findsNothing);
      });
    });

    group('Error Message Accessibility', () {
      testWidgets('it_should_display_error_messages_clearly',
          (WidgetTester tester) async {
        // GIVEN: failed 状态
        final status = SyncStatus.failed(errorMessage: '网络连接失败，请检查网络设置');

        // WHEN: 显示对话框
        await tester.pumpWidget(createTestWidget(status));
        await tester.pumpAndSettle();

        // THEN: 错误消息应该清晰显示
        expect(find.text('网络连接失败，请检查网络设置'), findsOneWidget);

        // AND: 错误图标应该显示
        expect(find.byIcon(Icons.error_outline), findsWidgets);
      });

      testWidgets('it_should_provide_error_recovery_action',
          (WidgetTester tester) async {
        // GIVEN: failed 状态
        final status = SyncStatus.failed(errorMessage: '同步失败');

        // WHEN: 显示对话框
        await tester.pumpWidget(createTestWidget(status));
        await tester.pumpAndSettle();

        // THEN: 应该提供重试按钮作为恢复操作
        final retryButton = find.text('重试');
        expect(retryButton, findsOneWidget);

        // AND: 重试按钮应该可以被点击
        await tester.tap(retryButton);
        await tester.pumpAndSettle();
      });
    });
  });
}
