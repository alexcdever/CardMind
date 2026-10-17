import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/doc_helpers.dart';

void main() {
  test('ADR 0008 存在，且覆盖协议必备内容', () {
    final adr = readRepoFile(adr0008Path());

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

  test('ADR 0008 提到的每个代码符号都真实存在', () {
    final adr = readRepoFile(adr0008Path());

    // 反引号里的裸标识符（可带 `()`）视为「ADR 提到的代码符号」；
    // 带 `/` 的路径引用由 markdown 引用检查负责，不在此列。
    final identifiers = RegExp(
      r'`([A-Za-z_][A-Za-z0-9_]*)(?:\(\))?`',
    ).allMatches(adr).map((match) => match.group(1)!).toSet();
    expect(
      identifiers.length,
      greaterThan(20),
      reason: 'ADR 必须实实在在引用代码符号，而不是只写自然语言',
    );

    final source = ['rust-backend/src', 'lib']
        .expand(
          (dir) => Directory(dir).listSync(recursive: true).whereType<File>(),
        )
        .where(
          (file) => file.path.endsWith('.rs') || file.path.endsWith('.dart'),
        )
        .map((file) => file.readAsStringSync())
        .join('\n');

    final missing = identifiers.where((id) => !source.contains(id)).toList()
      ..sort();
    expect(
      missing,
      isEmpty,
      reason: 'ADR 0008 提到的符号在 rust-backend/src 或 lib/ 里找不到（写了没实现的东西）：$missing',
    );
  });

  test('一次性任务单里的协议契约 / 安全语义 / 设计裁决逐条有归属', () {
    final adr = readRepoFile(adr0008Path());

    // 被判为「已废弃 / 非目标」的条目，必须落在「非目标」小节里。
    final retiredIndex = adr.indexOf('## 非目标');
    expect(retiredIndex, greaterThan(-1), reason: 'ADR 必须显式给出「非目标」小节');
    final retiredSection = adr.substring(retiredIndex);

    // 条目 → 该条目在新 ADR 里必须出现的表述（协议符号或关键约束）。
    const covered = <String, List<String>>{
      'Q-契约：canonical payload 字段与编码': [
        'CREDENTIAL_MAGIC',
        'CREDENTIAL_VERSION_V1',
        'issued_at',
        'pairing_code',
        '大端',
      ],
      'Q-契约：长度精确、拒绝尾随数据': ['CREDENTIAL_FINAL_LEN', 'trailing bytes'],
      'Q-契约：签名方式与验签来源': ['CREDENTIAL_SIGNATURE_LEN', 'SecretKey', 'PublicKey'],
      'Q-契约：字符串形态与二维码逐字一致': ['CREDENTIAL_PREFIX', '逐字相同'],
      'Q-安全语义：nonce 必须与会话一致，错误 nonce 计入失败次数': [
        'PairingSession',
        'PAIRING_MAX_FAILED_ATTEMPTS',
      ],
      'Q-安全语义：配对成功后会话清空、凭证单次使用': ['confirm_pairing_inner', '一次性使用'],
      'Q-安全语义：重新生成产生新 code + 新 nonce，旧凭证失效': [
        'begin_pairing_credential',
        'pending_pairing',
      ],
      'Q-安全语义：私钥 / 凭证 / code / nonce / 完整 ID 不入日志': [
        'redact_device_id',
        'mdns_skipped',
      ],
      'Q-API：复用 endpoint SecretKey，不另建长期配对密钥': ['secret_key', 'local_addrs'],
      'Q-API：凭证入口内部完成 parse/verify/target，空 ips 沿用 build_connect_addr': [
        'begin_pairing_connect_with_credential',
        'pairing_target_for_credential',
        'build_connect_addr',
      ],
      'Q-API：旧 6 位码 API 保留、组合 API 原子进入同一会话': [
        'begin_pairing_credential_with_advertising',
        'stop_pairing_advertising',
      ],
      'Q-API：凭证路径把 nonce 带入请求；mDNS TXT 携带 nonce': [
        'PairingRequest',
        'device_id',
        'nonce',
      ],
      'Q-UI：显示方二维码 / 6 位码 / 复制 / 倒计时 / 重新生成，且不显示 ID / nonce / 签名 / relay': [
        '_PairingAcceptDialog',
        'QrPainter',
        'qr_flutter',
      ],
      'Q-UI：发起方单一输入、扫码回填同一解析、桌面隐藏扫码': ['ScannerService', 'mobile_scanner'],
      'Q-UI：错误文案至少区分五类且不暴露裸异常': [
        'PairingCredentialException',
        'invalidFormat',
        'expired',
        'unreachable',
      ],
      'Q-API：解析结果字段（6 位码 / 节点 ID / 过期时间 / nonce / 内嵌地址）': [
        'ParsedPairingCredential',
        'base32',
      ],
      'Q-依赖与权限：成熟二维码 / 扫码包 + Android 最小 CAMERA 权限 + 不加遥测 / 云扫码 / 第三方服务': [
        'mobile_scanner',
        'CAMERA',
        '遥测',
      ],
      'Q2-裁决：空 / 全零 / 格式错误 / 不匹配的 nonce 一律拒绝，禁止兼容后门': ['空串', '全零', '格式错误'],
      'Q2-裁决：保留 6 位码路径 = 当前 mDNS 流程，不是旧二进制兼容': ['跨版本'],
      'Q2/Q3-裁决：显示方生命周期（先生成凭证再单 loop accept、不用旧 code confirm、关闭后不 setState）': [
        'accept_pairing_request_with_timeout',
        '_runAcceptRounds',
        '_acceptFuture',
      ],
      'Q3-裁决：发起方唯一主输入、无节点 ID 控件、凭证禁止 mDNS、6 位码才 discoverPeers': [
        'pair-credential-input',
        'discover_peers',
        'PairingTarget',
      ],
      'Q3-裁决：显示方文案方向「扫描此二维码」': ['扫描此二维码'],
      'S-裁决：discovery 的 nonce 是协议前置产物（PeerInfo / 广播携带 nonce）': [
        'PeerInfo',
        'nonce_to_hex',
      ],
      'S-裁决：离线 FRB 测试以凭证身份材料 + localAddrs 直连（测试编排）': ['local_addrs'],
    };

    covered.forEach((item, anchors) {
      for (final anchor in anchors) {
        expect(
          adr,
          contains(anchor),
          reason: '任务单条目「$item」在新 ADR 里既没有对应表述，也没被标成非目标：缺 $anchor',
        );
      }
    });

    // 被判为已废弃 / 非目标 / 一次性流程的条目：必须在「非目标」小节里点名。
    const retired = <String, List<String>>{
      '兼容空 nonce / 全零 nonce 的后门': ['空 nonce'],
      '与旧二进制客户端跨版本配对': ['跨版本'],
      '任务单的测试清单 / 报告门禁 / codegen 幂等 / 平台验收等一次性流程要求': ['一次性流程要求', 'codegen'],
      '测试编排细节（离线直连手法）': ['测试编排'],
      'public relay 写进凭证或默认发布配置': ['public relay'],
      '服务器侧 rendezvous / 云配对服务': ['rendezvous'],
      '双向确认与额外中间人防护': ['双向确认'],
      '为配对做数据库 schema 迁移': ['schema'],
    };

    retired.forEach((item, anchors) {
      for (final anchor in anchors) {
        expect(
          retiredSection,
          contains(anchor),
          reason: '条目「$item」必须在 ADR 的「非目标」小节里明确标注：缺 $anchor',
        );
      }
    });
  });
}
