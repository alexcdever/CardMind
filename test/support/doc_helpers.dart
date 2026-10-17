import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 文档契约测试共享 helper：把「读仓库文件 + 查 git 元数据」的
/// 通用逻辑集中一处，供 docs_*_test.dart 复用。
///
/// 只读取仓库文件与 git 元数据，不触碰产品代码。
Directory get docRepoRoot => Directory.current;

String readRepoFile(String relativePath) =>
    File(relativePath).readAsStringSync();

/// 文件名（跨平台取最后一段路径）。
String docFileName(String filePath) =>
    filePath.replaceAll('\\', '/').split('/').last;

/// git 元数据查询（只读）。
ProcessResult runGit(List<String> args) =>
    Process.runSync('git', args, workingDirectory: docRepoRoot.path);

/// 目标文件当前是否有未提交改动（工作区 + 暂存区都算）。
///
/// 只对「本次要校验的那个文件」问 git，避免别处脏文件影响判定。
bool docHasUncommittedChange(String relativePath) {
  final status = runGit(['status', '--porcelain', '--', relativePath]);
  expect(
    status.exitCode,
    0,
    reason: 'git status --porcelain -- $relativePath 必须成功',
  );
  return (status.stdout as String).trim().isNotEmpty;
}

/// 当前日期（`YYYY-MM-DD`，本地时区），与文档里「上次更新」的写法一致。
String todayLocal() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

/// 文档「最近一次真实修改日期」的判定：
///
/// - 有未提交改动 → 改动就发生在**当前工作区**，声明日期必须是今天；
///   否则「改了文档不改日期」要等到提交后才由 `git log` 暴露，本地形同放行。
/// - 无未提交改动 → 退化为 `git log -1 --format=%cs`（最后一次提交日期）。
String expectedDocDate(String relativePath) {
  if (docHasUncommittedChange(relativePath)) {
    return todayLocal();
  }
  return (runGit(['log', '-1', '--format=%cs', '--', relativePath]).stdout
          as String)
      .trim();
}

/// 定位编号 0008 的新 ADR（`docs/adr/0008-*.md`，必须恰有一份）。
String adr0008Path() {
  final matches =
      Directory('docs/adr')
          .listSync()
          .whereType<File>()
          .map((file) => file.path)
          .where((path) => docFileName(path).startsWith('0008-'))
          .where((path) => path.endsWith('.md'))
          .toList()
        ..sort();
  expect(matches, hasLength(1), reason: 'docs/adr/ 下必须恰有一份编号 0008 的 ADR');
  return matches.single;
}

/// 取 markdown 中某个二级小节（`## 标题` 起，到下一个二级标题前）的正文。
String sectionOf(String document, String heading) {
  final start = document.indexOf(heading);
  expect(start, greaterThan(-1), reason: '文档必须保留小节 $heading');
  final rest = document.substring(start + heading.length);
  final end = rest.indexOf('\n## ');
  return end == -1 ? rest : rest.substring(0, end);
}
