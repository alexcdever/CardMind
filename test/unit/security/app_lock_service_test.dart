import 'package:cardmind/features/security/app_lock/app_lock_service.dart';
import 'package:cardmind/features/security/app_lock/app_lock_state.dart';
import 'package:cardmind/bridge_generated/models/api_error.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAppLockGateway implements AppLockGateway {
  (bool, bool) status = (false, true);
  String? verifiedPin;
  String? setupPin;
  bool biometricMarked = false;
  Object? statusError;
  Object? setupError;
  Object? verifyError;
  Object? biometricError;

  @override
  Future<(bool, bool)> appLockStatus() async {
    if (statusError != null) throw statusError!;
    return status;
  }

  @override
  Future<void> markBiometricSuccess() async {
    if (biometricError != null) throw biometricError!;
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
    if (setupError != null) throw setupError!;
    setupPin = pin;
    status = (true, true);
  }

  @override
  Future<void> verifyAppLockWithPin({required String pin}) async {
    if (verifyError != null) throw verifyError!;
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

  test('refresh maps configured locked state', () async {
    final gateway = _FakeAppLockGateway()..status = (true, false);
    final service = AppLockService(gateway: gateway);

    await service.refresh();

    expect(service.state.phase, AppLockPhase.locked);
  });

  test('refresh maps ApiError into error state', () async {
    final gateway = _FakeAppLockGateway()
      ..statusError = ApiError(code: 'APP_LOCK_REQUIRED', message: 'boom');
    final service = AppLockService(gateway: gateway);

    await service.refresh();

    expect(service.state.phase, AppLockPhase.error);
    expect(service.state.message, 'boom');
  });

  test('setupPin maps ApiError into error state', () async {
    final gateway = _FakeAppLockGateway()
      ..setupError = ApiError(code: 'INVALID_ARGUMENT', message: 'invalid');
    final service = AppLockService(gateway: gateway);

    await service.setupPin('1234');

    expect(service.state.phase, AppLockPhase.error);
    expect(service.state.message, 'invalid');
  });

  test('unlockWithPin unlocks app lock', () async {
    final gateway = _FakeAppLockGateway()..status = (true, false);
    final service = AppLockService(gateway: gateway);

    await service.unlockWithPin('1234');

    expect(gateway.verifiedPin, '1234');
    expect(service.state.isUnlocked, isTrue);
  });

  test('unlockWithPin maps ApiError into locked state message', () async {
    final gateway = _FakeAppLockGateway()
      ..status = (true, false)
      ..verifyError = ApiError(code: 'APP_LOCKED', message: 'locked');
    final service = AppLockService(gateway: gateway);

    await service.unlockWithPin('0000');

    expect(service.state.phase, AppLockPhase.locked);
    expect(service.state.message, 'locked');
  });

  test('unlockWithBiometricSuccess unlocks app lock', () async {
    final gateway = _FakeAppLockGateway()..status = (true, false);
    final service = AppLockService(gateway: gateway);

    await service.unlockWithBiometricSuccess();

    expect(gateway.biometricMarked, isTrue);
    expect(service.state.isUnlocked, isTrue);
  });

  test('unlockWithBiometricSuccess maps ApiError into locked state', () async {
    final gateway = _FakeAppLockGateway()
      ..status = (true, false)
      ..biometricError = ApiError(code: 'APP_LOCKED', message: 'bio failed');
    final service = AppLockService(gateway: gateway);

    await service.unlockWithBiometricSuccess();

    expect(service.state.phase, AppLockPhase.locked);
    expect(service.state.message, 'bio failed');
  });
}
