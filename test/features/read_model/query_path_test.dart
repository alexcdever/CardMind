// input: 读取生产页面、控制器与 FRB client 源码文本，检查查询主路径是否仍回退到 Flutter 本地查询装配。
// output: 断言 Flutter 刷新只通过 FRB -> Rust Query API，不再直接接线 AppDatabase 或 SQLite 读仓。
// pos: 覆盖主路径查询边界，防止生产代码重新依赖 Flutter 本地 SQLite 查询。修改本文件需同步更新文件头与所属 DIR.md。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _readSource(String path) => File(path).readAsStringSync();

Map<String, String> _productionSources() {
  return <String, String>{
    'CardsPage': _readSource('lib/features/cards/cards_page.dart'),
    'PoolPage': _readSource('lib/features/pool/pool_page.dart'),
    'CardsController': _readSource('lib/features/cards/cards_controller.dart'),
    'PoolController': _readSource('lib/features/pool/pool_controller.dart'),
  };
}

void expectNoLocalQueryWiring(
  String source,
  String token, {
  required String fileLabel,
}) {
  expect(
    source.contains(token),
    isFalse,
    reason:
        '$fileLabel must not wire Flutter-local query dependency token `$token` into the production refresh path.',
  );
}

void main() {
  test(
    'cards controller refresh should depend on api client query methods',
    () {
      final sources = _productionSources();
      final cardsController = sources['CardsController']!;
      final cardApiClient = _readSource(
        'lib/features/cards/card_api_client.dart',
      );

      expect(cardsController.contains('_apiClient.listCardSummaries('), isTrue);
      expect(cardsController.contains('_readRepository.search('), isFalse);
      expect(
        cardApiClient.contains('Future<List<CardSummary>> listCardSummaries('),
        isTrue,
      );
      expect(cardApiClient.contains('frb.queryCardNotes('), isTrue);
      expect(cardApiClient.contains('frb.listCardNotes('), isFalse);
      expect(cardApiClient.contains('.where((note)'), isFalse);
      expect(cardApiClient.contains('includeDeleted && note.deleted'), isFalse);
    },
  );

  test(
    'flutter production query path should not directly wire local sqlite read dependencies',
    () {
      final sources = _productionSources();

      expectNoLocalQueryWiring(
        sources['CardsPage']!,
        'AppDatabase(',
        fileLabel: 'CardsPage',
      );
      expectNoLocalQueryWiring(
        sources['CardsPage']!,
        'SqliteCardsReadRepository',
        fileLabel: 'CardsPage',
      );
      expectNoLocalQueryWiring(
        sources['PoolPage']!,
        'SqlitePoolReadRepository',
        fileLabel: 'PoolPage',
      );
      expectNoLocalQueryWiring(
        sources['CardsController']!,
        'CardsReadRepository',
        fileLabel: 'CardsController',
      );
      expectNoLocalQueryWiring(
        sources['PoolController']!,
        'PoolReadRepository',
        fileLabel: 'PoolController',
      );
    },
  );
}
