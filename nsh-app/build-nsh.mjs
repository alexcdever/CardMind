// nsh build 包装（NSH 0.3.0）。
//
// 0.2.0 起 nsh CLI 不再读 0.1.1 时代的源码 checkout 环境变量（crate 来源由 app
// crate 的 Cargo.toml 决定），但仍有一道硬门槛：CLI 版本必须与 Cargo.toml 的 nsh
// 依赖一致，否则 0.3.0 CLI 会在命令入口直接拒绝。这里先做一次版本一致性校验，
// 给出明确的错误（含两个版本号）并以非 0 退出。
//
// 用法：node build-nsh.mjs（在 nsh-app/ 下，等价于 `nsh build . -o out`）。
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const win = process.platform === 'win32';

/** 跑 nsh（Windows 上经 shell 解析 nsh.exe / nsh.cmd）。 */
function runNsh(args, { inherit = false } = {}) {
  return spawnSync('nsh', args, {
    cwd: here,
    encoding: inherit ? undefined : 'utf8',
    stdio: inherit ? 'inherit' : 'pipe',
    shell: win,
  });
}

/** 从 `nsh --version` 输出取版本号（形如 `nsh 0.3.0 (76fa8a7)`）。 */
export function parseCliVersion(text) {
  const m = /(\d+)\.(\d+)\.(\d+)/.exec(text ?? '');
  return m ? m[0] : null;
}

/** 从 Cargo.toml 取 nsh-core 的版本要求（形如 `nsh-core = "0.3.0"`）。 */
export function parseCargoVersion(manifest) {
  const m = /^\s*nsh-core\s*=\s*"([^"]+)"/m.exec(manifest ?? '');
  return m ? m[1] : null;
}

/** 版本是否兼容：0.x 要求 major.minor 相同（caret 语义），1+ 要求 major 相同。 */
export function versionMatches(cliVersion, required) {
  const cli = /^(\d+)\.(\d+)\.(\d+)/.exec(cliVersion ?? '');
  const req = /^[\^=~]?(\d+)\.(\d+)\.(\d+)/.exec(required ?? '');
  if (!cli || !req) return false;
  return cli[1] === req[1] && (cli[1] !== '0' || cli[2] === req[2]);
}

function fail(message) {
  console.error(`[build] ${message}`);
  process.exit(1);
}

const manifest = readFileSync(path.join(here, 'Cargo.toml'), 'utf8');
const required = parseCargoVersion(manifest);
if (!required) {
  fail('Cargo.toml 里找不到 `nsh-core = "…"`：无法校验 nsh CLI 版本');
}

const versionRun = runNsh(['--version']);
const rawVersion = `${versionRun.stdout ?? ''}${versionRun.stderr ?? ''}`.trim();
const cliVersion = parseCliVersion(rawVersion);
if (versionRun.error || !cliVersion) {
  fail(
    `无法运行 nsh（${versionRun.error?.message ?? `exit ${versionRun.status}`}）。\n` +
      `        请先安装与 Cargo.toml 的 nsh-core = "${required}" 一致的 nsh CLI，并确保它在 PATH 上。\n` +
      `        nsh --version 输出：${rawVersion || '(空)'}`,
  );
}
if (!versionMatches(cliVersion, required)) {
  fail(
    `nsh CLI 版本 ${cliVersion} 与 Cargo.toml 的 nsh-core = "${required}" 不一致：\n` +
      `        nsh ${cliVersion} 会在命令入口拒绝这个 app（a nsh app asks for nsh-core ^${required} and this nsh is ${cliVersion}）。\n` +
      `        请安装与依赖一致的 nsh（cargo install nsh-cli --version ${required}），或把 Cargo.toml 的 nsh-* 依赖改成 "${cliVersion}"。`,
  );
}

const result = runNsh(['build', '.', '-o', 'out'], { inherit: true });
if (result.error) {
  fail(`无法启动 nsh build：${result.error.message}`);
}
process.exit(result.status ?? 1);
