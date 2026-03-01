// input: 扫描 docs/plans 下所有 *plan*.md 文件并读取内容。
// output: 每个计划文档都包含 Red/Green/Blue/Commit 的强制执行规则。
// pos: 治理守卫，阻止计划文档退化为仅 Red/Green 的不完整 TDD 流程。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const legacyPlanFilesWithoutBlueRule = <String>{
    'docs/plans/2026-02-18-rebuild-foundation-plan.md',
    'docs/plans/2026-02-22-frb-api-implementation-plan.md',
    'docs/plans/2026-02-24-agents-claude-implementation-plan.md',
    'docs/plans/2026-02-25-fractal-doc-dir-md-check-plan.md',
    'docs/plans/2026-02-25-fractal-documentation-implementation-plan.md',
    'docs/plans/2026-02-26-iroh-migration-implementation-plan.md',
    'docs/plans/2026-02-26-pool-network-sync-implementation-plan.md',
    'docs/plans/2026-02-27-build-cli-implementation-plan.md',
    'docs/plans/2026-02-27-mobile-desktop-ui-interaction-implementation-plan.md',
    'docs/plans/2026-02-27-ui-interaction-governance-implementation-plan.md',
    'docs/plans/2026-02-28-flutter-rust-sync-integration-implementation-plan.md',
    'docs/plans/2026-02-28-rs-dart-file-header-truthfulness-implementation-plan.md',
    'docs/plans/2026-02-28-rust-flutter-chinese-comments-implementation-plan.md',
    'docs/plans/2026-02-28-ui-interaction-full-alignment-implementation-plan.md',
    'docs/plans/2026-02-28-usable-app-readwrite-split-implementation-plan.md',
  };

  test('new plan docs enforce complete Red-Green-Blue-Commit workflow', () {
    final planFiles = _listPlanFiles();

    expect(
      planFiles,
      isNotEmpty,
      reason: 'docs/plans should include *plan*.md files',
    );

    final missingFiles = <String>[];

    for (final file in planFiles) {
      if (_requiresTddRule(file, legacyPlanFilesWithoutBlueRule) &&
          !_hasCompleteTddWorkflow(file.readAsStringSync())) {
        missingFiles.add(file.path);
      }
    }

    expect(
      missingFiles,
      isEmpty,
      reason:
          'Missing mandatory complete TDD workflow: ${missingFiles.join(', ')}',
    );
  });

  test('plan guard validates all current plan files', () {
    final planFiles = _listPlanFiles();
    expect(
      planFiles.length,
      17,
      reason: 'Unexpected docs/plans/*plan*.md file count',
    );

    final missingFiles = <String>[];
    for (final file in planFiles) {
      if (_requiresTddRule(file, legacyPlanFilesWithoutBlueRule) &&
          !_hasCompleteTddWorkflow(file.readAsStringSync())) {
        missingFiles.add(file.path);
      }
    }

    expect(
      missingFiles,
      isEmpty,
      reason:
          'Plans missing complete TDD workflow block: ${missingFiles.join(', ')}',
    );
  });
}

List<File> _listPlanFiles() {
  final files = Directory('docs/plans')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('plan.md'))
      .toList();
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

bool _requiresTddRule(File file, Set<String> legacyPlanFilesWithoutBlueRule) {
  return !legacyPlanFilesWithoutBlueRule.contains(file.path);
}

bool _hasCompleteTddWorkflow(String content) {
  final hasRed = content.contains('Red') || content.contains('红');
  final hasGreen = content.contains('Green') || content.contains('绿');
  final hasBlue = content.contains('Blue') || content.contains('蓝');
  final hasRedGreenBlueCommitFlow =
      content.contains('Red -> Green -> Blue -> Commit') ||
      content.contains('Red→Green→Blue→Commit') ||
      content.contains('红 -> 绿 -> 蓝 -> 提交') ||
      content.contains('红→绿→蓝→提交');
  final hasFailingTestStep =
      content.contains('failing test') ||
      content.contains('verify it fails') ||
      content.contains('Expected: FAIL') ||
      content.contains('失败测试') ||
      content.contains('按预期失败');
  final hasPassingTestStep =
      content.contains('verify it passes') ||
      content.contains('Expected: PASS') ||
      content.contains('确认通过') ||
      content.contains('按预期通过');
  final hasRefactorStep =
      content.contains('Blue refactor') || content.contains('重构');
  final hasCommitStep =
      content.contains('Step 6: Commit') || content.contains('提交');

  return hasRed &&
      hasGreen &&
      hasBlue &&
      hasRedGreenBlueCommitFlow &&
      hasFailingTestStep &&
      hasPassingTestStep &&
      hasRefactorStep &&
      hasCommitStep;
}
