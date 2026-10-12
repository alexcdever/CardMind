import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 文档验收测试：把本次「docs 收尾」任务的验收标准固定成可执行的检查。
///
/// 只读取仓库文件与 git 元数据，不触碰产品代码；每个 test 对应一条验收标准
/// （标准编号写进测试名，便于逐条自检）。
Directory get _repoRoot => Directory.current;

/// 文件名（跨平台取最后一段路径）。
String _fileName(String filePath) =>
    filePath.replaceAll('\\', '/').split('/').last;

/// git 元数据查询（只读）。
ProcessResult _git(List<String> args) =>
    Process.runSync('git', args, workingDirectory: _repoRoot.path);

void main() {
  test('验收 3：docs/ 根目录不再保留任何一次性任务单', () {
    final tracked = _git(['ls-files', 'docs/task-*.md']);
    expect(tracked.exitCode, 0, reason: 'git ls-files 必须成功');
    expect(
      (tracked.stdout as String).trim(),
      isEmpty,
      reason: 'git ls-files docs/task-*.md 必须输出为空（一次性任务单已从版本控制移除）',
    );

    final leftovers =
        Directory('docs')
            .listSync()
            .whereType<File>()
            .map((file) => _fileName(file.path))
            .where((name) => name.startsWith('task-') && name.endsWith('.md'))
            .toList()
          ..sort();
    expect(leftovers, isEmpty, reason: 'docs/ 根目录不得残留未跟踪的 task-*.md');
  });
}
