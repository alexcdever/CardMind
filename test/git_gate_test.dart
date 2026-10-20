// 纯 Dart 选择器 / 状态 / formatter / timeout 测试（不依赖真实 CardMind 业务代码）。
// 验收标准每条对应一个用例（用例名带编号与任务单五节对应）。
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';

import '../tool/src/git_gate/cache.dart';
import '../tool/src/git_gate/command.dart';
import '../tool/src/git_gate/gate.dart';
import '../tool/src/git_gate/git.dart';
import '../tool/src/git_gate/host_build.dart';
import '../tool/src/git_gate/runner.dart';
import '../tool/src/git_gate/selector.dart';

/// 与任务单五节对应的假测试索引（模拟 CardMind 现有测试资产）。
///
/// flutterTestFiles 必须与 `test/` 下真实清单一致：所有 `_test.dart`
/// （含 `test/services/`、`test/models/` 子目录）+ `test/support/` 下的
/// 共享 fake（非 `_test.dart`，分类为 dartBusiness，但仍列入索引供
/// `_maybePairing`/`_maybeSync`/`_relatedDartTests` 匹配）。
/// rustTestTargets 必须与 `rust-backend/tests/` 下所有 `*_test.rs` 的
/// stem 集合一致。supportImporters 由 `scanTestIndex` 读测试文件内容
/// 派生（`import 'support/xxx.dart'`），fixture 通过 setUpAll 真实扫描
/// 注入——不手抄，手抄就是本任务要消灭的漂移源。
late final TestIndex testIndex;

final TestIndex _staticTestIndex = TestIndex(
  flutterTestFiles: {
    'test/adr_0008_test.dart',
    'test/agents_md_test.dart',
    'test/api_integration_test.dart',
    'test/build_lib_crossplatform_test.dart',
    'test/build_tool_test.dart',
    'test/cardmind_theme_test.dart',
    'test/debug_log_file_test.dart',
    'test/debug_log_test.dart',
    'test/design_tokens_doc_test.dart',
    'test/device_name_edit_test.dart',
    'test/devices_page_widget_test.dart',
    'test/docs_dir_test.dart',
    'test/editor_page_widget_test.dart',
    'test/feature_test_file_arg_test.dart',
    'test/feature_test_security_test.dart',
    'test/frb_note_repository_test.dart',
    'test/git_gate_hook_integration_test.dart',
    'test/git_gate_test.dart',
    'test/knowledge_base_widget_test.dart',
    'test/macos_desktop_support_test.dart',
    'test/markdown_references_test.dart',
    'test/mobile_ui_test.dart',
    'test/models/update_manifest_test.dart',
    'test/note_list_page_widget_test.dart',
    'test/pairing_accept_ui_test.dart',
    'test/pairing_credential_repository_test.dart',
    'test/pairing_credential_ui_test.dart',
    'test/pairing_log_events_test.dart',
    'test/pairing_mdns_widget_test.dart',
    'test/pairing_repository_test.dart',
    'test/platform_log_capture_test.dart',
    'test/product_doc_test.dart',
    'test/quality_coverage_reuse_test.dart',
    'test/quality_frb_prep_test.dart',
    'test/receiver_store_borrow_test.dart',
    'test/release_workflow_test.dart',
    'test/rust_library_loader_test.dart',
    'test/services/app_settings_service_test.dart',
    'test/services/http_proxy_policy_test.dart',
    'test/services/platform_update_installer_test.dart',
    'test/services/update_download_manager_test.dart',
    'test/services/update_downloader_test.dart',
    'test/services/update_service_test.dart',
    'test/settings_page_test.dart',
    'test/spec_lifecycle_doc_test.dart',
    // test/support/ 下的共享 fake：不是 _test.dart（分类为 dartBusiness），
    // 但列入索引——它们是被测资产的依赖方，供关键词路由与 stem 兜底匹配。
    'test/support/credential_ui_repository.dart',
    'test/support/devices_repository.dart',
    'test/support/doc_helpers.dart',
    'test/support/memory_note_repository.dart',
    'test/support/note_repository_stub.dart',
    'test/test_boundary_scanner_coverage_absence_test.dart',
    'test/test_boundary_scanner_rust_test.dart',
    'test/sync_network_doc_test.dart',
    'test/sync_scheduler_test.dart',
    'test/sync_ui_widget_test.dart',
    'test/trash_page_widget_test.dart',
    'test/ui_style_guide_doc_test.dart',
    'test/widget_test.dart',
  },
  rustTestTargets: {
    'autosync_test',
    'connect_test',
    'debug_log_test',
    'device_name_test',
    'discovery_test',
    'live_relay_test',
    'migration_test',
    'net_env_policy_test',
    'note_crdt_test',
    'pairing_credential_test',
    'pairing_test',
    'receiver_continuous_test',
    'relay_config_test',
    'security_sync_test',
    'store_test',
    'sync_service_test',
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

/// 计划里的 flutter test 命令（合批后应为 0 或 1 条）。
List<GateCommand> flutterTestCmdsOf(GatePlan plan) =>
    plan.steps.where((s) => s.kind == CommandKind.flutterTest).toList();

/// flutter test 命令携带的测试文件（跳过 `test --timeout 5m` 前缀）。
List<String> flutterTestFilesOfCmd(GateCommand cmd) =>
    cmd.arguments.skip(3).toList();

void main() {
  // fixture TestIndex 由生产 scanTestIndex 真实扫描填充（repoRoot =
  // 当前工作目录 = 仓库根）。flutterTestFiles/rustTestTargets 与
  // _staticTestIndex 的手抄清单交叉校验（测试 11 用 git ls-files 为
  // 真相源复核两者）；supportImporters 只能由扫描内容派生，无法手抄。
  setUpAll(() async {
    final scanned = await scanTestIndex(Directory.current.path);
    expect(
      scanned.flutterTestFiles,
      _staticTestIndex.flutterTestFiles,
      reason:
          'scanTestIndex 的 flutterTestFiles 与 fixture 不一致：'
          '缺 ${_staticTestIndex.flutterTestFiles.difference(scanned.flutterTestFiles)} / '
          '多 ${scanned.flutterTestFiles.difference(_staticTestIndex.flutterTestFiles)}',
    );
    expect(
      scanned.rustTestTargets,
      _staticTestIndex.rustTestTargets,
      reason:
          'scanTestIndex 的 rustTestTargets 与 fixture 不一致：'
          '缺 ${_staticTestIndex.rustTestTargets.difference(scanned.rustTestTargets)} / '
          '多 ${scanned.rustTestTargets.difference(_staticTestIndex.rustTestTargets)}',
    );
    testIndex = scanned;
  });

  group('selector', () {
    test('1 docs-only 计划 = format + docs lint + 全部文档契约测试', () {
      final plan = selectPlanForFiles([
        'docs/standards/testing.md',
      ], index: testIndex);
      expect(kindsOf(plan), <CommandKind>[
        CommandKind.formatDart,
        CommandKind.formatRust,
        CommandKind.docsLint,
        CommandKind.flutterTest,
      ]);
      // 只有文档契约测试（9 个合批一条），不跑 analyze、不跑全量。
      final cmds = flutterTestCmdsOf(plan);
      expect(cmds, hasLength(1));
      expect(cmds.single.label, 'flutter:test');
      expect(flutterTestFilesOfCmd(cmds.single), hasLength(9));
      expect(
        kindsOf(plan),
        isNot(contains(CommandKind.analyze)),
        reason: '文档改动不需要 flutter analyze',
      );
    });

    test('2 单个 Flutter test 文件只选自身（同时含 analyze）', () {
      final plan = selectPlanForFiles([
        'test/editor_page_widget_test.dart',
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
        '5m',
        'test/editor_page_widget_test.dart',
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

    test('5b tests/common/mod.rs 是共享辅助，不生成 --test mod（fail-closed 全量）', () {
      // tests/common/mod.rs 不是 cargo test target（被各 *_test.rs 用
      // `mod common;` 引入的模块）；改它只能跑 clippy + Rust 全量
      // （fail-closed 覆盖所有引用方），绝不能生成不存在的 target `mod`
      // ——cargo test --test mod 必然失败，曾迫使任务 --no-verify 绕过门禁。
      final plan = selectPlanForFiles([
        'rust-backend/tests/common/mod.rs',
      ], index: testIndex);
      expect(kindsOf(plan), contains(CommandKind.clippy));
      final rustArgs = plan.steps
          .where((s) => s.kind == CommandKind.rustTest)
          .expand((s) => s.arguments)
          .toList();
      expect(
        rustArgs.where((a) => a == 'mod'),
        isEmpty,
        reason: '不得生成 cargo test --test mod（cargo 无此 target）',
      );
      expect(
        rustArgs.join(' '),
        contains('test --all-features --jobs 1'),
        reason: '辅助文件无明确 target 映射，应升级 Rust 全量测试',
      );
    });

    test('5c tests/<dir>/main.rs 是 target <dir>，不是 --test main', () {
      // cargo 规则：tests/foo/main.rs → target foo（目录名），文件名 main
      // 不是 target stem。当前仓库无此形态，用纯逻辑测试钉住规则防回退。
      final plan = selectPlanForFiles([
        'rust-backend/tests/pairing/main.rs',
      ], index: testIndex);
      final rustArgs = plan.steps
          .where((s) => s.kind == CommandKind.rustTest)
          .expand((s) => s.arguments)
          .toList();
      expect(rustArgs.where((a) => a == 'main'), isEmpty);
      expect(
        rustArgs,
        containsAllInOrder(<String>['test', '--test', 'pairing']),
        reason: 'tests/pairing/main.rs 应映射到 target pairing',
      );
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
      expect(pubspecFlutter.arguments, <String>['test', '--timeout', '5m']);

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

    Set<String> flutterTestFilesOf(GatePlan plan) => plan.steps
        .where((s) => s.kind == CommandKind.flutterTest)
        .expand((s) => s.arguments.skip(3))
        .toSet();

    test(
      '10b test/support memory_note_repository 按真实 import 方路由（非 pairing 集群）',
      () {
        final plan = selectPlanForFiles([
          'test/support/memory_note_repository.dart',
        ], index: testIndex);
        final files = flutterTestFilesOf(plan);
        // 真实 import 方（git grep "import 'support" test/）= 4 个 note widget 测试。
        expect(
          files,
          containsAll(<String>[
            'test/editor_page_widget_test.dart',
            'test/knowledge_base_widget_test.dart',
            'test/note_list_page_widget_test.dart',
            'test/trash_page_widget_test.dart',
          ]),
        );
        // 不再错配 pairing 集群。
        final pairingSelected = files.where(
          (f) => f.contains('pairing') || f.contains('device'),
        );
        expect(
          pairingSelected,
          isEmpty,
          reason:
              'memory_note_repository 不应路由到 pairing/device 测试: $pairingSelected',
        );
      },
    );

    test('10c test/support devices_repository 按真实 import 方路由', () {
      final plan = selectPlanForFiles([
        'test/support/devices_repository.dart',
      ], index: testIndex);
      expect(
        flutterTestFilesOf(plan),
        containsAll(<String>[
          'test/devices_page_widget_test.dart',
          'test/note_list_page_widget_test.dart',
          'test/sync_ui_widget_test.dart',
        ]),
      );
    });

    test('10d test/support credential_ui_repository 按真实 import 方路由', () {
      final plan = selectPlanForFiles([
        'test/support/credential_ui_repository.dart',
      ], index: testIndex);
      expect(
        flutterTestFilesOf(plan),
        containsAll(<String>[
          'test/devices_page_widget_test.dart',
          'test/pairing_credential_ui_test.dart',
        ]),
      );
    });

    test('10e test/support doc_helpers 按真实 import 方路由', () {
      final plan = selectPlanForFiles([
        'test/support/doc_helpers.dart',
      ], index: testIndex);
      expect(
        flutterTestFilesOf(plan),
        containsAll(<String>[
          'test/adr_0008_test.dart',
          'test/agents_md_test.dart',
          'test/docs_dir_test.dart',
          'test/product_doc_test.dart',
        ]),
      );
    });

    test('10f tool/*.yaml 映射到 boundary scanner 测试（非双栈全量）', () {
      expect(
        classifyPath('tool/test_boundary_config.yaml'),
        FileCategory.boundaryToolConfig,
        reason: 'tool/*.yaml 应有独立分类，不是 sharedConfig',
      );
      final plan = selectPlanForFiles([
        'tool/test_boundary_config.yaml',
      ], index: testIndex);
      expect(
        plan.steps
            .where((s) => s.kind == CommandKind.flutterTest)
            .map((s) => s.arguments.last),
        contains('test/test_boundary_scanner_rust_test.dart'),
        reason: '应选中 boundary scanner 测试',
      );
      // 不升级双栈全量。
      expect(kindsOf(plan), isNot(contains(CommandKind.clippy)));
      expect(kindsOf(plan), isNot(contains(CommandKind.rustTest)));
      expect(
        plan.steps.where((s) => s.label == 'flutter:test:full'),
        isEmpty,
        reason: 'tool/*.yaml 不得触发 flutter:test:full',
      );
    });

    test('10g .github/workflows/*.yml 归 ciWorkflow（非双栈全量）', () {
      expect(
        classifyPath('.github/workflows/manual-build-artifacts.yml'),
        FileCategory.ciWorkflow,
      );
      expect(classifyPath('.github/workflows/ci.yml'), FileCategory.ciWorkflow);
      final plan = selectPlanForFiles([
        '.github/workflows/manual-build-artifacts.yml',
      ], index: testIndex);
      expect(kindsOf(plan), isNot(contains(CommandKind.clippy)));
      expect(kindsOf(plan), isNot(contains(CommandKind.rustTest)));
      expect(plan.steps.where((s) => s.label == 'flutter:test:full'), isEmpty);
      expect(
        plan.steps
            .where((s) => s.kind == CommandKind.flutterTest)
            .map((s) => s.arguments.last),
        contains('test/release_workflow_test.dart'),
        reason: 'workflow 改动应选中 release_workflow_test',
      );
    });

    test('10h 根级 yaml 仍归 sharedConfig（全量 fail-closed）', () {
      expect(classifyPath('.gitignore'), FileCategory.sharedConfig);
      // 未知目录的 yaml 走 unknown 兜底（fail-closed 双栈全量）。
      expect(classifyPath('docs/foo.yaml'), FileCategory.unknown);
    });

    test(
      '10i rust-backend/tool/**.rs 归 rustTool（clippy + rustToolTest，无 flutter）',
      () {
        expect(
          classifyPath('rust-backend/tool/boundary_scanner/src/main.rs'),
          FileCategory.rustTool,
          reason: 'rust-backend/tool/ 下的 .rs 应有独立分类，不落 unknown',
        );
        final plan = selectPlanForFiles([
          'rust-backend/tool/boundary_scanner/src/main.rs',
        ], index: testIndex);
        expect(
          kindsOf(plan),
          contains(CommandKind.clippy),
          reason: 'rustTool 应跑 clippy（workspace 覆盖 boundary_scanner）',
        );
        // 源码改动也跑该 crate 自身 cargo test（rustToolTest），不只是
        // manifest 才跑。boundary_scanner/src/main.rs → package boundary_scanner。
        expect(
          plan.steps.any(
            (s) =>
                s.kind == CommandKind.rustTest &&
                s.arguments.contains('boundary_scanner'),
          ),
          isTrue,
          reason: 'rustTool 源码改动应跑 cargo test -p boundary_scanner',
        );
        // 不升级 rust:test:full、不跑 analyze/flutter。
        expect(
          plan.steps.any((s) => s.label == 'rust:test:full'),
          isFalse,
          reason: 'rustTool 不升级 rust:test:full',
        );
        expect(kindsOf(plan), isNot(contains(CommandKind.analyze)));
        expect(kindsOf(plan), isNot(contains(CommandKind.flutterTest)));
      },
    );

    test('10i2 rust-backend/tool/foo.rs（无子目录）归 rustTool，rustToolTest 跳过', () {
      // 不在任何 crate 子目录的顶层 .rs：_rustToolPackage 返回 null，
      // rustToolTest 应被跳过（null 守卫），仍只跑 clippy。
      expect(classifyPath('rust-backend/tool/foo.rs'), FileCategory.rustTool);
      final plan = selectPlanForFiles([
        'rust-backend/tool/foo.rs',
      ], index: testIndex);
      expect(kindsOf(plan), contains(CommandKind.clippy));
      expect(
        plan.steps.any((s) => s.kind == CommandKind.rustTest),
        isFalse,
        reason: '无 crate 子目录时 rustToolTest 应跳过',
      );
      expect(kindsOf(plan), isNot(contains(CommandKind.flutterTest)));
    });

    test('10j rust-backend/tool 子树 manifest → clippy + 自身 cargo test', () {
      expect(
        classifyPath('rust-backend/tool/boundary_scanner/Cargo.toml'),
        FileCategory.manifest,
        reason: 'Cargo.toml 仍归 manifest',
      );
      final plan = selectPlanForFiles([
        'rust-backend/tool/boundary_scanner/Cargo.toml',
      ], index: testIndex);
      expect(kindsOf(plan), contains(CommandKind.clippy));
      // rustTool 子树 manifest：跑该 crate 自身 test（rustToolTest），
      // 不升级 rust:test:full、不跑 flutter。
      expect(
        plan.steps.any(
          (s) =>
              s.kind == CommandKind.rustTest &&
              s.arguments.contains('boundary_scanner'),
        ),
        isTrue,
        reason: 'tool 子树 manifest 应跑 boundary_scanner 自身 cargo test',
      );
      expect(
        plan.steps.any((s) => s.label == 'rust:test:full'),
        isFalse,
        reason: 'tool 子树 manifest 不升级 rust:test:full',
      );
      expect(kindsOf(plan), isNot(contains(CommandKind.analyze)));
    });

    test('10k tool/release/*.py 归独立分类并选中 python unittest（窄路由）', () {
      // 独立分类：tool/release/*.py 不再落 unknown fail-closed。
      for (final py in <String>[
        'tool/release/release_metadata.py',
        'tool/release/generate_update_manifest.py',
        'tool/release/test_release_metadata.py',
        'tool/release/test_generate_update_manifest.py',
      ]) {
        expect(
          classifyPath(py),
          isNot(FileCategory.unknown),
          reason: '$py 应有独立分类（releasePython），不落 unknown',
        );
      }
      final plan = selectPlanForFiles([
        'tool/release/release_metadata.py',
      ], index: testIndex);
      // 计划里必须存在一条 python -m unittest 步骤（发现 tool/release 的
      // test_*.py）。
      final pySteps = plan.steps
          .where((s) => s.executable == 'python')
          .toList();
      expect(pySteps, hasLength(1), reason: '发布脚本改动必须触发一条 python unittest 步骤');
      expect(pySteps.single.arguments, <String>[
        '-m',
        'unittest',
        'discover',
        '-s',
        'tool/release',
        '-p',
        'test_*.py',
      ]);
      // 窄路由：不升级为 Dart/Rust 全量或任何双栈检查。
      expect(kindsOf(plan), isNot(contains(CommandKind.clippy)));
      expect(kindsOf(plan), isNot(contains(CommandKind.rustTest)));
      expect(kindsOf(plan), isNot(contains(CommandKind.analyze)));
      expect(kindsOf(plan), isNot(contains(CommandKind.flutterTest)));
      expect(
        plan.steps.where((s) => s.label == 'flutter:test:full'),
        isEmpty,
        reason: 'tool/release/*.py 不得触发 flutter:test:full',
      );
      expect(
        plan.steps.where((s) => s.label == 'rust:test:full'),
        isEmpty,
        reason: 'tool/release/*.py 不得触发 rust:test:full',
      );
    });

    test('10l 对照腿：无关文件不触发 python unittest 步骤', () {
      // 防「恒出现」空断言：docs-only 计划不得包含任何 python 步骤。
      final docsPlan = selectPlanForFiles([
        'docs/product.md',
      ], index: testIndex);
      expect(
        docsPlan.steps.any((s) => s.executable == 'python'),
        isFalse,
        reason: 'docs-only 计划不得出现 python -m unittest',
      );
      // 混合计划：多个 release .py 去重为一条 unittest discover 步骤。
      final mixed = selectPlanForFiles([
        'docs/product.md',
        'tool/release/generate_update_manifest.py',
        'tool/release/test_release_metadata.py',
      ], index: testIndex);
      expect(
        mixed.steps.where((s) => s.executable == 'python').length,
        1,
        reason: '多个 release .py 应去重为一条 unittest discover 步骤',
      );
      // tool/release 之外的 .py 无分类 → 仍落 unknown（fail-closed 双栈全量）。
      expect(classifyPath('tool/foo.py'), FileCategory.unknown);
      expect(classifyPath('scripts/gen.py'), FileCategory.unknown);
    });

    // ── 标准 1：同一计划里的 flutter 测试合批成一条多文件命令 ──────────────
    test('12a 合批：devices_page 的 9 条 flutter 测试合成 1 条多文件命令', () {
      final plan = selectPlanForFiles([
        'lib/pages/devices_page.dart',
      ], index: testIndex);
      final cmds = flutterTestCmdsOf(plan);
      expect(cmds, hasLength(1), reason: '同一计划里的 flutter 测试必须合批成一条命令');
      expect(cmds.single.arguments, <String>[
        'test',
        '--timeout',
        '5m',
        'test/device_name_edit_test.dart',
        'test/devices_page_widget_test.dart',
        'test/pairing_accept_ui_test.dart',
        'test/pairing_credential_repository_test.dart',
        'test/pairing_credential_ui_test.dart',
        'test/pairing_log_events_test.dart',
        'test/pairing_mdns_widget_test.dart',
        'test/pairing_repository_test.dart',
        'test/sync_ui_widget_test.dart',
      ], reason: '文件集合必须完整、顺序稳定、无重复');
    });

    test('12b 合批：test_boundary_scanner 路由到自身窄测试（1 条命令）', () {
      // 旧行为：路径含 'scanner' 子串，被 _pairingKeywords 命中，错配 9 个
      // pairing 测试 + 自身共 10 个文件。修复后 pairing 集群不得再出现。
      // 前缀并集：coverage_absence 也在 test_boundary_scanner 前缀下、且
      // import '../tool/test_boundary_scanner.dart'，同族一并选中。
      final plan = selectPlanForFiles([
        'tool/test_boundary_scanner.dart',
      ], index: testIndex);
      final cmds = flutterTestCmdsOf(plan);
      expect(cmds, hasLength(1), reason: '同一计划里的 flutter 测试必须合批成一条命令');
      expect(flutterTestFilesOfCmd(cmds.single), <String>[
        'test/test_boundary_scanner_coverage_absence_test.dart',
        'test/test_boundary_scanner_rust_test.dart',
      ], reason: '只应选边界扫描器自身的窄测试，不带 pairing 集群');
    });

    test('12c 合批：跨 staged 文件重复命中的测试只出现一次', () {
      // memory_note_repository 的 import 方含 trash_page_widget_test；
      // lib/pages/trash_page.dart 的 stem 也命中同一个测试——合批后不得重复。
      final plan = selectPlanForFiles([
        'test/support/memory_note_repository.dart',
        'lib/pages/trash_page.dart',
      ], index: testIndex);
      final cmds = flutterTestCmdsOf(plan);
      expect(cmds, hasLength(1), reason: '跨 staged 文件的测试也要合批');
      expect(flutterTestFilesOfCmd(cmds.single), <String>[
        'test/editor_page_widget_test.dart',
        'test/knowledge_base_widget_test.dart',
        'test/note_list_page_widget_test.dart',
        'test/trash_page_widget_test.dart',
      ], reason: '并集去重且顺序稳定');
    });

    // ── 标准 2：无窄测试可映射的 dartBusiness 文件 fail-closed 落全量 ────────
    test('12d 空映射 fail-closed：无窄测试的 dartBusiness 落全量 flutter test', () {
      // 这 5 个是主代理实测「计划里只有 flutter:analyze、零测试」的典型：
      // _relatedDartTests 命中 0（无同名测试、无 importer 映射、无关键词）。
      for (final file in <String>[
        'lib/main.dart',
        'lib/models/update_channel.dart',
        'lib/ui/design_system/cardmind_widgets.dart',
        'lib/bridge/bridge_helper.dart',
        'tool/lint/markdown_references_linter.dart',
      ]) {
        final plan = selectPlanForFiles(<String>[file], index: testIndex);
        final cmds = flutterTestCmdsOf(plan);
        expect(
          cmds,
          hasLength(1),
          reason: '$file 没有窄测试可映射，必须落一条全量 flutter test（不得静默零测试）',
        );
        expect(
          flutterTestFilesOfCmd(cmds.single),
          isEmpty,
          reason: '$file 的全量 flutter test 不得带文件参数',
        );
        expect(
          cmds.single.label,
          'flutter:test:full',
          reason: '$file 应落全量 flutter test（label 为 flutter:test:full）',
        );
        expect(
          kindsOf(plan),
          contains(CommandKind.analyze),
          reason: '$file 仍应跑 flutter analyze',
        );
      }
    });

    test('12d2 对照腿：仓库没有测试资产时不落全量（防误伤最小仓库）', () {
      // hook 集成测试的临时仓库只有 lib/x.dart + tool/，没有 test/ 目录：
      // 此时索引为空，任何 dartBusiness 都会「无窄测试可映射」。若在这种情况下
      // 也落全量 flutter test，最小仓库的提交会去跑根本不存在的全量测试。
      // 语义：fail-closed 兜底的前提是「仓库里有测试资产可跑」。
      const emptyIndex = TestIndex(
        flutterTestFiles: <String>{},
        rustTestTargets: <String>{},
      );
      final plan = selectPlanForFiles(<String>[
        'lib/x.dart',
      ], index: emptyIndex);
      expect(
        kindsOf(plan),
        isNot(contains(CommandKind.flutterTest)),
        reason: '索引为空时不得落全量 flutter test',
      );
      expect(kindsOf(plan), contains(CommandKind.analyze));
    });

    test('12e 对照腿：有窄测试映射的 dartBusiness 不落全量', () {
      // 防「恒落全量」空断言：命中窄测试时必须只跑窄测试。
      for (final file in <String>[
        'lib/pages/editor_page.dart',
        'lib/pages/devices_page.dart',
        'tool/build.dart',
        'test/support/doc_helpers.dart',
      ]) {
        final plan = selectPlanForFiles(<String>[file], index: testIndex);
        expect(
          plan.steps.where((s) => s.label == 'flutter:test:full'),
          isEmpty,
          reason: '$file 命中窄测试，不得升级为全量 flutter test',
        );
      }
    });

    test('12f 对照腿：其它分类不受空映射兜底影响', () {
      // markdown 走 docs:lint 路由，不由 dartBusiness 兜底升级。
      final md = selectPlanForFiles(<String>[
        'docs/product.md',
      ], index: testIndex);
      expect(
        md.steps.where((s) => s.label == 'flutter:test:full'),
        isEmpty,
        reason: 'markdown 改动不落全量 flutter test',
      );
      // rustTool 完全不含 flutter 步骤。
      final rustTool = selectPlanForFiles(<String>[
        'rust-backend/tool/boundary_scanner/src/main.rs',
      ], index: testIndex);
      expect(
        kindsOf(rustTool),
        isNot(contains(CommandKind.flutterTest)),
        reason: 'rustTool 不跑 flutter 测试',
      );
    });

    // ── 标准 3：全量优先、不重复 ────────────────────────────────────────
    test('12g 全量优先：已有全量 flutter test 时窄命令不再保留', () {
      // lib/main.dart 走空映射兜底落全量；lib/pages/editor_page.dart 有窄测试
      // editor_page_widget_test。全量已覆盖它，再跑窄命令是纯重复开销。
      final plan = selectPlanForFiles(<String>[
        'lib/main.dart',
        'lib/pages/editor_page.dart',
      ], index: testIndex);
      final cmds = flutterTestCmdsOf(plan);
      expect(cmds, hasLength(1), reason: '全量 + 窄命令必须收敛成一条');
      expect(
        flutterTestFilesOfCmd(cmds.single),
        isEmpty,
        reason: '收敛后必须是全量命令（不带文件参数）',
      );
      expect(cmds.single.label, 'flutter:test:full');
      // 窄命令彻底消失（不是被全量盖住但仍留在计划里）。
      expect(
        cmds.where(
          (c) => c.arguments.contains('test/editor_page_widget_test.dart'),
        ),
        isEmpty,
        reason: '不得同时出现 test/editor_page_widget_test.dart 的窄命令',
      );
    });

    test('12h 全量优先：平台/配置类全量与业务窄命令同样收敛', () {
      // pubspec.yaml 本身就是全量 fail-closed；混入有窄测试的业务文件后仍只一条。
      final plan = selectPlanForFiles(<String>[
        'pubspec.yaml',
        'lib/pages/devices_page.dart',
      ], index: testIndex);
      final cmds = flutterTestCmdsOf(plan);
      expect(cmds, hasLength(1), reason: '全量与窄命令必须收敛成一条');
      expect(cmds.single.arguments, <String>['test', '--timeout', '5m']);
      expect(cmds.single.label, 'flutter:test:full');
    });

    test('12i 对照腿：没有全量时窄命令照常保留（不被误吞）', () {
      final plan = selectPlanForFiles(<String>[
        'lib/pages/editor_page.dart',
        'lib/pages/note_list_page.dart',
      ], index: testIndex);
      final cmds = flutterTestCmdsOf(plan);
      expect(cmds, hasLength(1), reason: '合批成一条');
      expect(
        flutterTestFilesOfCmd(cmds.single),
        isNotEmpty,
        reason: '无全量时必须是带文件参数的窄命令，不能被误吞成空',
      );
      expect(cmds.single.label, 'flutter:test');
    });

    // ── 标准 5：同一生产文件 stem 命中多个测试文件时并集返回（不截断最短）─────
    // 旧实现两处截断：精确命中即 return（漏前缀命中）、前缀命中只取最短一个
    // （漏同族其余测试）。改为精确命中 ∪ 前缀命中并集去重、排序稳定。
    test('15a feature_test 同时选中 file_arg + security（前缀并集）', () {
      final plan = selectPlanForFiles(<String>[
        'tool/feature_test.dart',
      ], index: testIndex);
      final files = flutterTestCmdsOf(
        plan,
      ).expand(flutterTestFilesOfCmd).toSet();
      expect(
        files,
        containsAll(<String>[
          'test/feature_test_file_arg_test.dart',
          'test/feature_test_security_test.dart',
        ]),
        reason: '同一 stem 的多个前缀测试必须全部选中（不再截断为最短一个）',
      );
    });

    test('15b git_gate 同时选中 git_gate_test + hook_integration（并集）', () {
      final plan = selectPlanForFiles(<String>[
        'tool/git_gate.dart',
      ], index: testIndex);
      final files = flutterTestCmdsOf(
        plan,
      ).expand(flutterTestFilesOfCmd).toSet();
      expect(
        files,
        containsAll(<String>[
          'test/git_gate_test.dart',
          'test/git_gate_hook_integration_test.dart',
        ]),
        reason: '精确命中与前缀命中取并集',
      );
    });

    test('15c debug_log 同时选中 debug_log_test + debug_log_file_test（精确∪前缀）', () {
      // debug_log.dart 的 stem 精确命中 debug_log_test（旧实现命中即 return，
      // 不再看前缀命中 debug_log_file_test——FileDebugSink 的测试被漏跑）。
      final plan = selectPlanForFiles(<String>[
        'lib/bridge/debug_log.dart',
      ], index: testIndex);
      final files = flutterTestCmdsOf(
        plan,
      ).expand(flutterTestFilesOfCmd).toSet();
      expect(
        files,
        containsAll(<String>[
          'test/debug_log_test.dart',
          'test/debug_log_file_test.dart',
        ]),
        reason: '精确命中不得截断前缀命中',
      );
    });

    test('15d quality 同时选中 frb_prep + coverage_reuse（前缀并集）', () {
      final plan = selectPlanForFiles(<String>[
        'tool/quality.dart',
      ], index: testIndex);
      final files = flutterTestCmdsOf(
        plan,
      ).expand(flutterTestFilesOfCmd).toSet();
      expect(
        files,
        containsAll(<String>[
          'test/quality_frb_prep_test.dart',
          'test/quality_coverage_reuse_test.dart',
        ]),
        reason: '同一 stem 前缀下的多个测试不得截断',
      );
    });

    test('15e 并集不误扩：build 仍只选最短族 build_tool_test（防回归腿）', () {
      // build 前缀命中 build_tool_test + build_lib_crossplatform_test。
      // 「最接近」语义保留：取 stem 最短者的同族（首段相同），不得把不同首段的
      // build_lib 族拉进来。
      final plan = selectPlanForFiles(<String>[
        'tool/build.dart',
      ], index: testIndex);
      final files = flutterTestCmdsOf(
        plan,
      ).expand(flutterTestFilesOfCmd).toList();
      expect(files, <String>[
        'test/build_tool_test.dart',
      ], reason: 'build 只应选最接近的 build_tool 族，不得拉入 build_lib 族');
    });

    test('15f 并集在跨文件间去重：feature_test + git_gate 不重复、排序稳定', () {
      final plan = selectPlanForFiles(<String>[
        'tool/feature_test.dart',
        'tool/git_gate.dart',
      ], index: testIndex);
      final cmds = flutterTestCmdsOf(plan);
      expect(cmds, hasLength(1), reason: '跨 staged 文件的测试合批一条');
      final files = flutterTestFilesOfCmd(cmds.single);
      expect(
        files,
        containsAll(<String>[
          'test/feature_test_file_arg_test.dart',
          'test/feature_test_security_test.dart',
          'test/git_gate_test.dart',
          'test/git_gate_hook_integration_test.dart',
        ]),
      );
      expect(files.toSet().length, files.length, reason: '并集去重：不得有重复测试文件');
      expect(files, orderedEquals(files.toList()..sort()), reason: '排序稳定');
    });

    // ── 标准 4：markdown 改动选上全部文档契约测试 ─────────────────────────
    test('12j markdown 改动：docs:lint + 全部文档契约测试（合批一条）', () {
      // 9 个测试就是 doc_helpers 的全部 import 方（= 全部文档契约测试），
      // 由 scanTestIndex 从测试文件内容派生，不再是手抄表。
      const docContractTests = <String>[
        'test/adr_0008_test.dart',
        'test/agents_md_test.dart',
        'test/design_tokens_doc_test.dart',
        'test/docs_dir_test.dart',
        'test/markdown_references_test.dart',
        'test/product_doc_test.dart',
        'test/spec_lifecycle_doc_test.dart',
        'test/sync_network_doc_test.dart',
        'test/ui_style_guide_doc_test.dart',
      ];
      for (final md in <String>['docs/product.md', 'AGENTS.md']) {
        final plan = selectPlanForFiles(<String>[md], index: testIndex);
        expect(
          plan.steps.where((s) => s.label == 'docs:lint'),
          hasLength(1),
          reason: '$md 仍要跑 docs:lint',
        );
        final cmds = flutterTestCmdsOf(plan);
        expect(cmds, hasLength(1), reason: '$md 的文档契约测试应合批成一条');
        expect(
          flutterTestFilesOfCmd(cmds.single),
          docContractTests,
          reason: '$md 必须选上全部 9 个文档契约测试（顺序稳定、无重复）',
        );
      }
    });

    test('12k markdown 契约测试按存在性加入（不存在的跳过）', () {
      // 与 _addIfExists 同语义：索引里没有的测试文件不得进计划，
      // 否则 flutter test 会因「找不到文件」失败。sparse 索引注入
      // doc_helpers 的派生 importer（含一个不存在的文件），验证
      // 按存在性收窄。
      final sparse = TestIndex(
        flutterTestFiles: <String>{
          'test/product_doc_test.dart',
          'test/markdown_references_test.dart',
        },
        rustTestTargets: const <String>{},
        supportImporters: const <String, List<String>>{
          'doc_helpers': <String>[
            'test/markdown_references_test.dart',
            'test/nonexistent_doc_test.dart',
            'test/product_doc_test.dart',
          ],
        },
      );
      final plan = selectPlanForFiles(<String>[
        'docs/product.md',
      ], index: sparse);
      final cmds = flutterTestCmdsOf(plan);
      expect(cmds, hasLength(1));
      expect(flutterTestFilesOfCmd(cmds.single), <String>[
        'test/markdown_references_test.dart',
        'test/product_doc_test.dart',
      ], reason: '只选索引里存在的文档契约测试');
    });

    test('12l 对照腿：非 markdown 不改动选文档契约测试', () {
      // 防「恒选文档测试」空断言。
      final plan = selectPlanForFiles(<String>[
        'lib/pages/editor_page.dart',
      ], index: testIndex);
      final files = flutterTestFilesOfCmd(flutterTestCmdsOf(plan).single);
      expect(
        files.where((f) => f.contains('_doc_test') || f.contains('markdown')),
        isEmpty,
        reason: '业务代码改动不应选文档契约测试',
      );
    });

    // ── 缺陷 A：api.rs 的 Rust target 映射要覆盖真实消费方 ──────────────
    test('13a api.rs 选中全部真实 api:: 消费方 + 原有 target', () {
      // 真相源：git grep -l "api::" rust-backend/tests/ → trash_test /
      // debug_log_test / live_relay_test。旧映射（note_crdt/store/pairing）
      // 中没有一个引用 api::，真实消费方被漏跑。
      final plan = selectPlanForFiles(<String>[
        'rust-backend/src/api.rs',
      ], index: testIndex);
      final rustTargets = plan.steps
          .where((s) => s.kind == CommandKind.rustTest)
          .map((s) => s.arguments.last)
          .toSet();
      expect(
        rustTargets,
        containsAll(<String>[
          'trash_test',
          'debug_log_test',
          'live_relay_test',
        ]),
        reason: 'api.rs 必须跑引用 api:: 的 3 个 Rust 测试 target',
      );
      expect(
        rustTargets,
        containsAll(<String>['note_crdt_test', 'store_test', 'pairing_test']),
        reason: '原有 target 不得丢',
      );
    });

    test('13b api.rs 部分索引按存在性收窄（不凭空加 target）', () {
      // 注入只含部分 target 的索引：选到的集合按存在性收窄，
      // 且不凭空出现不存在的 target（与 _relatedRustTargets 现有
      // existing/null 语义一致）。
      const partial = TestIndex(
        flutterTestFiles: <String>{},
        rustTestTargets: <String>{'trash_test', 'store_test'},
      );
      final plan = selectPlanForFiles(<String>[
        'rust-backend/src/api.rs',
      ], index: partial);
      final rustTargets = plan.steps
          .where((s) => s.kind == CommandKind.rustTest)
          .map((s) => s.arguments.last)
          .toSet();
      expect(rustTargets, <String>{
        'trash_test',
        'store_test',
      }, reason: '部分索引只选存在的 target，不得出现索引外的 target');
    });

    // ── 缺陷 B：'scanner' 子串不得把边界扫描器错配到 pairing 集群 ───────
    test('13c tool/test_boundary_scanner.dart 不带 pairing 集群', () {
      final plan = selectPlanForFiles(<String>[
        'tool/test_boundary_scanner.dart',
      ], index: testIndex);
      final files = plan.steps
          .where((s) => s.kind == CommandKind.flutterTest)
          .expand((s) => s.arguments.skip(3))
          .toSet();
      expect(files, <String>{
        'test/test_boundary_scanner_coverage_absence_test.dart',
        'test/test_boundary_scanner_rust_test.dart',
      });
      expect(
        files.where((f) => f.contains('pairing') || f.contains('device')),
        isEmpty,
        reason: '边界扫描器工具与配对无关，不得路由到 pairing/device 测试',
      );
    });

    test('13d coverage_absence 测试自身不带 pairing 集群', () {
      // dartTest 分类：文件名含 'scanner' 时旧逻辑会附 9 个 pairing 测试。
      final plan = selectPlanForFiles(<String>[
        'test/test_boundary_scanner_coverage_absence_test.dart',
      ], index: testIndex);
      final files = plan.steps
          .where((s) => s.kind == CommandKind.flutterTest)
          .expand((s) => s.arguments.skip(3))
          .toSet();
      expect(files, <String>{
        'test/test_boundary_scanner_coverage_absence_test.dart',
      }, reason: 'coverage_absence 测试只应跑自身，不带 pairing 集群');
    });
    // 防发散：fixture 的 TestIndex 必须与真实文件清单一致（git ls-files 为
    // 真相源）。否则 fixture 与生产 scanTestIndex 脱节，掩盖索引盲区。
    test('11 fixture TestIndex 与真实测试清单一致（git ls-files 真相源）', () async {
      Future<List<String>> lsFiles(String pattern) async {
        final r = await Process.run('git', ['ls-files', pattern]);
        expect(r.exitCode, 0, reason: 'git ls-files $pattern 应成功: ${r.stderr}');
        return r.stdout
            .toString()
            .split(RegExp(r'\r?\n'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      // flutterTestFiles：test/ 下所有 _test.dart + test/support/ 下的 fake。
      final allDart = await lsFiles('test/');
      final expectedFlutter = allDart
          .where(
            (p) =>
                p.endsWith('_test.dart') ||
                (p.endsWith('.dart') && p.startsWith('test/support/')),
          )
          .toSet();
      expect(
        testIndex.flutterTestFiles,
        expectedFlutter,
        reason:
            'fixture flutterTestFiles 与 git ls-files test/ 不一致：'
            '缺 ${expectedFlutter.difference(testIndex.flutterTestFiles)} / '
            '多 ${testIndex.flutterTestFiles.difference(expectedFlutter)}',
      );

      // rustTestTargets：按 cargo target 规则（与 scanTestIndex 同语义）——
      // tests/*.rs → stem；tests/<dir>/main.rs → <dir>；子目录其余文件
      // （tests/common/mod.rs 等共享辅助）不是 target。
      final rsFiles = await lsFiles('rust-backend/tests/');
      final expectedRust = rsFiles.map(rustTestTargetName).nonNulls.toSet();
      expect(
        testIndex.rustTestTargets,
        expectedRust,
        reason:
            'fixture rustTestTargets 与 git ls-files rust-backend/tests/ 不一致：'
            '缺 ${expectedRust.difference(testIndex.rustTestTargets)} / '
            '多 ${testIndex.rustTestTargets.difference(expectedRust)}',
      );
    });

    // ── 本任务：supportImporters 从测试文件 import 内容派生，不靠手抄表 ──

    test('14a 新增 support fake 的 importer 从扫描自动派生（不改映射表）', () async {
      // 在临时 repo 里模拟「新增 test/support/foo_repository.dart +
      // test/foo_widget_test.dart import 它」。旧实现下该 fake 不在
      // _supportFakeImporters 手抄表里 → 漏跑；派生实现必须自动纳入。
      final dir = await Directory.systemTemp.createTemp('gate_support_scan_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final support = Directory('${dir.path}/test/support')
        ..createSync(recursive: true);
      File(
        '${support.path}/foo_repository.dart',
      ).writeAsStringSync('// fake\nclass FooRepository {}\n');
      File('${dir.path}/test/foo_widget_test.dart').writeAsStringSync(
        // 拆串拼接：本测试文件自身不得含可匹配的 `import 'support/x.dart'`
        // 连续文本，否则真实仓库扫描会把 git_gate_test 误记为 importer。
        "import 'support/foo"
        "_repository.dart';\nvoid main() {}\n",
      );

      final index = await scanTestIndex(dir.path);
      expect(index.supportImporters['foo_repository'], <String>[
        'test/foo_widget_test.dart',
      ], reason: 'scanTestIndex 必须从测试文件内容派生 support fake 的 import 方');

      final plan = selectPlanForFiles(<String>[
        'test/support/foo_repository.dart',
      ], index: index);
      expect(
        plan.steps
            .where((s) => s.kind == CommandKind.flutterTest)
            .expand((s) => s.arguments.skip(3)),
        contains('test/foo_widget_test.dart'),
        reason: '新 fake 的 import 方必须自动纳入计划（不走手抄表）',
      );
      expect(
        plan.steps.where((s) => s.label == 'flutter:test:full'),
        isEmpty,
        reason: '有 importer 命中不得升级全量',
      );
    });

    test('14b 缺失 support fake 不错配（空映射 fail-closed 全量）', () {
      // 索引里没有的 fake：不得走 pairing/sync 关键词或 stem 兜底错配到
      // 无关测试；fail-closed 落全量 flutter test（「索引里没有 → 不返回
      // 任何窄测试」的 null 语义不破）。
      final plan = selectPlanForFiles(<String>[
        'test/support/nonexistent_fake.dart',
      ], index: testIndex);
      final cmds = flutterTestCmdsOf(plan);
      expect(cmds, hasLength(1));
      expect(
        flutterTestFilesOfCmd(cmds.single),
        isEmpty,
        reason: '缺失 fake 必须落全量（无文件参数），不得错配窄测试',
      );
      expect(cmds.single.label, 'flutter:test:full');
    });

    test('14c 真实仓库派生结果与已知 import 方一致（doc_helpers/memory）', () {
      // fixture testIndex 已由生产 scanTestIndex 填充（见 setUpAll）；
      // 这里直接断言派生值 = 手抄表应含的真实 import 方（git grep
      // "import 'support" test/ 为真相源）。
      expect(testIndex.supportImporters['doc_helpers'], <String>[
        'test/adr_0008_test.dart',
        'test/agents_md_test.dart',
        'test/design_tokens_doc_test.dart',
        'test/docs_dir_test.dart',
        'test/markdown_references_test.dart',
        'test/product_doc_test.dart',
        'test/spec_lifecycle_doc_test.dart',
        'test/sync_network_doc_test.dart',
        'test/ui_style_guide_doc_test.dart',
      ], reason: 'doc_helpers 的派生 importer 必须与真实消费方一致');
      expect(testIndex.supportImporters['memory_note_repository'], <String>[
        'test/editor_page_widget_test.dart',
        'test/knowledge_base_widget_test.dart',
        'test/note_list_page_widget_test.dart',
        'test/trash_page_widget_test.dart',
      ], reason: 'memory_note_repository 的派生 importer 必须与真实消费方一致');
      // doc_helpers 的 import 方 = 全部文档契约测试（markdown 改动时被选中）。
      expect(docContractTests(testIndex), <String>[
        'test/adr_0008_test.dart',
        'test/agents_md_test.dart',
        'test/design_tokens_doc_test.dart',
        'test/docs_dir_test.dart',
        'test/markdown_references_test.dart',
        'test/product_doc_test.dart',
        'test/spec_lifecycle_doc_test.dart',
        'test/sync_network_doc_test.dart',
        'test/ui_style_guide_doc_test.dart',
      ]);
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

    test('12 checkAsync 祖先包含命中语义（含非祖先安全边界）', () async {
      // 真实 git 仓库构造祖先/非祖先 SHA。
      final repo = await Directory.systemTemp.createTemp('gate_ancestor_');
      addTearDown(() => repo.deleteSync(recursive: true));
      Future<List<String>> git(List<String> args) async {
        final r = await Process.run('git', args, workingDirectory: repo.path);
        return r.stdout.toString().split('\n');
      }

      await Process.run('git', ['init', '-q'], workingDirectory: repo.path);
      await Process.run('git', [
        'config',
        'user.email',
        'gate@test.local',
      ], workingDirectory: repo.path);
      await Process.run('git', [
        'config',
        'user.name',
        'Gate Test',
      ], workingDirectory: repo.path);
      await Process.run('git', [
        'config',
        'commit.gpgsign',
        'false',
      ], workingDirectory: repo.path);
      File('${repo.path}/a.txt').writeAsStringSync('a\n');
      await Process.run('git', ['add', 'a.txt'], workingDirectory: repo.path);
      await Process.run('git', [
        'commit',
        '-q',
        '-m',
        'c1',
      ], workingDirectory: repo.path);
      final c1 = (await git(['rev-parse', 'HEAD'])).first.trim();
      File('${repo.path}/a.txt').writeAsStringSync('a\nb\n');
      await Process.run('git', [
        'commit',
        '-aq',
        '-m',
        'c2',
      ], workingDirectory: repo.path);
      final head = (await git(['rev-parse', 'HEAD'])).first.trim();
      // 非祖先提交：游离分支上的孤儿提交（同为合法 SHA，但不在 head 祖先链）。
      final orphan = (await git([
        'commit-tree',
        'HEAD^{tree}',
        '-m',
        'orphan',
      ])).first.trim();

      // isAncestor：HEAD 自身与早期提交是祖先，孤儿提交不是。
      expect(await isAncestor(repo.path, head, head), isTrue);
      expect(await isAncestor(repo.path, c1, head), isTrue);
      expect(await isAncestor(repo.path, orphan, head), isFalse);
      expect(
        await isAncestor(
          repo.path,
          '0000000000000000000000000000000000000000',
          head,
        ),
        isFalse,
        reason: '不存在的 sha 必须按非祖先处理，不 throw',
      );

      final dir = await Directory.systemTemp.createTemp('gate_cache_test_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final cache = GateCache.forRepo(dir.path);

      // runFull 语义：写缓存时 localShas 为空（不知道会推哪些提交）。
      await cache.write(
        input: CacheCheckInput(
          headSha: head,
          fingerprint: 'fp1',
          localShas: const <String>[],
          worktreeClean: true,
        ),
      );

      // push 的 localSha 都是 head 祖先 → 命中（full 预热路径）。
      final hit = await cache.checkAsync(
        repoRoot: repo.path,
        input: CacheCheckInput(
          headSha: head,
          fingerprint: 'fp1',
          localShas: <String>[c1, head],
          worktreeClean: true,
        ),
      );
      expect(hit.hit, isTrue, reason: '祖先 localSha 必须命中: ${hit.reason}');

      // 含非祖先 localSha → 不命中（安全边界：同 headSha 也不得误命中）。
      final miss = await cache.checkAsync(
        repoRoot: repo.path,
        input: CacheCheckInput(
          headSha: head,
          fingerprint: 'fp1',
          localShas: <String>[c1, orphan],
          worktreeClean: true,
        ),
      );
      expect(miss.hit, isFalse, reason: '非祖先 localSha 不得命中');
      expect(miss.reason, contains('非祖先'));
    });
  });

  group('timeout', () {
    test('12 注入短 timeout 触发超时状态与错误输出', () async {
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

    /// 当前测试进程的 Dart 可执行文件。
    /// flutter test 下 Platform.resolvedExecutable 是 flutter_tester，
    /// 从 SDK 布局推导真实 Dart CLI；Windows 使用 dart.exe，POSIX 使用 dart。
    String dartExe() {
      final resolved = Platform.resolvedExecutable.replaceAll(r'\', '/');
      final marker = '/cache/artifacts/engine/';
      final idx = resolved.indexOf(marker);
      if (resolved.contains('flutter_tester') && idx != -1) {
        final flutterBin = resolved.substring(0, idx);
        final suffix = Platform.isWindows ? 'dart.exe' : 'dart';
        return '$flutterBin/cache/dart-sdk/bin/$suffix';
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
      // 文档契约测试要跑（9 个合批一条），但只跑文档契约测试、不跑全量。
      final flutterTestCalls = called
          .where((c) => c.contains('flutter|test'))
          .toList();
      expect(flutterTestCalls, hasLength(1), reason: '文档契约测试合批成一条');
      expect(
        flutterTestCalls.single,
        isNot('flutter|test --timeout 5m'),
        reason: 'docs-only 不得落全量 flutter test',
      );
      expect(
        flutterTestCalls.single,
        contains('test/product_doc_test.dart'),
        reason: 'docs-only 必须选上文档契约测试',
      );
    });

    // 建 git 仓库 + 单个已提交 dart 源文件，返回 (repo, headSha)。
    Future<(String, String)> makeRepoWithCommit() async {
      final repo = await makeRepo(withGit: true);
      await Process.run('git', [
        'config',
        'commit.gpgsign',
        'false',
      ], workingDirectory: repo);
      final f = File('$repo/lib/a.dart');
      f.parent.createSync(recursive: true);
      f.writeAsStringSync('void main() {}\n');
      await Process.run('git', ['add', 'lib/a.dart'], workingDirectory: repo);
      await Process.run('git', [
        'commit',
        '-q',
        '-m',
        'init',
      ], workingDirectory: repo);
      final head = (await Process.run('git', [
        'rev-parse',
        'HEAD',
      ], workingDirectory: repo)).stdout.toString().trim();
      return (repo, head);
    }

    test('19 full 预热写缓存后 push 命中（祖先包含语义）', () async {
      final (repo, head) = await makeRepoWithCommit();
      final refLines = <String>[
        'refs/heads/main $head refs/heads/main 0000000',
      ];

      // 模拟 dart run tool/git_gate.dart full：跑完整套（fake runner 全
      // 通过）后写缓存。旧「等值匹配」实现下这条断言会红——full 写的是
      // localShas=[]，push 提供非空集，永不命中。
      var runner = FakeRunner();
      var exit = await runFull(optionsFor(repo, runner));
      expect(exit, 0, reason: 'full 必须成功才能写缓存');

      // 紧接着 git push（pre-push 模拟）：必须写 CACHE HIT 且不跑 suite。
      final hitLogs = <String>[];
      runner = FakeRunner();
      exit = await runPrePush(
        GateOptions(
          repoRoot: repo,
          runner: runner.call,
          stepTimeout: const Duration(seconds: 30),
          log: hitLogs.add,
          logError: hitLogs.add,
          index: testIndex,
          pushRefLinesOverride: refLines,
          testMode: true,
          testLogWriter: hitLogs.add,
        ),
      );
      expect(exit, 0, reason: '缓存命中时 push 直接通过');
      expect(hitLogs, contains('CACHE HIT'), reason: '必须走缓存命中路径');
      expect(
        runner.signatures.any((c) => c.contains('clippy')),
        isFalse,
        reason: '命中后不得重跑完整 suite',
      );
    });

    test('20 HEAD 前移后 push 不命中，非祖先 localSha 不命中（安全边界）', () async {
      final (repo, _) = await makeRepoWithCommit();

      // full 预热（写入 head1 + localShas=[] 的缓存）。
      var runner = FakeRunner();
      expect(await runFull(optionsFor(repo, runner)), 0);

      // 新提交一个 commit：HEAD 前移，缓存 headSha 失效。
      final f = File('$repo/lib/a.dart');
      f.writeAsStringSync('void main() {\n  print(1);\n}\n');
      await Process.run('git', [
        'commit',
        '-aq',
        '-m',
        'second',
      ], workingDirectory: repo);
      final head2 = (await Process.run('git', [
        'rev-parse',
        'HEAD',
      ], workingDirectory: repo)).stdout.toString().trim();

      var hitLogs = <String>[];
      runner = FakeRunner();
      var exit = await runPrePush(
        GateOptions(
          repoRoot: repo,
          runner: runner.call,
          stepTimeout: const Duration(seconds: 30),
          log: (_) {},
          logError: (_) {},
          index: testIndex,
          pushRefLinesOverride: <String>[
            'refs/heads/main $head2 refs/heads/main 0000000',
          ],
          testMode: true,
          testLogWriter: hitLogs.add,
        ),
      );
      expect(exit, 0, reason: '完整 suite 跑过后 push 仍应通过');
      expect(hitLogs, isNot(contains('CACHE HIT')), reason: 'headSha 不同不得命中缓存');
      expect(
        runner.signatures.any((c) => c.contains('clippy')),
        isTrue,
        reason: 'miss 后必须执行完整 suite',
      );

      // 非祖先 localSha：构造孤儿提交（合法 SHA 但不在 head 祖先链）。
      // 上一轮 pre-push 已把缓存改写为 head2，直接复用验证安全边界。
      final orphan = (await Process.run('git', [
        'commit-tree',
        'HEAD^{tree}',
        '-m',
        'orphan',
      ], workingDirectory: repo)).stdout.toString().trim();
      hitLogs = <String>[];
      runner = FakeRunner();
      exit = await runPrePush(
        GateOptions(
          repoRoot: repo,
          runner: runner.call,
          stepTimeout: const Duration(seconds: 30),
          log: (_) {},
          logError: (_) {},
          index: testIndex,
          pushRefLinesOverride: <String>[
            'refs/heads/side $orphan refs/heads/side 0000000',
          ],
          testMode: true,
          testLogWriter: hitLogs.add,
        ),
      );
      expect(exit, 0);
      expect(
        hitLogs,
        isNot(contains('CACHE HIT')),
        reason: '推非祖先提交（别的分支 SHA）不得命中——这是安全边界',
      );
      expect(
        runner.signatures.any((c) => c.contains('clippy')),
        isTrue,
        reason: '非祖先 miss 必须执行完整 suite',
      );
    });

    test('21 pre-push 自身写的缓存（真实 localShas）再次 push 命中', () async {
      final (repo, head) = await makeRepoWithCommit();
      final refLines = <String>[
        'refs/heads/main $head refs/heads/main 0000000',
      ];

      // 第一次 push：无缓存，跑完整套并写缓存（真实 localShas）。
      var runner = FakeRunner();
      var hitLogs = <String>[];
      var exit = await runPrePush(
        GateOptions(
          repoRoot: repo,
          runner: runner.call,
          stepTimeout: const Duration(seconds: 30),
          log: (_) {},
          logError: (_) {},
          index: testIndex,
          pushRefLinesOverride: refLines,
          testMode: true,
          testLogWriter: hitLogs.add,
        ),
      );
      expect(exit, 0);
      expect(hitLogs, isNot(contains('CACHE HIT')));
      expect(runner.signatures.any((c) => c.contains('clippy')), isTrue);

      // 相同 ref 集再次 push：命中。
      runner = FakeRunner();
      hitLogs = <String>[];
      exit = await runPrePush(
        GateOptions(
          repoRoot: repo,
          runner: runner.call,
          stepTimeout: const Duration(seconds: 30),
          log: (_) {},
          logError: (_) {},
          index: testIndex,
          pushRefLinesOverride: refLines,
          testMode: true,
          testLogWriter: hitLogs.add,
        ),
      );
      expect(exit, 0);
      expect(hitLogs, contains('CACHE HIT'), reason: '同 ref 集再推必须命中');
      expect(
        runner.signatures.any((c) => c.contains('clippy')),
        isFalse,
        reason: '命中后不得重跑完整 suite',
      );
    });

    test('22 gate fingerprint 变化不命中，恢复后命中（祖先语义）', () async {
      final (repo, head) = await makeRepoWithCommit();
      final refLines = <String>[
        'refs/heads/main $head refs/heads/main 0000000',
      ];

      var runner = FakeRunner();
      expect(await runFull(optionsFor(repo, runner)), 0);

      // 改动进 computeGateFingerprint 清单的源文件 → fingerprint 变化，
      // 同时工作树 dirty。先验证 dirty 阻止路径存在（不命中），再恢复文件
      // 证明命中回来——隔离出 miss 是由 fingerprint 判断引起的。
      File(
        '$repo/tool/git_gate.dart',
      ).writeAsStringSync('\n// fp change\n', mode: FileMode.append);

      var hitLogs = <String>[];
      runner = FakeRunner();
      var exit = await runPrePush(
        GateOptions(
          repoRoot: repo,
          runner: runner.call,
          stepTimeout: const Duration(seconds: 30),
          log: (_) {},
          logError: (_) {},
          index: testIndex,
          pushRefLinesOverride: refLines,
          testMode: true,
          testLogWriter: hitLogs.add,
        ),
      );
      // dirty tracked source（git_gate.dart 未提交）→ 阻止；同时也验证
      // 不命中（即使能走到缓存检查，fingerprint 已不同）。
      expect(exit, isNot(0), reason: 'dirty worktree 必须阻止 push');
      expect(hitLogs, isNot(contains('CACHE HIT')));

      // 恢复文件：fingerprint 回到缓存值，HEAD 未动，localSha 是祖先 → 命中。
      await Process.run('git', [
        'checkout',
        '--',
        'tool/git_gate.dart',
      ], workingDirectory: repo);
      hitLogs = <String>[];
      runner = FakeRunner();
      exit = await runPrePush(
        GateOptions(
          repoRoot: repo,
          runner: runner.call,
          stepTimeout: const Duration(seconds: 30),
          log: (_) {},
          logError: (_) {},
          index: testIndex,
          pushRefLinesOverride: refLines,
          testMode: true,
          testLogWriter: hitLogs.add,
        ),
      );
      expect(exit, 0);
      expect(
        hitLogs,
        contains('CACHE HIT'),
        reason: 'fingerprint 恢复一致 + 祖先 localSha → 命中',
      );
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

  group('windows flutter resolution', () {
    test('29 精确 executable flutter 在 Windows 解析为 flutter.bat', () {
      expect(resolveExecutable('flutter', isWindows: true), 'flutter.bat');
    });

    test('30 非 flutter executable 在 Windows 保持不变', () {
      expect(resolveExecutable('dart', isWindows: true), 'dart');
      expect(resolveExecutable('cargo', isWindows: true), 'cargo');
      expect(
        resolveExecutable('flutter_rust_bridge_codegen', isWindows: true),
        'flutter_rust_bridge_codegen',
      );
    });

    test('31 非 Windows 平台 flutter 保持 flutter', () {
      expect(resolveExecutable('flutter', isWindows: false), 'flutter');
      expect(resolveExecutable('dart', isWindows: false), 'dart');
    });

    test('32 CommandRunner 真实路径应用解析且参数/cwd/environment 完整保留', () async {
      final seenExecutables = <String>[];
      List<String>? seenArgs;
      String? seenCwd;
      Map<String, String>? seenEnv;
      Duration? seenTimeout;

      Future<RunnerResult> spyRunner({
        required String executable,
        required List<String> arguments,
        String? workingDirectory,
        Map<String, String>? environment,
        required Duration timeout,
      }) async {
        seenExecutables.add(executable);
        seenArgs = List<String>.of(arguments);
        seenCwd = workingDirectory;
        seenEnv = environment;
        seenTimeout = timeout;
        return const RunnerResult(
          exitCode: 0,
          stdout: '',
          stderr: '',
          timedOut: false,
          elapsed: Duration.zero,
        );
      }

      final runner = CommandRunner(
        timeout: const Duration(minutes: 3),
        testMode: false,
        realRunner: spyRunner,
      );

      final env = <String, String>{'PATH': '/x', 'FOO': 'bar'};
      final result = await runner.run(
        'flutter',
        <String>['analyze'],
        workingDirectory: 'C:/repo',
        environment: env,
      );

      expect(result.exitCode, 0);
      expect(
        seenExecutables.single,
        Platform.isWindows ? 'flutter.bat' : 'flutter',
        reason: '真实路径必须经过解析（Windows: flutter → flutter.bat）',
      );
      expect(seenArgs, <String>['analyze'], reason: '参数必须原样保留');
      expect(seenCwd, 'C:/repo', reason: 'cwd 必须原样保留');
      expect(seenEnv, env, reason: 'environment 必须原样保留');
      expect(seenTimeout, const Duration(minutes: 3), reason: 'timeout 必须原样保留');
    });

    test('33 测试模式 fake 记录逻辑命令 flutter（不掩盖真实解析）', () async {
      final logFile = File(
        '${Directory.systemTemp.path}/gate_fake_log_${DateTime.now().microsecondsSinceEpoch}.log',
      );
      addTearDown(() {
        try {
          logFile.deleteSync();
        } on FileSystemException {
          // 忽略清理失败
        }
      });
      final runner = CommandRunner(
        timeout: const Duration(minutes: 3),
        testMode: true,
        fakeLog: logFile.path,
      );
      await runner.run('flutter', <String>['analyze']);
      final log = logFile.readAsStringSync();
      expect(
        log,
        contains('FAKE flutter analyze'),
        reason: 'fake 必须记录逻辑命令 flutter（原始命令可观察）',
      );
      expect(
        log,
        isNot(contains('flutter.bat')),
        reason: 'fake 不应掩盖解析：真实解析由 test 32 的 spy 验证',
      );
    });

    test('34 Windows smoke: 解析后的 flutter.bat --version 成功（无副作用）', () async {
      if (!Platform.isWindows) {
        markTestSkipped('Windows-only smoke');
        return;
      }
      // PATH 中必须存在 flutter.bat；缺失意味着需停下报告，不自行决定
      final resolved = resolveExecutable('flutter', isWindows: true);
      expect(resolved, 'flutter.bat');
      expect(
        _findInPath('flutter.bat'),
        isNotNull,
        reason: 'PATH 中必须存在 flutter.bat（缺失需停下报告）',
      );

      final runner = CommandRunner(
        timeout: const Duration(minutes: 3),
        testMode: false,
      );
      final result = await runner.run(resolved, <String>['--version']);
      // smoke 记录（验收要求）：debugPrint 避免 avoid_print lint
      debugPrint('resolved executable=$resolved');
      debugPrint('flutter --version exit=${result.exitCode}');
      expect(result.timedOut, isFalse, reason: '不得超时（单步 15 分钟硬超时铁律）');
      expect(
        result.exitCode,
        0,
        reason: 'flutter.bat --version 必须成功: ${result.stderr}',
      );
    });
    test(
      '35 CommandRunner 剥离 Git 仓库定位环境变量（GIT_DIR/GIT_INDEX_FILE 不泄漏到子进程）',
      () async {
        Map<String, String>? captured;
        final runner = CommandRunner(
          timeout: const Duration(minutes: 3),
          testMode: false,
          realRunner:
              ({
                required String executable,
                required List<String> arguments,
                String? workingDirectory,
                Map<String, String>? environment,
                required Duration timeout,
              }) async {
                captured = environment;
                return const RunnerResult(
                  exitCode: 0,
                  stdout: '',
                  stderr: '',
                  timedOut: false,
                  elapsed: Duration.zero,
                );
              },
        );

        await runner.run(
          'dart',
          <String>['format'],
          environment: <String, String>{
            'PATH': '/x',
            'KEEP_ME': 'yes',
            'GIT_DIR': 'C:/repo/.git',
            'GIT_INDEX_FILE': 'C:/repo/.git/index',
            'GIT_WORK_TREE': 'C:/repo',
            'GIT_COMMON_DIR': 'C:/repo/.git',
            'GIT_OBJECT_DIRECTORY': 'C:/repo/.git/objects',
            'GIT_ALTERNATE_OBJECT_DIRECTORIES': 'C:/other',
            'GIT_PREFIX': '',
          },
        );

        expect(captured, isNotNull, reason: '子进程必须拿到显式环境，不能靠继承');
        for (final key in kGitRepoEnvVars) {
          expect(
            captured!.containsKey(key),
            isFalse,
            reason: '$key 泄漏到子进程会让其内部 git 操作污染外层仓库',
          );
        }
        expect(captured!['PATH'], '/x', reason: '非 Git 变量必须保留');
        expect(captured!['KEEP_ME'], 'yes', reason: '非 Git 变量必须保留');
      },
    );

    test('36 未显式传 environment 时子进程环境同样剔除 Git 仓库定位变量', () async {
      Map<String, String>? captured;
      final runner = CommandRunner(
        timeout: const Duration(minutes: 3),
        testMode: false,
        realRunner:
            ({
              required String executable,
              required List<String> arguments,
              String? workingDirectory,
              Map<String, String>? environment,
              required Duration timeout,
            }) async {
              captured = environment;
              return const RunnerResult(
                exitCode: 0,
                stdout: '',
                stderr: '',
                timedOut: false,
                elapsed: Duration.zero,
              );
            },
      );

      await runner.run('dart', <String>['format']);

      expect(captured, isNotNull, reason: '必须显式传递剔除后的环境副本，而非 null（继承）');
      for (final key in kGitRepoEnvVars) {
        expect(captured!.containsKey(key), isFalse, reason: '$key 不得继承泄漏');
      }
      expect(
        captured!['PATH'],
        Platform.environment['PATH'],
        reason: '其余环境应等于当前进程环境',
      );
    });
    test('37 真实子进程不合并父环境，且不继承 Git 仓库定位变量', () async {
      // 选一个确定存在于父环境的变量并从传入 environment 中剔除：若子进程仍能看到
      // 它，说明 `Process.start` 的 includeParentEnvironment 仍在合并父环境。
      final leakVar = Platform.isWindows ? 'USERPROFILE' : 'HOME';
      expect(
        Platform.environment[leakVar],
        isNotNull,
        reason: '$leakVar 应存在于父环境',
      );

      final env = Map<String, String>.from(Platform.environment)
        ..remove(leakVar)
        ..['GIT_DIR'] = 'should-be-stripped';

      final runner = CommandRunner(timeout: const Duration(minutes: 1));
      final result = Platform.isWindows
          ? await runner.run('cmd', <String>['/c', 'set'], environment: env)
          : await runner.run('env', const <String>[], environment: env);

      expect(result.exitCode, 0, reason: result.stderr);
      final lines = result.stdout.split(RegExp(r'\r?\n'));
      expect(
        lines.any((l) => l.startsWith('PATH=')),
        isTrue,
        reason: '传入的非 Git 变量应保留',
      );
      expect(
        lines.any((l) => l.startsWith('GIT_DIR=')),
        isFalse,
        reason: 'GIT_DIR 必须被剔除，且不得从父环境继承回来',
      );
      expect(
        lines.any((l) => l.startsWith('$leakVar=')),
        isFalse,
        reason: '父环境变量 $leakVar 不得出现（不得合并父环境）',
      );
    });
  });
}

/// Windows PATH 中查找可执行文件（存在返回完整路径，否则 null）。
String? _findInPath(String name) {
  final path = Platform.environment['PATH'] ?? '';
  for (final dir in path.split(';')) {
    if (dir.isEmpty) continue;
    final candidate = '$dir\\$name';
    if (File(candidate).existsSync()) return candidate;
  }
  return null;
}
