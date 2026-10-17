import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/doc_helpers.dart';

void main() {
  test('UI 规范里的危险操作举例与当前实现相符', () {
    final guide = readRepoFile('docs/standards/ui-style-guide.md');

    expect(
      guide.contains('解散'),
      isFalse,
      reason: '「解散」属于已删除功能的举例（数据池时代遗留），必须去掉',
    );

    final dangerLines = guide
        .split('\n')
        .where((line) => line.contains('危险操作'))
        .toList();
    expect(dangerLines, hasLength(1), reason: '「危险操作」应当恰有一条规范陈述');

    // 括号里用 / 分隔的具体操作名，必须能在 lib/ 里找到用户可见实现；
    // 若改成不点名具体功能的通用表述（没有括号举例），本条自然通过。
    final example = RegExp(r'[（(]([^）)]*)[）)]').firstMatch(dangerLines.single);
    if (example == null) return;

    final dartSources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    final names = example
        .group(1)!
        .split('/')
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    for (final name in names) {
      expect(
        dartSources,
        contains(name),
        reason: 'UI 规范举的「$name」在 lib/ 里找不到对应实现，属已删除功能的残留举例',
      );
    }
  });
}
