import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/bridge_generated/models/api_error.dart';
import 'package:cardmind/features/security/app_lock/app_lock_state.dart';
import 'package:flutter/foundation.dart';

abstract class AppLockGateway {
  Future<(bool, bool)> appLockStatus();
  Future<void> setupAppLock({
    required String pin,
    required bool allowBiometric,
  });
  Future<void> verifyAppLockWithPin({required String pin});
  Future<void> markBiometricSuccess();
  Future<void> resetAppLockForTests();
}

class FrbAppLockGateway implements AppLockGateway {
  @override
  Future<(bool, bool)> appLockStatus() => frb.appLockStatus();

  @override
  Future<void> setupAppLock({
    required String pin,
    required bool allowBiometric,
  }) => frb.setupAppLock(pin: pin, allowBiometric: allowBiometric);

  @override
  Future<void> verifyAppLockWithPin({required String pin}) =>
      frb.verifyAppLockWithPin(pin: pin);

  @override
  Future<void> markBiometricSuccess() => frb.markBiometricSuccess();

  @override
  Future<void> resetAppLockForTests() => frb.resetAppLockForTests();
}

class AppLockService extends ChangeNotifier {
  AppLockService({AppLockGateway? gateway})
    : _gateway = gateway ?? FrbAppLockGateway();

  final AppLockGateway _gateway;

  AppLockState _state = const AppLockState.loading();
  AppLockState get state => _state;

  Future<void> refresh() async {
    _state = const AppLockState.loading();
    notifyListeners();
    try {
      final (configured, unlocked) = await _gateway.appLockStatus();
      if (!configured) {
        _state = const AppLockState.unconfigured();
      } else if (unlocked) {
        _state = const AppLockState.unlocked(allowBiometric: true);
      } else {
        _state = const AppLockState.locked(allowBiometric: true);
      }
    } on ApiError catch (error) {
      _state = AppLockState.error(message: error.message);
    } catch (_) {
      _state = const AppLockState.error(message: '应用锁状态获取失败');
    }
    notifyListeners();
  }

  Future<void> setupPin(String pin, {bool allowBiometric = true}) async {
    _state = const AppLockState.loading();
    notifyListeners();
    try {
      await _gateway.setupAppLock(pin: pin, allowBiometric: allowBiometric);
      _state = AppLockState.unlocked(allowBiometric: allowBiometric);
    } on ApiError catch (error) {
      _state = AppLockState.error(message: error.message);
    } catch (_) {
      _state = const AppLockState.error(message: '应用锁设置失败');
    }
    notifyListeners();
  }

  Future<void> unlockWithPin(String pin) async {
    _state = const AppLockState.loading(allowBiometric: true);
    notifyListeners();
    try {
      await _gateway.verifyAppLockWithPin(pin: pin);
      _state = const AppLockState.unlocked(allowBiometric: true);
    } on ApiError catch (error) {
      _state = AppLockState.locked(
        allowBiometric: true,
        message: error.message,
      );
    } catch (_) {
      _state = const AppLockState.error(message: '应用锁解锁失败');
    }
    notifyListeners();
  }

  Future<void> unlockWithBiometricSuccess() async {
    try {
      await _gateway.markBiometricSuccess();
      _state = const AppLockState.unlocked(allowBiometric: true);
    } on ApiError catch (error) {
      _state = AppLockState.locked(
        allowBiometric: true,
        message: error.message,
      );
    }
    notifyListeners();
  }
}
