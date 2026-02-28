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
  };

  test('every docs/plans/*plan*.md includes red-green-blue rule', () {
    final planFiles = _listPlanFiles();

    expect(
      planFiles,
      isNotEmpty,
      reason: 'docs/plans should include *plan*.md files',
    );

    final missingFiles = <String>[];

    for (final file in planFiles) {
      if (_requiresTddRule(file, legacyPlanFilesWithoutBlueRule) &&
          !_hasRedGreenBlueRule(file.readAsStringSync())) {
        missingFiles.add(file.path);
      }
    }

    expect(
      missingFiles,
      isEmpty,
      reason:
          'Missing mandatory Red-Green-Blue-before-Commit rule: ${missingFiles.join(', ')}',
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

bool _hasRedGreenBlueRule(String content) {
  final hasRed = content.contains('Red');
  final hasGreen = content.contains('Green');
  final hasBlue = content.contains('Blue');
  final hasBlueBeforeCommit =
      content.contains('Red -> Green -> Blue -> Commit') ||
      content.contains('Red→Green→Blue→Commit');
  return hasRed && hasGreen && hasBlue && hasBlueBeforeCommit;
}
