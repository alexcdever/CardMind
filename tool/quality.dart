import 'dart:io';

typedef Runner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

const _usage = 'Usage: dart run tool/quality.dart <flutter|rust|all> [options]';
const _help = '''Usage: dart run tool/quality.dart <flutter|rust|all> [options]

Commands:
  flutter  Run Flutter lint, tests, and boundary scan
  rust     Run Rust lint and tests
  all      Run Flutter then Rust quality checks

Options:
  -h, --help  Show this help message

Default behavior:
  flutter runs: flutter analyze -> flutter test -> test boundary scan
  rust runs: cargo fmt --all -- --check -> cargo clippy --all-targets --all-features -- -D warnings -> cargo test
  all runs: flutter -> rust

Examples:
  dart run tool/quality.dart flutter
  dart run tool/quality.dart rust
  dart run tool/quality.dart all
''';

Future<void> main(List<String> args) async {
  exitCode = await runQualityCli(args);
}

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

Future<int> _runFlutterQuality({
  required Runner runProcess,
  required void Function(String) log,
  required void Function(String) logError,
}) async {
  final analyze = await runProcess('flutter', ['analyze']);
  if (analyze.exitCode != 0) {
    logError(_processError(analyze));
    return analyze.exitCode;
  }
  log('[flutter:analyze] done');

  final test = await runProcess('flutter', ['test']);
  if (test.exitCode != 0) {
    logError(_processError(test));
    return test.exitCode;
  }
  log('[flutter:test] done');

  // 运行测试边界扫描
  log('[flutter:test-boundary-scan] scanning...');
  final boundaryScan = await runProcess('dart', [
    'tool/test_boundary_scanner.dart',
  ]);
  if (boundaryScan.exitCode != 0) {
    logError(
      '[flutter:test-boundary-scan] High priority boundaries not covered',
    );
    log('See report: /tmp/cardmind_test_boundary_report.md');
    // 不返回错误，只作为警告
  } else {
    log('[flutter:test-boundary-scan] done');
  }
  return 0;
}

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

  final test = await runProcess('cargo', ['test'], workingDirectory: rustDir);
  if (test.exitCode != 0) {
    logError(_processError(test));
    return test.exitCode;
  }
  log('[rust:test] done');
  return 0;
}

String _processError(ProcessResult result) {
  final stderrText = result.stderr.toString().trim();
  final stdoutText = result.stdout.toString().trim();
  final output = stderrText.isNotEmpty ? stderrText : stdoutText;
  return 'Process failed with exit code ${result.exitCode}: $output';
}

Future<ProcessResult> _run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  return Process.run(executable, arguments, workingDirectory: workingDirectory);
}

void _stdout(String message) => stdout.writeln(message);

void _stderr(String message) => stderr.writeln(message);
