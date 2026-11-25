// 门禁编排：pre-commit 快速相关门禁、pre-push 完整 host suite、full。
//
// 本文件由 tool/src/git_gate/gate.dart 移植为 Node.js ESM（1:1 语义等价）。
// 差异（按任务语义决策）：format-first 只剩 `cargo fmt --all`（dart format 步骤删除），
// docsLint 改为 `node tool/lint/markdown_references_linter.mjs`。

import fs from 'node:fs';
import path from 'node:path';

import { CacheCheckInput, GateCache, computeGateFingerprint } from './cache.mjs';
import { CommandKind, Commands } from './command.mjs';
import { Formatter } from './formatter.mjs';
import {
  dirtyTrackedSourceFiles,
  headSha,
  localShasOf,
  readStdinLines,
  stagedFiles,
  untrackedSourceFiles,
} from './git.mjs';
import { CommandRunner } from './runner.mjs';
import { TestIndex, rustTestTargetName, selectPlanForFiles } from './selector.mjs';

/** 门禁依赖与开关（全部可注入，便于单测）。 */
export class GateOptions {
  constructor({
    repoRoot,
    runner,
    stepTimeout,
    log,
    logError,
    index = null,
    stagedFilesOverride = null,
    pushRefLinesOverride = null,
    forceFullCheck = false,
    dryRun = false,
    testLogWriter = null,
  }) {
    this.repoRoot = repoRoot;
    this.runner = runner;
    this.stepTimeout = stepTimeout;
    this.log = log;
    this.logError = logError;

    /** 现有测试资产索引；null 时按文件系统扫描。 */
    this.index = index;

    /** pre-commit 指定 staged 文件（测试/工具用）。 */
    this.stagedFilesOverride = stagedFilesOverride;

    /** pre-push stdin ref 行（测试注入）。 */
    this.pushRefLinesOverride = pushRefLinesOverride;

    /** CARDMIND_FORCE_FULL_CHECK=1：忽略缓存。 */
    this.forceFullCheck = forceFullCheck;

    /** 只打印计划，不格式化、不运行命令。 */
    this.dryRun = dryRun;

    /** 测试模式下额外写入 fake log 的行（如 REFS）。 */
    this.testLogWriter = testLogWriter;
  }

  copyWith({ index, stagedFilesOverride, forceFullCheck, dryRun } = {}) {
    return new GateOptions({
      repoRoot: this.repoRoot,
      runner: this.runner,
      stepTimeout: this.stepTimeout,
      log: this.log,
      logError: this.logError,
      index: index ?? this.index,
      stagedFilesOverride: stagedFilesOverride ?? this.stagedFilesOverride,
      pushRefLinesOverride: this.pushRefLinesOverride,
      forceFullCheck: forceFullCheck ?? this.forceFullCheck,
      dryRun: dryRun ?? this.dryRun,
      testLogWriter: this.testLogWriter,
    });
  }
}

/**
 * 扫描仓库现有测试资产（仅 Rust 测试 target；Flutter/Dart 测试索引已随
 * lib/test 整删移除——门禁 TSX 侧只有全量 `npx tsx --test`，不做文件级路由）。
 */
export async function scanTestIndex(repoRoot) {
  // 引用 `api::` 的 Rust 测试 target（派生，不手抄）。
  const apiConsumers = new Set();
  const rust = new Set();
  const rustTestsDir = path.join(repoRoot, 'nsh-app', 'tests');
  if (fs.existsSync(rustTestsDir)) {
    // 递归扫描按 cargo target 规则索引（与 selector 的 rustTestTargetName
    // 同语义）：tests/*.rs 与 tests/<dir>/main.rs 是 target；子目录其余
    // 文件（tests/common/mod.rs 等被 `mod` 引入的共享辅助）不是 target，
    // 不得入索引——否则分类器会给它生成不存在的 cargo test --test <stem>。
    for (const f of _listFilesRecursive(rustTestsDir)) {
      const rel = _repoRelative(repoRoot, f);
      const target = rustTestTargetName(rel);
      if (target == null) continue;
      rust.add(target);
      // 顺带派生「引用 `api::` 的 target」：`api.rs` 导出层已于 P1 死代码清理
      // 删除（2026-11），该集合当前为空；保留派生逻辑是为了让 selector 的
      // `api|frb` 路由在导出层回归时自动纳入真实消费方，而不必手抄名单
      // （手抄表必然漂移，新增引用 api:: 的测试不会被门禁选中，fail-silent）。
      // 只对 target 文件派生：common/mod.rs 等共享辅助即使含 api:: 也不是
      // cargo target，不得记成消费方。
      if (rustApiRefPattern.test(fs.readFileSync(f, 'utf8'))) {
        apiConsumers.add(target);
      }
    }
  }
  return new TestIndex({ rustTestTargets: rust, rustApiConsumers: apiConsumers });
}

/**
 * Rust 测试源码里引用 FRB 导出层的形态（导出层已删，逻辑保留以备回归）。
 *
 * 两个分支：
 * 1. `api::…`（任意前缀路径：`api::x`、`nsh_app_cardmind::kernel::api::x`、
 *    `crate::api::x`）——`api` 作为路径段，前面是非标识符边界，
 *    所以 `my_api::x`、`api_helpers::x` 不命中；
 * 2. `use …::api;` / `use …::api as A;` / `use {…, …::api}`——整路径
 *    引入 `api` 模块本身（此时后续调用不带 `api::` 前缀）。
 *
 * 命中即该文件是 `api::` 的消费方。宁可多匹配（多跑一个 target 只是慢），
 * 不可漏（漏跑 = fail-silent，改了导出层却没测真实消费方）。
 */
const rustApiRefPattern =
  /(?:^|[^\w])api\s*::|\buse\s+[^;]*?\bapi\s*(?:as\b|[;,}])/;

function _listFilesRecursive(dir) {
  const files = [];
  const walk = (d) => {
    for (const entity of fs.readdirSync(d, { withFileTypes: true })) {
      const full = path.join(d, entity.name);
      if (entity.isDirectory()) {
        walk(full);
      } else if (entity.isFile()) {
        files.push(full);
      }
    }
  };
  walk(dir);
  return files;
}

/** pre-commit：format-first → 按 staged 分类执行快速门禁。 */
export async function runPreCommit(o) {
  const index = o.index ?? (await scanTestIndex(o.repoRoot));
  const formatter = new Formatter({
    repoRoot: o.repoRoot,
    runner: o.runner,
    timeout: o.stepTimeout,
  });

  if (!o.dryRun) {
    const format = await formatter.formatAll();
    if (format.error != null) {
      o.logError(`[format-first] ${format.error}`);
      return 1;
    }
    if (format.changedPaths.length > 0) {
      o.logError('format-first 改变了以下文件，提交被阻止。请检查并重新暂存/提交：');
      for (const p of format.changedPaths) {
        o.logError(`  ${p}`);
      }
      o.logError('本轮未运行任何检查；未自动 git add。');
      return 1;
    }
  }

  const staged = o.stagedFilesOverride ?? stagedFiles(o.repoRoot);
  const plan = selectPlanForFiles(staged, { index });
  printPlan(o, plan, { title: 'pre-commit' });

  if (o.dryRun) {
    o.log('[dry-run] 仅打印计划，未执行任何命令。');
    return 0;
  }

  for (const step of plan.steps) {
    if (step.kind === CommandKind.formatRust) {
      continue; // format-first 已执行
    }
    const exit = await _runStep(o, step);
    if (exit !== 0) return exit;
  }
  o.log('✅ pre-commit 门禁通过');
  return 0;
}

/** pre-push：format-first → 工作树一致性 → 缓存 → 完整 host suite。 */
export async function runPrePush(o) {
  const formatter = new Formatter({
    repoRoot: o.repoRoot,
    runner: o.runner,
    timeout: o.stepTimeout,
  });

  if (!o.dryRun) {
    const format = await formatter.formatAll();
    if (format.error != null) {
      o.logError(`[format-first] ${format.error}`);
      return 1;
    }
    if (format.changedPaths.length > 0) {
      o.logError('format-first 改变了以下文件，push 被阻止。请检查并提交：');
      for (const p of format.changedPaths) {
        o.logError(`  ${p}`);
      }
      return 1;
    }
  }

  const dirty = dirtyTrackedSourceFiles(o.repoRoot);
  const untracked = untrackedSourceFiles(o.repoRoot);
  const worktreeClean = dirty.length === 0 && untracked.length === 0;
  if (!worktreeClean) {
    if (dirty.length > 0) {
      o.logError('存在未提交的 tracked 源码（与 HEAD 不一致）：');
      for (const p of dirty) {
        o.logError(`  ${p}`);
      }
    }
    if (untracked.length > 0) {
      o.logError('存在未跟踪源码：');
      for (const p of untracked) {
        o.logError(`  ${p}`);
      }
    }
    o.logError('pre-push 要求将测试的 tracked 源码与 HEAD 一致，且无未跟踪源码。');
    if (!o.dryRun) {
      o.logError('请先提交或清理后再 push。');
      return 1;
    }
    o.log('[dry-run] 仅提示，未阻止。');
  }

  // dry-run 且无显式注入时跳过 stdin 读取，避免交互终端挂起
  const refLines =
    o.dryRun && o.pushRefLinesOverride == null
      ? []
      : (o.pushRefLinesOverride ?? (await readStdinLines()));
  for (const ref of refLines) {
    o.log(`[push-ref] ${ref}`);
    o.testLogWriter?.('REFS ' + ref);
  }

  const head = await headSha(o.repoRoot);
  const fingerprint = computeGateFingerprint(o.repoRoot);

  if (!o.dryRun && !o.forceFullCheck && head != null) {
    const cache = GateCache.forGitDir(o.repoRoot);
    const check = await cache.checkAsync({
      repoRoot: o.repoRoot,
      input: new CacheCheckInput({
        headSha: head,
        fingerprint,
        localShas: localShasOf(refLines),
        worktreeClean,
      }),
    });
    if (check.hit) {
      o.log(`缓存命中（${check.reason}），跳过完整 suite。`);
      o.testLogWriter?.('CACHE HIT');
      o.log('✅ pre-push 门禁通过（缓存）');
      return 0;
    }
    o.log(`缓存未命中（${check.reason}），执行完整 host suite。`);
  }

  o.log('完整 host suite：');
  const code = await runFullSuite(o);
  if (code !== 0) return code;

  if (!o.dryRun && head != null) {
    const cache = GateCache.forGitDir(o.repoRoot);
    cache.write({
      input: new CacheCheckInput({
        headSha: head,
        fingerprint,
        localShas: localShasOf(refLines),
        worktreeClean: true,
      }),
    });
    o.log(`缓存已写入 .git/cardmind_gate_cache.json（HEAD ${head}）`);
  }
  o.log('✅ pre-push 门禁通过');
  return 0;
}

/** `full`：完整 host suite（真实执行一次；不做 dirty 阻止，但 format-first 阻止）。 */
export async function runFull(o) {
  const formatter = new Formatter({
    repoRoot: o.repoRoot,
    runner: o.runner,
    timeout: o.stepTimeout,
  });

  if (!o.dryRun) {
    const format = await formatter.formatAll();
    if (format.error != null) {
      o.logError(`[format-first] ${format.error}`);
      return 1;
    }
    if (format.changedPaths.length > 0) {
      o.logError('format-first 改变了以下文件，中止：');
      for (const p of format.changedPaths) {
        o.logError(`  ${p}`);
      }
      return 1;
    }
  }

  const code = await runFullSuite(o);
  if (code !== 0) return code;

  if (!o.dryRun) {
    const head = await headSha(o.repoRoot);
    if (head != null) {
      const cache = GateCache.forGitDir(o.repoRoot);
      cache.write({
        input: new CacheCheckInput({
          headSha: head,
          fingerprint: computeGateFingerprint(o.repoRoot),
          localShas: [],
          worktreeClean: true,
        }),
      });
      o.log(`缓存已写入 .git/cardmind_gate_cache.json（HEAD ${head}）`);
    }
  }
  o.log('✅ full 门禁通过');
  return 0;
}

/**
 * 完整 host suite：docs lint → clippy → cargo test 全量 → build-lib
 * （`cargo build --release`，只做 release 构建检查）→ 再次 format-first
 * （改变则阻止）→ tsx test 全量。
 * （frb codegen、flutter analyze/test 与 Flutter 时代 runtime 库复制已随
 * lib/ 整删移除；NSH 把 backend 作为 crate 编进 nsh-app，无运行态 dylib。）
 */
export async function runFullSuite(o) {
  const steps = [
    Commands.docsLint(),
    Commands.clippy(),
    Commands.rustFullTest(),
    Commands.hostBuildLib(),
  ];
  for (const step of steps) {
    const exit = await _runStep(o, step);
    if (exit !== 0) return exit;
  }

  // 第二次 format-first（dry-run 只打印；真实跑时改变文件则阻止）。
  if (o.dryRun) {
    o.log('  [dry-run] format-first #2');
  } else {
    const formatter = new Formatter({
      repoRoot: o.repoRoot,
      runner: o.runner,
      timeout: o.stepTimeout,
    });
    const format2 = await formatter.formatAll();
    if (format2.error != null) {
      o.logError(`[format-first #2] ${format2.error}`);
      return 1;
    }
    if (format2.changedPaths.length > 0) {
      o.logError('第二轮 format-first 改变了文件，push 被阻止：');
      for (const p of format2.changedPaths) {
        o.logError(`  ${p}`);
      }
      return 1;
    }
  }

  const test = await _runStep(o, Commands.tsxTest());
  if (test !== 0) return test;
  return 0;
}

async function _runStep(o, step) {
  if (o.dryRun) {
    o.log(`  [dry-run] ${step}`);
    return 0;
  }
  o.log(`==> ${step}`);
  const wd =
    step.workingDirectory == null
      ? o.repoRoot
      : `${o.repoRoot}/${step.workingDirectory.replaceAll('\\', '/')}`;
  const r = await o.runner(step.executable, step.arguments, {
    workingDirectory: wd,
  });
  if (r.exitCode !== 0) {
    const timeoutMark = r.timedOut
      ? ` TIMEOUT(${Math.floor(o.stepTimeout / 1000)}s)`
      : '';
    o.logError(
      `[fail] ${step.label} exit=${r.exitCode}${timeoutMark} ` +
        `elapsed=${Math.floor(r.elapsed / 1000)}s`,
    );
    // 步骤把有用输出写在 stdout 的（docs:lint 缺失清单），转发到 stderr，
    // 否则只剩一行 [fail]、看不到原因；与 stderr 相同则跳过避免重复。
    const stdoutText = r.stdout.trim();
    if (stdoutText.length > 0 && stdoutText !== r.stderr.trim()) {
      o.logError(`[stdout] ${step.label}`);
      o.logError(r.stdout);
    }
    o.logError(r.stderr);
    return r.timedOut ? CommandRunner.timeoutExitCode : r.exitCode;
  }
  return 0;
}

/** 打印结构化计划（不执行）。 */
export function printPlan(o, plan, { title }) {
  o.log(`CardMind git gate — ${title}`);
  o.log(`Files (${plan.files.length}):`);
  for (const f of plan.files) {
    o.log(`  ${f}`);
  }
  const counts = [...plan.categoryCounts.entries()]
    .filter(([, value]) => value > 0)
    .sort((a, b) => a[0].index - b[0].index);
  o.log('Categories:');
  for (const [c, value] of counts) {
    o.log(`  ${c.name}: ${value}`);
  }
  o.log('Format-first:');
  // JS 移植起只剩 Rust（dart format 步骤已删除）。
  o.log(`  ${Commands.formatRust()}`);
  o.log(`Checks (${plan.steps.length - 1} commands, deduped):`);
  for (const s of plan.steps.slice(1)) {
    o.log(`  ${s}`);
  }
}

function _repoRelative(repoRoot, absPath) {
  const root = repoRoot.replaceAll('\\', '/');
  let rel = absPath.replaceAll('\\', '/');
  if (rel.startsWith(root)) {
    rel = rel.substring(root.length);
    if (rel.startsWith('/')) rel = rel.substring(1);
  }
  return rel;
}
