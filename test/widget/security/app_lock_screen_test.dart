import 'package:cardmind/features/security/app_lock/app_lock_screen.dart';
import 'package:cardmind/features/security/app_lock/app_lock_service.dart';
import 'package:cardmind/features/security/app_lock/app_lock_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScreenGateway implements AppLockGateway {
  (bool, bool) status = (false, true);

  @override
  Future<(bool, bool)> appLockStatus() async => status;

  @override
  Future<void> markBiometricSuccess() async {
    status = (true, true);
  }

  @override
  Future<void> resetAppLockForTests() async {}

  @override
  Future<void> setupAppLock({
    required String pin,
    required bool allowBiometric,
  }) async {
    status = (true, true);
  }

  @override
  Future<void> verifyAppLockWithPin({required String pin}) async {
    status = (true, true);
  }
}

void main() {
  testWidgets('shows setup button when app lock is unconfigured', (
    tester,
  ) async {
    final service = AppLockService(gateway: _ScreenGateway());
    await service.refresh();

    await tester.pumpWidget(
      MaterialApp(
        home: AppLockScreen(service: service, onUnlocked: () {}),
      ),
    );

    expect(find.text('先设置应用锁'), findsOneWidget);
    expect(find.text('设置并继续'), findsOneWidget);
  });

  testWidgets('submitting pin from locked state unlocks app', (tester) async {
    final gateway = _ScreenGateway()..status = (true, false);
    final service = AppLockService(gateway: gateway);
    await service.refresh();

    var unlocked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockScreen(
          service: service,
          onUnlocked: () {
            unlocked = true;
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('app_lock.pin_field')),
      '1234',
    );
    await tester.tap(find.byKey(const ValueKey('app_lock.submit_button')));
    await tester.pumpAndSettle();

    expect(unlocked, isTrue);
    expect(service.state.phase, AppLockPhase.unlocked);
  });
}
