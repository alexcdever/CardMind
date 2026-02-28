// input: test/interaction_guard_test.dart 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Flutter 测试模块，验证 UI、交互守卫与文档门禁行为。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 测试模块，验证 UI、交互守卫与文档门禁行为。
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
