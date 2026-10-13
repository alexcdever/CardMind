import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/lint/markdown_references_linter.dart';

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

/// 取 markdown 中某个二级小节（`## 标题` 起，到下一个二级标题前）的正文。
String _sectionOf(String document, String heading) {
  final start = document.indexOf(heading);
  expect(start, greaterThan(-1), reason: '文档必须保留小节 $heading');
  final rest = document.substring(start + heading.length);
  final end = rest.indexOf('\n## ');
  return end == -1 ? rest : rest.substring(0, end);
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

  test('验收 1（续）：ADR 0008 提到的每个代码符号都真实存在', () {
    final adr = _read(_adr0008Path());

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

  test('验收 2：一次性任务单里的协议契约 / 安全语义 / 设计裁决逐条有归属', () {
    final adr = _read(_adr0008Path());

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

  test('验收 4：UI 规范里的危险操作举例与当前实现相符', () {
    final guide = _read('docs/standards/ui-style-guide.md');

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

  test('验收 5：product.md 的平台范围与 AGENTS.md 现状表一致，更新日期为本次修改', () {
    final product = _read('docs/product.md');
    final agents = _read('AGENTS.md');
    // 「开头的平台范围陈述」：只取文件头部区域，避免正文里的无关提及。
    final header = product.split('\n').take(12).join('\n');

    // 平台范围真相源（2026-10-12 用户拍定）：移动端 = Android + iOS；
    // 桌面端 = Linux + Windows + macOS；设备形态含手机/平板与台式机/笔记本。
    const mobileScope = 'Android + iOS';
    const desktopScope = 'Linux + Windows + macOS';

    expect(
      header,
      contains(mobileScope),
      reason: 'product.md 开头的平台范围必须把移动端写成 $mobileScope',
    );
    expect(
      header,
      contains(desktopScope),
      reason: 'product.md 开头的平台范围必须把桌面端写成 $desktopScope',
    );
    for (final device in <String>['手机', '平板', '台式机', '笔记本']) {
      expect(
        header,
        contains(device),
        reason: 'product.md 开头的平台范围必须写明设备形态（缺「$device」）',
      );
    }

    // 现状表锚点（AGENTS.md「当前状态」表）：目标平台与仓库现状必须分开表述。
    final statusIndex = agents.indexOf('## 当前状态');
    expect(statusIndex, greaterThan(-1), reason: 'AGENTS.md 必须保留「当前状态」小节');
    final platformRows = agents
        .substring(statusIndex)
        .split('\n')
        .where((line) => line.startsWith('| 平台 |'))
        .toList();
    expect(
      platformRows,
      hasLength(1),
      reason: 'AGENTS.md「当前状态」表必须恰有一行「| 平台 |」',
    );
    final platformRow = platformRows.single;

    expect(
      platformRow,
      contains(mobileScope),
      reason: 'AGENTS.md 现状表的平台行与 product.md 不一致：缺 $mobileScope',
    );
    expect(
      platformRow,
      contains(desktopScope),
      reason: 'AGENTS.md 现状表的平台行与 product.md 不一致：缺 $desktopScope',
    );
    expect(
      platformRow,
      contains('目标平台'),
      reason: '现状表的平台行必须显式写出「目标平台」，与仓库现状区分',
    );
    expect(platformRow, contains('工程目录'), reason: '现状表的平台行必须把仓库现状落到「平台工程目录」层面');

    // iOS 属目标平台，但仓库没有 iOS 工程目录：现状必须显式声明「尚未建立」，
    // 既不能声称已支持 iOS，也不能写回「不在支持范围内」。
    expect(
      <String>['尚未建立', '未建立', '尚未创建'].any(platformRow.contains),
      isTrue,
      reason: 'AGENTS.md 现状表必须显式声明 iOS 工程目录尚未建立',
    );

    // 路径引用检查：ios 目录不能作为仓库现有路径出现
    // （字面量拆开写，避免本检查文件自身命中该引用）。
    final iosPathReference = RegExp(
      '`'
      'ios/'
      '`',
    );
    expect(
      iosPathReference.hasMatch(agents),
      isFalse,
      reason: 'AGENTS.md 不得声称仓库存在 iOS 工程目录',
    );

    final declared = RegExp(r'上次更新：(\d{4}-\d{2}-\d{2})').firstMatch(product);
    expect(declared, isNotNull, reason: 'product.md 开头必须有「上次更新：YYYY-MM-DD」');
    final modified =
        (_git(['log', '-1', '--format=%cs', '--', 'docs/product.md']).stdout
                as String)
            .trim();
    expect(modified, isNotEmpty, reason: 'git 必须能给出 product.md 的最近修改日期');
    expect(
      declared!.group(1)!.compareTo(modified) >= 0,
      isTrue,
      reason: '「上次更新」${declared.group(1)} 早于文件最近一次真实修改 $modified',
    );
  });

  test('验收 6：sync-network.md 开头日期不早于该文件内容最近一次修改', () {
    final doc = _read('docs/sync-network.md');
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

    final modified =
        (_git([
                  'log',
                  '-1',
                  '--format=%cs',
                  '--',
                  'docs/sync-network.md',
                ]).stdout
                as String)
            .trim();
    expect(modified, isNotEmpty, reason: 'git 必须能给出 sync-network.md 的最近修改日期');
    expect(
      latest.compareTo(modified) >= 0,
      isTrue,
      reason: '开头声明的日期 $latest 早于该文件内容最近一次真实修改 $modified（日期必须一起改对）',
    );
  });

  test(
    // 直接调用 tool 里的检查实现（`dart run` 在 flutter test 子进程里找不到 dart 可执行文件）。
    '验收 7：markdown 引用检查通过（tool/lint/markdown_references_linter.dart）',
    () async {
      final messages = <String>[];
      final exit = await runMarkdownReferencesLint(
        projectRoot: _repoRoot,
        log: messages.add,
      );
      expect(exit, 0, reason: '仓库自有文档不得引用不存在的对象：\n${messages.join('\n')}');
      expect(
        messages,
        contains('All references are valid!'),
        reason: '检查器通过时会打印 All references are valid!：\n${messages.join('\n')}',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  // ---------------------------------------------------------------------------
  // docs-facts-realign：活文档与代码/现状对齐（AC1–AC6）。
  // ---------------------------------------------------------------------------

  test('AC1：spec-lifecycle 不再把 plan 当作现行文档类型', () {
    final doc = _read('docs/standards/spec-lifecycle.md');

    final title = doc.split('\n').first;
    expect(
      title,
      isNot(contains('plan')),
      reason: '标题不得再把 plan 与 standard 并列声明为现行文档类型',
    );

    expect(
      _sectionOf(doc, '## 目标'),
      isNot(contains('`plan`')),
      reason: '「目标」不得再把 plan 与 standard 并列定义为文档类型',
    );

    final types = _sectionOf(doc, '## 文档类型');
    expect(
      types.split('\n').where((line) => line.trimLeft().startsWith('- `plan`')),
      isEmpty,
      reason: '「文档类型」不得再把 plan 列成现行类型（只能作历史提及）',
    );
    expect(types, contains('`standard`'), reason: '必须保留 standard 类型');

    // plan 类文档的载体目录已整体删除：正文不得再声称它存在。
    expect(
      doc,
      isNot(contains('docs/plans')),
      reason: 'plan 类文档的载体目录已整体删除，文档不得再引用它',
    );

    // 「正式行为文档（唯一真相源）」与更新触发规则的含义不变。
    expect(doc, contains('## 正式行为文档（唯一真相源）'));
    expect(doc, contains('`docs/adr/`'));
    expect(doc, contains('`docs/product.md`'));
    expect(doc, contains('## 正式行为更新触发规则'));
  });

  test('AC2：AGENTS.md 指向 spec-lifecycle 的括注不再声明 plan 类型', () {
    final lines = _read(
      'AGENTS.md',
    ).split('\n').where((line) => line.contains('spec-lifecycle')).toList();
    expect(
      lines,
      hasLength(1),
      reason: 'AGENTS.md 文档地图应恰有一条 spec-lifecycle 引用',
    );
    expect(
      lines.single,
      isNot(contains('plan')),
      reason: '括注不得再写「（plan / standard）」：plan 已不是现行文档类型',
    );
  });
}
