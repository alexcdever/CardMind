import 'package:cardmind/models/device.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Device Tests', () {
    test('toJson converts Device to JSON correctly', () {
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

    test('fromJson creates Device from JSON correctly', () {
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

    test('fromJson handles missing multiaddrs', () {
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

    test('copyWith creates new Device with updated fields', () {
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

    test('JSON round-trip preserves data', () {
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
  });

  group('PeerIdValidator Tests', () {
    test('validates correct PeerId', () {
      const validPeerId = '12D3KooWTest123456789ABCDEFGHJKLMNPQRSTUVWXYZabc';
      expect(PeerIdValidator.isValid(validPeerId), true);
      expect(PeerIdValidator.validate(validPeerId), isNull);
    });

    test('rejects PeerId without correct prefix', () {
      const invalidPeerId = '11D3KooWTest123456789ABCDEFGHJKLMNPQRSTUVWXYZabc';
      expect(PeerIdValidator.isValid(invalidPeerId), false);
      expect(PeerIdValidator.validate(invalidPeerId), isNotNull);
      expect(PeerIdValidator.validate(invalidPeerId), contains('12D3KooW'));
    });

    test('rejects PeerId that is too short', () {
      const shortPeerId = '12D3KooWShort';
      expect(PeerIdValidator.isValid(shortPeerId), false);
      expect(PeerIdValidator.validate(shortPeerId), isNotNull);
      expect(PeerIdValidator.validate(shortPeerId), contains('长度不足'));
    });

    test('rejects PeerId that is too long', () {
      final longPeerId = '12D3KooW${'A' * 100}'; // 超过 60 个字符
      expect(PeerIdValidator.isValid(longPeerId), false);
      expect(PeerIdValidator.validate(longPeerId), isNotNull);
      expect(PeerIdValidator.validate(longPeerId), contains('长度过长'));
    });

    test('rejects PeerId with invalid characters', () {
      const invalidPeerId = '12D3KooWTest123456789ABCDEFGHJKLMNPQRSTUVWXYZ@#\$';
      expect(PeerIdValidator.isValid(invalidPeerId), false);
      expect(PeerIdValidator.validate(invalidPeerId), isNotNull);
      expect(PeerIdValidator.validate(invalidPeerId), contains('无效字符'));
    });

    test('rejects empty PeerId', () {
      const emptyPeerId = '';
      expect(PeerIdValidator.isValid(emptyPeerId), false);
      expect(PeerIdValidator.validate(emptyPeerId), isNotNull);
      expect(PeerIdValidator.validate(emptyPeerId), contains('不能为空'));
    });

    test('formats PeerId correctly', () {
      const peerId = '12D3KooWTest123456789ABCDEFGHJKLMNPQRSTUVWXYZabc';
      final formatted = PeerIdValidator.format(peerId);

      expect(formatted, contains('12D3KooWTest'));
      expect(formatted, contains('...'));
      expect(formatted, contains('XYZabc'));
      expect(formatted.length, lessThan(peerId.length));
    });

    test('does not format short PeerId', () {
      const shortPeerId = '12D3KooWShort';
      final formatted = PeerIdValidator.format(shortPeerId);

      expect(formatted, shortPeerId);
      expect(formatted, isNot(contains('...')));
    });

    test('validates real libp2p PeerId format', () {
      // 真实的 libp2p PeerId 示例
      const realPeerId = '12D3KooWEyoppNCUx8Yx66oV9fJnriXwCcXwDDUA2kj6vnc6iDEp';
      expect(PeerIdValidator.isValid(realPeerId), true);
      expect(PeerIdValidator.validate(realPeerId), isNull);
    });

    test('rejects Base58 invalid characters (0, O, I, l)', () {
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
