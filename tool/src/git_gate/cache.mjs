// pre-push 完整 suite 的 HEAD 缓存。
//
// 缓存写入 `.git` 内（worktree 场景解析到实际 gitdir），不写工作树、不提交。
// 缓存只跳过完整 suite；format-first 与工作树一致性检查始终执行。
//
// 本文件由 tool/src/git_gate/cache.dart 移植为 Node.js ESM（1:1 语义等价）。
// 文件格式与键名保持不变（headSha / fingerprint / localShas / result），
// 便于人工查看与后续工具读取。

import fs from 'node:fs';
import path from 'node:path';

import { GitException, gitDir, isAncestor } from './git.mjs';

/** 缓存命中判断输入。 */
export class CacheCheckInput {
  constructor({ headSha, fingerprint, localShas, worktreeClean }) {
    this.headSha = headSha;
    this.fingerprint = fingerprint;
    this.localShas = localShas;
    this.worktreeClean = worktreeClean;
  }
}

export class CacheCheckResult {
  constructor({ hit, reason }) {
    this.hit = hit;
    this.reason = reason;
  }
}

/** `.git/cardmind_gate_cache.json`。 */
export class GateCache {
  constructor({ file }) {
    this.file = file;
  }

  /** 目录不存在（如未初始化 git）时用仓库根下的 `.git`。 */
  static forRepo(repoRoot) {
    return new GateCache({
      file: path.join(repoRoot, '.git', 'cardmind_gate_cache.json'),
    });
  }

  /** 使用 gitdir（worktree 安全）构造。 */
  static forGitDir(repoRoot) {
    const dir = gitDir(repoRoot);
    return new GateCache({ file: path.join(dir, 'cardmind_gate_cache.json') });
  }

  /**
   * 同步粗筛：worktree + HEAD + fingerprint 相等即认为「可能命中」。
   * 不含 localSha 判断——祖先判断需要跑 git，见 checkAsync。
   * 保留同步版本供无须 git 的调用方/测试做粗筛。
   */
  check({ input }) {
    if (!input.worktreeClean) {
      return new CacheCheckResult({ hit: false, reason: 'worktree 不一致' });
    }
    if (!fs.existsSync(this.file)) {
      return new CacheCheckResult({ hit: false, reason: '无缓存记录' });
    }
    const record = this.#read();
    if (record == null) {
      return new CacheCheckResult({ hit: false, reason: '缓存损坏' });
    }
    if (record.headSha !== input.headSha) {
      return new CacheCheckResult({
        hit: false,
        reason: `HEAD 不同（缓存 ${record.headSha}，当前 ${input.headSha}）`,
      });
    }
    if (record.fingerprint !== input.fingerprint) {
      return new CacheCheckResult({
        hit: false,
        reason: 'gate fingerprint 不同',
      });
    }
    return new CacheCheckResult({
      hit: true,
      reason: 'exact HEAD + fingerprint 命中',
    });
  }

  /**
   * 祖先包含命中语义：HEAD+fingerprint 相等的前提下，要求当前要推的
   * 每个 localSha 都是已验证 headSha 的祖先（或等于它）。
   *
   * `full`/`pre-push` 已验证「HEAD 这套代码过了整套」，一次正常 push 推的
   * 提交都在 HEAD 历史上 → 命中安全。若某个 localSha 不在祖先链上（推了
   * 别的分支 / 强推重写后的孤立提交），其代码状态未被本次验证覆盖 →
   * 不命中，照常跑全套。这是安全边界。
   */
  async checkAsync({ repoRoot, input }) {
    const coarse = this.check({ input });
    if (!coarse.hit) {
      return coarse;
    }
    for (const sha of input.localShas) {
      if (!isAncestor(repoRoot, sha, input.headSha)) {
        return new CacheCheckResult({
          hit: false,
          reason: `push local SHA 含非祖先提交（${sha}）`,
        });
      }
    }
    return new CacheCheckResult({
      hit: true,
      reason: 'exact HEAD + fingerprint + 祖先 localShas 命中',
    });
  }

  write({ input }) {
    const record = {
      headSha: input.headSha,
      fingerprint: input.fingerprint,
      localShas: [...input.localShas].sort(),
      result: 'pass',
    };
    try {
      fs.mkdirSync(path.dirname(this.file), { recursive: true });
      fs.writeFileSync(this.file, JSON.stringify(record, null, 2));
    } catch (e) {
      throw new GitException(
        `无法写入门禁缓存 ${this.file}: ${e?.message ?? e}`,
      );
    }
  }

  #read() {
    try {
      const json = JSON.parse(fs.readFileSync(this.file, 'utf8'));
      return CacheRecord.fromJson(json);
    } catch {
      return null;
    }
  }
}

export class CacheRecord {
  constructor({ headSha, fingerprint, localShas }) {
    this.headSha = headSha;
    this.fingerprint = fingerprint;
    this.localShas = localShas;
  }

  toJson() {
    return {
      headSha: this.headSha,
      fingerprint: this.fingerprint,
      localShas: this.localShas,
      result: 'pass',
    };
  }

  static fromJson(json) {
    if (json == null || typeof json !== 'object' || Array.isArray(json)) {
      throw new TypeError('cache record must be a JSON object');
    }
    const localShas = Array.isArray(json.localShas) ? json.localShas : [];
    return new CacheRecord({
      headSha: typeof json.headSha === 'string' ? json.headSha : '',
      fingerprint: typeof json.fingerprint === 'string' ? json.fingerprint : '',
      localShas: localShas.map((e) => String(e)),
    });
  }
}

/** 64 位掩码与 FNV-1a 质数（原 Dart 实现同为 64 位环上的折叠）。 */
const kFnvMask = 0xffffffffffffffffn;
const kFnvPrime = 0x100000001b3n;
const kFnvOffsetBasis = 0xcbf29ce484222325n;

/** 把字符串的 UTF-16 code units 折进 FNV-1a 哈希（对齐 Dart codeUnits）。 */
function fnvUnits(hash, s) {
  let h = hash;
  for (let i = 0; i < s.length; i++) {
    h ^= BigInt(s.charCodeAt(i));
    h = (h * kFnvPrime) & kFnvMask;
  }
  return h;
}

/**
 * gate 版本 fingerprint：对门禁源码文件内容做 FNV-1a 哈希。
 *
 * 文件清单与 Dart 版同构（入口 + 7 个模块 + 两个 hook），后缀改为 .mjs。
 * 清单变化本身就会让旧 Dart 缓存失效——这正是移植后第一次 pre-push 应有的行为。
 */
export function computeGateFingerprint(repoRoot) {
  const files = [
    'tool/git_gate.mjs',
    'tool/src/git_gate/command.mjs',
    'tool/src/git_gate/selector.mjs',
    'tool/src/git_gate/runner.mjs',
    'tool/src/git_gate/formatter.mjs',
    'tool/src/git_gate/git.mjs',
    'tool/src/git_gate/cache.mjs',
    'tool/src/git_gate/gate.mjs',
    '.githooks/pre-commit',
    '.githooks/pre-push',
  ].sort();
  let hash = kFnvOffsetBasis;
  for (const f of files) {
    const file = path.join(repoRoot, ...f.replaceAll('\\', '/').split('/'));
    if (!fs.existsSync(file)) continue;
    const content = fs.readFileSync(file, 'utf8').replaceAll('\r\n', '\n');
    // 与 Dart 一致：先把「当前 hash + 文件路径」折一遍，再折文件内容。
    hash = hash ^ fnvUnits(hash, f);
    hash = fnvUnits(hash, content);
  }
  return hash.toString(16);
}
