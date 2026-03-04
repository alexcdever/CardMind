// input: 读取治理设计、验收矩阵、发布门禁与 plans 目录文档内容。
// output: 必需文档存在且包含规定场景与验证命令关键字。
// pos: 覆盖 UI 交互治理文档完整性门禁，防止发布漏文档。修改本文件需同步更新文件头与所属 DIR.md。
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
      'S1 首屏直达卡片',
      'S2 卡片管理',
      'S3 池管理',
      'S4 设置',
      'S5 全局同步异常',
    ]) {
      expect(content, contains(scenario));
    }
  });

  test('governance docs include shell two-step back and exit confirmation', () {
    final design = File(
      'docs/plans/2026-02-27-ui-interaction-governance-design.md',
    ).readAsStringSync();
    expect(design, contains('主壳双段返回'));
    expect(design, contains('是否退出应用'));
  });

  test(
    'design doc uses direct cards entry wording instead of onboarding split',
    () {
      final content = File('docs/specs/ui-interaction.md').readAsStringSync();

      expect(content, contains('首屏默认卡片'));
      expect(content.contains('首屏 MUST 显示两个主动作：`先本地使用`、`创建/加入池`'), isFalse);
    },
  );

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

    const poolLifecycleKeywords = <String>[
      '增删改查 + 创建/加入/审批',
      '退出',
      '编辑池信息',
      '解散池',
    ];

    expect(content, contains('S2 卡片笔记管理'));
    expect(content, contains('增删改查'));
    expect(content, contains('S3 池管理'));
    for (final keyword in poolLifecycleKeywords) {
      expect(content, contains(keyword));
    }
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

  test('acceptance matrix and release gate include S1-S5 plan mapping', () {
    final matrix = File(
      'docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md',
    ).readAsStringSync();
    final gate = File(
      'docs/plans/2026-02-27-ui-interaction-release-gate.md',
    ).readAsStringSync();

    const planFile =
        'docs/plans/2026-03-05-ui-interaction-full-s1-s5-implementation-plan.md';

    expect(matrix, contains(planFile));
    expect(gate, contains(planFile));
    for (final marker in const ['S1', 'S2', 'S3', 'S4', 'S5']) {
      expect(matrix, contains('| $marker '));
      expect(gate, contains('| $marker '));
    }
  });

  test('governance docs record explicit S1 completion evidence', () {
    final design = File(
      'docs/plans/2026-02-27-ui-interaction-governance-design.md',
    ).readAsStringSync();
    final matrix = File(
      'docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md',
    ).readAsStringSync();
    final gate = File(
      'docs/plans/2026-02-27-ui-interaction-release-gate.md',
    ).readAsStringSync();

    expect(design, contains('S1 完成证据'));
    expect(matrix, contains('S1 完成证据'));
    expect(gate, contains('S1 完成证据'));
    expect(design, contains('app cold start shows shell bottom nav on mobile'));
    expect(design, contains('back on cards shows exit confirmation dialog'));
    expect(design, contains('cancel on dialog stays in cards root'));
    expect(
      gate,
      contains('flutter test test/app/app_shell_navigation_test.dart'),
    );
  });

  test('governance docs record explicit S2 acceptance and gate evidence', () {
    final design = File(
      'docs/plans/2026-02-27-ui-interaction-governance-design.md',
    ).readAsStringSync();
    final matrix = File(
      'docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md',
    ).readAsStringSync();
    final gate = File(
      'docs/plans/2026-02-27-ui-interaction-release-gate.md',
    ).readAsStringSync();

    expect(design, contains('S2 完成证据'));
    expect(matrix, contains('S2 完成证据'));
    expect(gate, contains('S2 完成证据'));
    expect(
      design,
      contains('create-edit-save appears in cards list through read model'),
    );
    expect(design, contains('save failure keeps editor open with retry hint'));
    expect(
      gate,
      contains('flutter test test/features/cards/cards_page_test.dart'),
    );
    expect(
      gate,
      contains('flutter test test/features/editor/editor_page_test.dart'),
    );
  });

  test('governance docs record explicit S3 stable-error evidence', () {
    final design = File(
      'docs/plans/2026-02-27-ui-interaction-governance-design.md',
    ).readAsStringSync();
    final matrix = File(
      'docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md',
    ).readAsStringSync();
    final gate = File(
      'docs/plans/2026-02-27-ui-interaction-release-gate.md',
    ).readAsStringSync();

    expect(design, contains('S3 完成证据'));
    expect(matrix, contains('S3 完成证据'));
    expect(gate, contains('S3 完成证据'));
    expect(
      design,
      contains('POOL_NOT_FOUND shows stable primary and follow-up actions'),
    );
    expect(
      design,
      contains('maps REQUEST_TIMEOUT to what happened and next step message'),
    );
    expect(
      gate,
      contains('flutter test test/features/pool/pool_page_test.dart'),
    );
    expect(
      gate,
      contains('flutter test test/features/pool/join_error_mapper_test.dart'),
    );
  });
}
