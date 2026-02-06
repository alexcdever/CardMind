import 'package:cardmind/models/device.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Device Tests', () {
    test('it_should_toJson converts Device to JSON correctly', () {
      final device = Device(
        id: '12D3KooWTest123456789',
        name: 'Test Device',
        type: DeviceType.laptop,
        status: DeviceStatus.online,
        lastSeen: DateTime(2024, 1, 1, 12, 0, 0),
        multiaddrs: ['/ip4/192.168.1.100/tcp/4001'],
      );

      final json = device.toJson();

      expect(json['id'], '12D3KooWTest123456789');
      expect(json['name'], 'Test Device');
      expect(json['type'], 'laptop');
      expect(json['status'], 'online');
      expect(json['lastSeen'], isA<int>());
      expect(json['multiaddrs'], isA<List<dynamic>>());
      expect(json['multiaddrs'].length, 1);
    });

    test('it_should_fromJson creates Device from JSON correctly', () {
      final json = {
        'id': '12D3KooWTest123456789',
        'name': 'Test Device',
        'type': 'laptop',
        'status': 'online',
        'lastSeen': DateTime(2024, 1, 1, 12, 0, 0).millisecondsSinceEpoch,
        'multiaddrs': ['/ip4/192.168.1.100/tcp/4001'],
      };

      final device = Device.fromJson(json);

      expect(device.id, '12D3KooWTest123456789');
      expect(device.name, 'Test Device');
      expect(device.type, DeviceType.laptop);
      expect(device.status, DeviceStatus.online);
      expect(device.multiaddrs.length, 1);
    });

    test('it_should_fromJson handles missing multiaddrs', () {
      final json = {
        'id': '12D3KooWTest123456789',
        'name': 'Test Device',
        'type': 'phone',
        'status': 'offline',
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      };

      final device = Device.fromJson(json);

      expect(device.multiaddrs, isEmpty);
    });

    test('it_should_copyWith creates new Device with updated fields', () {
      final original = Device(
        id: '12D3KooWTest123456789',
        name: 'Original Name',
        type: DeviceType.laptop,
        status: DeviceStatus.offline,
        lastSeen: DateTime.now(),
      );

      final updated = original.copyWith(
        name: 'Updated Name',
        status: DeviceStatus.online,
      );

      expect(updated.id, original.id);
      expect(updated.name, 'Updated Name');
      expect(updated.type, original.type);
      expect(updated.status, DeviceStatus.online);
    });

    test('it_should_JSON round-trip preserves data', () {
      final original = Device(
        id: '12D3KooWTest123456789',
        name: 'Test Device',
        type: DeviceType.tablet,
        status: DeviceStatus.online,
        lastSeen: DateTime(2024, 1, 1, 12, 0, 0),
        multiaddrs: ['/ip4/192.168.1.100/tcp/4001', '/ip6/::1/tcp/4001'],
      );

      final json = original.toJson();
      final restored = Device.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.type, original.type);
      expect(restored.status, original.status);
      expect(restored.multiaddrs, original.multiaddrs);
    });

    test('it_should_fromJson_fallbacks_for_invalid_type_and_status', () {
      final json = {
        'id': '12D3KooWInvalid',
        'name': 'Invalid Device',
        'type': 'invalid-type',
        'status': 'invalid-status',
        'lastSeen': DateTime(2024, 1, 1, 12, 0, 0).millisecondsSinceEpoch,
      };

      final device = Device.fromJson(json);

      expect(device.type, DeviceType.laptop);
      expect(device.status, DeviceStatus.offline);
    });

    test('it_should_isOnline_reflects_status', () {
      final onlineDevice = Device(
        id: 'peer-1',
        name: 'Online',
        type: DeviceType.phone,
        status: DeviceStatus.online,
        lastSeen: DateTime.now(),
      );
      final offlineDevice = Device(
        id: 'peer-2',
        name: 'Offline',
        type: DeviceType.tablet,
        status: DeviceStatus.offline,
        lastSeen: DateTime.now(),
      );

      expect(onlineDevice.isOnline, isTrue);
      expect(offlineDevice.isOnline, isFalse);
    });

    test('it_should_copyWith_keeps_original_values_when_null', () {
      final original = Device(
        id: 'peer-1',
        name: 'Original',
        type: DeviceType.laptop,
        status: DeviceStatus.offline,
        lastSeen: DateTime(2024, 1, 1, 12, 0, 0),
      );

      final updated = original.copyWith();

      expect(updated.id, original.id);
      expect(updated.name, original.name);
      expect(updated.type, original.type);
      expect(updated.status, original.status);
      expect(updated.lastSeen, original.lastSeen);
    });

    test('it_should_toJson_preserves_last_seen_millis', () {
      final lastSeen = DateTime(2024, 1, 1, 12, 0, 0);
      final device = Device(
        id: 'peer-1',
        name: 'Device',
        type: DeviceType.laptop,
        status: DeviceStatus.online,
        lastSeen: lastSeen,
      );

      final json = device.toJson();

      expect(json['lastSeen'], lastSeen.millisecondsSinceEpoch);
    });
  });

  group('PeerIdValidator Tests', () {
    test('it_should_validates correct PeerId', () {
      const validPeerId = '12D3KooWTest123456789ABCDEFGHJKLMNPQRSTUVWXYZabc';
      expect(PeerIdValidator.isValid(validPeerId), true);
      expect(PeerIdValidator.validate(validPeerId), isNull);
    });

    test('it_should_rejects PeerId without correct prefix', () {
      const invalidPeerId = '11D3KooWTest123456789ABCDEFGHJKLMNPQRSTUVWXYZabc';
      expect(PeerIdValidator.isValid(invalidPeerId), false);
      expect(PeerIdValidator.validate(invalidPeerId), isNotNull);
      expect(PeerIdValidator.validate(invalidPeerId), contains('12D3KooW'));
    });

    test('it_should_rejects PeerId that is too short', () {
      const shortPeerId = '12D3KooWShort';
      expect(PeerIdValidator.isValid(shortPeerId), false);
      expect(PeerIdValidator.validate(shortPeerId), isNotNull);
      expect(PeerIdValidator.validate(shortPeerId), contains('长度不足'));
    });

    test('it_should_rejects PeerId that is too long', () {
      final longPeerId = '12D3KooW${'A' * 100}'; // 超过 60 个字符
      expect(PeerIdValidator.isValid(longPeerId), false);
      expect(PeerIdValidator.validate(longPeerId), isNotNull);
      expect(PeerIdValidator.validate(longPeerId), contains('长度过长'));
    });

    test('it_should_rejects PeerId with invalid characters', () {
      const invalidPeerId = '12D3KooWTest123456789ABCDEFGHJKLMNPQRSTUVWXYZ@#\$';
      expect(PeerIdValidator.isValid(invalidPeerId), false);
      expect(PeerIdValidator.validate(invalidPeerId), isNotNull);
      expect(PeerIdValidator.validate(invalidPeerId), contains('无效字符'));
    });

    test('it_should_rejects empty PeerId', () {
      const emptyPeerId = '';
      expect(PeerIdValidator.isValid(emptyPeerId), false);
      expect(PeerIdValidator.validate(emptyPeerId), isNotNull);
      expect(PeerIdValidator.validate(emptyPeerId), contains('不能为空'));
    });

    test('it_should_formats PeerId correctly', () {
      const peerId = '12D3KooWTest123456789ABCDEFGHJKLMNPQRSTUVWXYZabc';
      final formatted = PeerIdValidator.format(peerId);

      expect(formatted, contains('12D3KooWTest'));
      expect(formatted, contains('...'));
      expect(formatted, contains('XYZabc'));
      expect(formatted.length, lessThan(peerId.length));
    });

    test('it_should_does not format short PeerId', () {
      const shortPeerId = '12D3KooWShort';
      final formatted = PeerIdValidator.format(shortPeerId);

      expect(formatted, shortPeerId);
      expect(formatted, isNot(contains('...')));
    });

    test('it_should_validates real libp2p PeerId format', () {
      // 真实的 libp2p PeerId 示例
      const realPeerId = '12D3KooWEyoppNCUx8Yx66oV9fJnriXwCcXwDDUA2kj6vnc6iDEp';
      expect(PeerIdValidator.isValid(realPeerId), true);
      expect(PeerIdValidator.validate(realPeerId), isNull);
    });

    test('it_should_rejects Base58 invalid characters (0, O, I, l)', () {
      // Base58 不包含 0, O, I, l 这些容易混淆的字符
      const invalidChars = ['0', 'O', 'I', 'l'];

      for (final char in invalidChars) {
        final peerId = '12D3KooWTest123456789ABCDEFGHJKLMNPQRSTUVWXY$char';
        expect(
          PeerIdValidator.isValid(peerId),
          false,
          reason: 'Should reject character: $char',
        );
      }
    });
  });
}
