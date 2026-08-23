import 'dart:io';

import 'package:cardmind/bridge/debug_log.dart';
import 'package:flutter_test/flutter_test.dart';

/// 任务 U7 验收测试（Windows 文件日志，Flutter 侧）：
///
/// 1. file sink writes event lines —— FileDebugSink 写入指定目录，
///    读回内容包含 `[cardmind:log]` 结构化事件行（复用 DebugEvent.toLine 格式）
/// 2. open failure degrades silently —— 打开失败返回 null、不抛异常
///    （主流程静默退化为仅 debugPrint）
/// 3. FLUTTER_TEST init writes nothing —— flutter test 环境下
///    initializeFileLogging 不挂载任何文件 sink（测试不落盘）
/// 4. oversized log truncated at startup keeping second half —— 启动时超过
///    上限按行对齐保留后半部分（最近会话日志可查）

DebugEvent _event(String event, {Map<String, String> fields = const {}}) {
  return DebugEvent(
    timestamp: DateTime.now().toUtc(),
    platform: 'test',
    event: event,
    stage: 'file.sink',
    fields: fields,
  );
}

class _CollectingSink implements DebugSink {
  _CollectingSink(this.lines);

  final List<String> lines;

  @override
  void emit(DebugEvent event) => lines.add(event.toLine());
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cardmind_log_test');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    DebugLogger.instance.setPlatform('test');
    DebugLogger.instance.detachExtraSinks();
    addTearDown(DebugLogger.instance.detachExtraSinks);
  });

  group('FileDebugSink', () {
    test('writes event lines to log file in provided directory', () async {
      final sink = await FileDebugSink.open(baseDirectory: tempDir.path);
      expect(sink, isNotNull, reason: '正常目录下应成功打开文件 sink');
      addTearDown(sink!.flush);

      sink.emit(_event('pairing.accept', fields: const {'action': 'start'}));
      sink.emit(
        _event('pairing.confirm', fields: const {'action': 'success'}),
      );
      await sink.flush();

      final logFile = File('${tempDir.path}/logs/cardmind.log');
      expect(logFile.existsSync(), isTrue, reason: '日志文件应落在 logs/ 子目录');
      final content = logFile.readAsStringSync();
      expect(content, contains('[cardmind:log] '));
      expect(content, contains('platform=test'));
      expect(content, contains('event=pairing.accept'));
      expect(content, contains('stage=file.sink'));
      expect(content, contains('action=start'));
      // 追加写：两条事件各占一行
      expect(
        content
            .split('\n')
            .where((l) => l.startsWith('[cardmind:log]')),
        hasLength(2),
      );
    });

    test('returns null instead of throwing when open fails', () async {
      // 在"目录"位置放一个普通文件 → 在其下创建 logs/ 必然失败
      final blocker = File('${tempDir.path}/blocker.txt');
      blocker.writeAsStringSync('not a directory');

      expect(
        () => FileDebugSink.open(baseDirectory: blocker.path),
        returnsNormally,
        reason: '打开失败不得向调用方抛异常',
      );
      expect(
        await FileDebugSink.open(baseDirectory: blocker.path),
        isNull,
        reason: '打开失败应静默返回 null（退化为仅 debugPrint）',
      );
    });

    test('truncates oversized log keeping second half line-aligned', () async {
      const maxBytes = 256;
      final logsDir = Directory('${tempDir.path}/logs');
      logsDir.createSync(recursive: true);
      final logFile = File('${logsDir.path}/cardmind.log');
      // 写入 20 行，每行约 40+ 字节（总量 ~900B > 256B 上限）
      final buffer = StringBuffer();
      for (var i = 1; i <= 20; i++) {
        buffer.writeln(
          '[cardmind:log] 2026-08-22T00:00:${i.toString().padLeft(2, '0')}Z '
          'platform=windows event=line.$i stage=t',
        );
      }
      logFile.writeAsStringSync(buffer.toString());
      expect(logFile.lengthSync(), greaterThan(maxBytes));

      final sink = await FileDebugSink.open(
        baseDirectory: tempDir.path,
        maxBytes: maxBytes,
      );
      expect(sink, isNotNull);
      addTearDown(sink!.flush);

      final after = logFile.readAsStringSync();
      expect(after.length, lessThanOrEqualTo(maxBytes),
          reason: '截断后不得超过上限');
      expect(after, contains('event=line.20'), reason: '最近的行必须保留');
      expect(after, isNot(contains(':01Z platform')), reason: '最早的行应被丢弃');
      expect(after.startsWith('[cardmind:log] '), isTrue,
          reason: '保留部分必须从完整行开始（按行对齐）');

      // 截断后仍可继续追加写
      sink.emit(_event('after.truncate'));
      await sink.flush();
      expect(logFile.readAsStringSync(), contains('event=after.truncate'));
    });
  });

  group('initializeFileLogging', () {
    test('attaches nothing under FLUTTER_TEST (no disk writes)', () async {
      // flutter test 环境自带 FLUTTER_TEST 环境变量；守卫应在打开任何文件前返回
      await initializeFileLogging(log: DebugLogger.instance);
      expect(
        DebugLogger.instance.extraSinkCount,
        0,
        reason: '测试环境下 initializeFileLogging 不得挂载文件 sink',
      );
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('attached extra sink receives emitted events (fan-out)', () async {
      // 用内存 sink 模拟 attach 通道本身的行为（不依赖磁盘环境）
      final lines = <String>[];
      DebugLogger.instance.attachSink(_CollectingSink(lines));
      DebugLogger.instance.event('fan.out.check', 'file.sink');
      expect(lines, hasLength(1), reason: '附加 sink 应与主 sink 并行收到事件');
      expect(lines.single, contains('event=fan.out.check'));
    });
  });
}
