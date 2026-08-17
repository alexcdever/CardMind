// 纯 Dart 选择器 / 状态 / formatter / timeout 测试（不依赖真实 CardMind 业务代码）。
// 验收标准每条对应一个用例（用例名带编号与任务单五节对应）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/src/git_gate/cache.dart';
import '../tool/src/git_gate/command.dart';
import '../tool/src/git_gate/gate.dart';
import '../tool/src/git_gate/host_build.dart';
import '../tool/src/git_gate/runner.dart';
import '../tool/src/git_gate/selector.dart';

/// 与任务单五节对应的假测试索引（模拟 CardMind 现有测试资产）。
final TestIndex testIndex = TestIndex(
  flutterTestFiles: {
    'test/api_integration_test.dart',
    'test/frb_note_repository_test.dart',
    'test/receiver_store_borrow_test.dart',
    'test/pairing_accept_ui_test.dart',
    'test/pairing_log_events_test.dart',
    'test/pairing_mdns_widget_test.dart',
    'test/pairing_repository_test.dart',
    'test/sync_scheduler_test.dart',
    'test/sync_ui_widget_test.dart',
    'test/vertical_slice_widget_test.dart',
  },
  rustTestTargets: {
    'autosync_test',
    'connect_test',
    'debug_log_test',
    'discovery_test',
    'integration_test',
    'live_relay_test',
    'migration_test',
    'note_crdt_test',
    'pairing_test',
    'receiver_continuous_test',
    'relay_config_test',
    'store_test',
    'sync_service_test',
    'sync_test',
    'trash_test',
  },
);

/// 记录 runner 调用。
class FakeRunner {
  final List<RunnerCall> calls = <RunnerCall>[];
  final int exitCode;
  final RunnerResult? Function(RunnerCall call)? onCall;

  FakeRunner({this.exitCode = 0, this.onCall});

  Future<RunnerResult> call(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    final call = RunnerCall(executable, List.of(arguments), workingDirectory);
    calls.add(call);
    final custom = onCall?.call(call);
    if (custom != null) return custom;
    return RunnerResult(
      exitCode: exitCode,
      stdout: '',
      stderr: '',
      timedOut: false,
      elapsed: Duration.zero,
    );
  }

  List<String> get signatures =>
      calls.map((c) => '${c.executable}|${c.arguments.join(' ')}').toList();
}

class RunnerCall {
  RunnerCall(this.executable, this.arguments, this.workingDirectory);

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
}

List<CommandKind> kindsOf(GatePlan plan) =>
    plan.steps.map((s) => s.kind).toList();

List<String> argsOf(GatePlan plan, CommandKind kind) =>
    plan.steps.where((s) => s.kind == kind).expand((s) => s.arguments).toList();

void main() {
  group('selector', () {
    test('1 docs-only 计划只有 format + docs lint，无代码测试', () {
      final plan = selectPlanForFiles([
        'docs/standards/testing.md',
      ], index: testIndex);
      expect(kindsOf(plan), <CommandKind>[
        CommandKind.formatDart,
        CommandKind.formatRust,
        CommandKind.docsLint,
      ]);
    });

    test('2 单个 Flutter test 文件只选自身（同时含 analyze）', () {
      final plan = selectPlanForFiles([
        'test/vertical_slice_widget_test.dart',
      ], index: testIndex);
      expect(kindsOf(plan), <CommandKind>[
        CommandKind.formatDart,
        CommandKind.formatRust,
        CommandKind.analyze,
        CommandKind.flutterTest,
      ]);
      final testCmds = plan.steps
          .where((s) => s.kind == CommandKind.flutterTest)
          .toList();
      expect(testCmds, hasLength(1));
      expect(testCmds.single.arguments, <String>[
        'test',
        '--timeout',
        '3m',
        'test/vertical_slice_widget_test.dart',
      ]);
    });

    test('3 devices/pairing/scanner 选中全部 pairing widget/repository 测试', () {
      final plan = selectPlanForFiles([
        'lib/pages/devices_page.dart',
      ], index: testIndex);
      final flutterFiles = plan.steps
          .where((s) => s.kind == CommandKind.flutterTest)
          .expand((s) => s.arguments.skip(3))
          .toSet();
      expect(
        flutterFiles,
        containsAll(<String>[
          'test/pairing_accept_ui_test.dart',
          'test/pairing_log_events_test.dart',
          'test/pairing_mdns_widget_test.dart',
          'test/pairing_repository_test.dart',
          'test/sync_ui_widget_test.dart',
        ]),
      );
    });

    test('4 sync scheduler 选中 sync + receiver borrow 测试', () {
      final plan = selectPlanForFiles([
        'lib/src/rust/sync.dart',
      ], index: testIndex);
      final flutterFiles = plan.steps
          .where((s) => s.kind == CommandKind.flutterTest)
          .expand((s) => s.arguments.skip(3))
          .toSet();
      expect(flutterFiles, contains('test/sync_scheduler_test.dart'));
      expect(flutterFiles, contains('test/receiver_store_borrow_test.dart'));
      expect(flutterFiles, contains('test/sync_ui_widget_test.dart'));
    });

    test('5 单个 Rust test 文件选中对应 target', () {
      final plan = selectPlanForFiles([
        'rust-backend/tests/store_test.rs',
      ], index: testIndex);
      final rustTests = plan.steps
          .where((s) => s.kind == CommandKind.rustTest)
          .toList();
      expect(rustTests, hasLength(1));
      expect(rustTests.single.arguments, <String>[
        'test',
        '--test',
        'store_test',
      ]);
      expect(rustTests.single.workingDirectory, 'rust-backend');
      expect(kindsOf(plan), contains(CommandKind.clippy));
    });

    test('6 sync.rs 选中 sync/service/receiver/autosync 相关 targets', () {
      final plan = selectPlanForFiles([
        'rust-backend/src/sync.rs',
      ], index: testIndex);
      final targets = plan.steps
          .where((s) => s.kind == CommandKind.rustTest)
          .map((s) => s.arguments.last)
          .toSet();
      expect(
        targets,
        containsAll(<String>[
          'sync_test',
          'sync_service_test',
          'receiver_continuous_test',
          'autosync_test',
        ]),
      );
    });

    test('7 FRB 边界改动选中真实 FRB smoke + Rust', () {
      final plan = selectPlanForFiles([
        'rust-backend/src/api.rs',
      ], index: testIndex);
      final flutterFiles = plan.steps
          .where((s) => s.kind == CommandKind.flutterTest)
          .expand((s) => s.arguments.skip(3))
          .toSet();
      expect(
        flutterFiles,
        containsAll(<String>[
          'test/api_integration_test.dart',
          'test/frb_note_repository_test.dart',
          'test/receiver_store_borrow_test.dart',
        ]),
      );
      final rustTargets = plan.steps
          .where((s) => s.kind == CommandKind.rustTest)
          .map((s) => s.arguments.last)
          .toSet();
      expect(
        rustTargets,
        containsAll(<String>['store_test', 'note_crdt_test']),
      );
    });

    test('8 manifest/shared/unknown fail closed', () {
      // pubspec.* → Flutter 全量
      var plan = selectPlanForFiles(['pubspec.yaml'], index: testIndex);
      expect(kindsOf(plan), contains(CommandKind.analyze));
      expect(kindsOf(plan), contains(CommandKind.flutterTest));
      expect(kindsOf(plan), isNot(contains(CommandKind.clippy)));
      final pubspecFlutter = plan.steps
          .where((s) => s.kind == CommandKind.flutterTest)
          .single;
      expect(pubspecFlutter.arguments, <String>['test', '--timeout', '3m']);

      // Cargo.* → Rust 全量
      plan = selectPlanForFiles(['Cargo.toml'], index: testIndex);
      expect(kindsOf(plan), contains(CommandKind.clippy));
      final rustFullArgs = plan.steps
          .where((s) => s.kind == CommandKind.rustTest)
          .map((s) => s.arguments.join(' '))
          .toList();
      expect(rustFullArgs, contains('test --all-features --jobs 1'));
      expect(kindsOf(plan), isNot(contains(CommandKind.analyze)));

      // flutter_rust_bridge.yaml → 双栈全量
      plan = selectPlanForFiles(['flutter_rust_bridge.yaml'], index: testIndex);
      expect(kindsOf(plan), contains(CommandKind.clippy));
      expect(kindsOf(plan), contains(CommandKind.analyze));
      expect(
        plan.steps.where((s) => s.kind == CommandKind.flutterTest).length,
        1,
      );

      // 未知文件 → 双栈全量
      plan = selectPlanForFiles(['unknown.file'], index: testIndex);
      expect(kindsOf(plan), contains(CommandKind.clippy));
      expect(kindsOf(plan), contains(CommandKind.analyze));
      expect(
        plan.steps.where((s) => s.kind == CommandKind.flutterTest).length,
        1,
      );

      // 共享配置 analysis_options.yaml → 双栈全量
      plan = selectPlanForFiles(['analysis_options.yaml'], index: testIndex);
      expect(kindsOf(plan), contains(CommandKind.clippy));
      expect(kindsOf(plan), contains(CommandKind.analyze));

      // rust-backend/Cargo.toml 与 rust-backend/Cargo.lock → manifest，Rust 全量 fail-closed
      for (final cargoPath in <String>[
        'rust-backend/Cargo.toml',
        'rust-backend/Cargo.lock',
      ]) {
        expect(
          classifyPath(cargoPath),
          FileCategory.manifest,
          reason: '$cargoPath 应分类为 manifest',
        );
        final cargoPlan = selectPlanForFiles([cargoPath], index: testIndex);
        expect(
          kindsOf(cargoPlan),
          contains(CommandKind.clippy),
          reason: '$cargoPath 应触发 rust:clippy',
        );
        expect(
          kindsOf(cargoPlan),
          contains(CommandKind.rustTest),
          reason: '$cargoPath 应触发 rust:test',
        );
        final cargoRustFull = cargoPlan.steps
            .where((s) => s.kind == CommandKind.rustTest)
            .map((s) => s.arguments.join(' '))
            .toList();
        expect(
          cargoRustFull,
          contains('test --all-features --jobs 1'),
          reason: '$cargoPath 应升级 Rust 全量',
        );
        expect(
          kindsOf(cargoPlan),
          isNot(contains(CommandKind.analyze)),
          reason: '$cargoPath 不应触发 flutter:analyze',
        );
        expect(
          kindsOf(cargoPlan),
          isNot(contains(CommandKind.flutterTest)),
          reason: '$cargoPath 不应触发 flutter:test',
        );
      }

      // Windows 反斜杠 rust-backend\Cargo.toml 与 POSIX 完全一致
      final posixCargo = selectPlanForFiles([
        'rust-backend/Cargo.toml',
      ], index: testIndex);
      final windowsCargo = selectPlanForFiles([
        r'rust-backend\Cargo.toml',
      ], index: testIndex);
      expect(
        windowsCargo.steps.map((s) => s.signature).toList(),
        posixCargo.steps.map((s) => s.signature).toList(),
        reason: '反斜杠与正斜杠 Cargo manifest 计划必须一致',
      );
    });

    test('9 命令去重、稳定排序', () {
      final plan = selectPlanForFiles([
        'test/pairing_repository_test.dart',
        'lib/src/rust/discovery.dart',
        'rust-backend/src/api.rs',
      ], index: testIndex);
      final signatures = plan.steps.map((s) => s.signature).toList();
      expect(signatures.toSet().length, signatures.length, reason: '无重复命令');
      // 排序：kind 优先级非降序
      const order = <CommandKind>[
        CommandKind.formatDart,
        CommandKind.formatRust,
        CommandKind.docsLint,
        CommandKind.clippy,
        CommandKind.rustTest,
        CommandKind.buildLib,
        CommandKind.codegen,
        CommandKind.analyze,
        CommandKind.flutterTest,
      ];
      final kinds = kindsOf(plan);
      for (var i = 1; i < kinds.length; i++) {
        expect(
          order.indexOf(kinds[i - 1]) <= order.indexOf(kinds[i]),
          isTrue,
          reason: 'kind 顺序 ${kinds[i - 1]} 应不晚于 ${kinds[i]}',
        );
      }
    });

    test('10 Windows 反斜杠和 POSIX 斜杠归一化结果相同', () {
      final posix = selectPlanForFiles([
        'lib/pages/devices_page.dart',
      ], index: testIndex);
      final windows = selectPlanForFiles([
        r'lib\pages\devices_page.dart',
      ], index: testIndex);
      expect(
        windows.steps.map((s) => s.signature).toList(),
        posix.steps.map((s) => s.signature).toList(),
      );
    });
  });

  group('cache', () {
    test('11 exact HEAD + fingerprint 缓存命中/失效', () async {
      final dir = await Directory.systemTemp.createTemp('gate_cache_test_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final cache = GateCache.forRepo(dir.path);

      final base = CacheCheckInput(
        headSha: 'abc123',
        fingerprint: 'fp1',
        localShas: <String>['sha-a'],
        worktreeClean: true,
      );

      // 无缓存 → miss
      expect(cache.check(input: base).hit, isFalse);

      await cache.write(input: base);

      // 完全一致 → hit
      expect(cache.check(input: base).hit, isTrue);

      // HEAD 不同 → miss
      expect(
        cache
            .check(
              input: CacheCheckInput(
                headSha: 'def456',
                fingerprint: 'fp1',
                localShas: <String>['sha-a'],
                worktreeClean: true,
              ),
            )
            .hit,
        isFalse,
      );

      // fingerprint 不同 → miss
      expect(
        cache
            .check(
              input: CacheCheckInput(
                headSha: 'abc123',
                fingerprint: 'fp2',
                localShas: <String>['sha-a'],
                worktreeClean: true,
              ),
            )
            .hit,
        isFalse,
      );

      // localShas 不同 → miss
      expect(
        cache
            .check(
              input: CacheCheckInput(
                headSha: 'abc123',
                fingerprint: 'fp1',
                localShas: <String>['sha-b'],
                worktreeClean: true,
              ),
            )
            .hit,
        isFalse,
      );

      // 工作树不干净 → miss
      expect(
        cache
            .check(
              input: CacheCheckInput(
                headSha: 'abc123',
                fingerprint: 'fp1',
                localShas: <String>['sha-a'],
                worktreeClean: false,
              ),
            )
            .hit,
        isFalse,
      );
    });
  });

  group('timeout', () {
    test('12 3 分钟 timeout 状态与错误输出（注入短 timeout）', () async {
      final runner = CommandRunner(
        timeout: const Duration(milliseconds: 300),
        testMode: false,
      );
      final executable = Platform.isWindows ? 'cmd' : 'sleep';
      final args = Platform.isWindows
          ? <String>['/c', 'ping -n 6 127.0.0.1 > nul']
          : <String>['6'];
      final result = await runner.run(executable, args);
      expect(result.timedOut, isTrue);
      expect(result.exitCode, CommandRunner.timeoutExitCode);
      expect(result.elapsed.inMilliseconds, lessThan(5000));
      expect(
        result.stderr,
        contains('TIMEOUT'),
        reason: '超时错误输出应包含 TIMEOUT 标记',
      );
      expect(result.stderr, contains(executable), reason: '超时错误输出应包含命令名');
    });
  });

  group('format-first gate', () {
    Future<String> makeRepo({required bool withGit}) async {
      final dir = await Directory.systemTemp.createTemp('gate_repo_');
      addTearDown(() => dir.deleteSync(recursive: true));
      if (withGit) {
        await Process.run('git', ['init', '-q'], workingDirectory: dir.path);
        await Process.run('git', [
          'config',
          'user.email',
          'gate@test.local',
        ], workingDirectory: dir.path);
        await Process.run('git', [
          'config',
          'user.name',
          'Gate Test',
        ], workingDirectory: dir.path);
        await Process.run('git', [
          'config',
          'core.autocrlf',
          'false',
        ], workingDirectory: dir.path);
      }
      return dir.path;
    }

    GateOptions optionsFor(
      String repoRoot,
      FakeRunner runner, {
      List<String>? files,
      List<String>? pushRefLines,
      List<String>? logLines,
      List<String>? errorLines,
    }) {
      final logs = logLines ?? <String>[];
      final errors = errorLines ?? <String>[];
      return GateOptions(
        repoRoot: repoRoot,
        runner: runner.call,
        stepTimeout: const Duration(seconds: 30),
        log: logs.add,
        logError: errors.add,
        index: testIndex,
        stagedFilesOverride: files,
        pushRefLinesOverride: pushRefLines,
        testMode: true,
      );
    }

    /// 当前测试进程的 dart 可执行文件。
    /// flutter test 下 Platform.resolvedExecutable 是 flutter_tester，
    /// 从 SDK 布局推导真实 dart.exe（.../bin/cache/dart-sdk/bin/dart.exe）。
    String dartExe() {
      final resolved = Platform.resolvedExecutable.replaceAll(r'\', '/');
      final marker = '/cache/artifacts/engine/';
      final idx = resolved.indexOf(marker);
      if (resolved.contains('flutter_tester') && idx != -1) {
        final flutterBin = resolved.substring(0, idx);
        return '$flutterBin/cache/dart-sdk/bin/dart.exe';
      }
      return 'dart';
    }

    test('13 Dart 未格式化文件被写回、报告 changed、后续测试 runner 未调用', () async {
      final repo = await makeRepo(withGit: false);
      final badDart = File('$repo/lib/bad.dart');
      badDart.parent.createSync(recursive: true);
      const unformatted = 'void main(){print("x");}';
      badDart.writeAsStringSync(unformatted);

      final runner = FakeRunner(
        onCall: (call) {
          // 仅真实执行 dart format，模拟 formatter 写回
          if (call.executable == 'dart' && call.arguments.first == 'format') {
            final sw = Stopwatch()..start();
            final r = Process.runSync(
              dartExe(),
              call.arguments,
              workingDirectory: call.workingDirectory,
            );
            sw.stop();
            return RunnerResult(
              exitCode: r.exitCode,
              stdout: r.stdout.toString(),
              stderr: r.stderr.toString(),
              timedOut: false,
              elapsed: Duration.zero,
            );
          }
          return null;
        },
      );
      final errors = <String>[];
      final exit = await runPreCommit(
        optionsFor(
          repo,
          runner,
          files: <String>['lib/bad.dart'],
          errorLines: errors,
        ),
      );

      expect(exit, isNot(0), reason: 'format 改变文件必须阻止提交');
      expect(
        File('$repo/lib/bad.dart').readAsStringSync(),
        isNot(unformatted),
        reason: '格式化必须真的写入文件',
      );
      expect(errors.join('\n'), contains('lib/bad.dart'));
      // 后续测试 runner 未调用（无 analyze / test / clippy）
      final called = runner.signatures;
      expect(called.any((c) => c.contains('analyze')), isFalse);
      expect(called.any((c) => c.contains('clippy')), isFalse);
      expect(called.any((c) => c.contains('test')), isFalse);
    });

    test('14 Rust 未格式化文件同样阻止（fake runner 模拟写回）', () async {
      final repo = await makeRepo(withGit: false);
      final badRs = File('$repo/rust-backend/src/bad.rs');
      badRs.parent.createSync(recursive: true);
      badRs.writeAsStringSync('pub fn x(){}');

      final runner = FakeRunner(
        onCall: (call) {
          // 模拟 cargo fmt 写回内容
          if (call.executable == 'cargo' &&
              call.arguments.join(' ') == 'fmt --all') {
            badRs.writeAsStringSync('pub fn x() {}\n');
            return RunnerResult(
              exitCode: 0,
              stdout: 'formatted',
              stderr: '',
              timedOut: false,
              elapsed: Duration.zero,
            );
          }
          return null;
        },
      );
      final errors = <String>[];
      final exit = await runPreCommit(
        optionsFor(
          repo,
          runner,
          files: <String>['rust-backend/src/bad.rs'],
          errorLines: errors,
        ),
      );

      expect(exit, isNot(0));
      expect(errors.join('\n'), contains('rust-backend/src/bad.rs'));
      final called = runner.signatures;
      expect(called.any((c) => c.contains('analyze')), isFalse);
      expect(called.any((c) => c.contains('test')), isFalse);
    });

    test('15 formatter 无变化才继续', () async {
      final repo = await makeRepo(withGit: false);
      final okDart = File('$repo/lib/ok.dart');
      okDart.parent.createSync(recursive: true);
      okDart.writeAsStringSync('void main() {\n  print("x");\n}\n');

      final runner = FakeRunner();
      final exit = await runPreCommit(
        optionsFor(repo, runner, files: <String>['lib/ok.dart']),
      );
      expect(exit, 0);
      final called = runner.signatures;
      expect(called.first, contains('format'));
      expect(
        called.any((c) => c.startsWith('flutter|analyze')),
        isTrue,
        reason: '格式化无变化后应继续执行 analyze',
      );
    });

    test('16 partial staging 不会自动 git add、也不改 index', () async {
      final repo = await makeRepo(withGit: true);
      final badDart = File('$repo/lib/bad.dart');
      badDart.parent.createSync(recursive: true);
      const unformatted = 'void main(){print("x");}';
      badDart.writeAsStringSync(unformatted);
      await Process.run('git', ['add', 'lib/bad.dart'], workingDirectory: repo);
      // 同一文件再追加 unstaged 修改
      badDart.writeAsStringSync('$unformatted\n// unstaged\n');

      final indexBefore = (await Process.run('git', [
        'rev-parse',
        ':lib/bad.dart',
      ], workingDirectory: repo)).stdout.toString().trim();

      final runner = FakeRunner(
        onCall: (call) {
          if (call.executable == 'dart' && call.arguments.first == 'format') {
            final r = Process.runSync(
              dartExe(),
              call.arguments,
              workingDirectory: call.workingDirectory,
            );
            return RunnerResult(
              exitCode: r.exitCode,
              stdout: r.stdout.toString(),
              stderr: r.stderr.toString(),
              timedOut: false,
              elapsed: Duration.zero,
            );
          }
          return null;
        },
      );
      final exit = await runPreCommit(optionsFor(repo, runner));

      expect(exit, isNot(0), reason: 'format 改变文件必须阻止提交');
      final indexAfter = (await Process.run('git', [
        'rev-parse',
        ':lib/bad.dart',
      ], workingDirectory: repo)).stdout.toString().trim();
      expect(indexAfter, indexBefore, reason: '不得自动修改 index');
      expect(runner.signatures.any((c) => c.contains('add')), isFalse);
    });

    test(
      '17 pre-push 的 dirty tracked source / untracked source 会阻止完整 suite',
      () async {
        // Case A: tracked 文件有未提交修改
        var repo = await makeRepo(withGit: true);
        var aDart = File('$repo/lib/a.dart');
        aDart.parent.createSync(recursive: true);
        aDart.writeAsStringSync('void main() {}\n');
        await Process.run('git', ['add', 'lib/a.dart'], workingDirectory: repo);
        await Process.run('git', [
          'commit',
          '-q',
          '-m',
          'init',
        ], workingDirectory: repo);
        aDart.writeAsStringSync('void main() {\n  print(1);\n}\n'); // dirty

        var runner = FakeRunner();
        var exit = await runPrePush(
          optionsFor(
            repo,
            runner,
            pushRefLines: <String>[
              'refs/heads/main deadbeef refs/heads/main 0000000',
            ],
          ),
        );
        expect(exit, isNot(0), reason: 'dirty tracked source 必须阻止 push');
        expect(
          runner.signatures.any(
            (c) => c.contains('clippy') || c.contains('test'),
          ),
          isFalse,
          reason: '阻止后不得运行完整 suite',
        );

        // Case B: untracked source 文件
        repo = await makeRepo(withGit: true);
        aDart = File('$repo/lib/a.dart');
        aDart.parent.createSync(recursive: true);
        aDart.writeAsStringSync('void main() {}\n');
        await Process.run('git', ['add', 'lib/a.dart'], workingDirectory: repo);
        await Process.run('git', [
          'commit',
          '-q',
          '-m',
          'init',
        ], workingDirectory: repo);
        File('$repo/lib/untracked.dart').writeAsStringSync('void main() {}\n');

        runner = FakeRunner();
        exit = await runPrePush(
          optionsFor(
            repo,
            runner,
            pushRefLines: <String>[
              'refs/heads/main deadbeef refs/heads/main 0000000',
            ],
          ),
        );
        expect(exit, isNot(0), reason: 'untracked source 必须阻止 push');
        expect(
          runner.signatures.any(
            (c) => c.contains('clippy') || c.contains('test'),
          ),
          isFalse,
        );

        // Case C: 仅 untracked 文档不阻止，suite 正常运行
        repo = await makeRepo(withGit: true);
        aDart = File('$repo/lib/a.dart');
        aDart.parent.createSync(recursive: true);
        aDart.writeAsStringSync('void main() {}\n');
        await Process.run('git', ['add', 'lib/a.dart'], workingDirectory: repo);
        await Process.run('git', [
          'commit',
          '-q',
          '-m',
          'init',
        ], workingDirectory: repo);
        File('$repo/docs/new.md').parent.createSync(recursive: true);
        File('$repo/docs/new.md').writeAsStringSync('# new doc\n');

        runner = FakeRunner();
        exit = await runPrePush(
          optionsFor(
            repo,
            runner,
            pushRefLines: <String>[
              'refs/heads/main deadbeef refs/heads/main 0000000',
            ],
          ),
        );
        expect(exit, 0, reason: 'untracked 文档不应阻止 push');
        expect(
          runner.signatures.any(
            (c) => c.contains('clippy') || c.contains('test'),
          ),
          isTrue,
          reason: '干净状态下应执行完整 suite',
        );
      },
    );

    test('18 Markdown-only 仍先调用 formatter', () async {
      final repo = await makeRepo(withGit: false);
      // 创建源码目录，让 formatter 真正被调用（docs 变更也先 format）
      Directory('$repo/lib').createSync(recursive: true);
      File(
        '$repo/lib/ok.dart',
      ).writeAsStringSync('void main() {\n  print("x");\n}\n');
      Directory('$repo/rust-backend/src').createSync(recursive: true);
      File('$repo/rust-backend/src/ok.rs').writeAsStringSync('pub fn x() {}\n');

      final runner = FakeRunner();
      final exit = await runPreCommit(
        optionsFor(repo, runner, files: <String>['docs/a.md']),
      );
      expect(exit, 0);
      final called = runner.signatures;
      expect(called.length, greaterThanOrEqualTo(3));
      expect(called[0], contains('dart|format'), reason: '第一个必须是 dart format');
      expect(called[1], contains('cargo|fmt'), reason: '第二个必须是 cargo fmt');
      expect(
        called.any((c) => c.contains('markdown_references_linter')),
        isTrue,
        reason: 'docs-only 仍要跑 markdown lint',
      );
      expect(called.any((c) => c.contains('clippy')), isFalse);
      expect(called.any((c) => c.contains('flutter|analyze')), isFalse);
      expect(called.any((c) => c.contains('flutter|test')), isFalse);
    });
  });

  group('host build', () {
    test('23 hostBuildLib 命令规格（跨平台 cargo build --release）', () {
      final cmd = Commands.hostBuildLib();
      expect(cmd.executable, 'cargo');
      expect(cmd.arguments, <String>['build', '--release']);
      expect(cmd.workingDirectory, 'rust-backend');
      expect(cmd.kind, CommandKind.buildLib);
      expect(cmd.label, 'rust:build-lib');
      // 不再调用 tool/build.dart（其硬编码 macOS dylib 路径，Windows 必失败）
      final isDartBuildDart =
          cmd.executable == 'dart' && cmd.arguments.contains('tool/build.dart');
      expect(isDartBuildDart, isFalse);
    });

    test('24 hostRuntimeSpec 三平台 source/dest 路径', () {
      final windows = hostRuntimeSpec(HostBuildPlatform.windows);
      expect(windows.platform, HostBuildPlatform.windows);
      expect(
        windows.cargoSourceRel,
        'rust-backend/target/release/cardmind_backend.dll',
      );
      expect(
        windows.runtimeDestRel,
        'build/windows/x64/runner/Release/cardmind_backend.dll',
      );

      final macos = hostRuntimeSpec(HostBuildPlatform.macos);
      expect(macos.platform, HostBuildPlatform.macos);
      expect(
        macos.cargoSourceRel,
        'rust-backend/target/release/libcardmind_backend.dylib',
      );
      expect(
        macos.runtimeDestRel,
        'build/native/macos/libcardmind_backend.dylib',
      );

      final linux = hostRuntimeSpec(HostBuildPlatform.linux);
      expect(linux.platform, HostBuildPlatform.linux);
      expect(
        linux.cargoSourceRel,
        'rust-backend/target/release/libcardmind_backend.so',
      );
      expect(
        linux.runtimeDestRel,
        'build/linux/x64/release/bundle/lib/libcardmind_backend.so',
      );
    });

    test('25 真实同步：把 cargo 产物复制到运行态路径（Windows spec）', () {
      final root = Directory.systemTemp.createTempSync('gate_host_build_');
      addTearDown(() {
        try {
          root.deleteSync(recursive: true);
        } on FileSystemException {
          // 忽略清理失败
        }
      });
      final spec = hostRuntimeSpec(HostBuildPlatform.windows);
      final source = File('${root.path}/${spec.cargoSourceRel}');
      source.parent.createSync(recursive: true);
      const content = 'fake cardmind_backend.dll content';
      source.writeAsStringSync(content);

      final err = syncHostRuntimeLibrary(root.path, HostBuildPlatform.windows);
      expect(err, isNull, reason: '同步应成功（无错误串）');

      final dest = File('${root.path}/${spec.runtimeDestRel}');
      expect(dest.existsSync(), isTrue, reason: 'dest 应存在');
      expect(dest.readAsStringSync(), content, reason: '内容应与源一致');
    });

    test('26 已存在 dest 会被替换', () {
      final root = Directory.systemTemp.createTempSync('gate_host_build_');
      addTearDown(() {
        try {
          root.deleteSync(recursive: true);
        } on FileSystemException {
          // 忽略清理失败
        }
      });
      final spec = hostRuntimeSpec(HostBuildPlatform.windows);
      final source = File('${root.path}/${spec.cargoSourceRel}');
      source.parent.createSync(recursive: true);
      source.writeAsStringSync('new content');
      final dest = File('${root.path}/${spec.runtimeDestRel}');
      dest.parent.createSync(recursive: true);
      dest.writeAsStringSync('old content');

      final err = syncHostRuntimeLibrary(root.path, HostBuildPlatform.windows);
      expect(err, isNull, reason: '同步应成功（无错误串）');
      expect(dest.readAsStringSync(), 'new content', reason: '旧 dest 应被新源内容替换');
    });

    test('27 源缺失返回含源绝对路径的错误串', () {
      final root = Directory.systemTemp.createTempSync('gate_host_build_');
      addTearDown(() {
        try {
          root.deleteSync(recursive: true);
        } on FileSystemException {
          // 忽略清理失败
        }
      });
      final err = syncHostRuntimeLibrary(root.path, HostBuildPlatform.windows);
      expect(err, isNotNull, reason: '源缺失必须返回错误串');
      expect(err, contains('cardmind_backend.dll'));
      expect(
        err,
        contains(
          '${root.path.replaceAll(r'\', '/')}/rust-backend/target/release/cardmind_backend.dll',
        ),
        reason: '错误串应含源绝对路径',
      );
    });

    test('28 反斜杠 repoRoot 也能成功同步（路径归一化兼容）', () {
      final root = Directory.systemTemp.createTempSync('gate_host_build_');
      addTearDown(() {
        try {
          root.deleteSync(recursive: true);
        } on FileSystemException {
          // 忽略清理失败
        }
      });
      final spec = hostRuntimeSpec(HostBuildPlatform.windows);
      final source = File('${root.path}/${spec.cargoSourceRel}');
      source.parent.createSync(recursive: true);
      source.writeAsStringSync('content');
      final backslashRoot = root.path.replaceAll('/', r'\');

      final err = syncHostRuntimeLibrary(
        backslashRoot,
        HostBuildPlatform.windows,
      );
      expect(err, isNull, reason: '反斜杠 repoRoot 也应成功同步');

      final dest = File('${root.path}/${spec.runtimeDestRel}');
      expect(dest.existsSync(), isTrue, reason: 'dest 应存在');
      expect(dest.readAsStringSync(), 'content');
    });
  });
}
