import 'package:cardmind/widgets/device_manager_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeScreen Integration Tests - Device Management', () {
    testWidgets('it_should_should display current device info', (
      WidgetTester tester,
    ) async {
      final currentDevice = DeviceInfo(
        id: 'device-1',
        name: 'My Phone',
        type: DeviceType.phone,
        isOnline: true,
        lastSeen: DateTime.now(),
      );

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

      // Verify current device is displayed
      expect(find.text('My Phone'), findsOneWidget);
      expect(find.byIcon(Icons.smartphone), findsOneWidget);
    });

    testWidgets('it_should_should rename current device', (WidgetTester tester) async {
      String? newName;
      final currentDevice = DeviceInfo(
        id: 'device-1',
        name: 'My Phone',
        type: DeviceType.phone,
        isOnline: true,
        lastSeen: DateTime.now(),
      );

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

      // Find and tap edit button
      final editButton = find.byIcon(Icons.edit);
      expect(editButton, findsOneWidget);
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      // Enter new name
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'My New Phone');
      await tester.pumpAndSettle();

      // Tap save button
      final saveButton = find.byIcon(Icons.check);
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify callback was called with new name
      expect(newName, 'My New Phone');
    });

    testWidgets('it_should_should display paired devices list', (
      WidgetTester tester,
    ) async {
      final currentDevice = DeviceInfo(
        id: 'device-1',
        name: 'My Phone',
        type: DeviceType.phone,
        isOnline: true,
        lastSeen: DateTime.now(),
      );

      final pairedDevices = [
        DeviceInfo(
          id: 'device-2',
          name: 'My Laptop',
          type: DeviceType.laptop,
          isOnline: true,
          lastSeen: DateTime.now(),
        ),
        DeviceInfo(
          id: 'device-3',
          name: 'My Tablet',
          type: DeviceType.tablet,
          isOnline: false,
          lastSeen: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ];

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

      // Verify paired devices are displayed
      expect(find.text('My Laptop'), findsOneWidget);
      expect(find.text('My Tablet'), findsOneWidget);
      expect(find.byIcon(Icons.laptop), findsOneWidget);
      expect(find.byIcon(Icons.tablet), findsOneWidget);
    });

    testWidgets('it_should_should show device online/offline status', (
      WidgetTester tester,
    ) async {
      final currentDevice = DeviceInfo(
        id: 'device-1',
        name: 'My Phone',
        type: DeviceType.phone,
        isOnline: true,
        lastSeen: DateTime.now(),
      );

      final pairedDevices = [
        DeviceInfo(
          id: 'device-2',
          name: 'Online Device',
          type: DeviceType.laptop,
          isOnline: true,
          lastSeen: DateTime.now(),
        ),
        DeviceInfo(
          id: 'device-3',
          name: 'Offline Device',
          type: DeviceType.tablet,
          isOnline: false,
          lastSeen: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ];

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

      // Verify online/offline indicators
      expect(find.text('在线'), findsAtLeastNWidgets(1));
      // Note: The offline text includes timestamp, so we check for the icon instead
      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
    });

    testWidgets('it_should_should open add device dialog', (WidgetTester tester) async {
      final currentDevice = DeviceInfo(
        id: 'device-1',
        name: 'My Phone',
        type: DeviceType.phone,
        isOnline: true,
        lastSeen: DateTime.now(),
      );

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

      // Find and tap add device button (button text is "添加", not "添加设备")
      final addButton = find.text('添加');
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Verify dialog is shown (dialog title is "添加设备")
      expect(find.text('添加设备'), findsOneWidget);
      expect(find.text('扫码配对'), findsOneWidget);
      expect(find.text('局域网发现'), findsOneWidget);
    });

    testWidgets('it_should_should remove paired device', (WidgetTester tester) async {
      String? removedDeviceId;
      final currentDevice = DeviceInfo(
        id: 'device-1',
        name: 'My Phone',
        type: DeviceType.phone,
        isOnline: true,
        lastSeen: DateTime.now(),
      );

      final pairedDevices = [
        DeviceInfo(
          id: 'device-2',
          name: 'My Laptop',
          type: DeviceType.laptop,
          isOnline: true,
          lastSeen: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceManagerPanel(
              currentDevice: currentDevice,
              pairedDevices: pairedDevices,
              onDeviceNameChange: (_) {},
              onAddDevice: (_) {},
              onRemoveDevice: (id) {
                removedDeviceId = id;
              },
            ),
          ),
        ),
      );

      // Find and tap remove button (icon is delete_outline, not close)
      final removeButton = find.byIcon(Icons.delete_outline);
      expect(removeButton, findsOneWidget);
      await tester.tap(removeButton);
      await tester.pumpAndSettle();

      // Verify callback was called
      expect(removedDeviceId, 'device-2');
    });

    testWidgets('it_should_should display empty state when no paired devices', (
      WidgetTester tester,
    ) async {
      final currentDevice = DeviceInfo(
        id: 'device-1',
        name: 'My Phone',
        type: DeviceType.phone,
        isOnline: true,
        lastSeen: DateTime.now(),
      );

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

      // Verify empty state message
      expect(find.text('暂无配对设备'), findsOneWidget);
    });

    testWidgets('it_should_should show correct device type icons', (
      WidgetTester tester,
    ) async {
      final currentDevice = DeviceInfo(
        id: 'device-1',
        name: 'My Phone',
        type: DeviceType.phone,
        isOnline: true,
        lastSeen: DateTime.now(),
      );

      final pairedDevices = [
        DeviceInfo(
          id: 'device-2',
          name: 'Device 1',
          type: DeviceType.phone,
          isOnline: true,
          lastSeen: DateTime.now(),
        ),
        DeviceInfo(
          id: 'device-3',
          name: 'Device 2',
          type: DeviceType.laptop,
          isOnline: true,
          lastSeen: DateTime.now(),
        ),
        DeviceInfo(
          id: 'device-4',
          name: 'Device 3',
          type: DeviceType.tablet,
          isOnline: true,
          lastSeen: DateTime.now(),
        ),
      ];

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

      // Verify all device type icons are present
      expect(
        find.byIcon(Icons.smartphone),
        findsNWidgets(2),
      ); // Current + paired
      expect(find.byIcon(Icons.laptop), findsOneWidget);
      expect(find.byIcon(Icons.tablet), findsOneWidget);
    });
  });
}
