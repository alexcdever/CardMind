// 纯 Dart 选择器 / 状态 / formatter / timeout 测试（不依赖真实 CardMind 业务代码）。
// 验收标准每条对应一个用例（用例名带编号与任务单五节对应）。
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';

import '../tool/src/git_gate/cache.dart';
import '../tool/src/git_gate/command.dart';
import '../tool/src/git_gate/gate.dart';
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
/// stem 集合一致。
final TestIndex testIndex = TestIndex(
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
