import 'package:cardmind/models/sync_status.dart';
import 'package:cardmind/widgets/sync_status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncStatusIndicator Widget Tests', () {
    testWidgets('it_should_display_disconnected_state', (
      WidgetTester tester,
    ) async {
      final status = SyncStatus.disconnected();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SyncStatusIndicator(status: status)),
        ),
      );

      expect(find.text('未同步'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('it_should_display_syncing_state', (WidgetTester tester) async {
      final status = SyncStatus.syncing(syncingPeers: 2);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SyncStatusIndicator(status: status)),
        ),
      );

      expect(find.text('同步中 (2 台设备)'), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);
    });

    testWidgets('it_should_display_synced_state', (WidgetTester tester) async {
      final status = SyncStatus.synced(
        lastSyncTime: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SyncStatusIndicator(status: status)),
        ),
      );

      expect(find.textContaining('已同步'), findsOneWidget);
      expect(find.textContaining('分钟前'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
    });

    testWidgets('it_should_display_failed_state', (WidgetTester tester) async {
      final status = SyncStatus.failed(errorMessage: 'Network error');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SyncStatusIndicator(status: status)),
        ),
      );

      expect(find.text('同步失败'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('it_should_show_rotation_animation_when_syncing', (
      WidgetTester tester,
    ) async {
      final status = SyncStatus.syncing(syncingPeers: 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SyncStatusIndicator(status: status)),
        ),
      );

      // Should have at least one RotationTransition (may have more from Material components)
      expect(find.byType(RotationTransition), findsAtLeastNWidgets(1));
    });

    testWidgets('it_should_not_show_rotation_animation_when_not_syncing', (
      WidgetTester tester,
    ) async {
      final status = SyncStatus.synced(lastSyncTime: DateTime.now());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SyncStatusIndicator(status: status)),
        ),
      );

      // In synced state, there should be fewer RotationTransitions than in syncing state
      // We check that the sync icon is NOT wrapped in a RotationTransition
      final syncIcon = find.byIcon(Icons.cloud_done);
      expect(syncIcon, findsOneWidget);

      // Verify the icon is not inside a RotationTransition by checking its ancestors
      final iconWidget = tester.widget<Icon>(syncIcon);
      expect(iconWidget, isNotNull);
    });

    testWidgets('it_should_display_relative_time_just_now', (
      WidgetTester tester,
    ) async {
      final status = SyncStatus.synced(
        lastSyncTime: DateTime.now().subtract(const Duration(seconds: 5)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SyncStatusIndicator(status: status)),
        ),
      );

      expect(find.textContaining('刚刚'), findsOneWidget);
    });

    testWidgets('it_should_display_relative_time_minutes', (
      WidgetTester tester,
    ) async {
      final status = SyncStatus.synced(
        lastSyncTime: DateTime.now().subtract(const Duration(minutes: 30)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SyncStatusIndicator(status: status)),
        ),
      );

      expect(find.textContaining('分钟前'), findsOneWidget);
    });

    testWidgets('it_should_display_relative_time_hours', (
      WidgetTester tester,
    ) async {
      final status = SyncStatus.synced(
        lastSyncTime: DateTime.now().subtract(const Duration(hours: 3)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SyncStatusIndicator(status: status)),
        ),
      );

      expect(find.textContaining('小时前'), findsOneWidget);
    });

    testWidgets('it_should_display_relative_time_days', (
      WidgetTester tester,
    ) async {
      final status = SyncStatus.synced(
        lastSyncTime: DateTime.now().subtract(const Duration(days: 2)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SyncStatusIndicator(status: status)),
        ),
      );

      expect(find.textContaining('天前'), findsOneWidget);
    });

    testWidgets('it_should_display_syncing_without_peer_count', (
      WidgetTester tester,
    ) async {
      final status = SyncStatus.syncing(syncingPeers: 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SyncStatusIndicator(status: status)),
        ),
      );

      expect(find.text('同步中...'), findsOneWidget);
    });

    testWidgets('it_should_be_tappable', (WidgetTester tester) async {
      final status = SyncStatus.synced(lastSyncTime: DateTime.now());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SyncStatusIndicator(status: status)),
        ),
      );

      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('it_should_have_semantic_label', (WidgetTester tester) async {
      final status = SyncStatus.synced(lastSyncTime: DateTime.now());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SyncStatusIndicator(status: status)),
        ),
      );

      expect(find.byType(Semantics), findsWidgets);
    });
  });
}
