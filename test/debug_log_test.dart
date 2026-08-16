import 'package:cardmind/bridge/debug_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

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
      expect(DebugLogger.redactDeviceId('short-id'), 'short-id',
          reason: '短 id 原样返回');
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
      expect(ev.deviceIds, ['FULLDEVI…89ABCDEF'],
          reason: '事件中的 device id 必须是脱敏形式');
      expect(ev.toLine().contains('FULLDEVICEID0123456789ABCDEF'), isFalse);
    });

    test('sensitive field keys (code/key/secret/token/body/content) are redacted', () {
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
        expect(text.contains(sensitive), isFalse,
            reason: '敏感值 "$sensitive" 不应出现在日志事件中');
      }
      expect(ev.fields['transport'], 'direct',
          reason: '非敏感字段保持原样');
      expect(ev.fields['code'], '[redacted]');
      expect(ev.fields['apiKey'], '[redacted]');
    });

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
      final events = capture.events.map((e) => '${e.event}:${e.fields['action']}');
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

    test('rustlib init failure emits rustlib failed event and rethrows', () async {
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
    });
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
      DebugLogger.instance.event('discovery.mdns', 'discovery.mdns',
          fields: const {'action': 'result'}, verbose: true);
      expect(capture.events, isEmpty, reason: 'verbose=false 时跳过 verbose 事件');

      DebugLogger.instance.verbose = true;
      DebugLogger.instance.event('discovery.mdns', 'discovery.mdns',
          fields: const {'action': 'result'}, verbose: true);
      expect(capture.events, hasLength(1), reason: 'verbose=true 时输出 verbose 事件');
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
      expect(line.contains('FULLDEVICEID0123456789ABCDEF'), isFalse,
          reason: '平台日志行中 device id 必须脱敏');
    });
  });
}
