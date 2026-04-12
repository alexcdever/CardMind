import 'package:cardmind/features/pool/pool_page.dart';
import 'package:cardmind/features/pool/pool_shell.dart';
import 'package:cardmind/features/security/app_lock/app_lock_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _UnlockedGateway implements AppLockGateway {
  @override
  Future<(bool, bool)> appLockStatus() async => (true, true);

  @override
  Future<void> markBiometricSuccess() async {}

  @override
  Future<void> resetAppLockForTests() async {}

  @override
  Future<void> setupAppLock({
    required String pin,
    required bool allowBiometric,
  }) async {}

  @override
  Future<void> verifyAppLockWithPin({required String pin}) async {}
}

void main() {
  testWidgets(
    'pool shell initializes network after unlock before showing pool page',
    (tester) async {
      final service = AppLockService(gateway: _UnlockedGateway());
      var loaderCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PoolShell(
            service: service,
            appDataDir: 'test-app-dir',
            poolNetworkLoader: (appDataDir) async {
              loaderCalls += 1;
              expect(appDataDir, 'test-app-dir');
              return BigInt.from(7);
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(loaderCalls, 1);
      final poolPage = tester.widget<PoolPage>(find.byType(PoolPage));
      expect(poolPage.networkId, BigInt.from(7));
    },
  );
}
