import 'dart:io';

import 'package:cardmind/bridge/debug_log.dart';
import 'package:cardmind/bridge/frb_note_repository.dart';
import 'package:cardmind/src/rust/frb_generated.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// 验收 14：Windows / Android 平台日志采集验证（明确覆盖范围见报告）。
///
/// Windows：本测试在 Windows 宿主加载真实 Rust dylib（`RustLib.init` →
/// 真实 SyncService 启动事件经 PlatformSink 输出），并通过 DebugLogger 默认
/// `debugPrint` 通道（Windows 调试日志 / Android logcat 的共用 Flutter 通道）
/// 验证格式化单行输出与真实 device id 脱敏。
///
/// Android：同一测试在 Android 模拟器/真机执行时，`Platform.isAndroid` 分支
/// 生效（platform 字段为 'android'）。本环境无模拟器，Android 分支为已编写、
/// 未在此环境执行——覆盖范围在 executor-report 中如实说明。
void main() {
  setUpAll(() async {
    await RustLib.init();
  });

  test('real Rust backend emits safe logs via default platform sink', () async {
    // 捕获 debugPrint（Flutter 平台日志通道：Windows 调试输出 / Android logcat）
    final lines = <String>[];
    final previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) lines.add(message);
    };
    addTearDown(() => debugPrint = previous);

    // 真实 FRB：打开持久化 SyncService → Rust 侧启动事件经 PlatformSink（stderr）
    final dir = await Directory.systemTemp.createTemp('cardmind_platform_log_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final repo = await FrbNoteRepository.open(dataDirectory: dir.path);
    addTearDown(repo.close);

    final realId = await repo.deviceId();
    expect(realId.length, greaterThan(16), reason: '真实 iroh device id 应为长 id');
    expect(repo, isNotNull, reason: '真实 FRB 后端应在宿主平台初始化成功');

    // DebugLogger 默认 sink（PlatformDebugSink → debugPrint）
    DebugLogger.instance.resetSink();
    DebugLogger.instance.event(
      'identity.device_id',
      'identity',
      deviceIds: [realId],
    );

    expect(lines, isNotEmpty, reason: '默认 sink 应输出到 debugPrint（平台日志通道）');
    final line = lines.last;
    expect(line, startsWith('[cardmind:log] '), reason: '平台日志行为格式化单行');
    expect(line, contains('event=identity.device_id'));
    expect(line, contains('stage=identity'));
    expect(line, contains('ids=['), reason: '日志行应含脱敏 device id 列表');
    expect(line.contains(realId), isFalse, reason: '真实完整 device id 不得出现在平台日志中');
    expect(
      line,
      contains(DebugLogger.redactDeviceId(realId)),
      reason: '日志行应含真实 device id 的 8+8 脱敏形式',
    );

    // 平台字段：Windows 宿主 → windows；Android → android（平台日志采集验证）
    if (Platform.isAndroid) {
      expect(
        DebugLogger.instance.platform,
        'android',
        reason: 'Android 上日志 platform 字段应为 android（logcat 采集）',
      );
    } else if (Platform.isWindows) {
      expect(
        DebugLogger.instance.platform,
        'windows',
        reason: 'Windows 上日志 platform 字段应为 windows',
      );
    }
  });
}
