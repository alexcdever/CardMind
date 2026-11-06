/// markdown 引用 linter 的自测。
///
/// 守护的边界有两条：
///
/// 1. **历史前缀只豁免已删除链路，不能整体关闭检查**——`spike/` 只豁免两个
///    未跟踪的旧探针，已提交的 `spike/nsh-editor-md-probe/` 照常判定；
/// 2. **零依赖路径工具与 `package:path` 在这些用法上等价**——POSIX 与 Windows
///    形态都要正确，否则 Windows 上的门禁会误判/漏判。
///
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
    'spike/nsh-probe/tools/v4b_webview_perf.py',
    'spike/nsh-rich-editor-probe/logs/app-main-build.log',
    'spike/nsh-rich-editor-probe/probe-030/App.tsx',
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
    // P1 死代码清理：FRB 生成物与导出层已删，历史文档仍引用。
    'rust-backend/src/frb_generated.rs',
    'rust-backend/src/api.rs',
    'nsh-app/src/main.rs',
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
    // `spike/` 只豁免两个未跟踪的旧探针；已提交的 P2 探针照常判定。
    'spike/nsh-editor-md-probe/App.tsx',
    'spike/nsh-editor-md-probe/logs/window-visual2.png',
    'spike/nsh-editor-md-probe/logs/__nope__.png',
    'spike/nsh-editor-md-probe/__nope__.md',
    'spike/nsh-editor-md-probe',
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

  // 日志（`.log`）是本地运行产物：根 `.gitignore` 的 `*.log` 保证 fresh
  // checkout 里没有它们，因此不判存在性；非日志文件不受影响。
  const logTokens = <String>[
    'spike/nsh-editor-md-probe/logs/test-final2.log',
    'spike/nsh-editor-md-probe/logs/run-windows.log',
    'rust-backend/target/release/build.log',
  ];
  for (final token in logTokens) {
    _expect('本地日志: $token', isLocalLogPath(token));
  }
  for (final token in <String>[
    'spike/nsh-editor-md-probe/logs/window-visual2.png',
    'spike/nsh-editor-md-probe/App.tsx',
    'docs/product.md',
  ]) {
    _expect('非日志文件: $token', !isLocalLogPath(token));
  }

  // 零依赖路径工具：POSIX 形态。
  _expect('normalize /a/b/../c', PathTools.normalize('/a/b/../c') == '/a/c');
  _expect('normalize a/./b//c', PathTools.normalize('a/./b//c') == 'a/b/c');
  _expect('normalize 空串', PathTools.normalize('') == '.');
  _expect('normalize ../a', PathTools.normalize('../a') == '../a');
  _expect('normalize /../a', PathTools.normalize('/../a') == '/a');
  _expect('normalize /', PathTools.normalize('/') == '/');
  _expect(
    'join /repo + docs/product.md',
    PathTools.join('/repo', 'docs/product.md') == '/repo/docs/product.md',
  );
  _expect(
    'join 折叠 ..',
    PathTools.join('/repo/docs', '../product.md') == '/repo/product.md',
  );
  _expect('join 子路径为绝对路径', PathTools.join('/repo', '/abs/x.md') == '/abs/x.md');
  _expect(
    'relative 子路径',
    PathTools.relative('/repo/docs/a.md', from: '/repo') == 'docs/a.md',
  );
  _expect('relative 相同路径', PathTools.relative('/repo', from: '/repo') == '.');
  _expect(
    'relative 向上退',
    PathTools.relative('/repo/x', from: '/repo/docs') == '../x',
  );
  _expect(
    'relative 同根跨目录',
    PathTools.relative('/other/x', from: '/repo') == '../other/x',
  );
  _expect(
    'split 绝对路径',
    _sameList(PathTools.split('/a/b'), <String>['/', 'a', 'b']),
  );
  _expect('split 相对路径', _sameList(PathTools.split('a/b'), <String>['a', 'b']));
  _expect('split 单段', _sameList(PathTools.split('a'), <String>['a']));
  _expect('split 空串', PathTools.split('').isEmpty);

  // 零依赖路径工具：Windows 形态（分隔符、盘符、跨盘）。
  _expect(
    r'windows normalize C:\repo\docs\..\a.md',
    PathTools.normalize(r'C:\repo\docs\..\a.md') == 'C:/repo/a.md',
  );
  _expect(
    r'windows join C:\repo + docs\a.md',
    PathTools.join(r'C:\repo', r'docs\a.md') == 'C:/repo/docs/a.md',
  );
  _expect(
    r'windows join 混合分隔符',
    PathTools.join(r'C:\repo', 'docs/a.md') == 'C:/repo/docs/a.md',
  );
  _expect(
    r'windows relative C:\repo\docs\a.md from C:\repo',
    PathTools.relative(r'C:\repo\docs\a.md', from: r'C:\repo') == 'docs/a.md',
  );
  _expect(
    r'windows relative 跨盘',
    PathTools.relative(r'D:\x', from: r'C:\repo') == 'D:/x',
  );
  _expect(
    r'windows split C:\a\b',
    _sameList(PathTools.split(r'C:\a\b'), <String>['C:/', 'a', 'b']),
  );

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

bool _sameList(List<String> actual, List<String> expected) {
  if (actual.length != expected.length) return false;
  for (var index = 0; index < actual.length; index++) {
    if (actual[index] != expected[index]) return false;
  }
  return true;
}
