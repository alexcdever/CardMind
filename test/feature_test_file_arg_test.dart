import 'package:flutter_test/flutter_test.dart';

import '../tool/feature_test.dart'
    show featureTestTargetForArgs, kDefaultFeatureTestTarget, validateTestFile;

/// `--file=<path>` 目标文件参数的安全属性与解析行为测试。
///
/// 直接调用公开校验 `validateTestFile` 与公开解析 `featureTestTargetForArgs`，
/// 用真实输入验证「非法路径一律拒绝、合法相对路径可解析、缺省回落
/// cardmind_journeys」三件事。
void main() {
  group('validateTestFile rejects path escape and shell syntax', () {
    const rejected = <String, String>{
      r'..': '纯父目录引用',
      r'..\windows\system32_test.dart': 'Windows 路径逃逸',
      r'../../etc/passwd_test.dart': 'POSIX 路径逃逸',
      r'../x_test.dart': '父目录逃逸',
      r'/abs/path_test.dart': 'POSIX 绝对路径',
      r'C:\abs\path_test.dart': 'Windows 盘符绝对路径',
      r'\\server\share\x_test.dart': 'UNC 网络路径',
      'x_test.dart;rm -rf /': '命令分隔符',
      'x_test.dart&whoami': '后台执行',
      'x_test.dart|cat': '管道',
      r'x$(id)_test.dart': '命令替换',
      'x`id`_test.dart': '反引号命令替换',
      'x test.dart': '含空格',
      '"x_test.dart"': '引号',
      "x'_test.dart": '单引号',
      r'$HOME_test.dart': '变量展开',
      'x%PATH%_test.dart': 'Windows 环境变量展开',
      'x~_test.dart': '家目录展开',
      'x*_test.dart': '通配符',
      'x?_test.dart': '单字符通配符',
      'x_test.dart\nwhoami': '换行拆分命令',
      'unit/foo_test.dart': 'integration_test 目录外的相对路径',
      'lib/foo_test.dart': 'lib 下的相对路径（不属集成测试目录）',
      'integration_test/': '目录不是文件',
      'integration_test/helper.dart': '非 _test.dart 结尾',
      'integration_test/support/harness.dart': 'support 内的非测试文件',
      '': '空路径',
    };

    rejected.forEach((input, why) {
      test('rejects ${_label(input)}（$why）', () {
        expect(
          () => validateTestFile(input),
          throwsFormatException,
          reason: '--file 值「${_label(input)}」必须被拒绝：$why',
        );
      });
    });

    test('rejects paths longer than 256 characters', () {
      final tooLong = 'integration_test/${'a' * 260}_test.dart';
      expect(() => validateTestFile(tooLong), throwsFormatException);
    });
  });

  group('validateTestFile accepts integration_test relative paths', () {
    for (final accepted in const [
      'integration_test/cardmind_journeys_test.dart',
      'integration_test/device_name_live_test.dart',
      'integration_test/pairing_credential_platform_test.dart',
      'integration_test/pairing_credential_dual_end_test.dart',
      'integration_test/receiver_platform_test.dart',
      // 子目录下的测试文件也应可用（support/ 组织形态）。
      'integration_test/support/foo_test.dart',
    ]) {
      test('accepts $accepted', () {
        expect(
          () => validateTestFile(accepted),
          returnsNormally,
          reason: 'integration_test 下的相对测试路径必须通过校验',
        );
      });
    }
  });

  group('featureTestTargetForArgs resolves --file', () {
    test('defaults to cardmind_journeys target when --file absent', () {
      expect(
        featureTestTargetForArgs(const ['--windows']),
        kDefaultFeatureTestTarget,
      );
      expect(
        featureTestTargetForArgs(const []),
        'integration_test/cardmind_journeys_test.dart',
      );
    });

    test('resolves --file=<path> to the given target', () {
      expect(
        featureTestTargetForArgs(const [
          '--windows',
          '--file=integration_test/device_name_live_test.dart',
        ]),
        'integration_test/device_name_live_test.dart',
      );
    });

    test('rejects malicious --file values at parse time', () {
      for (final bad in const [
        '--file=../escape_test.dart',
        '--file=x_test.dart;id',
        r'--file=C:\abs\x_test.dart',
        '--file=lib/foo_test.dart',
      ]) {
        expect(
          () => featureTestTargetForArgs([bad]),
          throwsFormatException,
          reason: '解析阶段必须拒绝非法 --file 值「$bad」',
        );
      }
    });
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
