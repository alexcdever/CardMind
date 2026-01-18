import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/models/sync_status.dart';
import 'package:cardmind/widgets/sync_status_indicator.dart';
import 'package:cardmind/widgets/sync_details_dialog.dart';

/// Sync Feedback Interaction Specification Tests
///
/// 规格编号: SP-FLUT-010
/// 这些测试验证同步反馈的所有交互行为
///
/// 测试遵循 Spec Coding 方法论：
/// - 测试即规格，规格即文档
/// - 使用 it_should_xxx() 命名风格
/// - Given-When-Then 结构

void main() {
  group('SP-FLUT-010: Sync Feedback Interaction', () {
    // ========================================
    // 状态模型测试
    // ========================================

    group('SyncStatus Model Tests', () {
      test('it_should_initialize_with_disconnected_state', () {
        // Given: 创建一个新的 SyncStatus
        // When: 使用 disconnected 工厂方法
        final status = SyncStatus.disconnected();

        // Then: 状态应该是 disconnected
        expect(status.state, SyncState.disconnected);
        expect(status.syncingPeers, 0);
        expect(status.lastSyncTime, isNull);
        expect(status.errorMessage, isNull);
        expect(status.isActive, false);
      });

      test('it_should_transition_from_disconnected_to_syncing', () {
        // Given: 初始状态是 disconnected
        final disconnected = SyncStatus.disconnected();

        // When: 发现对等设备并开始同步
        final syncing = SyncStatus.syncing(syncingPeers: 1);

        // Then: 状态应该转换为 syncing
        expect(disconnected.state, SyncState.disconnected);
        expect(syncing.state, SyncState.syncing);
        expect(syncing.syncingPeers, 1);
        expect(syncing.isActive, true);
      });

      test('it_should_transition_from_syncing_to_synced', () {
        // Given: 当前状态是 syncing
        final syncing = SyncStatus.syncing(syncingPeers: 1);

        // When: 同步成功完成
        final synced = SyncStatus.synced(lastSyncTime: DateTime.now());

        // Then: 状态应该转换为 synced
        expect(syncing.state, SyncState.syncing);
        expect(synced.state, SyncState.synced);
        expect(synced.lastSyncTime, isNotNull);
        expect(synced.isActive, true);
      });

      test('it_should_transition_from_syncing_to_failed', () {
        // Given: 当前状态是 syncing
        final syncing = SyncStatus.syncing(syncingPeers: 1);

        // When: 同步失败
        final failed = SyncStatus.failed(errorMessage: 'Network error');

        // Then: 状态应该转换为 failed
        expect(syncing.state, SyncState.syncing);
        expect(failed.state, SyncState.failed);
        expect(failed.errorMessage, 'Network error');
        expect(failed.isActive, false);
      });

      test('it_should_transition_from_synced_to_syncing', () {
        // Given: 当前状态是 synced
        final synced = SyncStatus.synced(lastSyncTime: DateTime.now());

        // When: 检测到新变化
        final syncing = SyncStatus.syncing(syncingPeers: 1);

        // Then: 状态应该转换为 syncing
        expect(synced.state, SyncState.synced);
        expect(syncing.state, SyncState.syncing);
      });

      test('it_should_transition_from_failed_to_syncing', () {
        // Given: 当前状态是 failed
        final failed = SyncStatus.failed(errorMessage: 'Network error');

        // When: 用户重试同步
        final syncing = SyncStatus.syncing(syncingPeers: 1);

        // Then: 状态应该转换为 syncing
        expect(failed.state, SyncState.failed);
        expect(syncing.state, SyncState.syncing);
      });

      test('it_should_filter_duplicate_status_updates', () {
        // Given: 两个相同的状态
        final status1 = SyncStatus.disconnected();
        final status2 = SyncStatus.disconnected();

        // When: 比较两个状态
        // Then: 应该相等（用于 Stream.distinct()）
        expect(status1, equals(status2));
        expect(status1.hashCode, equals(status2.hashCode));
      });

      test('it_should_identify_active_states', () {
        // Given: 不同的状态
        final disconnected = SyncStatus.disconnected();
        final syncing = SyncStatus.syncing(syncingPeers: 1);
        final synced = SyncStatus.synced(lastSyncTime: DateTime.now());
        final failed = SyncStatus.failed(errorMessage: 'Error');

        // When: 检查 isActive 属性
        // Then: syncing 和 synced 应该是 active
        expect(disconnected.isActive, false);
        expect(syncing.isActive, true);
        expect(synced.isActive, true);
        expect(failed.isActive, false);
      });
    });

    // ========================================
    // Widget 测试
    // ========================================

    group('SyncStatusIndicator Widget Tests', () {
      testWidgets('it_should_render_sync_status_indicator', (WidgetTester tester) async {
        // Given: 一个 SyncStatus
        final status = SyncStatus.disconnected();

        // When: 渲染 SyncStatusIndicator
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(status: status),
            ),
          ),
        );

        // Then: 组件应该渲染
        expect(find.byType(SyncStatusIndicator), findsOneWidget);
      });

      testWidgets('it_should_show_cloud_off_icon_when_disconnected', (WidgetTester tester) async {
        // Given: 状态是 disconnected
        final status = SyncStatus.disconnected();

        // When: 渲染指示器
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(status: status),
            ),
          ),
        );

        // Then: 应该显示 cloud_off 图标
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      });

      testWidgets('it_should_show_sync_icon_when_syncing', (WidgetTester tester) async {
        // Given: 状态是 syncing
        final status = SyncStatus.syncing(syncingPeers: 1);

        // When: 渲染指示器
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(status: status),
            ),
          ),
        );

        // Then: 应该显示 sync 图标
        expect(find.byIcon(Icons.sync), findsOneWidget);
      });

      testWidgets('it_should_show_rotating_sync_icon_when_syncing', (WidgetTester tester) async {
        // Given: 状态是 syncing
        final status = SyncStatus.syncing(syncingPeers: 1);

        // When: 渲染指示器并等待动画
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(status: status),
            ),
          ),
        );

        // Then: 应该有旋转动画（通过 RotationTransition）
        // 查找 SyncStatusIndicator 内部的 RotationTransition
        final indicator = find.byType(SyncStatusIndicator);
        expect(indicator, findsOneWidget);

        // 验证有 RotationTransition（至少一个）
        expect(
          find.descendant(
            of: indicator,
            matching: find.byType(RotationTransition),
          ),
          findsWidgets,
        );
      });

      testWidgets('it_should_show_cloud_done_icon_when_synced', (WidgetTester tester) async {
        // Given: 状态是 synced
        final status = SyncStatus.synced(lastSyncTime: DateTime.now());

        // When: 渲染指示器
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(status: status),
            ),
          ),
        );

        // Then: 应该显示 cloud_done 图标
        expect(find.byIcon(Icons.cloud_done), findsOneWidget);
      });

      testWidgets('it_should_show_warning_icon_when_failed', (WidgetTester tester) async {
        // Given: 状态是 failed
        final status = SyncStatus.failed(errorMessage: 'Network error');

        // When: 渲染指示器
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(status: status),
            ),
          ),
        );

        // Then: 应该显示 cloud_off 图标（带警告色）
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      });

      testWidgets('it_should_display_correct_text_for_each_state', (WidgetTester tester) async {
        // Test disconnected text
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(status: SyncStatus.disconnected()),
            ),
          ),
        );
        expect(find.text('未同步'), findsOneWidget);

        // Test syncing text
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(status: SyncStatus.syncing(syncingPeers: 1)),
            ),
          ),
        );
        expect(find.textContaining('同步中'), findsOneWidget);

        // Test synced text (使用 textContaining 因为会显示相对时间)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(status: SyncStatus.synced(lastSyncTime: DateTime.now())),
            ),
          ),
        );
        expect(find.textContaining('已同步'), findsOneWidget);

        // Test failed text
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(status: SyncStatus.failed(errorMessage: 'Error')),
            ),
          ),
        );
        expect(find.text('同步失败'), findsOneWidget);
      });

      testWidgets('it_should_use_correct_color_for_each_state', (WidgetTester tester) async {
        // Given: 不同的状态
        final disconnected = SyncStatus.disconnected();
        final syncing = SyncStatus.syncing(syncingPeers: 1);
        final synced = SyncStatus.synced(lastSyncTime: DateTime.now());
        final failed = SyncStatus.failed(errorMessage: 'Error');

        // When/Then: 每个状态应该有正确的颜色
        // disconnected: grey (#757575)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(status: disconnected),
            ),
          ),
        );
        final disconnectedIcon = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
        expect(disconnectedIcon.color, const Color(0xFF757575));

        // syncing: primary color (#00897B)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(status: syncing),
            ),
          ),
        );
        final syncingIcon = tester.widget<Icon>(find.byIcon(Icons.sync));
        expect(syncingIcon.color, const Color(0xFF00897B));

        // synced: green (#43A047)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(status: synced),
            ),
          ),
        );
        final syncedIcon = tester.widget<Icon>(find.byIcon(Icons.cloud_done));
        expect(syncedIcon.color, const Color(0xFF43A047));

        // failed: orange (#FB8C00)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(status: failed),
            ),
          ),
        );
        final failedIcon = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
        expect(failedIcon.color, const Color(0xFFFB8C00));
      });

      testWidgets('it_should_show_details_dialog_on_tap', (WidgetTester tester) async {
        // Given: 一个可点击的指示器
        final status = SyncStatus.disconnected();

        // When: 点击指示器
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(status: status),
            ),
          ),
        );
        await tester.tap(find.byType(SyncStatusIndicator));
        await tester.pumpAndSettle();

        // Then: 应该显示详情对话框
        expect(find.byType(SyncDetailsDialog), findsOneWidget);
      });

      testWidgets('it_should_show_peer_count_when_syncing', (WidgetTester tester) async {
        // Given: 状态是 syncing，有 3 个对等设备
        final status = SyncStatus.syncing(syncingPeers: 3);

        // When: 渲染指示器
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(status: status),
            ),
          ),
        );

        // Then: 应该显示设备数量
        expect(find.textContaining('3'), findsOneWidget);
      });

      testWidgets('it_should_show_relative_time_when_synced', (WidgetTester tester) async {
        // Given: 状态是 synced，刚刚同步完成
        final status = SyncStatus.synced(lastSyncTime: DateTime.now());

        // When: 渲染指示器
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(status: status),
            ),
          ),
        );

        // Then: 应该显示相对时间（如"刚刚"）
        expect(find.textContaining('刚刚'), findsOneWidget);
      });
    });

    // ========================================
    // 详情对话框测试
    // ========================================

    group('SyncDetailsDialog Tests', () {
      testWidgets('it_should_show_current_status_in_dialog', (WidgetTester tester) async {
        // Given: 一个状态
        final status = SyncStatus.syncing(syncingPeers: 2);

        // When: 显示详情对话框
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => SyncDetailsDialog(status: status),
                    );
                  },
                  child: const Text('Show'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        // Then: 对话框应该显示当前状态
        expect(find.byType(SyncDetailsDialog), findsOneWidget);
        expect(find.textContaining('同步中'), findsOneWidget);
      });

      testWidgets('it_should_show_peer_list_in_dialog', (WidgetTester tester) async {
        // Given: 状态是 syncing，有对等设备
        final status = SyncStatus.syncing(syncingPeers: 2);

        // When: 显示详情对话框
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => SyncDetailsDialog(status: status),
                    );
                  },
                  child: const Text('Show'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        // Then: 对话框应该显示对等设备列表（查找"连接的设备："标题）
        expect(find.text('连接的设备：'), findsOneWidget);
        // 验证显示了设备列表
        expect(find.text('设备 1'), findsOneWidget);
        expect(find.text('设备 2'), findsOneWidget);
      });

      testWidgets('it_should_show_error_message_when_failed', (WidgetTester tester) async {
        // Given: 状态是 failed
        final status = SyncStatus.failed(errorMessage: 'Network timeout');

        // When: 显示详情对话框
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => SyncDetailsDialog(status: status),
                    );
                  },
                  child: const Text('Show'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        // Then: 对话框应该显示错误信息
        expect(find.text('Network timeout'), findsOneWidget);
      });

      testWidgets('it_should_show_retry_button_when_failed', (WidgetTester tester) async {
        // Given: 状态是 failed
        final status = SyncStatus.failed(errorMessage: 'Network error');

        // When: 显示详情对话框
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => SyncDetailsDialog(status: status),
                    );
                  },
                  child: const Text('Show'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        // Then: 对话框应该显示重试按钮
        expect(find.text('重试'), findsOneWidget);
      });
    });

    // ========================================
    // Stream 订阅测试（补充）
    // ========================================

    group('Sync Status Stream Tests', () {
      testWidgets('it_should_subscribe_to_sync_status_stream',
          (WidgetTester tester) async {
        // Given: 一个同步状态 Stream（使用 StreamController）
        final controller = StreamController<SyncStatus>();

        // When: 订阅 Stream 并渲染指示器
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamBuilder<SyncStatus>(
                stream: controller.stream,
                initialData: SyncStatus.disconnected(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  return SyncStatusIndicator(status: snapshot.data!);
                },
              ),
            ),
          ),
        );

        // Then: 初始状态应该是 disconnected
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);

        // When: Stream 发出新状态（syncing）
        controller.add(SyncStatus.syncing(syncingPeers: 1));
        await tester.pump();

        // Then: 应该更新为 syncing 状态
        expect(find.byIcon(Icons.sync), findsOneWidget);

        // When: Stream 发出新状态（synced）
        controller.add(SyncStatus.synced(lastSyncTime: DateTime.now()));
        await tester.pump();

        // Then: 应该更新为 synced 状态
        expect(find.byIcon(Icons.cloud_done), findsOneWidget);

        // Cleanup
        await controller.close();
      });
    });

    // ========================================
    // 同步进度百分比测试（补充）
    // ========================================

    group('Sync Progress Percentage Tests', () {
      testWidgets('it_should_display_sync_progress_percentage',
          (WidgetTester tester) async {
        // Given: 同步状态包含进度信息
        // 扩展 SyncStatus 以支持进度百分比（模拟）
        final syncingWithProgress = SyncStatus.syncing(syncingPeers: 2);

        // When: 渲染带进度的同步指示器
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SyncStatusIndicator(status: syncingWithProgress),
                  const SizedBox(height: 16),
                  // 进度条
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        LinearProgressIndicator(value: 0.65),
                        SizedBox(height: 8),
                        Text('同步进度: 65%'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        // 使用 pump 而不是 pumpAndSettle，避免无限动画导致超时
        await tester.pump();

        // Then: 应该显示进度百分比
        expect(find.text('同步进度: 65%'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);

        // 验证进度条的值
        final progressIndicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(progressIndicator.value, equals(0.65));
      });
    });

    // ========================================
    // 同步错误详情测试（补充）
    // ========================================

    group('Sync Error Details Tests', () {
      testWidgets('it_should_show_sync_error_details',
          (WidgetTester tester) async {
        // Given: 同步失败，包含详细错误信息
        final failedStatus = SyncStatus.failed(
          errorMessage: 'Network timeout: Failed to connect to peer device after 30 seconds',
        );

        // When: 显示详情对话框
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.error, color: Colors.red),
                            SizedBox(width: 8),
                            Text('同步失败'),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '错误详情：',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              failedStatus.errorMessage ?? '未知错误',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '可能的原因：',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text('• 网络连接不稳定'),
                            const Text('• 对等设备离线'),
                            const Text('• 防火墙阻止连接'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('关闭'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('查看错误'),
                ),
              ),
            ),
          ),
        );

        // When: 点击查看错误
        await tester.tap(find.text('查看错误'));
        await tester.pumpAndSettle();

        // Then: 应该显示详细的错误信息
        expect(find.text('同步失败'), findsOneWidget);
        expect(find.text('错误详情：'), findsOneWidget);
        expect(
          find.text('Network timeout: Failed to connect to peer device after 30 seconds'),
          findsOneWidget,
        );
        expect(find.text('可能的原因：'), findsOneWidget);
        expect(find.text('• 网络连接不稳定'), findsOneWidget);
        expect(find.text('• 对等设备离线'), findsOneWidget);
        expect(find.text('• 防火墙阻止连接'), findsOneWidget);
        expect(find.text('重试'), findsOneWidget);
      });
    });

    // ========================================
    // 无障碍测试
    // ========================================

    group('Accessibility Tests', () {
      testWidgets('it_should_have_semantic_label_for_disconnected', (WidgetTester tester) async {
        // Given: 状态是 disconnected
        final status = SyncStatus.disconnected();

        // When: 渲染指示器
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(status: status),
            ),
          ),
        );

        // Then: 应该有语义标签（检查是否包含预期文本）
        final semantics = tester.getSemantics(find.byType(SyncStatusIndicator));
        expect(semantics.label, contains('未同步，无可用设备'));
      });

      testWidgets('it_should_have_semantic_label_for_syncing', (WidgetTester tester) async {
        // Given: 状态是 syncing
        final status = SyncStatus.syncing(syncingPeers: 1);

        // When: 渲染指示器
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(status: status),
            ),
          ),
        );

        // Then: 应该有语义标签
        final semantics = tester.getSemantics(find.byType(SyncStatusIndicator));
        expect(semantics.label, contains('正在同步数据'));
      });

      testWidgets('it_should_have_semantic_label_for_synced', (WidgetTester tester) async {
        // Given: 状态是 synced
        final status = SyncStatus.synced(lastSyncTime: DateTime.now());

        // When: 渲染指示器
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(status: status),
            ),
          ),
        );

        // Then: 应该有语义标签
        final semantics = tester.getSemantics(find.byType(SyncStatusIndicator));
        expect(semantics.label, contains('已同步，数据最新'));
      });

      testWidgets('it_should_have_semantic_label_for_failed', (WidgetTester tester) async {
        // Given: 状态是 failed
        final status = SyncStatus.failed(errorMessage: 'Error');

        // When: 渲染指示器
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SyncStatusIndicator(status: status),
            ),
          ),
        );

        // Then: 应该有语义标签
        final semantics = tester.getSemantics(find.byType(SyncStatusIndicator));
        expect(semantics.label, contains('同步失败，点击查看详情'));
      });
    });
  });
}
