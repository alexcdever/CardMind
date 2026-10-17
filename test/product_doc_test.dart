import 'package:flutter_test/flutter_test.dart';

import 'support/doc_helpers.dart';

void main() {
  test('product.md 平台范围与 AGENTS.md 现状表一致且日期不早于最近修改', () {
    final product = readRepoFile('docs/product.md');
    final agents = readRepoFile('AGENTS.md');
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
    // 日期真相源：有未提交改动时以「今天」为准（改动就在工作区），
    // 否则退化为 git log 的最后提交日期——见 expectedDocDate。
    final expected = expectedDocDate('docs/product.md');
    expect(expected, isNotEmpty, reason: '必须能判定 product.md 的最近修改日期');
    final declaredDate = declared!.group(1)!;
    if (docHasUncommittedChange('docs/product.md')) {
      expect(
        declaredDate,
        expected,
        reason:
            'docs/product.md 有未提交改动，「上次更新」必须改成当天日期 $expected，'
            '实际 $declaredDate（改了文档不改日期会在提交后才被发现）',
      );
    } else {
      expect(
        declaredDate.compareTo(expected) >= 0,
        isTrue,
        reason: '「上次更新」$declaredDate 早于文件最近一次真实修改 $expected',
      );
    }
  });

  test('ADR 0003 的「现状核对」不再使用旧平台口径', () {
    final adr = readRepoFile('docs/adr/0003-product-truth-source-spec.md');
    final section = sectionOf(adr, '### 现状核对（2026-10）');

    // 旧的收窄口径（Android / Windows / macOS 混用）只能作废，不得再作为现行平台范围。
    expect(
      section,
      isNot(contains('Android / Windows / macOS')),
      reason: '「现状核对」不得再写「Android / Windows / macOS」这一已作废的平台口径',
    );

    // 现行口径必须与 product.md / product-decisions.md 一致。
    const mobileScope = 'Android + iOS';
    const desktopScope = 'Linux + Windows + macOS';
    expect(
      section,
      contains(mobileScope),
      reason: '「现状核对」必须写出移动端现行范围 $mobileScope',
    );
    expect(
      section,
      contains(desktopScope),
      reason: '「现状核对」必须写出桌面端现行范围 $desktopScope',
    );

    final productHeader = readRepoFile(
      'docs/product.md',
    ).split('\n').take(12).join('\n');
    expect(
      productHeader,
      contains(mobileScope),
      reason: '对照基线：product.md 开头必须写明移动端 $mobileScope',
    );
    expect(
      productHeader,
      contains(desktopScope),
      reason: '对照基线：product.md 开头必须写明桌面端 $desktopScope',
    );
  });
}
