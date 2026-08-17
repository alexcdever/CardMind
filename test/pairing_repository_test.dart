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

    final deviceIdA = await repoA.deviceId();
    final addrsA = await repoA.localAddrs();
    expect(addrsA, isNotEmpty, reason: '确认方应至少有一个本地 IPv4 地址');

    // 确认方生成签名凭证并启动广播；发起方只使用凭证入口。
    final display = await repoA.beginPairingCredential();
    expect(display.code, matches(RegExp(r'^\d{6}$')));
    expect(display.credential, startsWith('cm1.'));
    final parsed = await repoB.parsePairingCredential(display.credential);
    expect(parsed.code, display.code);
    expect(parsed.deviceId, deviceIdA);
    expect(parsed.nonce, isNotEmpty);
    expect(parsed.nonce, isNot(matches(RegExp(r'^0+$'))));

    // 确认方 bounded accept 必须在凭证生成后启动。
    final acceptFuture = repoA.acceptPairingRequestWithTimeout(
      const Duration(minutes: 3),
    );

    // 真实 FRB 测试使用凭证字段和确认方 localAddrs，避免 DNS/relay 寻址。
    final connectFuture = repoB.beginPairingConnect(
      display.code,
      PairingTarget(
        deviceId: parsed.deviceId,
        ips: addrsA,
        nonce: parsed.nonce,
      ),
    );

    // 确认方收到请求（含发起方身份）
    final request = await acceptFuture;
    expect(request, isNotNull);
    final received = request!;
    expect(received.deviceId, await repoB.deviceId());
    expect(received.deviceName, 'New Phone');

    // 确认方确认 → 回复握手 + 自动推送全量快照
    final confirmFuture = repoA.confirmPairing(display.code, received);
    final resultB = await connectFuture;

    // 发起方立即接收并导入首次全量同步（与确认方 push 并行，避免 push 超时）
    final pushFuture = repoB.acceptAndImportPush();
    final resultA = await confirmFuture;
    await pushFuture;
    await repoA.stopPairingAdvertising();

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

  // ━━ 任务 M 验收 9：有界确认方等待经真实 FRB 桥的超时路径 ━━
  // 验证 chrono::Duration → Dart Duration 映射 + 超时返回 null（有界、不永久阻塞）。
  test('bounded accept times out through FRB bridge', () async {
    final dirA = await Directory.systemTemp.createTemp('cardmind_pair_tmo_');
    final repoA = await FrbNoteRepository.open(dataDirectory: dirA.path);
    addTearDown(() {
      repoA.close();
      if (dirA.existsSync()) dirA.deleteSync(recursive: true);
    });

    final request = await repoA.acceptPairingRequestWithTimeout(
      const Duration(milliseconds: 100),
    );
    expect(request, isNull, reason: '短时限内无请求应返回 null（有界等待）');
  });
}
