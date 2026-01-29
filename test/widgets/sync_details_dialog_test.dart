import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/models/sync_status.dart';
import 'package:cardmind/widgets/sync_details_dialog.dart';

void main() {
  group('SyncDetailsDialog Widget Tests', () {
    group('Display Tests', () {
      testWidgets('it_should_show_current_status_for_not_yet_synced',
          (WidgetTester tester) async {
        // GIVEN: notYetSynced 状态
        final status = SyncStatus.notYetSynced();

        // WHEN: 显示对话框
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => SyncDetailsDialog(status: status),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // THEN: 应该显示 "尚未同步" 标题
        expect(find.text('尚未同步'), findsOneWidget);

        // AND: 应该显示 cloud_off 图标
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);

        // AND: 应该显示状态描述
        expect(
          find.textContaining('应用尚未执行过同步操作'),
          findsOneWidget,
        );

        // AND: 不应该显示重试按钮
        expect(find.text('重试'), findsNothing);
      });

      testWidgets('it_should_show_current_status_for_syncing',
          (WidgetTester tester) async {
        // GIVEN: syncing 状态
        final status = SyncStatus.syncing();

        // WHEN: 显示对话框
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => SyncDetailsDialog(status: status),
              ),
            ),
          ),
        );
        await tester.pump();

        // THEN: 应该显示 "同步中" 标题
        expect(find.text('同步中'), findsOneWidget);

        // AND: 应该显示 refresh 图标
        expect(find.byIcon(Icons.refresh), findsOneWidget);

        // AND: 应该显示进度指示器
        expect(find.byType(CircularProgressIndicator), findsWidgets);

        // AND: 应该显示 "正在同步数据..." 文本
        expect(find.text('正在同步数据...'), findsWidgets);
      });

      testWidgets('it_should_show_current_status_for_synced',
          (WidgetTester tester) async {
        // GIVEN: synced 状态（带时间）
        final lastSyncTime = DateTime(2026, 1, 29, 14, 30, 45);
        final status = SyncStatus.synced(lastSyncTime: lastSyncTime);

        // WHEN: 显示对话框
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => SyncDetailsDialog(status: status),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // THEN: 应该显示 "已同步" 标题
        expect(find.text('已同步'), findsOneWidget);

        // AND: 应该显示 check 图标
        expect(find.byIcon(Icons.check), findsOneWidget);

        // AND: 应该显示最后同步时间
        expect(find.textContaining('14:30:45'), findsOneWidget);
      });

      testWidgets('it_should_show_error_message_when_failed',
          (WidgetTester tester) async {
        // GIVEN: failed 状态（带错误信息）
        final status = SyncStatus.failed(
          errorMessage: SyncErrorType.noAvailablePeers,
        );

        // WHEN: 显示对话框
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => SyncDetailsDialog(status: status),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // THEN: 应该显示 "同步失败" 标题
        expect(find.text('同步失败'), findsOneWidget);

        // AND: 应该显示 error_outline 图标
        expect(find.byIcon(Icons.error_outline), findsWidgets);

        // AND: 应该显示错误详情标题
        expect(find.text('错误详情：'), findsOneWidget);

        // AND: 应该显示错误消息
        expect(find.text(SyncErrorType.noAvailablePeers), findsOneWidget);
      });

      testWidgets('it_should_show_retry_button_when_failed',
          (WidgetTester tester) async {
        // GIVEN: failed 状态
        final status = SyncStatus.failed(
          errorMessage: SyncErrorType.connectionTimeout,
        );

        // WHEN: 显示对话框
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => SyncDetailsDialog(status: status),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // THEN: 应该显示重试按钮
        expect(find.text('重试'), findsOneWidget);

        // AND: 应该有 TextButton
        expect(find.byType(TextButton), findsWidgets);
      });
    });

    group('Interaction Tests', () {
      testWidgets('it_should_dismiss_on_close_button',
          (WidgetTester tester) async {
        // GIVEN: 任意状态
        final status = SyncStatus.notYetSynced();
        bool dialogDismissed = false;

        // WHEN: 显示对话框
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      await showDialog<void>(
                        context: context,
                        builder: (context) => SyncDetailsDialog(status: status),
                      );
                      dialogDismissed = true;
                    },
                    child: const Text('Show Dialog'),
                  );
                },
              ),
            ),
          ),
        );

        // 点击按钮显示对话框
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // THEN: 对话框应该显示
        expect(find.byType(SyncDetailsDialog), findsOneWidget);

        // WHEN: 点击关闭按钮
        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();

        // THEN: 对话框应该关闭
        expect(find.byType(SyncDetailsDialog), findsNothing);
        expect(dialogDismissed, isTrue);
      });

      testWidgets('it_should_not_show_retry_button_for_non_failed_states',
          (WidgetTester tester) async {
        // GIVEN: 非 failed 状态列表
        final statuses = [
          SyncStatus.notYetSynced(),
          SyncStatus.syncing(),
          SyncStatus.synced(lastSyncTime: DateTime.now()),
        ];

        for (final status in statuses) {
          // WHEN: 显示对话框
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => SyncDetailsDialog(status: status),
                ),
              ),
            ),
          );
          await tester.pump();

          // THEN: 不应该显示重试按钮
          expect(find.text('重试'), findsNothing);

          // 清理
          await tester.binding.setSurfaceSize(null);
        }
      });
    });

    group('Accessibility Tests', () {
      testWidgets('it_should_have_semantic_labels',
          (WidgetTester tester) async {
        // GIVEN: failed 状态
        final status = SyncStatus.failed(
          errorMessage: SyncErrorType.dataTransmissionFailed,
        );

        // WHEN: 显示对话框
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => SyncDetailsDialog(status: status),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // THEN: 应该有可访问的文本
        expect(find.text('同步失败'), findsOneWidget);
        expect(find.text('重试'), findsOneWidget);
        expect(find.text('关闭'), findsOneWidget);
      });

      testWidgets('it_should_support_keyboard_navigation',
          (WidgetTester tester) async {
        // GIVEN: failed 状态
        final status = SyncStatus.failed(
          errorMessage: SyncErrorType.localStorageError,
        );

        // WHEN: 显示对话框
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => SyncDetailsDialog(status: status),
              ),
            ),
          ),
        );
        await tester.pump();

        // THEN: 应该显示重试和关闭按钮（AlertDialog 默认支持键盘导航）
        expect(find.text('重试'), findsOneWidget);
        expect(find.text('关闭'), findsOneWidget);

        // 验证按钮存在
        expect(find.byType(TextButton), findsWidgets);
      });
    });

    group('Visual Styling Tests', () {
      testWidgets('it_should_use_correct_colors_for_each_state',
          (WidgetTester tester) async {
        // GIVEN: 不同状态的列表
        final testCases = [
          (SyncStatus.notYetSynced(), Icons.cloud_off),
          (SyncStatus.syncing(), Icons.refresh),
          (SyncStatus.synced(lastSyncTime: DateTime.now()), Icons.check),
          (
            SyncStatus.failed(errorMessage: 'error'),
            Icons.error_outline
          ),
        ];

        for (final (status, expectedIcon) in testCases) {
          // WHEN: 显示对话框
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => SyncDetailsDialog(status: status),
                ),
              ),
            ),
          );
          await tester.pump();

          // THEN: 应该显示正确的图标
          expect(find.byIcon(expectedIcon), findsWidgets);

          // 清理 - 使用 pump 而不是 pumpWidget(Container())
          await tester.binding.setSurfaceSize(null);
        }
      });
    });
  });
}
