/// 外部进程执行器：3 分钟硬超时（可注入），超时终止完整进程树。
///
/// 测试模式（`CARDMIND_GATE_TEST_MODE=1`）下所有命令走 fake runner，
/// 记录到 fake log 且不真实执行，供真实 hook 集成测试使用。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 超时专用退出码。
const int kTimeoutExitCode = 124;

/// 单条命令的执行结果。
class RunnerResult {
  const RunnerResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.timedOut,
    required this.elapsed,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
  final bool timedOut;
  final Duration elapsed;
}

/// runner 签名（可注入 fake）。
typedef Runner =
    Future<RunnerResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
    });

/// 真实启动函数签名（可注入 spy 测试；默认 [runWithTimeout]）。
typedef RealProcessRunner =
    Future<RunnerResult> Function({
      required String executable,
      required List<String> arguments,
      String? workingDirectory,
      Map<String, String>? environment,
      required Duration timeout,
    });

/// 解析可执行文件：Windows 上精确 `flutter` → `flutter.bat`。
///
/// 背景：Dart `Process.start` 在 Windows 上无法启动 Scoop/Flutter 的
/// extensionless `flutter` shim，而 `flutter.bat` 可以启动。
/// 只有精确 executable `flutter` 被替换；`flutter_rust_bridge_codegen`、
/// `dart`、`cargo` 等其它可执行文件不受影响。非 Windows 保持 `flutter`。
String resolveExecutable(String executable, {required bool isWindows}) {
  if (isWindows && executable == 'flutter') return 'flutter.bat';
  return executable;
}

/// Git 为 hook / `--git-dir` 调用导出的仓库定位变量。
///
/// 门禁运行的子进程（测试、构建、格式化）必须看不到这些变量：子进程内部的
/// `git` 调用会被重定向到外层仓库，从而污染外层仓库的 index/HEAD。典型场景是
/// `test/git_gate_hook_integration_test.dart` 在临时仓库里执行 git，一旦外层
/// 导出了 `GIT_DIR`，临时仓库的 `git add/commit` 就会落到真实仓库上。
const List<String> kGitRepoEnvVars = <String>[
  'GIT_DIR',
  'GIT_WORK_TREE',
  'GIT_INDEX_FILE',
  'GIT_COMMON_DIR',
  'GIT_OBJECT_DIRECTORY',
  'GIT_ALTERNATE_OBJECT_DIRECTORIES',
  'GIT_PREFIX',
];

/// 返回剔除了 Git 仓库定位变量（[kGitRepoEnvVars]）的环境副本，用于隔离子进程。
///
/// 其余变量原样保留；调用方传入的 `environment` 与当前进程环境都会被处理，
/// 因此子进程既能拿到必要变量，又不会继承门禁自身所在仓库的 git 定位信息。
Map<String, String> sanitizeStepEnvironment(Map<String, String> base) {
  final env = Map<String, String>.from(base);
  for (final key in kGitRepoEnvVars) {
    env.remove(key);
  }
  return env;
}

/// 带硬超时的真实 runner + 测试模式 fake runner。
class CommandRunner {
  CommandRunner({
    required this.timeout,
    this.testMode = false,
    this.fakeFail = false,
    this.fakeLog,
    RealProcessRunner? realRunner,
  }) : _realRunner = realRunner ?? runWithTimeout;

  static const int timeoutExitCode = kTimeoutExitCode;

  final Duration timeout;
  final bool testMode;
  final bool fakeFail;
  final String? fakeLog;
  final RealProcessRunner _realRunner;

  Future<RunnerResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) {
    if (testMode) {
      // 测试模式记录逻辑命令（原始 executable），不掩盖真实解析；
      // 真实解析只作用于真实启动路径，见下方 resolveExecutable。
      return _fakeRun(executable, arguments, workingDirectory);
    }
    // 所有真实 runner 入口统一经过解析：参数、cwd 保留；environment 剔除 Git
    // 仓库定位变量后显式传入（不传则子进程会继承外层仓库的 GIT_DIR 等，见
    // sanitizeStepEnvironment）。
    final resolved = resolveExecutable(
      executable,
      isWindows: Platform.isWindows,
    );
    return _realRunner(
      executable: resolved,
      arguments: arguments,
      workingDirectory: workingDirectory,
      environment: sanitizeStepEnvironment(environment ?? Platform.environment),
      timeout: timeout,
    );
  }

  Future<RunnerResult> _fakeRun(
    String executable,
    List<String> arguments,
    String? workingDirectory,
  ) async {
    final line =
        'FAKE $executable ${arguments.join(' ')}'
        '${workingDirectory == null ? '' : ' (cwd=$workingDirectory)'}';
    if (fakeLog != null) {
      try {
        final f = File(fakeLog!);
        f.parent.createSync(recursive: true);
        f.writeAsStringSync('$line\n', mode: FileMode.append);
      } on FileSystemException {
        // 无法写日志不致命
      }
    }
    if (fakeFail) {
      return RunnerResult(
        exitCode: 1,
        stdout: '',
        stderr: '[fake] forced failure: $line',
        timedOut: false,
        elapsed: Duration.zero,
      );
    }
    return RunnerResult(
      exitCode: 0,
      stdout: '',
      stderr: '',
      timedOut: false,
      elapsed: Duration.zero,
    );
  }
}

/// 运行外部命令并强制 hard timeout。
///
/// 超时行为：
/// - Windows：`taskkill /T /F` 终止完整进程树；
/// - POSIX：`pgrep -P` 递归收集后代后自底向上 kill；
/// - 返回 exit code 124 + `TIMEOUT` 标记 + 命令/耗时信息；
/// - 绝不无限等待。
Future<RunnerResult> runWithTimeout({
  required String executable,
  required List<String> arguments,
  String? workingDirectory,
  Map<String, String>? environment,
  required Duration timeout,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    // `includeParentEnvironment` 默认 true：Dart 会把父环境与传入的 environment
    // 合并，那么即使传入的 map 已剔除 GIT_DIR，子进程仍会从父环境继承回来。
    // 因此传入 environment 时按“完整环境”处理（不合并）；未传入时沿用父环境。
    environment: environment,
    includeParentEnvironment: environment == null,
    mode: ProcessStartMode.normal,
  );

  final stdoutBuf = StringBuffer();
  final stderrBuf = StringBuffer();
  process.stdout.transform(utf8.decoder).listen(stdoutBuf.write);
  process.stderr.transform(utf8.decoder).listen(stderrBuf.write);

  final sw = Stopwatch()..start();
  var done = false;
  final completer = Completer<RunnerResult>();

  Future<void> killTree() async {
    try {
      if (Platform.isWindows) {
        // taskkill /T 终止完整进程树；taskkill 本身也套超时，防挂死
        await Process.run('taskkill', <String>[
          '/PID',
          '${process.pid}',
          '/T',
          '/F',
        ]).timeout(
          const Duration(seconds: 10),
          onTimeout: () => ProcessResult(0, -1, '', 'taskkill timeout'),
        );
      } else {
        // POSIX：递归收集后代（pgrep -P）后自底向上 kill
        await killTreePosix(process.pid);
      }
    } catch (_) {
      // 忽略清理失败
    }
  }

  final timer = Timer(timeout, () async {
    if (done) return;
    done = true;
    sw.stop();
    await killTree();
    if (!completer.isCompleted) {
      completer.complete(
        RunnerResult(
          exitCode: kTimeoutExitCode,
          stdout: stdoutBuf.toString(),
          stderr:
              '${stderrBuf.toString()}\n'
              '[gate] TIMEOUT after ${timeout.inSeconds}s: '
              '$executable ${arguments.join(' ')}',
          timedOut: true,
          elapsed: sw.elapsed,
        ),
      );
    }
  });

  final exit = await process.exitCode;
  if (!done) {
    done = true;
    timer.cancel();
    sw.stop();
    // 给流一个事件循环周期，确保 stdout/stderr 已消费
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!completer.isCompleted) {
      completer.complete(
        RunnerResult(
          exitCode: exit,
          stdout: stdoutBuf.toString(),
          stderr: stderrBuf.toString(),
          timedOut: false,
          elapsed: sw.elapsed,
        ),
      );
    }
  }
  return completer.future;
}

/// POSIX 进程树终止：pgrep -P 递归收集后代，自底向上 kill。
Future<void> killTreePosix(int pid) async {
  final children = <int>[];
  final stack = <int>[pid];
  while (stack.isNotEmpty) {
    final parent = stack.removeLast();
    try {
      final r = await Process.run('pgrep', <String>['-P', '$parent']);
      if (r.exitCode == 0) {
        for (final line in r.stdout.toString().split('\n')) {
          final p = int.tryParse(line.trim());
          if (p != null) {
            children.add(p);
            stack.add(p);
          }
        }
      }
    } on ProcessException {
      // pgrep 不可用时只杀父进程
    }
  }
  for (final child in children.reversed) {
    try {
      Process.killPid(child);
    } on ProcessException {
      // ignore
    }
  }
  try {
    Process.killPid(pid);
  } on ProcessException {
    // ignore
  }
}
