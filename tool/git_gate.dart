/// CardMind 本地质量门禁 CLI。
///
/// 用法：
///   dart run tool/git_gate.dart pre-commit [--dry-run] [--files `<path...>`]
///   dart run tool/git_gate.dart pre-push    [--dry-run]
///   dart run tool/git_gate.dart full        [--dry-run]
///   dart run tool/git_gate.dart plan --staged | --files `<path...>`
///
/// 环境变量：
///   SKIP_LOCAL_CHECK=1         （由 hook 处理）跳过门禁
///   CARDMIND_FORCE_FULL_CHECK=1  忽略 pre-push 缓存，强制完整 suite
///   CARDMIND_GATE_TEST_MODE=1    fake runner（真实 hook 集成测试用）
///   CARDMIND_GATE_FAKE_FAIL=1    测试模式下强制命令失败
///   CARDMIND_GATE_FAKE_LOG=path  测试模式 fake 日志路径
library;

import 'dart:io';

import 'src/git_gate/gate.dart';
import 'src/git_gate/git.dart';
import 'src/git_gate/runner.dart';
import 'src/git_gate/selector.dart';

const String _usage = '''
CardMind Git Gate — 本地质量门禁

用法:
  dart run tool/git_gate.dart <pre-commit|pre-push|full|plan> [options]

Commands:
  pre-commit              按 staged 变更执行快速相关门禁（format-first）
  pre-push                完整 host suite（读取 Git stdin ref 行，支持 HEAD 缓存）
  full                    完整 host suite（独立执行，写缓存）
  plan                    只打印结构化计划，不格式化、不运行

Options:
  --dry-run               只打印将执行的命令
  --files <path...>       用给定文件代替 staged 文件（pre-commit/plan）
  --staged                读取 staged 文件（plan）
  -h, --help              显示帮助

环境变量:
  SKIP_LOCAL_CHECK=1         跳过门禁（由 hook 处理）
  CARDMIND_FORCE_FULL_CHECK=1 忽略 pre-push 缓存
  CARDMIND_GATE_TEST_MODE=1   测试模式（fake runner）
  CARDMIND_GATE_FAKE_FAIL=1   测试模式强制失败
  CARDMIND_GATE_FAKE_LOG=path 测试模式 fake 日志
''';

Future<void> main(List<String> args) async {
  exitCode = await runGitGateCli(args);
}

Future<int> runGitGateCli(List<String> args) async {
  if (args.contains('-h') || args.contains('--help')) {
    stdout.writeln(_usage);
    return 0;
  }
  if (args.isEmpty) {
    stderr.writeln(_usage);
    return 1;
  }

  final env = Platform.environment;
  final repoRoot = Directory.current.path;
  final testMode = env['CARDMIND_GATE_TEST_MODE'] == '1';
  final fakeLog =
      env['CARDMIND_GATE_FAKE_LOG'] ??
      (testMode ? '$repoRoot/.git/cardmind-gate-fake.log' : null);

  final runner = CommandRunner(
    timeout: const Duration(minutes: 3),
    testMode: testMode,
    fakeFail: env['CARDMIND_GATE_FAKE_FAIL'] == '1',
    fakeLog: fakeLog,
  );

  void testWriter(String line) {
    if (!testMode || fakeLog == null) return;
    try {
      final f = File(fakeLog);
      f.parent.createSync(recursive: true);
      f.writeAsStringSync('$line\n', mode: FileMode.append);
    } on FileSystemException {
      // 忽略
    }
  }

  final baseOptions = GateOptions(
    repoRoot: repoRoot,
    runner: runner.run,
    stepTimeout: const Duration(minutes: 3),
    log: (m) => stdout.writeln(m),
    logError: (m) => stderr.writeln(m),
    forceFullCheck: env['CARDMIND_FORCE_FULL_CHECK'] == '1',
    testLogWriter: testWriter,
    testMode: testMode,
  );

  final command = args.first;
  final rest = args.skip(1).toList();
  final dryRun = rest.contains('--dry-run');

  switch (command) {
    case 'pre-commit':
      final files = _optionFiles(rest);
      return runPreCommit(
        baseOptions.copyWith(stagedFilesOverride: files, dryRun: dryRun),
      );
    case 'pre-push':
      return runPrePush(baseOptions.copyWith(dryRun: dryRun));
    case 'full':
      return runFull(baseOptions.copyWith(dryRun: dryRun));
    case 'plan':
      return _runPlan(baseOptions, rest);
    default:
      stderr.writeln('未知命令: $command');
      stderr.writeln(_usage);
      return 1;
  }
}

Future<int> _runPlan(GateOptions o, List<String> rest) async {
  final index = await scanTestIndex(o.repoRoot);
  List<String> files;
  if (rest.contains('--staged')) {
    files = await stagedFiles(o.repoRoot);
  } else if (rest.contains('--files')) {
    files = _optionFiles(rest) ?? const <String>[];
  } else {
    stderr.writeln('plan 需要 --staged 或 --files <path...>');
    return 1;
  }
  final plan = selectPlanForFiles(files, index: index);
  printPlan(o, plan, title: 'plan');
  return 0;
}

List<String>? _optionFiles(List<String> rest) {
  final idx = rest.indexOf('--files');
  if (idx == -1) return null;
  final files = rest.sublist(idx + 1).where((s) => s != '--dry-run').toList();
  return files.isEmpty ? null : files;
}
