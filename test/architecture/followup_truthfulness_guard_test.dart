// input: 读取 truthfulness follow-up 相关生产源码文本，检查身份、save、query、sync 恢复主路径是否回退。
// output: 断言 Flutter 不再推断身份、不再本地过滤 query、不再把 existing save 走 create，也不再让 sync 恢复停留在本地状态切换。
// pos: 覆盖 follow-up 真相修补的源码守卫测试，防止错误实现回流。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:flutter_test/flutter_test.dart';
import '../support/source_guard.dart';

void main() {
  test('frontend must not infer joined pool role from member ordering', () {
    final poolApiClient = readSource('lib/features/pool/pool_api_client.dart');
    final rustApi = readSource('rust/src/api.rs');

    expectSourceContains(
      poolApiClient,
      'frb.getJoinedPoolView(',
      fileLabel: 'FrbPoolApiClient',
      requirementLabel: 'consume backend current-user pool view',
    );
    expectSourceOmits(
      rustApi,
      'members.first()\n        .map(member_role)',
      fileLabel: 'rust/src/api.rs',
      violationLabel: 'derive current role from member ordering',
    );
  });

  test('save path must not route existing card saves through create', () {
    final cardsController = readSource(
      'lib/features/cards/cards_controller.dart',
    );
    final cardsPage = readSource('lib/features/cards/cards_page.dart');

    expectSourceContains(
      cardsController,
      '_apiClient.updateCardNote(',
      fileLabel: 'CardsController',
      requirementLabel: 'route existing save through update api',
    );
    expectSourceContains(
      cardsPage,
      '_effectiveController.save(',
      fileLabel: 'CardsPage',
      requirementLabel: 'use unified save entry for existing desktop session',
    );
    expectSourceOmits(
      cardsPage,
      'session.selectedId ?? generateNoteId()',
      fileLabel: 'CardsPage',
      violationLabel: 'collapse existing save into create path',
    );
  });

  test('sync recovery actions must not be local-only state mutations', () {
    final poolController = readSource('lib/features/pool/pool_controller.dart');
    final poolPage = readSource('lib/features/pool/pool_page.dart');
    final appPage = readSource('lib/app/navigation/app_homepage_page.dart');

    expectSourceContains(
      poolController,
      'service.retry()',
      fileLabel: 'PoolController',
      requirementLabel: 'delegate retry to backend sync service',
    );
    expectSourceContains(
      poolController,
      'service.reconnect(_reconnectTarget)',
      fileLabel: 'PoolController',
      requirementLabel: 'delegate reconnect to backend sync service',
    );
    expectSourceContains(
      poolPage,
      'syncService: widget.networkId == null',
      fileLabel: 'PoolPage',
      requirementLabel: 'wire production sync recovery through backend service',
    );
    expectSourceContains(
      poolPage,
      'SyncService(',
      fileLabel: 'PoolPage',
      requirementLabel:
          'construct backend sync service for production recovery path',
    );
    expectSourceContains(
      appPage,
      'networkId:',
      fileLabel: 'AppHomepagePage',
      requirementLabel: 'pass pool network id into production pool page',
    );
    expectSourceOmits(
      poolController,
      '_syncStatus = const SyncStatus.connected();',
      fileLabel: 'PoolController',
      violationLabel: 'pretend retry succeeded locally',
    );
  });

  test('card query semantics must stay in rust query api', () {
    final cardApiClient = readSource('lib/features/cards/card_api_client.dart');

    expectSourceContains(
      cardApiClient,
      'frb.queryCardNotes(',
      fileLabel: 'FrbCardApiClient',
      requirementLabel: 'query via rust backend api',
    );
    expectSourceOmits(
      cardApiClient,
      'frb.listCardNotes(',
      fileLabel: 'FrbCardApiClient',
      violationLabel: 'query by listing everything then filtering locally',
    );
    expectSourceOmits(
      cardApiClient,
      '.where((note)',
      fileLabel: 'FrbCardApiClient',
      violationLabel: 'apply product query filtering in dart',
    );
  });
}
