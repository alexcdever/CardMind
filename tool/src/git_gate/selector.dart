/// 文件分类与快速门禁计划选择器（纯逻辑，不触碰文件系统）。
///
/// 输入 staged 文件路径（POSIX 相对路径），输出去重、稳定排序的命令计划。
/// 测试索引由调用方注入，保证可单测。
///
/// 4.6 起 Flutter 链整删：dartTest/dartBusiness/frbBoundary/flutterTest 路由
/// 与 `test/` 文件级聚合全部移除；前端测试只剩 nsh-app 的 TSX 全量
/// （`npx tsx --test "*_test.ts" "web/src/*_test.ts"`，在 nsh-app/ 跑）。
library;

import 'command.dart';

/// 文件类别。
enum FileCategory {
  markdown,
  tsxTest,
  tsxSource,
  rustSource,
  rustTest,
  rustTool,
  toolDart,
  manifest,
  platform,
  sharedConfig,
  ciWorkflow,
  releasePython,
  unknown,
}

/// 仓库现有测试资产索引。
class TestIndex {
  const TestIndex({
    this.rustTestTargets = const <String>{},
    this.rustApiConsumers = const <String>{},
  });

  /// 已存在的 Rust 测试 target（如 `sync_service_test`）。
  final Set<String> rustTestTargets;

  /// 引用 `api::`（FRB 导出层）的 Rust 测试 target 名。
  ///
  /// 待由 `scanTestIndex` 读 `rust-backend/tests/**/*.rs` 内容派生。
  final Set<String> rustApiConsumers;
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
    final steps = List<GateCommand>.of(_steps);
    steps.sort((a, b) {
      final byKind = a.kind.priority.compareTo(b.kind.priority);
      if (byKind != 0) return byKind;
      return a.signature.compareTo(b.signature);
    });
    return steps;
  }
}

/// 分类（路径归一化为 POSIX 风格；Windows 反斜杠与 POSIX 斜杠结果相同）。
FileCategory classifyPath(String path) {
  final p = normalizePath(path);
  if (p.endsWith('.md')) return FileCategory.markdown;
  if (_isTsxTest(p)) return FileCategory.tsxTest;
  if (_isTsxSource(p)) return FileCategory.tsxSource;
  if (_isRustTest(p)) return FileCategory.rustTest;
  if (_isRustTool(p)) return FileCategory.rustTool;
  if (_isRustSource(p)) return FileCategory.rustSource;
  if (_isToolDart(p)) return FileCategory.toolDart;
  if (_isManifest(p)) return FileCategory.manifest;
  if (_isPlatform(p)) return FileCategory.platform;
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

/// nsh-app 的 TS/TSX 测试文件（node --test 约定 `*_test.ts`/`_test.tsx`）。
bool _isTsxTest(String p) =>
    p.startsWith('nsh-app/') &&
    (p.endsWith('_test.ts') || p.endsWith('_test.tsx'));

/// nsh-app 其余源码/清单（.ts/.tsx/.mts/.cts 与 package.json/nsh.json/tsconfig）。
bool _isTsxSource(String p) {
  if (!p.startsWith('nsh-app/')) return false;
  return p.endsWith('.ts') ||
      p.endsWith('.tsx') ||
      p.endsWith('.mts') ||
      p.endsWith('.cts') ||
      p.endsWith('package.json') ||
      p.endsWith('package-lock.json') ||
      p.endsWith('tsconfig.json') ||
      p.endsWith('nsh.json');
}

bool _isRustTest(String p) =>
    p.startsWith('rust-backend/tests/') && p.endsWith('.rs');

/// rust-backend/tool/ 下的辅助 crate 源码（boundary_scanner 等，已纳入
/// workspace）：属 Rust 范畴但不是产品源码，归 rustTool——只跑 clippy，
/// 不升级 rust:test:full。
bool _isRustTool(String p) =>
    p.startsWith('rust-backend/tool/') && p.endsWith('.rs');

bool _isRustSource(String p) =>
    p.startsWith('rust-backend/src/') && p.endsWith('.rs');

/// 门禁/工具自身的 Dart 源码（tool/**/*.dart）：改它只跑 dart format +
/// docsLint，不升级双栈全量（tool 改动不影响产品代码正确性）。
bool _isToolDart(String p) => p.startsWith('tool/') && p.endsWith('.dart');

/// Cargo manifest（含 rust-backend/Cargo.toml、rust-backend/Cargo.lock）。
/// 按文件名匹配（Cargo 大小写不敏感；normalizePath 已保证反斜杠先归一化）。
bool _isManifest(String p) {
  final lower = p.toLowerCase();
  return lower.endsWith('cargo.toml') || lower.endsWith('cargo.lock');
}

bool _isPlatform(String p) =>
    p.startsWith('android/') ||
    p.startsWith('windows/') ||
    p.startsWith('linux/') ||
    p.startsWith('macos/') ||
    p.startsWith('ios/') ||
    p.startsWith('web/');

/// CI workflow（.github/workflows/*.yml）：改 CI 本身不用跑产品双栈全量；
/// 路由到唯一读 workflow 文件的 release_workflow_test（已随 test/ 删除，
/// 现仅打 docs lint + 保持窄分类不升级全量）。
bool _isCiWorkflow(String p) =>
    p.startsWith('.github/workflows/') &&
    (p.endsWith('.yml') || p.endsWith('.yaml'));

/// tool/release/*.py 发布脚本与其 unittest：只被 python -m unittest 覆盖，
/// 与 Rust/TSX 双栈无关——独立分类做窄路由；tool/release 之外的 .py 仍落
/// unknown（fail-closed 双栈全量）。
bool _isReleasePython(String p) =>
    p.startsWith('tool/release/') && p.endsWith('.py');

/// 影响全仓的根级共享配置；其余 *.yaml/*.json 归 unknown 兜底
/// （fail-closed 双栈全量）。
bool _isSharedConfig(String p) =>
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
      // 文档改动：markdown 引用 lint（文档契约测试已随 test/ 删除）。
      b.add(Commands.docsLint());
    case FileCategory.tsxTest:
    case FileCategory.tsxSource:
      // nsh-app 任何 TS/TSX 改动都跑 TSX 全量（单进程、秒级，无需文件级路由）。
      b.add(Commands.tsxTest());
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
    case FileCategory.toolDart:
      // tool/ 的 Dart 源码：format-first 已覆盖，补 docsLint 防止连带改文档。
      b.add(Commands.docsLint());
    case FileCategory.manifest:
      // Cargo manifest fail-closed 为 Rust 全量（clippy + cargo test 全量）；
      // endsWith 匹配覆盖 rust-backend/Cargo.toml 与 rust-backend/Cargo.lock。
      final toolPkg = _rustToolPackage(file);
      if (toolPkg != null) {
        // rust-backend/tool/ 子树 crate 的 manifest（boundary_scanner 等）：
        // 跑该 crate 自身 cargo test，不升级 rust:test:full。
        b.add(Commands.clippy());
        b.add(Commands.rustToolTest(toolPkg));
      } else {
        b.add(Commands.clippy());
        b.add(Commands.rustFullTest());
      }
    case FileCategory.platform:
      // 平台工程目录（android/linux/macos/windows/ios/web 根目录；注意
      // nsh-app/web/** 已被 tsxSource 先捕获，不会落到这里）暂不承担检查：
      // 其内容由 NSH 打包（npm run build）与 Rust 构建覆盖，门禁保持窄路由。
      break;
    case FileCategory.sharedConfig:
      b.add(Commands.clippy());
      b.add(Commands.rustFullTest());
      b.add(Commands.tsxTest());
    case FileCategory.ciWorkflow:
      // 改 CI 不跑产品双栈全量；无现存 Dart 契约测试后仅补 docs lint。
      b.add(Commands.docsLint());
    case FileCategory.releasePython:
      // 发布脚本/测试改动：只跑 tool/release 的 python unittest（窄路由），
      // 不升级 Rust/TSX 双栈全量。
      b.add(Commands.pythonReleaseTest());
    case FileCategory.unknown:
      b.add(Commands.clippy());
      b.add(Commands.rustFullTest());
      b.add(Commands.tsxTest());
  }
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
    // FRB 导出层，两类来源取并集（去重、稳定排序）：
    // 1. **可派生**：引用 `api::` 的 Rust 测试 target——真相源是测试源码
    //    内容，由 `scanTestIndex` 扫描派生（[TestIndex.rustApiConsumers]）。
    //    新增/重命名引用 api:: 的测试自动纳入，无需改本文件；
    // 2. **策展**：导出层直接覆盖的核心面（note_crdt / store / pairing）
    //    不引用 `api::`，是刻意规定的核心覆盖面，只能显式列出。
    candidates = <String>{
      ...index.rustApiConsumers,
      'note_crdt_test',
      'store_test',
      'pairing_test',
    }.toList();
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
