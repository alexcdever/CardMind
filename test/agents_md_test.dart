import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/doc_helpers.dart';

void main() {
  test('AGENTS.md 的工程事实（tool/ 概览、Rust PATH、布局用词）与仓库现状一致', () {
    final agents = readRepoFile('AGENTS.md');

    // 1) tool/ 概览行：点名的脚本 / 目录必须真实存在，且不再把 gate、scanner 当目录名。
    final toolLines = agents
        .split('\n')
        .where((line) => line.startsWith('tool/'))
        .toList();
    expect(toolLines, hasLength(1), reason: '项目结构里应恰有一行 tool/ 概览');
    final toolLine = toolLines.single;

    for (final script in <String>[
      'git_gate.dart',
      'test_boundary_scanner.dart',
    ]) {
      expect(toolLine, contains(script), reason: 'tool/ 概览行必须点名 $script');
      expect(
        File('tool/$script').existsSync(),
        isTrue,
        reason: 'tool/ 概览行点名的 tool/$script 必须真实存在',
      );
    }
    for (final entry in <String>['build', 'quality', 'lint']) {
      expect(toolLine, contains(entry), reason: 'tool/ 概览行必须点名 $entry');
      expect(
        File('tool/$entry.dart').existsSync() ||
            Directory('tool/$entry').existsSync(),
        isTrue,
        reason: 'tool/ 概览行点名的 tool/$entry 必须真实存在（.dart 或目录）',
      );
    }
    expect(
      toolLine,
      isNot(contains(RegExp(r'\bgate\b'))),
      reason: 'tool/ 下不存在名为 gate 的目录（门禁脚本是 tool/git_gate.dart）',
    );
    expect(
      toolLine,
      isNot(contains(RegExp(r'\bscanner\b'))),
      reason: 'tool/ 下不存在名为 scanner 的目录（边界扫描是 tool/test_boundary_scanner.dart）',
    );

    // 2) Rust PATH：不得写死某台机器的 macOS 用户路径。
    expect(
      agents,
      isNot(contains('/Users/alexc/.cargo/bin')),
      reason: 'Rust PATH 示例不得写死 /Users/alexc/.cargo/bin（跨平台仓库）',
    );
    expect(
      agents,
      contains(r'%USERPROFILE%\.cargo\bin'),
      reason: '必须保留 Windows 的 cargo 路径说明（跨平台口径）',
    );

    // 3) 布局用词：桌面端为三栏，与 ui-style-guide 一致。
    expect(agents, isNot(contains('双栏')), reason: '桌面布局口径是三栏，不得再写双栏');
    expect(agents, contains('三栏'), reason: 'AGENTS.md 必须用三栏描述桌面布局');
    expect(
      readRepoFile('docs/standards/ui-style-guide.md'),
      contains('三栏'),
      reason: '对照基线：ui-style-guide 用三栏描述桌面布局',
    );
  });

  test('README.md 的布局用词与 ui-style-guide 一致（三栏）', () {
    final readme = readRepoFile('README.md');

    expect(readme, isNot(contains('双栏')), reason: '桌面布局口径是三栏，README 不得再写双栏');
    expect(readme, contains('三栏'), reason: 'README.md 必须用三栏描述桌面布局');

    // 同一个口径不允许在两个入口文档里漂移。
    expect(
      readRepoFile('AGENTS.md'),
      contains('三栏'),
      reason: 'AGENTS.md 与 README.md 的布局用词必须一致（三栏）',
    );
  });
}
