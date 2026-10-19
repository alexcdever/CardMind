import 'dart:async' show TimeoutException;
import 'dart:io';

const _testTarget = 'integration_test/cardmind_journeys_test.dart';

/// `--file` 缺省时的目标文件；公开以便测试断言「缺省行为零变化」。
const kDefaultFeatureTestTarget = _testTarget;

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

    final result = await _runFlutter(device!, options.file);
    if (result != 0) {
      exitCode = result;
      return;
    }
  }
}

Future<int> _runFlutter(String device, String file) async {
  stdout.writeln('Running CardMind journeys on $device');
  late final Process process;
  try {
    validateDevice(device);
    validateTestFile(file);
    final executable = Platform.isWindows ? 'flutter.bat' : 'flutter';
    process = await Process.start(executable, [
      'test',
      '--no-pub',
      file,
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

/// `--file=<path>` 目标文件校验：必须是 `integration_test/` 下的相对路径，
/// 以 `_test.dart` 结尾，不含 `..` 路径逃逸、绝对路径、或 shell 元字符。
///
/// 公开（非 `_` 前缀）是为了让测试直接调用，用真实输入验证安全属性；
/// 校验逻辑本身不接受任何会被 shell/路径解析改写的字符。
void validateTestFile(String file) {
  if (file.isEmpty ||
      file.length > 256 ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._/-]*_test\.dart$').hasMatch(file) ||
      !file.startsWith('integration_test/') ||
      file.contains('..')) {
    throw FormatException(
      'Invalid --file target: must be a relative path under '
      'integration_test/ ending in _test.dart',
    );
  }
}

/// 解析 `--file` 参数（缺省回落 [_testTarget]）。
///
/// 公开以便测试直接断言解析结果；委托 [_parseArgs] 保证 `--file`
/// 只有单份解析实现，非法值在解析阶段即抛 [FormatException]。
String featureTestTargetForArgs(List<String> args) => _parseArgs(args).file;

_Options _parseArgs(List<String> args) {
  var platform = 'windows';
  String? device;
  var help = false;
  var file = _testTarget;
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
    } else if (arg.startsWith('--file=')) {
      file = arg.substring('--file='.length);
      validateTestFile(file);
    } else {
      throw FormatException('Unknown argument: $arg');
    }
  }
  if (!{'windows', 'android', 'all'}.contains(platform)) {
    throw FormatException('Unsupported platform: $platform');
  }
  return _Options(platform: platform, device: device, help: help, file: file);
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
    '  --file=<path>         Integration test file under integration_test/\n'
    '                        (default: $_testTarget)',
  );
  stdout.writeln(
    '  --no-pub is always used; this runner never downloads SDKs.',
  );
}

class _Options {
  const _Options({
    required this.platform,
    required this.device,
    required this.help,
    required this.file,
  });

  final String platform;
  final String? device;
  final bool help;
  final String file;
}
