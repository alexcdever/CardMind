// input: 读取主流程页面、控制器与 API client 源码文本，检查是否仍依赖旧写入主路径或 store handle 组合。
// output: 断言生产路径不再直接引用 Flutter 侧写真源，也不再暴露 storeId/initCardStore 组合。
// pos: 覆盖前端不再作为写真源且不再泄露 handle 的架构约束，防止主流程回退。修改本文件需同步更新文件头与所属 DIR.md。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _readSource(String path) => File(path).readAsStringSync();

void expectSourceOmits(
  String source,
  String token, {
  required String fileLabel,
  required String violationLabel,
}) {
  expect(
    source.contains(token),
    isFalse,
    reason:
        '$fileLabel must not $violationLabel token `$token` in production path.',
  );
}

void expectNoHandleLeak(
  String source,
  String token, {
  required String fileLabel,
}) {
  expectSourceOmits(
    source,
    token,
    fileLabel: fileLabel,
    violationLabel: 'leak store handle',
  );
}

void main() {
  test('main page flows should not depend on flutter-side business write source', () {
    final cardsPage = _readSource('lib/features/cards/cards_page.dart');
    final cardsController = _readSource(
      'lib/features/cards/cards_controller.dart',
    );
    final poolPage = _readSource('lib/features/pool/pool_page.dart');
    final poolController = _readSource(
      'lib/features/pool/pool_controller.dart',
    );
    final legacyCardClient = _readSource(
      'lib/features/cards/card_api_client.dart',
    );

    expect(
      cardsPage.contains('CardsCommandService'),
      isFalse,
      reason: 'CardsPage production path must not depend on command service.',
    );
    expect(
      cardsPage.contains('writeRepository:'),
      isFalse,
      reason:
          'CardsPage production path must not wire a Flutter write repository.',
    );
    expect(
      cardsController.contains('CardsWriteRepository'),
      isFalse,
      reason:
          'CardsController production path must not depend on Flutter write repositories.',
    );
    expect(
      poolPage.contains('PoolCommandService'),
      isFalse,
      reason: 'PoolPage production path must not depend on command service.',
    );
    expect(
      poolPage.contains('PoolWriteRepository'),
      isFalse,
      reason:
          'PoolPage production path must not wire a Flutter write repository.',
    );
    expect(
      poolController.contains('PoolWriteRepository'),
      isFalse,
      reason:
          'PoolController production path must not depend on Flutter write repositories.',
    );
    expect(
      cardsPage.contains('LegacyCardApiClient'),
      isFalse,
      reason:
          'CardsPage production composition must not instantiate LegacyCardApiClient.',
    );
    expect(
      poolPage.contains('LocalPoolApiClient'),
      isFalse,
      reason:
          'PoolPage production composition must not instantiate LocalPoolApiClient.',
    );
    expect(
      legacyCardClient.contains('短期兼容路径'),
      isTrue,
      reason:
          'Legacy compatibility code must stay clearly labeled until removed.',
    );
    expect(
      legacyCardClient.contains('后续将由 FRB 客户端替换并删除'),
      isTrue,
      reason:
          'Legacy compatibility code must keep its removal intent documented.',
    );
  });

  test(
    'production sources should not depend on storeId handle composition',
    () {
      final cardsPage = _readSource('lib/features/cards/cards_page.dart');
      final poolPage = _readSource('lib/features/pool/pool_page.dart');
      final cardApiClient = _readSource(
        'lib/features/cards/card_api_client.dart',
      );
      final poolApiClient = _readSource(
        'lib/features/pool/pool_api_client.dart',
      );

      expectNoHandleLeak(cardsPage, 'storeId', fileLabel: 'CardsPage');
      expectNoHandleLeak(poolPage, 'storeId', fileLabel: 'PoolPage');
      expectNoHandleLeak(
        cardApiClient,
        'initCardStore',
        fileLabel: 'FrbCardApiClient',
      );
      expectNoHandleLeak(
        poolApiClient,
        'storeId',
        fileLabel: 'FrbPoolApiClient',
      );
    },
  );

  test(
    'production pages and controllers should not wire local sqlite query dependencies',
    () {
      final cardsPage = _readSource('lib/features/cards/cards_page.dart');
      final poolPage = _readSource('lib/features/pool/pool_page.dart');
      final cardsController = _readSource(
        'lib/features/cards/cards_controller.dart',
      );
      final poolController = _readSource(
        'lib/features/pool/pool_controller.dart',
      );

      expectSourceOmits(
        cardsPage,
        'AppDatabase(',
        fileLabel: 'CardsPage',
        violationLabel: 'wire local sqlite query dependency',
      );
      expectSourceOmits(
        cardsPage,
        'SqliteCardsReadRepository',
        fileLabel: 'CardsPage',
        violationLabel: 'wire local sqlite query dependency',
      );
      expectSourceOmits(
        poolPage,
        'SqlitePoolReadRepository',
        fileLabel: 'PoolPage',
        violationLabel: 'wire local sqlite query dependency',
      );
      expectSourceOmits(
        cardsController,
        'CardsReadRepository',
        fileLabel: 'CardsController',
        violationLabel: 'depend on flutter-local query repository',
      );
      expectSourceOmits(
        poolController,
        'PoolReadRepository',
        fileLabel: 'PoolController',
        violationLabel: 'depend on flutter-local query repository',
      );
    },
  );
}
