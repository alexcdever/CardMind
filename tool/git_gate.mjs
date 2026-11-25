// CardMind 本地质量门禁 CLI（Node.js 移植版，入口 `node tool/git_gate.mjs`，不再需要 Dart SDK）。
//
// 用法：
//   node tool/git_gate.mjs pre-commit [--dry-run] [--files <path...>]
//   node tool/git_gate.mjs pre-push    [--dry-run]
//   node tool/git_gate.mjs full        [--dry-run]
//   node tool/git_gate.mjs plan --staged | --files <path...>
//
// 环境变量：
//   SKIP_LOCAL_CHECK=1         （由 hook 处理）跳过门禁
//   CARDMIND_FORCE_FULL_CHECK=1  忽略 pre-push 缓存，强制完整 suite
//   CARDMIND_GATE_TEST_MODE=1    fake runner（真实 hook 集成测试用）
//   CARDMIND_GATE_FAKE_FAIL=1    测试模式下强制命令失败
//   CARDMIND_GATE_FAKE_LOG=path  测试模式 fake 日志路径
//
// 本文件由 tool/git_gate.dart 移植为 Node.js ESM（1:1 语义等价），仅使用
// Node 内置模块、零 npm 依赖。

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { runFull, runPreCommit, runPrePush, scanTestIndex, printPlan, GateOptions } from './src/git_gate/gate.mjs';
import { stagedFiles } from './src/git_gate/git.mjs';
import { CommandRunner } from './src/git_gate/runner.mjs';
import { selectPlanForFiles } from './src/git_gate/selector.mjs';

const _usage = `CardMind Git Gate — 本地质量门禁

用法:
  node tool/git_gate.mjs <pre-commit|pre-push|full|plan> [options]

Commands:
  pre-commit              按 staged 变更执行快速相关门禁（format-first）
  pre-push                完整 host suite（读取 Git stdin ref 行，支持 HEAD 缓存）
  full                    完整 host suite（独立执行，写缓存）
  plan                    只打印结构化计划，不格式化、不运行

Options:
  --dry-run               只打印将执行的命令
  --files <path...>       用给定文件代替 staged 文件（pre-commit/plan）
  --staged                读取 staged 文件（plan）
  -h, --help              显示帮助

环境变量:
  SKIP_LOCAL_CHECK=1         跳过门禁（由 hook 处理）
  CARDMIND_FORCE_FULL_CHECK=1 忽略 pre-push 缓存
  CARDMIND_GATE_TEST_MODE=1   测试模式（fake runner）
  CARDMIND_GATE_FAKE_FAIL=1   测试模式强制失败
  CARDMIND_GATE_FAKE_LOG=path 测试模式 fake 日志
  CARDMIND_GATE_STEP_TIMEOUT_MINUTES=n  单步硬超时（分钟，默认 15；Rust 全量
                             测试约需 4–5 分钟，勿设低于该值）
`;

export async function runGitGateCli(args) {
  if (args.includes('-h') || args.includes('--help')) {
    process.stdout.write(_usage + '\n');
    return 0;
  }
  if (args.length === 0) {
    process.stderr.write(_usage + '\n');
    return 1;
  }

  const env = process.env;
  const repoRoot = process.cwd();
  const testMode = env.CARDMIND_GATE_TEST_MODE === '1';
  const fakeLog =
    env.CARDMIND_GATE_FAKE_LOG ??
    (testMode ? `${repoRoot}/.git/cardmind-gate-fake.log` : null);

  // 单条命令硬超时（防卡死兜底）。默认 15 分钟：Rust 全量测试（
  // `cargo test --all-features --jobs 1`，编译 + 串行跑多个 test binary）
  // 常需 4–5 分钟，硬超时设短会误杀合法慢步骤。可用环境变量
  // `CARDMIND_GATE_STEP_TIMEOUT_MINUTES` 覆盖（分钟，整数）。
  const timeoutMinutes = Number.parseInt(
    env.CARDMIND_GATE_STEP_TIMEOUT_MINUTES ?? '',
    10,
  );
  const stepTimeout = (Number.isNaN(timeoutMinutes) ? 15 : timeoutMinutes) * 60 * 1000;

  const runner = new CommandRunner({
    timeout: stepTimeout,
    testMode,
    fakeFail: env.CARDMIND_GATE_FAKE_FAIL === '1',
    fakeLog,
  });

  const testWriter = (line) => {
    if (!testMode || fakeLog == null) return;
    try {
      fs.mkdirSync(path.dirname(fakeLog), { recursive: true });
      fs.appendFileSync(fakeLog, `${line}\n`);
    } catch (e) {
      // 与 Dart 的 `on FileSystemException` 同义：仅吞文件系统错误。
      if (e == null || typeof e.code !== 'string') throw e;
    }
  };

  const baseOptions = new GateOptions({
    repoRoot,
    runner: runner.run.bind(runner),
    stepTimeout,
    log: (m) => process.stdout.write(`${m}\n`),
    logError: (m) => process.stderr.write(`${m}\n`),
    forceFullCheck: env.CARDMIND_FORCE_FULL_CHECK === '1',
    testLogWriter: testWriter,
  });

  const command = args[0];
  const rest = args.slice(1);
  const dryRun = rest.includes('--dry-run');

  switch (command) {
    case 'pre-commit': {
      const files = _optionFiles(rest);
      return runPreCommit(
        baseOptions.copyWith({ stagedFilesOverride: files, dryRun }),
      );
    }
    case 'pre-push':
      return runPrePush(baseOptions.copyWith({ dryRun }));
    case 'full':
      return runFull(baseOptions.copyWith({ dryRun }));
    case 'plan':
      return _runPlan(baseOptions, rest);
    default:
      process.stderr.write(`未知命令: ${command}\n`);
      process.stderr.write(_usage + '\n');
      return 1;
  }
}

async function _runPlan(o, rest) {
  const index = await scanTestIndex(o.repoRoot);
  let files;
  if (rest.includes('--staged')) {
    files = stagedFiles(o.repoRoot);
  } else if (rest.includes('--files')) {
    files = _optionFiles(rest) ?? [];
  } else {
    process.stderr.write('plan 需要 --staged 或 --files <path...>\n');
    return 1;
  }
  const plan = selectPlanForFiles(files, { index });
  printPlan(o, plan, { title: 'plan' });
  return 0;
}

function _optionFiles(rest) {
  const idx = rest.indexOf('--files');
  if (idx === -1) return null;
  const files = rest.slice(idx + 1).filter((s) => s !== '--dry-run');
  return files.length === 0 ? null : files;
}

const isMain =
  process.argv[1] != null &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  process.exitCode = await runGitGateCli(process.argv.slice(2));
}
