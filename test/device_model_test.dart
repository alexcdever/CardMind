import 'package:cardmind/models/device.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Device Model Tests', () {
    test('Device creation with all fields', () {
      final device = Device(
        id: 'test-peer-id',
        name: 'Test Device',
        type: DeviceType.laptop,
        status: DeviceStatus.online,
        lastSeen: DateTime.now(),
        multiaddrs: ['/ip4/192.168.1.100/tcp/4001'],
      );

      expect(device.id, 'test-peer-id');
      expect(device.name, 'Test Device');
      expect(device.type, DeviceType.laptop);
      expect(device.status, DeviceStatus.online);
      expect(device.isOnline, true);
      expect(device.multiaddrs.length, 1);
    });

    test('Device isOnline property', () {
      final onlineDevice = Device(
        id: 'test-1',
        name: 'Online Device',
        type: DeviceType.phone,
        status: DeviceStatus.online,
        lastSeen: DateTime.now(),
      );

      final offlineDevice = Device(
        id: 'test-2',
        name: 'Offline Device',
        type: DeviceType.tablet,
        status: DeviceStatus.offline,
        lastSeen: DateTime.now(),
      );

      expect(onlineDevice.isOnline, true);
      expect(offlineDevice.isOnline, false);
    });

    test('Device with empty multiaddrs', () {
      final device = Device(
        id: 'test-3',
        name: 'No Address Device',
        type: DeviceType.laptop,
        status: DeviceStatus.offline,
        lastSeen: DateTime.now(),
      );

      expect(device.multiaddrs, isEmpty);
    });
  });

  group('DeviceType Enum Tests', () {
    test('All device types exist', () {
      expect(DeviceType.values.length, 3);
      expect(DeviceType.values, contains(DeviceType.phone));
      expect(DeviceType.values, contains(DeviceType.laptop));
      expect(DeviceType.values, contains(DeviceType.tablet));
    });
  });

  group('DeviceStatus Enum Tests', () {
    test('All device statuses exist', () {
      expect(DeviceStatus.values.length, 2);
      expect(DeviceStatus.values, contains(DeviceStatus.online));
      expect(DeviceStatus.values, contains(DeviceStatus.offline));
    });
  });
}
