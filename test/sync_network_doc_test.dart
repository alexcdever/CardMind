import 'package:flutter_test/flutter_test.dart';

import 'support/doc_helpers.dart';

void main() {
  test('sync-network.md 开头日期不早于该文件内容最近一次修改', () {
    final doc = readRepoFile('docs/sync-network.md');
    final header = doc.split('\n').take(6).join('\n');

    final declaredDates = RegExp(
      r'(\d{4}-\d{2}-\d{2})',
    ).allMatches(header).map((match) => match.group(1)!).toList();
    expect(
      declaredDates,
      isNotEmpty,
      reason: 'sync-network.md 开头必须声明定稿 / 更新日期',
    );
    final latest = declaredDates.reduce((a, b) => a.compareTo(b) >= 0 ? a : b);

    // 同 product.md：有未提交改动时声明日期必须是今天，否则退回提交日期比较。
    final expected = expectedDocDate('docs/sync-network.md');
    expect(expected, isNotEmpty, reason: '必须能判定 sync-network.md 的最近修改日期');
    if (docHasUncommittedChange('docs/sync-network.md')) {
      expect(
        latest,
        expected,
        reason:
            'docs/sync-network.md 有未提交改动，开头日期必须改成当天 $expected，'
            '实际 $latest（改了文档不改日期会在提交后才被发现）',
      );
    } else {
      expect(
        latest.compareTo(expected) >= 0,
        isTrue,
        reason: '开头声明的日期 $latest 早于该文件内容最近一次真实修改 $expected（日期必须一起改对）',
      );
    }
  });
}
