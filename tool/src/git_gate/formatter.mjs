// format-first：先格式化全部源码，再比较内容快照（CRLF 归一化）。
//
// 本文件由 tool/src/git_gate/formatter.dart 移植为 Node.js ESM。
// JS 移植起仓库不再有 .dart 文件，`dart format tool` 步骤（formatDart）已删除，
// 只剩 `cargo fmt --all`。
//
// 关键点：
// - formatter 必须真的写入文件（不 `--check`）；
// - 快照覆盖 tracked/untracked 文件；
// - 内容比较做 CRLF→LF 归一化，避免 Windows autocrlf 环境把
//   纯换行差异误判为“formatter 改变了文件”；
// - 不自动 `git add`，不修改 index。

import fs from 'node:fs';
import path from 'node:path';

/** 格式化结果。 */
export class FormatOutcome {
  constructor({ changedPaths, error = null, commandsRun = [] }) {
    /** formatter 实际改变的文件（POSIX 相对路径，排序）。 */
    this.changedPaths = changedPaths;

    /** formatter 命令失败信息；null 表示命令成功。 */
    this.error = error;

    /** 实际执行的命令描述（用于测试与日志）。 */
    this.commandsRun = commandsRun;
  }
}

const kFnvMask = 0xffffffffffffffffn;
const kFnvPrime = 0x100000001b3n;
const kFnvOffsetBasis = 0xcbf29ce484222325n;

function _fnvFold(hash, s) {
  let h = hash;
  for (let i = 0; i < s.length; i++) {
    h ^= BigInt(s.charCodeAt(i));
    h = (h * kFnvPrime) & kFnvMask;
  }
  return h;
}

/** 内容归一化哈希（FNV-1a 64；CRLF→LF 后计算）。 */
export function normalizedContentHash(content) {
  const normalized = content.replaceAll('\r\n', '\n');
  return _fnvFold(kFnvOffsetBasis, normalized).toString(16);
}

/** 收集目录下所有匹配后缀的文件（递归，排除 target/.git/build 等）。 */
export function snapshotSources(repoRoot, dirs, suffix) {
  const result = new Map();
  const excluded = new Set([
    'target',
    '.git',
    'build',
    '.dart_tool',
    '.worktrees',
  ]);
  for (const dir of dirs) {
    const abs = path.join(repoRoot, ...dir.replaceAll('\\', '/').split('/'));
    if (!fs.existsSync(abs)) continue;
    const walk = (d) => {
      for (const entity of fs.readdirSync(d, { withFileTypes: true })) {
        const full = path.join(d, entity.name);
        if (entity.isDirectory()) {
          if (excluded.has(entity.name)) continue;
          walk(full);
        } else if (entity.isFile() && full.endsWith(suffix)) {
          const relative = _relativePosix(repoRoot, full);
          result.set(relative, normalizedContentHash(fs.readFileSync(full, 'utf8')));
        }
      }
    };
    walk(abs);
  }
  return result;
}

/** 生成文件快照——FRB codegen 已随 lib/ 整删，`frb_generated.rs` 不存在，
 * 故不再有生成物需要纳入快照（原实现只观测该文件，已删除）。 */

function _relativePosix(repoRoot, p) {
  const abs = p.replaceAll('\\', '/');
  const root = repoRoot.replaceAll('\\', '/');
  if (abs.startsWith(root)) {
    let rel = abs.substring(root.length);
    if (rel.startsWith('/')) rel = rel.substring(1);
    return rel;
  }
  return abs;
}

/** formatter：执行命令 → 快照对比。 */
export class Formatter {
  constructor({ repoRoot, runner, timeout }) {
    this.repoRoot = repoRoot;
    this.runner = runner;
    this.timeout = timeout;
  }

  async formatRust() {
    if (!fs.existsSync(path.join(this.repoRoot, 'nsh-app'))) {
      return new FormatOutcome({ changedPaths: [] });
    }
    // 快照必须传窄目录：`['nsh-app']` 会递归遍历 node_modules/ 与 .nsh/，
    // 既慢又会把生成物算成「formatter 改了文件」。
    const rustDirs = ['nsh-app/src', 'nsh-app/tests', 'nsh-app/examples'];
    const before = snapshotSources(this.repoRoot, rustDirs, '.rs');
    const result = await this.runner('cargo', ['fmt', '--all'], {
      workingDirectory: `${this.repoRoot}/nsh-app`,
    });
    if (result.exitCode !== 0) {
      return new FormatOutcome({
        changedPaths: [],
        error: `cargo fmt failed (exit ${result.exitCode}): ${result.stderr}`,
        commandsRun: ['cargo fmt --all (in nsh-app)'],
      });
    }
    const after = snapshotSources(this.repoRoot, rustDirs, '.rs');
    return new FormatOutcome({
      changedPaths: _changed(before, after),
      commandsRun: ['cargo fmt --all (in nsh-app)'],
    });
  }

  async formatAll() {
    // JS 移植起只剩 Rust：原 formatDart 步骤随 tool/**/*.dart 一起删除。
    const rust = await this.formatRust();
    return new FormatOutcome({
      changedPaths: [...rust.changedPaths].sort(),
      error: rust.error,
      commandsRun: [...rust.commandsRun],
    });
  }
}

function _changed(before, after) {
  const changed = new Set();
  for (const [key, value] of before.entries()) {
    if (after.get(key) !== value) {
      changed.add(key);
    }
  }
  for (const key of after.keys()) {
    if (!before.has(key)) {
      changed.add(key);
    }
  }
  return [...changed].sort();
}
