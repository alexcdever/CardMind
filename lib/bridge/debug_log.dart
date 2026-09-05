import 'dart:io' show Directory, File, FileMode, Platform;

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:path_provider/path_provider.dart';

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

/// 单个日志文件大小上限；启动时超过则截断（任务 U7 设计契约 B.1）。
const int maxLogFileBytes = 5 * 1024 * 1024;

/// 文件日志 sink（任务 U7）：追加写 `<base>/logs/cardmind.log`，每事件一行。
///
/// - 行格式复用 [DebugEvent.toLine]（与 debugPrint 输出一致，带时间戳）；
/// - 打开失败（权限/磁盘）由 [FileDebugSink.open] 返回 null 表达——调用方
///   静默退化为仅 debugPrint，不影响主流程；运行期写失败在串行队列内吞掉；
/// - 启动时若文件超过上限则截断：**保留后半部分**（按行对齐）——重启正是
///   最常查日志的时机，丢前半段保住最近一次会话的记录更利于报障定位；
/// - flush 策略：逐条直写（事件量低频），内部仅用串行 Future 队列保证
///   落盘顺序与事件顺序一致，不做批量缓冲。
class FileDebugSink implements DebugSink {
  FileDebugSink._(this._file, this._maxBytes);

  final File _file;

  /// 截断上限（字节）；open 时用于判断是否需要截断，保留供诊断与测试。
  // ignore: unused_field
  final int _maxBytes;

  /// 串行化写入队列：保证追加写顺序与事件顺序一致；单条失败不破坏队列。
  Future<void> _queue = Future<void>.value();

  /// 日志文件完整路径（诊断用）。
  String get path => _file.path;

  /// 打开文件日志 sink；任何一步失败返回 null（静默退化，绝不抛出）。
  ///
  /// [baseDirectory] 缺省用 `getApplicationSupportDirectory()`（Windows 实际
  /// 为 `%APPDATA%\com.cardmind\cardmind`；Android 为 app-private 目录），
  /// 日志写入其下 `logs/cardmind.log`。测试可显式传临时目录并调小 [maxBytes]。
  ///
  /// FLUTTER_TEST 守卫不在本方法——位于 [initializeFileLogging]，这样测试
  /// 可以直接构造 sink 到临时目录验证写盘行为本身。
  static Future<FileDebugSink?> open({
    String? baseDirectory,
    int maxBytes = maxLogFileBytes,
  }) async {
    try {
      final Directory base = baseDirectory != null
          ? Directory(baseDirectory)
          : await getApplicationSupportDirectory();
      final logsDir = Directory('${base.path}${Platform.pathSeparator}logs');
      await logsDir.create(recursive: true);
      final file = File('${logsDir.path}${Platform.pathSeparator}cardmind.log');
      await _truncateIfNeeded(file, maxBytes);
      // 探测性打开：权限不足在这里暴露而不是首条 emit 时
      final probe = await file.open(mode: FileMode.append);
      await probe.close();
      return FileDebugSink._(file, maxBytes);
    } catch (_) {
      return null;
    }
  }

  @override
  void emit(DebugEvent event) {
    final line = '${event.toLine()}\n';
    _queue = _queue.then((_) async {
      try {
        await _file.writeAsString(line, mode: FileMode.append, flush: true);
      } catch (_) {
        // 写失败静默：日志绝不影响配对/同步主流程
      }
    });
  }

  /// 等待挂起写入全部落盘（测试断言用）。
  @visibleForTesting
  Future<void> flush() => _queue;

  /// 启动截断：超过 [maxBytes] 时保留文件末尾至多 [maxBytes] 字节的完整行
  /// （丢弃开头），保证截断后不超过上限且最近的日志仍在。
  ///
  /// 分两步（read 关闭后 writeAsBytes 重建）：Windows 上同一句柄先读后
  /// truncate 会报拒绝访问（errno=5）。文件 ≤ 上限的常态路径零开销。
  static Future<void> _truncateIfNeeded(File file, int maxBytes) async {
    // 首次启动文件尚不存在：exists() 为 false，直接跳过（length() 会抛错）
    if (!await file.exists()) return;
    final length = await file.length();
    if (length <= maxBytes) return;
    final raf = await file.open();
    List<int> tail;
    try {
      await raf.setPosition(length - maxBytes);
      tail = await raf.read(maxBytes);
    } finally {
      await raf.close();
    }
    var start = 0;
    while (start < tail.length && tail[start] != 0x0A) {
      start++;
    }
    start++; // 跳过被切断的半行，从下一个完整行起保留
    final keep = start < tail.length ? tail.sublist(start) : <int>[];
    // FileMode.write 打开即截断重建，等价"清空后写回保留部分"
    await file.writeAsBytes(keep, mode: FileMode.write);
  }
}

/// 应用启动时挂载文件日志（main.dart 调用一次；任务 U7 设计契约 B.2/B.3）。
///
/// 测试环境机制：`FLUTTER_TEST` 环境变量守卫——flutter test 下直接跳过，
/// 不打开任何文件、不挂载 sink（widget 测试不得落盘）。生产环境打开失败
/// （权限/磁盘）静默退化：不 attach，日志仍走 debugPrint。fire-and-forget，
/// 不阻塞应用启动。
Future<void> initializeFileLogging({DebugLogger? log}) async {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return;
  final sink = await FileDebugSink.open();
  if (sink != null) {
    (log ?? DebugLogger.instance).attachSink(sink);
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

  /// 附加持久 sink（如 [FileDebugSink]）；与主 sink 并行输出，互不阻塞。
  final List<DebugSink> _extraSinks = <DebugSink>[];

  /// verbose 开关：true 时输出 verbose 级事件（debug 提高详细程度）。
  bool verbose = false;

  /// 当前平台（测试可注入覆盖）。
  String get platform => _injectedPlatform ?? _defaultPlatform();

  /// 挂载附加持久 sink（应用启动时由 [initializeFileLogging] 调用一次）。
  /// 单侧失败互不影响（emit 内部逐个吞异常）。
  void attachSink(DebugSink sink) => _extraSinks.add(sink);

  /// 测试钩子：卸载全部附加 sink。
  @visibleForTesting
  void detachExtraSinks() => _extraSinks.clear();

  /// 测试钩子：当前附加 sink 数量。
  @visibleForTesting
  int get extraSinkCount => _extraSinks.length;

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

  DebugSink get _sink =>
      _injectedSink ?? (_fallbackSink ??= PlatformDebugSink());

  /// 输出一条事件；主 sink 与附加 sink 逐个输出，任一抛异常都被吞掉
  /// （日志失败不影响配对/同步主流程）。
  void emit(DebugEvent event) {
    if (event.verbose && !verbose) return;
    try {
      _sink.emit(event);
    } catch (_) {
      // 日志失败不影响配对/同步主流程
    }
    for (final sink in _extraSinks) {
      try {
        sink.emit(event);
      } catch (_) {
        // 附加 sink 失败同样吞掉（如文件写权限丢失）
      }
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
    log.event(
      'startup.rustlib',
      'startup',
      fields: const {'action': 'success'},
    );
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
