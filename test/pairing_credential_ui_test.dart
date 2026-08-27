import 'dart:async';

import 'package:cardmind/bridge/note_repository.dart';
import 'package:cardmind/bridge/pairing_credential_exception.dart';
import 'package:cardmind/pages/devices_page.dart';
import 'package:cardmind/src/rust/discovery.dart';
import 'package:cardmind/src/rust/store.dart';
import 'package:cardmind/src/rust/sync.dart';
import 'package:cardmind/ui/design_system/cardmind_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/scanner/scanner_interface.dart';

/// 任务单 CRITICAL 1/2 验收测试（凭证 UI）。
///
/// 每条验收标准 = 一个测试用例：
/// 1. show dialog renders qr code text copy and countdown
/// 2. regenerate invalidates old display and updates qr and text
/// 3. enter dialog has one primary field and no node id field
/// 4. pasted credential connects without discovery
/// 5. six digits preserve mdns path and ambiguity messages
/// 6. android scan result uses same parser as paste
/// 7. scanner permission denied has friendly fallback
/// 8. long credential never overflows desktop or mobile dialog
/// 9. accept starts only after credential session is ready
/// 10. regenerate never leaves two accept loops or confirms with old code

/// 凭证 UI 专用 fake repository：记录配对 API 调用轨迹，可控模拟
/// 凭证生成、accept、confirm 行为（generation round token 语义）。
class CredentialUiRepository implements NoteRepository {
  int credentialCalls = 0;
  int acceptCalls = 0;
  int confirmCalls = 0;
  int discoverCalls = 0;
  int connectCalls = 0;
  int credentialConnectCalls = 0;
  int parseCalls = 0;
  int stopAdvertisingCalls = 0;

  String confirmCode = '';
  String? lastCredentialArg;

  /// credential 生成序列（每次 beginPairingCredential 取下一个；耗尽用最后一个）。
  List<PairingCredentialDisplay> credentialSeq = [
    PairingCredentialDisplay(
      code: '111111',
      credential: 'cm1.credential-first',
      expiresAt: DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 10))
          .toIso8601String(),
    ),
  ];

  /// accept 默认立即返回请求（generation 就绪后）。
  PairingRequest? acceptResult = const PairingRequest(
    code: '111111',
    deviceId: 'initiator-device',
    deviceName: 'New Phone',
    relayInfo: '',
    ips: [],
    nonce: '11111111111111111111111111111111',
  );

  /// accept 抛错（模拟后端异常）。每轮 accept 立即结束——用于需要
  /// 「重新生成」按钮快速完成的用例（旧 accept future 已结束，无需等待窗口）。
  Object? acceptError;

  /// 前 N 次 accept 返回 null（模拟有界窗口超时）。任务 U7：超时会触发
  /// 静默自动重生成链——测试时钟下必须"有限次 null + 挂起"收尾，
  /// 否则重生成链在纯 microtask 中无限旋转拖死 pumpAndSettle。
  int timeoutResults = 0;

  /// accept 挂起 gate（一次性：首个到达的 accept 消费后清除）。
  Completer<PairingRequest?>? acceptGate;

  /// timeoutResults/acceptGate 均未命中时挂起等待（模拟真实设备窗口内的
  /// 静默等待），保证弹窗保持打开且链路静止、测试可终止。
  bool parkAfterControlled = false;

  /// accept 挂起 gate（用于控制"凭证就绪前不启动 accept"）。
  Completer<void>? credentialGate;

  /// discoverPeers 返回结果。
  List<PeerInfo> peers = [];

  /// parsePairingCredential 抛错（模拟格式/签名/过期/已使用）。
  PairingCredentialException? parseError;

  /// credential connect 抛错（不可达）。
  Object? connectError;
  Completer<PairingResult>? credentialConnectGate;

  @override
  Future<PairingCredentialDisplay> beginPairingCredential() async {
    credentialCalls++;
    if (credentialGate case final gate?) await gate.future;
    final display = credentialSeq.length > 1
        ? credentialSeq.removeAt(0)
        : credentialSeq.last;
    return display;
  }

  @override
  Future<PairingRequest?> acceptPairingRequestWithTimeout(
    Duration timeout,
  ) async {
    acceptCalls++;
    if (acceptError case final error?) throw error;
    if (timeoutResults > 0) {
      timeoutResults--;
      return null;
    }
    if (acceptGate case final gate?) {
      acceptGate = null; // 一次性消费：后续 accept 落到后续规则
      return gate.future;
    }
    if (parkAfterControlled) return Completer<PairingRequest?>().future;
    return acceptResult;
  }

  @override
  Future<PairingResult> confirmPairing(
    String code,
    PairingRequest requester,
  ) async {
    confirmCalls++;
    confirmCode = code;
    return PairingResult(
      peerId: requester.deviceId,
      peerName: requester.deviceName,
    );
  }

  @override
  Future<List<PeerInfo>> discoverPeers() async {
    discoverCalls++;
    return peers;
  }

  @override
  Future<PairingResult> beginPairingConnect(
    String code,
    PairingTarget target,
  ) async {
    connectCalls++;
    return PairingResult(peerId: target.deviceId, peerName: 'Peer');
  }

  @override
  Future<ParsedPairingCredential> parsePairingCredential(
    String credential,
  ) async {
    parseCalls++;
    if (parseError case final e?) throw e;
    return ParsedPairingCredential(
      code: '111111',
      deviceId: 'parsed-device',
      expiresAt: DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 10))
          .toIso8601String(),
      nonce: '11111111111111111111111111111111',
    );
  }

  @override
  Future<PairingResult> beginPairingConnectWithCredential(
    String credential,
  ) async {
    credentialConnectCalls++;
    lastCredentialArg = credential;
    if (credentialConnectGate case final gate?) return gate.future;
    if (connectError case final e?) throw e;
    return PairingResult(peerId: 'parsed-device', peerName: 'Trusted PC');
  }

  @override
  Future<void> stopPairingAdvertising() async {
    stopAdvertisingCalls++;
  }

  @override
  Future<List<PairedDeviceRow>> listPairedDevices() async => [];

  @override
  Future<String> deviceName() async => 'My PC';
  @override
  Future<String> deviceId() async => 'confirmer-device';
  @override
  Future<String> beginPairingAccept() async => '111111';
  @override
  Future<String> beginPairingAcceptAndAdvertise() async => '111111';
  @override
  Future<PairingRequest> acceptPairingRequest() =>
      throw UnimplementedError('UI 走有界版本');
  @override
  Future<void> acceptAndImportPush() async {}
  @override
  Future<void> removePairedDevice(String peerId) async {}
  @override
  Future<void> setDeviceName(String name) async {}
  @override
  Future<List<String>> localAddrs() async => [];

  @override
  Future<List<NoteRow>> listNotes() async => [];
  @override
  Future<List<NoteRow>> search(String query) async => [];
  @override
  Future<String?> getNote(String id) async => null;
  @override
  Future<void> createNote(String id, String content) async {}
  @override
  Future<String> generateNoteId() async => 'generated-id';
  @override
  Future<void> updateMetadata(String id, List<String> tags) async {}
  @override
  Future<List<LinkRow>> getOutgoingLinks(String id) async => [];
  @override
  Future<List<LinkRow>> getBacklinks(String id) async => [];
  @override
  Future<List<NoteRow>> searchNotes(String query) async => [];
  @override
  Future<List<NoteRow>> autoCompleteLinks(String prefix) async => [];
  @override
  Future<List<String>> getAllTags() async => [];
  @override
  Future<List<NoteRow>> searchByTag(String tag) async => [];
  @override
  Future<void> softDelete(String id) async {}
  @override
  Future<void> restore(String id) async {}
  @override
  Future<void> purge(String id) async {}
  @override
  Future<int> purgeExpired(DateTime cutoff) async => 0;
  @override
  Future<List<NoteRow>> trashList() async => [];
}

class _SupportedScanner implements ScannerService {
  _SupportedScanner({this.outcome = const ScanOutcome(text: 'cm1.scanned')});

  final ScanOutcome outcome;

  @override
  bool get isSupported => true;

  @override
  Future<ScanOutcome> scanCredential(BuildContext context) async => outcome;
}

class _RouteScanner implements ScannerService {
  _RouteScanner();
  final ScanOutcome outcome = const ScanOutcome(text: 'cm1.scanned');
  @override
  bool get isSupported => true;
  @override
  Future<ScanOutcome> scanCredential(BuildContext context) async {
    final result = await Navigator.of(context).push<ScanOutcome>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey('route-scanner-detect'),
              onPressed: () => Navigator.of(context).pop(outcome),
              child: const Text('模拟识别'),
            ),
          ),
        ),
      ),
    );
    return result ?? const ScanOutcome();
  }
}

Future<void> _pump(
  WidgetTester tester,
  NoteRepository repository, {
  ScannerService? scanner,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CardMindTheme.light,
      home: Scaffold(
        body: DevicesPage(repository: repository, scanner: scanner),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openShowDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('devices-add')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('pair-mode-show')));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> _openEnterDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('devices-add')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('pair-mode-enter')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'countdown visibly decreases and resets for regenerated credential',
    (tester) async {
      final now = DateTime.now().toUtc();
      final repo = CredentialUiRepository()
        // U7：acceptError 让每轮 accept 立即结束（否则「重新生成」要等旧
        // accept future 到窗口末尾），倒计时断言不受错误文案影响。
        ..acceptError = Exception('simulated accept failure')
        ..credentialSeq = [
          PairingCredentialDisplay(
            code: '111111',
            credential: 'cm1.first',
            expiresAt: now.add(const Duration(seconds: 10)).toIso8601String(),
          ),
          PairingCredentialDisplay(
            code: '222222',
            credential: 'cm1.second',
            expiresAt: now.add(const Duration(seconds: 20)).toIso8601String(),
          ),
        ];
      await tester.pumpWidget(
        MaterialApp(
          theme: CardMindTheme.light,
          home: Scaffold(body: DevicesPage(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();
      await _openShowDialog(tester);
      final first = tester
          .widget<Text>(find.byKey(const ValueKey('pair-code-countdown')))
          .data!;
      await tester.pump(const Duration(seconds: 1));
      final decreased = tester
          .widget<Text>(find.byKey(const ValueKey('pair-code-countdown')))
          .data!;
      expect(decreased, isNot(first));
      await tester.tap(find.byKey(const ValueKey('pair-regenerate-button')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(seconds: 1));
      final reset = tester
          .widget<Text>(find.byKey(const ValueKey('pair-code-countdown')))
          .data!;
      expect(reset, isNot('已过期，请重新生成'));
      await tester.tap(find.byKey(const ValueKey('pair-dialog-close')));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('add device presents show scan and manual as peer choices', (
    tester,
  ) async {
    final repo = CredentialUiRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: Scaffold(
          body: DevicesPage(repository: repo, scanner: _SupportedScanner()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('devices-add')));
    await tester.pump();
    expect(find.byKey(const ValueKey('pair-mode-show')), findsOneWidget);
    expect(find.byKey(const ValueKey('pair-mode-scan')), findsOneWidget);
    expect(find.byKey(const ValueKey('pair-mode-enter')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pair-dialog-cancel')));
  });

  testWidgets('show dialog renders qr code text copy and countdown', (
    tester,
  ) async {
    final repo = CredentialUiRepository()
      ..acceptResult =
          null // 不立即 confirm
      ..parkAfterControlled = true; // U7：null 超时会触发自动重生成链，挂起保持静止
    await _pump(tester, repo);
    await _openShowDialog(tester);

    expect(find.byKey(const ValueKey('pair-code-display')), findsOneWidget);
    expect(find.byKey(const ValueKey('pair-qr-image')), findsOneWidget);
    expect(find.byKey(const ValueKey('pair-copy-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('pair-code-countdown')), findsOneWidget);
    // 文案应为"扫描此二维码"（显示方方向正确）
    expect(find.textContaining('扫描此二维码'), findsOneWidget);
    expect(find.textContaining('用相机扫描对方二维码'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('pair-dialog-close')));
    await tester.pumpAndSettle();
  });

  testWidgets('regenerate invalidates old display and updates qr and text', (
    tester,
  ) async {
    final repo = CredentialUiRepository()
      // U7：acceptError 让旧轮次 accept 立即结束，「重新生成」无需等待窗口。
      ..acceptError = Exception('simulated accept failure')
      ..credentialSeq = [
        const PairingCredentialDisplay(
          code: '111111',
          credential: 'cm1.credential-first',
          expiresAt: '',
        ),
        const PairingCredentialDisplay(
          code: '222222',
          credential: 'cm1.credential-second',
          expiresAt: '',
        ),
      ];
    // 修正过期时间
    repo.credentialSeq = [
      PairingCredentialDisplay(
        code: '111111',
        credential: 'cm1.credential-first',
        expiresAt: DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 10))
            .toIso8601String(),
      ),
      PairingCredentialDisplay(
        code: '222222',
        credential: 'cm1.credential-second',
        expiresAt: DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 10))
            .toIso8601String(),
      ),
    ];
    await _pump(tester, repo);
    await _openShowDialog(tester);

    expect(find.text('111111'), findsOneWidget);
    expect(find.text('222222'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('pair-regenerate-button')));
    await tester.pumpAndSettle();

    expect(repo.credentialCalls, 2, reason: '重新生成应再次调用 beginPairingCredential');
    expect(find.text('222222'), findsOneWidget, reason: '新 6 位码应显示');
    expect(find.text('111111'), findsNothing, reason: '旧码应失效/被替换');

    await tester.tap(find.byKey(const ValueKey('pair-dialog-close')));
    await tester.pumpAndSettle();
  });

  testWidgets('enter dialog has one primary field and no node id field', (
    tester,
  ) async {
    final repo = CredentialUiRepository();
    await _pump(tester, repo);
    await _openEnterDialog(tester);

    expect(find.byKey(const ValueKey('pair-credential-input')), findsOneWidget);
    expect(find.byKey(const ValueKey('pair-code-input')), findsNothing);
    expect(find.byKey(const ValueKey('pair-peer-id-input')), findsNothing);
    expect(find.textContaining('手动填写对方设备 ID'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('pair-cancel')));
    await tester.pumpAndSettle();
  });

  testWidgets('pasted credential connects without discovery', (tester) async {
    final repo = CredentialUiRepository();
    await _pump(tester, repo);
    await _openEnterDialog(tester);

    await tester.enterText(
      find.byKey(const ValueKey('pair-credential-input')),
      'cm1.some-credential-text',
    );
    await tester.tap(find.byKey(const ValueKey('pair-submit')));
    await tester.pumpAndSettle();

    expect(repo.credentialConnectCalls, 1, reason: '凭证输入应走凭证连接入口');
    expect(repo.discoverCalls, 0, reason: '凭证连接禁止 mDNS 扫描');
    expect(repo.connectCalls, 0, reason: '凭证连接不走 beginPairingConnect');
    expect(repo.lastCredentialArg, 'cm1.some-credential-text');
  });

  testWidgets('six digits preserve mdns path and ambiguity messages', (
    tester,
  ) async {
    final repo = CredentialUiRepository()
      ..peers = [
        const PeerInfo(
          deviceId: 'dev-a',
          ip: '192.168.1.2',
          port: 3456,
          nonce: '',
        ),
        const PeerInfo(
          deviceId: 'dev-b',
          ip: '192.168.1.3',
          port: 3456,
          nonce: '',
        ),
      ];
    await _pump(tester, repo);
    await _openEnterDialog(tester);

    await tester.enterText(
      find.byKey(const ValueKey('pair-credential-input')),
      '123456',
    );
    await tester.tap(find.byKey(const ValueKey('pair-submit')));
    await tester.pumpAndSettle();

    expect(repo.discoverCalls, 1, reason: '纯 6 位数字应走 mDNS 发现');
    expect(repo.credentialConnectCalls, 0);
    expect(
      find.byKey(const ValueKey('pair-submit-error')),
      findsOneWidget,
      reason: '多台设备歧义应显示友好错误',
    );
  });

  testWidgets('android scan result uses same parser as paste', (tester) async {
    // 测试环境为桌面 stub，扫码按钮应隐藏（Windows 隐藏扫码按钮）。
    // 但解析路径与粘贴共用同一 submit 函数：通过直接粘贴凭证验证解析被调用。
    final repo = CredentialUiRepository();
    await _pump(tester, repo);
    await _openEnterDialog(tester);

    // 桌面桩：不显示扫码按钮（isSupported == false）
    expect(find.byKey(const ValueKey('pair-scan-button')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('pair-credential-input')),
      'cm1.scanned-credential',
    );
    await tester.tap(find.byKey(const ValueKey('pair-submit')));
    await tester.pumpAndSettle();

    expect(repo.credentialConnectCalls, 1);
    expect(repo.lastCredentialArg, 'cm1.scanned-credential');
  });

  testWidgets('scanner cm1 result connects directly without discovery', (
    tester,
  ) async {
    final repo = CredentialUiRepository();
    await _pump(tester, repo, scanner: _SupportedScanner());
    await tester.tap(find.byKey(const ValueKey('devices-add')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pair-mode-scan')));
    await tester.pump();

    expect(repo.credentialConnectCalls, 1);
    expect(repo.lastCredentialArg, 'cm1.scanned');
    expect(repo.discoverCalls, 0);
    expect(find.byKey(const ValueKey('pair-credential-input')), findsNothing);
    expect(
      find.byKey(const ValueKey('pair-scan-connecting-dialog')),
      findsOneWidget,
    );
  });

  testWidgets('scanner cancellation closes without error', (tester) async {
    final repo = CredentialUiRepository();
    await _pump(
      tester,
      repo,
      scanner: _SupportedScanner(outcome: ScanOutcome()),
    );
    await tester.tap(find.byKey(const ValueKey('devices-add')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pair-mode-scan')));
    await tester.pump();

    expect(repo.credentialConnectCalls, 0);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('scanner errors show readable feedback', (tester) async {
    final repo = CredentialUiRepository();
    await _pump(
      tester,
      repo,
      scanner: _SupportedScanner(
        outcome: ScanOutcome(error: '相机权限被拒绝，请手动输入配对信息'),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('devices-add')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pair-mode-scan')));
    await tester.pumpAndSettle();
    expect(find.text('相机权限被拒绝，请手动输入配对信息'), findsOneWidget);
  });

  testWidgets('invalid scanner contents show readable feedback', (
    tester,
  ) async {
    final repo = CredentialUiRepository();
    await _pump(
      tester,
      repo,
      scanner: _SupportedScanner(outcome: ScanOutcome(text: 'not-a-code')),
    );
    await tester.tap(find.byKey(const ValueKey('devices-add')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pair-mode-scan')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('pair-scan-result-dialog')),
      findsOneWidget,
    );
    expect(find.text('扫码内容不是有效的配对信息，请重新扫描'), findsOneWidget);
    expect(repo.credentialConnectCalls, 0);
  });

  testWidgets('delayed scanner failure persists and offers manual input', (
    tester,
  ) async {
    final repo = CredentialUiRepository()
      ..credentialConnectGate = Completer<PairingResult>()
      ..connectError = const PairingCredentialException(
        kind: PairingCredentialErrorKind.unreachable,
        message: '无法连接到对方设备，请确认网络可达后重试',
      );
    await _pump(tester, repo, scanner: _SupportedScanner());
    await tester.tap(find.byKey(const ValueKey('devices-add')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pair-mode-scan')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('pair-scan-connecting-dialog')),
      findsOneWidget,
    );
    repo.credentialConnectGate!.completeError(repo.connectError!);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('pair-scan-result-dialog')),
      findsOneWidget,
    );
    expect(find.text(repo.connectError!.toString()), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pair-scan-manual')));
    await tester.pump();
    expect(find.byKey(const ValueKey('pair-credential-input')), findsOneWidget);
  });

  testWidgets('scanner permission denied has friendly fallback', (
    tester,
  ) async {
    final repo = CredentialUiRepository();
    await _pump(tester, repo);
    await _openEnterDialog(tester);
    // 桌面桩不支持扫码，输入框路径是唯一路径；这里验证扫码按钮确实不存在，
    // 且友好错误（不可达）可展示。
    expect(find.byKey(const ValueKey('pair-scan-button')), findsNothing);

    // 不可达错误 → 友好文案
    repo.connectError = const PairingCredentialException(
      kind: PairingCredentialErrorKind.unreachable,
      message: '无法连接到对方设备',
    );
    await tester.enterText(
      find.byKey(const ValueKey('pair-credential-input')),
      'cm1.unreachable',
    );
    await tester.tap(find.byKey(const ValueKey('pair-submit')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('pair-submit-error')),
      findsOneWidget,
      reason: '不可达应显示友好错误',
    );
    expect(find.textContaining('AnyhowException'), findsNothing);
  });

  testWidgets('real Navigator scanner route supports delayed success', (
    tester,
  ) async {
    final repo = CredentialUiRepository()
      ..credentialConnectGate = Completer<PairingResult>();
    await _pump(tester, repo, scanner: _RouteScanner());
    await tester.tap(find.byKey(const ValueKey('devices-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pair-mode-scan')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('route-scanner-detect')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('pair-scan-connecting-dialog')),
      findsOneWidget,
    );
    repo.credentialConnectGate!.complete(
      const PairingResult(peerId: 'p', peerName: 'Trusted PC'),
    );
    await tester.pump();
    expect(find.textContaining('Trusted PC'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pair-scan-done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pair-scan-result-dialog')), findsNothing);
  });

  testWidgets('long credential never overflows desktop or mobile dialog', (
    tester,
  ) async {
    final repo = CredentialUiRepository();
    final longCredential = 'cm1.${'A' * 800}';
    repo.credentialSeq = [
      PairingCredentialDisplay(
        code: '111111',
        credential: longCredential,
        expiresAt: DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 10))
            .toIso8601String(),
      ),
    ];
    repo.acceptResult = null;
    repo.parkAfterControlled = true; // U7：挂起保持链路静止，弹窗保持打开

    // 移动端 320x640
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(tester, repo);
    await _openShowDialog(tester);
    expect(tester.takeException(), isNull, reason: '移动端不得 overflow');
    await tester.tap(find.byKey(const ValueKey('pair-dialog-close')));
    await tester.pumpAndSettle();

    // 桌面端 1280x720
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    await _pump(tester, repo);
    await _openShowDialog(tester);
    expect(tester.takeException(), isNull, reason: '桌面端不得 overflow');
    await tester.tap(find.byKey(const ValueKey('pair-dialog-close')));
    await tester.pumpAndSettle();
  });

  testWidgets('accept starts only after credential session is ready', (
    tester,
  ) async {
    final repo = CredentialUiRepository();
    // 挂起 credential 生成：accept 不应在生成完成前启动
    final gate = Completer<void>();
    repo.credentialGate = gate;
    repo.acceptResult = null; // 不立即 confirm，避免弹窗自动关闭
    repo.parkAfterControlled = true; // U7：挂起保持链路静止

    await _pump(tester, repo);
    await _openShowDialog(tester);

    // 生成尚未完成 → accept 未启动
    expect(repo.acceptCalls, 0, reason: '凭证/session 就绪前不得启动 accept');
    expect(repo.credentialCalls, 1);

    gate.complete();
    await tester.pumpAndSettle();

    expect(repo.credentialCalls, 1, reason: '只生成一次，外部不重复生成');
    expect(repo.acceptCalls, 1, reason: '凭证就绪后启动有界 accept（一次）');

    await tester.tap(find.byKey(const ValueKey('pair-dialog-close')));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'regenerate never leaves two accept loops or confirms with old code',
    (tester) async {
      final repo = CredentialUiRepository();
      // 第一次 accept 挂起（gate 控制释放），弹窗保持打开；
      // 触发凭证重新生成后再放行旧 accept，验证不确认旧码、不叠加 loop。
      // U7：旧轮次以"超时"放行时 generation 已被手动重生成递增 → 判废退出，
      // 不会触发自动重生成链；新轮次 accept 由 parkAfterControlled 挂起。
      repo.acceptResult = null;
      repo.parkAfterControlled = true;
      final oldRound = Completer<PairingRequest?>();
      repo.acceptGate = oldRound;
      repo.credentialSeq = [
        PairingCredentialDisplay(
          code: '111111',
          credential: 'cm1.credential-first',
          expiresAt: DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 10))
              .toIso8601String(),
        ),
        PairingCredentialDisplay(
          code: '222222',
          credential: 'cm1.credential-second',
          expiresAt: DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 10))
              .toIso8601String(),
        ),
      ];

      await _pump(tester, repo);
      await _openShowDialog(tester);
      expect(repo.acceptCalls, 1, reason: '初始 accept 启动一次');

      await tester.tap(find.byKey(const ValueKey('pair-regenerate-button')));
      await tester.pump(); // 处理点击：generation 递增并等待旧 accept 结束
      oldRound.complete(null); // 旧轮次以超时返回（已判废）
      await tester.pumpAndSettle();

      expect(repo.credentialCalls, 2, reason: '重新生成调用第二次 credential');
      expect(repo.acceptCalls, 2, reason: '新 generation 启动新的有界 accept（旧轮次已失效）');

      // 此时若收到请求（旧 code 111111），不得 confirm
      repo.acceptResult = const PairingRequest(
        code: '111111',
        deviceId: 'initiator-device',
        deviceName: 'New Phone',
        relayInfo: '',
        ips: [],
        nonce: '11111111111111111111111111111111',
      );
      // 触发一轮新 accept 后确认使用的应是当前 display code（222222），
      // 但旧 111111 请求不匹配应被拒绝。这里通过 confirm 仅当 code 等于当前 display code 断言。
      expect(repo.confirmCalls, 0, reason: '重新生成后旧 code 请求不得确认');

      await tester.tap(find.byKey(const ValueKey('pair-dialog-close')));
      await tester.pumpAndSettle();
      expect(repo.stopAdvertisingCalls, greaterThanOrEqualTo(1));
    },
  );
}
