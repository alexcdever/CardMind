// input: 真实 FRB 动态库、app config 与 network handle。
// output: 断言 FrbSyncGateway 能贯通 status/connect/join/push/pull/disconnect。
// pos: 同步网关契约测试。修改本文件需同步更新所属 DIR.md。
import 'dart:io';

import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/bridge_generated/frb_generated.dart';
import 'package:cardmind/features/sync/sync_service.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';

bool _rustLibInitialized = false;

Future<void> _ensureRustLibInitialized() async {
  if (_rustLibInitialized) return;
  final dylib = File(
    'rust/target/release/libcardmind_rust.dylib',
  ).absolute.path;
  await RustLib.init(externalLibrary: ExternalLibrary.open(dylib));
  _rustLibInitialized = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('frb sync gateway delegates all sync operations', () async {
    final root = await Directory.systemTemp.createTemp(
      'cardmind-sync-gateway-',
    );
    await _ensureRustLibInitialized();
    await frb.resetAppConfigForTests();
    await frb.initAppConfig(appDataDir: root.path);

    final gateway = FrbSyncGateway();
    final networkId = await frb.initPoolNetwork(basePath: root.path);
    final pool = await frb.createPool(
      endpointId: 'endpoint-a',
      nickname: 'owner',
      os: 'macos',
    );

    try {
      final initial = await gateway.syncStatus(networkId: networkId);
      // Phase 2: "idle" 映射为 "ready"
      expect(initial.syncState, 'ready');

      await gateway.syncConnect(networkId: networkId, target: 'peer');
      await gateway.syncJoinPool(networkId: networkId, poolId: pool.id);

      final pushed = await gateway.syncPush(networkId: networkId);
      final pulled = await gateway.syncPull(networkId: networkId);
      final connected = await gateway.syncStatus(networkId: networkId);

      // Phase 2: "connected" 映射为 "ready"
      expect(pushed.syncState, 'ready');
      expect(pulled.syncState, 'ready');
      expect(connected.syncState, 'ready');

      await gateway.syncDisconnect(networkId: networkId);
      final disconnected = await gateway.syncStatus(networkId: networkId);
      // Phase 2: "idle" 映射为 "ready"
      expect(disconnected.syncState, 'ready');
    } finally {
      await frb.closePoolNetwork(networkId: networkId);
      await frb.resetAppConfigForTests();
      await root.delete(recursive: true);
    }
  });
}
