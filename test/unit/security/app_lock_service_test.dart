import 'package:cardmind/features/security/app_lock/app_lock_service.dart';
import 'package:cardmind/features/security/app_lock/app_lock_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAppLockGateway implements AppLockGateway {
  (bool, bool) status = (false, true);
  String? verifiedPin;
  String? setupPin;
  bool biometricMarked = false;

  @override
  Future<(bool, bool)> appLockStatus() async => status;

  @override
  Future<void> markBiometricSuccess() async {
    biometricMarked = true;
    status = (true, true);
  }

  @override
  Future<void> resetAppLockForTests() async {
    status = (false, true);
  }

  @override
  Future<void> setupAppLock({
    required String pin,
    required bool allowBiometric,
  }) async {
    setupPin = pin;
    status = (true, true);
  }

  @override
  Future<void> verifyAppLockWithPin({required String pin}) async {
    verifiedPin = pin;
    status = (true, true);
  }
}

void main() {
  test('refresh maps unconfigured state', () async {
    final gateway = _FakeAppLockGateway()..status = (false, true);
    final service = AppLockService(gateway: gateway);

    await service.refresh();

    expect(service.state.phase, AppLockPhase.unconfigured);
  });

  test('setupPin unlocks app lock', () async {
    final gateway = _FakeAppLockGateway();
    final service = AppLockService(gateway: gateway);

    await service.setupPin('1234');

    expect(gateway.setupPin, '1234');
    expect(service.state.isUnlocked, isTrue);
  });

  test('unlockWithPin unlocks app lock', () async {
    final gateway = _FakeAppLockGateway()..status = (true, false);
    final service = AppLockService(gateway: gateway);

    await service.unlockWithPin('1234');

    expect(gateway.verifiedPin, '1234');
    expect(service.state.isUnlocked, isTrue);
  });

  test('unlockWithBiometricSuccess unlocks app lock', () async {
    final gateway = _FakeAppLockGateway()..status = (true, false);
    final service = AppLockService(gateway: gateway);

    await service.unlockWithBiometricSuccess();

    expect(gateway.biometricMarked, isTrue);
    expect(service.state.isUnlocked, isTrue);
  });
}
