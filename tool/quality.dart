import 'dart:io';

import 'src/git_gate/host_build.dart';
import 'src/git_gate/runner.dart' show resolveExecutable;

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
  flutter runs: markdown references lint -> build host rust library -> FRB codegen -> flutter analyze -> flutter test -> test boundary scan
  rust runs: cargo fmt --all -- --check -> cargo clippy --all-targets --all-features -- -D warnings -> cargo test --all-features --jobs 1
  docs runs: markdown references lint
  all runs: flutter quality with FRB prep -> rust

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
///
/// [repoRoot] / [platformOverride] 是 FRB 准备步骤的注入点（默认当前工作目录与
/// 当前 host 平台），其余步骤沿用当前工作目录。
Future<int> runQualityCli(
  List<String> args, {
  Runner runProcess = _run,
  void Function(String) log = _stdout,
  void Function(String) logError = _stderr,
  String? repoRoot,
  HostBuildPlatform? platformOverride,
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
      repoRoot: repoRoot,
      platformOverride: platformOverride,
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
      repoRoot: repoRoot,
      platformOverride: platformOverride,
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
  String? repoRoot,
  HostBuildPlatform? platformOverride,
}) async {
  final docsExit = await _runDocsQuality(
    runProcess: runProcess,
    log: log,
    logError: logError,
  );
  if (docsExit != 0) {
    return docsExit;
  }

  final frbPrepExit = await _prepareFlutterFrbArtifacts(
    runProcess: runProcess,
    log: log,
    logError: logError,
    repoRoot: repoRoot,
    platformOverride: platformOverride,
  );
  if (frbPrepExit != 0) {
    return frbPrepExit;
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
    '--timeout',
    '5m',
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
    '--reuse-coverage',
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

/// FRB 准备：构建 host 动态库 → 同步运行态库 → FRB codegen。
///
/// 运行态同步复用 host_build.dart 的跨平台规格（与 gate 的 build-lib 同一真相源，
/// Windows `cardmind_backend.dll` / macOS `libcardmind_backend.dylib` /
/// Linux `libcardmind_backend.so`），不再通过子进程调用 `dart tool/build.dart lib`
/// ——该入口此前硬编码 macOS 路径，Windows 上必失败。
///
/// [repoRoot] / [platformOverride] 默认取当前工作目录与当前 host 平台；测试注入
/// 临时仓库根，避免改动共享的运行态库。
Future<int> _prepareFlutterFrbArtifacts({
  required Runner runProcess,
  required void Function(String) log,
  required void Function(String) logError,
  String? repoRoot,
  HostBuildPlatform? platformOverride,
}) async {
  final root = repoRoot ?? Directory.current.path;
  final HostBuildPlatform platform;
  try {
    platform = platformOverride ?? detectHostPlatform();
  } on UnsupportedError catch (e) {
    logError('[flutter:frb-lib] ${e.message}');
    return 1;
  }

  final build = await runProcess('cargo', [
    'build',
    '--release',
  ], workingDirectory: '$root/rust-backend');
  if (build.exitCode != 0) {
    logError(_processError(build));
    return build.exitCode;
  }
  log('[flutter:frb-lib] cargo build --release done');

  final syncError = syncHostRuntimeLibrary(root, platform);
  if (syncError != null) {
    logError('[flutter:frb-lib] $syncError');
    return 1;
  }
  log(
    '[flutter:frb-lib] runtime library synced: '
    '${hostRuntimeSpec(platform).runtimeDestRel}',
  );

  final codegen = await runProcess('flutter_rust_bridge_codegen', ['generate']);
  if (codegen.exitCode != 0) {
    logError(_processError(codegen));
    return codegen.exitCode;
  }
  log('[flutter:frb-codegen] done');

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
  final rustDir = '${Directory.current.path}/rust-backend';

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
    '--workspace',
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
    '--all-features',
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
    log('[rust:coverage] LCOV report generated: rust-backend/lcov.info');
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
  final parts = <String>[
    if (stderrText.isNotEmpty) '[stderr] $stderrText',
    if (stdoutText.isNotEmpty) '[stdout] $stdoutText',
  ];
  final output = parts.isNotEmpty ? parts.join('\n') : '(no output)';
  return 'Process failed with exit code ${result.exitCode}: $output';
}

/// 运行外部命令
Future<ProcessResult> _run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  return Process.run(
    resolveExecutable(executable, isWindows: Platform.isWindows),
    arguments,
    workingDirectory: workingDirectory,
  );
}

/// 输出到stdout
void _stdout(String message) => stdout.writeln(message);

/// 输出到stderr
void _stderr(String message) => stderr.writeln(message);
