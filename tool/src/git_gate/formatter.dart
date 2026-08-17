/// format-first：先格式化全部源码，再比较内容快照（CRLF 归一化）。
///
/// 关键点：
/// - formatter 必须真的写入文件（不 `--check`）；
/// - 快照覆盖 tracked/untracked 文件；
/// - 内容比较做 CRLF→LF 归一化，避免 Windows autocrlf 环境把
///   纯换行差异误判为“formatter 改变了文件”；
/// - 不自动 `git add`，不修改 index。
library;

import 'dart:io';

import 'runner.dart';

/// 格式化结果。
class FormatOutcome {
  const FormatOutcome({
    required this.changedPaths,
    this.error,
    this.commandsRun = const <String>[],
  });

  /// formatter 实际改变的文件（POSIX 相对路径，排序）。
  final List<String> changedPaths;

  /// formatter 命令失败信息；null 表示命令成功。
  final String? error;

  /// 实际执行的命令描述（用于测试与日志）。
  final List<String> commandsRun;
}

/// 内容归一化哈希（FNV-1a 64；CRLF→LF 后计算）。
String normalizedContentHash(String content) {
  final normalized = content.replaceAll('\r\n', '\n');
  var hash = 0xcbf29ce484222325;
  for (final unit in normalized.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash.toRadixString(16);
}

/// 收集目录下所有匹配后缀的文件（递归，排除 target/.git/build 等）。
Map<String, String> snapshotSources(
  String repoRoot,
  List<String> dirs,
  String suffix,
) {
  final result = <String, String>{};
  final excluded = <String>{
    'target',
    '.git',
    'build',
    '.dart_tool',
    '.worktrees',
  };
  for (final dir in dirs) {
    final abs = '$repoRoot/${dir.replaceAll(r'\', '/')}';
    final root = Directory(abs);
    if (!root.existsSync()) continue;
    void walk(Directory d) {
      for (final entity in d.listSync(followLinks: false)) {
        if (entity is Directory) {
          if (excluded.contains(
            entity.path.split(Platform.pathSeparator).last,
          )) {
            continue;
          }
          walk(entity);
        } else if (entity is File && entity.path.endsWith(suffix)) {
          final relative = _relativePosix(repoRoot, entity.path);
          result[relative] = normalizedContentHash(entity.readAsStringSync());
        }
      }
    }

    walk(root);
  }
  return result;
}

/// 生成文件快照（FRB codegen 产物：Dart 绑定 + Rust 生成文件）。
Map<String, String> snapshotGeneratedFiles(String repoRoot) {
  final result = <String, String>{};
  final dartDir = Directory('$repoRoot/lib/src/rust');
  if (dartDir.existsSync()) {
    for (final f in dartDir.listSync().whereType<File>()) {
      if (f.path.endsWith('.dart')) {
        result[_relativePosix(repoRoot, f.path)] = normalizedContentHash(
          f.readAsStringSync(),
        );
      }
    }
  }
  final frbGenerated = File('$repoRoot/rust-backend/src/frb_generated.rs');
  if (frbGenerated.existsSync()) {
    result['rust-backend/src/frb_generated.rs'] = normalizedContentHash(
      frbGenerated.readAsStringSync(),
    );
  }
  return result;
}

String _relativePosix(String repoRoot, String path) {
  final abs = path.replaceAll(r'\', '/');
  final root = repoRoot.replaceAll(r'\', '/');
  if (abs.startsWith(root)) {
    var rel = abs.substring(root.length);
    if (rel.startsWith('/')) rel = rel.substring(1);
    return rel;
  }
  return abs;
}

/// formatter：执行命令 → 快照对比。
class Formatter {
  Formatter({
    required this.repoRoot,
    required this.runner,
    required this.timeout,
  });

  final String repoRoot;
  final Runner runner;
  final Duration timeout;

  static const dartDirs = <String>['lib', 'test', 'integration_test', 'tool'];

  Future<FormatOutcome> formatDart() async {
    final existing = dartDirs
        .where((d) => Directory('$repoRoot/$d').existsSync())
        .toList();
    if (existing.isEmpty) {
      return const FormatOutcome(changedPaths: <String>[]);
    }
    final before = snapshotSources(repoRoot, existing, '.dart');
    final args = <String>['format', ...existing];
    final result = await runner('dart', args, workingDirectory: repoRoot);
    if (result.exitCode != 0) {
      return FormatOutcome(
        changedPaths: const <String>[],
        error: 'dart format failed (exit ${result.exitCode}): ${result.stderr}',
        commandsRun: <String>['dart ${args.join(' ')}'],
      );
    }
    final after = snapshotSources(repoRoot, existing, '.dart');
    return FormatOutcome(
      changedPaths: _changed(before, after),
      commandsRun: <String>['dart ${args.join(' ')}'],
    );
  }

  Future<FormatOutcome> formatRust() async {
    if (!Directory('$repoRoot/rust-backend').existsSync()) {
      return const FormatOutcome(changedPaths: <String>[]);
    }
    final before = snapshotSources(repoRoot, <String>['rust-backend'], '.rs');
    final result = await runner('cargo', <String>[
      'fmt',
      '--all',
    ], workingDirectory: '$repoRoot/rust-backend');
    if (result.exitCode != 0) {
      return FormatOutcome(
        changedPaths: const <String>[],
        error: 'cargo fmt failed (exit ${result.exitCode}): ${result.stderr}',
        commandsRun: const <String>['cargo fmt --all (in rust-backend)'],
      );
    }
    final after = snapshotSources(repoRoot, <String>['rust-backend'], '.rs');
    return FormatOutcome(
      changedPaths: _changed(before, after),
      commandsRun: const <String>['cargo fmt --all (in rust-backend)'],
    );
  }

  Future<FormatOutcome> formatAll() async {
    final dart = await formatDart();
    final rust = await formatRust();
    final changed = <String>{
      ...dart.changedPaths,
      ...rust.changedPaths,
    }.toList()..sort();
    final error = dart.error ?? rust.error;
    return FormatOutcome(
      changedPaths: changed,
      error: error,
      commandsRun: <String>[...dart.commandsRun, ...rust.commandsRun],
    );
  }
}

List<String> _changed(Map<String, String> before, Map<String, String> after) {
  final changed = <String>{};
  for (final entry in before.entries) {
    if (after[entry.key] != entry.value) {
      changed.add(entry.key);
    }
  }
  for (final key in after.keys) {
    if (!before.containsKey(key)) {
      changed.add(key);
    }
  }
  return changed.toList()..sort();
}
