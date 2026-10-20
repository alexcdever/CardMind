/// 门禁编排：pre-commit 快速相关门禁、pre-push 完整 host suite、full。
library;

import 'dart:io';

import 'cache.dart';
import 'command.dart';
import 'formatter.dart';
import 'git.dart';
import 'host_build.dart';
import 'runner.dart';
import 'selector.dart';

/// 门禁依赖与开关（全部可注入，便于单测）。
class GateOptions {
  const GateOptions({
    required this.repoRoot,
    required this.runner,
    required this.stepTimeout,
    required this.log,
    required this.logError,
    this.index,
    this.stagedFilesOverride,
    this.pushRefLinesOverride,
    this.forceFullCheck = false,
    this.dryRun = false,
    this.testLogWriter,
    this.testMode = false,
  });

  final String repoRoot;
  final Runner runner;
  final Duration stepTimeout;
  final void Function(String) log;
  final void Function(String) logError;

  /// 现有测试资产索引；null 时按文件系统扫描。
  final TestIndex? index;

  /// pre-commit 指定 staged 文件（测试/工具用）。
  final List<String>? stagedFilesOverride;

  /// pre-push stdin ref 行（测试注入）。
  final List<String>? pushRefLinesOverride;

  /// CARDMIND_FORCE_FULL_CHECK=1：忽略缓存。
  final bool forceFullCheck;

  /// 只打印计划，不格式化、不运行命令。
  final bool dryRun;

  /// 测试模式下额外写入 fake log 的行（如 REFS）。
  final void Function(String)? testLogWriter;

  /// 测试模式（CARDMIND_GATE_TEST_MODE=1）：host runtime 库同步跳过，
  /// 避免在临时 repo 做真实 dll 复制。
  final bool testMode;

  GateOptions copyWith({
    TestIndex? index,
    List<String>? stagedFilesOverride,
    bool? forceFullCheck,
    bool? dryRun,
    bool? testMode,
  }) {
    return GateOptions(
      repoRoot: repoRoot,
      runner: runner,
      stepTimeout: stepTimeout,
      log: log,
      logError: logError,
      index: index ?? this.index,
      stagedFilesOverride: stagedFilesOverride ?? this.stagedFilesOverride,
      pushRefLinesOverride: pushRefLinesOverride,
      forceFullCheck: forceFullCheck ?? this.forceFullCheck,
      dryRun: dryRun ?? this.dryRun,
      testLogWriter: testLogWriter,
      testMode: testMode ?? this.testMode,
    );
  }
}

/// 测试文件里 `import 'support/x.dart'`（相对 `test/`）或
/// `import 'package:cardmind/test/support/x.dart'` 的包别名形式。
/// 命中即把该测试文件记为 `test/support/x.dart`（stem `x`）的 import 方。
final RegExp _supportImportPattern = RegExp(
  "import\\s+['\"](?:package:cardmind/test/)?support/([A-Za-z0-9_]+)\\.dart['\"]",
);

/// 扫描仓库现有测试资产。
Future<TestIndex> scanTestIndex(String repoRoot) async {
  final flutter = <String>{};
  final rust = <String>{};
  // test/support/ fake stem → import 它的测试文件（派生，不手抄）。
  final importers = <String, Set<String>>{};
  final testDir = Directory('$repoRoot/test');
  if (testDir.existsSync()) {
    // 递归扫描：test/services、test/models 子目录的测试，以及
    // test/support/ 下的共享 fake（非 _test.dart，分类 dartBusiness，
    // 但列入 flutterTestFiles 供 _maybePairing/_maybeSync/_relatedDartTests 命中）。
    for (final f in testDir.listSync(recursive: true).whereType<File>()) {
      final p = f.path.replaceAll(Platform.pathSeparator, '/');
      if (p.endsWith('_test.dart') ||
          (p.endsWith('.dart') && p.contains('/test/support/'))) {
        flutter.add(_repoRelative(repoRoot, f.path));
      }
    }
    // 从测试文件内容派生 support fake 的 import 方：新增/重命名
    // test/support/ 下的 fake、或调整测试的 import 方时自动纳入，无需
    // 维护手抄映射（手抄必然漂移，新测试会默默不被门禁选中）。fake stem
    // 必须真实存在于 test/support/（在 flutter 索引里）才记录：
    // import 'support/x.dart' 但 x.dart 不在索引（拼错/已删除）时不得建
    // importer 映射——否则该 stem 会被锚成「有映射」而跳过调用方的
    // fail-closed 全量兜底。
    for (final f in testDir.listSync(recursive: true).whereType<File>()) {
      final p = f.path.replaceAll(Platform.pathSeparator, '/');
      if (!p.endsWith('_test.dart')) continue;
      final rel = _repoRelative(repoRoot, f.path);
      for (final m in _supportImportPattern.allMatches(f.readAsStringSync())) {
        final stem = m.group(1)!;
        if (flutter.contains('test/support/$stem.dart')) {
          importers.putIfAbsent(stem, () => <String>{}).add(rel);
        }
      }
    }
  }
  final supportImporters = <String, List<String>>{};
  for (final e in importers.entries) {
    supportImporters[e.key] = e.value.toList()..sort();
  }
  // 引用 `api::` 的 Rust 测试 target（派生，不手抄）。
  final apiConsumers = <String>{};
  final rustTestsDir = Directory('$repoRoot/rust-backend/tests');
  if (rustTestsDir.existsSync()) {
    // 递归扫描按 cargo target 规则索引（与 selector 的 rustTestTargetName
    // 同语义）：tests/*.rs 与 tests/<dir>/main.rs 是 target；子目录其余
    // 文件（tests/common/mod.rs 等被 `mod` 引入的共享辅助）不是 target，
    // 不得入索引——否则分类器会给它生成不存在的 cargo test --test <stem>。
    for (final f in rustTestsDir.listSync(recursive: true).whereType<File>()) {
      final rel = _repoRelative(repoRoot, f.path);
      final target = rustTestTargetName(rel);
      if (target == null) continue;
      rust.add(target);
      // 顺带派生「引用 `api::`（FRB 导出层）的 target」：改
      // rust-backend/src/api.rs 时必须跑的真实消费方集合。真相源是测试
      // 源码内容，不手抄——手抄表必然漂移（新增引用 api:: 的测试不会被
      // 门禁选中，fail-silent）。只对 target 文件派生：common/mod.rs 等
      // 共享辅助即使含 api:: 也不是 cargo target，不得记成消费方。
      if (_rustApiRefPattern.hasMatch(f.readAsStringSync())) {
        apiConsumers.add(target);
      }
    }
  }
  return TestIndex(
    flutterTestFiles: flutter,
    rustTestTargets: rust,
    supportImporters: supportImporters,
    rustApiConsumers: apiConsumers,
  );
}

/// Rust 测试源码里引用 FRB 导出层的形态。
///
/// 两个分支：
/// 1. `api::…`（任意前缀路径：`api::x`、`cardmind_backend::api::x`、
///    `crate::api::x`）——`api` 作为路径段，前面是非标识符边界，
///    所以 `my_api::x`、`api_helpers::x` 不命中；
/// 2. `use …::api;` / `use …::api as A;` / `use {…, …::api}`——整路径
///    引入 `api` 模块本身（此时后续调用不带 `api::` 前缀）。
///
/// 命中即该文件是 `api::` 的消费方。宁可多匹配（多跑一个 target 只是慢），
/// 不可漏（漏跑 = fail-silent，改了导出层却没测真实消费方）。
final RegExp _rustApiRefPattern = RegExp(
  r'(?:^|[^\w])api\s*::'
  r'|\buse\s+[^;]*?\bapi\s*(?:as\b|[;,}])',
);

/// pre-commit：format-first → 按 staged 分类执行快速门禁。
Future<int> runPreCommit(GateOptions o) async {
  final index = o.index ?? await scanTestIndex(o.repoRoot);
  final formatter = Formatter(
    repoRoot: o.repoRoot,
    runner: o.runner,
    timeout: o.stepTimeout,
  );

  if (!o.dryRun) {
    final format = await formatter.formatAll();
    if (format.error != null) {
      o.logError('[format-first] ${format.error}');
      return 1;
    }
    if (format.changedPaths.isNotEmpty) {
      o.logError('format-first 改变了以下文件，提交被阻止。请检查并重新暂存/提交：');
      for (final p in format.changedPaths) {
        o.logError('  $p');
      }
      o.logError('本轮未运行任何检查；未自动 git add。');
      return 1;
    }
  }

  final staged = o.stagedFilesOverride ?? await stagedFiles(o.repoRoot);
  final plan = selectPlanForFiles(staged, index: index);
  printPlan(o, plan, title: 'pre-commit');

  if (o.dryRun) {
    o.log('[dry-run] 仅打印计划，未执行任何命令。');
    return 0;
  }

  for (final step in plan.steps) {
    if (step.kind == CommandKind.formatDart ||
        step.kind == CommandKind.formatRust) {
      continue; // format-first 已执行
    }
    final exit = await _runStep(o, step);
    if (exit != 0) return exit;
  }
  o.log('✅ pre-commit 门禁通过');
  return 0;
}

/// pre-push：format-first → 工作树一致性 → 缓存 → 完整 host suite。
Future<int> runPrePush(GateOptions o) async {
  final formatter = Formatter(
    repoRoot: o.repoRoot,
    runner: o.runner,
    timeout: o.stepTimeout,
  );

  if (!o.dryRun) {
    final format = await formatter.formatAll();
    if (format.error != null) {
      o.logError('[format-first] ${format.error}');
      return 1;
    }
    if (format.changedPaths.isNotEmpty) {
      o.logError('format-first 改变了以下文件，push 被阻止。请检查并提交：');
      for (final p in format.changedPaths) {
        o.logError('  $p');
      }
      return 1;
    }
  }

  final dirty = await dirtyTrackedSourceFiles(o.repoRoot);
  final untracked = await untrackedSourceFiles(o.repoRoot);
  final worktreeClean = dirty.isEmpty && untracked.isEmpty;
  if (!worktreeClean) {
    if (dirty.isNotEmpty) {
      o.logError('存在未提交的 tracked 源码（与 HEAD 不一致）：');
      for (final p in dirty) {
        o.logError('  $p');
      }
    }
    if (untracked.isNotEmpty) {
      o.logError('存在未跟踪源码：');
      for (final p in untracked) {
        o.logError('  $p');
      }
    }
    o.logError('pre-push 要求将测试的 tracked 源码与 HEAD 一致，且无未跟踪源码。');
    if (o.dryRun) {
      o.log('[dry-run] 仅提示，未阻止。');
    } else {
      o.logError('请先提交或清理后再 push。');
      return 1;
    }
  }

  // dry-run 且无显式注入时跳过 stdin 读取，避免交互终端挂起
  final refLines = (o.dryRun && o.pushRefLinesOverride == null)
      ? const <String>[]
      : (o.pushRefLinesOverride ?? await readStdinLines());
  for (final ref in refLines) {
    o.log('[push-ref] $ref');
    o.testLogWriter?.call('REFS $ref');
  }

  final head = await headSha(o.repoRoot);
  final fingerprint = computeGateFingerprint(o.repoRoot);

  if (!o.dryRun && !o.forceFullCheck && head != null) {
    final cache = await GateCache.forGitDir(o.repoRoot);
    final check = await cache.checkAsync(
      repoRoot: o.repoRoot,
      input: CacheCheckInput(
        headSha: head,
        fingerprint: fingerprint,
        localShas: localShasOf(refLines),
        worktreeClean: worktreeClean,
      ),
    );
    if (check.hit) {
      o.log('缓存命中（${check.reason}），跳过完整 suite。');
      o.testLogWriter?.call('CACHE HIT');
      o.log('✅ pre-push 门禁通过（缓存）');
      return 0;
    }
    o.log('缓存未命中（${check.reason}），执行完整 host suite。');
  }

  o.log('完整 host suite：');
  final code = await runFullSuite(o);
  if (code != 0) return code;

  if (!o.dryRun && head != null) {
    final cache = await GateCache.forGitDir(o.repoRoot);
    await cache.write(
      input: CacheCheckInput(
        headSha: head,
        fingerprint: fingerprint,
        localShas: localShasOf(refLines),
        worktreeClean: true,
      ),
    );
    o.log('缓存已写入 .git/cardmind_gate_cache.json（HEAD $head）');
  }
  o.log('✅ pre-push 门禁通过');
  return 0;
}

/// `full`：完整 host suite（真实执行一次；不做 dirty 阻止，但 format-first 阻止）。
Future<int> runFull(GateOptions o) async {
  final formatter = Formatter(
    repoRoot: o.repoRoot,
    runner: o.runner,
    timeout: o.stepTimeout,
  );

  if (!o.dryRun) {
    final format = await formatter.formatAll();
    if (format.error != null) {
      o.logError('[format-first] ${format.error}');
      return 1;
    }
    if (format.changedPaths.isNotEmpty) {
      o.logError('format-first 改变了以下文件，中止：');
      for (final p in format.changedPaths) {
        o.logError('  $p');
      }
      return 1;
    }
  }

  final code = await runFullSuite(o);
  if (code != 0) return code;

  if (!o.dryRun) {
    final head = await headSha(o.repoRoot);
    if (head != null) {
      final cache = await GateCache.forGitDir(o.repoRoot);
      await cache.write(
        input: CacheCheckInput(
          headSha: head,
          fingerprint: computeGateFingerprint(o.repoRoot),
          localShas: const <String>[],
          worktreeClean: true,
        ),
      );
      o.log('缓存已写入 .git/cardmind_gate_cache.json（HEAD $head）');
    }
  }
  o.log('✅ full 门禁通过');
  return 0;
}

/// 完整 host suite：docs lint → clippy → cargo test 全量 → build host lib →
/// 同步 host runtime 库 → codegen（改变生成文件则阻止）→ 再次 format-first（改变则阻止）→ analyze → flutter test 全量。
Future<int> runFullSuite(GateOptions o) async {
  final generatedBefore = snapshotGeneratedFiles(o.repoRoot);

  final steps = <GateCommand>[
    Commands.docsLint(),
    Commands.clippy(),
    Commands.rustFullTest(),
    Commands.hostBuildLib(),
    Commands.codegen(),
  ];
  for (final step in steps) {
    final exit = await _runStep(o, step);
    if (exit != 0) return exit;
  }

  // build 步骤成功后：把 host runtime 库同步到运行态路径。
  // 同步是 Dart 进程内文件操作，不走 runner、不受单步硬超时限制；
  // cargo build 本身已由 runner 超时保护。dry-run 只打印；testMode 跳过。
  if (o.dryRun) {
    String dest;
    try {
      dest = hostRuntimeSpec(detectHostPlatform()).runtimeDestRel;
    } on UnsupportedError {
      dest = '<unsupported host platform>';
    }
    o.log('  [dry-run] sync host runtime library: $dest');
  } else if (o.testMode) {
    o.log('  [test-mode] host runtime library sync skipped');
  } else {
    HostRuntimeSpec spec;
    try {
      spec = hostRuntimeSpec(detectHostPlatform());
    } on UnsupportedError catch (e) {
      o.logError('[fail] rust:build-lib sync: ${e.message}');
      return 1;
    }
    final err = syncHostRuntimeLibrary(o.repoRoot, spec.platform);
    if (err != null) {
      o.logError('[fail] rust:build-lib sync: $err');
      return 1;
    }
    o.log('  [ok] host runtime library synced: ${spec.runtimeDestRel}');
  }

  // codegen 后：生成内容变化 → 阻止，要求提交生成结果
  // （dry-run 不执行 codegen/format，不比较快照，避免副作用）
  if (o.dryRun) {
    o.log('  [dry-run] codegen change check');
    o.log('  [dry-run] format-first (after codegen)');
  } else {
    final generatedAfter = snapshotGeneratedFiles(o.repoRoot);
    final genChanged = _changedKeys(generatedBefore, generatedAfter);
    if (genChanged.isNotEmpty) {
      o.logError('flutter_rust_bridge_codegen generate 改变了生成文件，push 被阻止：');
      for (final p in genChanged) {
        o.logError('  $p');
      }
      o.logError('请提交生成结果后重试。');
      return 1;
    }

    // codegen 后再次 format-first
    final formatter = Formatter(
      repoRoot: o.repoRoot,
      runner: o.runner,
      timeout: o.stepTimeout,
    );
    final format2 = await formatter.formatAll();
    if (format2.error != null) {
      o.logError('[format-first #2] ${format2.error}');
      return 1;
    }
    if (format2.changedPaths.isNotEmpty) {
      o.logError('codegen 后 format-first 改变了文件，push 被阻止：');
      for (final p in format2.changedPaths) {
        o.logError('  $p');
      }
      return 1;
    }
  }

  final analyze = await _runStep(o, Commands.analyze());
  if (analyze != 0) return analyze;
  final test = await _runStep(o, Commands.flutterFullTest());
  if (test != 0) return test;
  return 0;
}

Future<int> _runStep(GateOptions o, GateCommand step) async {
  if (o.dryRun) {
    o.log('  [dry-run] $step');
    return 0;
  }
  o.log('==> $step');
  final wd = step.workingDirectory == null
      ? o.repoRoot
      : '${o.repoRoot}/${step.workingDirectory!.replaceAll(r'\', '/')}';
  final r = await o.runner(
    step.executable,
    step.arguments,
    workingDirectory: wd,
  );
  if (r.exitCode != 0) {
    final timeoutMark = r.timedOut
        ? ' TIMEOUT(${o.stepTimeout.inSeconds}s)'
        : '';
    o.logError(
      '[fail] ${step.label} exit=${r.exitCode}$timeoutMark '
      'elapsed=${r.elapsed.inSeconds}s',
    );
    o.logError(r.stderr);
    return r.timedOut ? CommandRunner.timeoutExitCode : r.exitCode;
  }
  return 0;
}

/// 打印结构化计划（不执行）。
void printPlan(GateOptions o, GatePlan plan, {required String title}) {
  o.log('CardMind git gate — $title');
  o.log('Files (${plan.files.length}):');
  for (final f in plan.files) {
    o.log('  $f');
  }
  final counts = plan.categoryCounts.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) => a.key.index.compareTo(b.key.index));
  o.log('Categories:');
  for (final c in counts) {
    o.log('  ${c.key.name}: ${c.value}');
  }
  o.log('Format-first:');
  o.log('  ${Commands.formatDart()}');
  o.log('  ${Commands.formatRust()}');
  o.log('Checks (${plan.steps.length - 2} commands, deduped):');
  for (final s in plan.steps.skip(2)) {
    o.log('  $s');
  }
}

List<String> _changedKeys(
  Map<String, String> before,
  Map<String, String> after,
) {
  final changed = <String>{};
  for (final entry in before.entries) {
    if (after[entry.key] != entry.value) {
      changed.add(entry.key);
    }
  }
  for (final key in after.keys) {
    if (!before.containsKey(key)) {
      changed.add(key);
    }
  }
  return changed.toList()..sort();
}

String _repoRelative(String repoRoot, String absPath) {
  final root = repoRoot.replaceAll(r'\', '/');
  var rel = absPath.replaceAll(r'\', '/');
  if (rel.startsWith(root)) {
    rel = rel.substring(root.length);
    if (rel.startsWith('/')) rel = rel.substring(1);
  }
  return rel;
}
