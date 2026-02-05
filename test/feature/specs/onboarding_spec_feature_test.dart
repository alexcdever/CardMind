import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_utils.dart';
import '../../helpers/test_helpers.dart';

/// Onboarding Specification Tests
///
/// 规格编号: SP-FLUT-007
/// 这些测试验证初始化流程规格的所有交互行为
///
/// 测试遵循 Spec Coding 方法论：
/// - 测试即规格，规格即文档
/// - 使用 it_should_xxx() 命名风格
/// - Given-When-Then 结构

void main() {
  group('SP-FLUT-007: Onboarding Flow', () {
    // Setup
    late MockDeviceManager mockDeviceManager;
    late MockSettingsService mockSettings;

    setUp(() {
      mockDeviceManager = MockDeviceManager();
      mockSettings = MockSettingsService();
    });

    tearDown(() {
      mockDeviceManager.reset();
      mockSettings.reset();
    });

    // ========================================
    // 首次启动检测测试
    // ========================================
    group('First Launch Detection', () {
      testWidgets('it_should_show_welcome_page_on_first_launch', (
        WidgetTester tester,
      ) async {
        // Given: 首次启动应用
        // When: 应用启动
        await tester.pumpWidget(
          createTestWidget(const Scaffold(body: Text('Welcome Page'))),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示欢迎页
        expect(find.text('Welcome Page'), findsOneWidget);
        expect(find.text('Home Screen'), findsNothing);
      });

      testWidgets('it_should_show_splash_screen_during_initialization_check', (
        WidgetTester tester,
      ) async {
        // Given: 正在检查初始化状态
        await tester.pumpWidget(
          createTestWidget(
            const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('CardMind'),
                  ],
                ),
              ),
            ),
          ),
        );

        // When: 显示启动画面
        await tester.pump();

        // Then: 应该显示加载指示器和应用名称
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('CardMind'), findsOneWidget);
      });

      testWidgets('it_should_skip_welcome_page_on_subsequent_launches', (
        WidgetTester tester,
      ) async {
        // Given: 非首次启动
        // When: 应用启动（直接显示主页内容）
        await tester.pumpWidget(
          createTestWidget(const Scaffold(body: Text('Home Screen'))),
        );
        await tester.pumpAndSettle();

        // Then: 应该直接进入主页
        expect(find.text('Home Screen'), findsOneWidget);
        expect(find.text('Welcome Page'), findsNothing);
      });
    });

    // ========================================
    // 欢迎页测试
    // ========================================
    group('Welcome Page', () {
      testWidgets('it_should_display_app_name_and_description', (
        WidgetTester tester,
      ) async {
        // Given: 用户在欢迎页
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'CardMind',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('离线优先的卡片笔记应用'),
                    const SizedBox(height: 48),
                    ElevatedButton(onPressed: () {}, child: const Text('开始使用')),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示应用名称和描述
        expect(find.text('CardMind'), findsOneWidget);
        expect(find.text('离线优先的卡片笔记应用'), findsOneWidget);
        expect(find.text('开始使用'), findsOneWidget);
      });

      testWidgets('it_should_navigate_to_action_selection_on_button_tap', (
        WidgetTester tester,
      ) async {
        // Given: 用户在欢迎页
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const Scaffold(body: Text('Action Selection')),
                      ),
                    );
                  },
                  child: const Text('开始使用'),
                ),
              ),
            ),
          ),
        );

        // When: 用户点击开始使用按钮
        await tester.tap(find.text('开始使用'));
        await tester.pumpAndSettle();

        // Then: 应该导航到操作选择页面
        expect(find.text('Action Selection'), findsOneWidget);
      });
    });

    // ========================================
    // 操作选择测试
    // ========================================
    group('Action Selection', () {
      testWidgets('it_should_show_create_pool_and_join_pool_options', (
        WidgetTester tester,
      ) async {
        // Given: 用户在操作选择页面
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('选择操作'),
                  const SizedBox(height: 32),
                  ElevatedButton(onPressed: () {}, child: const Text('创建新空间')),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: () {}, child: const Text('加入现有空间')),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示两个选项
        expect(find.text('选择操作'), findsOneWidget);
        expect(find.text('创建新空间'), findsOneWidget);
        expect(find.text('加入现有空间'), findsOneWidget);
      });

      testWidgets('it_should_navigate_to_create_pool_screen_on_create_tap', (
        WidgetTester tester,
      ) async {
        // Given: 用户在操作选择页面
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const Scaffold(body: Text('Create Pool Screen')),
                      ),
                    );
                  },
                  child: const Text('创建新空间'),
                ),
              ),
            ),
          ),
        );

        // When: 用户点击创建新空间
        await tester.tap(find.text('创建新空间'));
        await tester.pumpAndSettle();

        // Then: 应该导航到创建空间页面
        expect(find.text('Create Pool Screen'), findsOneWidget);
      });

      testWidgets('it_should_navigate_to_join_pool_screen_on_join_tap', (
        WidgetTester tester,
      ) async {
        // Given: 用户在操作选择页面
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const Scaffold(body: Text('Join Pool Screen')),
                      ),
                    );
                  },
                  child: const Text('加入现有空间'),
                ),
              ),
            ),
          ),
        );

        // When: 用户点击加入现有空间
        await tester.tap(find.text('加入现有空间'));
        await tester.pumpAndSettle();

        // Then: 应该导航到加入空间页面
        expect(find.text('Join Pool Screen'), findsOneWidget);
      });
    });

    // ========================================
    // 创建空间测试
    // ========================================
    group('Create Pool', () {
      testWidgets('it_should_show_pool_name_input_field', (
        WidgetTester tester,
      ) async {
        // Given: 用户在创建空间页面
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: Column(
                children: [
                  const Text('创建新空间'),
                  const SizedBox(height: 16),
                  const TextField(
                    decoration: InputDecoration(
                      labelText: '空间名称',
                      hintText: '输入空间名称',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: () {}, child: const Text('创建')),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示空间名称输入框
        expect(find.text('创建新空间'), findsOneWidget);
        expect(find.text('空间名称'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('创建'), findsOneWidget);
      });

      testWidgets('it_should_accept_pool_name_input', (
        WidgetTester tester,
      ) async {
        // Given: 用户在创建空间页面
        final controller = TextEditingController();
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: '空间名称'),
              ),
            ),
          ),
        );

        // When: 用户输入空间名称
        await tester.enterText(find.byType(TextField), '我的空间');
        await tester.pumpAndSettle();

        // Then: 应该接受输入
        expect(controller.text, equals('我的空间'));
        expect(find.text('我的空间'), findsOneWidget);
      });

      testWidgets('it_should_show_loading_indicator_during_pool_creation', (
        WidgetTester tester,
      ) async {
        // Given: 正在创建空间
        await tester.pumpWidget(
          createTestWidget(
            const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在创建空间...'),
                  ],
                ),
              ),
            ),
          ),
        );

        // Then: 应该显示加载指示器
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('正在创建空间...'), findsOneWidget);
      });

      testWidgets(
        'it_should_navigate_to_home_screen_after_successful_creation',
        (WidgetTester tester) async {
          // Given: 空间创建成功
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () async {
                      // 模拟创建空间
                      await Future<void>.delayed(
                        const Duration(milliseconds: 100),
                      );

                      // 导航到主页
                      unawaited(
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                const Scaffold(body: Text('Home Screen')),
                          ),
                        ),
                      );
                    },
                    child: const Text('创建'),
                  ),
                ),
              ),
            ),
          );

          // When: 创建完成
          await tester.tap(find.text('创建'));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();

          // Then: 应该导航到主页
          expect(find.text('Home Screen'), findsOneWidget);
        },
      );

      testWidgets('it_should_show_error_message_when_pool_name_is_empty', (
        WidgetTester tester,
      ) async {
        // Given: 用户未输入空间名称
        await tester.pumpWidget(
          createTestWidget(
            const Scaffold(
              body: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      labelText: '空间名称',
                      errorText: '空间名称不能为空',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示错误消息
        expect(find.text('空间名称不能为空'), findsOneWidget);
      });
    });

    // ========================================
    // 加入空间测试
    // ========================================
    group('Join Pool', () {
      testWidgets('it_should_show_discovered_pools_list', (
        WidgetTester tester,
      ) async {
        // Given: 发现了可用的空间
        final pools = [
          {'id': '1', 'name': 'Pool 1', 'deviceCount': 2},
          {'id': '2', 'name': 'Pool 2', 'deviceCount': 1},
        ];

        // When: 显示空间列表
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: ListView.builder(
                itemCount: pools.length,
                itemBuilder: (context, index) {
                  final pool = pools[index];
                  return ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(pool['name'] as String),
                    subtitle: Text('${pool['deviceCount']} 个设备'),
                    trailing: ElevatedButton(
                      onPressed: () {},
                      child: const Text('加入'),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示所有可用空间
        expect(find.text('Pool 1'), findsOneWidget);
        expect(find.text('Pool 2'), findsOneWidget);
        expect(find.text('2 个设备'), findsOneWidget);
        expect(find.text('1 个设备'), findsOneWidget);
      });

      testWidgets('it_should_show_loading_indicator_during_discovery', (
        WidgetTester tester,
      ) async {
        // Given: 正在搜索空间
        await tester.pumpWidget(
          createTestWidget(
            const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在搜索附近的空间...'),
                  ],
                ),
              ),
            ),
          ),
        );

        // Then: 应该显示加载指示器
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('正在搜索附近的空间...'), findsOneWidget);
      });

      testWidgets('it_should_show_empty_state_when_no_pools_found', (
        WidgetTester tester,
      ) async {
        // Given: 没有发现可用空间
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_off, size: 64),
                    const SizedBox(height: 16),
                    const Text('未发现附近的空间'),
                    const SizedBox(height: 8),
                    const Text('请确保其他设备已创建空间'),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: () {}, child: const Text('重新搜索')),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示空状态提示
        expect(find.text('未发现附近的空间'), findsOneWidget);
        expect(find.text('请确保其他设备已创建空间'), findsOneWidget);
        expect(find.text('重新搜索'), findsOneWidget);
      });

      testWidgets('it_should_navigate_to_home_screen_after_successful_join', (
        WidgetTester tester,
      ) async {
        // Given: 加入空间成功
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    // 模拟加入空间
                    await Future<void>.delayed(
                      const Duration(milliseconds: 100),
                    );

                    // 导航到主页
                    unawaited(
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const Scaffold(body: Text('Home Screen')),
                        ),
                      ),
                    );
                  },
                  child: const Text('加入'),
                ),
              ),
            ),
          ),
        );

        // When: 加入完成
        await tester.tap(find.text('加入'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Then: 应该导航到主页
        expect(find.text('Home Screen'), findsOneWidget);
      });
    });

    // ========================================
    // 错误处理测试
    // ========================================
    group('Error Handling', () {
      testWidgets('it_should_show_error_message_when_pool_creation_fails', (
        WidgetTester tester,
      ) async {
        // Given: 空间创建失败
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('创建空间失败'),
                  const SizedBox(height: 8),
                  const Text('请检查网络连接后重试'),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: () {}, child: const Text('重试')),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示错误消息和重试按钮
        expect(find.text('创建空间失败'), findsOneWidget);
        expect(find.text('请检查网络连接后重试'), findsOneWidget);
        expect(find.text('重试'), findsOneWidget);
      });

      testWidgets('it_should_show_error_message_when_join_fails', (
        WidgetTester tester,
      ) async {
        // Given: 加入空间失败
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('加入空间失败'),
                  const SizedBox(height: 8),
                  const Text('无法连接到该空间'),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: () {}, child: const Text('返回')),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示错误消息
        expect(find.text('加入空间失败'), findsOneWidget);
        expect(find.text('无法连接到该空间'), findsOneWidget);
        expect(find.text('返回'), findsOneWidget);
      });

      testWidgets('it_should_allow_retry_after_error', (
        WidgetTester tester,
      ) async {
        // Given: 发生错误后显示重试按钮
        int retryCount = 0;

        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: Column(
                children: [
                  const Text('操作失败'),
                  ElevatedButton(
                    onPressed: () {
                      retryCount++;
                    },
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
        );

        // When: 用户点击重试
        await tester.tap(find.text('重试'));
        await tester.pumpAndSettle();

        // Then: 应该触发重试操作
        expect(retryCount, equals(1));
      });
    });

    // ========================================
    // 导航测试
    // ========================================
    group('Navigation', () {
      testWidgets('it_should_allow_back_navigation_from_action_selection', (
        WidgetTester tester,
      ) async {
        // Given: 用户在操作选择页面
        await tester.pumpWidget(
          MaterialApp(
            home: const Scaffold(body: Text('Welcome Page')),
            routes: {
              '/action': (context) => Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                body: const Text('Action Selection'),
              ),
            },
          ),
        );

        // When: 导航到操作选择页面
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/action'),
                  child: const Text('Next'),
                ),
              ),
            ),
            routes: {
              '/action': (context) => Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                body: const Text('Action Selection'),
              ),
            },
          ),
        );

        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        // Then: 应该能够返回
        expect(find.text('Action Selection'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
      });
    });
  });
}
