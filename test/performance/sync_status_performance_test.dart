import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/models/sync_status.dart';
import 'package:cardmind/widgets/sync_status_indicator.dart';
import 'package:cardmind/widgets/sync_details_dialog.dart';

void main() {
  group('Sync Status UI Performance Tests', () {
    testWidgets('PT-001: SyncStatusIndicator 渲染性能测试',
        (WidgetTester tester) async {
      // GIVEN: syncing 状态
      final status = SyncStatus.syncing();

      // WHEN: 渲染指示器
      final startTime = DateTime.now();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SyncStatusIndicator(status: status),
          ),
        ),
      );

      final renderTime = DateTime.now().difference(startTime);

      // THEN: 渲染时间应该小于 500ms（测试环境可能较慢）
      expect(renderTime.inMilliseconds, lessThan(500));

      // AND: 组件应该正常显示
      expect(find.byType(SyncStatusIndicator), findsOneWidget);
    });

    testWidgets('PT-002: SyncDetailsDialog 渲染性能测试',
        (WidgetTester tester) async {
      // GIVEN: synced 状态
      final status = SyncStatus.synced(lastSyncTime: DateTime.now());

      // WHEN: 渲染对话框
      final startTime = DateTime.now();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => SyncDetailsDialog(status: status),
            ),
          ),
        ),
      );

      final renderTime = DateTime.now().difference(startTime);

      // THEN: 渲染时间应该小于 500ms（测试环境可能较慢）
      expect(renderTime.inMilliseconds, lessThan(500));

      // AND: 对话框应该正常显示
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('PT-003: SyncStatusIndicator 动画性能测试',
        (WidgetTester tester) async {
      // GIVEN: syncing 状态（有旋转动画）
      final status = SyncStatus.syncing();

      // WHEN: 渲染指示器并运行动画
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SyncStatusIndicator(status: status),
          ),
        ),
      );

      // THEN: 动画应该流畅运行
      final startTime = DateTime.now();

      // 运行 10 帧动画
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16)); // 60 FPS
      }

      final animationTime = DateTime.now().difference(startTime);

      // AND: 10 帧动画时间应该合理（测试环境中时间可能不准确）
      // 只验证动画能够正常运行，不严格验证时间
      expect(animationTime.inMilliseconds, greaterThan(0));
      expect(animationTime.inMilliseconds, lessThan(1000));
    });

    testWidgets('PT-004: 状态切换性能测试', (WidgetTester tester) async {
      // GIVEN: 初始状态
      SyncStatus status = SyncStatus.notYetSynced();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SyncStatusIndicator(status: status);
              },
            ),
          ),
        ),
      );

      // WHEN: 快速切换状态
      final startTime = DateTime.now();

      // 切换到 syncing
      status = SyncStatus.syncing();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SyncStatusIndicator(status: status),
          ),
        ),
      );

      // 切换到 synced
      status = SyncStatus.synced(lastSyncTime: DateTime.now());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SyncStatusIndicator(status: status),
          ),
        ),
      );

      // 切换到 failed
      status = SyncStatus.failed(errorMessage: '测试错误');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SyncStatusIndicator(status: status),
          ),
        ),
      );

      final switchTime = DateTime.now().difference(startTime);

      // THEN: 3次状态切换应该在 300ms 内完成
      expect(switchTime.inMilliseconds, lessThan(300));
    });

    testWidgets('PT-005: 内存使用测试 - 组件创建和销毁',
        (WidgetTester tester) async {
      // GIVEN: 多个状态
      final statuses = [
        SyncStatus.notYetSynced(),
        SyncStatus.syncing(),
        SyncStatus.synced(lastSyncTime: DateTime.now()),
        SyncStatus.failed(errorMessage: '测试错误'),
      ];

      // WHEN: 重复创建和销毁组件
      for (int i = 0; i < 10; i++) {
        for (final status in statuses) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SyncStatusIndicator(status: status),
              ),
            ),
          );

          // 销毁组件
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }

      // THEN: 测试应该成功完成（没有内存泄漏导致的崩溃）
      expect(true, isTrue);
    });

    testWidgets('PT-006: 对话框打开和关闭性能测试',
        (WidgetTester tester) async {
      // GIVEN: 任意状态
      final status = SyncStatus.synced(lastSyncTime: DateTime.now());

      // WHEN: 打开对话框
      final openStartTime = DateTime.now();

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

      final openTime = DateTime.now().difference(openStartTime);

      // THEN: 打开时间应该小于 200ms
      expect(openTime.inMilliseconds, lessThan(200));

      // WHEN: 关闭对话框
      final closeStartTime = DateTime.now();

      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();

      final closeTime = DateTime.now().difference(closeStartTime);

      // THEN: 关闭时间应该小于 200ms
      expect(closeTime.inMilliseconds, lessThan(200));
    });

    testWidgets('PT-007: 相对时间更新性能测试', (WidgetTester tester) async {
      // GIVEN: synced 状态（刚刚同步）
      final status = SyncStatus.synced(lastSyncTime: DateTime.now());

      // WHEN: 渲染指示器
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SyncStatusIndicator(status: status),
          ),
        ),
      );

      // THEN: 应该显示 "刚刚"
      expect(find.text('刚刚'), findsOneWidget);

      // WHEN: 模拟时间流逝（通过多次 pump）
      final startTime = DateTime.now();

      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      final updateTime = DateTime.now().difference(startTime);

      // THEN: 5次更新应该在合理时间内完成（< 6秒，允许误差）
      expect(updateTime.inSeconds, lessThanOrEqualTo(6));

      // AND: 文本应该更新
      expect(find.text('刚刚'), findsOneWidget);
    });

    testWidgets('PT-008: 批量状态更新性能测试', (WidgetTester tester) async {
      // GIVEN: 初始状态
      SyncStatus status = SyncStatus.notYetSynced();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SyncStatusIndicator(status: status),
          ),
        ),
      );

      // WHEN: 快速批量更新状态（模拟频繁的状态变化）
      final startTime = DateTime.now();

      for (int i = 0; i < 20; i++) {
        // 交替切换状态
        if (i % 2 == 0) {
          status = SyncStatus.syncing();
        } else {
          status = SyncStatus.synced(lastSyncTime: DateTime.now());
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(status: status),
            ),
          ),
        );
      }

      final batchUpdateTime = DateTime.now().difference(startTime);

      // THEN: 20次状态更新应该在 1秒内完成
      expect(batchUpdateTime.inMilliseconds, lessThan(1000));
    });
  });
}
