/// Git 仓库辅助（只读查询，供门禁使用）。
library;

import 'dart:convert';
import 'dart:io';

/// 对仓库根目录执行 git 命令，返回 stdout 行列表。
Future<List<String>> gitLines(
  String repoRoot,
  List<String> args, {
  String? input,
}) async {
  final result = await Process.run(
    'git',
    args,
    workingDirectory: repoRoot,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (result.exitCode != 0) {
    throw GitException(
      'git ${args.join(' ')} failed (${result.exitCode}): ${result.stderr}',
    );
  }
  final out = result.stdout.toString();
  return out
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) => l.isNotEmpty)
      .toList();
}

class GitException implements Exception {
  GitException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 读入标准输入行（pre-push ref 行）。
Future<List<String>> readStdinLines() async {
  final lines = <String>[];
  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) lines.add(trimmed);
  }
  return lines;
}

/// 本次 push 的 local SHA 集合（每行第 2 列），排序去重。
List<String> localShasOf(List<String> refLines) {
  final shas =
      refLines
          .map(
            (l) => l.split(RegExp(r'\s+')).length >= 2
                ? l.split(RegExp(r'\s+'))[1]
                : '',
          )
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return shas;
}

/// 暂存文件列表（git diff --cached --name-only --diff-filter=ACMR）。
Future<List<String>> stagedFiles(String repoRoot) => gitLines(
  repoRoot,
  <String>['diff', '--cached', '--name-only', '--diff-filter=ACMR'],
);

/// HEAD SHA（无提交时返回 null）。
Future<String?> headSha(String repoRoot) async {
  try {
    final lines = await gitLines(repoRoot, <String>[
      'rev-parse',
      '--verify',
      'HEAD',
    ]);
    return lines.isEmpty ? null : lines.first.trim();
  } on GitException {
    return null;
  }
}

/// 仓库实际 git 目录（worktree 下解析到对应 gitdir）。
Future<String> gitDir(String repoRoot) async {
  final lines = await gitLines(repoRoot, <String>[
    'rev-parse',
    '--absolute-git-dir',
  ]);
  return lines.isEmpty ? '$repoRoot/.git' : lines.first.trim();
}

/// tracked 源码与 HEAD 不一致的路径（内容比较、忽略 CRLF，排除文档）。
Future<List<String>> dirtyTrackedSourceFiles(String repoRoot) async {
  final head = await headSha(repoRoot);
  if (head == null) return const <String>[];
  try {
    final lines = await gitLines(repoRoot, <String>[
      'diff',
      '--ignore-cr-at-eol',
      '--name-only',
      'HEAD',
    ]);
    return lines.map(normalize).where((p) => !p.endsWith('.md')).toList()
      ..sort();
  } on GitException {
    return const <String>[];
  }
}

/// 未跟踪源码路径（排除文档；`git ls-files --others --exclude-standard`）。
Future<List<String>> untrackedSourceFiles(String repoRoot) async {
  try {
    final lines = await gitLines(repoRoot, <String>[
      'ls-files',
      '--others',
      '--exclude-standard',
    ]);
    return lines.map(normalize).where((p) => !p.endsWith('.md')).toList()
      ..sort();
  } on GitException {
    return const <String>[];
  }
}

String normalize(String path) => path.replaceAll(r'\', '/');
