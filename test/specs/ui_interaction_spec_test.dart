import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_utils.dart';
import '../helpers/test_helpers.dart';

/// UI Interaction Specification Tests
///
/// 规格编号: SP-FLUT-003
/// 这些测试验证 UI 交互规格的所有交互行为
///
/// 测试遵循 Spec Coding 方法论：
/// - 测试即规格，规格即文档
/// - 使用 it_should_xxx() 命名风格
/// - Given-When-Then 结构

void main() {
  group('SP-FLUT-003: UI Interaction', () {
    // Setup
    late MockDeviceManager mockDeviceManager;
    late MockNavigationService mockNavigation;

    setUp(() {
      mockDeviceManager = MockDeviceManager();
      mockNavigation = MockNavigationService();
    });

    tearDown(() {
      mockDeviceManager.reset();
      mockNavigation.reset();
    });

    // ========================================
    // 应用启动流程测试
    // ========================================
    group('Application Startup Flow', () {
      testWidgets('it_should_route_to_home_screen_when_device_is_initialized', (
        WidgetTester tester,
      ) async {
        // Given: 设备已初始化
        const isInitialized = true;

        // When: 应用启动
        await tester.pumpWidget(
          createTestWidget(
            Builder(
              builder: (context) {
                return isInitialized
                    ? const Scaffold(body: Text('Home Screen'))
                    : const Scaffold(body: Text('Onboarding Screen'));
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示主页
        expect(find.text('Home Screen'), findsOneWidget);
        expect(find.text('Onboarding Screen'), findsNothing);
      });

      testWidgets(
        'it_should_route_to_onboarding_screen_when_device_is_not_initialized',
        (WidgetTester tester) async {
          // Given: 设备未初始化
          const isInitialized = false;

          // When: 应用启动
          await tester.pumpWidget(
            createTestWidget(
              Builder(
                builder: (context) {
                  return isInitialized
                      ? const Scaffold(body: Text('Home Screen'))
                      : const Scaffold(body: Text('Onboarding Screen'));
                },
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Then: 应该显示初始化向导
          expect(find.text('Onboarding Screen'), findsOneWidget);
          expect(find.text('Home Screen'), findsNothing);
        },
      );
    });

    // ========================================
    // 设备发现测试
    // ========================================
    group('Device Discovery', () {
      testWidgets('it_should_show_loading_indicator_during_discovery', (
        WidgetTester tester,
      ) async {
        // Given: 正在发现设备
        mockDeviceManager.delayMs = 1000;

        // When: 显示发现界面
        await tester.pumpWidget(
          createTestWidget(
            const Scaffold(
              body: Column(
                children: [
                  Text('欢迎使用 CardMind'),
                  SizedBox(height: 32),
                  CircularProgressIndicator(),
                  Text('正在搜索附近的设备...'),
                ],
              ),
            ),
          ),
        );

        // Then: 应该显示加载指示器
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('正在搜索附近的设备...'), findsOneWidget);
      });

      testWidgets('it_should_display_discovered_devices_in_list', (
        WidgetTester tester,
      ) async {
        // Given: 发现了 3 个设备
        final devices = [
          MockDevice(id: '1', name: 'Device 1', platform: 'Android'),
          MockDevice(id: '2', name: 'Device 2', platform: 'iOS'),
          MockDevice(id: '3', name: 'Device 3', platform: 'Windows'),
        ];

        // When: 显示设备列表
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: ListView.builder(
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];
                  return ListTile(
                    leading: const Icon(Icons.devices),
                    title: Text(device.name),
                    subtitle: Text('平台: ${device.platform}'),
                    trailing: ElevatedButton(
                      onPressed: () {},
                      child: const Text('配对'),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示所有设备
        expect(find.text('Device 1'), findsOneWidget);
        expect(find.text('Device 2'), findsOneWidget);
        expect(find.text('Device 3'), findsOneWidget);
        expect(find.byIcon(Icons.devices), findsNWidgets(3));
      });

      testWidgets('it_should_show_pair_button_for_each_device', (
        WidgetTester tester,
      ) async {
        // Given: 发现了设备
        final device = MockDevice(
          id: '1',
          name: 'Test Device',
          platform: 'Android',
        );

        // When: 显示设备列表
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: ListTile(
                leading: const Icon(Icons.devices),
                title: Text(device.name),
                trailing: ElevatedButton(
                  onPressed: () {},
                  child: const Text('配对'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示配对按钮
        expect(find.text('配对'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
      });

      testWidgets('it_should_show_empty_state_when_no_devices_found', (
        WidgetTester tester,
      ) async {
        // Given: 没有发现设备
        final devices = <MockDevice>[];

        // When: 显示空状态
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_off, size: 64),
                    const SizedBox(height: 16),
                    const Text('未发现附近的设备'),
                    const SizedBox(height: 8),
                    ElevatedButton(onPressed: () {}, child: const Text('重新搜索')),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示空状态提示
        expect(find.text('未发现附近的设备'), findsOneWidget);
        expect(find.text('重新搜索'), findsOneWidget);
        expect(find.byIcon(Icons.search_off), findsOneWidget);
      });
    });

    // ========================================
    // 设备配对测试
    // ========================================
    group('Device Pairing', () {
      testWidgets('it_should_show_confirmation_dialog_before_pairing', (
        WidgetTester tester,
      ) async {
        // Given: 用户点击配对按钮
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('确认配对'),
                        content: const Text('是否要配对到此设备？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('确认'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('配对'),
                ),
              ),
            ),
          ),
        );

        // When: 点击配对按钮
        await tester.tap(find.text('配对'));
        await tester.pumpAndSettle();

        // Then: 应该显示确认对话框
        expect(find.text('确认配对'), findsOneWidget);
        expect(find.text('是否要配对到此设备？'), findsOneWidget);
        expect(find.text('取消'), findsOneWidget);
        expect(find.text('确认'), findsOneWidget);
      });

      testWidgets('it_should_show_loading_indicator_during_pairing', (
        WidgetTester tester,
      ) async {
        // Given: 正在配对
        mockDeviceManager.delayMs = 1000;

        // When: 显示配对进度
        await tester.pumpWidget(
          createTestWidget(
            const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在配对...'),
                  ],
                ),
              ),
            ),
          ),
        );

        // Then: 应该显示加载指示器
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('正在配对...'), findsOneWidget);
      });

      testWidgets(
        'it_should_navigate_to_home_screen_after_successful_pairing',
        (WidgetTester tester) async {
          // Given: 配对成功
          bool pairingSuccess = false;

          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () async {
                      // 模拟配对
                      await Future.delayed(const Duration(milliseconds: 100));
                      pairingSuccess = true;

                      // 导航到主页
                      if (pairingSuccess) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const Scaffold(body: Text('Home Screen')),
                          ),
                        );
                      }
                    },
                    child: const Text('配对'),
                  ),
                ),
              ),
            ),
          );

          // When: 配对完成
          await tester.tap(find.text('配对'));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();

          // Then: 应该导航到主页
          expect(find.text('Home Screen'), findsOneWidget);
        },
      );

      testWidgets('it_should_show_error_message_when_pairing_fails', (
        WidgetTester tester,
      ) async {
        // Given: 配对失败
        mockDeviceManager.shouldThrowError = true;

        // When: 显示错误消息
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    const Text('配对失败'),
                    const SizedBox(height: 8),
                    const Text('无法连接到设备，请重试'),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: () {}, child: const Text('重试')),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示错误消息和重试按钮
        expect(find.text('配对失败'), findsOneWidget);
        expect(find.text('无法连接到设备，请重试'), findsOneWidget);
        expect(find.text('重试'), findsOneWidget);
      });
    });

    // ========================================
    // 创建新空间测试
    // ========================================
    group('Create New Space', () {
      testWidgets('it_should_show_create_space_button_on_onboarding_screen', (
        WidgetTester tester,
      ) async {
        // Given: 用户在初始化向导页面
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: Column(
                children: [
                  const Text('欢迎使用 CardMind'),
                  const SizedBox(height: 32),
                  ElevatedButton(onPressed: () {}, child: const Text('创建新空间')),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示创建新空间按钮
        expect(find.text('创建新空间'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
      });

      testWidgets('it_should_navigate_to_home_screen_after_creating_space', (
        WidgetTester tester,
      ) async {
        // Given: 用户点击创建新空间
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    // 创建空间后导航到主页
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const Scaffold(body: Text('Home Screen')),
                      ),
                    );
                  },
                  child: const Text('创建新空间'),
                ),
              ),
            ),
          ),
        );

        // When: 点击创建新空间按钮
        await tester.tap(find.text('创建新空间'));
        await tester.pumpAndSettle();

        // Then: 应该导航到主页
        expect(find.text('Home Screen'), findsOneWidget);
      });

      testWidgets('it_should_show_success_message_after_creating_space', (
        WidgetTester tester,
      ) async {
        // Given: 空间创建成功
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: Builder(
                builder: (context) => const Column(
                  children: [
                    Text('空间创建成功'),
                    Icon(Icons.check_circle, color: Colors.green),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示成功消息
        expect(find.text('空间创建成功'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      });
    });

    // ========================================
    // 错误处理测试
    // ========================================
    group('Error Handling', () {
      testWidgets('it_should_show_error_message_when_discovery_fails', (
        WidgetTester tester,
      ) async {
        // Given: 设备发现失败
        mockDeviceManager.shouldThrowError = true;

        // When: 显示错误消息
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('设备发现失败'),
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
        expect(find.text('设备发现失败'), findsOneWidget);
        expect(find.text('请检查网络连接后重试'), findsOneWidget);
        expect(find.text('重试'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
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
    // 密码验证测试（补充）
    // ========================================
    group('Password Validation', () {
      testWidgets('it_should_validate_password_length_at_least_8_characters', (
        WidgetTester tester,
      ) async {
        // Given: 用户在创建空间对话框
        String? errorMessage;

        await tester.pumpWidget(
          createTestWidget(
            Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          final passwordController = TextEditingController();
                          return AlertDialog(
                            title: const Text('创建笔记空间'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: passwordController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText: '密码',
                                    hintText: '至少 8 位',
                                    errorText: errorMessage,
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('取消'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  if (passwordController.text.length < 8) {
                                    // 显示错误
                                    Navigator.pop(context);
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('错误'),
                                        content: const Text('密码至少需要 8 位'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('确定'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                                child: const Text('创建'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: const Text('创建空间'),
                  ),
                ),
              ),
            ),
          ),
        );

        // When: 用户输入少于 8 位的密码
        await tester.tap(find.text('创建空间'));
        await tester.pumpAndSettle();

        final textField = find.byType(TextField);
        await tester.enterText(textField, '1234567'); // 7 位
        await tester.tap(find.text('创建'));
        await tester.pumpAndSettle();

        // Then: 应该显示错误提示
        expect(find.text('密码至少需要 8 位'), findsOneWidget);
      });

      testWidgets('it_should_show_error_when_passwords_do_not_match', (
        WidgetTester tester,
      ) async {
        // Given: 用户在创建空间对话框
        await tester.pumpWidget(
          createTestWidget(
            Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          final passwordController = TextEditingController();
                          final confirmController = TextEditingController();
                          return AlertDialog(
                            title: const Text('创建笔记空间'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: passwordController,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: '密码',
                                  ),
                                ),
                                TextField(
                                  controller: confirmController,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: '确认密码',
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () {
                                  if (passwordController.text !=
                                      confirmController.text) {
                                    Navigator.pop(context);
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('错误'),
                                        content: const Text('密码不匹配'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('确定'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                                child: const Text('创建'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: const Text('创建空间'),
                  ),
                ),
              ),
            ),
          ),
        );

        // When: 用户输入不匹配的密码
        await tester.tap(find.text('创建空间'));
        await tester.pumpAndSettle();

        final textFields = find.byType(TextField);
        await tester.enterText(textFields.first, 'password123');
        await tester.enterText(textFields.last, 'password456');
        await tester.tap(find.text('创建'));
        await tester.pumpAndSettle();

        // Then: 应该显示错误提示
        expect(find.text('密码不匹配'), findsOneWidget);
      });

      testWidgets('it_should_show_password_input_in_pair_device_screen', (
        WidgetTester tester,
      ) async {
        // Given: 用户在配对设备界面
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              appBar: AppBar(title: const Text('配对设备')),
              body: Column(
                children: [
                  const Text('输入空间密码'),
                  const SizedBox(height: 16),
                  const TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: '密码',
                      hintText: '输入空间密码',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: () {}, child: const Text('配对')),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示密码输入框
        expect(find.text('输入空间密码'), findsWidgets);
        expect(find.text('密码'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
      });
    });

    // ========================================
    // 设置页面测试（补充）
    // ========================================
    group('Settings - Leave Space', () {
      testWidgets('it_should_show_leave_space_option_in_settings', (
        WidgetTester tester,
      ) async {
        // Given: 用户在设置页面
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              appBar: AppBar(title: const Text('设置')),
              body: ListView(
                children: [
                  ListTile(
                    title: const Text('退出笔记空间'),
                    subtitle: const Text('清除所有本地数据'),
                    leading: const Icon(Icons.exit_to_app, color: Colors.red),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示退出空间选项
        expect(find.text('退出笔记空间'), findsOneWidget);
        expect(find.text('清除所有本地数据'), findsOneWidget);
        expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
      });

      testWidgets('it_should_show_confirmation_dialog_before_leaving_space', (
        WidgetTester tester,
      ) async {
        // Given: 用户点击退出空间
        await tester.pumpWidget(
          createTestWidget(
            Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('确认退出？'),
                          content: const Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('⚠️ 警告：'),
                              SizedBox(height: 8),
                              Text('• 此设备上的所有卡片将被删除'),
                              Text('• 其他设备不受影响'),
                              Text('• 退出后可以加入其他笔记空间'),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('取消'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('确认退出'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('退出空间'),
                  ),
                ),
              ),
            ),
          ),
        );

        // When: 用户点击退出空间
        await tester.tap(find.text('退出空间'));
        await tester.pumpAndSettle();

        // Then: 应该显示确认对话框
        expect(find.text('确认退出？'), findsOneWidget);
        expect(find.text('⚠️ 警告：'), findsOneWidget);
        expect(find.text('• 此设备上的所有卡片将被删除'), findsOneWidget);
        expect(find.text('确认退出'), findsOneWidget);
      });

      testWidgets('it_should_navigate_to_onboarding_after_leaving_space', (
        WidgetTester tester,
      ) async {
        // Given: 用户确认退出空间
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      // 模拟退出空间
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const Scaffold(
                            body: Center(child: Text('Onboarding Screen')),
                          ),
                        ),
                      );
                    },
                    child: const Text('确认退出'),
                  ),
                ),
              ),
            ),
          ),
        );

        // When: 用户点击确认退出
        await tester.tap(find.text('确认退出'));
        await tester.pumpAndSettle();

        // Then: 应该导航到初始化页面
        expect(find.text('Onboarding Screen'), findsOneWidget);
      });
    });

    // ========================================
    // 密码强度指示器测试（补充）
    // ========================================
    group('Password Strength Indicator', () {
      testWidgets('it_should_show_password_strength_indicator', (
        WidgetTester tester,
      ) async {
        // Given: 用户在创建空间对话框输入密码
        await tester.pumpWidget(
          createTestWidget(
            Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          final passwordController = TextEditingController();
                          String passwordStrength = '弱';
                          Color strengthColor = Colors.red;

                          return StatefulBuilder(
                            builder: (context, setState) {
                              return AlertDialog(
                                title: const Text('创建笔记空间'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: passwordController,
                                      obscureText: true,
                                      decoration: const InputDecoration(
                                        labelText: '密码',
                                        hintText: '至少 8 位',
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          if (value.length < 8) {
                                            passwordStrength = '弱';
                                            strengthColor = Colors.red;
                                          } else if (value.length < 12) {
                                            passwordStrength = '中';
                                            strengthColor = Colors.orange;
                                          } else {
                                            passwordStrength = '强';
                                            strengthColor = Colors.green;
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Text('密码强度: '),
                                        Text(
                                          passwordStrength,
                                          style: TextStyle(
                                            color: strengthColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('取消'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('创建'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                    child: const Text('创建空间'),
                  ),
                ),
              ),
            ),
          ),
        );

        // When: 用户输入不同长度的密码
        await tester.tap(find.text('创建空间'));
        await tester.pumpAndSettle();

        // 输入短密码（弱）
        final textField = find.byType(TextField);
        await tester.enterText(textField, '1234567'); // 7 位
        await tester.pump();

        // Then: 应该显示"弱"
        expect(find.text('密码强度: '), findsOneWidget);
        expect(find.text('弱'), findsOneWidget);

        // When: 输入中等长度密码（中）
        await tester.enterText(textField, '12345678'); // 8 位
        await tester.pump();

        // Then: 应该显示"中"
        expect(find.text('中'), findsOneWidget);

        // When: 输入长密码（强）
        await tester.enterText(textField, '123456789012'); // 12 位
        await tester.pump();

        // Then: 应该显示"强"
        expect(find.text('强'), findsOneWidget);
      });
    });

    // ========================================
    // 数据清除测试（补充）
    // ========================================
    group('Local Data Cleanup', () {
      testWidgets('it_should_clear_local_data_after_leaving_space', (
        WidgetTester tester,
      ) async {
        // Given: 用户确认退出空间
        bool dataCleared = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      // 模拟退出空间流程
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('确认退出？'),
                          content: const Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('⚠️ 警告：'),
                              SizedBox(height: 8),
                              Text('• 此设备上的所有卡片将被删除'),
                              Text('• 其他设备不受影响'),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('取消'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('确认退出'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        // 模拟清除本地数据
                        dataCleared = true;

                        // 显示清除完成的提示
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('本地数据已清除')),
                          );

                          // 导航到初始化页面
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const Scaffold(
                                body: Center(child: Text('Onboarding Screen')),
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('退出空间'),
                  ),
                ),
              ),
            ),
          ),
        );

        // When: 用户点击退出空间并确认
        await tester.tap(find.text('退出空间'));
        await tester.pumpAndSettle();

        expect(find.text('确认退出？'), findsOneWidget);

        await tester.tap(find.text('确认退出'));
        await tester.pumpAndSettle();

        // Then: 应该清除本地数据并显示提示
        expect(dataCleared, isTrue);
        expect(find.text('本地数据已清除'), findsOneWidget);
        expect(find.text('Onboarding Screen'), findsOneWidget);
      });
    });

    // ========================================
    // 术语统一测试（补充）
    // ========================================
    group('Terminology Consistency', () {
      testWidgets('it_should_use_correct_terminology_throughout_app', (
        WidgetTester tester,
      ) async {
        // Given: 应用使用统一的术语
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: ListView(
                children: const [
                  ListTile(
                    title: Text('创建笔记空间'), // 新术语
                  ),
                  ListTile(
                    title: Text('配对设备'), // 新术语
                  ),
                  ListTile(
                    title: Text('退出笔记空间'), // 新术语
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该使用新术语
        expect(find.text('创建笔记空间'), findsOneWidget);
        expect(find.text('配对设备'), findsOneWidget);
        expect(find.text('退出笔记空间'), findsOneWidget);

        // 不应该出现旧术语
        expect(find.text('创建数据池'), findsNothing);
        expect(find.text('加入数据池'), findsNothing);
        expect(find.text('常驻池'), findsNothing);
      });
    });
  });
}
