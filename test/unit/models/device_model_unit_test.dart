import 'package:cardmind/models/device.dart';
import 'package:cardmind/models/pairing_request.dart';
import 'package:cardmind/utils/device_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Device Model Tests', () {
    test('it_should_UT-001: 测试 Device 模型创建', () {
      // Arrange
      const id = '12D3KooWTest123';
      const name = '测试设备';
      const type = DeviceType.phone;
      const status = DeviceStatus.online;
      final lastSeen = DateTime.now();

      // Act
      final device = Device(
        id: id,
        name: name,
        type: type,
        status: status,
        lastSeen: lastSeen,
      );

      // Assert
      expect(device.id, equals(id));
      expect(device.name, equals(name));
      expect(device.type, equals(type));
      expect(device.status, equals(status));
      expect(device.lastSeen, equals(lastSeen));
    });

    test('it_should_UT-002: 测试设备类型枚举', () {
      // Assert
      expect(DeviceType.phone, isNotNull);
      expect(DeviceType.laptop, isNotNull);
      expect(DeviceType.tablet, isNotNull);

      // 测试枚举比较
      expect(DeviceType.phone == DeviceType.phone, isTrue);
      expect(DeviceType.phone == DeviceType.laptop, isFalse);
    });

    test('it_should_UT-003: 测试设备状态枚举', () {
      // Assert
      expect(DeviceStatus.online, isNotNull);
      expect(DeviceStatus.offline, isNotNull);

      // 测试枚举比较
      expect(DeviceStatus.online == DeviceStatus.online, isTrue);
      expect(DeviceStatus.online == DeviceStatus.offline, isFalse);
    });
  });

  group('PairingRequest Model Tests', () {
    test('it_should_UT-004: 测试 PairingRequest 模型创建', () {
      // Arrange
      const requestId = 'request-123';
      const deviceId = '12D3KooWTest456';
      const deviceName = '配对设备';
      const deviceType = DeviceType.laptop;
      const verificationCode = '123456';
      final timestamp = DateTime.now();

      // Act
      final request = PairingRequest(
        requestId: requestId,
        deviceId: deviceId,
        deviceName: deviceName,
        deviceType: deviceType,
        verificationCode: verificationCode,
        timestamp: timestamp,
      );

      // Assert
      expect(request.requestId, equals(requestId));
      expect(request.deviceId, equals(deviceId));
      expect(request.deviceName, equals(deviceName));
      expect(request.deviceType, equals(deviceType));
      expect(request.verificationCode, equals(verificationCode));
      expect(request.timestamp, equals(timestamp));

      // 测试过期时间（应该是 5 分钟后）
      final expectedExpiry = timestamp.add(const Duration(minutes: 5));
      expect(request.expiresAt, equals(expectedExpiry));
    });

    test('it_should_UT-005: 测试验证码生成（6 位数字）', () {
      // 注意：这里测试验证码的格式，实际生成逻辑在 VerificationCodeService 中
      // 这里只测试验证码字符串的有效性

      // Arrange
      final validCodes = ['000000', '123456', '999999', '000123'];
      final invalidCodes = ['12345', '1234567', 'abcdef', '12345a'];

      // Act & Assert
      for (final code in validCodes) {
        expect(code.length, equals(6));
        expect(int.tryParse(code), isNotNull);
        expect(int.parse(code), greaterThanOrEqualTo(0));
        expect(int.parse(code), lessThanOrEqualTo(999999));
      }

      for (final code in invalidCodes) {
        final isValid = code.length == 6 && int.tryParse(code) != null;
        expect(isValid, isFalse);
      }
    });
  });

  group('Device Sorting Tests', () {
    test('it_should_UT-006: 测试设备列表排序逻辑', () {
      // Arrange
      final now = DateTime.now();
      final devices = [
        Device(
          id: 'device-1',
          name: '离线设备1',
          type: DeviceType.phone,
          status: DeviceStatus.offline,
          lastSeen: now.subtract(const Duration(hours: 2)),
        ),
        Device(
          id: 'device-2',
          name: '在线设备1',
          type: DeviceType.laptop,
          status: DeviceStatus.online,
          lastSeen: now.subtract(const Duration(minutes: 5)),
        ),
        Device(
          id: 'device-3',
          name: '离线设备2',
          type: DeviceType.tablet,
          status: DeviceStatus.offline,
          lastSeen: now.subtract(const Duration(hours: 1)),
        ),
        Device(
          id: 'device-4',
          name: '在线设备2',
          type: DeviceType.phone,
          status: DeviceStatus.online,
          lastSeen: now.subtract(const Duration(minutes: 10)),
        ),
      ];

      // Act
      final sorted = DeviceUtils.sortDevices(devices);

      // Assert
      // 在线设备应该在前面
      expect(sorted[0].status, equals(DeviceStatus.online));
      expect(sorted[1].status, equals(DeviceStatus.online));
      expect(sorted[2].status, equals(DeviceStatus.offline));
      expect(sorted[3].status, equals(DeviceStatus.offline));

      // 在线设备中，最近在线的在前（device-2 比 device-4 更近）
      expect(sorted[0].id, equals('device-2'));
      expect(sorted[1].id, equals('device-4'));

      // 离线设备中，最近在线的在前（device-3 比 device-1 更近）
      expect(sorted[2].id, equals('device-3'));
      expect(sorted[3].id, equals('device-1'));
    });
  });

  group('Time Formatting Tests', () {
    test('it_should_UT-007: 测试时间格式化', () {
      final now = DateTime.now();

      // 测试 "刚刚"（1 分钟内）
      final justNow = now.subtract(const Duration(seconds: 30));
      expect(DeviceUtils.formatLastSeen(justNow), equals('刚刚'));

      // 测试 "X 分钟前"（1 小时内）
      final minutes30 = now.subtract(const Duration(minutes: 30));
      expect(DeviceUtils.formatLastSeen(minutes30), equals('30 分钟前'));

      // 测试 "X 小时前"（24 小时内）
      final hours5 = now.subtract(const Duration(hours: 5));
      expect(DeviceUtils.formatLastSeen(hours5), equals('5 小时前'));

      // 测试 "X 天前"（7 天内）
      final days3 = now.subtract(const Duration(days: 3));
      expect(DeviceUtils.formatLastSeen(days3), equals('3 天前'));

      // 测试完整日期格式（超过 7 天）
      final days10 = DateTime(2024, 1, 15, 14, 30);
      final formatted = DeviceUtils.formatLastSeen(days10);
      expect(formatted, equals('2024-01-15 14:30'));
    });
  });

  group('Device Name Validation Tests', () {
    test('it_should_UT-008: 测试设备名称验证', () {
      // 测试空字符串（无效）
      expect(DeviceUtils.isValidDeviceName(''), isFalse);
      expect(DeviceUtils.getDeviceNameError(''), equals('设备名称不能为空'));

      // 测试只有空格（无效）
      expect(DeviceUtils.isValidDeviceName('   '), isFalse);
      expect(DeviceUtils.getDeviceNameError('   '), equals('设备名称不能为空'));

      // 测试正常名称（有效）
      expect(DeviceUtils.isValidDeviceName('我的手机'), isTrue);
      expect(DeviceUtils.getDeviceNameError('我的手机'), isNull);

      // 测试超长名称（>32 字符，无效）
      const longName = '这是一个非常非常非常非常非常非常非常非常非常非常非常长的设备名称啊';
      expect(longName.length, greaterThan(32));
      expect(DeviceUtils.isValidDeviceName(longName), isFalse);
      expect(
        DeviceUtils.getDeviceNameError(longName),
        equals('设备名称不能超过 32 个字符'),
      );

      // 测试边界情况（正好 32 字符，有效）
      const exactName = '这是一个正好三十二个字符的设备名称测试用例啊啊啊啊啊啊啊啊啊啊啊';
      expect(exactName.length, equals(32));
      expect(DeviceUtils.isValidDeviceName(exactName), isTrue);
      expect(DeviceUtils.getDeviceNameError(exactName), isNull);
    });
  });
}
