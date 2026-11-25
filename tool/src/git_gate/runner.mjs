// 外部进程执行器：15 分钟硬超时（`CARDMIND_GATE_STEP_TIMEOUT_MINUTES` 可调，可注入），超时终止完整进程树。
//
// 本文件由 tool/src/git_gate/runner.dart 移植为 Node.js ESM（1:1 语义等价，
// 只用 node:child_process 等内置模块）。测试模式（`CARDMIND_GATE_TEST_MODE=1`）下
// 所有命令走 fake runner，记录到 fake log 且不真实执行，供真实 hook 集成测试使用。

import { execFile, spawn, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);

/** 超时专用退出码。 */
export const kTimeoutExitCode = 124;

/** 单条命令的执行结果（elapsed 单位：毫秒）。 */
export class RunnerResult {
  constructor({ exitCode, stdout, stderr, timedOut, elapsed }) {
    this.exitCode = exitCode;
    this.stdout = stdout;
    this.stderr = stderr;
    this.timedOut = timedOut;
    this.elapsed = elapsed;
  }
}

/**
 * runner 签名（可注入 fake）：
 *   async (executable, args, { workingDirectory?, environment? }) => RunnerResult
 */

/**
 * 解析可执行文件：Windows 上 `flutter` → `flutter.bat`、`npx` → `npx.cmd`。
 *
 * 背景：Node `child_process.spawn`（与 Dart `Process.start` 一样走 CreateProcess）
 * 无法直接拉起 extensionless shim；npx 的标准 Node 安装 shim 是 .cmd 批处理。
 * npx 特殊在本机可能以 `npx.exe`（nvm/scoop）或 `npx.cmd`（官方 Node 安装）
 * 存在——只把确实存在的变体改写，否则原样返回交给系统 PATH 解析
 * （spawn 自己会找 `npx.exe`）。只有精确 executable 命中时才替换；
 * `git`、`cargo` 等其它可执行文件不受影响。非 Windows 原样返回。
 */
export function resolveExecutable(executable, { isWindows, environment } = {}) {
  if (!isWindows) return executable;
  if (executable === 'flutter') return 'flutter.bat';
  if (executable === 'npx') {
    return _firstOnPath(['npx.cmd', 'npx.exe', 'npx.bat'], { environment });
  }
  return executable;
}

/**
 * 在 PATH 上按候选名顺序找第一个存在的可执行文件；都不存在时返回 `npx`
 * （让 spawn 按 PATHEXT 解析到 `npx.exe`；硬编码 `.cmd` 会在
 * nvm/scoop 布局下必败）。
 */
function _firstOnPath(candidates, { environment } = {}) {
  const raw = (environment ?? process.env)['PATH'] ?? '';
  const dirs = raw.split(process.platform === 'win32' ? ';' : ':');
  for (const name of candidates) {
    for (const dir of dirs) {
      if (dir === '') continue;
      if (fs.existsSync(path.join(dir, name))) {
        return name;
      }
    }
  }
  // PATH 上找不到已知变体：返回无扩展名原名，交给 spawn 按 PATHEXT 自行解析
  // （如 `npx` → `npx.exe`）；硬编码 `.cmd` 会在 nvm/scoop 布局（只有
  // npx.exe）下必败。
  return 'npx';
}

/**
 * Git 为 hook / `--git-dir` 调用导出的仓库定位变量。
 *
 * 门禁运行的子进程（测试、构建、格式化）必须看不到这些变量：子进程内部的
 * `git` 调用会被重定向到外层仓库，从而污染外层仓库的 index/HEAD。典型场景是
 * 集成测试在临时仓库里执行 git，一旦外层导出了 `GIT_DIR`，临时仓库的
 * `git add/commit` 就会落到真实仓库上。
 */
export const kGitRepoEnvVars = [
  'GIT_DIR',
  'GIT_WORK_TREE',
  'GIT_INDEX_FILE',
  'GIT_COMMON_DIR',
  'GIT_OBJECT_DIRECTORY',
  'GIT_ALTERNATE_OBJECT_DIRECTORIES',
  'GIT_PREFIX',
];

/**
 * 返回剔除了 Git 仓库定位变量（kGitRepoEnvVars）的环境副本，用于隔离子进程。
 *
 * 其余变量原样保留；调用方传入的 `environment` 与当前进程环境都会被处理，
 * 因此子进程既能拿到必要变量，又不会继承门禁自身所在仓库的 git 定位信息。
 */
export function sanitizeStepEnvironment(base) {
  const env = { ...base };
  for (const key of kGitRepoEnvVars) {
    delete env[key];
  }
  return env;
}

/** 带硬超时的真实 runner + 测试模式 fake runner。 */
export class CommandRunner {
  static timeoutExitCode = kTimeoutExitCode;

  constructor({ timeout, testMode = false, fakeFail = false, fakeLog = null, realRunner = null }) {
    this.timeout = timeout;
    this.testMode = testMode;
    this.fakeFail = fakeFail;
    this.fakeLog = fakeLog;
    this._realRunner = realRunner ?? runWithTimeout;
  }

  run(executable, args, { workingDirectory = null, environment = null } = {}) {
    if (this.testMode) {
      // 测试模式记录逻辑命令（原始 executable），不掩盖真实解析；
      // 真实解析只作用于真实启动路径，见下方 resolveExecutable。
      return Promise.resolve(this._fakeRun(executable, args, workingDirectory));
    }
    // 所有真实 runner 入口统一经过解析：参数、cwd 保留；environment 剔除 Git
    // 仓库定位变量后显式传入（不传则子进程会继承外层仓库的 GIT_DIR 等，见
    // sanitizeStepEnvironment）。
    const resolved = resolveExecutable(executable, {
      isWindows: process.platform === 'win32',
    });
    return this._realRunner({
      executable: resolved,
      arguments: args,
      workingDirectory,
      environment: sanitizeStepEnvironment(environment ?? process.env),
      timeout: this.timeout,
    });
  }

  _fakeRun(executable, args, workingDirectory) {
    const line =
      `FAKE ${executable} ${args.join(' ')}` +
      (workingDirectory == null ? '' : ` (cwd=${workingDirectory})`);
    if (this.fakeLog != null) {
      try {
        fs.mkdirSync(path.dirname(this.fakeLog), { recursive: true });
        fs.appendFileSync(this.fakeLog, `${line}\n`);
      } catch (e) {
        // 无法写日志不致命（仅吞文件系统类错误，对齐 Dart `on FileSystemException`）。
        if (e == null || e.code == null) throw e;
      }
    }
    if (this.fakeFail) {
      return new RunnerResult({
        exitCode: 1,
        stdout: '',
        stderr: `[fake] forced failure: ${line}`,
        timedOut: false,
        elapsed: 0,
      });
    }
    return new RunnerResult({
      exitCode: 0,
      stdout: '',
      stderr: '',
      timedOut: false,
      elapsed: 0,
    });
  }
}

function _needsCmdShim(file) {
  const lower = file.toLowerCase();
  return lower.endsWith('.cmd') || lower.endsWith('.bat');
}

/**
 * Windows 上 cmd.exe 批处理（.cmd/.bat）的启动包装。
 *
 * Node ≥20.12 起 spawn 拒绝直接执行 .cmd/.bat（CVE-2024-27980，EINVAL），
 * 必须显式经 cmd.exe。`/d /s /c` + 单条命令行参数与 Node `shell:true` 等价；
 * windowsVerbatimArguments 保证参数原样交给 cmd 解析，避免 Node 默认转义
 * 在 cmd 元字符（如 `*_test.ts` 的 `*`）上误引号。
 * 仅处理门禁实际用到的简单字符（字母数字、._-/、* 与 =），
 * 含空格/&/|/< >/引号等 cmd 特殊字符的参数在本工具链中不会出现。
 */
function _cmdShimLine(executable, args) {
  const quote = (s) =>
    /^[A-Za-z0-9_\-./:=*+@]+$/.test(s) ? s : `"${s.replaceAll('"', '""')}"`;
  return [executable, ...args].map(quote).join(' ');
}

/**
 * 运行外部命令并强制 hard timeout。
 *
 * 超时行为：
 * - Windows：`taskkill /T /F` 终止完整进程树；
 * - POSIX：`pgrep -P` 递归收集后代后自底向上 kill；
 * - 返回 exit code 124 + `TIMEOUT` 标记 + 命令/耗时信息；
 * - 绝不无限等待。
 */
export function runWithTimeout({
  executable,
  arguments: args,
  workingDirectory = null,
  environment = null,
  timeout,
}) {
  return new Promise((resolve, reject) => {
    let spawnFile = executable;
    let spawnArgs = args;
    if (process.platform === 'win32' && _needsCmdShim(executable)) {
      spawnFile = process.env.ComSpec ?? 'cmd.exe';
      spawnArgs = ['/d', '/s', '/c', _cmdShimLine(executable, args)];
    }
    const child = spawn(spawnFile, spawnArgs, {
      cwd: workingDirectory ?? undefined,
      // Node 的 env 语义 = 完整替换（不传则继承父环境）；门禁侧已显式传入
      // 剔除 GIT_* 定位变量的完整环境副本，语义与 Dart
      // `includeParentEnvironment: environment == null` 等价。
      env: environment ?? undefined,
      windowsVerbatimArguments: true,
    });

    const stdoutChunks = [];
    const stderrChunks = [];
    child.stdout.on('data', (c) => stdoutChunks.push(c));
    child.stderr.on('data', (c) => stderrChunks.push(c));
    child.on('error', reject);

    const start = Date.now();
    let done = false;

    const killTree = async () => {
      try {
        if (process.platform === 'win32') {
          // taskkill /T 终止完整进程树；taskkill 本身也套超时，防挂死。
          // Node ≥20.12 对 taskkill.exe（非 .cmd）可直接 spawn。
          const killer = spawn('taskkill', ['/PID', String(child.pid), '/T', '/F']);
          const killerDone = new Promise((r) => killer.on('close', r));
          killer.on('error', r);
          await Promise.race([killerDone, new Promise((r) => setTimeout(r, 10_000))]);
        } else {
          // POSIX：递归收集后代（pgrep -P）后自底向上 kill
          await killTreePosix(child.pid);
        }
      } catch {
        // 忽略清理失败
      }
    };

    const timer = setTimeout(async () => {
      if (done) return;
      done = true;
      await killTree();
      resolve(
        new RunnerResult({
          exitCode: kTimeoutExitCode,
          stdout: Buffer.concat(stdoutChunks).toString('utf8'),
          stderr:
            `${Buffer.concat(stderrChunks).toString('utf8')}\n` +
            `[gate] TIMEOUT after ${Math.floor(timeout / 1000)}s: ` +
            `${executable} ${args.join(' ')}`,
          timedOut: true,
          elapsed: Date.now() - start,
        }),
      );
    }, timeout);

    // 'close' 在所有 stdio 关闭后触发：stdout/stderr 缓冲此时已齐，
    // 等价于 Dart `process.exitCode` + 50ms 流冲刷延迟的组合。
    child.on('close', (code) => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      resolve(
        new RunnerResult({
          exitCode: code ?? -1,
          stdout: Buffer.concat(stdoutChunks).toString('utf8'),
          stderr: Buffer.concat(stderrChunks).toString('utf8'),
          timedOut: false,
          elapsed: Date.now() - start,
        }),
      );
    });
  });
}

/** POSIX 进程树终止：pgrep -P 递归收集后代，自底向上 kill。 */
export async function killTreePosix(pid) {
  const children = [];
  const stack = [pid];
  while (stack.length > 0) {
    const parent = stack.pop();
    try {
      const { stdout } = await execFileAsync('pgrep', ['-P', String(parent)]);
      for (const line of String(stdout).split('\n')) {
        const p = parseInt(line.trim(), 10);
        if (!Number.isNaN(p)) {
          children.push(p);
          stack.push(p);
        }
      }
    } catch {
      // pgrep 不可用/无子进程时只杀父进程
    }
  }
  for (const child of children.reverse()) {
    try {
      process.kill(child);
    } catch {
      // ignore
    }
  }
  try {
    process.kill(pid);
  } catch {
    // ignore
  }
}

/**
 * 供 gate/git 模块内部复用的同步 git 执行（非 runner 链：这是门禁自己的
 * 仓库查询，保留 GIT_* 定位变量）。
 */
export function _spawnGitSync(args, { cwd } = {}) {
  return spawnSync('git', args, { cwd, encoding: 'utf8' });
}
