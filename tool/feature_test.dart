import 'dart:async' show TimeoutException;
import 'dart:io';

const _testTarget = 'integration_test/cardmind_journeys_test.dart';

/// 单次 `flutter test` 子进程的兜底时长：journeys 是实机/平台集成测试，
/// 正常要跑数分钟，20 分钟只是防挂死的上限，不是压测目标。
const _defaultTimeoutMinutes = 20;

/// GNU `timeout` 惯例：进程被超时终止时返回 124，区别于 flutter 自身非零码
/// 与本脚本的 64（用法错误）/ 69（无法启动）。
const _timeoutExitCode = 124;

Future<void> main(List<String> args) async {
  late final _Options options;
  try {
    options = _parseArgs(args);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    _printUsage();
    exitCode = 64;
    return;
  }
  if (options.help) {
    _printUsage();
    return;
  }

  final targets = options.platform == 'all'
      ? const ['windows', 'android']
      : [options.platform];
  for (final target in targets) {
    final device = target == 'windows'
        ? 'windows'
        : options.device ?? Platform.environment['CARDMIND_ANDROID_DEVICE_ID'];
    if (target == 'android' && (device == null || device.isEmpty)) {
      stderr.writeln(
        'Android integration tests require --device=<id> or '
        'CARDMIND_ANDROID_DEVICE_ID.',
      );
      exitCode = 64;
      return;
    }

    final result = await _runFlutter(device!);
    if (result != 0) {
      exitCode = result;
      return;
    }
  }
}

Future<int> _runFlutter(String device) async {
  stdout.writeln('Running CardMind journeys on $device');
  late final Process process;
  try {
    validateDevice(device);
    final executable = Platform.isWindows ? 'flutter.bat' : 'flutter';
    process = await Process.start(executable, [
      'test',
      '--no-pub',
      _testTarget,
      '-d',
      device,
    ], runInShell: false);
  } on ProcessException catch (error) {
    stderr.writeln('Unable to start Flutter: $error');
    return 69;
  }

  final stdoutDone = stdout.addStream(process.stdout);
  final stderrDone = stderr.addStream(process.stderr);
  final timeout = Duration(minutes: _timeoutMinutes());
  final stopwatch = Stopwatch()..start();
  int code;
  try {
    code = await process.exitCode.timeout(timeout);
  } on TimeoutException {
    process.kill();
    await process.exitCode;
    stopwatch.stop();
    stderr.writeln(
      'flutter test on $device timed out after '
      '${stopwatch.elapsed.inMinutes} minutes; process killed.',
    );
    code = _timeoutExitCode;
  }
  // kill 后 stdout/stderr 会随进程退出自行结束，addStream 照常收尾。
  await Future.wait([stdoutDone, stderrDone]);
  return code;
}

/// 读取 `CARDMIND_FEATURE_TEST_TIMEOUT_MINUTES`（分钟整数）；缺省或非法值
/// （非整数、≤0）回落 [_defaultTimeoutMinutes]。
int _timeoutMinutes() {
  final raw = Platform.environment['CARDMIND_FEATURE_TEST_TIMEOUT_MINUTES'];
  final parsed = raw == null ? null : int.tryParse(raw.trim());
  if (parsed == null || parsed <= 0) {
    return _defaultTimeoutMinutes;
  }
  return parsed;
}

/// 设备标识校验：只允许字母数字与 `._:-`，长度 ≤128 且非空。
///
/// 公开（非 `_` 前缀）是为了让 `test/feature_test_security_test.dart` 直接调用，
/// 用真实输入验证安全属性；校验逻辑本身不接受任意 shell 元字符。
void validateDevice(String device) {
  if (device.isEmpty ||
      device.length > 128 ||
      !RegExp(r'^[A-Za-z0-9._:-]+$').hasMatch(device)) {
    throw FormatException('Invalid device identifier');
  }
}

_Options _parseArgs(List<String> args) {
  var platform = 'windows';
  String? device;
  var help = false;
  for (final arg in args) {
    if (arg == '--help' || arg == '-h') {
      help = true;
    } else if (arg == '--windows') {
      platform = 'windows';
    } else if (arg == '--android') {
      platform = 'android';
    } else if (arg == '--all') {
      platform = 'all';
    } else if (arg.startsWith('--platform=')) {
      platform = arg.substring('--platform='.length);
    } else if (arg.startsWith('--device=')) {
      device = arg.substring('--device='.length);
    } else {
      throw FormatException('Unknown argument: $arg');
    }
  }
  if (!{'windows', 'android', 'all'}.contains(platform)) {
    throw FormatException('Unsupported platform: $platform');
  }
  return _Options(platform: platform, device: device, help: help);
}

void _printUsage() {
  stdout.writeln('Usage: dart run tool/feature_test.dart [options]');
  stdout.writeln(
    '  --windows             Run the Windows journey suite (default)',
  );
  stdout.writeln(
    '  --android --device=id Run Android journeys on an existing device',
  );
  stdout.writeln('  --all                 Run Windows then Android journeys');
  stdout.writeln('  --platform=<target>   windows, android, or all');
  stdout.writeln(
    '  --no-pub is always used; this runner never downloads SDKs.',
  );
}

class _Options {
  const _Options({
    required this.platform,
    required this.device,
    required this.help,
  });

  final String platform;
  final String? device;
  final bool help;
}
