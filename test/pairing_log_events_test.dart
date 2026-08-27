import 'dart:async';

import 'package:cardmind/bridge/debug_log.dart';
import 'package:cardmind/bridge/note_repository.dart';
import 'package:cardmind/pages/devices_page.dart';
import 'package:cardmind/scanner/scanner_interface.dart';
import 'package:cardmind/src/rust/discovery.dart';
import 'package:cardmind/src/rust/store.dart';
import 'package:cardmind/src/rust/sync.dart';
import 'package:cardmind/ui/design_system/cardmind_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

/// debug-log 任务验收测试（配对 UI 事件，Flutter 侧）：
/// 4. signed credential emits discovery-bypass event —— 凭证路径明确记录跳过 mDNS
/// 5. mdns discovery emits count and duration —— 数量与耗时
/// 6. pairing accept lifecycle emits all stages —— 显示码/accept/request/confirm/成功/超时
/// 7. relay connection emits transport and error chain —— 直连 vs relay + 错误链 + 耗时
/// 9. logger failure does not break flow —— sink 抛异常时配对仍完成

class CaptureSink implements DebugSink {
  final List<DebugEvent> events = [];

  @override
  void emit(DebugEvent event) => events.add(event);
}

class ThrowingSink implements DebugSink {
  @override
  void emit(DebugEvent event) => throw StateError('sink exploded');
}

/// 配对日志测试专用 fake repository：可配置 accept/confirm/connect 结果。
class PairingLogRepository implements NoteRepository {
  String code = '289260';
  List<PeerInfo> discoverResult = [];
  Object? discoverError;
  PairingRequest? acceptResult;
  Object? acceptError;

  /// 前 N 次 accept 返回 null（模拟有界窗口超时）；其后挂起等待——U7 超时
  /// 自动重生成链在测试时钟下必须用"有限次 null + 挂起"收尾。
  int timeoutResults = 0;
  bool parkAfterTimeouts = false;
  PairingResult? confirmResult;
  Object? confirmError;
  PairingResult? connectResult;
  Object? connectError;

  int acceptCalls = 0;
  int confirmCalls = 0;
  int connectCalls = 0;
  int discoverCalls = 0;
  bool advertisingStarted = false;
  bool advertisingStopped = false;
  PairingTarget? connectTarget;
  int credentialConnectCalls = 0;
  Object? credentialConnectError;

  @override
  Future<List<PairedDeviceRow>> listPairedDevices() async => [];

  @override
  Future<String> deviceName() async => 'My PC';

  @override
  Future<String> deviceId() async => 'local-device-id-123456789';

  @override
  Future<String> beginPairingAccept() async => code;

  @override
  Future<String> beginPairingAcceptAndAdvertise() async {
    advertisingStarted = true;
    return code;
  }

  @override
  Future<void> stopPairingAdvertising() async {
    advertisingStopped = true;
  }

  @override
  Future<List<PeerInfo>> discoverPeers() async {
    discoverCalls++;
    if (discoverError case final error?) throw error;
    return List.of(discoverResult);
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
    if (parkAfterTimeouts) return Completer<PairingRequest?>().future;
    return acceptResult;
  }

  @override
  Future<PairingResult> confirmPairing(
    String code,
    PairingRequest requester,
  ) async {
    confirmCalls++;
    if (confirmError case final error?) throw error;
    return confirmResult ??
        PairingResult(peerId: requester.deviceId, peerName: 'New Phone');
  }

  @override
  Future<PairingResult> beginPairingConnect(
    String code,
    PairingTarget target,
  ) async {
    connectCalls++;
    connectTarget = target;
    if (connectError case final error?) throw error;
    return connectResult ??
        PairingResult(peerId: target.deviceId, peerName: 'New Phone');
  }

  @override
  Future<PairingCredentialDisplay> beginPairingCredential() async {
    return PairingCredentialDisplay(
      code: '289260',
      credential: 'cm1.credential-fake-text',
      expiresAt: DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 10))
          .toIso8601String(),
    );
  }

  @override
  Future<ParsedPairingCredential> parsePairingCredential(
    String credential,
  ) async {
    return ParsedPairingCredential(
      code: '289260',
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
    if (credentialConnectError case final error?) throw error;
    return PairingResult(peerId: 'parsed-device', peerName: 'Trusted PC');
  }

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

  @override
  Future<void> setDeviceName(String name) async {}

  @override
  Future<List<String>> localAddrs() async => [];

  @override
  Future<PairingRequest> acceptPairingRequest() =>
      throw UnimplementedError('not used');

  @override
  Future<void> acceptAndImportPush() async {}

  @override
  Future<void> removePairedDevice(String peerId) async {}
}

class _RouteScanner implements ScannerService {
  const _RouteScanner(this.outcome);
  final ScanOutcome outcome;
  @override
  bool get isSupported => true;
  @override
  Future<ScanOutcome> scanCredential(BuildContext context) async {
    final value = await Navigator.of(context).push<ScanOutcome>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: ElevatedButton(
            key: const ValueKey('route-scan-detect'),
            onPressed: () => Navigator.of(context).pop(outcome),
            child: const Text('模拟识别'),
          ),
        ),
      ),
    );
    return value ?? const ScanOutcome();
  }
}

Future<void> _pumpDevicesPage(
  WidgetTester tester,
  PairingLogRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CardMindTheme.light,
      home: Scaffold(body: DevicesPage(repository: repository)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openEnterCodeDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('devices-add')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('pair-mode-enter')));
  await tester.pumpAndSettle();
}

Future<void> _openShowCodeDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('devices-add')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('pair-mode-show')));
  await tester.pumpAndSettle();
}

void main() {
  late CaptureSink capture;
  late PairingLogRepository repository;

  setUp(() {
    capture = CaptureSink();
    DebugLogger.instance.setSink(capture);
    DebugLogger.instance.setPlatform('test');
    DebugLogger.instance.verbose = false;
    repository = PairingLogRepository();
  });

  tearDown(() {
    DebugLogger.instance.resetSink();
    DebugLogger.instance.resetPlatform();
  });

  // ━━ 验收 4：签名凭证路径明确记录跳过 mDNS ━━
  testWidgets('signed credential emits discovery-bypass event', (tester) async {
    await _pumpDevicesPage(tester, repository);
    await _openEnterCodeDialog(tester);

    await tester.enterText(
      find.byKey(const ValueKey('pair-credential-input')),
      'cm1.credential-fake-text',
    );
    await tester.tap(find.byKey(const ValueKey('pair-submit')));
    await tester.pumpAndSettle();

    expect(repository.discoverCalls, 0, reason: '输入签名凭证时不应调用 mDNS 扫描');
    final bypass = capture.events.firstWhere(
      (e) => e.event == 'pairing.discovery' && e.fields['action'] == 'bypassed',
    );
    expect(
      bypass.fields['mdns_skipped'],
      'true',
      reason: '签名凭证路径必须明确记录跳过 mDNS',
    );
    expect(bypass.deviceIds, isEmpty, reason: '凭证 bypass 不得记录目标 ID');
  });

  // ━━ 验收 5：mDNS 发现记录数量与耗时 ━━
  testWidgets('mdns discovery emits count and duration', (tester) async {
    repository.discoverResult = [
      PeerInfo(
        deviceId: 'mdns-found-device-0001',
        ip: '192.168.1.42',
        port: 11223,
        nonce: '',
      ),
    ];
    await _pumpDevicesPage(tester, repository);
    await _openEnterCodeDialog(tester);

    await tester.enterText(
      find.byKey(const ValueKey('pair-credential-input')),
      repository.code,
    );
    await tester.tap(find.byKey(const ValueKey('pair-submit')));
    await tester.pumpAndSettle();

    final start = capture.events.firstWhere(
      (e) => e.event == 'pairing.discovery' && e.fields['action'] == 'start',
    );
    expect(start, isNotNull, reason: '应记录 mDNS 扫描开始');
    final result = capture.events.firstWhere(
      (e) => e.event == 'pairing.discovery' && e.fields['action'] == 'result',
    );
    expect(result.fields['count'], '1', reason: '应记录发现数量');
    expect(result.durationMs, isNotNull, reason: '应记录发现耗时');
  });

  // ━━ 验收 6a：显示码/广播/accept/request/confirm 全阶段事件 ━━
  testWidgets('pairing accept lifecycle emits all stages', (tester) async {
    repository.acceptResult = PairingRequest(
      code: repository.code,
      deviceId: 'requester-device-0001',
      deviceName: 'New Phone',
      relayInfo: '',
      ips: const [],
      nonce: '',
    );
    repository.confirmResult = PairingResult(
      peerId: 'requester-device-0001',
      peerName: 'New Phone',
    );

    await _pumpDevicesPage(tester, repository);
    await _openShowCodeDialog(tester);
    await tester.pumpAndSettle();

    final events = capture.events;
    final text = events
        .map((e) => '${e.event}:${e.fields['action']}')
        .join('\n');
    for (final expected in [
      'pairing.show_code:start',
      'pairing.show_code:success',
      'pairing.advertise:start',
      'pairing.accept:start',
      'pairing.request:received',
      'pairing.confirm:start',
      'pairing.confirm:success',
    ]) {
      expect(text, contains(expected), reason: '配对 accept 生命周期应发出 $expected');
    }
    expect(
      find.textContaining('配对成功'),
      findsOneWidget,
      reason: '配对成功提示应出现（主流程未受日志影响）',
    );
    // 配对码绝不进入事件
    expect(
      events.any((e) => e.fields.values.contains(repository.code)),
      isFalse,
      reason: '配对码不得出现在日志事件中',
    );
  });

  // ━━ 验收 6b：accept 超时事件（U7：超时同时触发静默自动重生成）━━
  testWidgets('pairing accept timeout emits timeout event', (tester) async {
    repository.acceptResult = null; // 有界等待超时
    repository.timeoutResults = 1;
    repository.parkAfterTimeouts = true; // 重生成一轮后挂起，测试可终止

    await _pumpDevicesPage(tester, repository);
    await _openShowCodeDialog(tester);
    await tester.pumpAndSettle();

    final timeout = capture.events.firstWhere(
      (e) => e.event == 'pairing.accept' && e.fields['action'] == 'timeout',
    );
    expect(timeout, isNotNull, reason: 'accept 超时应发出 timeout 事件');
    final regenerate = capture.events.firstWhere(
      (e) => e.event == 'pairing.accept' && e.fields['action'] == 'regenerate',
    );
    expect(regenerate, isNotNull, reason: '自动重生成应记录 regenerate 日志');
    expect(repository.advertisingStopped, isTrue, reason: '超时后应停止广播（清理事件）');
  });

  // ━━ 验收 6c：显示码弹窗取消事件 ━━
  testWidgets('pairing show-code cancel emits cancelled event', (tester) async {
    repository
      ..acceptResult = null
      ..parkAfterTimeouts = true; // U7：null 超时会触发自动重生成链，挂起保持静止
    await _pumpDevicesPage(tester, repository);
    await _openShowCodeDialog(tester);
    await tester.tap(find.byKey(const ValueKey('pair-dialog-close')));
    await tester.pumpAndSettle();

    final cancelled = capture.events.firstWhere(
      (e) =>
          e.event == 'pairing.show_code' && e.fields['action'] == 'cancelled',
    );
    expect(cancelled, isNotNull, reason: '取消显示码应发出 cancelled 事件');
    final stop = capture.events.firstWhere(
      (e) => e.event == 'pairing.advertise' && e.fields['action'] == 'stop',
    );
    expect(stop.fields['ok'], 'true', reason: '清理事件应记录 ok');
  });

  // ━━ 验收 7：连接事件带 transport 与错误链/耗时 ━━
  testWidgets('connect failure emits transport and error chain', (
    tester,
  ) async {
    // mDNS 发现路径：target 带 ip:port → transport=direct
    repository.discoverResult = [
      PeerInfo(
        deviceId: 'mdns-found-device-0001',
        ip: '192.168.1.42',
        port: 11223,
        nonce: 'nonce',
      ),
    ];
    repository.connectError = AnyhowException('connect to confirmer: refused');

    await _pumpDevicesPage(tester, repository);
    await _openEnterCodeDialog(tester);
    await tester.enterText(
      find.byKey(const ValueKey('pair-credential-input')),
      repository.code,
    );
    await tester.tap(find.byKey(const ValueKey('pair-submit')));
    await tester.pumpAndSettle();

    final start = capture.events.firstWhere(
      (e) => e.event == 'pairing.connect' && e.fields['action'] == 'start',
    );
    expect(
      start.fields['transport'],
      'direct',
      reason: 'mDNS 发现带直连地址时 transport 应为 direct',
    );
    final failed = capture.events.firstWhere(
      (e) => e.event == 'pairing.connect' && e.fields['action'] == 'failed',
    );
    expect(failed.error, isNotNull, reason: '失败事件应记录错误类型');
    expect(failed.errorChain, contains('refused'), reason: '失败事件应记录错误链');
    expect(failed.durationMs, isNotNull, reason: '失败事件应记录耗时');
  });

  testWidgets('connect with empty ips records relay_or_dns transport', (
    tester,
  ) async {
    // 签名凭证 + 无本地 IP 信息 → 走 relay/DNS 解析路径
    repository.connectResult = PairingResult(
      peerId: 'credential-target-device-0001',
      peerName: 'New Phone',
    );
    await _pumpDevicesPage(tester, repository);
    await _openEnterCodeDialog(tester);
    await tester.enterText(
      find.byKey(const ValueKey('pair-credential-input')),
      'cm1.credential-fake-text',
    );
    await tester.tap(find.byKey(const ValueKey('pair-submit')));
    await tester.pumpAndSettle();

    final start = capture.events.firstWhere(
      (e) => e.event == 'pairing.connect' && e.fields['action'] == 'start',
    );
    expect(
      start.fields['transport'],
      'credential',
      reason: '无直连 IP 时应记录 relay_or_dns 传输路径',
    );
  });

  testWidgets('credential scan failure logs sanitized chain and scan source', (
    tester,
  ) async {
    repository.credentialConnectError = StateError(
      'credential=cm1.SECRET pairingCode=123456 privateKey=TOPSECRET',
    );
    await _pumpDevicesPage(tester, repository);
    await _openEnterCodeDialog(tester);
    await tester.enterText(
      find.byKey(const ValueKey('pair-credential-input')),
      'cm1.scan-secret',
    );
    await tester.tap(find.byKey(const ValueKey('pair-submit')));
    await tester.pumpAndSettle();
    final failed = capture.events.firstWhere(
      (e) => e.event == 'pairing.connect' && e.fields['action'] == 'failed',
    );
    expect(failed.fields['source'], 'manual');
    expect(
      capture.events.where(
        (e) => e.event == 'pairing.connect' && e.fields['action'] == 'failed',
      ),
      hasLength(1),
    );
    expect(failed.fields['transport'], 'credential');
    expect(failed.fields['source'], 'manual');
    expect(failed.errorChain, isNot(contains('cm1.SECRET')));
    expect(failed.errorChain, isNot(contains('123456')));
    expect(failed.errorChain, isNot(contains('TOPSECRET')));
  });

  testWidgets('real scanner route emits one scan success lifecycle', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: Scaffold(
          body: DevicesPage(
            repository: repository,
            scanner: const _RouteScanner(ScanOutcome(text: 'cm1.scanned')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('devices-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pair-mode-scan')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('route-scan-detect')));
    await tester.pumpAndSettle();
    expect(
      capture.events.where(
        (e) => e.event == 'pairing.connect' && e.fields['action'] == 'start',
      ),
      hasLength(1),
    );
    expect(
      capture.events.where(
        (e) => e.event == 'pairing.connect' && e.fields['action'] == 'success',
      ),
      hasLength(1),
    );
    expect(
      capture.events.where((e) => e.fields['source'] == 'scan'),
      isNotEmpty,
    );
  });

  // ━━ 验收 9：日志失败不影响配对主流程 ━━
  testWidgets('logger failure does not break pairing flow', (tester) async {
    DebugLogger.instance.setSink(ThrowingSink());
    repository.acceptResult = PairingRequest(
      code: repository.code,
      deviceId: 'requester-device-0001',
      deviceName: 'New Phone',
      relayInfo: '',
      ips: const [],
      nonce: '',
    );
    repository.confirmResult = PairingResult(
      peerId: 'requester-device-0001',
      peerName: 'New Phone',
    );

    await _pumpDevicesPage(tester, repository);
    await _openShowCodeDialog(tester);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('配对成功'),
      findsOneWidget,
      reason: '日志 sink 抛异常时配对仍应完成',
    );
    expect(repository.confirmCalls, 1, reason: 'confirm 应被调用');
  });
}
