// input: 遍历 lib 目录下全部 Dart 文件并匹配交互处理器模式。
// output: 发现空处理器或禁用主交互时输出违规文件并失败。
// pos: 覆盖交互守卫静态扫描规则，防止空交互进入主干。修改本文件需同步更新文件头与所属 DIR.md。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib has no empty or disabled primary interaction handlers', () {
    final root = Directory.current;
    final libDir = Directory('${root.path}/lib');
    final emptyHandler = RegExp(r'on[A-Za-z0-9_]+\s*:\s*\(\)\s*\{\s*\}');
    final disabledPressed = RegExp(r'onPressed\s*:\s*null');
    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }

      final content = entity.readAsStringSync();
      if (emptyHandler.hasMatch(content) || disabledPressed.hasMatch(content)) {
        final relativePath = entity.path.replaceFirst('${root.path}/', '');
        violations.add(relativePath);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Found empty/disabled interactions in: ${violations.join(', ')}',
    );
  });
}
