// input: docs/plans governance markdown files
// output: fast fail when required governance docs are missing
// pos: test guard for ui governance docs; 修改本文件需同步更新文件头与所属 DIR.md
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('governance companion docs exist', () {
    expect(
      File(
        'docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md',
      ).existsSync(),
      isTrue,
    );
    expect(
      File('docs/plans/2026-02-27-ui-interaction-release-gate.md').existsSync(),
      isTrue,
    );
  });

  test('design doc includes required scenarios', () {
    final content = File(
      'docs/plans/2026-02-27-ui-interaction-governance-design.md',
    ).readAsStringSync();

    for (final scenario in [
      'S1 引导分流',
      'S2 卡片管理',
      'S3 池管理',
      'S4 设置',
      'S5 全局同步异常',
    ]) {
      expect(content, contains(scenario));
    }
  });

  test(
    'acceptance matrix has both dev and experience tracks for all scenarios',
    () {
      final content = File(
        'docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md',
      ).readAsStringSync();

      for (final scenario in ['S1 ', 'S2 ', 'S3 ', 'S4 ', 'S5 ']) {
        expect(content, contains(scenario));
      }
      expect(content, contains('研发轨断言'));
      expect(content, contains('体验轨阈值'));
    },
  );

  test('plans DIR includes governance plan and companion docs', () {
    final dirContent = File('docs/plans/DIR.md').readAsStringSync();

    expect(
      dirContent,
      contains('2026-02-27-ui-interaction-governance-design.md'),
    );
    expect(
      dirContent,
      contains('2026-02-27-ui-interaction-governance-implementation-plan.md'),
    );
    expect(
      dirContent,
      contains('2026-02-27-ui-interaction-acceptance-matrix.md'),
    );
    expect(dirContent, contains('2026-02-27-ui-interaction-release-gate.md'));
  });

  test('release gate doc references required verification commands', () {
    final content = File(
      'docs/plans/2026-02-27-ui-interaction-release-gate.md',
    ).readAsStringSync();

    expect(content, contains('flutter analyze'));
    expect(content, contains('flutter test'));
    expect(content, contains('dart run tool/fractal_doc_check.dart --base'));
  });
}
