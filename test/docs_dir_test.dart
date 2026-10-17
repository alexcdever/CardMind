import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/doc_helpers.dart';

void main() {
  test('docs/ 根目录不再保留任何一次性任务单', () {
    final tracked = runGit(['ls-files', 'docs/task-*.md']);
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
            .map((file) => docFileName(file.path))
            .where((name) => name.startsWith('task-') && name.endsWith('.md'))
            .toList()
          ..sort();
    expect(leftovers, isEmpty, reason: 'docs/ 根目录不得残留未跟踪的 task-*.md');
  });
}
