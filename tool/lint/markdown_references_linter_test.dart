/// markdown 引用 linter 的自测。
///
/// 守护的边界只有一条：**历史前缀只豁免已删除链路，不能整体关闭检查**。
/// 仓库从 4.6 起没有 `pubspec.yaml`（Dart 只服务 `tool/`），拿不到
/// `package:test`，因此用普通断言 + 退出码表达结果：
///
///   dart tool/lint/markdown_references_linter_test.dart
///
/// exit 0 = 全部通过；exit 1 = 有断言失败（并打印失败项）。
library;

import 'dart:io';

import 'markdown_references_linter.dart';

int _failures = 0;

void main() {
  // 已删除历史链路：命中前缀本身或位于其下 → 不判存在性。
  const deletedTokens = <String>[
    'spike/nsh-probe',
    'spike/nsh-rich-editor-probe/logs/app-main-build.log',
    'lib/main.dart',
    'test/widget_test.dart',
    'integration_test/support/test_harness.dart',
    'docs/dev/rich-editor.md',
    'android/app/build.gradle',
    'macos/Runner/Release.entitlements',
    'linux/x64/release/bundle/lib/libcardmind_backend.so',
    'windows/x64/runner/Release/cardmind_backend.dll',
    'nsh-app/web',
    'nsh-app/web/src/index.ts',
    'nsh-app/editor_page_test.ts',
    'nsh-app/editor_test_entry.tsx',
    'nsh-app/editor_test_repo.ts',
    'tool/boundary_scanner',
    'nsh-app/out/bundle.nshc',
    'nsh-app/.nsh/out/cardmind/nsh/capabilities.json',
    '.git/shallow',
    '.git/info/exclude',
    '.workflow-archive-2026-09-30/README.md',
  ];
  for (final token in deletedTokens) {
    _expect('已删除历史链路: $token', isDeletedHistoryPath(token));
  }

  // 构建产物：生成目录同样不判存在性。
  const buildTokens = <String>[
    'nsh-app/target',
    'nsh-app/target/debug/build/x',
    'nsh-app/.nsh/types',
    'rust-backend/target/release/cardmind_backend.dll',
  ];
  for (final token in buildTokens) {
    _expect('构建产物: $token', isBuildOutputPath(token));
  }

  // 关键反例：名字相近的**现存**路径必须照常判定（否则检查等于被关闭）。
  const stillJudged = <String>[
    'docs/standards/__nope__.md',
    'docs/product.md',
    'docs/devtools/a.md',
    'libx/a.dart',
    'spike2/a.md',
    'nsh-app/webx/a.ts',
    'nsh-app/editor_page_test.ts.bak',
    'rust-backend/tool/boundary_scanner',
    'rust-backend/src/store.rs',
  ];
  for (final token in stillJudged) {
    _expect(
      '仍应判定: $token',
      !isDeletedHistoryPath(token) && !isBuildOutputPath(token),
    );
  }

  // 行内代码路径只判定仓库根相对路径：`..` 开头描述的是仓库之外。
  final root = Directory.current;
  _expect(
    '仓库相对路径 docs/product.md',
    isRepoRelativeToken(root, 'docs/product.md'),
  );
  _expect(
    '仓库相对路径 rust-backend/src',
    isRepoRelativeToken(root, 'rust-backend/src'),
  );
  _expect('非仓库相对路径 ../nsh/types', !isRepoRelativeToken(root, '../nsh/types'));
  _expect(
    '非仓库相对路径 references/x.md',
    !isRepoRelativeToken(root, 'references/x.md'),
  );

  if (_failures == 0) {
    stdout.writeln('markdown_references_linter self-test: all passed');
    exitCode = 0;
    return;
  }
  stderr.writeln('markdown_references_linter self-test: $_failures failure(s)');
  exitCode = 1;
}

void _expect(String name, bool condition) {
  if (condition) return;
  _failures++;
  stderr.writeln('FAIL: $name');
}
