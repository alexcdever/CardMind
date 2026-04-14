import 'package:cardmind/features/pool/pool_page.dart';
import 'package:cardmind/features/pool/pool_shell.dart';
import 'package:cardmind/features/security/app_lock/app_lock_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'dart:io';

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

class _ConfigurableGateway implements AppLockGateway {
  _ConfigurableGateway({required this.configured, required this.unlocked});

  bool configured;
  bool unlocked;
  String? setupPinValue;
  String? verifyPinValue;

  @override
  Future<(bool, bool)> appLockStatus() async => (configured, unlocked);

  @override
  Future<void> markBiometricSuccess() async {}

  @override
  Future<void> resetAppLockForTests() async {}

  @override
  Future<void> setupAppLock({
    required String pin,
    required bool allowBiometric,
  }) async {
    setupPinValue = pin;
    configured = true;
    unlocked = true;
  }

  @override
  Future<void> verifyAppLockWithPin({required String pin}) async {
    verifyPinValue = pin;
    unlocked = true;
  }
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

  testWidgets('pool shell auto unlocks with debug pin before loading network', (
    tester,
  ) async {
    final gateway = _ConfigurableGateway(configured: false, unlocked: false);
    final service = AppLockService(gateway: gateway);
    var loaderCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: PoolShell(
          service: service,
          appDataDir: 'test-app-dir',
          debugAutoPin: '1234',
          poolNetworkLoader: (appDataDir) async {
            loaderCalls += 1;
            return BigInt.from(9);
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(gateway.setupPinValue, '1234');
    expect(loaderCalls, 1);
    final poolPage = tester.widget<PoolPage>(find.byType(PoolPage));
    expect(poolPage.networkId, BigInt.from(9));
  });

  testWidgets('pool shell forwards debug flags into pool page', (tester) async {
    final service = AppLockService(gateway: _UnlockedGateway());

    await tester.pumpWidget(
      MaterialApp(
        home: PoolShell(
          service: service,
          appDataDir: 'test-app-dir',
          debugPrintInvite: true,
          debugJoinTrace: true,
          poolNetworkLoader: (appDataDir) async => BigInt.from(13),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final poolPage = tester.widget<PoolPage>(find.byType(PoolPage));
    expect(poolPage.debugPrintInvite, isTrue);
    expect(poolPage.debugJoinTrace, isTrue);
  });

  testWidgets('pool shell can export debug status milestones to file', (
    tester,
  ) async {
    final service = AppLockService(gateway: _UnlockedGateway());
    final tempDir = await Directory.systemTemp.createTemp(
      'cardmind-pool-shell-status-',
    );
    final statusPath = p.join(tempDir.path, 'status.log');

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: PoolShell(
            service: service,
            appDataDir: 'test-app-dir',
            debugStatusExportPath: statusPath,
            poolNetworkLoader: (appDataDir) async => BigInt.from(11),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      final status = await File(statusPath).readAsString();
      expect(status, contains('app_lock:unlocked'));
      expect(status, contains('network_ready:11'));
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}
