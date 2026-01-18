import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/widgets/device_manager_panel.dart';

void main() {
  group('DeviceManagerPanel Widget Tests', () {
    late DeviceInfo currentDevice;
    late List<DeviceInfo> pairedDevices;

    setUp(() {
      currentDevice = DeviceInfo(
        id: 'current-id',
        name: 'My Device',
        type: DeviceType.laptop,
        isOnline: true,
        lastSeen: DateTime.now(),
      );

      pairedDevices = [
        DeviceInfo(
          id: 'device-1',
          name: 'Phone',
          type: DeviceType.phone,
          isOnline: true,
          lastSeen: DateTime.now(),
        ),
        DeviceInfo(
          id: 'device-2',
          name: 'Tablet',
          type: DeviceType.tablet,
          isOnline: false,
          lastSeen: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ];
    });

    testWidgets('it_should_display_current_device', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceManagerPanel(
              currentDevice: currentDevice,
              pairedDevices: const [],
              onDeviceNameChange: (_) {},
              onAddDevice: (_) {},
              onRemoveDevice: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('My Device'), findsOneWidget);
      expect(find.text('当前设备'), findsOneWidget);
    });

    testWidgets('it_should_display_paired_devices', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceManagerPanel(
              currentDevice: currentDevice,
              pairedDevices: pairedDevices,
              onDeviceNameChange: (_) {},
              onAddDevice: (_) {},
              onRemoveDevice: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('Tablet'), findsOneWidget);
    });

    testWidgets('it_should_show_online_status', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceManagerPanel(
              currentDevice: currentDevice,
              pairedDevices: pairedDevices,
              onDeviceNameChange: (_) {},
              onAddDevice: (_) {},
              onRemoveDevice: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('在线'), findsOneWidget);
      expect(find.textContaining('离线'), findsOneWidget);
    });

    testWidgets('it_should_display_empty_state_when_no_paired_devices', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceManagerPanel(
              currentDevice: currentDevice,
              pairedDevices: const [],
              onDeviceNameChange: (_) {},
              onAddDevice: (_) {},
              onRemoveDevice: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('暂无配对设备'), findsOneWidget);
    });

    testWidgets('it_should_have_add_device_button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceManagerPanel(
              currentDevice: currentDevice,
              pairedDevices: const [],
              onDeviceNameChange: (_) {},
              onAddDevice: (_) {},
              onRemoveDevice: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('添加'), findsOneWidget);
    });

    testWidgets('it_should_show_add_device_dialog_when_add_button_tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceManagerPanel(
              currentDevice: currentDevice,
              pairedDevices: const [],
              onDeviceNameChange: (_) {},
              onAddDevice: (_) {},
              onRemoveDevice: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();

      expect(find.text('添加设备'), findsOneWidget);
      expect(find.text('扫码配对'), findsOneWidget);
      expect(find.text('局域网发现'), findsOneWidget);
    });

    testWidgets('it_should_display_device_type_icons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceManagerPanel(
              currentDevice: currentDevice,
              pairedDevices: pairedDevices,
              onDeviceNameChange: (_) {},
              onAddDevice: (_) {},
              onRemoveDevice: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.laptop), findsOneWidget);
      expect(find.byIcon(Icons.smartphone), findsOneWidget);
      expect(find.byIcon(Icons.tablet), findsOneWidget);
    });

    testWidgets('it_should_call_onRemoveDevice_when_delete_button_pressed', (WidgetTester tester) async {
      String? removedId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceManagerPanel(
              currentDevice: currentDevice,
              pairedDevices: pairedDevices,
              onDeviceNameChange: (_) {},
              onAddDevice: (_) {},
              onRemoveDevice: (id) {
                removedId = id;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      expect(removedId, equals('device-1'));
    });

    testWidgets('it_should_enter_edit_mode_when_edit_button_pressed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceManagerPanel(
              currentDevice: currentDevice,
              pairedDevices: const [],
              onDeviceNameChange: (_) {},
              onAddDevice: (_) {},
              onRemoveDevice: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('it_should_call_onDeviceNameChange_when_name_saved', (WidgetTester tester) async {
      String? newName;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceManagerPanel(
              currentDevice: currentDevice,
              pairedDevices: const [],
              onDeviceNameChange: (name) {
                newName = name;
              },
              onAddDevice: (_) {},
              onRemoveDevice: (_) {},
            ),
          ),
        ),
      );

      // Enter edit mode
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Edit name
      await tester.enterText(find.byType(TextField), 'New Device Name');
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(newName, equals('New Device Name'));
    });

    testWidgets('it_should_display_last_seen_time_for_offline_devices', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceManagerPanel(
              currentDevice: currentDevice,
              pairedDevices: pairedDevices,
              onDeviceNameChange: (_) {},
              onAddDevice: (_) {},
              onRemoveDevice: (_) {},
            ),
          ),
        ),
      );

      expect(find.textContaining('小时前'), findsOneWidget);
    });

    testWidgets('it_should_close_add_device_dialog_when_cancel_pressed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceManagerPanel(
              currentDevice: currentDevice,
              pairedDevices: const [],
              onDeviceNameChange: (_) {},
              onAddDevice: (_) {},
              onRemoveDevice: (_) {},
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();

      expect(find.text('添加设备'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.text('添加设备'), findsNothing);
    });
  });
}
