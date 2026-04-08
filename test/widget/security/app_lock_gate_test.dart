import 'package:cardmind/features/security/app_lock/app_lock_gate.dart';
import 'package:cardmind/features/security/app_lock/app_lock_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _GuardGateway implements AppLockGateway {
  (bool, bool) status;

  _GuardGateway(this.status);

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
  testWidgets('guard shows child immediately when already unlocked', (
    tester,
  ) async {
    final service = AppLockService(gateway: _GuardGateway((true, true)));

    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(service: service, child: const Text('guarded-child')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('guarded-child'), findsOneWidget);
    expect(find.byKey(const ValueKey('app_lock.submit_button')), findsNothing);
  });
}
