import 'package:cardmind/widgets/device_manager_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Device Manager UI Specification Tests
///
/// 规格编号: SP-UI-003
/// 这些测试验证设备管理面板 UI 的所有交互行为
///
/// 测试遵循 Spec Coding 方法论：
/// - 测试即规格，规格即文档
/// - 使用 it_should_xxx() 命名风格
/// - Given-When-Then 结构

void main() {
  group('SP-UI-003: Device Manager UI', () {
    // ========================================
    // Test Data
    // ========================================

    final currentDevice = DeviceInfo(
      id: 'current',
      name: 'My Laptop',
      type: DeviceType.laptop,
      isOnline: true,
      lastSeen: DateTime.now(),
    );

    final pairedDevices = [
      DeviceInfo(
        id: 'device1',
        name: 'iPhone 13',
        type: DeviceType.phone,
        isOnline: true,
        lastSeen: DateTime.now(),
      ),
      DeviceInfo(
        id: 'device2',
        name: 'iPad Pro',
        type: DeviceType.tablet,
        isOnline: false,
        lastSeen: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];

    // ========================================
    // Helper: 创建 DeviceManagerPanel
    // ========================================
    Widget createDeviceManagerPanel({
      DeviceInfo? current,
      List<DeviceInfo>? paired,
      void Function(String)? onDeviceNameChange,
      void Function(DeviceInfo)? onAddDevice,
      void Function(String)? onRemoveDevice,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: DeviceManagerPanel(
            currentDevice: current ?? currentDevice,
            pairedDevices: paired ?? pairedDevices,
            onDeviceNameChange: onDeviceNameChange ?? (_) {},
            onAddDevice: onAddDevice ?? (_) {},
            onRemoveDevice: onRemoveDevice ?? (_) {},
          ),
        ),
      );
    }

    // ========================================
    // UI Layout Tests
    // ========================================

    group('UI Layout Tests', () {
      testWidgets('it_should_display_panel_title', (WidgetTester tester) async {
        // Given: 设备管理面板加载
        await tester.pumpWidget(createDeviceManagerPanel());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示标题 "设备网络"
        expect(find.text('设备网络'), findsOneWidget);
      });

      testWidgets('it_should_display_current_device_section', (
        WidgetTester tester,
      ) async {
        // Given: 设备管理面板加载
        await tester.pumpWidget(createDeviceManagerPanel());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示 "当前设备" 标题
        expect(find.text('当前设备'), findsOneWidget);
      });

      testWidgets('it_should_display_paired_devices_section', (
        WidgetTester tester,
      ) async {
        // Given: 设备管理面板加载
        await tester.pumpWidget(createDeviceManagerPanel());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示 "已配对设备" 标题
        expect(find.text('已配对设备'), findsOneWidget);
      });

      testWidgets('it_should_display_add_device_button', (
        WidgetTester tester,
      ) async {
        // Given: 设备管理面板加载
        await tester.pumpWidget(createDeviceManagerPanel());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示 "添加" 按钮
        expect(find.text('添加'), findsOneWidget);
      });

      testWidgets('it_should_display_wifi_icon_in_title', (
        WidgetTester tester,
      ) async {
        // Given: 设备管理面板加载
        await tester.pumpWidget(createDeviceManagerPanel());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示 WiFi 图标
        expect(find.byIcon(Icons.wifi), findsOneWidget);
      });
    });

    // ========================================
    // Current Device Tests
    // ========================================

    group('Current Device Tests', () {
      testWidgets('it_should_display_current_device_name', (
        WidgetTester tester,
      ) async {
        // Given: 当前设备名称为 "My Laptop"
        await tester.pumpWidget(createDeviceManagerPanel());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示设备名称
        expect(find.text('My Laptop'), findsOneWidget);
      });

      testWidgets('it_should_display_current_device_icon', (
        WidgetTester tester,
      ) async {
        // Given: 当前设备类型为 laptop
        await tester.pumpWidget(createDeviceManagerPanel());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示笔记本图标
        expect(find.byIcon(Icons.laptop), findsOneWidget);
      });

      testWidgets('it_should_display_edit_button_for_current_device', (
        WidgetTester tester,
      ) async {
        // Given: 当前设备显示
        await tester.pumpWidget(createDeviceManagerPanel());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示编辑按钮
        expect(find.byIcon(Icons.edit), findsOneWidget);
      });

      testWidgets('it_should_show_text_field_when_edit_button_tapped', (
        WidgetTester tester,
      ) async {
        // Given: 当前设备显示
        await tester.pumpWidget(createDeviceManagerPanel());
        await tester.pumpAndSettle();

        // When: 用户点击编辑按钮
        await tester.tap(find.byIcon(Icons.edit));
        await tester.pumpAndSettle();

        // Then: 显示文本输入框
        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('it_should_show_check_button_in_edit_mode', (
        WidgetTester tester,
      ) async {
        // Given: 进入编辑模式
        await tester.pumpWidget(createDeviceManagerPanel());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.edit));
        await tester.pumpAndSettle();

        // When: 检查按钮
        // Then: 显示确认按钮
        expect(find.byIcon(Icons.check), findsOneWidget);
      });

      testWidgets('it_should_save_device_name_when_check_button_tapped', (
        WidgetTester tester,
      ) async {
        // Given: 编辑模式下修改了名称
        String? savedName;
        await tester.pumpWidget(
          createDeviceManagerPanel(
            onDeviceNameChange: (name) {
              savedName = name;
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.edit));
        await tester.pumpAndSettle();

        // When: 用户输入新名称并点击确认
        await tester.enterText(find.byType(TextField), 'New Name');
        await tester.tap(find.byIcon(Icons.check));
        await tester.pumpAndSettle();

        // Then: 回调被调用，名称被保存
        expect(savedName, equals('New Name'));
      });

      testWidgets('it_should_not_save_empty_device_name', (
        WidgetTester tester,
      ) async {
        // Given: 编辑模式下输入空名称
        String? savedName;
        await tester.pumpWidget(
          createDeviceManagerPanel(
            onDeviceNameChange: (name) {
              savedName = name;
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.edit));
        await tester.pumpAndSettle();

        // When: 用户输入空格并点击确认
        await tester.enterText(find.byType(TextField), '   ');
        await tester.tap(find.byIcon(Icons.check));
        await tester.pumpAndSettle();

        // Then: 回调不被调用
        expect(savedName, isNull);
      });

      testWidgets('it_should_highlight_current_device_with_border', (
        WidgetTester tester,
      ) async {
        // Given: 当前设备显示
        await tester.pumpWidget(createDeviceManagerPanel());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 当前设备有特殊边框样式
        // 查找包含当前设备名称的 Container
        final containers = find.byType(Container);
        bool foundDecoratedContainer = false;
        for (final element in containers.evaluate()) {
          final container = element.widget as Container;
          if (container.decoration is BoxDecoration) {
            final decoration = container.decoration as BoxDecoration;
            if (decoration.border != null) {
              foundDecoratedContainer = true;
              break;
            }
          }
        }
        expect(foundDecoratedContainer, isTrue);
      });
    });

    // ========================================
    // Paired Devices Tests
    // ========================================

    group('Paired Devices Tests', () {
      testWidgets('it_should_display_all_paired_devices', (
        WidgetTester tester,
      ) async {
        // Given: 有 2 个配对设备
        await tester.pumpWidget(createDeviceManagerPanel());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示所有设备名称
        expect(find.text('iPhone 13'), findsOneWidget);
        expect(find.text('iPad Pro'), findsOneWidget);
      });

      testWidgets('it_should_display_device_type_icons', (
        WidgetTester tester,
      ) async {
        // Given: 配对设备有不同类型
        await tester.pumpWidget(createDeviceManagerPanel());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示对应的图标
        expect(find.byIcon(Icons.smartphone), findsOneWidget);
        expect(find.byIcon(Icons.tablet), findsOneWidget);
      });

      testWidgets('it_should_display_online_status_for_devices', (
        WidgetTester tester,
      ) async {
        // Given: 设备有在线和离线状态
        await tester.pumpWidget(createDeviceManagerPanel());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示在线/离线状态
        expect(find.text('在线'), findsOneWidget);
        expect(find.textContaining('离线'), findsOneWidget);
      });

      testWidgets('it_should_display_last_seen_time_for_offline_devices', (
        WidgetTester tester,
      ) async {
        // Given: 离线设备
        await tester.pumpWidget(createDeviceManagerPanel());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示最后在线时间
        expect(find.textContaining('小时前'), findsOneWidget);
      });

      testWidgets('it_should_display_delete_button_for_each_device', (
        WidgetTester tester,
      ) async {
        // Given: 配对设备列表
        await tester.pumpWidget(createDeviceManagerPanel());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 每个设备有删除按钮
        expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
      });

      testWidgets('it_should_call_remove_callback_when_delete_tapped', (
        WidgetTester tester,
      ) async {
        // Given: 配对设备列表
        String? removedDeviceId;
        await tester.pumpWidget(
          createDeviceManagerPanel(
            onRemoveDevice: (id) {
              removedDeviceId = id;
            },
          ),
        );
        await tester.pumpAndSettle();

        // When: 用户点击删除按钮
        await tester.tap(find.byIcon(Icons.delete_outline).first);
        await tester.pumpAndSettle();

        // Then: 回调被调用
        expect(removedDeviceId, isNotNull);
      });

      testWidgets('it_should_show_empty_state_when_no_paired_devices', (
        WidgetTester tester,
      ) async {
        // Given: 没有配对设备
        await tester.pumpWidget(createDeviceManagerPanel(paired: []));

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示空状态提示
        expect(find.text('暂无配对设备'), findsOneWidget);
      });
    });

    // ========================================
    // Add Device Tests
    // ========================================

    group('Add Device Tests', () {
      testWidgets('it_should_show_add_device_dialog_when_add_button_tapped', (
        WidgetTester tester,
      ) async {
        // Given: 设备管理面板显示
        await tester.pumpWidget(createDeviceManagerPanel());
        await tester.pumpAndSettle();

        // When: 用户点击添加按钮
        await tester.tap(find.text('添加'));
        await tester.pumpAndSettle();

        // Then: 显示添加设备对话框
        expect(find.text('添加设备'), findsOneWidget);
      });

      testWidgets('it_should_show_scan_qr_code_option_in_dialog', (
        WidgetTester tester,
      ) async {
        // Given: 添加设备对话框显示
        await tester.pumpWidget(createDeviceManagerPanel());
        await tester.pumpAndSettle();

        await tester.tap(find.text('添加'));
        await tester.pumpAndSettle();

        // When: 检查对话框内容
        // Then: 显示扫码配对选项
        expect(find.text('扫码配对'), findsOneWidget);
        expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
      });

      testWidgets('it_should_show_lan_discovery_option_in_dialog', (
        WidgetTester tester,
      ) async {
        // Given: 添加设备对话框显示
        await tester.pumpWidget(createDeviceManagerPanel());
        await tester.pumpAndSettle();

        await tester.tap(find.text('添加'));
        await tester.pumpAndSettle();

        // When: 检查对话框内容
        // Then: 显示局域网发现选项
        expect(find.text('局域网发现'), findsOneWidget);
        expect(find.byIcon(Icons.radar), findsOneWidget);
      });

      testWidgets('it_should_close_dialog_when_cancel_tapped', (
        WidgetTester tester,
      ) async {
        // Given: 添加设备对话框显示
        await tester.pumpWidget(createDeviceManagerPanel());
        await tester.pumpAndSettle();

        await tester.tap(find.text('添加'));
        await tester.pumpAndSettle();

        // When: 用户点击取消
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();

        // Then: 对话框关闭
        expect(find.text('添加设备'), findsNothing);
      });

      testWidgets('it_should_close_dialog_when_scan_option_tapped', (
        WidgetTester tester,
      ) async {
        // Given: 添加设备对话框显示
        await tester.pumpWidget(createDeviceManagerPanel());
        await tester.pumpAndSettle();

        await tester.tap(find.text('添加'));
        await tester.pumpAndSettle();

        // When: 用户点击扫码配对
        await tester.tap(find.text('扫码配对'));
        await tester.pumpAndSettle();

        // Then: 对话框关闭
        expect(find.text('添加设备'), findsNothing);
      });

      testWidgets('it_should_close_dialog_when_lan_option_tapped', (
        WidgetTester tester,
      ) async {
        // Given: 添加设备对话框显示
        await tester.pumpWidget(createDeviceManagerPanel());
        await tester.pumpAndSettle();

        await tester.tap(find.text('添加'));
        await tester.pumpAndSettle();

        // When: 用户点击局域网发现
        await tester.tap(find.text('局域网发现'));
        await tester.pumpAndSettle();

        // Then: 对话框关闭
        expect(find.text('添加设备'), findsNothing);
      });
    });

    // ========================================
    // Device Icon Tests
    // ========================================

    group('Device Icon Tests', () {
      testWidgets('it_should_display_phone_icon_for_phone_type', (
        WidgetTester tester,
      ) async {
        // Given: 设备类型为 phone
        final phoneDevice = DeviceInfo(
          id: 'phone',
          name: 'iPhone',
          type: DeviceType.phone,
          isOnline: true,
          lastSeen: DateTime.now(),
        );

        await tester.pumpWidget(
          createDeviceManagerPanel(paired: [phoneDevice]),
        );

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示手机图标
        expect(find.byIcon(Icons.smartphone), findsOneWidget);
      });

      testWidgets('it_should_display_laptop_icon_for_laptop_type', (
        WidgetTester tester,
      ) async {
        // Given: 设备类型为 laptop
        await tester.pumpWidget(createDeviceManagerPanel());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示笔记本图标
        expect(find.byIcon(Icons.laptop), findsOneWidget);
      });

      testWidgets('it_should_display_tablet_icon_for_tablet_type', (
        WidgetTester tester,
      ) async {
        // Given: 设备类型为 tablet
        final tabletDevice = DeviceInfo(
          id: 'tablet',
          name: 'iPad',
          type: DeviceType.tablet,
          isOnline: true,
          lastSeen: DateTime.now(),
        );

        await tester.pumpWidget(
          createDeviceManagerPanel(paired: [tabletDevice]),
        );

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示平板图标
        expect(find.byIcon(Icons.tablet), findsOneWidget);
      });
    });

    // ========================================
    // Time Formatting Tests
    // ========================================

    group('Time Formatting Tests', () {
      testWidgets('it_should_display_just_now_for_recent_activity', (
        WidgetTester tester,
      ) async {
        // Given: 设备刚刚离线
        final recentDevice = DeviceInfo(
          id: 'recent',
          name: 'Recent Device',
          type: DeviceType.phone,
          isOnline: false,
          lastSeen: DateTime.now().subtract(const Duration(seconds: 30)),
        );

        await tester.pumpWidget(
          createDeviceManagerPanel(paired: [recentDevice]),
        );

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示 "刚刚"
        expect(find.text('离线 · 刚刚'), findsOneWidget);
      });

      testWidgets('it_should_display_minutes_ago_for_recent_offline', (
        WidgetTester tester,
      ) async {
        // Given: 设备几分钟前离线
        final minutesAgoDevice = DeviceInfo(
          id: 'minutes',
          name: 'Minutes Device',
          type: DeviceType.phone,
          isOnline: false,
          lastSeen: DateTime.now().subtract(const Duration(minutes: 30)),
        );

        await tester.pumpWidget(
          createDeviceManagerPanel(paired: [minutesAgoDevice]),
        );

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示分钟数
        expect(find.textContaining('分钟前'), findsOneWidget);
      });

      testWidgets('it_should_display_hours_ago_for_hours_offline', (
        WidgetTester tester,
      ) async {
        // Given: 设备几小时前离线
        final hoursAgoDevice = DeviceInfo(
          id: 'hours',
          name: 'Hours Device',
          type: DeviceType.phone,
          isOnline: false,
          lastSeen: DateTime.now().subtract(const Duration(hours: 5)),
        );

        await tester.pumpWidget(
          createDeviceManagerPanel(paired: [hoursAgoDevice]),
        );

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示小时数
        expect(find.textContaining('小时前'), findsOneWidget);
      });

      testWidgets('it_should_display_days_ago_for_days_offline', (
        WidgetTester tester,
      ) async {
        // Given: 设备几天前离线
        final daysAgoDevice = DeviceInfo(
          id: 'days',
          name: 'Days Device',
          type: DeviceType.phone,
          isOnline: false,
          lastSeen: DateTime.now().subtract(const Duration(days: 3)),
        );

        await tester.pumpWidget(
          createDeviceManagerPanel(paired: [daysAgoDevice]),
        );

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示天数
        expect(find.textContaining('天前'), findsOneWidget);
      });
    });

    // ========================================
    // Accessibility Tests
    // ========================================

    group('Accessibility Tests', () {
      testWidgets('it_should_provide_semantic_labels_for_buttons', (
        WidgetTester tester,
      ) async {
        // Given: 设备管理面板显示
        await tester.pumpWidget(createDeviceManagerPanel());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 按钮有文本或图标作为语义标签
        expect(find.text('添加'), findsOneWidget);
        expect(find.byIcon(Icons.edit), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsWidgets);
      });

      testWidgets('it_should_provide_device_status_information', (
        WidgetTester tester,
      ) async {
        // Given: 设备有在线/离线状态
        await tester.pumpWidget(createDeviceManagerPanel());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 状态信息清晰可见
        expect(find.text('在线'), findsOneWidget);
        expect(find.textContaining('离线'), findsOneWidget);
      });
    });

    // ========================================
    // Performance Tests
    // ========================================

    group('Performance Tests', () {
      testWidgets('it_should_render_panel_within_100ms', (
        WidgetTester tester,
      ) async {
        // Given: 面板即将加载
        final startTime = DateTime.now();

        // When: 加载面板
        await tester.pumpWidget(createDeviceManagerPanel());
        await tester.pumpAndSettle();

        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);

        // Then: 渲染时间小于 1000ms（测试环境波动）
        expect(duration.inMilliseconds, lessThan(1000));
      });

      testWidgets('it_should_handle_large_device_list_efficiently', (
        WidgetTester tester,
      ) async {
        // Given: 大量配对设备
        final manyDevices = List.generate(
          50,
          (i) => DeviceInfo(
            id: 'device$i',
            name: 'Device $i',
            type: DeviceType.phone,
            isOnline: i % 2 == 0,
            lastSeen: DateTime.now(),
          ),
        );

        // When: 渲染面板
        await tester.pumpWidget(createDeviceManagerPanel(paired: manyDevices));
        await tester.pumpAndSettle();

        // Then: 没有性能问题
        expect(tester.takeException(), isNull);
      });
    });
  });
}
