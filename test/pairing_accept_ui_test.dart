import 'dart:async';

import 'package:cardmind/bridge/note_repository.dart';
import 'package:cardmind/pages/devices_page.dart';
import 'package:cardmind/src/rust/discovery.dart';
import 'package:cardmind/src/rust/store.dart';
import 'package:cardmind/src/rust/sync.dart';
import 'package:cardmind/ui/design_system/cardmind_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 任务 M（显示码流程启动确认方接收器）验收测试：
///
/// 缺陷：`DevicesPage._showMyCode()` 只生成配对码并展示弹窗，没有启动
/// `acceptPairingRequest()`，也没有在收到请求后调用 `confirmPairing(code, requester)`，
/// 导致发起方经 relay 发出请求后确认方无人消费，最终 `connect to confirmer -> timed out`。
///
/// 每条验收标准 = 一个测试用例（红-绿-蓝循环）：
/// 1. show-code starts confirmer accept loop
/// 2. received request confirms with displayed code
/// 3. pairing success closes or updates waiting state
/// 4. cancel stops advertising and accept task
/// 5. accept failure is visible and recoverable
/// 6. accept timeout is bounded
/// 7. reopen does not duplicate accept loops
/// 8. signed credential relay pairing UI path

// ━━ fake ━━

/// 任务 M 专用 fake repository：记录 UI 对配对 API 的调用轨迹，并可控地模拟
/// 确认方接收（acceptPairingRequestWithTimeout）与确认（confirmPairing）行为。
class PairingAcceptRepository implements NoteRepository {
  /// 显示的配对码（固定，测试断言用）。
  String acceptCodeValue = '289260';

  /// 生成的请求样例（默认返回；测试可覆盖）。
  static PairingRequest sampleRequest() => const PairingRequest(
    code: '289260',
    deviceId: 'initiator-device',
    deviceName: 'New Phone',
    relayInfo: '',
    ips: [],
    nonce: '',
  );

  // ━━ 调用轨迹 ━━
  int acceptCalls = 0;
  int confirmCalls = 0;
  int connectCalls = 0;
  int discoverCalls = 0;
  int listPairedCalls = 0;
  int credentialCalls = 0;
  int credentialConnectCalls = 0;
  String? confirmCode;
  PairingRequest? confirmRequester;
  Duration? acceptTimeoutArg;
  String? connectCode;
  PairingTarget? connectTarget;
  bool advertisingStarted = false;
  bool advertisingStopped = false;

  // ━━ 凭证 fake 数据（任务 Q）━━
  String credentialCode = '289260';
  String credentialText = 'cm1.credential-fake-text';

  // ━━ 行为控制 ━━
  /// accept 返回的请求；null 表示超时。优先级低于 [acceptError]、[timeoutResults]
  /// 与 [acceptGate]。
  PairingRequest? acceptResult = sampleRequest();

  /// accept 抛错（模拟网络/后端异常）。
  Object? acceptError;

  /// 前 N 次 accept 返回 null（模拟有界窗口超时）。任务 U7：超时后 UI 会静默
  /// 自动重生成并再次 accept——测试时钟下必须用"有限次 null + 挂起"收尾，
  /// 否则重生成链在纯 microtask 中无限旋转拖死 pumpAndSettle。
  int timeoutResults = 0;

  /// [timeoutResults] 用尽且无 gate 后挂起等待（模拟真实设备窗口内的静默等待），
  /// 保证测试可终止、断言时链路已静止。
  bool parkAfterTimeouts = false;

  /// accept 挂起等待 gate；测试完成后释放（模拟慢请求/取消后返回）。
  Completer<PairingRequest?>? acceptGate;

  /// confirm 抛错（模拟确认失败）。
  Object? confirmError;

  /// confirm 成功后设备列表返回的内容（模拟确认方持久化发起方）。
  List<PairedDeviceRow> pairedDevices = [];

  @override
  Future<String> beginPairingAccept() async => acceptCodeValue;

  @override
  Future<String> beginPairingAcceptAndAdvertise() async {
    advertisingStarted = true;
    return acceptCodeValue;
  }

  @override
  Future<void> stopPairingAdvertising() async {
    advertisingStopped = true;
  }

  @override
  Future<PairingRequest?> acceptPairingRequestWithTimeout(
    Duration timeout,
  ) async {
    acceptCalls++;
    acceptTimeoutArg = timeout;
    if (acceptError case final error?) throw error;
    if (timeoutResults > 0) {
      timeoutResults--;
      return null;
    }
    if (acceptGate case final gate?) return gate.future;
    if (parkAfterTimeouts) return Completer<PairingRequest?>().future;
    return acceptResult;
  }

  @override
  Future<PairingResult> confirmPairing(
    String code,
    PairingRequest requester,
  ) async {
    confirmCalls++;
    confirmCode = code;
    confirmRequester = requester;
    if (confirmError case final error?) throw error;
    return PairingResult(
      peerId: requester.deviceId,
      peerName: requester.deviceName,
    );
  }

  @override
  Future<List<PairedDeviceRow>> listPairedDevices() async {
    listPairedCalls++;
    return pairedDevices;
  }

  @override
  Future<List<PeerInfo>> discoverPeers() async {
    discoverCalls++;
    return const [];
  }

  @override
  Future<PairingResult> beginPairingConnect(
    String code,
    PairingTarget target,
  ) async {
    connectCalls++;
    connectCode = code;
    connectTarget = target;
    return PairingResult(peerId: target.deviceId, peerName: 'Android Phone');
  }

  @override
  Future<PairingCredentialDisplay> beginPairingCredential() async {
    credentialCalls++;
    advertisingStarted = true;
    return PairingCredentialDisplay(
      code: credentialCode,
      credential: credentialText,
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
      code: credentialCode,
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
    return PairingResult(peerId: 'parsed-device', peerName: 'Trusted PC');
  }

  @override
  Future<String> deviceName() async => 'My PC';

  @override
  Future<String> deviceId() async => 'confirmer-device';

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
      throw UnimplementedError('UI 走有界版本 acceptPairingRequestWithTimeout');

  @override
  Future<void> acceptAndImportPush() async {}

  @override
  Future<void> removePairedDevice(String peerId) async {}
}

Future<void> _pumpDevicesPage(
  WidgetTester tester,
  PairingAcceptRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CardMindTheme.light,
      home: Scaffold(body: DevicesPage(repository: repository)),
    ),
  );
  await tester.pumpAndSettle();
}

/// 打开"添加设备"并进入显示码弹窗（确认方分支）。
Future<void> _openShowCodeDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('devices-add')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('pair-mode-show')));
  await tester.pumpAndSettle();
}

/// 打开"添加设备"并进入输入码弹窗（发起方分支）。
Future<void> _openEnterCodeDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('devices-add')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('pair-mode-enter')));
  await tester.pumpAndSettle();
}

void main() {
  // ━━ 验收 1：显示码后启动确认方接收器 ━━
  testWidgets('show-code starts confirmer accept loop', (tester) async {
    final repository = PairingAcceptRepository()
      ..acceptGate = Completer<PairingRequest?>();
    await _pumpDevicesPage(tester, repository);
    await _openShowCodeDialog(tester);

    expect(
      repository.acceptCalls,
      1,
      reason: '显示码后应启动确认方接收器（acceptPairingRequestWithTimeout）',
    );
    expect(repository.acceptTimeoutArg, isNotNull, reason: '接收器应带有界时限（不得无限阻塞）');
    expect(find.text('289260'), findsOneWidget, reason: '弹窗应展示配对码');

    // 清理：关闭弹窗（accept 挂起被释放，见验收 4/7）
    await tester.tap(find.byKey(const ValueKey('pair-dialog-close')));
    await tester.pumpAndSettle();
    expect(repository.advertisingStopped, isTrue);
  });

  // ━━ 验收 2：收到请求后以显示的码 confirm ━━
  testWidgets('received request confirms with displayed code', (tester) async {
    final repository = PairingAcceptRepository();
    await _pumpDevicesPage(tester, repository);
    await _openShowCodeDialog(tester);

    // fake 默认 accept 立即返回请求 → confirmPairing(displayedCode, requester)
    await tester.pumpAndSettle();

    expect(repository.acceptCalls, 1);
    expect(
      repository.confirmCalls,
      1,
      reason: '收到配对请求后应调用 confirmPairing 完成配对',
    );
    expect(repository.confirmCode, '289260', reason: 'confirm 应使用弹窗展示的 6 位配对码');
    expect(
      repository.confirmRequester?.deviceId,
      'initiator-device',
      reason: 'confirm 应携带发起方身份',
    );
  });

  // ━━ 验收 3：配对成功后结束等待并刷新设备列表 ━━
  testWidgets('pairing success closes or updates waiting state', (
    tester,
  ) async {
    final repository = PairingAcceptRepository()
      ..pairedDevices = [
        PairedDeviceRow(
          peerId: 'initiator-device',
          name: 'New Phone',
          pairedAt: DateTime.now().toIso8601String(),
        ),
      ];
    final listCallsBefore = repository.listPairedCalls;
    await _pumpDevicesPage(tester, repository);
    await _openShowCodeDialog(tester);
    await tester.pumpAndSettle();

    expect(repository.confirmCalls, 1, reason: 'confirm 成功');
    expect(
      repository.listPairedCalls,
      greaterThan(listCallsBefore),
      reason: '配对成功后设备列表应刷新',
    );
    expect(
      find.byKey(const ValueKey('pair-code-display')),
      findsNothing,
      reason: '配对成功后等待弹窗应关闭',
    );
    expect(find.textContaining('配对成功'), findsOneWidget, reason: '应显示配对成功提示');
    expect(find.text('New Phone'), findsOneWidget, reason: '设备列表应出现对方设备');
  });

  // ━━ 验收 4：取消后停止广播、不 confirm、不 setState 已卸载 widget ━━
  testWidgets('cancel stops advertising and accept task', (tester) async {
    final repository = PairingAcceptRepository()
      ..acceptGate = Completer<PairingRequest?>();
    await _pumpDevicesPage(tester, repository);
    await _openShowCodeDialog(tester);

    expect(repository.acceptCalls, 1);
    expect(repository.advertisingStarted, isTrue);

    // 取消：关闭弹窗 → 停止广播
    await tester.tap(find.byKey(const ValueKey('pair-dialog-close')));
    await tester.pumpAndSettle();
    expect(
      repository.advertisingStopped,
      isTrue,
      reason: '取消/关闭显示码弹窗后应停止 mDNS 广播',
    );

    // 取消后 accept 才返回请求：不得 confirm，也不得向已卸载 widget 调 setState
    repository.acceptGate!.complete(PairingAcceptRepository.sampleRequest());
    await tester.pumpAndSettle();
    expect(repository.confirmCalls, 0, reason: '取消后收到请求不得调用 confirmPairing');
    expect(tester.takeException(), isNull, reason: '不得向已卸载 widget 调 setState');
  });

  // ━━ 验收 5：accept 异常可见且可恢复 ━━
  testWidgets('accept failure is visible and recoverable', (tester) async {
    final repository = PairingAcceptRepository()
      ..acceptError = Exception('network down');
    await _pumpDevicesPage(tester, repository);
    await _openShowCodeDialog(tester);
    await tester.pumpAndSettle();

    expect(repository.acceptCalls, 1);
    expect(
      find.byKey(const ValueKey('pair-accept-error')),
      findsOneWidget,
      reason: 'accept 异常应在弹窗内显示错误',
    );
    expect(
      find.textContaining('等待配对请求失败'),
      findsOneWidget,
      reason: '错误应可读（不展示裸异常）',
    );
    expect(find.textContaining('AnyhowException'), findsNothing);
    expect(
      repository.advertisingStopped,
      isTrue,
      reason: 'accept 异常后应停止广播（设计目标 5）',
    );

    // 关闭后可重新发起（再次打开仍能启动接收器）
    await tester.tap(find.byKey(const ValueKey('pair-dialog-close')));
    await tester.pumpAndSettle();
    repository.acceptError = null;
    repository.timeoutResults = 1; // 本次模拟超时路径
    repository.parkAfterTimeouts = true; // 超时后挂起，链路静止
    await _openShowCodeDialog(tester);
    await tester.pumpAndSettle();
    expect(
      repository.acceptCalls,
      greaterThanOrEqualTo(2),
      reason: '失败后重新发起仍启动接收器（U7：模拟的超时会再触发一轮自动重生成）',
    );
    expect(
      find.byKey(const ValueKey('pair-accept-error')),
      findsNothing,
      reason: 'U7：超时静默自动重生成，不得显示超时错误',
    );
    await tester.tap(find.byKey(const ValueKey('pair-dialog-close')));
    await tester.pumpAndSettle();
  });

  // ━━ 验收 6（U7 重写）：确认方等待超时 → 静默自动重生成 ━━
  testWidgets(
    'accept timeout silently regenerates credential instead of showing error',
    (tester) async {
      final repository = PairingAcceptRepository()
        ..acceptResult = null
        ..timeoutResults =
            2 // 前两轮模拟窗口超时 → 应触发两轮自动重生成
        ..parkAfterTimeouts = true; // 之后挂起：链路静止，断言可确定性进行
      await _pumpDevicesPage(tester, repository);
      await _openShowCodeDialog(tester);
      await tester.pumpAndSettle();

      expect(
        repository.credentialCalls,
        greaterThanOrEqualTo(2),
        reason: '超时应静默重生成凭证（新 code + 新 nonce + 重启广播）',
      );
      expect(
        repository.acceptCalls,
        greaterThanOrEqualTo(2),
        reason: '每轮重生成都应启动新的有界 accept loop',
      );
      expect(
        repository.acceptTimeoutArg,
        const Duration(minutes: 10),
        reason: 'accept 窗口应与配对码有效期 PAIRING_CODE_TTL 对齐为 10 分钟',
      );
      expect(
        find.textContaining('等待配对超时'),
        findsNothing,
        reason: '超时不得再向用户显示错误文案（用户无感）',
      );
      expect(find.byKey(const ValueKey('pair-accept-error')), findsNothing);
      expect(
        find.byKey(const ValueKey('pair-code-display')),
        findsOneWidget,
        reason: '二维码/配对码仍展示（新一轮有效期内）',
      );
      expect(
        repository.advertisingStopped,
        isTrue,
        reason: '重启广播语义：重生成前应停掉旧广播',
      );

      // 关闭弹窗（收尾路径仍停止广播，幂等）
      await tester.tap(find.byKey(const ValueKey('pair-dialog-close')));
      await tester.pumpAndSettle();
      expect(repository.advertisingStopped, isTrue);
    },
  );

  // ━━ 验收 7：重复打开/关闭不叠加并发接收器 ━━
  testWidgets('reopen does not duplicate accept loops', (tester) async {
    final repository = PairingAcceptRepository()
      ..acceptGate = Completer<PairingRequest?>();
    await _pumpDevicesPage(tester, repository);

    // 第一次打开 → 关闭
    await _openShowCodeDialog(tester);
    expect(repository.acceptCalls, 1, reason: '单次打开只启动一个接收器');
    await tester.tap(find.byKey(const ValueKey('pair-dialog-close')));
    await tester.pumpAndSettle();

    // 第二次打开
    await _openShowCodeDialog(tester);
    expect(repository.acceptCalls, 2, reason: '重复打开各启动一个接收器（不叠加/不复制）');

    // 两个挂起的 accept future 同时完成：只有活着的弹窗 confirm
    repository.acceptGate!.complete(PairingAcceptRepository.sampleRequest());
    await tester.pumpAndSettle();
    expect(
      repository.confirmCalls,
      1,
      reason: '已取消弹窗的接收器不得 confirm，只有当前弹窗 confirm',
    );
    expect(repository.confirmCode, '289260');
    // 当前弹窗配对成功 → 自动关闭；页面收尾停止广播
    expect(
      find.byKey(const ValueKey('pair-code-display')),
      findsNothing,
      reason: '配对成功弹窗应关闭',
    );
    expect(repository.advertisingStopped, isTrue, reason: '配对成功后页面收尾停止广播');
  });

  // ━━ 验收 8：签名凭证 relay 配对 UI 路径（双方 API 调用链完整） ━━
  testWidgets('signed credential relay pairing UI path', (tester) async {
    final repository = PairingAcceptRepository();
    await _pumpDevicesPage(tester, repository);

    // 确认方：显示码 → accept loop → confirm（以显示的码）
    await _openShowCodeDialog(tester);
    await tester.pumpAndSettle();
    expect(repository.acceptCalls, 1, reason: '确认方等待器应被启动');
    expect(repository.confirmCalls, 1, reason: '确认方应 confirm 发起方请求');
    expect(repository.confirmCode, '289260');

    // 发起方：粘贴签名凭证（relay 跨网段路径）→ 不走 mDNS
    await _openEnterCodeDialog(tester);
    await tester.enterText(
      find.byKey(const ValueKey('pair-credential-input')),
      'cm1.credential-fake-text',
    );
    await tester.tap(find.byKey(const ValueKey('pair-submit')));
    await tester.pumpAndSettle();

    expect(repository.discoverCalls, 0, reason: '输入签名凭证时不走 mDNS 扫描');
    expect(
      repository.credentialConnectCalls,
      1,
      reason: '发起方应调用 beginPairingConnectWithCredential（relay 路径）',
    );
    expect(repository.discoverCalls, 0);
    expect(find.textContaining('配对成功'), findsWidgets, reason: '发起方配对成功提示');
  });
}
