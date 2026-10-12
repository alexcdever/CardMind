import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 文档验收测试：把本次「docs 收尾」任务的验收标准固定成可执行的检查。
///
/// 只读取仓库文件与 git 元数据，不触碰产品代码；每个 test 对应一条验收标准
/// （标准编号写进测试名，便于逐条自检）。
Directory get _repoRoot => Directory.current;

String _read(String relativePath) => File(relativePath).readAsStringSync();

/// 文件名（跨平台取最后一段路径）。
String _fileName(String filePath) =>
    filePath.replaceAll('\\', '/').split('/').last;

/// git 元数据查询（只读）。
ProcessResult _git(List<String> args) =>
    Process.runSync('git', args, workingDirectory: _repoRoot.path);

/// 定位编号 0008 的新 ADR（`docs/adr/0008-*.md`，必须恰有一份）。
String _adr0008Path() {
  final matches =
      Directory('docs/adr')
          .listSync()
          .whereType<File>()
          .map((file) => file.path)
          .where((path) => _fileName(path).startsWith('0008-'))
          .where((path) => path.endsWith('.md'))
          .toList()
        ..sort();
  expect(matches, hasLength(1), reason: 'docs/adr/ 下必须恰有一份编号 0008 的 ADR');
  return matches.single;
}

void main() {
  test('验收 3：docs/ 根目录不再保留任何一次性任务单', () {
    final tracked = _git(['ls-files', 'docs/task-*.md']);
    expect(tracked.exitCode, 0, reason: 'git ls-files 必须成功');
    expect(
      (tracked.stdout as String).trim(),
      isEmpty,
      reason: 'git ls-files docs/task-*.md 必须输出为空（一次性任务单已从版本控制移除）',
    );

    final leftovers =
        Directory('docs')
            .listSync()
            .whereType<File>()
            .map((file) => _fileName(file.path))
            .where((name) => name.startsWith('task-') && name.endsWith('.md'))
            .toList()
          ..sort();
    expect(leftovers, isEmpty, reason: 'docs/ 根目录不得残留未跟踪的 task-*.md');
  });

  test('验收 1：ADR 0008 存在，且覆盖协议必备内容', () {
    final adr = _read(_adr0008Path());

    // 与既有 ADR 同体例的头部元信息。
    expect(adr, contains('**日期**'), reason: 'ADR 头部必须有日期');
    expect(adr, contains('**状态**'), reason: 'ADR 头部必须有状态');
    expect(adr, contains('**决策者**'), reason: 'ADR 头部必须有决策者');

    // 验收标准要求的覆盖点：每项都必须能在 ADR 里找到对应表述。
    const required = <String, List<String>>{
      '用途与参与方': ['配对凭证', '发起方', '确认方', '节点 ID'],
      'canonical payload 构成（版本/前缀/字段与编码）': [
        'CREDENTIAL_MAGIC',
        'CREDENTIAL_VERSION_V2',
        'CREDENTIAL_PAYLOAD_LEN',
        '大端',
      ],
      '签名与校验方式': [
        'SecretKey',
        'PublicKey',
        'CREDENTIAL_SIGNATURE_LEN',
        'parse_credential',
      ],
      'nonce 的生成与防重放': ['nonce', 'PairingSession', 'confirm_pairing'],
      '凭证有效期与失败尝试上限': [
        'CREDENTIAL_TTL_SECS',
        'CREDENTIAL_CLOCK_SKEW_SECS',
        'PAIRING_CODE_TTL_MINUTES',
        'PAIRING_MAX_FAILED_ATTEMPTS',
      ],
      '失败或拒绝时的行为': ['PairingCredentialErrorKind', 'PairingCredentialException'],
      '非目标': ['非目标'],
    };

    required.forEach((topic, anchors) {
      for (final anchor in anchors) {
        expect(adr, contains(anchor), reason: 'ADR 0008 缺少「$topic」的表述：$anchor');
      }
    });
  });
}
