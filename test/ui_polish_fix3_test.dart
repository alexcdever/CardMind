import 'dart:async';
import 'dart:io';

import 'package:cardmind/pages/devices_page.dart';
import 'package:cardmind/scanner/scanner_interface.dart';
import 'package:cardmind/src/rust/sync.dart';
import 'package:cardmind/ui/design_system/cardmind_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pairing_credential_ui_test.dart' show CredentialUiRepository;

/// 扫码 fake：isSupported=true，直接返回固定 `cm1` 凭证文本，跳过相机路由。
class _StubScanner implements ScannerService {
  @override
  bool get isSupported => true;

  @override
  Future<ScanOutcome> scanCredential(BuildContext context) async =>
      const ScanOutcome(text: 'cm1.stub');
}

/// 打开扫描→connecting 弹窗；`credentialConnectGate` 挂起保证停在 connecting 态。
Future<CredentialUiRepository> _openConnectingDialog(
  WidgetTester tester, {
  Completer<PairingResult>? gate,
}) async {
  final repo = CredentialUiRepository()
    ..credentialConnectGate = gate ?? Completer<PairingResult>();
  await tester.pumpWidget(
    MaterialApp(
      theme: CardMindTheme.light,
      home: Scaffold(
        body: DevicesPage(repository: repo, scanner: _StubScanner()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('devices-add')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('pair-mode-scan')));
  await tester.pump();
  expect(
    find.byKey(const ValueKey('pair-scan-connecting-dialog')),
    findsOneWidget,
    reason: '前置：connect future 挂起时应停在 connecting 弹窗',
  );
  return repo;
}

/// ui-polish-fix-3 验收测试：配对连接中弹窗死锁无出口（唯一必修项）。
///
/// - AC1：connecting 态有可点「取消」控件
/// - AC2：点取消弹窗关闭，不触发成功/失败后续导航（不额外 _load）
/// - AC3：connect future 超时后进入失败态，而非永久停在「正在连接…」
void main() {
  testWidgets('AC1: connecting dialog exposes a tappable cancel control', (
    tester,
  ) async {
    await _openConnectingDialog(tester);

    final cancel = find.byKey(const ValueKey('pair-scan-cancel'));
    expect(
      cancel,
      findsOneWidget,
      reason: 'connecting 态必须提供取消出口（barrierDismissible=false 下唯一退路）',
    );
    final button = tester.widget<TextButton>(cancel);
    expect(button.onPressed, isNotNull, reason: '取消控件的 onPressed 不得为 null');

    // 收场：点取消关闭弹窗；底层 connect future 落空，30s 超时计时器随 pump 耗尽。
    await tester.tap(cancel);
    await tester.pump();
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('AC2: cancelling the connecting dialog closes it without reload', (
    tester,
  ) async {
    final gate = Completer<PairingResult>();
    final repo = CredentialUiRepository();
    var listDevicesCalls = 0;
    repo.onListPairedDevices = () => listDevicesCalls++;
    repo.credentialConnectGate = gate;
    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: Scaffold(
          body: DevicesPage(repository: repo, scanner: _StubScanner()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    listDevicesCalls = 0; // 只统计取消后是否有多余 _load

    await tester.tap(find.byKey(const ValueKey('devices-add')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pair-mode-scan')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('pair-scan-connecting-dialog')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('pair-scan-cancel')));
    // 放行底层 connect future：取消只是 UI 放弃等待（_run mounted 检查兜底），
    // future 完成后 timeout 内部计时器取消，不留 pending timer、不触发
    // 页面 2s 周期刷新干扰下面的 _load 计数断言。
    gate.complete(const PairingResult(peerId: 'p', peerName: 'late'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.byKey(const ValueKey('pair-scan-connecting-dialog')),
      findsNothing,
      reason: '点取消后弹窗必须关闭',
    );
    expect(
      find.byKey(const ValueKey('pair-scan-result-dialog')),
      findsNothing,
      reason: '取消不是成功/失败结果态，不得弹出结果弹窗',
    );
    expect(
      find.byKey(const ValueKey('pair-credential-input')),
      findsNothing,
      reason: '取消不得跳到手动输入',
    );
    expect(
      listDevicesCalls,
      0,
      reason: '取消不得触发 _load()（非 done 结果不刷设备列表）',
    );
  });

  testWidgets('AC3: hung connect future falls to failure state on timeout', (
    tester,
  ) async {
    await _openConnectingDialog(tester);

    await tester.pump(const Duration(seconds: 30));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('pair-scan-connecting-dialog')),
      findsNothing,
      reason: '超时后不得仍停在「正在连接…」',
    );
    expect(
      find.byKey(const ValueKey('pair-scan-result-dialog')),
      findsOneWidget,
      reason: '超时应进入失败结果态',
    );
    expect(
      find.textContaining('无法连接'),
      findsOneWidget,
      reason: '超时错误文案应与既有 catch 分支一致',
    );

    await tester.tap(find.byKey(const ValueKey('pair-scan-done')));
    await tester.pump();
  });

  test(
    'AC3: connect timeout uses the documented 30s budget',
    () {
      final source = File('lib/pages/devices_page.dart').readAsStringSync();
      expect(
        source.contains('_pairConnectTimeout'),
        isTrue,
        reason: '超时必须是显式命名的常量（可测试、可调）',
      );
      expect(
        RegExp(r'Duration\(seconds:\s*30\)').hasMatch(source),
        isTrue,
        reason: '超时预算 30 秒（任务建议值）',
      );
    },
  );

  testWidgets(
    'AC2: success path still reloads the device list after done',
    (tester) async {
      // 守护：取消语义新增后，成功→「完成」仍要 _load（回归保护）。
      final repo = CredentialUiRepository();
      var listDevicesCalls = 0;
      repo.onListPairedDevices = () => listDevicesCalls++;
      await tester.pumpWidget(
        MaterialApp(
          theme: CardMindTheme.light,
          home: Scaffold(
            body: DevicesPage(repository: repo, scanner: _StubScanner()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      listDevicesCalls = 0;

      await tester.tap(find.byKey(const ValueKey('devices-add')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pair-mode-scan')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Trusted PC'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pair-scan-done')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(
        listDevicesCalls,
        greaterThanOrEqualTo(1),
        reason: '成功结果点「完成」仍应触发 _load()',
      );
    },
  );
}
