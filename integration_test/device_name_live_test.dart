import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

import 'support/test_harness.dart';

/// 设备名端到端实机验证：真实 FRB + 真实 Rust 后端 + 真实磁盘。
///
/// 覆盖「改名 → 落盘 → 重启读取」完整链路，全部经 FrbNoteRepository
/// （真 Rust `set_device_name_and_notify` / `SyncService::new_persistent`），
/// 不是 fake/mock。
///
/// 运行：flutter test integration_test/device_name_live_test.dart -d macos --timeout 3m
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initializeFrb);
  tearDownAll(disposeFrb);

  testWidgets('改名落盘并在重启后仍读到新名（真实 Rust 后端）', (tester) async {
    final harness = CardMindIntegrationHarness();
    final dir = await harness.createDataDirectory();

    // 1. 首次打开：默认名来自主机名，不应为空，且 device_name.txt 尚未生成
    final first = await harness.openRepository(dataDirectory: dir);
    final defaultName = await first.deviceName();
    expect(defaultName, isNotEmpty, reason: '默认设备名不应为空');
    expect(
      File(p.join(dir, 'device_name.txt')).existsSync(),
      isFalse,
      reason: '未改名时不应预先落盘 device_name.txt',
    );

    // 2. 改名：真实写入 Rust 内存态 + 落盘
    const newName = 'Alexc-MBA-实机验证';
    await first.setDeviceName(newName);
    expect(await first.deviceName(), newName, reason: '内存态应立即返回新名');
    await harness.closeRepository(first);

    // 3. 磁盘证据：device_name.txt 内容就是新名
    final nameFile = File(p.join(dir, 'device_name.txt'));
    expect(nameFile.existsSync(), isTrue, reason: '改名后必须落盘 device_name.txt');
    expect(nameFile.readAsStringSync().trim(), newName);

    // 4. 重启：同一数据目录重新打开，读到的仍是新名（而非退回默认主机名）
    final reopened = await harness.openRepository(dataDirectory: dir);
    expect(
      await reopened.deviceName(),
      newName,
      reason: '重启后应从 device_name.txt 恢复，而不是回到主机名',
    );

    await harness.dispose();
  });

  testWidgets('两个隔离数据目录的实例互不干扰（模拟双设备）', (tester) async {
    final harness = CardMindIntegrationHarness();
    final dirA = await harness.createDataDirectory();
    final dirB = await harness.createDataDirectory();

    final a = await harness.openRepository(dataDirectory: dirA);
    final b = await harness.openRepository(dataDirectory: dirB);

    // 各自身份独立
    expect(await a.deviceId(), isNot(await b.deviceId()));

    await a.setDeviceName('设备甲');
    await b.setDeviceName('设备乙');

    // 各自读到自己的名字，未串扰
    expect(await a.deviceName(), '设备甲');
    expect(await b.deviceName(), '设备乙');

    // 两目录各自的 device_name.txt 独立
    expect(
      File(p.join(dirA, 'device_name.txt')).readAsStringSync().trim(),
      '设备甲',
    );
    expect(
      File(p.join(dirB, 'device_name.txt')).readAsStringSync().trim(),
      '设备乙',
    );

    await harness.dispose();
  });
}