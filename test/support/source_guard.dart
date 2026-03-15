// input: 测试传入源码文件路径、待检查 token 与约束文案。
// output: 提供统一的源码读取与 contains/omits 守卫断言辅助函数。
// pos: 供架构/主路径源码守卫测试复用的辅助文件。修改本文件需同步更新文件头与所属 DIR.md。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String readSource(String path) => File(path).readAsStringSync();

void expectSourceContains(
  String source,
  String token, {
  required String fileLabel,
  required String requirementLabel,
}) {
  expect(
    source.contains(token),
    isTrue,
    reason: '$fileLabel must $requirementLabel token `$token`.',
  );
}

void expectSourceOmits(
  String source,
  String token, {
  required String fileLabel,
  required String violationLabel,
}) {
  expect(
    source.contains(token),
    isFalse,
    reason: '$fileLabel must not $violationLabel token `$token`.',
  );
}
