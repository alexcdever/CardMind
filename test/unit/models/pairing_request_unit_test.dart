import 'package:cardmind/models/device.dart';
import 'package:cardmind/models/pairing_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('it_should_serialize_and_deserialize_pairing_request', () {
    final request = PairingRequest(
      requestId: 'req-1',
      deviceId: 'peer-1',
      deviceName: 'Device',
      deviceType: DeviceType.laptop,
      verificationCode: '123456',
      timestamp: DateTime(2026, 2, 1, 12, 0, 0),
    );

    final json = request.toJson();
    final restored = PairingRequest.fromJson(json);

    expect(restored, equals(request));
  });

  test('it_should_calculate_expiration_and_remaining_time', () {
    final now = DateTime.now();
    final request = PairingRequest(
      requestId: 'req-1',
      deviceId: 'peer-1',
      deviceName: 'Device',
      deviceType: DeviceType.phone,
      verificationCode: '654321',
      timestamp: now,
    );

    expect(request.expiresAt, equals(now.add(const Duration(minutes: 5))));
    expect(request.isExpired, isFalse);
    expect(request.timeRemaining, greaterThan(Duration.zero));
  });

  test('it_should_mark_expired_request', () {
    final past = DateTime.now().subtract(const Duration(minutes: 6));
    final request = PairingRequest(
      requestId: 'req-2',
      deviceId: 'peer-2',
      deviceName: 'Device',
      deviceType: DeviceType.tablet,
      verificationCode: '000000',
      timestamp: past,
    );

    expect(request.isExpired, isTrue);
    expect(request.timeRemaining, Duration.zero);
  });

  test('it_should_copy_with_updated_fields', () {
    final request = PairingRequest(
      requestId: 'req-1',
      deviceId: 'peer-1',
      deviceName: 'Device',
      deviceType: DeviceType.laptop,
      verificationCode: '123456',
      timestamp: DateTime(2026, 2, 1, 12, 0, 0),
    );

    final updated = request.copyWith(deviceName: 'Updated');

    expect(updated.deviceName, 'Updated');
    expect(updated.requestId, request.requestId);
  });

  test('it_should_toJson_contains_device_type_name', () {
    final request = PairingRequest(
      requestId: 'req-3',
      deviceId: 'peer-3',
      deviceName: 'Device',
      deviceType: DeviceType.phone,
      verificationCode: '111111',
      timestamp: DateTime(2026, 2, 1, 12, 0, 0),
    );

    final json = request.toJson();

    expect(json['deviceType'], 'phone');
    expect(json['timestamp'], request.timestamp.millisecondsSinceEpoch);
  });

  test('it_should_toString_contains_request_id', () {
    final request = PairingRequest(
      requestId: 'req-4',
      deviceId: 'peer-4',
      deviceName: 'Device',
      deviceType: DeviceType.tablet,
      verificationCode: '222222',
      timestamp: DateTime(2026, 2, 1, 12, 0, 0),
    );

    expect(request.toString(), contains('req-4'));
  });
}
