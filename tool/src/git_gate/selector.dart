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
  frbBoundary,
  manifest,
  platform,
  sharedConfig,
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

/// 命令构建器：同一命令只能出现一次。
class PlanBuilder {
  final Set<String> _seen = <String>{};
  final List<GateCommand> _steps = <GateCommand>[];

  void add(GateCommand command) {
    if (_seen.add(command.signature)) {
      _steps.add(command);
    }
  }

  List<GateCommand> build() {
    final sorted = List<GateCommand>.of(_steps)
      ..sort((a, b) {
        final byKind = a.kind.priority.compareTo(b.kind.priority);
        if (byKind != 0) return byKind;
        return a.signature.compareTo(b.signature);
      });
    return sorted;
  }
}

/// 分类（路径归一化为 POSIX 风格；Windows 反斜杠与 POSIX 斜杠结果相同）。
FileCategory classifyPath(String path) {
  final p = normalizePath(path);
  if (p.endsWith('.md')) return FileCategory.markdown;
  if (_isFrbBoundary(p)) return FileCategory.frbBoundary;
  if (_isDartTest(p)) return FileCategory.dartTest;
  if (_isRustTest(p)) return FileCategory.rustTest;
  if (_isRustSource(p)) return FileCategory.rustSource;
  if (_isDartBusiness(p)) return FileCategory.dartBusiness;
  if (_isManifest(p)) return FileCategory.manifest;
  if (_isPlatform(p)) return FileCategory.platform;
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

bool _isSharedConfig(String p) =>
    p == 'analysis_options.yaml' ||
    p == '.metadata' ||
    p == 'flutter_rust_bridge.yaml' ||
    p.endsWith('.yaml') ||
    p.endsWith('.yml') ||
    p.endsWith('.json') ||
    p.startsWith('.github/') ||
    p.startsWith('.githooks/') ||
    p.startsWith('.gitignore');

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
      _maybePairing(b, file, index);
      _maybeSync(b, file, index);
    case FileCategory.rustTest:
      b.add(Commands.clippy());
      b.add(Commands.rustTestTarget(_rustTestStem(file)));
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
        b.add(Commands.clippy());
        b.add(Commands.rustFullTest());
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
    case FileCategory.unknown:
      b.add(Commands.clippy());
      b.add(Commands.rustFullTest());
      b.add(Commands.analyze());
      b.add(Commands.flutterFullTest());
  }
}

const List<String> _pairingKeywords = <String>[
  'pairing',
  'device',
  'scanner',
  'discovery',
  // test/support fake 的文件名关键词：memory_note_repository /
  // credential_ui_repository 归入 dartBusiness 后，靠这两个词根命中
  // pairing 集群（含 devices_page_widget_test 等 extra 清单）。
  'memory',
  'credential',
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
    'test/receiver_continuous_test.dart',
    'test/trash_page_widget_test.dart',
  ];
  for (final t in syncTests) {
    if (index.flutterTestFiles.contains(t)) {
      b.add(Commands.flutterTest(<String>[t]));
    }
  }
}

/// 与 lib/tool Dart 业务文件相关的测试。
///
/// 查找顺序：
/// 1. stem 直配：`test/{stem}_test.dart`、`test/{stem}_widget_test.dart`，
///    以及按被测对象目录组织的 `test/services/{stem}_test.dart`、
///    `test/models/{stem}_test.dart`；
/// 2. stem 前缀：`tool/build.dart` 的 stem 是 `build`，而测试名是
///    `build_tool_test`——stem 是测试名 stem 的前缀时选「含该前缀的最短
///    stem 测试」（最接近的一个）；
/// 3. tool/ 目录名回退：`tool/src/git_gate/x.dart` → `test/git_gate_test.dart`；
/// 4. 最后兜底：测试名含 stem 的所有文件（test/support fake 的
///    `_repository` 词根走这条，如 memory_note_repository →
///    editor/note_list/trash/knowledge_base 等 widget 测试）。
List<String> _relatedDartTests(String file, TestIndex index) {
  final name = file.split('/').last;
  if (!name.endsWith('.dart')) {
    return const <String>[];
  }
  final stem = name.substring(0, name.length - '.dart'.length);
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

String _rustTestStem(String file) {
  final name = file.split('/').last;
  return name.endsWith('.rs')
      ? name.substring(0, name.length - '.rs'.length)
      : name;
}
