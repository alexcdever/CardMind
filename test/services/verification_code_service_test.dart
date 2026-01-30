import 'package:cardmind/services/verification_code_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VerificationCodeService Tests', () {
    late VerificationCodeService service;

    setUp(() {
      service = VerificationCodeService();
    });

    tearDown(() {
      service.dispose();
    });

    test('generateCode returns 6-digit code', () {
      final code = service.generateCode();

      expect(code.length, equals(6));
      expect(int.tryParse(code), isNotNull);
      expect(int.parse(code), greaterThanOrEqualTo(100000));
      expect(int.parse(code), lessThanOrEqualTo(999999));
    });

    test('generateCode returns different codes', () {
      final codes = <String>{};

      // 生成 100 个验证码，应该都不相同
      for (int i = 0; i < 100; i++) {
        codes.add(service.generateCode());
      }

      // 至少有 95 个不同的验证码（允许极小概率的重复）
      expect(codes.length, greaterThan(95));
    });

    test('createSession creates valid session', () {
      final session = service.createSession(
        remotePeerId: '12D3KooWTest',
        remoteDeviceName: 'Test Device',
      );

      expect(session.code.length, equals(6));
      expect(session.remotePeerId, equals('12D3KooWTest'));
      expect(session.remoteDeviceName, equals('Test Device'));
      expect(session.status, equals(VerificationStatus.pending));
      expect(session.isExpired, isFalse);
    });

    test('createSession sets 5-minute expiration', () {
      final session = service.createSession(
        remotePeerId: '12D3KooWTest',
        remoteDeviceName: 'Test Device',
      );

      final expectedExpiry = session.createdAt.add(const Duration(minutes: 5));
      expect(
        session.expiresAt.difference(expectedExpiry).inSeconds,
        lessThan(1),
      );
    });

    test('verifyCode returns true for correct code', () {
      final session = service.createSession(
        remotePeerId: '12D3KooWTest',
        remoteDeviceName: 'Test Device',
      );

      final result = service.verifyCode(
        remotePeerId: '12D3KooWTest',
        inputCode: session.code,
      );

      expect(result, isTrue);
      expect(session.status, equals(VerificationStatus.verified));
    });

    test('verifyCode returns false for incorrect code', () {
      service.createSession(
        remotePeerId: '12D3KooWTest',
        remoteDeviceName: 'Test Device',
      );

      final result = service.verifyCode(
        remotePeerId: '12D3KooWTest',
        inputCode: '000000',
      );

      expect(result, isFalse);
    });

    test('verifyCode returns false for non-existent session', () {
      final result = service.verifyCode(
        remotePeerId: '12D3KooWNonExistent',
        inputCode: '123456',
      );

      expect(result, isFalse);
    });

    test('getSession returns existing session', () {
      final created = service.createSession(
        remotePeerId: '12D3KooWTest',
        remoteDeviceName: 'Test Device',
      );

      final retrieved = service.getSession('12D3KooWTest');

      expect(retrieved, isNotNull);
      expect(retrieved!.code, equals(created.code));
      expect(retrieved.remotePeerId, equals(created.remotePeerId));
    });

    test('getSession returns null for non-existent session', () {
      final session = service.getSession('12D3KooWNonExistent');

      expect(session, isNull);
    });

    test('cancelSession removes session', () {
      service
        ..createSession(
          remotePeerId: '12D3KooWTest',
          remoteDeviceName: 'Test Device',
        )
        ..cancelSession('12D3KooWTest');

      final session = service.getSession('12D3KooWTest');
      expect(session, isNull);
    });

    test('createSession replaces existing session for same peer', () {
      final session1 = service.createSession(
        remotePeerId: '12D3KooWTest',
        remoteDeviceName: 'Test Device',
      );

      final session2 = service.createSession(
        remotePeerId: '12D3KooWTest',
        remoteDeviceName: 'Test Device',
      );

      expect(session1.code, isNot(equals(session2.code)));

      final retrieved = service.getSession('12D3KooWTest');
      expect(retrieved!.code, equals(session2.code));
    });

    test('remainingSeconds calculates correctly', () {
      final session = service.createSession(
        remotePeerId: '12D3KooWTest',
        remoteDeviceName: 'Test Device',
      );

      // 应该接近 300 秒（5 分钟）
      expect(session.remainingSeconds, greaterThan(295));
      expect(session.remainingSeconds, lessThanOrEqualTo(300));
    });

    test('remainingPercentage calculates correctly', () {
      final session = service.createSession(
        remotePeerId: '12D3KooWTest',
        remoteDeviceName: 'Test Device',
      );

      // 刚创建时应该接近 1.0
      expect(session.remainingPercentage, greaterThan(0.98));
      expect(session.remainingPercentage, lessThanOrEqualTo(1.0));
    });

    test('sessionStateChanges emits events', () async {
      final events = <VerificationSession>[];
      service.sessionStateChanges.listen(events.add);

      // 创建会话
      service.createSession(
        remotePeerId: '12D3KooWTest',
        remoteDeviceName: 'Test Device',
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(events.length, greaterThan(0));
      expect(events.first.remotePeerId, equals('12D3KooWTest'));
    });

    test('verifyCode emits status change event', () async {
      final events = <VerificationSession>[];
      service.sessionStateChanges.listen(events.add);

      final session = service.createSession(
        remotePeerId: '12D3KooWTest',
        remoteDeviceName: 'Test Device',
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));
      events.clear();

      service.verifyCode(remotePeerId: '12D3KooWTest', inputCode: session.code);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(events.length, greaterThan(0));
      expect(events.last.status, equals(VerificationStatus.verified));
    });
  });

  group('VerificationCodeManager Tests', () {
    tearDown(VerificationCodeManager.reset);

    test('returns singleton instance', () {
      final instance1 = VerificationCodeManager.instance;
      final instance2 = VerificationCodeManager.instance;

      expect(instance1, same(instance2));
    });

    test('reset creates new instance', () {
      final instance1 = VerificationCodeManager.instance;

      VerificationCodeManager.reset();

      final instance2 = VerificationCodeManager.instance;

      expect(instance1, isNot(same(instance2)));
    });
  });
}
