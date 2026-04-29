import 'package:cardmind/features/security/app_lock/app_lock_screen.dart';
import 'package:cardmind/features/security/app_lock/app_lock_service.dart';
import 'package:cardmind/features/security/app_lock/app_lock_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScreenGateway implements AppLockGateway {
  (bool, bool) status = (false, true);
  String? setupPinValue;

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
    setupPinValue = pin;
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

    expect(find.text('设置应用锁'), findsWidgets);
    expect(find.text('设置并继续'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('app_lock.confirm_pin_field')),
      findsOneWidget,
    );
  });

  testWidgets('desktop setup uses Pencil desktop copy and title scale', (
    tester,
  ) async {
    final service = AppLockService(gateway: _ScreenGateway());
    await service.refresh();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(960, 720)),
          child: AppLockScreen(service: service, onUnlocked: () {}),
        ),
      ),
    );

    final titleWidgets = tester.widgetList<Text>(find.text('设置应用锁'));
    expect(titleWidgets.any((text) => text.style?.fontSize == 44), isTrue);
    expect(find.text('创建应用锁'), findsOneWidget);
    expect(
      find.text('创建或加入数据池前，请先设置应用锁。数据池数据可能保留在本设备上，因此即使他人拿到设备，也无法看到数据池内容。'),
      findsOneWidget,
    );
  });

  testWidgets('desktop locked state uses Pencil session lock copy', (
    tester,
  ) async {
    final gateway = _ScreenGateway()..status = (true, false);
    final service = AppLockService(gateway: gateway);
    await service.refresh();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(960, 720)),
          child: AppLockScreen(service: service, onUnlocked: () {}),
        ),
      ),
    );

    expect(find.text('会话已锁定'), findsOneWidget);
    expect(
      find.text('本次会话的数据池页面已锁定。打开数据池设置、成员、邀请或同步笔记前，请先完成验证。'),
      findsOneWidget,
    );
    expect(find.text('解锁数据池'), findsOneWidget);
  });

  testWidgets('setup requires matching pin confirmation', (tester) async {
    final gateway = _ScreenGateway();
    final service = AppLockService(gateway: gateway);
    await service.refresh();

    await tester.pumpWidget(
      MaterialApp(
        home: AppLockScreen(service: service, onUnlocked: () {}),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('app_lock.pin_field')),
      '1234',
    );
    await tester.enterText(
      find.byKey(const ValueKey('app_lock.confirm_pin_field')),
      '5678',
    );
    await tester.tap(find.byKey(const ValueKey('app_lock.submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('两次输入的数字密码不一致'), findsOneWidget);
    expect(gateway.setupPinValue, isNull);
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

  testWidgets('biometric button unlocks when allowBiometric is true', (
    tester,
  ) async {
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

    await tester.tap(find.byKey(const ValueKey('app_lock.biometric_button')));
    await tester.pumpAndSettle();

    expect(unlocked, isTrue);
    expect(service.state.phase, AppLockPhase.unlocked);
  });
}
