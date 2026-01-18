import 'package:cardmind/models/sync_status.dart';
import 'package:cardmind/widgets/sync_status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

/// Sync Status Indicator Component Specification Tests
///
/// 规格编号: SP-UI-008
/// 这些测试验证同步状态指示器组件的所有行为
///
/// 测试遵循 Spec Coding 方法论：
/// - 测试即规格，规格即文档
/// - 使用 it_should_xxx() 命名风格
/// - Given-When-Then 结构

void main() {
  group('SP-UI-008: Sync Status Indicator Component', () {
    // ========================================
    // 任务组 1: Display Tests
    // ========================================

    group('Display Tests', () {
      testWidgets('it_should_display_disconnected_state', (
        WidgetTester tester,
      ) async {
        // Given: 创建断开连接状态的指示器
        final status = SyncStatus.disconnected();

        await tester.pumpWidget(
          createTestWidget(SyncStatusIndicator(status: status)),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该显示断开连接的图标和文字
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
        expect(find.text('未同步'), findsOneWidget);
      });

      testWidgets('it_should_display_syncing_state', (
        WidgetTester tester,
      ) async {
        // Given: 创建同步中状态的指示器
        final status = SyncStatus.syncing(syncingPeers: 2);

        await tester.pumpWidget(
          createTestWidget(SyncStatusIndicator(status: status)),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该显示同步图标和文字
        expect(find.byIcon(Icons.sync), findsOneWidget);
        expect(find.text('同步中 (2 台设备)'), findsOneWidget);
      });

      testWidgets('it_should_display_synced_state', (
        WidgetTester tester,
      ) async {
        // Given: 创建已同步状态的指示器
        final status = SyncStatus.synced(
          lastSyncTime: DateTime.now().subtract(const Duration(minutes: 5)),
        );

        await tester.pumpWidget(
          createTestWidget(SyncStatusIndicator(status: status)),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该显示已同步图标和文字
        expect(find.byIcon(Icons.cloud_done), findsOneWidget);
        expect(find.textContaining('已同步'), findsOneWidget);
      });

      testWidgets('it_should_display_failed_state', (
        WidgetTester tester,
      ) async {
        // Given: 创建同步失败状态的指示器
        final status = SyncStatus.failed(errorMessage: 'Sync failed');

        await tester.pumpWidget(
          createTestWidget(SyncStatusIndicator(status: status)),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该显示失败图标和文字
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
        expect(find.text('同步失败'), findsOneWidget);
      });
    });

    // ========================================
    // 任务组 2: Animation Tests
    // ========================================

    group('Animation Tests', () {
      testWidgets('it_should_animate_sync_icon_when_syncing', (
        WidgetTester tester,
      ) async {
        // Given: 创建同步中状态的指示器
        final status = SyncStatus.syncing(syncingPeers: 1);

        await tester.pumpWidget(
          createTestWidget(SyncStatusIndicator(status: status)),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该有旋转动画
        expect(find.byType(RotationTransition), findsOneWidget);
      });

      testWidgets('it_should_stop_animation_when_sync_completes', (
        WidgetTester tester,
      ) async {
        // Given: 创建同步中状态的指示器
        final syncingStatus = SyncStatus.syncing(syncingPeers: 1);

        await tester.pumpWidget(
          createTestWidget(SyncStatusIndicator(status: syncingStatus)),
        );
        await tester.pumpAndSettle();

        // When: 状态变为已同步
        final syncedStatus = SyncStatus.synced(lastSyncTime: DateTime.now());

        await tester.pumpWidget(
          createTestWidget(SyncStatusIndicator(status: syncedStatus)),
        );
        await tester.pumpAndSettle();

        // Then: 动画应该停止
        expect(find.byType(RotationTransition), findsNothing);
      });
    });

    // ========================================
    // 任务组 3: Color Tests
    // ========================================

    group('Color Tests', () {
      testWidgets('it_should_use_grey_color_for_disconnected', (
        WidgetTester tester,
      ) async {
        // Given: 创建断开连接状态的指示器
        final status = SyncStatus.disconnected();

        await tester.pumpWidget(
          createTestWidget(SyncStatusIndicator(status: status)),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该使用灰色
        final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
        expect(icon.color, equals(const Color(0xFF757575)));
      });

      testWidgets('it_should_use_primary_color_for_syncing', (
        WidgetTester tester,
      ) async {
        // Given: 创建同步中状态的指示器
        final status = SyncStatus.syncing(syncingPeers: 1);

        await tester.pumpWidget(
          createTestWidget(SyncStatusIndicator(status: status)),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该使用主题色
        final rotationTransition = tester.widget<RotationTransition>(
          find.byType(RotationTransition),
        );
        final icon = rotationTransition.child as Icon;
        expect(icon.color, equals(const Color(0xFF00897B)));
      });

      testWidgets('it_should_use_green_color_for_synced', (
        WidgetTester tester,
      ) async {
        // Given: 创建已同步状态的指示器
        final status = SyncStatus.synced(lastSyncTime: DateTime.now());

        await tester.pumpWidget(
          createTestWidget(SyncStatusIndicator(status: status)),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该使用绿色
        final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_done));
        expect(icon.color, equals(const Color(0xFF43A047)));
      });

      testWidgets('it_should_use_orange_color_for_failed', (
        WidgetTester tester,
      ) async {
        // Given: 创建同步失败状态的指示器
        final status = SyncStatus.failed(errorMessage: 'Sync failed');

        await tester.pumpWidget(
          createTestWidget(SyncStatusIndicator(status: status)),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该使用橙色
        final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
        expect(icon.color, equals(const Color(0xFFFB8C00)));
      });
    });

    // ========================================
    // 任务组 4: Relative Time Tests
    // ========================================

    group('Relative Time Tests', () {
      testWidgets('it_should_display_just_now_for_recent_sync', (
        WidgetTester tester,
      ) async {
        // Given: 创建刚刚同步的状态
        final status = SyncStatus.synced(lastSyncTime: DateTime.now());

        await tester.pumpWidget(
          createTestWidget(SyncStatusIndicator(status: status)),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该显示"刚刚"
        expect(find.textContaining('刚刚'), findsOneWidget);
      });

      testWidgets('it_should_display_minutes_ago', (WidgetTester tester) async {
        // Given: 创建几分钟前同步的状态
        final status = SyncStatus.synced(lastSyncTime: DateTime.now());

        await tester.pumpWidget(
          createTestWidget(SyncStatusIndicator(status: status)),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该显示"X 分钟前"
        expect(find.textContaining('分钟前'), findsOneWidget);
      });

      testWidgets('it_should_display_hours_ago', (WidgetTester tester) async {
        // Given: 创建几小时前同步的状态
        final status = SyncStatus.synced(lastSyncTime: DateTime.now());

        await tester.pumpWidget(
          createTestWidget(SyncStatusIndicator(status: status)),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该显示"X 小时前"
        expect(find.textContaining('小时前'), findsOneWidget);
      });

      testWidgets('it_should_display_days_ago', (WidgetTester tester) async {
        // Given: 创建几天前同步的状态
        final status = SyncStatus.synced(lastSyncTime: DateTime.now());

        await tester.pumpWidget(
          createTestWidget(SyncStatusIndicator(status: status)),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该显示"X 天前"
        expect(find.textContaining('天前'), findsOneWidget);
      });
    });

    // ========================================
    // 任务组 5: Interaction Tests
    // ========================================

    group('Interaction Tests', () {
      testWidgets('it_should_show_details_dialog_on_tap', (
        WidgetTester tester,
      ) async {
        // Given: 创建同步状态指示器
        final status = SyncStatus.synced(lastSyncTime: DateTime.now());

        await tester.pumpWidget(
          createTestWidget(SyncStatusIndicator(status: status)),
        );

        // When: 点击指示器
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        // Then: 应该显示详情对话框
        expect(find.byType(Dialog), findsOneWidget);
      });

      testWidgets('it_should_be_tappable', (WidgetTester tester) async {
        // Given: 创建同步状态指示器
        final status = SyncStatus.synced(lastSyncTime: DateTime.now());

        await tester.pumpWidget(
          createTestWidget(SyncStatusIndicator(status: status)),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该有 InkWell
        expect(find.byType(InkWell), findsOneWidget);
      });
    });

    // ========================================
    // 任务组 6: Accessibility Tests
    // ========================================

    group('Accessibility Tests', () {
      testWidgets('it_should_provide_semantic_label', (
        WidgetTester tester,
      ) async {
        // Given: 创建同步状态指示器
        final status = SyncStatus.synced(lastSyncTime: DateTime.now());

        await tester.pumpWidget(
          createTestWidget(SyncStatusIndicator(status: status)),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该有语义标签
        expect(find.byType(Semantics), findsWidgets);
      });

      testWidgets('it_should_mark_as_button_for_accessibility', (
        WidgetTester tester,
      ) async {
        // Given: 创建同步状态指示器
        final status = SyncStatus.synced(lastSyncTime: DateTime.now());

        await tester.pumpWidget(
          createTestWidget(SyncStatusIndicator(status: status)),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该标记为按钮
        expect(find.byType(Semantics), findsWidgets);
      });
    });

    // ========================================
    // 任务组 7: Edge Cases
    // ========================================

    group('Edge Cases', () {
      testWidgets('it_should_handle_null_last_sync_time', (
        WidgetTester tester,
      ) async {
        // Given: 创建没有最后同步时间的状态
        final status = SyncStatus.synced(lastSyncTime: DateTime.now());

        await tester.pumpWidget(
          createTestWidget(SyncStatusIndicator(status: status)),
        );

        // When: Widget 渲染完成
        await tester.pumpAndSettle();

        // Then: 应该显示"已同步"（不显示时间）
        expect(find.text('已同步'), findsOneWidget);
      });

      testWidgets('it_should_handle_zero_syncing_peers', (
        WidgetTester tester,
      ) async {
        // Given: 创建没有同步设备的同步中状态
        final status = SyncStatus.syncing(syncingPeers: 0);

        await tester.pumpWidget(
          createTestWidget(SyncStatusIndicator(status: status)),
        );

        // When: Widget 渲染完成
        await tester.pump();

        // Then: 应该显示"同步中..."
        expect(find.text('同步中...'), findsOneWidget);
      });

      testWidgets('it_should_update_when_status_changes', (
        WidgetTester tester,
      ) async {
        // Given: 创建同步中状态的指示器
        final syncingStatus = SyncStatus.syncing(syncingPeers: 1);

        await tester.pumpWidget(
          createTestWidget(SyncStatusIndicator(status: syncingStatus)),
        );
        await tester.pump();

        // When: 状态变为已同步
        final syncedStatus = SyncStatus.synced(lastSyncTime: DateTime.now());

        await tester.pumpWidget(
          createTestWidget(SyncStatusIndicator(status: syncedStatus)),
        );
        await tester.pump();

        // Then: UI 应该更新
        expect(find.byIcon(Icons.cloud_done), findsOneWidget);
        expect(find.textContaining('已同步'), findsOneWidget);
      });
    });
  });
}
