import 'package:flutter_test/flutter_test.dart';

import 'support/doc_helpers.dart';

void main() {
  test('design-tokens 圆角表与 CardMindRadii 逐项一致', () {
    final tokens = readRepoFile('docs/standards/design-tokens.md');
    final table = sectionOf(tokens, '## 圆角');
    final theme = readRepoFile('lib/ui/design_system/cardmind_theme.dart');

    // 代码侧真相源：`CardMindRadii` 里的常量与取值。
    final blockStart = theme.indexOf('abstract final class CardMindRadii');
    expect(
      blockStart,
      greaterThan(-1),
      reason: '必须能从 cardmind_theme.dart 找到 CardMindRadii',
    );
    final block = theme.substring(blockStart);
    final body = block.substring(0, block.indexOf('}'));
    final defined = <String, String>{
      for (final match in RegExp(
        r'static const double (\w+) = (\d+)',
      ).allMatches(body))
        match.group(1)!: match.group(2)!,
    };
    expect(defined.keys.toSet(), <String>{
      'sm',
      'md',
      'lg',
      'xl',
    }, reason: 'CardMindRadii 应有 sm / md / lg / xl 四个常量');

    // 文档侧：圆角表列出的 token 集合必须与代码一致（不多不少）。
    final documented = RegExp(
      r'`radius\.(\w+)`',
    ).allMatches(table).map((match) => match.group(1)!).toSet();
    expect(
      documented,
      defined.keys.toSet(),
      reason: '圆角表与 CardMindRadii 的 token 集合必须一致（多出的 token 在代码里没有实现）',
    );

    // 逐项数值一致。
    defined.forEach((name, value) {
      final row = RegExp('`radius\\.$name`[^\\n]*').firstMatch(table);
      expect(row, isNotNull, reason: '圆角表缺少 `radius.$name`');
      expect(
        row!.group(0),
        contains('${value}px'),
        reason: '`radius.$name` 的取值与 CardMindRadii.$name（${value}px）不一致',
      );
    });
  });
}
