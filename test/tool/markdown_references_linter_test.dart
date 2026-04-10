// input: 针对 Markdown 引用检查脚本的相对路径、锚点与 CLI 返回码行为编写测试。
// output: 验证脚本能准确报告失效引用，并为质量门禁提供稳定返回码。
// pos: test/tool/markdown_references_linter_test.dart - Markdown 引用检查脚本测试，修改本文件需同步更新文件头与所属 DIR.md。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/lint/markdown_references_linter.dart';

void main() {
  group('extractReferences', () {
    test('keeps file path and strips markdown anchor', () {
      final references = extractReferences(
        '[spec](../docs/specs/example.md#accepted-behavior)',
        File('/repo/docs/plans/plan.md'),
      );

      expect(references, hasLength(1));
      expect(references.single.originalPath, '../docs/specs/example.md');
      expect(references.single.sourceFile.path, '/repo/docs/plans/plan.md');
    });

    test('keeps file path when markdown link includes title text', () {
      final references = extractReferences(
        '[spec](../docs/specs/example.md#accepted-behavior "Spec Title")',
        File('/repo/docs/plans/plan.md'),
      );

      expect(references, hasLength(1));
      expect(references.single.originalPath, '../docs/specs/example.md');
    });
  });

  group('verifyReferences', () {
    test(
      'reports missing reference with source file and resolved path',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'markdown_references_linter_test_',
        );
        addTearDown(() => tempDir.delete(recursive: true));

        final sourceFile = File('${tempDir.path}/docs/plans/feature.md')
          ..createSync(recursive: true);

        final missingReferences = verifyReferences(tempDir, [
          ReferenceInfo(
            originalPath: '../specs/missing.md',
            sourceFile: sourceFile,
          ),
        ]);

        expect(missingReferences, hasLength(1));
        expect(missingReferences.single.originalPath, '../specs/missing.md');
        expect(missingReferences.single.sourceFile.path, sourceFile.path);
        expect(
          missingReferences.single.resolvedPath,
          '${tempDir.path}/docs/specs/missing.md',
        );
      },
    );

    test('accepts existing relative reference with anchor suffix', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'markdown_references_linter_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final sourceFile = File('${tempDir.path}/docs/plans/feature.md')
        ..createSync(recursive: true);
      File(
        '${tempDir.path}/docs/specs/accepted.md',
      ).createSync(recursive: true);

      final references = extractReferences(
        '[spec](../specs/accepted.md#done)',
        sourceFile,
      );

      expect(verifyReferences(tempDir, references), isEmpty);
    });

    test(
      'accepts existing relative reference with URL encoded spaces',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'markdown_references_linter_test_',
        );
        addTearDown(() => tempDir.delete(recursive: true));

        final sourceFile = File('${tempDir.path}/docs/plans/feature.md')
          ..createSync(recursive: true);
        File(
          '${tempDir.path}/docs/specs/accepted path.md',
        ).createSync(recursive: true);

        final references = extractReferences(
          '[spec](../specs/accepted%20path.md)',
          sourceFile,
        );

        expect(verifyReferences(tempDir, references), isEmpty);
      },
    );
  });

  group('runMarkdownReferencesLint', () {
    test(
      'returns non-zero and logs source file when a reference is missing',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'markdown_references_linter_test_',
        );
        addTearDown(() => tempDir.delete(recursive: true));

        File('${tempDir.path}/docs/plans/feature.md')
          ..createSync(recursive: true)
          ..writeAsStringSync('[missing](../specs/missing.md)');

        final logs = <String>[];
        final exit = await runMarkdownReferencesLint(
          projectRoot: tempDir,
          log: logs.add,
        );

        expect(exit, 1);
        expect(logs.join('\n'), contains('docs/plans/feature.md'));
        expect(logs.join('\n'), contains('../specs/missing.md'));
        expect(logs.join('\n'), contains('docs/specs/missing.md'));
      },
    );

    test('ignores markdown files under .worktrees', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'markdown_references_linter_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      File(
        '${tempDir.path}/docs/specs/accepted.md',
      ).createSync(recursive: true);
      File('${tempDir.path}/docs/progress.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('[accepted](./specs/accepted.md)');

      File('${tempDir.path}/.worktrees/demo/docs/progress.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('[missing](docs/specs/missing.md)');

      final logs = <String>[];
      final exit = await runMarkdownReferencesLint(
        projectRoot: tempDir,
        log: logs.add,
      );

      expect(exit, 0);
      expect(logs.join('\n'), contains('All references are valid!'));
      expect(
        logs.join('\n'),
        isNot(contains('.worktrees/demo/docs/progress.md')),
      );
    });
  });
}
