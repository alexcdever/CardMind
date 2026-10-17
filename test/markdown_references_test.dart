import 'package:flutter_test/flutter_test.dart';

import '../tool/lint/markdown_references_linter.dart';
import 'support/doc_helpers.dart';

void main() {
  test(
    // 直接调用 tool 里的检查实现（`dart run` 在 flutter test 子进程里找不到 dart 可执行文件）。
    'markdown 引用检查通过（tool/lint/markdown_references_linter.dart）',
    () async {
      final messages = <String>[];
      final exit = await runMarkdownReferencesLint(
        projectRoot: docRepoRoot,
        log: messages.add,
      );
      expect(exit, 0, reason: '仓库自有文档不得引用不存在的对象：\n${messages.join('\n')}');
      expect(
        messages,
        contains('All references are valid!'),
        reason: '检查器通过时会打印 All references are valid!：\n${messages.join('\n')}',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
