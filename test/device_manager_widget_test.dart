import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/adaptive/platform_detector.dart';
import 'package:cardmind/models/device.dart';
import 'package:cardmind/screens/device_manager_page.dart';
import 'package:cardmind/widgets/current_device_card.dart';
import 'package:cardmind/widgets/device_list_item.dart';

void main() {
  // 设置测试环境为桌面平台
  setUpAll(() {
    PlatformDetector.debugOverridePlatform = PlatformType.desktop;
  });

  // 清理测试环境
  tearDownAll(() {
    PlatformDetector.debugOverridePlatform = null;
  });
  group('CurrentDeviceCard Widget Tests', () {
    testWidgets('displays device information correctly', (tester) async {
      final device = Device(
        id: '12D3KooWTest',
        name: 'Test Laptop',
        type: DeviceType.laptop,
        status: DeviceStatus.online,
        lastSeen: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrentDeviceCard(
              device: device,
              onDeviceNameChange: (_) {},
            ),
          ),
        ),
      );

      // 验证设备名称显示
      expect(find.text('Test Laptop'), findsOneWidget);

      // 验证"本机"标签显示
      expect(find.text('本机'), findsOneWidget);

      // 验证在线状态显示
      expect(find.text('在线'), findsOneWidget);

      // 验证 PeerId 显示
      expect(find.textContaining('12D3KooWTest'), findsOneWidget);
    });

    testWidgets('can enter edit mode when tapped', (tester) async {
      final device = Device(
        id: 'test-id',
        name: 'Original Name',
        type: DeviceType.laptop,
        status: DeviceStatus.online,
        lastSeen: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrentDeviceCard(
              device: device,
              onDeviceNameChange: (_) {},
            ),
          ),
        ),
      );

      // 点击设备名称进入编辑模式
      await tester.tap(find.text('Original Name'));
      await tester.pumpAndSettle();

      // 验证编辑模式下显示 TextField
      expect(find.byType(TextField), findsOneWidget);

      // 验证显示保存和取消按钮
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });

  group('DeviceListItem Widget Tests', () {
    testWidgets('displays device information correctly', (tester) async {
      final device = Device(
        id: '12D3KooWTestDevice',
        name: 'Test Phone',
        type: DeviceType.phone,
        status: DeviceStatus.online,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 5)),
        multiaddrs: [
          '/ip4/192.168.1.100/tcp/4001',
          '/ip4/192.168.1.100/udp/4001/quic',
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceListItem(device: device),
          ),
        ),
      );

      // 验证设备名称显示
      expect(find.text('Test Phone'), findsOneWidget);

      // 验证设备类型显示
      expect(find.text('手机'), findsOneWidget);

      // 验证在线状态显示
      expect(find.text('在线'), findsOneWidget);

      // 验证 PeerId 显示
      expect(find.textContaining('12D3KooWTestDevice'), findsOneWidget);

      // 验证地址显示
      expect(find.textContaining('192.168.1.100'), findsAtLeastNWidgets(1));
    });

    testWidgets('displays offline status correctly', (tester) async {
      final device = Device(
        id: 'offline-device',
        name: 'Offline Device',
        type: DeviceType.tablet,
        status: DeviceStatus.offline,
        lastSeen: DateTime.now().subtract(const Duration(hours: 2)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceListItem(device: device),
          ),
        ),
      );

      // 验证离线状态显示
      expect(find.text('离线'), findsOneWidget);

      // 验证设备类型显示
      expect(find.text('平板'), findsOneWidget);
    });
  });

  group('DeviceManagerPage Widget Tests', () {
    testWidgets('displays not in pool state correctly', (tester) async {
      final currentDevice = Device(
        id: 'current',
        name: 'Current Device',
        type: DeviceType.laptop,
        status: DeviceStatus.online,
        lastSeen: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DeviceManagerPage(
            hasJoinedPool: false,
            currentDevice: currentDevice,
            pairedDevices: const [],
            onDeviceNameChange: (_) {},
            onPairDevice: (_, __) async => true,
          ),
        ),
      );

      // 验证显示"请先加入数据池"提示
      expect(find.text('请先加入数据池'), findsOneWidget);
    });

    testWidgets('displays empty state when no paired devices', (tester) async {
      final currentDevice = Device(
        id: 'current',
        name: 'Current Device',
        type: DeviceType.laptop,
        status: DeviceStatus.online,
        lastSeen: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DeviceManagerPage(
            hasJoinedPool: true,
            currentDevice: currentDevice,
            pairedDevices: const [],
            onDeviceNameChange: (_) {},
            onPairDevice: (_, __) async => true,
          ),
        ),
      );

      // 验证显示空状态
      expect(find.text('暂无配对设备'), findsOneWidget);
      expect(find.text('配对新设备开始同步数据'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });

    testWidgets('displays paired devices list', (tester) async {
      final currentDevice = Device(
        id: 'current',
        name: 'Current Device',
        type: DeviceType.laptop,
        status: DeviceStatus.online,
        lastSeen: DateTime.now(),
      );

      final pairedDevices = [
        Device(
          id: 'device-1',
          name: 'Device 1',
          type: DeviceType.phone,
          status: DeviceStatus.online,
          lastSeen: DateTime.now(),
        ),
        Device(
          id: 'device-2',
          name: 'Device 2',
          type: DeviceType.tablet,
          status: DeviceStatus.offline,
          lastSeen: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: DeviceManagerPage(
            hasJoinedPool: true,
            currentDevice: currentDevice,
            pairedDevices: pairedDevices,
            onDeviceNameChange: (_) {},
            onPairDevice: (_, __) async => true,
          ),
        ),
      );

      // 等待渲染完成
      await tester.pumpAndSettle();

      // 验证显示设备数量
      expect(find.text('2'), findsAtLeastNWidgets(1));

      // 验证显示设备列表
      expect(find.text('Device 1'), findsOneWidget);
      expect(find.text('Device 2'), findsOneWidget);
    });

    testWidgets('shows pair device button', (tester) async {
      final currentDevice = Device(
        id: 'current',
        name: 'Current Device',
        type: DeviceType.laptop,
        status: DeviceStatus.online,
        lastSeen: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DeviceManagerPage(
            hasJoinedPool: true,
            currentDevice: currentDevice,
            pairedDevices: const [],
            onDeviceNameChange: (_) {},
            onPairDevice: (_, __) async => true,
          ),
        ),
      );

      // 等待渲染完成
      await tester.pumpAndSettle();

      // 验证显示配对按钮（使用 findsWidgets 因为可能有多个匹配）
      expect(find.textContaining('配对'), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.add), findsAtLeastNWidgets(1));
    });
  });
}
