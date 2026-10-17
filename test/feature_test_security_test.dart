import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/feature_test.dart' show validateDevice;

/// 设备标识（`flutter test -d <device>` 的 -d 值）校验的安全属性测试。
///
/// 旧版本只读 `tool/feature_test.dart` 的源码文本做 `contains(...)` 匹配：
/// 删掉校验函数、或把非法字符集改成更宽的集合，只要文本里还留着
/// `runInShell: false` 之类字样，测试照样通过。这里直接调用 `validateDevice`，
/// 用真实输入验证「shell 元字符与超长输入一律拒绝」。
void main() {
  group('validateDevice rejects shell syntax and malformed identifiers', () {
    const rejected = <String, String>{
      'device; rm -rf /': '命令分隔符 + 参数注入',
      r'$(id)': '命令替换',
      '`id`': '反引号命令替换',
      'a b': '空格会被拆成额外参数',
      'a|b': '管道符',
      'a&&b': '逻辑与串联命令',
      'a\nb': '换行（Windows 上可拆成第二条命令）',
      'a\tb': '制表符',
      '': '空标识',
    };

    rejected.forEach((input, why) {
      test('rejects ${_label(input)}（$why）', () {
        expect(
          () => validateDevice(input),
          throwsFormatException,
          reason: '设备标识「${_label(input)}」必须被拒绝：$why',
        );
      });
    });

    test('rejects identifiers longer than 128 characters', () {
      final tooLong = 'a' * 129;
      expect(
        () => validateDevice(tooLong),
        throwsFormatException,
        reason: '129 字符的设备标识必须被拒绝（上限 128）',
      );
    });
  });

  group('validateDevice accepts real device identifiers', () {
    for (final accepted in const [
      'windows',
      'emulator-5554',
      '192.168.1.2:5555',
      'R5CT30XXXXX',
    ]) {
      test('accepts $accepted', () {
        expect(
          () => validateDevice(accepted),
          returnsNormally,
          reason: '真实设备标识「$accepted」必须通过校验',
        );
      });
    }

    test('accepts identifiers of exactly 128 characters', () {
      expect(
        () => validateDevice('a' * 128),
        returnsNormally,
        reason: '128 字符是边界内输入，必须通过',
      );
    });
  });

  // `-d` 值最终交给 `Process.start`：必须走 argv 进程启动（不经过 shell 解释），
  // 且校验发生在启动之前。这里只检查调用点本身，先剥掉注释行，
  // 避免旧写法 `isNot(contains('runInShell: true'))` 被注释误伤。
  test('flutter process is launched with argv, not through a shell', () {
    final code = File('tool/feature_test.dart')
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    expect(
      RegExp(r'Process\.start\([^;]*runInShell:\s*false').hasMatch(code),
      isTrue,
      reason: '设备标识以 argv 传给 Process.start，必须显式 runInShell: false',
    );
    expect(
      RegExp(r'runInShell:\s*true').hasMatch(code),
      isFalse,
      reason: '经 shell 解释的设备标识可被 -d 值注入命令',
    );
    final validateAt = code.indexOf('validateDevice(device)');
    final startAt = code.indexOf('Process.start(');
    expect(validateAt, greaterThan(-1), reason: '启动进程前必须校验设备标识');
    expect(
      validateAt < startAt,
      isTrue,
      reason: '设备标识校验必须发生在 Process.start 之前',
    );
  });
}

/// 让测试名里的控制字符可见（空串 / 换行 / 制表符）。
String _label(String input) {
  if (input.isEmpty) return '<empty>';
  return input
      .replaceAll('\n', r'\n')
      .replaceAll('\t', r'\t')
      .replaceAll('\r', r'\r');
}
