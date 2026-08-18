import 'dart:async';

import 'package:cardmind/bridge/note_repository.dart';
import 'package:cardmind/bridge/sync_scheduler.dart';
import 'package:cardmind/pages/devices_page.dart';
import 'package:cardmind/pages/note_list_page.dart';
import 'package:cardmind/src/rust/discovery.dart';
import 'package:cardmind/src/rust/store.dart';
import 'package:cardmind/src/rust/sync.dart';
import 'package:cardmind/ui/design_system/cardmind_theme.dart';
import 'package:cardmind/ui/design_system/cardmind_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 任务 I（模块 5）验收测试：状态指示器 + 立即同步 + 设备页（两端）。
///
/// 每条验收标准 = 一个测试用例（详见下方注释编号）。

// ━━ fakes ━━

class FakeNetworkMonitor implements NetworkTypeMonitor {
  final _controller = StreamController<bool>.broadcast();

  @override
  Stream<bool> get allowedChanges => _controller.stream;

  @override
  Future<bool> currentAllowed() async => true;

  @override
  void dispose() {
    if (!_controller.isClosed) _controller.close();
  }
}

class FakeSyncApi implements SyncApi {
  /// 待同步计数返回值（测试控制）。
  int pendingCountValue = 0;

  final List<bool> setSyncAllowedCalls = [];
  int runSyncCycleCalls = 0;
  int receiverRevision = 0;

  /// 非空时挂起 runSyncCycle（模拟同步进行中）。
  Completer<void>? cycleGate;

  @override
  Future<int> get pollIntervalSecs async => 60;

  @override
  Future<int> pendingCount() async => pendingCountValue;

  @override
  Future<void> setSyncAllowed(bool allowed) async {
    setSyncAllowedCalls.add(allowed);
  }

  @override
  Future<void> pushPending() async {}

  @override
  Future<void> runSyncCycle() async {
    runSyncCycleCalls++;
    final gate = cycleGate;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> startReceiver() async {}

  @override
  Future<void> stopReceiver() async {}

  @override
  Future<int> receiverContentRevision() async => receiverRevision;
}

/// 设备页 / 列表页共享的内存 fake repository。
class DevicesRepository implements NoteRepository {
  List<PairedDeviceRow> pairedDevices = [];
  String deviceNameValue = 'My PC';
  String deviceIdValue = 'dev-1234567890';
  String acceptCodeValue = '123456';
  int acceptCodeCalls = 0;
  int credentialCalls = 0;
  int credentialConnectCalls = 0;
  int removeCalls = 0;
  final List<String> removedPeerIds = [];
  int connectCalls = 0;
  String? connectCode;
  PairingTarget? connectTarget;
  String connectPeerName = 'New Phone';

  /// 任务 J：mDNS 广播生命周期记录（显示码开启/关闭）。
  bool advertisingStarted = false;
  bool advertisingStopped = false;

  @override
  Future<List<PairedDeviceRow>> listPairedDevices() async =>
      List.of(pairedDevices);

  @override
  Future<String> deviceName() async => deviceNameValue;

  @override
  Future<String> deviceId() async => deviceIdValue;

  @override
  Future<String> beginPairingAccept() async {
    acceptCodeCalls++;
    return acceptCodeValue;
  }

  /// 组合 API（任务 J）：生成配对码并启动 mDNS 广播。
  @override
  Future<String> beginPairingAcceptAndAdvertise() async {
    acceptCodeCalls++;
    advertisingStarted = true;
    return acceptCodeValue;
  }

  @override
  Future<void> stopPairingAdvertising() async {
    advertisingStopped = true;
  }

  @override
  Future<List<PeerInfo>> discoverPeers() async => [];

  @override
  Future<void> removePairedDevice(String peerId) async {
    removeCalls++;
    removedPeerIds.add(peerId);
    pairedDevices.removeWhere((d) => d.peerId == peerId);
  }

  @override
  Future<PairingResult> beginPairingConnect(
    String code,
    PairingTarget target,
  ) async {
    connectCalls++;
    connectCode = code;
    connectTarget = target;
    pairedDevices.add(
      PairedDeviceRow(
        peerId: target.deviceId,
        name: connectPeerName,
        lastSeen: DateTime.now().toIso8601String(),
        pairedAt: DateTime.now().toIso8601String(),
      ),
    );
    return PairingResult(peerId: target.deviceId, peerName: connectPeerName);
  }

  @override
  Future<PairingCredentialDisplay> beginPairingCredential() async {
    credentialCalls++;
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
      throw UnimplementedError('not used in device page tests');

  /// 任务 M：有界接收——本 fake 不模拟接收（显示码弹窗仅展示码，不配对），
  /// 返回永不完成的 future，使现有显示码测试保持"等待中"状态。
  @override
  Future<PairingRequest?> acceptPairingRequestWithTimeout(Duration timeout) =>
      Completer<PairingRequest?>().future;

  @override
  Future<PairingResult> confirmPairing(String code, PairingRequest requester) =>
      throw UnimplementedError('not used in device page tests');

  @override
  Future<void> acceptAndImportPush() async {}
}

SyncScheduler _scheduler(FakeSyncApi api) =>
    SyncScheduler(monitor: FakeNetworkMonitor(), api: api);

Future<void> _pumpStatus(WidgetTester tester, CardMindSyncStatus status) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CardMindTheme.light,
      home: Scaffold(body: Center(child: status)),
    ),
  );
}

void main() {
  // ━━ 验收 1：status shows pending count when unsynced ━━
  testWidgets('status shows pending count when unsynced', (tester) async {
    await _pumpStatus(tester, const CardMindSyncStatus(pendingCount: 3));
    expect(find.text('3 篇待同步'), findsOneWidget);

    await _pumpStatus(tester, const CardMindSyncStatus(pendingCount: 0));
    expect(
      find.textContaining('待同步'),
      findsNothing,
      reason: '无待同步时应回归纯圆点，不显示计数文字',
    );
    expect(find.text('本地已就绪'), findsOneWidget);
  });

  // ━━ 验收 2：sync now button appears only with pending ━━
  testWidgets('sync now button appears only with pending', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeSyncApi()..pendingCountValue = 0;
    final scheduler = _scheduler(api);

    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: NoteListPage(
          repository: DevicesRepository(),
          scheduler: scheduler,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('sync-now-button')),
      findsNothing,
      reason: 'pendingCount=0 时不应出现立即同步按钮',
    );

    api.pendingCountValue = 3;
    await scheduler.refreshPendingCount();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('sync-now-button')),
      findsOneWidget,
      reason: 'pendingCount>0 时应出现立即同步按钮',
    );
  });

  // ━━ 验收 3：sync now triggers cycle and disables during run ━━
  testWidgets('sync now triggers cycle and disables during run', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeSyncApi()..pendingCountValue = 3;
    final scheduler = _scheduler(api);

    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: NoteListPage(
          repository: DevicesRepository(),
          scheduler: scheduler,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 挂起 runSyncCycle 模拟同步进行中
    final gate = Completer<void>();
    api.cycleGate = gate;

    await tester.tap(find.byKey(const ValueKey('sync-now-button')));
    await tester.pump();

    expect(api.setSyncAllowedCalls, [
      true,
    ], reason: '手动立即同步应先临时打开同步开关（无视 WiFi 限制）');
    expect(api.runSyncCycleCalls, 1, reason: '应立即触发一次同步周期');

    final runningButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('sync-now-button')),
    );
    expect(runningButton.onPressed, isNull, reason: '同步进行中按钮应禁用（防连点）');

    gate.complete();
    await tester.pumpAndSettle();

    final idleButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('sync-now-button')),
    );
    expect(idleButton.onPressed, isNotNull, reason: '同步完成后按钮应恢复可用');
  });

  // ━━ 验收 4：status turns gray after prolonged failure ━━
  testWidgets('status turns gray after prolonged failure', (tester) async {
    await _pumpStatus(
      tester,
      const CardMindSyncStatus(lastSyncFailedFor: Duration(hours: 25)),
    );
    expect(find.text('长时间未同步'), findsOneWidget);

    final dot = tester.widget<Container>(
      find.byKey(const ValueKey('sync-status-dot')),
    );
    final decoration = dot.decoration as BoxDecoration;
    expect(
      decoration.color,
      CardMindSyncStatus.staleDotColor,
      reason: '连续失败超过 24 小时圆点应变色提示',
    );
  });

  // ━━ 验收 5：devices page lists paired devices ━━
  testWidgets('devices page lists paired devices', (tester) async {
    final now = DateTime.now();
    final repository = DevicesRepository()
      ..pairedDevices = [
        PairedDeviceRow(
          peerId: 'peer-a',
          name: '桌面 Mac',
          lastSeen: now.subtract(const Duration(minutes: 2)).toIso8601String(),
          pairedAt: now.toIso8601String(),
        ),
        PairedDeviceRow(
          peerId: 'peer-b',
          name: '手机',
          lastSeen: now.subtract(const Duration(hours: 3)).toIso8601String(),
          pairedAt: now.toIso8601String(),
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: Scaffold(body: DevicesPage(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    // 本机信息
    expect(find.text('My PC'), findsOneWidget);
    expect(
      find.text('dev-1234…'),
      findsOneWidget,
      reason: '本机 device_id 短显示（前 8 字符）',
    );

    // 设备列表：名称 + 状态 + 最后同步时间
    expect(find.text('桌面 Mac'), findsOneWidget);
    expect(find.text('手机'), findsOneWidget);
    expect(find.text('在线'), findsOneWidget, reason: '最近 5 分钟内同步过 → 在线');
    expect(find.textContaining('离线'), findsOneWidget);
    expect(find.textContaining('3 小时前'), findsOneWidget);
    // 卸载页面以取消后台刷新 Timer（任务 O 验收 15）
    await tester.pumpWidget(const SizedBox());
  });

  // ━━ 验收 6：devices page empty state ━━
  testWidgets('devices page empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: Scaffold(body: DevicesPage(repository: DevicesRepository())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有配对设备'), findsOneWidget);
    expect(
      find.textContaining('添加设备'),
      findsWidgets,
      reason: '空状态应包含引导文案与添加入口',
    );
    await tester.pumpWidget(const SizedBox());
  });

  // ━━ 验收 7：unpair flow asks confirmation then removes ━━
  testWidgets('unpair flow asks confirmation then removes', (tester) async {
    final now = DateTime.now();
    final repository = DevicesRepository()
      ..pairedDevices = [
        PairedDeviceRow(
          peerId: 'peer-a',
          name: '桌面 Mac',
          lastSeen: now.toIso8601String(),
          pairedAt: now.toIso8601String(),
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: Scaffold(body: DevicesPage(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('unpair-peer-a')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('解除后不再同步'),
      findsOneWidget,
      reason: '解除配对前应弹确认框',
    );

    await tester.tap(find.byKey(const ValueKey('unpair-confirm')));
    await tester.pumpAndSettle();

    expect(repository.removeCalls, 1);
    expect(repository.removedPeerIds, ['peer-a']);
    expect(find.text('桌面 Mac'), findsNothing, reason: '解除后列表应刷新');
    await tester.pumpWidget(const SizedBox());
  });

  // ━━ 验收 8：pairing flow shows code and accepts input ━━
  testWidgets('pairing flow shows code and accepts input', (tester) async {
    final repository = DevicesRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: Scaffold(body: DevicesPage(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    // 第一步：两种模式
    await tester.tap(find.byKey(const ValueKey('devices-add')));
    await tester.pumpAndSettle();
    expect(find.text('我显示配对码'), findsOneWidget);
    expect(find.text('我输入对方的码'), findsOneWidget);

    // 我显示码 → 第二步展示本机码
    await tester.tap(find.byKey(const ValueKey('pair-mode-show')));
    await tester.pumpAndSettle();
    expect(
      repository.credentialCalls,
      1,
      reason: '显示码模式应调用 beginPairingCredential',
    );
    expect(find.text('289260'), findsOneWidget);

    // 关闭，进入输入码模式
    await tester.tap(find.byKey(const ValueKey('pair-dialog-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('devices-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pair-mode-enter')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('pair-credential-input')),
      'cm1.credential-fake-text',
    );
    await tester.tap(find.byKey(const ValueKey('pair-submit')));
    await tester.pumpAndSettle();

    expect(repository.credentialConnectCalls, 1, reason: '输入凭证应调用配对连接 API');
    expect(find.textContaining('配对成功'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  // ━━ 验收 9：mobile devices tab renders device page ━━
  testWidgets('mobile devices tab renders device page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.now();
    final repository = DevicesRepository()
      ..pairedDevices = [
        PairedDeviceRow(
          peerId: 'peer-a',
          name: '桌面 Mac',
          lastSeen: now.toIso8601String(),
          pairedAt: now.toIso8601String(),
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: NoteListPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('设备'));
    await tester.pumpAndSettle();

    expect(
      find.byType(DevicesPage),
      findsOneWidget,
      reason: '移动端设备 tab 应渲染设备页（替换空壳占位）',
    );
    expect(find.text('桌面 Mac'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  // ━━ 验收 10：desktop sidebar has devices entry ━━
  testWidgets('desktop sidebar has devices entry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = DevicesRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: NoteListPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('devices-entry')),
      findsOneWidget,
      reason: '桌面侧边栏底部应有设备入口',
    );
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byKey(const ValueKey('devices-entry')));
    await tester.pumpAndSettle();

    expect(find.byType(DevicesPage), findsOneWidget, reason: '点击设备入口应进入设备页');
    await tester.pumpWidget(const SizedBox());
  });

  // ━━ 验收 15（任务 O）：devices page refreshes status ━━
  // 页面保持打开时，后台 last_seen 更新后在 ≤5 秒内从离线变在线；
  // dispose 后不再刷新（不产生 pending timer / 不崩溃）。
  testWidgets('devices page refreshes online status in background', (
    tester,
  ) async {
    final now = DateTime.now();
    final repository = DevicesRepository()
      ..pairedDevices = [
        PairedDeviceRow(
          peerId: 'peer-a',
          name: '桌面 Mac',
          lastSeen: now.subtract(const Duration(hours: 1)).toIso8601String(),
          pairedAt: now.toIso8601String(),
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: Scaffold(body: DevicesPage(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('离线'),
      findsOneWidget,
      reason: '初始 last_seen 1 小时前 → 离线',
    );

    // 后台同步更新 last_seen（模拟对端 push 后接收器刷新投影）
    repository.pairedDevices = [
      PairedDeviceRow(
        peerId: 'peer-a',
        name: '桌面 Mac',
        lastSeen: DateTime.now().toIso8601String(),
        pairedAt: now.toIso8601String(),
      ),
    ];

    // 后台刷新周期 2s：推进 2s 触发 Timer → 再 pump 一帧让 async _load 完成
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(
      find.text('在线'),
      findsOneWidget,
      reason: '后台 last_seen 更新后应在 ≤5 秒内刷新为在线（实际 2 秒周期）',
    );

    // dispose 后不再刷新：卸载页面，之后推进时间不产生 pending timer / 不崩溃
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('devices page stops refreshing after dispose', (tester) async {
    final repository = DevicesRepository()
      ..pairedDevices = [
        PairedDeviceRow(
          peerId: 'peer-x',
          name: '设备 X',
          lastSeen: null,
          pairedAt: DateTime.now().toIso8601String(),
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: Scaffold(body: DevicesPage(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('离线'), findsOneWidget);

    // 卸载页面（dispose）
    await tester.pumpWidget(const SizedBox());
    // dispose 后修改数据 + 推进时间：不应触发任何刷新/异常
    repository.pairedDevices = [
      PairedDeviceRow(
        peerId: 'peer-x',
        name: '设备 X',
        lastSeen: DateTime.now().toIso8601String(),
        pairedAt: DateTime.now().toIso8601String(),
      ),
    ];
    await tester.pump(const Duration(seconds: 5));
    // 无 pending timer、无异常即通过
  });
}
