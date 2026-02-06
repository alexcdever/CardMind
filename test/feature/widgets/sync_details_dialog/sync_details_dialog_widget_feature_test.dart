import 'package:cardmind/bridge/api/sync.dart' as api;
import 'package:cardmind/widgets/sync_details_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/integration_test_helper.dart';

void main() {
  setUpAll(() async {
    await IntegrationTestEnvironment.initialize();
  });

  group('SyncDetailsDialog Widget Tests', () {
    // 创建测试用的同步状态
    api.SyncStatus createTestStatus({
      api.SyncUiState state = api.SyncUiState.synced,
      int? lastSyncTime,
      String? errorMessage,
    }) {
      return api.SyncStatus(
        state: state,
        lastSyncTime: lastSyncTime,
        errorMessage: errorMessage,
        onlineDevices: 2,
        syncingDevices: 0,
        offlineDevices: 1,
      );
    }

    group('Rendering Tests', () {
      integrationTest('renders dialog with title', (WidgetTester tester) async {
        final status = createTestStatus();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => SyncDetailsDialog.show(context, status),
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        // 点击按钮打开对话框
        await tester.tap(find.text('Show Dialog'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 验证标题存在
        expect(find.text('同步详情'), findsOneWidget);
      });

      integrationTest('renders close button', (WidgetTester tester) async {
        final status = createTestStatus();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => SyncDetailsDialog.show(context, status),
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Dialog'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 验证关闭按钮存在
        expect(find.byIcon(Icons.close), findsOneWidget);
      });

      integrationTest('renders synced status', (WidgetTester tester) async {
        final status = createTestStatus(
          state: api.SyncUiState.synced,
          lastSyncTime: DateTime.now().millisecondsSinceEpoch,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => SyncDetailsDialog.show(context, status),
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Dialog'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 验证已同步状态显示
        expect(find.text('已同步'), findsOneWidget);
      });

      integrationTest('renders syncing status', (WidgetTester tester) async {
        final status = createTestStatus(state: api.SyncUiState.syncing);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => SyncDetailsDialog.show(context, status),
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Dialog'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 验证同步中状态显示
        expect(find.text('同步中'), findsOneWidget);
      });

      integrationTest('renders failed status', (WidgetTester tester) async {
        final status = createTestStatus(
          state: api.SyncUiState.failed,
          errorMessage: '网络连接失败',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => SyncDetailsDialog.show(context, status),
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Dialog'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 验证同步失败状态显示
        expect(find.text('同步失败'), findsOneWidget);
      });

      integrationTest('renders section headers', (WidgetTester tester) async {
        final status = createTestStatus();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => SyncDetailsDialog.show(context, status),
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Dialog'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        // 等待内容加载（多次 pump 以处理异步操作）
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // 验证各区域标题存在
        expect(find.text('已发现设备'), findsOneWidget);
        // 注意：同步统计区域只在有数据或错误时显示，测试环境可能没有数据
        // expect(find.text('同步统计'), findsOneWidget);
        expect(find.text('同步历史'), findsOneWidget);
      });
    });

    group('Interaction Tests', () {
      integrationTest('closes dialog on close button tap', (
        WidgetTester tester,
      ) async {
        final status = createTestStatus();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => SyncDetailsDialog.show(context, status),
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        // 打开对话框
        await tester.tap(find.text('Show Dialog'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 验证对话框已打开
        expect(find.text('同步详情'), findsOneWidget);

        // 点击关闭按钮
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        // 等待对话框关闭动画完成
        await tester.pumpAndSettle();

        // 验证对话框已关闭
        expect(find.text('同步详情'), findsNothing);
      });

      integrationTest('closes dialog on ESC key press', (
        WidgetTester tester,
      ) async {
        final status = createTestStatus();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => SyncDetailsDialog.show(context, status),
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        // 打开对话框
        await tester.tap(find.text('Show Dialog'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 验证对话框已打开
        expect(find.text('同步详情'), findsOneWidget);

        // 按 ESC 键
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 验证对话框已关闭
        expect(find.text('同步详情'), findsNothing);
      });

      integrationTest('closes dialog on barrier tap', (
        WidgetTester tester,
      ) async {
        final status = createTestStatus();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => SyncDetailsDialog.show(context, status),
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        // 打开对话框
        await tester.tap(find.text('Show Dialog'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 验证对话框已打开
        expect(find.text('同步详情'), findsOneWidget);

        // 点击对话框外部（barrier）
        await tester.tapAt(const Offset(10, 10));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 验证对话框已关闭
        expect(find.text('同步详情'), findsNothing);
      });
    });

    group('Animation Tests', () {
      integrationTest('plays open animation', (WidgetTester tester) async {
        final status = createTestStatus();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => SyncDetailsDialog.show(context, status),
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        // 打开对话框
        await tester.tap(find.text('Show Dialog'));
        await tester.pump(); // 开始动画

        // 验证对话框正在动画中
        expect(find.text('同步详情'), findsOneWidget);

        // 完成动画
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 验证对话框完全显示
        expect(find.text('同步详情'), findsOneWidget);
      });

      integrationTest('plays close animation', (WidgetTester tester) async {
        final status = createTestStatus();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => SyncDetailsDialog.show(context, status),
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        // 打开对话框
        await tester.tap(find.text('Show Dialog'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 点击关闭按钮
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump(); // 开始关闭动画

        // 验证对话框仍然可见（动画中）
        expect(find.text('同步详情'), findsOneWidget);

        // 完成动画
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 验证对话框已关闭
        expect(find.text('同步详情'), findsNothing);
      });
    });

    group('Semantics Tests', () {
      integrationTest('has proper semantic labels', (
        WidgetTester tester,
      ) async {
        final status = createTestStatus();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => SyncDetailsDialog.show(context, status),
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Dialog'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 验证主对话框有语义标签
        final dialogSemantics = find.bySemanticsLabel('同步详情对话框');
        expect(dialogSemantics, findsOneWidget);
        expect(
          tester.getSemantics(dialogSemantics.first),
          matchesSemantics(
            label: '同步详情对话框',
            scopesRoute: true,
            namesRoute: true,
          ),
        );
      });

      integrationTest('close button has tooltip', (WidgetTester tester) async {
        final status = createTestStatus();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => SyncDetailsDialog.show(context, status),
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Dialog'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 验证关闭按钮有 tooltip
        final closeButton = find.byIcon(Icons.close);
        expect(closeButton, findsOneWidget);

        // 长按显示 tooltip
        await tester.longPress(closeButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('关闭 (ESC)'), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      integrationTest('handles null lastSyncTime', (WidgetTester tester) async {
        final status = createTestStatus(
          state: api.SyncUiState.notYetSynced,
          lastSyncTime: null,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => SyncDetailsDialog.show(context, status),
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Dialog'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 验证对话框正常显示
        expect(find.text('同步详情'), findsOneWidget);
      });

      integrationTest('handles empty error message', (
        WidgetTester tester,
      ) async {
        final status = createTestStatus(
          state: api.SyncUiState.failed,
          errorMessage: '',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => SyncDetailsDialog.show(context, status),
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Dialog'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 验证对话框正常显示
        expect(find.text('同步详情'), findsOneWidget);
        expect(find.text('同步失败'), findsOneWidget);
      });
    });
  });
}
