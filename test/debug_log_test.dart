import 'dart:io';

import 'package:cardmind/bridge/debug_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// debug-log 任务验收测试（Flutter 侧）：
/// 1. debug logger redacts device ids —— 完整 id 只输出脱敏形式；敏感字段被结构性拦截
/// 2. startup emits initialization events —— 启动成功/失败各有可断言事件
/// 9. logger failure does not break flow —— sink 抛异常时事件不抛出、主流程继续
/// 14. platform log capture —— debugPrint 输出格式化单行（Windows 宿主实测）
class CaptureSink implements DebugSink {
  final List<DebugEvent> events = [];

  @override
  void emit(DebugEvent event) => events.add(event);
}

class ThrowingSink implements DebugSink {
  @override
  void emit(DebugEvent event) => throw StateError('sink exploded');
}

void main() {
  late CaptureSink capture;

  setUp(() {
    capture = CaptureSink();
    DebugLogger.instance.setSink(capture);
    DebugLogger.instance.setPlatform('test');
    DebugLogger.instance.verbose = false;
  });

  tearDown(() {
    DebugLogger.instance.resetSink();
    DebugLogger.instance.resetPlatform();
  });

  group('redaction', () {
    test('redacts long device ids to first-8 + last-8', () {
      expect(
        DebugLogger.redactDeviceId(
          'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGH',
        ),
        'abcdefgh…ABCDEFGH',
        reason: '长 device id 只保留前 8 + 后 8，中间省略',
      );
      expect(
        DebugLogger.redactDeviceId('short-id'),
        'short-id',
        reason: '短 id 原样返回',
      );
      expect(
        DebugLogger.redactDeviceId('0123456789ABCDEF'),
        '0123456789ABCDEF',
        reason: '16 字符 id 不超过前 8 + 后 8 窗口',
      );
    });

    test('event() always redacts deviceIds before emit', () {
      DebugLogger.instance.event(
        'pairing.connect',
        'pairing.connect',
        deviceIds: ['FULLDEVICEID0123456789ABCDEF'],
      );
      final ev = capture.events.single;
      expect(ev.deviceIds, [
        'FULLDEVI…89ABCDEF',
      ], reason: '事件中的 device id 必须是脱敏形式');
      expect(ev.toLine().contains('FULLDEVICEID0123456789ABCDEF'), isFalse);
    });

    test(
      'sensitive field keys (code/key/secret/token/body/content) are redacted',
      () {
        DebugLogger.instance.event(
          'pairing.test',
          'pairing',
          deviceIds: ['FULLDEVICEID0123456789ABCDEF'],
          fields: {
            'code': '289260',
            'apiKey': 'sk-live-abc123',
            'secret': 's3cret',
            'token': 'tok-1',
            'body': 'TOP-SECRET-NOTE-BODY',
            'content': 'PRIVATE-CONTENT',
            'transport': 'direct',
          },
        );
        final ev = capture.events.single;
        final text = '${ev.toLine()} ${ev.toString()}';
        for (final sensitive in [
          '289260',
          'sk-live-abc123',
          's3cret',
          'tok-1',
          'TOP-SECRET-NOTE-BODY',
          'PRIVATE-CONTENT',
        ]) {
          expect(
            text.contains(sensitive),
            isFalse,
            reason: '敏感值 "$sensitive" 不应出现在日志事件中',
          );
        }
        expect(ev.fields['transport'], 'direct', reason: '非敏感字段保持原样');
        expect(ev.fields['code'], '[redacted]');
        expect(ev.fields['apiKey'], '[redacted]');
      },
    );

    test('events carry timestamp/platform/event/stage fields', () {
      DebugLogger.instance.setPlatform('android');
      DebugLogger.instance.event('relay.config', 'sync.init');
      final ev = capture.events.single;
      expect(ev.event, 'relay.config');
      expect(ev.stage, 'sync.init');
      expect(ev.platform, 'android');
      expect(ev.timestamp, isNotNull);
    });
  });

  group('startup events', () {
    test('startup success emits rustlib and bridge success events', () async {
      await initializeBackendWithLogging(
        rustInit: () async {},
        bridgeInit: () async {},
        log: DebugLogger.instance,
      );
      final events = capture.events.map(
        (e) => '${e.event}:${e.fields['action']}',
      );
      expect(events, contains('startup.rustlib:start'));
      expect(events, contains('startup.rustlib:success'));
      expect(events, contains('startup.bridge:start'));
      expect(events, contains('startup.bridge:success'));
    });

    test('startup failure emits failed event and rethrows', () async {
      await expectLater(
        initializeBackendWithLogging(
          rustInit: () async {},
          bridgeInit: () async => throw StateError('bridge exploded'),
          log: DebugLogger.instance,
        ),
        throwsStateError,
      );
      final events = capture.events;
      final failed = events.firstWhere(
        (e) => e.event == 'startup.bridge' && e.fields['action'] == 'failed',
      );
      expect(failed.error, 'StateError');
      expect(failed.errorChain, contains('bridge exploded'));
    });

    test(
      'rustlib init failure emits rustlib failed event and rethrows',
      () async {
        await expectLater(
          initializeBackendWithLogging(
            rustInit: () async => throw Exception('rust dylib missing'),
            bridgeInit: () async {},
            log: DebugLogger.instance,
          ),
          throwsException,
        );
        final failed = capture.events.firstWhere(
          (e) => e.event == 'startup.rustlib' && e.fields['action'] == 'failed',
        );
        expect(failed.errorChain, contains('rust dylib missing'));
      },
    );
  });

  group('logger failure resilience', () {
    test('throwing sink does not propagate from event()', () {
      DebugLogger.instance.setSink(ThrowingSink());
      expect(
        () => DebugLogger.instance.event('startup.sync_service', 'sync.init'),
        returnsNormally,
        reason: '日志 sink 抛异常不应影响主流程',
      );
    });

    test('verbose events are skipped unless verbose flag is on', () {
      DebugLogger.instance.verbose = false;
      DebugLogger.instance.event(
        'discovery.mdns',
        'discovery.mdns',
        fields: const {'action': 'result'},
        verbose: true,
      );
      expect(capture.events, isEmpty, reason: 'verbose=false 时跳过 verbose 事件');

      DebugLogger.instance.verbose = true;
      DebugLogger.instance.event(
        'discovery.mdns',
        'discovery.mdns',
        fields: const {'action': 'result'},
        verbose: true,
      );
      expect(
        capture.events,
        hasLength(1),
        reason: 'verbose=true 时输出 verbose 事件',
      );
    });
  });

  group('platform log capture', () {
    test('default sink emits formatted line via debugPrint (Windows host)', () {
      final lines = <String>[];
      final previous = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) lines.add(message);
      };
      addTearDown(() => debugPrint = previous);

      DebugLogger.instance.resetSink(); // 恢复默认 PlatformDebugSink → debugPrint
      DebugLogger.instance.setPlatform('windows');
      DebugLogger.instance.event(
        'pairing.connect',
        'pairing.connect',
        deviceIds: ['FULLDEVICEID0123456789ABCDEF'],
        duration: const Duration(milliseconds: 42),
        fields: const {'transport': 'direct', 'action': 'success'},
      );

      expect(lines, isNotEmpty, reason: '默认 sink 应输出到 debugPrint（平台日志通道）');
      final line = lines.single;
      expect(line, startsWith('[cardmind:log] '));
      expect(line, contains('platform=windows'));
      expect(line, contains('event=pairing.connect'));
      expect(line, contains('stage=pairing.connect'));
      expect(line, contains('ids=[FULLDEVI…89ABCDEF]'));
      expect(line, contains('duration_ms=42'));
      expect(line, contains('transport=direct'));
      expect(
        line.contains('FULLDEVICEID0123456789ABCDEF'),
        isFalse,
        reason: '平台日志行中 device id 必须脱敏',
      );
    });
  });

  group('log directory resolution', () {
    late Directory tempBase;

    setUp(() async {
      tempBase = await Directory.systemTemp.createTemp('cardmind-logdir-');
    });

    tearDown(() async {
      if (tempBase.existsSync()) await tempBase.delete(recursive: true);
    });

    test('A1: resolveLogDirectory uses the injected base directory', () async {
      final resolved = await resolveLogDirectory(baseDirectory: tempBase.path);

      expect(
        resolved.path,
        p.join(tempBase.path, 'logs'),
        reason: '日志目录必须是 <base>/logs，且不触碰真实 getApplicationSupportDirectory',
      );
      expect(
        resolved.path.startsWith(tempBase.path),
        isTrue,
        reason: '解析结果必须完全落在注入的临时目录内',
      );
    });

    test('A2: FileDebugSink.open writes under resolveLogDirectory', () async {
      final resolved = await resolveLogDirectory(baseDirectory: tempBase.path);
      final sink = await FileDebugSink.open(
        baseDirectory: tempBase.path,
        maxBytes: 1024,
      );

      expect(sink, isNotNull, reason: '临时目录可写，sink 必须打开成功');
      sink!.emit(
        DebugEvent(
          timestamp: DateTime.utc(2026),
          platform: 'test',
          event: 'log.dir',
          stage: 'log.dir',
        ),
      );
      await sink.flush();

      expect(File(sink.path).existsSync(), isTrue, reason: '写入后日志文件必须真实存在');
      expect(
        p.isWithin(resolved.path, sink.path),
        isTrue,
        reason:
            'FileDebugSink.open 的落盘路径必须位于 resolveLogDirectory 返回目录之下'
            '（两处目录推导不得漂移）',
      );
      expect(
        p.dirname(sink.path),
        resolved.path,
        reason: '日志文件必须直接位于解析出的日志目录内',
      );
    });
  });

  group('revealLogDirectory', () {
    late Directory tempBase;

    setUp(() async {
      tempBase = await Directory.systemTemp.createTemp('cardmind-reveal-');
    });

    tearDown(() async {
      if (tempBase.existsSync()) await tempBase.delete(recursive: true);
    });

    test(
      'returns the resolved path and calls the injected opener once',
      () async {
        var openCount = 0;
        String? openedWith;

        final path = await revealLogDirectory(
          baseDirectory: tempBase.path,
          opener: (directory) async {
            openCount++;
            openedWith = directory;
          },
        );

        expect(path, p.join(tempBase.path, 'logs'));
        expect(openCount, 1, reason: '注入的 opener 必须被调用且恰好一次');
        expect(openedWith, path, reason: 'opener 收到的必须是解析出的实际路径');
      },
    );

    test(
      'opener failure is swallowed but the path is still returned',
      () async {
        final path = await revealLogDirectory(
          baseDirectory: tempBase.path,
          opener: (_) async => throw const ProcessException('open', <String>[]),
        );

        expect(
          path,
          p.join(tempBase.path, 'logs'),
          reason: '打开失败不得抛异常到调用方，且仍返回路径供 UI 展示',
        );
      },
    );

    test(
      'resolver failure degrades to an empty path without throwing',
      () async {
        final path = await revealLogDirectory(
          resolver: ({String? baseDirectory}) async =>
              throw StateError('no app support dir'),
          opener: (_) async => fail('解析失败时不应调用 opener'),
        );

        expect(path, '', reason: '解析彻底失败时返回空串，绝不抛出');
      },
    );
  });
}
