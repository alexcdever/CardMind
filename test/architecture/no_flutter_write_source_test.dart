// input: 读取主流程页面与控制器源码文本，检查是否仍直接依赖 Flutter 侧写真源实现。
// output: 断言主页面流不再直接引用旧写仓/命令服务，并要求遗留兼容路径带有明确中文标注。
// pos: 覆盖前端不再作为写真源的架构约束，防止主流程回退。修改本文件需同步更新文件头与所属 DIR.md。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'main page flows should not depend on flutter-side business write source',
    () {
      final cardsPage = File(
        'lib/features/cards/cards_page.dart',
      ).readAsStringSync();
      final cardsController = File(
        'lib/features/cards/cards_controller.dart',
      ).readAsStringSync();
      final poolPage = File(
        'lib/features/pool/pool_page.dart',
      ).readAsStringSync();
      final poolController = File(
        'lib/features/pool/pool_controller.dart',
      ).readAsStringSync();
      final legacyCardClient = File(
        'lib/features/cards/card_api_client.dart',
      ).readAsStringSync();

      expect(cardsPage.contains('CardsCommandService'), isFalse);
      expect(cardsPage.contains('writeRepository:'), isFalse);
      expect(cardsController.contains('CardsWriteRepository'), isFalse);
      expect(poolPage.contains('PoolCommandService'), isFalse);
      expect(poolPage.contains('PoolWriteRepository'), isFalse);
      expect(poolController.contains('PoolWriteRepository'), isFalse);
      expect(legacyCardClient.contains('短期兼容路径'), isTrue);
      expect(legacyCardClient.contains('后续将由 FRB 客户端替换并删除'), isTrue);
    },
  );
}
