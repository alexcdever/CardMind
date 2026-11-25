// markdown 引用 linter 的自测（Node.js 移植版）。
//
// 由 tool/lint/markdown_references_linter_test.dart 1:1 移植为 `node --test`：
//
//   node --test tool/lint/markdown_references_linter_test.mjs
//
// 守护的边界有两条：
//
// 1. **历史前缀只豁免已删除链路，不能整体关闭检查**——`spike/` 只豁免两个
//    未跟踪的旧探针，已提交的 `spike/nsh-editor-md-probe/` 照常判定；
// 2. **零依赖路径工具与 `package:path` 在这些用法上等价**——POSIX 与 Windows
//    形态都要正确，否则 Windows 上的门禁会误判/漏判。

import assert from 'node:assert/strict';
import test from 'node:test';

import {
  isBuildOutputPath,
  isDeletedHistoryPath,
  isLocalLogPath,
  isRepoRelativeToken,
  PathTools,
} from './markdown_references_linter.mjs';

test('已删除历史链路：命中前缀本身或位于其下 → 不判存在性', () => {
  const deletedTokens = [
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
  for (const token of deletedTokens) {
    assert.ok(isDeletedHistoryPath(token), `已删除历史链路: ${token}`);
  }
});

test('构建产物：生成目录同样不判存在性', () => {
  const buildTokens = [
    'nsh-app/target',
    'nsh-app/target/debug/build/x',
    'nsh-app/.nsh/types',
    'rust-backend/target/release/cardmind_backend.dll',
  ];
  for (const token of buildTokens) {
    assert.ok(isBuildOutputPath(token), `构建产物: ${token}`);
  }
});

test('名字相近的现存路径必须照常判定（否则检查等于被关闭）', () => {
  const stillJudged = [
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
  for (const token of stillJudged) {
    assert.ok(
      !isDeletedHistoryPath(token) && !isBuildOutputPath(token),
      `仍应判定: ${token}`,
    );
  }
});

test('本地日志（.log）不判存在性；非日志文件不受影响', () => {
  const logTokens = [
    'spike/nsh-editor-md-probe/logs/test-final2.log',
    'spike/nsh-editor-md-probe/logs/run-windows.log',
    'rust-backend/target/release/build.log',
  ];
  for (const token of logTokens) {
    assert.ok(isLocalLogPath(token), `本地日志: ${token}`);
  }
  for (const token of [
    'spike/nsh-editor-md-probe/logs/window-visual2.png',
    'spike/nsh-editor-md-probe/App.tsx',
    'docs/product.md',
  ]) {
    assert.ok(!isLocalLogPath(token), `非日志文件: ${token}`);
  }
});

test('零依赖路径工具：POSIX 形态', () => {
  assert.equal(PathTools.normalize('/a/b/../c'), '/a/c', 'normalize /a/b/../c');
  assert.equal(PathTools.normalize('a/./b//c'), 'a/b/c', 'normalize a/./b//c');
  assert.equal(PathTools.normalize(''), '.', 'normalize 空串');
  assert.equal(PathTools.normalize('../a'), '../a', 'normalize ../a');
  assert.equal(PathTools.normalize('/../a'), '/a', 'normalize /../a');
  assert.equal(PathTools.normalize('/'), '/', 'normalize /');
  assert.equal(
    PathTools.join('/repo', 'docs/product.md'),
    '/repo/docs/product.md',
    'join /repo + docs/product.md',
  );
  assert.equal(
    PathTools.join('/repo/docs', '../product.md'),
    '/repo/product.md',
    'join 折叠 ..',
  );
  assert.equal(
    PathTools.join('/repo', '/abs/x.md'),
    '/abs/x.md',
    'join 子路径为绝对路径',
  );
  assert.equal(
    PathTools.relative('/repo/docs/a.md', { from: '/repo' }),
    'docs/a.md',
    'relative 子路径',
  );
  assert.equal(
    PathTools.relative('/repo', { from: '/repo' }),
    '.',
    'relative 相同路径',
  );
  assert.equal(
    PathTools.relative('/repo/x', { from: '/repo/docs' }),
    '../x',
    'relative 向上退',
  );
  assert.equal(
    PathTools.relative('/other/x', { from: '/repo' }),
    '../other/x',
    'relative 同根跨目录',
  );
  assert.deepEqual(
    PathTools.split('/a/b'),
    ['/', 'a', 'b'],
    'split 绝对路径',
  );
  assert.deepEqual(PathTools.split('a/b'), ['a', 'b'], 'split 相对路径');
  assert.deepEqual(PathTools.split('a'), ['a'], 'split 单段');
  assert.ok(PathTools.split('').length === 0, 'split 空串');
});

test('零依赖路径工具：Windows 形态（分隔符、盘符、跨盘）', () => {
  assert.equal(
    PathTools.normalize('C:\\repo\\docs\\..\\a.md'),
    'C:/repo/a.md',
    'windows normalize C:\\repo\\docs\\..\\a.md',
  );
  assert.equal(
    PathTools.join('C:\\repo', 'docs\\a.md'),
    'C:/repo/docs/a.md',
    'windows join C:\\repo + docs\\a.md',
  );
  assert.equal(
    PathTools.join('C:\\repo', 'docs/a.md'),
    'C:/repo/docs/a.md',
    'windows join 混合分隔符',
  );
  assert.equal(
    PathTools.relative('C:\\repo\\docs\\a.md', { from: 'C:\\repo' }),
    'docs/a.md',
    'windows relative C:\\repo\\docs\\a.md from C:\\repo',
  );
  assert.equal(
    PathTools.relative('D:\\x', { from: 'C:\\repo' }),
    'D:/x',
    'windows relative 跨盘',
  );
  assert.deepEqual(
    PathTools.split('C:\\a\\b'),
    ['C:/', 'a', 'b'],
    'windows split C:\\a\\b',
  );
});

test('行内代码路径只判定仓库根相对路径：`..` 开头描述的是仓库之外', () => {
  const root = process.cwd();
  assert.ok(
    isRepoRelativeToken(root, 'docs/product.md'),
    '仓库相对路径 docs/product.md',
  );
  assert.ok(
    isRepoRelativeToken(root, 'rust-backend/src'),
    '仓库相对路径 rust-backend/src',
  );
  assert.ok(
    !isRepoRelativeToken(root, '../nsh/types'),
    '非仓库相对路径 ../nsh/types',
  );
  assert.ok(
    !isRepoRelativeToken(root, 'references/x.md'),
    '非仓库相对路径 references/x.md',
  );
});
