/// pre-push 完整 suite 的 HEAD 缓存。
///
/// 缓存写入 `.git` 内（worktree 场景解析到实际 gitdir），不写工作树、不提交。
/// 缓存只跳过完整 suite；format-first 与工作树一致性检查始终执行。
library;

import 'dart:convert';
import 'dart:io';

import 'git.dart';

/// 缓存命中判断输入。
class CacheCheckInput {
  const CacheCheckInput({
    required this.headSha,
    required this.fingerprint,
    required this.localShas,
    required this.worktreeClean,
  });

  final String headSha;
  final String fingerprint;
  final List<String> localShas;
  final bool worktreeClean;
}

class CacheCheckResult {
  const CacheCheckResult({required this.hit, required this.reason});

  final bool hit;
  final String reason;
}

/// `.git/cardmind_gate_cache.json`。
class GateCache {
  GateCache({required this.file});

  final File file;

  /// 目录不存在（如未初始化 git）时用仓库根下的 `.git`。
  static GateCache forRepo(String repoRoot) {
    return GateCache(file: File('$repoRoot/.git/cardmind_gate_cache.json'));
  }

  /// 使用 gitdir（worktree 安全）构造。
  static Future<GateCache> forGitDir(String repoRoot) async {
    final dir = await gitDir(repoRoot);
    return GateCache(file: File('$dir/cardmind_gate_cache.json'));
  }

  /// 同步粗筛：worktree + HEAD + fingerprint 相等即认为「可能命中」。
  /// 不含 localSha 判断——祖先判断需要跑 git，见 [checkAsync]。
  /// 保留同步版本供无须 git 的调用方/测试做粗筛。
  CacheCheckResult check({required CacheCheckInput input}) {
    if (!input.worktreeClean) {
      return const CacheCheckResult(hit: false, reason: 'worktree 不一致');
    }
    if (!file.existsSync()) {
      return const CacheCheckResult(hit: false, reason: '无缓存记录');
    }
    final record = _read();
    if (record == null) {
      return const CacheCheckResult(hit: false, reason: '缓存损坏');
    }
    if (record.headSha != input.headSha) {
      return CacheCheckResult(
        hit: false,
        reason: 'HEAD 不同（缓存 ${record.headSha}，当前 ${input.headSha}）',
      );
    }
    if (record.fingerprint != input.fingerprint) {
      return const CacheCheckResult(hit: false, reason: 'gate fingerprint 不同');
    }
    return const CacheCheckResult(
      hit: true,
      reason: 'exact HEAD + fingerprint 命中',
    );
  }

  /// 祖先包含命中语义：HEAD+fingerprint 相等的前提下，要求当前要推的
  /// 每个 localSha 都是已验证 headSha 的祖先（或等于它）。
  ///
  /// `full`/`pre-push` 已验证「HEAD 这套代码过了整套」，一次正常 push 推的
  /// 提交都在 HEAD 历史上 → 命中安全。若某个 localSha 不在祖先链上（推了
  /// 别的分支 / 强推重写后的孤立提交），其代码状态未被本次验证覆盖 →
  /// 不命中，照常跑全套。这是安全边界。
  Future<CacheCheckResult> checkAsync({
    required String repoRoot,
    required CacheCheckInput input,
  }) async {
    final coarse = check(input: input);
    if (!coarse.hit) {
      return coarse;
    }
    for (final sha in input.localShas) {
      if (!await isAncestor(repoRoot, sha, input.headSha)) {
        return CacheCheckResult(
          hit: false,
          reason: 'push local SHA 含非祖先提交（$sha）',
        );
      }
    }
    return const CacheCheckResult(
      hit: true,
      reason: 'exact HEAD + fingerprint + 祖先 localShas 命中',
    );
  }

  Future<void> write({required CacheCheckInput input}) async {
    final record = CacheRecord(
      headSha: input.headSha,
      fingerprint: input.fingerprint,
      localShas: List<String>.of(input.localShas)..sort(),
    );
    try {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(record.toJson()),
      );
    } on FileSystemException catch (e) {
      throw GitException('无法写入门禁缓存 ${file.path}: ${e.message}');
    }
  }

  CacheRecord? _read() {
    try {
      final json = jsonDecode(file.readAsStringSync());
      return CacheRecord.fromJson(json as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }
}

class CacheRecord {
  CacheRecord({
    required this.headSha,
    required this.fingerprint,
    required this.localShas,
  });

  final String headSha;
  final String fingerprint;
  final List<String> localShas;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'headSha': headSha,
    'fingerprint': fingerprint,
    'localShas': localShas,
    'result': 'pass',
  };

  factory CacheRecord.fromJson(Map<String, dynamic> json) => CacheRecord(
    headSha: json['headSha'] as String? ?? '',
    fingerprint: json['fingerprint'] as String? ?? '',
    localShas: (json['localShas'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => e.toString())
        .toList(),
  );
}

/// gate 版本 fingerprint：对门禁源码文件内容做 FNV-1a 哈希。
String computeGateFingerprint(String repoRoot) {
  final files = <String>[
    'tool/git_gate.dart',
    'tool/src/git_gate/command.dart',
    'tool/src/git_gate/selector.dart',
    'tool/src/git_gate/runner.dart',
    'tool/src/git_gate/formatter.dart',
    'tool/src/git_gate/git.dart',
    'tool/src/git_gate/cache.dart',
    'tool/src/git_gate/host_build.dart',
    'tool/src/git_gate/gate.dart',
    '.githooks/pre-commit',
    '.githooks/pre-push',
  ]..sort();
  var hash = 0xcbf29ce484222325;
  for (final f in files) {
    final file = File('$repoRoot/${f.replaceAll(r'\', '/')}');
    if (!file.existsSync()) continue;
    final content = file.readAsStringSync().replaceAll('\r\n', '\n');
    hash ^= _fnv(hash, f);
    for (final unit in content.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
  }
  return hash.toRadixString(16);
}

int _fnv(int hash, String s) {
  for (final unit in s.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash;
}
