import 'package:cardmind/bridge/note_repository.dart';
import 'package:cardmind/pages/devices_page.dart';
import 'package:cardmind/src/rust/discovery.dart';
import 'package:cardmind/src/rust/store.dart';
import 'package:cardmind/src/rust/sync.dart';
import 'package:cardmind/ui/design_system/cardmind_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

/// 任务 J（mDNS 自动发现接线）验收测试：
///
/// - 0. 缺陷回归：设备 ID 留空 + mDNS 无结果 → 友好错误提示（不再裸抛
///     AnyhowException "invalid target endpoint id"）
/// - 1. 确认方（显示码）：开启后 mDNS 广播（start_advertising），关闭后停止
/// - 2. 发起方（输入码）：设备 ID 留空 → mDNS 发现自动填充 target.deviceId
/// - 3. 发起方：mDNS 无结果 → 友好错误文案（不出现 AnyhowException 字样）
/// - 4. 发起方：手动填 ID → 跳过 mDNS 直接用填写值
/// - 5. 确认方：显示码弹窗直接关闭 → stop_advertising 被调用
///
/// 每条验收标准 = 一个测试用例（红-绿-蓝循环）。

// ━━ fake ━━

/// 任务 J 专用 fake repository：记录 UI 对配对 / mDNS 方法的调用轨迹，
/// 并模拟真实 Rust 行为——`beginPairingConnect` 收到空 deviceId 时抛出
/// 与后端一致的 AnyhowException（复现实机缺陷）。
class PairingMdnsRepository implements NoteRepository {
  String acceptCodeValue = '289260';
  int acceptCodeCalls = 0;
  int connectCalls = 0;
  String? connectCode;
  PairingTarget? connectTarget;

  /// 显示码分支开启后是否调用了 start_advertising（组合 API）。
  bool advertisingStarted = false;
  bool advertisingStopped = false;

  /// discoverPeers 返回结果（测试控制）。
  List<PeerInfo> discoverResult = [];
  int discoverCalls = 0;
  Object? discoverError;

  String connectPeerName = 'New Phone';

  @override
  Future<List<PairedDeviceRow>> listPairedDevices() async => [];

  @override
  Future<String> deviceName() async => 'My PC';

  @override
  Future<String> deviceId() async => 'dev-1234567890';

  @override
  Future<String> beginPairingAccept() async {
    acceptCodeCalls++;
    return acceptCodeValue;
  }

  /// 组合 API：生成配对码 + 启动 mDNS 广播。
  @override
  Future<String> beginPairingAcceptAndAdvertise() async {
    acceptCodeCalls++;
    advertisingStarted = true;
    return acceptCodeValue;
  }

  /// 停止 mDNS 广播（弹窗关闭 / 配对完成 / 取消）。
  @override
  Future<void> stopPairingAdvertising() async {
    advertisingStopped = true;
  }

  /// mDNS 扫描局域网内的 CardMind 设备。
  @override
  Future<List<PeerInfo>> discoverPeers() async {
    discoverCalls++;
    if (discoverError case final error?) throw error;
    return List.of(discoverResult);
  }

  @override
  Future<PairingResult> beginPairingConnect(
    String code,
    PairingTarget target,
  ) async {
    connectCalls++;
    connectCode = code;
    connectTarget = target;
    // 模拟真实 Rust：空 device_id 解析 EndpointId 必败
    if (target.deviceId.isEmpty) {
      throw AnyhowException('invalid target endpoint id — invalid length');
    }
    return PairingResult(peerId: target.deviceId, peerName: connectPeerName);
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
      throw UnimplementedError('not used in pairing mdns tests');

  @override
  Future<PairingResult> confirmPairing(String code, PairingRequest requester) =>
      throw UnimplementedError('not used in pairing mdns tests');

  @override
  Future<void> acceptAndImportPush() async {}

  @override
  Future<void> removePairedDevice(String peerId) async {}
}

Future<void> _pumpDevicesPage(
  WidgetTester tester,
  PairingMdnsRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CardMindTheme.light,
      home: Scaffold(body: DevicesPage(repository: repository)),
    ),
  );
  await tester.pumpAndSettle();
}

/// 打开"添加设备"并进入输入码弹窗（发起方分支）。
Future<void> _openEnterCodeDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('devices-add')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('pair-mode-enter')));
  await tester.pumpAndSettle();
}

/// 打开"添加设备"并进入显示码弹窗（确认方分支）。
Future<void> _openShowCodeDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('devices-add')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('pair-mode-show')));
  await tester.pumpAndSettle();
}

void main() {
  // ━━ 验收 0（缺陷回归）：设备 ID 留空 + mDNS 无结果 → 友好错误提示 ━━
  testWidgets('test_regression_empty_device_id_user_path', (tester) async {
    final repository = PairingMdnsRepository()..discoverResult = [];
    await _pumpDevicesPage(tester, repository);
    await _openEnterCodeDialog(tester);

    // 用户只输入配对码，设备 ID 留空（复现实机缺陷路径）
    await tester.enterText(
      find.byKey(const ValueKey('pair-code-input')),
      '289260',
    );
    await tester.tap(find.byKey(const ValueKey('pair-submit')));
    await tester.pumpAndSettle();

    // 修复后：走友好错误提示分支，不裸抛 AnyhowException
    expect(
      find.textContaining('未在局域网发现'),
      findsOneWidget,
      reason: '设备 ID 留空且 mDNS 无结果时应显示友好错误提示',
    );
    expect(
      find.textContaining('AnyhowException'),
      findsNothing,
      reason: '不得向用户展示裸 AnyhowException',
    );
    expect(
      repository.connectCalls,
      0,
      reason: 'mDNS 无结果时不应以空 device_id 调用 beginPairingConnect',
    );
  });

  // ━━ 验收 1：确认方显示码期间广播，关闭后停止 ━━
  testWidgets('confirmer advertises while showing code', (tester) async {
    final repository = PairingMdnsRepository();
    await _pumpDevicesPage(tester, repository);
    await _openShowCodeDialog(tester);

    expect(repository.acceptCodeCalls, 1, reason: '显示码模式应调用配对码生成（组合 API 内含广播）');
    expect(
      repository.advertisingStarted,
      isTrue,
      reason: '显示码开启后应启动 mDNS 广播（start_advertising）',
    );
    expect(find.text('289260'), findsOneWidget);

    // 关闭弹窗 → 停止广播
    await tester.tap(find.byKey(const ValueKey('pair-dialog-close')));
    await tester.pumpAndSettle();
    expect(
      repository.advertisingStopped,
      isTrue,
      reason: '显示码弹窗关闭后应停止 mDNS 广播（stop_advertising）',
    );
  });

  // ━━ 验收 2：发起方设备 ID 留空 → mDNS 自动填充 ━━
  testWidgets('requester auto-fills device id via mdns', (tester) async {
    final repository = PairingMdnsRepository()
      ..discoverResult = [
        PeerInfo(
          deviceId: 'mdns-found-device',
          ip: '192.168.1.42',
          port: 11223,
        ),
      ];
    await _pumpDevicesPage(tester, repository);
    await _openEnterCodeDialog(tester);

    await tester.enterText(
      find.byKey(const ValueKey('pair-code-input')),
      '289260',
    );
    // 设备 ID 留空
    await tester.tap(find.byKey(const ValueKey('pair-submit')));
    await tester.pumpAndSettle();

    expect(repository.discoverCalls, 1, reason: '设备 ID 留空时应先做 mDNS 扫描');
    expect(repository.connectCalls, 1, reason: '发现设备后应继续配对连接');
    expect(
      repository.connectTarget?.deviceId,
      'mdns-found-device',
      reason: 'beginPairingConnect 的 target.deviceId 应为 mDNS 发现的 device_id',
    );
    expect(repository.connectTarget?.ips, [
      '192.168.1.42:11223',
    ], reason: 'target.ips 应带 mDNS 发现的 ip:port 直连地址');
  });

  // ━━ 验收 3：发起方 mDNS 无结果 → 友好错误 ━━
  testWidgets('requester shows friendly error when mdns finds nothing', (
    tester,
  ) async {
    final repository = PairingMdnsRepository()..discoverResult = [];
    await _pumpDevicesPage(tester, repository);
    await _openEnterCodeDialog(tester);

    await tester.enterText(
      find.byKey(const ValueKey('pair-code-input')),
      '289260',
    );
    await tester.tap(find.byKey(const ValueKey('pair-submit')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('未在局域网发现'),
      findsOneWidget,
      reason: 'mDNS 无结果时应提示用户检查网络或手动填写',
    );
    expect(
      find.textContaining('AnyhowException'),
      findsNothing,
      reason: '不得向用户展示裸 AnyhowException',
    );
    expect(repository.connectCalls, 0, reason: 'mDNS 无结果时不应发起连接');
  });

  // ━━ 验收 4：手动填 ID 时跳过 mDNS ━━
  testWidgets('requester uses manual device id when provided', (tester) async {
    final repository = PairingMdnsRepository()
      ..discoverResult = [
        PeerInfo(
          deviceId: 'should-not-be-used',
          ip: '192.168.1.99',
          port: 9999,
        ),
      ];
    await _pumpDevicesPage(tester, repository);
    await _openEnterCodeDialog(tester);

    await tester.enterText(
      find.byKey(const ValueKey('pair-code-input')),
      '289260',
    );
    await tester.enterText(
      find.byKey(const ValueKey('pair-peer-id-input')),
      'manual-device-id',
    );
    await tester.tap(find.byKey(const ValueKey('pair-submit')));
    await tester.pumpAndSettle();

    expect(repository.discoverCalls, 0, reason: '手动填写设备 ID 时应跳过 mDNS 扫描');
    expect(
      repository.connectTarget?.deviceId,
      'manual-device-id',
      reason: 'beginPairingConnect 应使用手动填写的 device_id',
    );
  });

  // ━━ 验收 5：显示码弹窗直接关闭 → 停止广播 ━━
  testWidgets('requester cancels advertising on dialog close', (tester) async {
    final repository = PairingMdnsRepository();
    await _pumpDevicesPage(tester, repository);
    await _openShowCodeDialog(tester);

    expect(repository.advertisingStarted, isTrue);

    // 直接关闭显示码弹窗（不配对）
    await tester.tap(find.byKey(const ValueKey('pair-dialog-close')));
    await tester.pumpAndSettle();

    expect(repository.advertisingStopped, isTrue, reason: '显示码弹窗关闭应停止 mDNS 广播');
  });

  // ━━ 附加：mDNS 发现多台设备时不静默取第一台（需决策点 1 的处理）━━
  testWidgets('requester shows guidance when multiple mdns devices found', (
    tester,
  ) async {
    final repository = PairingMdnsRepository()
      ..discoverResult = [
        PeerInfo(deviceId: 'device-a', ip: '10.0.0.2', port: 11223),
        PeerInfo(deviceId: 'device-b', ip: '10.0.0.3', port: 11223),
      ];
    await _pumpDevicesPage(tester, repository);
    await _openEnterCodeDialog(tester);

    await tester.enterText(
      find.byKey(const ValueKey('pair-code-input')),
      '289260',
    );
    await tester.tap(find.byKey(const ValueKey('pair-submit')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('多台'),
      findsOneWidget,
      reason: '发现多台设备时不应静默取第一台，应引导手动填写',
    );
    expect(repository.connectCalls, 0, reason: '多台设备歧义时不应发起连接');
  });
}
