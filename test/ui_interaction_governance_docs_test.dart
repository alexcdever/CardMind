// input: UI 交互治理三件套文档内容
// output: 验证文档存在性、关键约束与场景覆盖
// pos: UI 交互治理文档守卫测试；修改需同步 test/DIR.md
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

  test('acceptance matrix reflects card-note CRUD and pool CRUD scope', () {
    final content = File(
      'docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md',
    ).readAsStringSync();

    expect(content, contains('S2 卡片笔记管理'));
    expect(content, contains('增删改查'));
    expect(content, contains('S3 池管理'));
    expect(content, contains('增删改查 + 创建/加入/审批/退出'));
    expect(content, contains('S4 设置'));
    expect(content, contains('Tab 可一步切换至卡片页和池页'));
  });

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
