import 'package:cardmind/pages/devices_page.dart';
import 'package:cardmind/src/rust/store.dart';
import 'package:cardmind/ui/design_system/cardmind_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/note_repository_stub.dart';

/// 设备名可编辑：设备页本机卡片编辑入口。
///
/// 覆盖：弹窗可访问性、保存/取消/空值/同名分支、错误内联（不是 SnackBar）。

// ━━ fake ━━

class _FakeRepository extends NoteRepositoryStub {
  String name = 'Alexc-MBA';
  final List<String> setDeviceNameCalls = [];
  Object? setDeviceNameError;

  @override
  Future<String> deviceName() async => name;

  @override
  Future<void> setDeviceName(String value) async {
    if (setDeviceNameError != null) throw setDeviceNameError!;
    setDeviceNameCalls.add(value);
    name = value;
  }

  @override
  Future<String> deviceId() async => 'abcdef1234567890';

  @override
  Future<List<PairedDeviceRow>> listPairedDevices() async => [];
}

// ━━ helpers ━━

Future<void> _pumpPage(WidgetTester tester, _FakeRepository repo) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CardMindTheme.light,
      home: Scaffold(body: DevicesPage(repository: repo)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openEditor(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('device-local-name-edit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('本机卡片显示当前设备名，且有编辑按钮', (tester) async {
    final repo = _FakeRepository();
    await _pumpPage(tester, repo);
    expect(find.byKey(const ValueKey('device-local-name')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('device-local-name'))).data,
      'Alexc-MBA',
    );
    expect(
      find.byKey(const ValueKey('device-local-name-edit')),
      findsOneWidget,
    );
  });

  testWidgets('点编辑 → 弹窗打开，输入框自动聚焦且有可见 label', (tester) async {
    final repo = _FakeRepository();
    await _pumpPage(tester, repo);
    await _openEditor(tester);

    expect(find.byKey(const ValueKey('device-name-input')), findsOneWidget);
    // 可见 label（不是 placeholder-only）
    expect(find.text('设备名'), findsOneWidget);

    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('device-name-input')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.autofocus, isTrue);
    expect(field.controller?.text, 'Alexc-MBA');
  });

  testWidgets('输入新名 → 保存 → 调用 setDeviceName 且卡片更新', (tester) async {
    final repo = _FakeRepository();
    await _pumpPage(tester, repo);
    await _openEditor(tester);

    await tester.enterText(
      find.byKey(const ValueKey('device-name-input')),
      'Alexc-MBA-2',
    );
    await tester.tap(find.byKey(const ValueKey('device-name-save')));
    await tester.pumpAndSettle();

    expect(repo.setDeviceNameCalls, ['Alexc-MBA-2']);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('device-local-name'))).data,
      'Alexc-MBA-2',
    );
    // 弹窗已关闭
    expect(find.byKey(const ValueKey('device-name-input')), findsNothing);
  });

  testWidgets('空输入 → 不调 setDeviceName，弹窗不关，错误内联在字段下（非 SnackBar）', (
    tester,
  ) async {
    final repo = _FakeRepository();
    await _pumpPage(tester, repo);
    await _openEditor(tester);

    await tester.enterText(
      find.byKey(const ValueKey('device-name-input')),
      '   ',
    );
    await tester.tap(find.byKey(const ValueKey('device-name-save')));
    await tester.pumpAndSettle();

    expect(repo.setDeviceNameCalls, isEmpty);
    expect(find.byKey(const ValueKey('device-name-input')), findsOneWidget);
    // 错误文案可见
    expect(find.text('设备名不能为空'), findsOneWidget);
    // 错误在 TextFormField 子树内（内联），而不是 SnackBar
    expect(
      find.descendant(
        of: find.byType(TextFormField),
        matching: find.text('设备名不能为空'),
      ),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('取消 → 不调 setDeviceName，弹窗关闭', (tester) async {
    final repo = _FakeRepository();
    await _pumpPage(tester, repo);
    await _openEditor(tester);

    await tester.enterText(
      find.byKey(const ValueKey('device-name-input')),
      'Changed',
    );
    await tester.tap(find.byKey(const ValueKey('device-name-cancel')));
    await tester.pumpAndSettle();

    expect(repo.setDeviceNameCalls, isEmpty);
    expect(find.byKey(const ValueKey('device-name-input')), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('device-local-name'))).data,
      'Alexc-MBA',
    );
  });

  testWidgets('与当前名相同 → 弹窗关闭且不调 setDeviceName', (tester) async {
    final repo = _FakeRepository();
    await _pumpPage(tester, repo);
    await _openEditor(tester);

    await tester.tap(find.byKey(const ValueKey('device-name-save')));
    await tester.pumpAndSettle();

    expect(repo.setDeviceNameCalls, isEmpty);
    expect(find.byKey(const ValueKey('device-name-input')), findsNothing);
  });

  testWidgets('编辑按钮有可访问名「修改设备名」', (tester) async {
    final repo = _FakeRepository();
    await _pumpPage(tester, repo);

    final semantics = tester.getSemantics(
      find.byKey(const ValueKey('device-local-name-edit')),
    );
    expect(semantics.label, contains('修改设备名'));
  });
}
