import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/models/device.dart';
import 'package:cardmind/services/device_discovery_service.dart';

void main() {
  late DeviceDiscoveryService service;

  setUp(() {
    service = DeviceDiscoveryService();
  });

  tearDown(() {
    service.dispose();
  });

  group('DeviceDiscoveryService Tests', () {
    test('handles device online event', () async {
      final peerId = '12D3KooWTest123456789';
      final multiaddrs = ['/ip4/192.168.1.100/tcp/4001'];

      // 监听状态变化
      final events = <DeviceDiscoveryEvent>[];
      service.stateChanges.listen(events.add);

      // 触发设备上线
      service.handleDeviceOnline(peerId, multiaddrs);

      // 等待事件处理
      await Future.delayed(const Duration(milliseconds: 10));

      // 验证事件
      expect(events.length, 1);
      expect(events[0].peerId, peerId);
      expect(events[0].multiaddrs, multiaddrs);
      expect(events[0].isOnline, true);

      // 验证状态
      final state = service.getDeviceState(peerId);
      expect(state, isNotNull);
      expect(state!.isOnline, true);
    });

    test('handles device offline event', () async {
      final peerId = '12D3KooWTest123456789';
      final multiaddrs = ['/ip4/192.168.1.100/tcp/4001'];

      // 先上线
      service.handleDeviceOnline(peerId, multiaddrs);

      // 监听状态变化
      final events = <DeviceDiscoveryEvent>[];
      service.stateChanges.listen(events.add);

      // 触发设备离线
      service.handleDeviceOffline(peerId);

      // 等待事件处理
      await Future.delayed(const Duration(milliseconds: 10));

      // 验证事件
      expect(events.length, 1);
      expect(events[0].peerId, peerId);
      expect(events[0].isOnline, false);

      // 验证状态
      final state = service.getDeviceState(peerId);
      expect(state, isNotNull);
      expect(state!.isOnline, false);
    });

    test('getOnlineDevices returns only online devices', () {
      final peerId1 = '12D3KooWTest1';
      final peerId2 = '12D3KooWTest2';
      final peerId3 = '12D3KooWTest3';

      // 添加设备
      service.handleDeviceOnline(peerId1, ['/ip4/192.168.1.100/tcp/4001']);
      service.handleDeviceOnline(peerId2, ['/ip4/192.168.1.101/tcp/4001']);
      service.handleDeviceOnline(peerId3, ['/ip4/192.168.1.102/tcp/4001']);

      // 设置一个设备离线
      service.handleDeviceOffline(peerId2);

      // 获取在线设备
      final onlineDevices = service.getOnlineDevices();

      expect(onlineDevices.length, 2);
      expect(onlineDevices, contains(peerId1));
      expect(onlineDevices, contains(peerId3));
      expect(onlineDevices, isNot(contains(peerId2)));
    });

    test('updateDeviceStates updates device list correctly', () {
      final peerId1 = '12D3KooWTest1';
      final peerId2 = '12D3KooWTest2';

      // 创建设备列表
      final devices = [
        Device(
          id: peerId1,
          name: 'Device 1',
          type: DeviceType.laptop,
          status: DeviceStatus.offline,
          lastSeen: DateTime(2024, 1, 1),
          multiaddrs: [],
        ),
        Device(
          id: peerId2,
          name: 'Device 2',
          type: DeviceType.phone,
          status: DeviceStatus.offline,
          lastSeen: DateTime(2024, 1, 1),
          multiaddrs: [],
        ),
      ];

      // 设置设备状态
      service.handleDeviceOnline(peerId1, ['/ip4/192.168.1.100/tcp/4001']);

      // 更新设备列表
      final updatedDevices = service.updateDeviceStates(devices);

      // 验证更新
      expect(updatedDevices[0].status, DeviceStatus.online);
      expect(updatedDevices[0].multiaddrs, ['/ip4/192.168.1.100/tcp/4001']);
      expect(updatedDevices[0].lastSeen.isAfter(DateTime(2024, 1, 1)), true);

      expect(updatedDevices[1].status, DeviceStatus.offline);
      expect(updatedDevices[1].multiaddrs, isEmpty);
    });

    test('updateDeviceStates preserves existing multiaddrs when empty', () {
      final peerId = '12D3KooWTest1';
      final existingMultiaddrs = ['/ip4/192.168.1.100/tcp/4001'];

      final devices = [
        Device(
          id: peerId,
          name: 'Device 1',
          type: DeviceType.laptop,
          status: DeviceStatus.offline,
          lastSeen: DateTime(2024, 1, 1),
          multiaddrs: existingMultiaddrs,
        ),
      ];

      // 设置设备在线但没有新地址
      service.handleDeviceOnline(peerId, []);

      // 更新设备列表
      final updatedDevices = service.updateDeviceStates(devices);

      // 验证保留了原有地址
      expect(updatedDevices[0].multiaddrs, existingMultiaddrs);
    });

    test('handles multiple state changes for same device', () async {
      final peerId = '12D3KooWTest1';
      final multiaddrs1 = ['/ip4/192.168.1.100/tcp/4001'];
      final multiaddrs2 = [
        '/ip4/192.168.1.100/tcp/4001',
        '/ip6/::1/tcp/4001',
      ];

      final events = <DeviceDiscoveryEvent>[];
      service.stateChanges.listen(events.add);

      // 第一次上线
      service.handleDeviceOnline(peerId, multiaddrs1);
      await Future.delayed(const Duration(milliseconds: 10));

      // 更新地址
      service.handleDeviceOnline(peerId, multiaddrs2);
      await Future.delayed(const Duration(milliseconds: 10));

      // 离线
      service.handleDeviceOffline(peerId);
      await Future.delayed(const Duration(milliseconds: 10));

      // 验证事件序列
      expect(events.length, 3);
      expect(events[0].isOnline, true);
      expect(events[0].multiaddrs, multiaddrs1);
      expect(events[1].isOnline, true);
      expect(events[1].multiaddrs, multiaddrs2);
      expect(events[2].isOnline, false);
    });

    test('getDeviceState returns null for unknown device', () {
      final state = service.getDeviceState('unknown-peer-id');
      expect(state, isNull);
    });

    test('handleDeviceOffline does nothing for unknown device', () async {
      final events = <DeviceDiscoveryEvent>[];
      service.stateChanges.listen(events.add);

      service.handleDeviceOffline('unknown-peer-id');
      await Future.delayed(const Duration(milliseconds: 10));

      expect(events, isEmpty);
    });
  });

  group('DeviceDiscoveryManager Tests', () {
    tearDown(() {
      DeviceDiscoveryManager.reset();
    });

    test('returns singleton instance', () {
      final instance1 = DeviceDiscoveryManager.instance;
      final instance2 = DeviceDiscoveryManager.instance;

      expect(instance1, same(instance2));
    });

    test('reset creates new instance', () {
      final instance1 = DeviceDiscoveryManager.instance;
      DeviceDiscoveryManager.reset();
      final instance2 = DeviceDiscoveryManager.instance;

      expect(instance1, isNot(same(instance2)));
    });
  });
}
