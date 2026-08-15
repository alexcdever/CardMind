import 'dart:io';

import 'package:cardmind/bridge/frb_note_repository.dart';
import 'package:cardmind/src/rust/frb_generated.dart';
import 'package:cardmind/src/rust/sync.dart';
import 'package:flutter_test/flutter_test.dart';

/// 任务 G 验收 7：repository pair flow — repository 层封装配对 API 调用链正确。
///
/// 真实 FRB：两个隔离数据目录的 FrbNoteRepository 在同一进程内完成
/// 确认方（生成码 + 接收请求 + 确认）与发起方（连接 + 握手 + 首次全量同步）全链路。
void main() {
  setUpAll(RustLib.init);

  test('repository pair flow pairs two devices and syncs notes', () async {
    final dirA = await Directory.systemTemp.createTemp('cardmind_pair_a_');
    final dirB = await Directory.systemTemp.createTemp('cardmind_pair_b_');
    final repoA = await FrbNoteRepository.open(dataDirectory: dirA.path);
    final repoB = await FrbNoteRepository.open(dataDirectory: dirB.path);
    addTearDown(() {
      repoA.close();
      repoB.close();
      if (dirA.existsSync()) dirA.deleteSync(recursive: true);
      if (dirB.existsSync()) dirB.deleteSync(recursive: true);
    });

    // ━━ 确认方（已信任设备）：命名 + 已有笔记；发起方（新设备）：命名 ━━
    await repoA.setDeviceName('Trusted PC');
    await repoA.createNote('seed', '# Seed\n\nhello from A');
    await repoB.setDeviceName('New Phone');

    // 发起方需要确认方地址（真实场景由 mDNS 发现提供）；在 accept 阻塞前取好
    final deviceIdA = await repoA.deviceId();
    final addrsA = await repoA.localAddrs();
    expect(addrsA, isNotEmpty, reason: '确认方应至少有一个本地 IPv4 地址');

    // 确认方生成 6 位数字配对码
    final code = await repoA.beginPairingAccept();
    expect(code, matches(RegExp(r'^\d{6}$')));

    // 确认方阻塞接收发起方请求（发起方连接前启动）
    final acceptFuture = repoA.acceptPairingRequest();

    // 发起方连接确认方：发送请求 → 等待握手响应
    final connectFuture = repoB.beginPairingConnect(
      code,
      PairingTarget(deviceId: deviceIdA, ips: addrsA),
    );

    // 确认方收到请求（含发起方身份）
    final request = await acceptFuture;
    expect(request.deviceId, await repoB.deviceId());
    expect(request.deviceName, 'New Phone');

    // 确认方确认 → 回复握手 + 自动推送全量快照
    final confirmFuture = repoA.confirmPairing(code, request);
    final resultB = await connectFuture;

    // 发起方立即接收并导入首次全量同步（与确认方 push 并行，避免 push 超时）
    final pushFuture = repoB.acceptAndImportPush();
    final resultA = await confirmFuture;
    await pushFuture;

    // ━━ 双方身份交换一致 ━━
    expect(resultA.peerId, await repoB.deviceId());
    expect(resultA.peerName, 'New Phone');
    expect(resultB.peerId, deviceIdA);
    expect(resultB.peerName, 'Trusted PC');

    // ━━ 双方持久化配对 ━━
    final pairedA = await repoA.listPairedDevices();
    expect(pairedA.map((d) => d.peerId), contains(await repoB.deviceId()));
    final pairedB = await repoB.listPairedDevices();
    expect(pairedB.map((d) => d.peerId), contains(deviceIdA));

    // ━━ 决策 8：首次配对自动全量同步 → 发起方可见确认方笔记 ━━
    expect(await repoB.getNote('seed'), '# Seed\n\nhello from A');

    // ━━ 解除配对 ━━
    await repoA.removePairedDevice(await repoB.deviceId());
    expect(
      (await repoA.listPairedDevices()).map((d) => d.peerId),
      isNot(contains(await repoB.deviceId())),
    );
  });
}
