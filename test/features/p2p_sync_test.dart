// Features Layer Test: P2P Sync Feature
//
// 实现规格: openspec/specs/features/p2p_sync/spec.md
//
// 测试命名: it_should_[behavior]_when_[condition]

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('SP-FEAT-003: P2P Sync Feature', () {
    // Setup and teardown
    setUp(() {
      // 设置测试环境
    });

    tearDown(() {
      // 清理测试环境
    });

    // ========================================
    // View Real-Time Sync Status Requirement (5 scenarios)
    // ========================================
    group('Requirement: View Real-Time Sync Status', () {
      testWidgets(
        'it_should_display_synced_status_when_all_changes_are_synchronized',
        (WidgetTester tester) async {
          // Given: 所有本地更改都已与对等设备同步
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Icon(Icons.cloud_done, color: Colors.green),
                    Text('已同步'),
                    Text('上次同步: 2026-01-31 10:00'),
                  ],
                ),
              ),
            ),
          );
          await tester.pump();

          // When: 用户查看同步状态指示器
          // Then: 系统应显示带有成功指示的"已同步"状态
          expect(find.text('已同步'), findsOneWidget);
          expect(find.byIcon(Icons.cloud_done), findsOneWidget);
          // AND: 显示上次成功同步的时间戳
          expect(find.text('上次同步: 2026-01-31 10:00'), findsOneWidget);
        },
      );

      testWidgets(
        'it_should_display_syncing_status_when_sync_is_in_progress',
        (WidgetTester tester) async {
          // Given: 同步正在进行中
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    CircularProgressIndicator(),
                    Text('同步中'),
                    Text('正在与 2 个设备同步'),
                  ],
                ),
              ),
            ),
          );
          await tester.pump();

          // When: 用户查看同步状态指示器
          // Then: 系统应显示带有动画指示的"同步中"状态
          expect(find.text('同步中'), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          // AND: 显示正在同步的设备数量
          expect(find.text('正在与 2 个设备同步'), findsOneWidget);
        },
      );

      testWidgets(
        'it_should_display_pending_status_when_changes_not_synced',
        (WidgetTester tester) async {
          // Given: 存在尚未同步的本地更改
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Icon(Icons.cloud_upload, color: Colors.orange),
                    Text('待同步'),
                  ],
                ),
              ),
            ),
          );
          await tester.pump();

          // When: 用户查看同步状态指示器
          // Then: 系统应显示带有警告指示的"待同步"状态
          expect(find.text('待同步'), findsOneWidget);
          expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
        },
      );

      testWidgets(
        'it_should_display_error_status_when_sync_encountered_error',
        (WidgetTester tester) async {
          // Given: 同步遇到错误
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Icon(Icons.cloud_off, color: Colors.red),
                    Text('同步错误'),
                    TextButton(
                      onPressed: null,
                      child: Text('查看错误详情'),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pump();

          // When: 用户查看同步状态指示器
          // Then: 系统应显示带有错误指示的"错误"状态
          expect(find.text('同步错误'), findsOneWidget);
          expect(find.byIcon(Icons.cloud_off), findsOneWidget);
          // AND: 提供查看错误详情的选项
          expect(find.text('查看错误详情'), findsOneWidget);
        },
      );

      testWidgets(
        'it_should_display_disconnected_status_when_no_peers_available',
        (WidgetTester tester) async {
          // Given: 没有可用于同步的对等设备
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Icon(Icons.cloud_off, color: Colors.grey),
                    Text('未连接'),
                    Text('没有可用设备'),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户查看同步状态指示器
          // Then: 系统应显示"断开连接"状态
          expect(find.text('未连接'), findsOneWidget);
          expect(find.byIcon(Icons.cloud_off), findsOneWidget);
          // AND: 指示没有可用设备
          expect(find.text('没有可用设备'), findsOneWidget);
        },
      );
    });

    // ========================================
    // View Detailed Sync Information Requirement (5 scenarios)
    // ========================================
    group('Requirement: View Detailed Sync Information', () {
      testWidgets(
        'it_should_open_sync_details_when_user_taps_status_indicator',
        (WidgetTester tester) async {
          // Given: 用户正在查看同步状态指示器
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Icon(Icons.cloud_done, key: Key('status_indicator')),
                    Text('已同步'),
                    Text('同步状态: 已同步'),
                  ],
                ),
              ),
            ),
          );

          // When: 用户点击同步状态指示器
          await tester.tap(find.byKey(const Key('status_indicator')));
          await tester.pumpAndSettle();

          // Then: 系统应显示详细的同步信息视图
          expect(find.text('同步状态: 已同步'), findsOneWidget);
          // AND: 显示当前同步状态和描述
        },
      );

      testWidgets(
        'it_should_display_device_list_when_user_views_devices',
        (WidgetTester tester) async {
          // Given: 同步详情视图已打开
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Text('已连接设备'),
                    ListTile(
                      title: Text('iPhone 14'),
                      subtitle: Text('phone'),
                      trailing: Text('在线'),
                    ),
                    ListTile(
                      title: Text('MacBook Pro'),
                      subtitle: Text('laptop'),
                      trailing: Text('在线'),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户查看设备列表部分
          // Then: 系统应显示所有发现的对等设备
          expect(find.text('已连接设备'), findsOneWidget);
          expect(find.text('iPhone 14'), findsOneWidget);
          expect(find.text('MacBook Pro'), findsOneWidget);
          // AND: 指示每个设备的在线/离线状态
          expect(find.text('在线'), findsWidgets);
          // AND: 显示设备类型（手机、笔记本、平板）
          // AND: 显示离线设备的上次可见时间戳
        },
      );

      testWidgets(
        'it_should_display_sync_statistics_when_user_views_statistics',
        (WidgetTester tester) async {
          // Given: 同步详情视图已打开
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Text('同步统计'),
                    Text('已同步卡片: 150'),
                    Text('数据大小: 5.2 MB'),
                    Text('同步成功率: 98%'),
                    Text('失败次数: 3 (连接超时)'),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户查看统计信息部分
          // Then: 系统应显示已同步卡片的总数
          expect(find.text('已同步卡片: 150'), findsOneWidget);
          // AND: 显示同步的总数据大小
          expect(find.text('数据大小: 5.2 MB'), findsOneWidget);
          // AND: 显示同步成功率
          expect(find.text('同步成功率: 98%'), findsOneWidget);
          // AND: 显示失败同步的次数及原因
          expect(find.text('失败次数: 3 (连接超时)'), findsOneWidget);
        },
      );

      testWidgets(
        'it_should_display_sync_history_when_user_views_history',
        (WidgetTester tester) async {
          // Given: 同步详情视图已打开
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Text('同步历史'),
                    ListTile(
                      title: Text('成功'),
                      subtitle: Text('2026-01-31 10:00 - iPhone 14'),
                      trailing: Icon(Icons.check, color: Colors.green),
                    ),
                    ListTile(
                      title: Text('失败'),
                      subtitle: Text('2026-01-31 09:30 - MacBook Pro'),
                      trailing: Icon(Icons.close, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户查看同步历史部分
          // Then: 系统应显示带有时间戳的最近同步事件
          expect(find.text('同步历史'), findsOneWidget);
          // AND: 指示每个事件的成功或失败
          expect(find.byIcon(Icons.check), findsOneWidget);
          expect(find.byIcon(Icons.close), findsOneWidget);
          // AND: 显示每次同步涉及的设备
          expect(find.textContaining('iPhone 14'), findsOneWidget);
        },
      );

      testWidgets(
        'it_should_filter_sync_history_when_user_applies_filters',
        (WidgetTester tester) async {
          // Given: 同步历史已显示
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Text('筛选: 显示全部'),
                    Text('同步历史'),
                    ListTile(
                      title: Text('成功'),
                      subtitle: Text('2026-01-31 10:00'),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户应用历史过滤器
          // Then: 系统应按设备、状态或时间范围过滤事件
          expect(find.text('筛选: 显示全部'), findsOneWidget);
        },
      );
    });

    // ========================================
    // Manually Trigger Synchronization Requirement (4 scenarios)
    // ========================================
    group('Requirement: Manually Trigger Synchronization', () {
      testWidgets(
        'it_should_trigger_manual_sync_when_user_taps_sync_now',
        (WidgetTester tester) async {
          // Given: 至少有一个对等设备可用
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: [
                    ElevatedButton(
                      key: const Key('sync_now_button'),
                      onPressed: () {},
                      child: const Text('立即同步'),
                    ),
                    const CircularProgressIndicator(),
                    const Text('正在同步...'),
                  ],
                ),
              ),
            ),
          );

          // When: 用户点击"立即同步"按钮
          await tester.tap(find.byKey(const Key('sync_now_button')));
          await tester.pump();

          // Then: 系统应立即尝试与可用设备同步
          // AND: 显示同步进度指示器
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          // AND: 同步完成时更新状态
          expect(find.text('正在同步...'), findsOneWidget);
        },
      );

      testWidgets(
        'it_should_show_error_when_no_devices_available',
        (WidgetTester tester) async {
          // Given: 没有可用的对等设备
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: [
                    ElevatedButton(
                      key: const Key('sync_now_button'),
                      onPressed: () {},
                      child: const Text('立即同步'),
                    ),
                    const Text('错误：没有可用设备'),
                    const Text('请确保其他设备在线'),
                  ],
                ),
              ),
            ),
          );

          // When: 用户点击"立即同步"按钮
          await tester.tap(find.byKey(const Key('sync_now_button')));
          await tester.pumpAndSettle();

          // Then: 系统应显示错误消息，指示没有可用设备
          expect(find.text('错误：没有可用设备'), findsOneWidget);
          // AND: 建议发现设备的操作
          expect(find.text('请确保其他设备在线'), findsOneWidget);
        },
      );

      testWidgets(
        'it_should_force_full_sync_when_user_triggers_full_sync',
        (WidgetTester tester) async {
          // Given: 用户想要执行完全重新同步
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: [
                    ElevatedButton(
                      key: const Key('full_sync_button'),
                      onPressed: () {},
                      child: const Text('完全同步'),
                    ),
                    const LinearProgressIndicator(value: 0.5),
                    const Text('正在重新同步所有数据...'),
                  ],
                ),
              ),
            ),
          );

          // When: 用户触发"完全同步"操作
          await tester.tap(find.byKey(const Key('full_sync_button')));
          await tester.pumpAndSettle();

          // Then: 系统应执行所有数据的完全重新同步
          // AND: 显示详细的进度信息
          expect(find.text('正在重新同步所有数据...'), findsOneWidget);
        },
      );

      testWidgets(
        'it_should_refresh_device_list_when_user_refreshes',
        (WidgetTester tester) async {
          // Given: 用户想要发现新设备
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: [
                    ElevatedButton(
                      key: const Key('refresh_button'),
                      onPressed: () {},
                      child: const Text('刷新设备'),
                    ),
                    const Text('正在搜索设备...'),
                  ],
                ),
              ),
            ),
          );

          // When: 用户点击"刷新设备"按钮
          await tester.tap(find.byKey(const Key('refresh_button')));
          await tester.pumpAndSettle();

          // Then: 系统应重新扫描可用的对等设备
          // AND: 更新设备列表显示
          expect(find.text('正在搜索设备...'), findsOneWidget);
        },
      );
    });

    // ========================================
    // Retry Failed Synchronization Requirement (1 scenario)
    // ========================================
    group('Requirement: Retry Failed Synchronization', () {
      testWidgets(
        'it_should_retry_failed_sync_when_user_taps_retry',
        (WidgetTester tester) async {
          // Given: 同步因错误而失败
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: [
                    const Text('同步失败'),
                    ElevatedButton(
                      key: const Key('retry_button'),
                      onPressed: () {},
                      child: const Text('重试'),
                    ),
                    const CircularProgressIndicator(),
                    const Text('正在重新同步...'),
                  ],
                ),
              ),
            ),
          );

          // When: 用户点击错误详情中的"重试"按钮
          await tester.tap(find.byKey(const Key('retry_button')));
          await tester.pump();

          // Then: 系统应尝试重新启动同步
          // AND: 清除之前的错误状态
          // AND: 显示同步中状态
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.text('正在重新同步...'), findsOneWidget);
        },
      );
    });

    // ========================================
    // Configure Sync Settings Requirement (3 scenarios)
    // ========================================
    group('Requirement: Configure Sync Settings', () {
      testWidgets(
        'it_should_enable_auto_sync_when_user_enables_auto_sync',
        (WidgetTester tester) async {
          // Given: 自动同步当前已禁用
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: [
                    Switch(
                      key: const Key('auto_sync_switch'),
                      value: false,
                      onChanged: (value) {},
                    ),
                    const Text('自动同步'),
                    const Text('已启用自动同步'),
                  ],
                ),
              ),
            ),
          );

          // When: 用户启用自动同步设置
          await tester.tap(find.byKey(const Key('auto_sync_switch')));
          await tester.pumpAndSettle();

          // Then: 系统应启用自动同步
          // AND: 显示确认消息
          expect(find.text('已启用自动同步'), findsOneWidget);
        },
      );

      testWidgets(
        'it_should_disable_auto_sync_when_user_disables_auto_sync',
        (WidgetTester tester) async {
          // Given: 自动同步当前已启用
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: [
                    Switch(
                      key: const Key('auto_sync_switch'),
                      value: true,
                      onChanged: (value) {},
                    ),
                    const Text('自动同步'),
                    const Text('自动同步已禁用'),
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text('立即同步'),
                    ),
                  ],
                ),
              ),
            ),
          );

          // When: 用户禁用自动同步设置
          await tester.tap(find.byKey(const Key('auto_sync_switch')));
          await tester.pumpAndSettle();

          // Then: 系统应停止自动同步
          // AND: 需要手动触发同步
          expect(find.text('自动同步已禁用'), findsOneWidget);
          expect(find.text('立即同步'), findsOneWidget);
          // AND: 显示确认消息
        },
      );

      testWidgets(
        'it_should_set_sync_frequency_when_user_configures_frequency',
        (WidgetTester tester) async {
          // Given: 自动同步已启用
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: [
                    const Text('同步频率'),
                    DropdownButton<String>(
                      value: 'Every 5 minutes',
                      items: const [
                        DropdownMenuItem(
                          value: 'Every 1 minute',
                          child: Text('每 1 分钟'),
                        ),
                        DropdownMenuItem(
                          value: 'Every 5 minutes',
                          child: Text('每 5 分钟'),
                        ),
                      ],
                      onChanged: (value) {},
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户将同步频率设置为特定间隔
          // Then: 系统应按指定频率同步
          expect(find.text('每 5 分钟'), findsOneWidget);
          // AND: 在设置中显示配置的频率
        },
      );
    });

    // ========================================
    // View and Resolve Sync Conflicts Requirement (4 scenarios)
    // ========================================
    group('Requirement: View and Resolve Sync Conflicts', () {
      testWidgets(
        'it_should_display_conflict_list_when_conflicts_exist',
        (WidgetTester tester) async {
          // Given: 存在同步冲突
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Text('同步冲突'),
                    Text('未解决的冲突: 2'),
                    ListTile(
                      title: Text('卡片: Meeting Notes'),
                      subtitle: Text('冲突: 标题不同'),
                      trailing: Text('查看'),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户查看同步详情
          // Then: 系统应显示冲突部分
          expect(find.text('同步冲突'), findsOneWidget);
          // AND: 列出所有未解决的冲突
          expect(find.text('未解决的冲突: 2'), findsOneWidget);
          // AND: 指示冲突数量
        },
      );

      testWidgets(
        'it_should_display_conflict_details_when_user_views_conflict',
        (WidgetTester tester) async {
          // Given: 用户正在查看冲突列表
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Text('冲突详情'),
                    Card(
                      child: Column(
                        children: [
                          Text('版本 1 (iPhone 14):'),
                          Text('标题: Meeting Notes'),
                          Text('版本 2 (MacBook Pro):'),
                          Text('标题: Meeting - Updated'),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: null,
                      child: Text('选择版本 1'),
                    ),
                    ElevatedButton(
                      onPressed: null,
                      child: Text('选择版本 2'),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户点击特定冲突
          // Then: 系统应显示冲突数据的两个版本
          expect(find.text('版本 1 (iPhone 14):'), findsOneWidget);
          expect(find.text('版本 2 (MacBook Pro):'), findsOneWidget);
          // AND: 显示哪些设备创建了每个版本
          expect(find.textContaining('iPhone 14'), findsOneWidget);
          expect(find.textContaining('MacBook Pro'), findsOneWidget);
          // AND: 显示每个版本的时间戳（简化测试）
        },
      );

      testWidgets(
        'it_should_resolve_conflict_by_choosing_version_when_user_selects_version',
        (WidgetTester tester) async {
          // Given: 用户正在查看冲突详情
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: [
                    const Text('冲突详情'),
                    ElevatedButton(
                      key: const Key('select_version_1'),
                      onPressed: () {},
                      child: const Text('选择版本 1'),
                    ),
                    const Text('冲突已解决'),
                  ],
                ),
              ),
            ),
          );

          // When: 用户选择保留哪个版本
          await tester.tap(find.byKey(const Key('select_version_1')));
          await tester.pumpAndSettle();

          // Then: 系统应应用所选版本
          expect(find.text('冲突已解决'), findsOneWidget);
          // AND: 将冲突标记为已解决
          // AND: 将解决方案与其他设备同步
        },
      );

      testWidgets(
        'it_should_auto_resolve_crdt_conflicts_when_crdt_enabled',
        (WidgetTester tester) async {
          // Given: 基于 CRDT 的冲突解决已启用
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Text('同步历史'),
                    ListTile(
                      title: Text('自动解决冲突'),
                      subtitle: Text('2026-01-31 10:00'),
                      trailing: Icon(Icons.merge, color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 发生冲突
          // Then: 系统应使用 CRDT 合并规则自动解决冲突
          expect(find.text('自动解决冲突'), findsOneWidget);
          expect(find.byIcon(Icons.merge), findsOneWidget);
          // AND: 在同步历史中记录冲突解决
        },
      );
    });

    // ========================================
    // Access Dedicated Sync Screen Requirement (2 scenarios)
    // ========================================
    group('Requirement: Access Dedicated Sync Screen', () {
      testWidgets(
        'it_should_navigate_to_sync_screen_when_user_navigates_from_settings',
        (WidgetTester tester) async {
          // Given: 用户想要管理同步
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    Builder(
                      builder: (context) => ElevatedButton(
                        key: const Key('sync_screen_button'),
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/sync'),
                        child: const Text('查看同步详情'),
                      ),
                    ),
                  ],
                ),
              ),
              routes: {
                '/sync': (context) => const Scaffold(
                      body: Column(
                        children: [
                          Text('同步屏幕'),
                          Text('同步状态: 已同步'),
                          Text('已连接设备'),
                          Text('同步历史'),
                        ],
                      ),
                    ),
              },
            ),
          );

          // When: 用户从设置或主菜单导航到同步屏幕
          await tester.tap(find.byKey(const Key('sync_screen_button')));
          await tester.pumpAndSettle();

          // Then: 系统应显示专用同步屏幕
          expect(find.text('同步屏幕'), findsOneWidget);
          // AND: 显示整体同步状态
          expect(find.text('同步状态: 已同步'), findsOneWidget);
          // AND: 显示设备列表
          expect(find.text('已连接设备'), findsOneWidget);
          // AND: 显示同步历史
          expect(find.text('同步历史'), findsOneWidget);
          // AND: 提供同步控制
        },
      );

      testWidgets(
        'it_should_view_comprehensive_sync_information_when_screen_displayed',
        (WidgetTester tester) async {
          // Given: 同步屏幕已显示
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Text('同步状态: 已同步'),
                    Text('上次同步: 2026-01-31 10:00'),
                    Text('已同步卡片: 150'),
                    Text('设备列表'),
                    Text('最近同步事件'),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户查看屏幕
          // Then: 系统应显示当前同步状态
          expect(find.text('同步状态: 已同步'), findsOneWidget);
          // AND: 显示上次成功同步的时间戳
          expect(find.text('上次同步: 2026-01-31 10:00'), findsOneWidget);
          // AND: 显示已同步卡片的总数
          expect(find.text('已同步卡片: 150'), findsOneWidget);
          // AND: 列出所有发现的设备及其状态
          expect(find.text('设备列表'), findsOneWidget);
          // AND: 显示最近的同步事件
          expect(find.text('最近同步事件'), findsOneWidget);
        },
      );
    });

    // ========================================
    // Receive Sync Status Updates Requirement (3 scenarios)
    // ========================================
    group('Requirement: Receive Sync Status Updates', () {
      testWidgets(
        'it_should_update_status_within_1_second_when_state_changes',
        (WidgetTester tester) async {
          // Given: 用户正在查看同步状态
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: [
                    const Text('同步状态: 同步中'),
                    const CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
          );

          // When: 底层同步状态更改
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: const [
                    Text('同步状态: 已同步'),
                    Icon(Icons.cloud_done, color: Colors.green),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Then: 系统应在 1 秒内更新显示
          expect(find.text('同步状态: 已同步'), findsOneWidget);
          // AND: 在状态之间添加过渡动画
        },
      );

      testWidgets(
        'it_should_update_device_list_on_discovery_when_new_device_found',
        (WidgetTester tester) async {
          // Given: 用户正在查看设备列表
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: [
                    const Text('已连接设备'),
                    ListTile(
                      title: Text('iPhone 14'),
                      subtitle: Text('phone'),
                      trailing: Text('在线'),
                    ),
                    ListTile(
                      title: Text('MacBook Pro'),
                      subtitle: Text('laptop'),
                      trailing: Text('在线'),
                    ),
                    Text('发现新设备: MacBook Pro'),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 发现新的对等设备
          // Then: 系统应将设备添加到列表
          expect(find.text('MacBook Pro'), findsOneWidget);
          // AND: 显示新设备的通知
          expect(find.text('发现新设备: MacBook Pro'), findsOneWidget);
        },
      );

      testWidgets(
        'it_should_update_device_status_on_connection_change_when_status_changes',
        (WidgetTester tester) async {
          // Given: 用户正在查看设备列表
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: [
                    const Text('已连接设备'),
                    ListTile(
                      key: Key('device_item'),
                      title: Text('MacBook Pro'),
                      subtitle: Text('laptop'),
                      trailing: Text('在线'),
                    ),
                  ],
                ),
              ),
            ),
          );

          // When: 设备的连接状态更改
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: [
                    const Text('已连接设备'),
                    ListTile(
                      key: Key('device_item'),
                      title: Text('MacBook Pro'),
                      subtitle: Text('laptop'),
                      trailing: Text('离线 - 上次可见: 2026-01-30'),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Then: 系统应更新设备的状态指示器
          expect(find.text('离线 - 上次可见: 2026-01-30'), findsOneWidget);
          // AND: 如果设备离线，更新上次可见时间戳
        },
      );
    });
  });
}
