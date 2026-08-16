import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

/// 结构化、脱敏的调试日志（Flutter 侧；对应 Rust `debug_log` 模块）。
///
/// 设计原则：
/// - 每条事件至少包含：时间戳、平台（Windows/Android）、事件名、当前阶段、
///   脱敏 device id（只允许前 8 + 后 8）、错误类型与错误链、耗时。
/// - 可测试 sink：默认输出到 `debugPrint`（平台调试日志：Android logcat /
///   Windows debug 输出）；测试注入 `CaptureSink` 断言事件，不依赖控制台文本。
/// - 脱敏保证：`deviceIds` 一律经 [DebugLogger.redactDeviceId]；字段键名命中的
///   敏感模式（code/key/secret/token/body/content）值被替换为 `[redacted]`。
/// - 健壮性：sink 抛异常被吞掉——日志失败绝不影响配对/同步主流程。
/// - debug 开关：`verbose` 事件默认不输出，打开 `DebugLogger.verbose` 后输出。

/// 一条结构化、已脱敏的日志事件（与 Rust `LogEvent` 对齐）。
class DebugEvent {
  const DebugEvent({
    required this.timestamp,
    required this.platform,
    required this.event,
    required this.stage,
    this.deviceIds = const [],
    this.error,
    this.errorChain,
    this.durationMs,
    this.fields = const {},
    this.verbose = false,
  });

  /// RFC3339 时间戳（UTC）。
  final DateTime timestamp;
  /// 平台（"windows" / "android" / "linux" / "test" ...）。
  final String platform;
  /// 事件名（如 "relay.config"、"sync.push"）。
  final String event;
  /// 当前阶段（如 "sync.init"、"pairing.accept"）。
  final String stage;
  /// 已脱敏的 device id 列表（只允许前 8 + 后 8）。
  final List<String> deviceIds;
  /// 错误类型与消息（成功事件为 null）。
  final String? error;
  /// 完整错误链（`toString()`；成功事件为 null）。
  final String? errorChain;
  /// 耗时（毫秒）。
  final int? durationMs;
  /// 额外安全字段（count/direction/transport 等）。
  final Map<String, String> fields;
  /// verbose 级事件：默认不输出。
  final bool verbose;

  /// 单行人类可读格式（与 Rust `format_line` 对齐）。
  String toLine() {
    final b = StringBuffer()
      ..write('[cardmind:log] ')
      ..write(timestamp.toIso8601String())
      ..write(' platform=$platform')
      ..write(' event=$event')
      ..write(' stage=$stage');
    if (deviceIds.isNotEmpty) b.write(' ids=[${deviceIds.join(',')}]');
    if (error != null) b.write(' error=$error');
    if (errorChain != null) b.write(' chain=$errorChain');
    if (durationMs != null) b.write(' duration_ms=$durationMs');
    for (final entry in fields.entries) {
      b.write(' ${entry.key}=${entry.value}');
    }
    return b.toString();
  }
}

/// 可测试的日志 sink：测试注入收集 sink 断言事件，不依赖控制台文本。
abstract interface class DebugSink {
  void emit(DebugEvent event);
}

/// 默认 sink：输出到 `debugPrint`（Flutter 平台调试日志）。
class PlatformDebugSink implements DebugSink {
  @override
  void emit(DebugEvent event) {
    debugPrint(event.toLine());
  }
}

/// 日志门面（应用单例；测试可注入 sink 断言事件）。
class DebugLogger {
  DebugLogger({DebugSink? sink, String? platform})
      : _injectedSink = sink,
        _injectedPlatform = platform;

  /// 应用单例。
  static final DebugLogger instance = DebugLogger();

  DebugSink? _injectedSink;
  DebugSink? _fallbackSink;
  String? _injectedPlatform;

  /// verbose 开关：true 时输出 verbose 级事件（debug 提高详细程度）。
  bool verbose = false;

  /// 当前平台（测试可注入覆盖）。
  String get platform => _injectedPlatform ?? _defaultPlatform();

  /// 测试钩子：注入 sink。
  @visibleForTesting
  void setSink(DebugSink sink) => _injectedSink = sink;

  /// 测试钩子：恢复默认 sink。
  @visibleForTesting
  void resetSink() => _injectedSink = null;

  /// 测试钩子：注入平台标识。
  @visibleForTesting
  void setPlatform(String platform) => _injectedPlatform = platform;

  /// 测试钩子：恢复默认平台探测。
  @visibleForTesting
  void resetPlatform() => _injectedPlatform = null;

  static String _defaultPlatform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isIOS) return 'ios';
    return 'test';
  }

  /// 脱敏 device id：只保留前 8 + 后 8 字符，中间省略。
  /// 短 id（≤ 16 字符）原样返回——整体不超过"前 8 + 后 8"窗口。
  static String redactDeviceId(String id) {
    if (id.length <= 16) return id;
    return '${id.substring(0, 8)}…${id.substring(id.length - 8)}';
  }

  DebugSink get _sink => _injectedSink ?? (_fallbackSink ??= PlatformDebugSink());

  /// 输出一条事件；sink 抛异常被吞掉（日志失败不影响主流程）。
  void emit(DebugEvent event) {
    if (event.verbose && !verbose) return;
    try {
      _sink.emit(event);
    } catch (_) {
      // 日志失败不影响配对/同步主流程
    }
  }

  /// 便捷构造并输出事件：device id 自动脱敏，敏感字段键值自动打码。
  void event(
    String event,
    String stage, {
    List<String> deviceIds = const [],
    String? error,
    String? errorChain,
    Duration? duration,
    Map<String, String> fields = const {},
    bool verbose = false,
  }) {
    emit(
      DebugEvent(
        timestamp: DateTime.now().toUtc(),
        platform: platform,
        event: event,
        stage: stage,
        deviceIds: deviceIds.map(redactDeviceId).toList(),
        error: error,
        errorChain: errorChain,
        durationMs: duration?.inMilliseconds,
        fields: _sanitizeFields(fields),
        verbose: verbose,
      ),
    );
  }

  /// 防御性打码：键名命中敏感模式（code/key/secret/token/body/content）的值
  /// 替换为 `[redacted]`——配对码、API key、笔记正文绝不被日志记录。
  static Map<String, String> _sanitizeFields(Map<String, String> fields) {
    const sensitiveKey = [
      'code',
      'key',
      'secret',
      'token',
      'password',
      'passwd',
      'body',
      'content',
    ];
    if (fields.isEmpty) return fields;
    final result = <String, String>{};
    fields.forEach((k, v) {
      final lower = k.toLowerCase();
      final sensitive = sensitiveKey.any((s) => lower.contains(s));
      result[k] = sensitive ? '[redacted]' : v;
    });
    return result;
  }
}

/// 带日志的后端初始化（RustLib.init + BridgeHelper.init 包装）。
///
/// 启动成功/失败各有可断言事件（验收 2）；测试用 fake 注入，无需真实 FRB。
Future<void> initializeBackendWithLogging({
  required Future<void> Function() rustInit,
  required Future<void> Function() bridgeInit,
  required DebugLogger log,
}) async {
  log.event('startup.rustlib', 'startup', fields: const {'action': 'start'});
  try {
    await rustInit();
    log.event('startup.rustlib', 'startup', fields: const {'action': 'success'});
  } catch (e) {
    log.event(
      'startup.rustlib',
      'startup',
      fields: const {'action': 'failed'},
      error: e.runtimeType.toString(),
      errorChain: e.toString(),
    );
    rethrow;
  }
  log.event('startup.bridge', 'startup', fields: const {'action': 'start'});
  try {
    await bridgeInit();
    log.event('startup.bridge', 'startup', fields: const {'action': 'success'});
  } catch (e) {
    log.event(
      'startup.bridge',
      'startup',
      fields: const {'action': 'failed'},
      error: e.runtimeType.toString(),
      errorChain: e.toString(),
    );
    rethrow;
  }
}
