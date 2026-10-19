/// 文件分类与快速门禁计划选择器（纯逻辑，不触碰文件系统）。
///
/// 输入 staged 文件路径（POSIX 相对路径），输出去重、稳定排序的命令计划。
/// 测试索引由调用方注入，保证可单测。
library;

import 'command.dart';

/// 文件类别。
enum FileCategory {
  markdown,
  dartBusiness,
  dartTest,
  rustSource,
  rustTest,
  rustTool,
  frbBoundary,
  manifest,
  platform,
  sharedConfig,
  boundaryToolConfig,
  ciWorkflow,
  releasePython,
  unknown,
}

/// 仓库现有测试资产索引。
class TestIndex {
  const TestIndex({
    required this.flutterTestFiles,
    required this.rustTestTargets,
  });

  /// 已存在的 Flutter 测试文件（POSIX 相对路径，如 `test/foo_test.dart`）。
  final Set<String> flutterTestFiles;

  /// 已存在的 Rust 测试 target（如 `sync_service_test`）。
  final Set<String> rustTestTargets;
}

/// 选择结果。
class GatePlan {
  GatePlan({required this.steps, required this.files});

  /// 去重、稳定排序后的命令列表。
  final List<GateCommand> steps;

  /// 参与计划的文件（POSIX 相对路径，排序去重）。
  final List<String> files;

  /// 每类文件数（用于输出分类矩阵）。
  Map<FileCategory, int> get categoryCounts {
    final counts = <FileCategory, int>{};
    for (final f in files) {
      final c = classifyPath(f);
      counts[c] = (counts[c] ?? 0) + 1;
    }
    return counts;
  }
}

/// 命令构建器：同一命令只能出现一次；flutter 测试在计划内合批。
///
/// flutter test 命令不逐条入计划，而是按测试文件聚合成**一条**多文件命令
/// （`flutter test --timeout 5m a.dart b.dart ...`）：单进程固定开销
/// （实测 ≈17s/次）远大于多文件共享同一进程的成本，逐条命令会让「窄路由」
/// 比整仓全量还贵。合批后文件按字典序稳定排序、跨 staged 文件去重。
class PlanBuilder {
  final Set<String> _seen = <String>{};
  final List<GateCommand> _steps = <GateCommand>[];

  /// 合批的 flutter 测试文件（输出时字典序）。
  final Set<String> _flutterTestFiles = <String>{};

  void add(GateCommand command) {
    if (command.kind == CommandKind.flutterTest) {
      final files = _flutterTestFilesOf(command);
      if (files.isNotEmpty) {
        _flutterTestFiles.addAll(files);
        return;
      }
    }
    if (_seen.add(command.signature)) {
      _steps.add(command);
    }
  }

  List<GateCommand> build() {
    final steps = List<GateCommand>.of(_steps);
    if (_flutterTestFiles.isNotEmpty) {
      final files = _flutterTestFiles.toList()..sort();
      steps.add(Commands.flutterTest(files));
    }
    steps.sort((a, b) {
      final byKind = a.kind.priority.compareTo(b.kind.priority);
      if (byKind != 0) return byKind;
      return a.signature.compareTo(b.signature);
    });
    return steps;
  }

  /// flutter test 命令携带的测试文件（`test --timeout 5m` 之后的部分）。
  static List<String> _flutterTestFilesOf(GateCommand command) =>
      command.arguments.skip(3).toList();
}

/// 分类（路径归一化为 POSIX 风格；Windows 反斜杠与 POSIX 斜杠结果相同）。
FileCategory classifyPath(String path) {
  final p = normalizePath(path);
  if (p.endsWith('.md')) return FileCategory.markdown;
  if (_isFrbBoundary(p)) return FileCategory.frbBoundary;
  if (_isDartTest(p)) return FileCategory.dartTest;
  if (_isRustTest(p)) return FileCategory.rustTest;
  if (_isRustTool(p)) return FileCategory.rustTool;
  if (_isRustSource(p)) return FileCategory.rustSource;
  if (_isDartBusiness(p)) return FileCategory.dartBusiness;
  if (_isManifest(p)) return FileCategory.manifest;
  if (_isPlatform(p)) return FileCategory.platform;
  if (_isBoundaryToolConfig(p)) return FileCategory.boundaryToolConfig;
  if (_isCiWorkflow(p)) return FileCategory.ciWorkflow;
  if (_isReleasePython(p)) return FileCategory.releasePython;
  if (_isSharedConfig(p)) return FileCategory.sharedConfig;
  return FileCategory.unknown;
}

/// 归一化路径为 POSIX 风格相对路径（用于分类与输出）。
String normalizePath(String path) {
  final p = path.replaceAll(r'\', '/');
  return p.startsWith('./') ? p.substring(2) : p;
}

bool _isFrbBoundary(String p) =>
    p == 'rust-backend/src/api.rs' ||
    p == 'rust-backend/src/frb_generated.rs' ||
    p.startsWith('lib/src/rust/');

bool _isDartTest(String p) => p.startsWith('test/') && p.endsWith('_test.dart');

bool _isRustTest(String p) =>
    p.startsWith('rust-backend/tests/') && p.endsWith('.rs');

/// rust-backend/tool/ 下的辅助 crate 源码（boundary_scanner 等，已纳入
/// workspace）：属 Rust 范畴但不是产品源码，归 rustTool——只跑 clippy，
/// 不升级 rust:test:full、不跑 flutter。
bool _isRustTool(String p) =>
    p.startsWith('rust-backend/tool/') && p.endsWith('.rs');

bool _isRustSource(String p) =>
    p.startsWith('rust-backend/src/') && p.endsWith('.rs');

bool _isDartBusiness(String p) =>
    (p.startsWith('lib/') ||
        p.startsWith('tool/') ||
        p.startsWith('integration_test/') ||
        // test/support/ 下的共享 fake 是测试资产但不是测试文件（不以
        // _test.dart 结尾）；归入 dartBusiness，由 _relatedDartTests 的
        // stem 匹配 + _maybePairing/_maybeSync 关键词路由选相关测试。
        p.startsWith('test/support/')) &&
    p.endsWith('.dart');

/// Cargo manifest（含 rust-backend/Cargo.toml、rust-backend/Cargo.lock）与
/// Flutter manifest 按文件名匹配（Cargo 大小写不敏感；normalizePath 已保证
/// Windows 反斜杠先归一化）。
bool _isManifest(String p) {
  final lower = p.toLowerCase();
  return p == 'pubspec.yaml' ||
      p == 'pubspec.lock' ||
      p == 'flutter_rust_bridge.yaml' ||
      lower.endsWith('cargo.toml') ||
      lower.endsWith('cargo.lock');
}

bool _isPlatform(String p) =>
    p.startsWith('android/') ||
    p.startsWith('windows/') ||
    p.startsWith('linux/') ||
    p.startsWith('macos/') ||
    p.startsWith('ios/') ||
    p.startsWith('web/');

/// 边界扫描器局部配置（tool/*.yaml）：只被 tool/test_boundary_scanner.dart
/// 读取，与 Rust/Flutter 测试无关——单独分类路由到 scanner 测试，
/// 不升级双栈全量。
bool _isBoundaryToolConfig(String p) =>
    p.startsWith('tool/') && p.endsWith('.yaml');

/// CI workflow（.github/workflows/*.yml）：改 CI 本身不用跑产品双栈全量；
/// 路由到唯一读 workflow 文件的 release_workflow_test。
bool _isCiWorkflow(String p) =>
    p.startsWith('.github/workflows/') &&
    (p.endsWith('.yml') || p.endsWith('.yaml'));

/// tool/release/*.py 发布脚本与其 unittest：只被 python -m unittest 覆盖，
/// 与 Dart/Rust 双栈无关——独立分类做窄路由；tool/release 之外的 .py 仍落
/// unknown（fail-closed 双栈全量）。
bool _isReleasePython(String p) =>
    p.startsWith('tool/release/') && p.endsWith('.py');

/// 影响全仓的根级共享配置；其余 *.yaml/*.json 归 unknown 兜底
/// （fail-closed 双栈全量）。
bool _isSharedConfig(String p) =>
    p == 'analysis_options.yaml' ||
    p == '.metadata' ||
    p == '.gitignore' ||
    p.startsWith('.githooks/') ||
    // 根级 yaml/json（不含 /）才视作共享配置。
    (!p.contains('/') && (p.endsWith('.yaml') || p.endsWith('.json')));

/// 根据 staged 文件生成计划。
GatePlan selectPlanForFiles(List<String> files, {required TestIndex index}) {
  final normalized = files.map(normalizePath).toList()..sort();
  final unique = <String>[];
  for (final f in normalized) {
    if (unique.isEmpty || unique.last != f) {
      unique.add(f);
    }
  }
  final builder = PlanBuilder();
  builder.add(Commands.formatDart());
  builder.add(Commands.formatRust());

  for (final file in normalized) {
    _contribute(builder, file, index);
  }
  return GatePlan(steps: builder.build(), files: unique);
}

void _contribute(PlanBuilder b, String file, TestIndex index) {
  switch (classifyPath(file)) {
    case FileCategory.markdown:
      b.add(Commands.docsLint());
    case FileCategory.dartTest:
      b.add(Commands.analyze());
      b.add(Commands.flutterTest(<String>[file]));
      _maybePairing(b, file, index);
      _maybeSync(b, file, index);
    case FileCategory.dartBusiness:
      b.add(Commands.analyze());
      for (final related in _relatedDartTests(file, index)) {
        b.add(Commands.flutterTest(<String>[related]));
      }
      // test/support/ 下的共享 fake 由 _relatedDartTests 的显式 importer
      // 映射路由到真实消费方；文件名里的 memory/credential/device 等
      // 关键词与被测对象无关，不能再走 pairing/sync 关键词兜底
      // （会把 fake 错配到 pairing 集群、漏掉真实 import 方）。
      if (!file.startsWith('test/support/')) {
        _maybePairing(b, file, index);
        _maybeSync(b, file, index);
      }
    case FileCategory.rustTest:
      b.add(Commands.clippy());
      final target = rustTestTargetName(file);
      if (target == null) {
        // tests/ 子目录下的共享辅助（如 common/mod.rs）不是 cargo test
        // target——cargo test --test <stem> 必失败。fail-closed 升级
        // Rust 全量，覆盖所有 `mod common;` 引用方。
        b.add(Commands.rustFullTest());
      } else {
        b.add(Commands.rustTestTarget(target));
      }
    case FileCategory.rustTool:
      // rust-backend/tool/ 辅助 crate 源码：workspace 已覆盖，跑 clippy；
      // 同时跑该 crate 自身 cargo test（rustToolTest）。与 rust-backend/src/**
      // 产品源码的测试映射无关。
      b.add(Commands.clippy());
      final toolPkg = _rustToolPackage(file);
      if (toolPkg != null) {
        b.add(Commands.rustToolTest(toolPkg));
      }
    case FileCategory.rustSource:
      b.add(Commands.clippy());
      final targets = _relatedRustTargets(file, index);
      if (targets == null) {
        b.add(Commands.rustFullTest());
      } else {
        for (final t in targets) {
          b.add(Commands.rustTestTarget(t));
        }
      }
      _maybeSync(b, file, index);
    case FileCategory.frbBoundary:
      b.add(Commands.analyze());
      b.add(Commands.clippy());
      final targets = _relatedRustTargets(file, index);
      if (targets == null) {
        b.add(Commands.rustFullTest());
      } else {
        for (final t in targets) {
          b.add(Commands.rustTestTarget(t));
        }
      }
      for (final smoke in _frbSmokeTests(index)) {
        b.add(Commands.flutterTest(<String>[smoke]));
      }
      _maybeSync(b, file, index);
    case FileCategory.manifest:
      final lower = file.toLowerCase();
      // Cargo manifest fail-closed 为 Rust 全量（clippy + cargo test 全量）；
      // endsWith 匹配覆盖 rust-backend/Cargo.toml 与 rust-backend/Cargo.lock。
      final isCargoManifest =
          lower.endsWith('cargo.toml') || lower.endsWith('cargo.lock');
      if (isCargoManifest) {
        // rust-backend/tool/ 子树 crate 的 manifest（boundary_scanner 等）：
        // 跑该 crate 自身 cargo test，不升级 rust:test:full。
        final toolPkg = _rustToolPackage(file);
        if (toolPkg != null) {
          b.add(Commands.clippy());
          b.add(Commands.rustToolTest(toolPkg));
        } else {
          b.add(Commands.clippy());
          b.add(Commands.rustFullTest());
        }
      } else if (lower == 'flutter_rust_bridge.yaml') {
        b.add(Commands.clippy());
        b.add(Commands.rustFullTest());
        b.add(Commands.analyze());
        b.add(Commands.flutterFullTest());
      } else {
        // pubspec.*
        b.add(Commands.analyze());
        b.add(Commands.flutterFullTest());
      }
    case FileCategory.platform:
      b.add(Commands.analyze());
      b.add(Commands.flutterFullTest());
    case FileCategory.sharedConfig:
      b.add(Commands.clippy());
      b.add(Commands.rustFullTest());
      b.add(Commands.analyze());
      b.add(Commands.flutterFullTest());
    case FileCategory.boundaryToolConfig:
      // 只被 tool/test_boundary_scanner.dart 读取：选中其测试，不升级全量。
      b.add(Commands.analyze());
      _addIfExists(b, index, const <String>[
        'test/test_boundary_scanner_rust_test.dart',
      ]);
    case FileCategory.ciWorkflow:
      // 改 CI 不跑产品双栈全量；唯一读 workflow 文件的测试是
      // release_workflow_test（只覆盖 manual-build-artifacts.yml）。
      b.add(Commands.analyze());
      _addIfExists(b, index, const <String>['test/release_workflow_test.dart']);
    case FileCategory.releasePython:
      // 发布脚本/测试改动：只跑 tool/release 的 python unittest（窄路由），
      // 不升级 Dart/Rust 双栈全量。
      b.add(Commands.pythonReleaseTest());
    case FileCategory.unknown:
      b.add(Commands.clippy());
      b.add(Commands.rustFullTest());
      b.add(Commands.analyze());
      b.add(Commands.flutterFullTest());
  }
}

/// 把存在的测试文件逐个加入计划（不存在的跳过，保持稳定输出）。
void _addIfExists(PlanBuilder b, TestIndex index, List<String> tests) {
  for (final t in tests) {
    if (index.flutterTestFiles.contains(t)) {
      b.add(Commands.flutterTest(<String>[t]));
    }
  }
}

const List<String> _pairingKeywords = <String>[
  'pairing',
  'device',
  'scanner',
  'discovery',
];

const List<String> _syncKeywords = <String>['sync'];

void _maybePairing(PlanBuilder b, String file, TestIndex index) {
  final lower = file.toLowerCase();
  final hit = _pairingKeywords.any(lower.contains);
  if (!hit) return;
  final pairingTests =
      index.flutterTestFiles.where((f) => f.contains('pairing')).toList()
        ..sort();
  for (final t in pairingTests) {
    b.add(Commands.flutterTest(<String>[t]));
  }
  // 设备页/配对流程相关但文件名不含 pairing 的测试（存在才加）。
  const extraPairingTests = <String>[
    'test/sync_ui_widget_test.dart',
    'test/devices_page_widget_test.dart',
    'test/device_name_edit_test.dart',
    'test/pairing_credential_ui_test.dart',
    'test/pairing_credential_repository_test.dart',
  ];
  for (final t in extraPairingTests) {
    if (index.flutterTestFiles.contains(t)) {
      b.add(Commands.flutterTest(<String>[t]));
    }
  }
}

void _maybeSync(PlanBuilder b, String file, TestIndex index) {
  final lower = file.toLowerCase();
  if (!_syncKeywords.any(lower.contains)) return;
  const syncTests = <String>[
    'test/sync_scheduler_test.dart',
    'test/sync_ui_widget_test.dart',
    'test/receiver_store_borrow_test.dart',
    'test/trash_page_widget_test.dart',
  ];
  for (final t in syncTests) {
    if (index.flutterTestFiles.contains(t)) {
      b.add(Commands.flutterTest(<String>[t]));
    }
  }
}

/// test/support/ 共享 fake → 真实 import 方（`git grep "import 'support" test/`
/// 为真相源）。fake 文件名里的 memory/credential/device 等关键词与被测对象
/// 无关，不能用 pairing/sync 关键词兜底——会错配到 pairing 集群并漏掉真实
/// 消费方。新增/重命名 support fake 或调整 import 方时同步更新本表。
const Map<String, List<String>> _supportFakeImporters = <String, List<String>>{
  'memory_note_repository': <String>[
    'test/editor_page_widget_test.dart',
    'test/knowledge_base_widget_test.dart',
    'test/note_list_page_widget_test.dart',
    'test/trash_page_widget_test.dart',
  ],
  'devices_repository': <String>[
    'test/devices_page_widget_test.dart',
    'test/note_list_page_widget_test.dart',
    'test/sync_ui_widget_test.dart',
  ],
  'credential_ui_repository': <String>[
    'test/devices_page_widget_test.dart',
    'test/pairing_credential_ui_test.dart',
  ],
  'doc_helpers': <String>[
    'test/adr_0008_test.dart',
    'test/agents_md_test.dart',
    'test/design_tokens_doc_test.dart',
    'test/docs_dir_test.dart',
    'test/markdown_references_test.dart',
    'test/product_doc_test.dart',
    'test/spec_lifecycle_doc_test.dart',
    'test/sync_network_doc_test.dart',
    'test/ui_style_guide_doc_test.dart',
  ],
};

/// 与 lib/tool Dart 业务文件相关的测试。
///
/// 查找顺序：
/// 0. `test/support/` fake：按 [_supportFakeImporters] 显式映射到真实
///    import 方（git grep 为真相源），不走关键词/stem 兜底；
/// 1. stem 直配：`test/{stem}_test.dart`、`test/{stem}_widget_test.dart`，
///    以及按被测对象目录组织的 `test/services/{stem}_test.dart`、
///    `test/models/{stem}_test.dart`；
/// 2. stem 前缀：`tool/build.dart` 的 stem 是 `build`，而测试名是
///    `build_tool_test`——stem 是测试名 stem 的前缀时选「含该前缀的最短
///    stem 测试」（最接近的一个）；
/// 3. tool/ 目录名回退：`tool/src/git_gate/x.dart` → `test/git_gate_test.dart`；
/// 4. 最后兜底：测试名含 stem 的所有文件。
List<String> _relatedDartTests(String file, TestIndex index) {
  final name = file.split('/').last;
  if (!name.endsWith('.dart')) {
    return const <String>[];
  }
  final stem = name.substring(0, name.length - '.dart'.length);

  // test/support/ fake：显式 importer 映射路由到真实消费方（映射缺失则
  // 不返回任何测试——宁可漏跑也不错配到无关集群）。
  final importers = _supportFakeImporters[stem];
  if (importers != null) {
    return importers.where(index.flutterTestFiles.contains).toList()..sort();
  }

  final candidates = <String>[
    'test/${stem}_test.dart',
    'test/${stem}_widget_test.dart',
    'test/services/${stem}_test.dart',
    'test/models/${stem}_test.dart',
  ];
  final hits = candidates.where(index.flutterTestFiles.contains).toList();
  if (hits.isNotEmpty) return hits..sort();

  // stem 前缀匹配：`build` 是 `build_tool` 的前缀 → test/build_tool_test.dart。
  // 取 stem 最短者（最接近）；并列按路径字典序保证稳定。
  String stemOf(String testPath) {
    final base = testPath.split('/').last;
    return base.substring(0, base.length - '_test.dart'.length);
  }

  final prefixed = index.flutterTestFiles
      .where((f) => f.endsWith('_test.dart') && stemOf(f).startsWith(stem))
      .toList();
  if (prefixed.isNotEmpty) {
    prefixed.sort((a, b) {
      final byLen = stemOf(a).length.compareTo(stemOf(b).length);
      return byLen != 0 ? byLen : a.compareTo(b);
    });
    return <String>[prefixed.first];
  }

  // tool/src/<dir>/x.dart → 目录名回退 test/<dir>_test.dart。
  if (file.startsWith('tool/src/')) {
    final dir = file.split('/')[2];
    final dirCandidate = 'test/${dir}_test.dart';
    if (index.flutterTestFiles.contains(dirCandidate)) {
      return <String>[dirCandidate];
    }
  }

  // 兜底：测试名含 stem（test/support fake 的 `_repository` 词根在此命中）。
  final contained =
      index.flutterTestFiles
          .where((f) => f.endsWith('_test.dart') && f.contains(stem))
          .toList()
        ..sort();
  return contained;
}

/// 真实 FRB smoke 集（存在才加入）。
List<String> _frbSmokeTests(TestIndex index) {
  const smokes = <String>[
    'test/api_integration_test.dart',
    'test/frb_note_repository_test.dart',
    'test/receiver_store_borrow_test.dart',
  ];
  return smokes.where(index.flutterTestFiles.contains).toList();
}

/// 相关 Rust 测试 target；返回 null 表示无明确映射 → 升级 Rust 全量。
List<String>? _relatedRustTargets(String file, TestIndex index) {
  final lower = file.toLowerCase();
  List<String> candidates;
  // 更具体的关键词放前面：security_sync / live_relay 含通用 sync/relay 词根，
  // 若排在后面会被先命中到通用 sync/relay 分支而漏掉对应 target。
  if (lower.contains('security_sync')) {
    candidates = const <String>['security_sync_test'];
  } else if (lower.contains('live_relay')) {
    candidates = const <String>['live_relay_test'];
  } else if (lower.contains('device_name')) {
    candidates = const <String>['device_name_test'];
  } else if (lower.contains('sync')) {
    candidates = const <String>[
      'sync_service_test',
      'receiver_continuous_test',
      'autosync_test',
      'connect_test',
      'security_sync_test',
    ];
  } else if (lower.contains('pairing_credential')) {
    candidates = const <String>['pairing_credential_test', 'pairing_test'];
  } else if (lower.contains('discovery') || lower.contains('pairing')) {
    candidates = const <String>[
      'discovery_test',
      'pairing_test',
      'pairing_credential_test',
    ];
  } else if (lower.contains('store')) {
    candidates = const <String>[
      'store_test',
      'note_crdt_test',
      'trash_test',
      'migration_test',
    ];
  } else if (lower.contains('trash')) {
    candidates = const <String>['trash_test', 'store_test', 'note_crdt_test'];
  } else if (lower.contains('api') || lower.contains('frb')) {
    candidates = const <String>['note_crdt_test', 'store_test', 'pairing_test'];
  } else if (lower.contains('debug')) {
    candidates = const <String>['debug_log_test'];
  } else if (lower.contains('migration')) {
    candidates = const <String>['migration_test'];
  } else if (lower.contains('relay')) {
    candidates = const <String>['relay_config_test', 'connect_test'];
  } else {
    return null;
  }
  final existing = candidates.where(index.rustTestTargets.contains).toList()
    ..sort();
  return existing.isEmpty ? null : existing;
}

/// 按 cargo 规则推导 `rust-backend/tests/` 路径是否为 test target；不是返回 null。
///
/// cargo 规则：`tests/foo.rs` → target `foo`；`tests/foo/main.rs` →
/// target `foo`（目录名，文件名 `main` 不是 target）；`tests/<dir>/`
/// 下其余文件（`common/mod.rs` 等被 `mod` 引入的模块）不是 target。
/// 输入为仓库相对路径，本函数自行校验前缀与 `.rs` 后缀。
String? rustTestTargetName(String path) {
  const prefix = 'rust-backend/tests/';
  if (!path.startsWith(prefix) || !path.endsWith('.rs')) return null;
  final rest = path.substring(prefix.length);
  final slash = rest.indexOf('/');
  if (slash == -1) {
    // tests/*.rs 直接子文件：stem 即 target 名。
    return rest.substring(0, rest.length - '.rs'.length);
  }
  // tests/<dir>/main.rs → target 为目录名；其他子目录文件不是 target。
  final base = rest.substring(slash + 1);
  if (!base.contains('/') && base == 'main.rs') {
    return rest.substring(0, slash);
  }
  return null;
}

/// `rust-backend/tool/<pkg>/…` → cargo package 名；不在子树内返回 null。
/// （workspace 成员 crate 名与目录名一致：`tool/boundary_scanner`。）
String? _rustToolPackage(String file) {
  const prefix = 'rust-backend/tool/';
  if (!file.startsWith(prefix)) return null;
  final rest = file.substring(prefix.length);
  final slash = rest.indexOf('/');
  return slash == -1 ? null : rest.substring(0, slash);
}
