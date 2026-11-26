// 文件分类与快速门禁计划选择器（纯逻辑，不触碰文件系统）。
//
// 本文件由 tool/src/git_gate/selector.dart 移植为 Node.js ESM（1:1 语义等价）。
// 输入 staged 文件路径（POSIX 相对路径），输出去重、稳定排序的命令计划。
// 测试索引由调用方注入，保证可单测。
//
// 4.6 起 Flutter 链整删：dartTest/dartBusiness/frbBoundary/flutterTest 路由
// 与 `test/` 文件级聚合全部移除；前端测试只剩仓库根 app 的 TSX 全量
// （`npx tsx --test "*_test.ts"`，在仓库根跑）。
// JS 移植起：formatDart 步删除，toolDart 类别改判 tool/**/*.mjs|.js（toolScript）。
// 2026-11-26 起 nsh-app/ 层已去掉，app 源码直接在仓库根。

import { Commands } from './command.mjs';

/**
 * 文件类别。顺序与原 Dart enum 一致（index 用于 plan 输出的分类排序）。
 */
export const FileCategory = Object.freeze({
  markdown: Object.freeze({ name: 'markdown', index: 0 }),
  tsxTest: Object.freeze({ name: 'tsxTest', index: 1 }),
  tsxSource: Object.freeze({ name: 'tsxSource', index: 2 }),
  rustSource: Object.freeze({ name: 'rustSource', index: 3 }),
  rustTest: Object.freeze({ name: 'rustTest', index: 4 }),
  toolScript: Object.freeze({ name: 'toolScript', index: 6 }),
  manifest: Object.freeze({ name: 'manifest', index: 7 }),
  platform: Object.freeze({ name: 'platform', index: 8 }),
  sharedConfig: Object.freeze({ name: 'sharedConfig', index: 9 }),
  ciWorkflow: Object.freeze({ name: 'ciWorkflow', index: 10 }),
  releasePython: Object.freeze({ name: 'releasePython', index: 11 }),
  unknown: Object.freeze({ name: 'unknown', index: 12 }),
});

/** 仓库现有测试资产索引。 */
export class TestIndex {
  constructor({ rustTestTargets = new Set(), rustApiConsumers = new Set() } = {}) {
    /** 已存在的 Rust 测试 target（如 `sync_service_test`）。 */
    this.rustTestTargets = rustTestTargets;

    // 引用 `api::`（FRB 导出层）的 Rust 测试 target 名。
    // 由 `scanTestIndex` 读 `tests/**/*.rs` 内容派生。
    this.rustApiConsumers = rustApiConsumers;
  }
}

/** 选择结果。 */
export class GatePlan {
  constructor({ steps, files }) {
    /** 去重、稳定排序后的命令列表。 */
    this.steps = steps;

    /** 参与计划的文件（POSIX 相对路径，排序去重）。 */
    this.files = files;
  }

  /** 每类文件数（用于输出分类矩阵）。 */
  get categoryCounts() {
    const counts = new Map();
    for (const f of this.files) {
      const c = classifyPath(f);
      counts.set(c, (counts.get(c) ?? 0) + 1);
    }
    return counts;
  }
}

/** 命令构建器：同一命令只能出现一次。 */
class PlanBuilder {
  #seen = new Set();
  #steps = [];

  add(command) {
    if (!this.#seen.has(command.signature)) {
      this.#seen.add(command.signature);
      this.#steps.push(command);
    }
  }

  build() {
    const steps = [...this.#steps];
    steps.sort((a, b) => {
      const byKind = a.kind.priority - b.kind.priority;
      if (byKind !== 0) return byKind;
      return a.signature < b.signature ? -1 : a.signature > b.signature ? 1 : 0;
    });
    return steps;
  }
}

/** 分类（路径归一化为 POSIX 风格；Windows 反斜杠与 POSIX 斜杠结果相同）。 */
export function classifyPath(path) {
  const p = normalizePath(path);
  if (p.endsWith('.md')) return FileCategory.markdown;
  if (_isTsxTest(p)) return FileCategory.tsxTest;
  if (_isTsxSource(p)) return FileCategory.tsxSource;
  if (_isRustTest(p)) return FileCategory.rustTest;
  if (_isRustSource(p)) return FileCategory.rustSource;
  if (_isToolScript(p)) return FileCategory.toolScript;
  if (_isManifest(p)) return FileCategory.manifest;
  if (_isPlatform(p)) return FileCategory.platform;
  if (_isCiWorkflow(p)) return FileCategory.ciWorkflow;
  if (_isReleasePython(p)) return FileCategory.releasePython;
  if (_isSharedConfig(p)) return FileCategory.sharedConfig;
  return FileCategory.unknown;
}

/** 归一化路径为 POSIX 风格相对路径（用于分类与输出）。 */
export function normalizePath(path) {
  const p = path.replaceAll('\\', '/');
  return p.startsWith('./') ? p.substring(2) : p;
}

// 「app 路径」判据：app 源码在仓库根（2026-11-26 去掉 nsh-app/ 层后）。
// 命中条件：路径不含 `/`（仓库根级文件），或位于下列 app 子目录之一。
// 刻意不做「任意 .ts/.tsx 都算 app」——否则将来出现在 tool/、docs/ 下的
// 脚本会被误判成前端源码而跑 TSX 全量。
const _appDirs = [
  'components/',
  'note_list/',
  'editor_page/',
  'devices_page/',
  'trash_page/',
  'settings_page/',
  'src/',
  'tests/',
  'examples/',
];

function _isAppPath(p) {
  if (!p.includes('/')) return true;
  return _appDirs.some((d) => p.startsWith(d));
}

/** app 的 TS/TSX 测试文件（node --test 约定 `*_test.ts`/`_test.tsx`）。 */
function _isTsxTest(p) {
  return (
    _isAppPath(p) &&
    (p.endsWith('_test.ts') || p.endsWith('_test.tsx'))
  );
}

/** app 其余源码/清单（.ts/.tsx/.mts/.cts 与 package.json/nsh.json/tsconfig）。 */
function _isTsxSource(p) {
  if (!_isAppPath(p)) return false;
  return (
    p.endsWith('.ts') ||
    p.endsWith('.tsx') ||
    p.endsWith('.mts') ||
    p.endsWith('.cts') ||
    p.endsWith('package.json') ||
    p.endsWith('package-lock.json') ||
    p.endsWith('tsconfig.json') ||
    p.endsWith('nsh.json')
  );
}

function _isRustTest(p) {
  return p.startsWith('tests/') && p.endsWith('.rs');
}

function _isRustSource(p) {
  return p.startsWith('src/') && p.endsWith('.rs');
}

// 门禁/工具自身的 JS 源码（tool/**/*.mjs|.js）：改它只跑 docsLint，
// 不升级双栈全量（tool 改动不影响产品代码正确性）。
function _isToolScript(p) {
  return p.startsWith('tool/') && (p.endsWith('.mjs') || p.endsWith('.js'));
}

// Cargo manifest（Cargo.toml 与 Cargo.lock 在仓库根，是仓库唯一一份）。
// 按文件名匹配（Cargo 大小写不敏感；normalizePath 已保证反斜杠先归一化）。
function _isManifest(p) {
  const lower = p.toLowerCase();
  return lower.endsWith('cargo.toml') || lower.endsWith('cargo.lock');
}

function _isPlatform(p) {
  return (
    p.startsWith('android/') ||
    p.startsWith('windows/') ||
    p.startsWith('linux/') ||
    p.startsWith('macos/') ||
    p.startsWith('ios/') ||
    p.startsWith('web/')
  );
}

// CI workflow（.github/workflows/*.yml）：改 CI 本身不用跑产品双栈全量；
// 路由到唯一读 workflow 文件的 release_workflow_test（已随 test/ 删除，
// 现仅打 docs lint + 保持窄分类不升级全量）。
function _isCiWorkflow(p) {
  return (
    p.startsWith('.github/workflows/') &&
    (p.endsWith('.yml') || p.endsWith('.yaml'))
  );
}

// tool/release/*.py 发布脚本与其 unittest：只被 python -m unittest 覆盖，
// 与 Rust/TSX 双栈无关——独立分类做窄路由；tool/release 之外的 .py 仍落
// unknown（fail-closed 双栈全量）。
function _isReleasePython(p) {
  return p.startsWith('tool/release/') && p.endsWith('.py');
}

// 影响全仓的根级共享配置；其余 *.yaml/*.json 归 unknown 兜底
// （fail-closed 双栈全量）。
function _isSharedConfig(p) {
  return (
    p === '.gitignore' ||
    p.startsWith('.githooks/') ||
    // 根级 yaml/json（不含 /）才视作共享配置。
    (!p.includes('/') && (p.endsWith('.yaml') || p.endsWith('.json')))
  );
}

/** 根据 staged 文件生成计划。 */
export function selectPlanForFiles(files, { index }) {
  const normalized = files.map(normalizePath).sort();
  const unique = [];
  for (const f of normalized) {
    if (unique.length === 0 || unique[unique.length - 1] !== f) {
      unique.push(f);
    }
  }
  const builder = new PlanBuilder();
  builder.add(Commands.formatRust());

  for (const file of normalized) {
    _contribute(builder, file, index);
  }
  return new GatePlan({ steps: builder.build(), files: unique });
}

function _contribute(b, file, index) {
  const category = classifyPath(file);
  switch (category) {
    case FileCategory.markdown:
      // 文档改动：markdown 引用 lint（文档契约测试已随 test/ 删除）。
      b.add(Commands.docsLint());
      break;
    case FileCategory.tsxTest:
    case FileCategory.tsxSource:
      // app 任何 TS/TSX 改动都跑 TSX 全量（单进程、秒级，无需文件级路由）。
      b.add(Commands.tsxTest());
      break;
    case FileCategory.rustTest: {
      b.add(Commands.clippy());
      const target = rustTestTargetName(file);
      if (target == null) {
        // tests/ 子目录下的共享辅助（如 common/mod.rs）不是 cargo test
        // target——cargo test --test <stem> 必失败。fail-closed 升级
        // Rust 全量，覆盖所有 `mod common;` 引用方。
        b.add(Commands.rustFullTest());
      } else {
        b.add(Commands.rustTestTarget(target));
      }
      break;
    }
    case FileCategory.rustSource: {
      b.add(Commands.clippy());
      const targets = _relatedRustTargets(file, index);
      if (targets == null) {
        b.add(Commands.rustFullTest());
      } else {
        for (const t of targets) {
          b.add(Commands.rustTestTarget(t));
        }
      }
      break;
    }
    case FileCategory.toolScript:
      // tool/ 的 JS 源码：format-first（cargo fmt）不适用，补 docsLint 防止连带改文档。
      b.add(Commands.docsLint());
      break;
    case FileCategory.manifest: {
      // Cargo manifest fail-closed 为 Rust 全量（clippy + cargo test 全量）；
      // endsWith 匹配覆盖根级 Cargo.toml 与 Cargo.lock。
      b.add(Commands.clippy());
      b.add(Commands.rustFullTest());
      break;
    }
    case FileCategory.platform:
      // 平台工程目录（android/linux/macos/windows/ios/web 根目录）暂不承担
      // 检查：其内容由 NSH 打包（npm run build）与 Rust 构建覆盖，门禁保持
      // 窄路由。
      break;
    case FileCategory.sharedConfig:
      b.add(Commands.clippy());
      b.add(Commands.rustFullTest());
      b.add(Commands.tsxTest());
      break;
    case FileCategory.ciWorkflow:
      // 改 CI 不跑产品双栈全量；无现存契约测试后仅补 docs lint。
      b.add(Commands.docsLint());
      break;
    case FileCategory.releasePython:
      // 发布脚本/测试改动：只跑 tool/release 的 python unittest（窄路由），
      // 不升级 Rust/TSX 双栈全量。
      b.add(Commands.pythonReleaseTest());
      break;
    case FileCategory.unknown:
      b.add(Commands.clippy());
      b.add(Commands.rustFullTest());
      b.add(Commands.tsxTest());
      break;
  }
}

/** 相关 Rust 测试 target；返回 null 表示无明确映射 → 升级 Rust 全量。 */
function _relatedRustTargets(file, index) {
  const lower = file.toLowerCase();
  let candidates;
  // 更具体的关键词放前面：security_sync / live_relay 含通用 sync/relay 词根，
  // 若排在后面会被先命中到通用 sync/relay 分支而漏掉对应 target。
  if (lower.includes('security_sync')) {
    candidates = ['security_sync_test'];
  } else if (lower.includes('live_relay')) {
    candidates = ['live_relay_test'];
  } else if (lower.includes('device_name')) {
    candidates = ['device_name_test'];
  } else if (lower.includes('sync')) {
    candidates = [
      'sync_service_test',
      'receiver_continuous_test',
      'autosync_test',
      'connect_test',
      'security_sync_test',
    ];
  } else if (lower.includes('pairing_credential')) {
    candidates = ['pairing_credential_test', 'pairing_test'];
  } else if (lower.includes('discovery') || lower.includes('pairing')) {
    candidates = [
      'discovery_test',
      'pairing_test',
      'pairing_credential_test',
    ];
  } else if (lower.includes('store')) {
    candidates = [
      'store_test',
      'note_crdt_test',
      'trash_test',
      'migration_test',
    ];
  } else if (lower.includes('trash')) {
    candidates = ['trash_test', 'store_test', 'note_crdt_test'];
  } else if (lower.includes('api') || lower.includes('frb')) {
    // FRB 导出层，两类来源取并集（去重、稳定排序）：
    // 1. **可派生**：引用 `api::` 的 Rust 测试 target——真相源是测试源码
    //    内容，由 `scanTestIndex` 扫描派生（TestIndex.rustApiConsumers）。
    //    新增/重命名引用 api:: 的测试自动纳入，无需改本文件；
    // 2. **策展**：导出层直接覆盖的核心面（note_crdt / store / pairing）
    //    不引用 `api::`，是刻意规定的核心覆盖面，只能显式列出。
    candidates = [
      ...new Set([
        ...index.rustApiConsumers,
        'note_crdt_test',
        'store_test',
        'pairing_test',
      ]),
    ];
  } else if (lower.includes('debug')) {
    candidates = ['debug_log_test'];
  } else if (lower.includes('migration')) {
    candidates = ['migration_test'];
  } else if (lower.includes('relay')) {
    candidates = ['relay_config_test', 'connect_test'];
  } else {
    return null;
  }
  const existing = candidates
    .filter((t) => index.rustTestTargets.has(t))
    .sort();
  return existing.length === 0 ? null : existing;
}

/**
 * 按 cargo 规则推导 `tests/` 路径是否为 test target；不是返回 null。
 *
 * cargo 规则：`tests/foo.rs` → target `foo`；`tests/foo/main.rs` →
 * target `foo`（目录名，文件名 `main` 不是 target）；`tests/<dir>/`
 * 下其余文件（`common/mod.rs` 等被 `mod` 引入的模块）不是 target。
 * 输入为仓库相对路径，本函数自行校验前缀与 `.rs` 后缀。
 */
export function rustTestTargetName(path) {
  const prefix = 'tests/';
  if (!path.startsWith(prefix) || !path.endsWith('.rs')) return null;
  const rest = path.substring(prefix.length);
  const slash = rest.indexOf('/');
  if (slash === -1) {
    // tests/*.rs 直接子文件：stem 即 target 名。
    return rest.substring(0, rest.length - '.rs'.length);
  }
  // tests/<dir>/main.rs → target 为目录名；其他子目录文件不是 target。
  const base = rest.substring(slash + 1);
  if (!base.includes('/') && base === 'main.rs') {
    return rest.substring(0, slash);
  }
  return null;
}
