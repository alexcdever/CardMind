import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/feature_test.dart'
    show
        enumerateIntegrationTests,
        featureTestAllTargetsForArgs,
        validateDevice,
        validateTestFile;

/// 设备标识（`flutter test -d <device>` 的 -d 值）校验的安全属性测试。
///
/// 旧版本只读 `tool/feature_test.dart` 的源码文本做 `contains(...)` 匹配：
/// 删掉校验函数、或把非法字符集改成更宽的集合，只要文本里还留着
/// `runInShell: false` 之类字样，测试照样通过。这里直接调用 `validateDevice`，
/// 用真实输入验证「shell 元字符与超长输入一律拒绝」。
void main() {
  group('validateDevice rejects shell syntax and malformed identifiers', () {
    // 单字符隔离：每个被禁字符单独出现一次，两侧都是合法字符 `a`/`b`，
    // 因此失败原因只能是该字符本身。放宽字符集里的任意一个都会让对应用例变红。
    const forbiddenChars = <String, String>{
      ';': '命令分隔符',
      '&': '后台执行 / 逻辑与',
      '|': '管道',
      r'$': '变量 / 命令替换起始',
      '`': '反引号命令替换',
      '"': '双引号（引号逃逸）',
      "'": '单引号（引号逃逸）',
      '>': '输出重定向',
      '<': '输入重定向',
      '*': '通配符',
      '?': '单字符通配符',
      '(': '子 shell 起始',
      ')': '子 shell 结束',
      '{': '花括号展开',
      '}': '花括号展开',
      '[': '字符类 / 测试命令',
      ']': '字符类 / 测试命令',
      '!': '历史展开 / 取反',
      '#': '注释起始',
      '~': '家目录展开',
      '%': 'Windows 环境变量展开',
      '^': '转义 / 取反',
      '=': '赋值 / 参数注入',
      ',': '参数分隔',
      '/': '路径分隔（可注入绝对路径）',
      r'\': '转义字符',
      ' ': '空格（会被拆成额外参数）',
      '\t': '制表符',
      '\n': '换行（Windows 上可拆成第二条命令）',
      '\r': '回车',
    };

    forbiddenChars.forEach((char, why) {
      final input = 'a${char}b';
      test('rejects the single forbidden character ${_label(char)}（$why）', () {
        expect(
          () => validateDevice(input),
          throwsFormatException,
          reason: '设备标识不得含 ${_label(char)}（$why），实际接受了「${_label(input)}」',
        );
      });
    });

    // 组合注入串（真实攻击形态，与上面的单字符隔离互补）。
    const rejected = <String, String>{
      'device; rm -rf /': '命令分隔符 + 参数注入',
      r'$(id)': '命令替换',
      '`id`': '反引号命令替换',
      'a&&b': '逻辑与串联命令',
      'a;b;c': '多命令串联',
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
      // 合法字符集 `A-Za-z0-9._:-` 逐项都要继续被接受，避免「收紧过头」。
      'a.b',
      'a_b',
      'a:b',
      'a-b',
      'A.b_c:D-e',
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

  // `--all` 枚举出的每个文件都走与 `--file` 完全相同的校验链路：
  // 枚举结果必须逐条过 validateTestFile，且不得逃出 integration_test/。
  test(
    '--all enumeration stays inside integration_test/ and passes validateTestFile',
    () {
      final all = enumerateIntegrationTests();
      expect(all, isNotEmpty, reason: '--all 必须枚举到真实集成测试文件');
      for (final f in all) {
        expect(
          f.startsWith('integration_test/'),
          isTrue,
          reason: '--all 枚举值「$f」必须在 integration_test/ 下',
        );
        expect(
          f.endsWith('_test.dart'),
          isTrue,
          reason: '--all 枚举值「$f」必须是 _test.dart（排除 support/ 辅助文件）',
        );
        expect(f.contains('..'), isFalse, reason: '--all 枚举值「$f」不得含路径逃逸片段');
        expect(
          () => validateTestFile(f),
          returnsNormally,
          reason: '--all 枚举值「$f」必须通过与 --file 相同的 validateTestFile',
        );
      }
    },
  );

  test('--all rejects --file at parse time（互斥，防静默取其一）', () {
    expect(
      () => featureTestAllTargetsForArgs(const [
        '--all',
        '--file=integration_test/device_name_live_test.dart',
      ]),
      throwsFormatException,
      reason: '--all 与 --file 互斥：静默取其一会让 CI 报告跑全量实则跑单文件',
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
