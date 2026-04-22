import 'dart:io';

typedef Runner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

const _flutterTestConcurrency = '4';
const _rustTestJobs = '1';

const _usage =
    'Usage: dart run tool/quality.dart <flutter|rust|docs|all> [options]';
const _help =
    '''Usage: dart run tool/quality.dart <flutter|rust|docs|all> [options]

Commands:
  flutter  Run Markdown lint, Flutter lint, tests, and boundary scan
  rust     Run Rust lint and tests
  docs     Run Markdown references lint
  all      Run Flutter then Rust quality checks

Options:
  -h, --help  Show this help message

Default behavior:
  flutter runs: markdown references lint -> flutter analyze -> flutter test -> test boundary scan
  rust runs: cargo fmt --all -- --check -> cargo clippy --all-targets --all-features -- -D warnings -> cargo test --jobs 1
  docs runs: markdown references lint
  all runs: flutter -> rust

Examples:
  dart run tool/quality.dart flutter
  dart run tool/quality.dart rust
  dart run tool/quality.dart all
''';

/// 主函数
Future<void> main(List<String> args) async {
  exitCode = await runQualityCli(args);
}

/// 质量检查命令行入口
Future<int> runQualityCli(
  List<String> args, {
  Runner runProcess = _run,
  void Function(String) log = _stdout,
  void Function(String) logError = _stderr,
}) async {
  if (args.contains('--help') || args.contains('-h')) {
    log(_help);
    return 0;
  }

  if (args.isEmpty) {
    logError(_usage);
    return 1;
  }

  if (args.first == 'flutter') {
    return _runFlutterQuality(
      runProcess: runProcess,
      log: log,
      logError: logError,
    );
  }
  if (args.first == 'rust') {
    return _runRustQuality(
      runProcess: runProcess,
      log: log,
      logError: logError,
    );
  }
  if (args.first == 'docs') {
    return _runDocsQuality(
      runProcess: runProcess,
      log: log,
      logError: logError,
    );
  }
  if (args.first == 'all') {
    final flutterExit = await _runFlutterQuality(
      runProcess: runProcess,
      log: log,
      logError: logError,
    );
    if (flutterExit != 0) {
      return flutterExit;
    }
    return _runRustQuality(
      runProcess: runProcess,
      log: log,
      logError: logError,
    );
  }

  logError(_usage);
  return 1;
}

/// 运行Flutter质量检查
Future<int> _runFlutterQuality({
  required Runner runProcess,
  required void Function(String) log,
  required void Function(String) logError,
}) async {
  final docsExit = await _runDocsQuality(
    runProcess: runProcess,
    log: log,
    logError: logError,
  );
  if (docsExit != 0) {
    return docsExit;
  }

  final analyze = await runProcess('flutter', ['analyze']);
  if (analyze.exitCode != 0) {
    logError(_processError(analyze));
    return analyze.exitCode;
  }
  log('[flutter:analyze] done');

  /// 运行测试并生成覆盖率（边界扫描需要）
  final test = await runProcess('flutter', [
    'test',
    '--coverage',
    '-j',
    _flutterTestConcurrency,
  ]);
  if (test.exitCode != 0) {
    logError(_processError(test));
    return test.exitCode;
  }
  log('[flutter:test] done (with coverage)');

  /// 运行测试边界扫描
  log('[flutter:test-boundary-scan] scanning...');
  final boundaryScan = await runProcess('dart', [
    'tool/test_boundary_scanner.dart',
    '--scope=flutter',
  ]);
  if (boundaryScan.exitCode != 0) {
    logError(
      '[flutter:test-boundary-scan] High priority boundaries not covered',
    );
    log('See report: tmp/cardmind_test_boundary_report.md');

    /// 不返回错误，只作为警告
  } else {
    log('[flutter:test-boundary-scan] done');
  }
  return 0;
}

Future<int> _runDocsQuality({
  required Runner runProcess,
  required void Function(String) log,
  required void Function(String) logError,
}) async {
  final markdownLint = await runProcess('dart', [
    'tool/lint/markdown_references_linter.dart',
  ]);
  if (markdownLint.exitCode != 0) {
    logError(_processError(markdownLint));
    return markdownLint.exitCode;
  }
  log('[docs:markdown-lint] done');
  return 0;
}

/// 运行Rust质量检查
Future<int> _runRustQuality({
  required Runner runProcess,
  required void Function(String) log,
  required void Function(String) logError,
}) async {
  final rustDir = '${Directory.current.path}/rust';

  final fmt = await runProcess('cargo', [
    'fmt',
    '--all',
    '--',
    '--check',
  ], workingDirectory: rustDir);
  if (fmt.exitCode != 0) {
    logError(_processError(fmt));
    return fmt.exitCode;
  }
  log('[rust:fmt] done');

  final clippy = await runProcess('cargo', [
    'clippy',
    '--all-targets',
    '--all-features',
    '--',
    '-D',
    'warnings',
  ], workingDirectory: rustDir);
  if (clippy.exitCode != 0) {
    logError(_processError(clippy));
    return clippy.exitCode;
  }
  log('[rust:clippy] done');

  // Rust 集成测试会生成多个 test target；这里显式串行化 target 进程，
  // 避免 iroh/netmon 相关全局资源在不同测试二进制间并发初始化。
  final test = await runProcess('cargo', [
    'test',
    '--jobs',
    _rustTestJobs,
  ], workingDirectory: rustDir);
  if (test.exitCode != 0) {
    logError(_processError(test));
    return test.exitCode;
  }
  log('[rust:test] done');

  /// 生成 Rust LCOV 覆盖率报告
  log('[rust:coverage] generating LCOV report...');
  final coverage = await runProcess('cargo', [
    'tarpaulin',
    '--out',
    'Lcov',
    '--output-dir',
    '.',
    '--exclude-files',
    'src/frb_generated.rs',
    '--exclude-files',
    'tool/**',
  ], workingDirectory: rustDir);
  if (coverage.exitCode != 0) {
    logError(
      '[rust:coverage] failed to generate LCOV (cargo-tarpaulin may not be installed)',
    );

    /// 不返回错误，因为这只是覆盖率数据
  } else {
    log('[rust:coverage] LCOV report generated: rust/lcov.info');
  }

  log('[rust:test-boundary-scan] scanning...');
  final boundaryScan = await runProcess('dart', [
    'tool/test_boundary_scanner.dart',
    '--scope=rust',
  ]);
  if (boundaryScan.exitCode != 0) {
    logError('[rust:test-boundary-scan] High priority boundaries not covered');
    log('See report: tmp/cardmind_test_boundary_report.md');
  } else {
    log('[rust:test-boundary-scan] done');
  }

  return 0;
}

/// 格式化进程错误信息
String _processError(ProcessResult result) {
  final stderrText = result.stderr.toString().trim();
  final stdoutText = result.stdout.toString().trim();
  final output = stderrText.isNotEmpty ? stderrText : stdoutText;
  return 'Process failed with exit code ${result.exitCode}: $output';
}

/// 运行外部命令
Future<ProcessResult> _run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  return Process.run(executable, arguments, workingDirectory: workingDirectory);
}

/// 输出到stdout
void _stdout(String message) => stdout.writeln(message);

/// 输出到stderr
void _stderr(String message) => stderr.writeln(message);
