// input: 真实 FRB 初始化参数，以及应用配置、创建池、创建卡片、查询与同步调用序列。
// output: 断言 Flutter 可经由 Rust 后端完成最小 pool-card-sync 烟测主链路。
// pos: 覆盖跨语言无句柄主链路烟测，防止 FRB 接口虽生成但无法贯通真实后端。修改本文件需同步更新文件头与所属 DIR.md。
import 'dart:io';

import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/bridge_generated/frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_utils/rust_library_test_helper.dart';

void main() {
  test(
    'flutter FRB flow should work after initAppConfig without storeId',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final root = await Directory.systemTemp.createTemp('cardmind-frb-flow-');
      final basePath = root.path;
      final dylibPath = resolveRustLibraryPathForTests();

      await RustLib.init(externalLibrary: ExternalLibrary.open(dylibPath));

      await frb.initAppConfig(appDataDir: basePath);
      await frb.setupAppLock(pin: '1234', allowBiometric: true);
      await frb.verifyAppLockWithPin(pin: '1234');
      final networkId = await frb.initPoolNetwork(basePath: basePath);

      try {
        final pool = await frb.createPool(
          endpointId: 'endpoint-a',
          nickname: 'nick-a',
          os: 'macos',
        );
        final card = await frb.createCardNoteInPool(
          poolId: pool.id,
          title: 'smoke-title',
          content: 'smoke-body',
        );

        final listedCards = await frb.listCardNotes();
        final poolDetail = await frb.getPoolDetail(
          poolId: pool.id,
          endpointId: 'endpoint-a',
        );
        final initialSync = await frb.syncStatus(networkId: networkId);

        expect(pool.id, isNotEmpty);
        expect(card.id, isNotEmpty);
        expect(listedCards.map((item) => item.id), contains(card.id));
        expect(poolDetail.noteIds, contains(card.id));
        expect(initialSync.state, 'idle');
        expect(initialSync.writeState, 'write_saved');

        await frb.syncConnect(networkId: networkId, target: 'local://peer');
        await frb.syncJoinPool(networkId: networkId, poolId: pool.id);
        final push = await frb.syncPush(networkId: networkId);
        final pull = await frb.syncPull(networkId: networkId);
        final connectedSync = await frb.syncStatus(networkId: networkId);

        expect(push.state, 'ok');
        // Phase 2 契约: 'connected' 映射为 'ready'
        expect(push.syncState, 'ready');
        expect(pull.state, 'ok');
        expect(connectedSync.state, 'connected');
        // Phase 2 契约: syncState 为 'ready' 表示已连接
        expect(connectedSync.syncState, 'ready');

        await frb.syncDisconnect(networkId: networkId);
        final finalSync = await frb.syncStatus(networkId: networkId);
        expect(finalSync.state, 'idle');
      } finally {
        await frb.closePoolNetwork(networkId: networkId);
        await root.delete(recursive: true);
        RustLib.dispose();
      }
    },
  );
}
