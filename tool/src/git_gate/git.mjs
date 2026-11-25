// Git 仓库辅助（只读查询，供门禁使用）。
//
// 本文件由 tool/src/git_gate/git.dart 移植为 Node.js ESM（1:1 语义等价）。
// 注意：这里的 git 查询属于门禁自身（需要看到调用方的 GIT_* 定位变量），
// 不走 runner 的环境清洗；清洗只作用于门禁启动的检查/测试子进程。

import { spawnSync } from 'node:child_process';

/** git 命令失败（非 0 退出）。 */
export class GitException extends Error {
  constructor(message) {
    super(message);
    this.name = 'GitException';
  }

  toString() {
    return this.message;
  }
}

/** 对仓库根目录执行 git 命令，返回 stdout 行列表（去尾部空白、丢弃空行）。 */
export function gitLines(repoRoot, args, { input = null } = {}) {
  const result = spawnSync('git', args, {
    cwd: repoRoot,
    encoding: 'utf8',
    input: input ?? undefined,
  });
  if (result.error != null) {
    throw new GitException(
      `git ${args.join(' ')} failed: ${result.error.message}`,
    );
  }
  if (result.status !== 0) {
    throw new GitException(
      `git ${args.join(' ')} failed (${result.status}): ${result.stderr}`,
    );
  }
  return String(result.stdout ?? '')
    .split('\n')
    .map((l) => l.replace(/\s+$/, ''))
    .filter((l) => l.length > 0);
}

/** 读入标准输入行（pre-push ref 行）；逐行 trim 后丢弃空行。 */
export async function readStdinLines() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  // LineSplitter 语义：按 \r\n / \n / \r 切行。
  return Buffer.concat(chunks)
    .toString('utf8')
    .split(/\r\n|\n|\r/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0);
}

/** 本次 push 的 local SHA 集合（每行第 2 列），排序去重。 */
export function localShasOf(refLines) {
  const shas = new Set();
  for (const l of refLines) {
    const parts = l.split(/\s+/);
    const sha = parts.length >= 2 ? parts[1] : '';
    if (sha.length > 0) shas.add(sha);
  }
  return [...shas].sort();
}

/** 暂存文件列表（git diff --cached --name-only --diff-filter=ACMR）。 */
export function stagedFiles(repoRoot) {
  return gitLines(repoRoot, [
    'diff',
    '--cached',
    '--name-only',
    '--diff-filter=ACMR',
  ]);
}

/** HEAD SHA（无提交时返回 null）。 */
export function headSha(repoRoot) {
  try {
    const lines = gitLines(repoRoot, ['rev-parse', '--verify', 'HEAD']);
    return lines.length === 0 ? null : lines[0].trim();
  } catch (e) {
    if (e instanceof GitException) return null;
    throw e;
  }
}

/** 仓库实际 git 目录（worktree 下解析到对应 gitdir）。 */
export function gitDir(repoRoot) {
  const lines = gitLines(repoRoot, ['rev-parse', '--absolute-git-dir']);
  return lines.length === 0 ? `${repoRoot}/.git` : lines[0].trim();
}

/**
 * 判断 sha 是否为 headSha 的祖先（或等于）。
 * `git merge-base --is-ancestor`：exit 0=祖先；非 0（含 sha 不存在、
 * detached/无 HEAD、非 fast-forward 等）一律按「非祖先」返回 false，不 throw。
 */
export function isAncestor(repoRoot, sha, head) {
  try {
    const result = spawnSync('git', ['merge-base', '--is-ancestor', sha, head], {
      cwd: repoRoot,
    });
    return result.status === 0;
  } catch {
    return false;
  }
}

/** tracked 源码与 HEAD 不一致的路径（内容比较、忽略 CRLF，排除文档）。 */
export function dirtyTrackedSourceFiles(repoRoot) {
  const head = headSha(repoRoot);
  if (head == null) return [];
  try {
    const lines = gitLines(repoRoot, [
      'diff',
      '--ignore-cr-at-eol',
      '--name-only',
      'HEAD',
    ]);
    return lines
      .map(normalize)
      .filter((p) => !p.endsWith('.md'))
      .sort();
  } catch (e) {
    if (e instanceof GitException) return [];
    throw e;
  }
}

/** 未跟踪源码路径（排除文档；`git ls-files --others --exclude-standard`）。 */
export function untrackedSourceFiles(repoRoot) {
  try {
    const lines = gitLines(repoRoot, [
      'ls-files',
      '--others',
      '--exclude-standard',
    ]);
    return lines
      .map(normalize)
      .filter((p) => !p.endsWith('.md'))
      .sort();
  } catch (e) {
    if (e instanceof GitException) return [];
    throw e;
  }
}

export function normalize(path) {
  return path.replaceAll('\\', '/');
}
