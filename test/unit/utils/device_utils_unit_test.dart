import 'package:cardmind/models/device.dart';
import 'package:cardmind/utils/device_utils.dart';
import 'package:flutter_test/flutter_test.dart';

String _repeat(String char, int count) {
  return List.filled(count, char).join();
}

void main() {
  Device buildDevice({
    required String id,
    required DeviceStatus status,
    required DateTime lastSeen,
  }) {
    return Device(
      id: id,
      name: 'Device $id',
      type: DeviceType.laptop,
      status: status,
      lastSeen: lastSeen,
      multiaddrs: const [],
    );
  }

  test('it_should_sort_devices_with_online_first_and_recent_first', () {
    final now = DateTime(2026, 2, 1, 12, 0, 0);
    final devices = <Device>[
      buildDevice(
        id: 'offline-old',
        status: DeviceStatus.offline,
        lastSeen: now.subtract(const Duration(days: 1)),
      ),
      buildDevice(
        id: 'online-old',
        status: DeviceStatus.online,
        lastSeen: now.subtract(const Duration(hours: 1)),
      ),
      buildDevice(id: 'online-new', status: DeviceStatus.online, lastSeen: now),
    ];

    final sorted = DeviceUtils.sortDevices(devices);

    expect(sorted.first.id, 'online-new');
    expect(sorted[1].id, 'online-old');
    expect(sorted.last.id, 'offline-old');
  });

  test('it_should_format_last_seen_time', () {
    final now = DateTime.now();

    expect(
      DeviceUtils.formatLastSeen(now.subtract(const Duration(seconds: 30))),
      '刚刚',
    );
    expect(
      DeviceUtils.formatLastSeen(now.subtract(const Duration(minutes: 5))),
      '5 分钟前',
    );
    expect(
      DeviceUtils.formatLastSeen(now.subtract(const Duration(hours: 3))),
      '3 小时前',
    );
    expect(
      DeviceUtils.formatLastSeen(now.subtract(const Duration(days: 2))),
      '2 天前',
    );

    final older = now.subtract(const Duration(days: 8, hours: 2, minutes: 3));
    final expected =
        '${older.year}-${older.month.toString().padLeft(2, '0')}-${older.day.toString().padLeft(2, '0')} '
        '${older.hour.toString().padLeft(2, '0')}:${older.minute.toString().padLeft(2, '0')}';
    expect(DeviceUtils.formatLastSeen(older), expected);
  });

  test('it_should_return_device_type_and_status_names', () {
    expect(DeviceUtils.getDeviceTypeName(DeviceType.phone), '手机');
    expect(DeviceUtils.getDeviceTypeName(DeviceType.laptop), '笔记本电脑');
    expect(DeviceUtils.getDeviceTypeName(DeviceType.tablet), '平板电脑');

    expect(DeviceUtils.getDeviceStatusName(DeviceStatus.online), '在线');
    expect(DeviceUtils.getDeviceStatusName(DeviceStatus.offline), '离线');
  });

  test('it_should_validate_device_name', () {
    expect(DeviceUtils.isValidDeviceName(''), isFalse);
    expect(DeviceUtils.isValidDeviceName('   '), isFalse);
    expect(DeviceUtils.isValidDeviceName(_repeat('a', 33)), isFalse);
    expect(DeviceUtils.isValidDeviceName('Valid Name'), isTrue);
  });

  test('it_should_return_device_name_error_messages', () {
    expect(DeviceUtils.getDeviceNameError(''), '设备名称不能为空');
    expect(DeviceUtils.getDeviceNameError('   '), '设备名称不能为空');
    expect(DeviceUtils.getDeviceNameError(_repeat('a', 33)), '设备名称不能超过 32 个字符');
    expect(DeviceUtils.getDeviceNameError('Valid Name'), isNull);
  });

  test('it_should_format_last_seen_exactly_one_minute', () {
    final now = DateTime.now();
    final result = DeviceUtils.formatLastSeen(
      now.subtract(const Duration(minutes: 1)),
    );

    expect(result, '1 分钟前');
  });

  test('it_should_format_last_seen_exactly_one_hour', () {
    final now = DateTime.now();
    final result = DeviceUtils.formatLastSeen(
      now.subtract(const Duration(hours: 1)),
    );

    expect(result, '1 小时前');
  });

  test('it_should_format_last_seen_seven_days_as_date', () {
    final now = DateTime.now();
    final target = now.subtract(const Duration(days: 7));
    final expected =
        '${target.year}-${target.month.toString().padLeft(2, '0')}-${target.day.toString().padLeft(2, '0')} '
        '${target.hour.toString().padLeft(2, '0')}:${target.minute.toString().padLeft(2, '0')}';

    expect(DeviceUtils.formatLastSeen(target), expected);
  });

  test('it_should_accept_device_name_with_32_chars', () {
    expect(DeviceUtils.isValidDeviceName(_repeat('a', 32)), isTrue);
  });
}
