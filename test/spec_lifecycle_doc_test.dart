import 'package:flutter_test/flutter_test.dart';

import 'support/doc_helpers.dart';

void main() {
  test('spec-lifecycle 不再把 plan 当作现行文档类型', () {
    final doc = readRepoFile('docs/standards/spec-lifecycle.md');

    final title = doc.split('\n').first;
    expect(
      title,
      isNot(contains('plan')),
      reason: '标题不得再把 plan 与 standard 并列声明为现行文档类型',
    );

    expect(
      sectionOf(doc, '## 目标'),
      isNot(contains('`plan`')),
      reason: '「目标」不得再把 plan 与 standard 并列定义为文档类型',
    );

    final types = sectionOf(doc, '## 文档类型');
    expect(
      types.split('\n').where((line) => line.trimLeft().startsWith('- `plan`')),
      isEmpty,
      reason: '「文档类型」不得再把 plan 列成现行类型（只能作历史提及）',
    );
    expect(types, contains('`standard`'), reason: '必须保留 standard 类型');

    // plan 类文档的载体目录已整体删除：正文不得再声称它存在。
    expect(
      doc,
      isNot(contains('docs/plans')),
      reason: 'plan 类文档的载体目录已整体删除，文档不得再引用它',
    );

    // 「正式行为文档（唯一真相源）」与更新触发规则的含义不变。
    expect(doc, contains('## 正式行为文档（唯一真相源）'));
    expect(doc, contains('`docs/adr/`'));
    expect(doc, contains('`docs/product.md`'));
    expect(doc, contains('## 正式行为更新触发规则'));
  });

  test('AGENTS.md 指向 spec-lifecycle 的括注不再声明 plan 类型', () {
    final lines = readRepoFile(
      'AGENTS.md',
    ).split('\n').where((line) => line.contains('spec-lifecycle')).toList();
    expect(
      lines,
      hasLength(1),
      reason: 'AGENTS.md 文档地图应恰有一条 spec-lifecycle 引用',
    );
    expect(
      lines.single,
      isNot(contains('plan')),
      reason: '括注不得再写「（plan / standard）」：plan 已不是现行文档类型',
    );
  });
}
