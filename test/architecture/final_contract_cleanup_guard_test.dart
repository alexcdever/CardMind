// input: 读取最终契约收尾相关生产源码文本，检查 pool caller-scoped 与 card query 默认语义是否回退。
// output: 断言不得回退为 first-member 角色推断、lookup miss 伪造 member，且 Flutter 不得重新引入 deleted 语义开关。
// pos: 覆盖 flutter/rust 最终契约收尾的源码守卫测试。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:flutter_test/flutter_test.dart';

import '../support/source_guard.dart';

void main() {
  test('pool role contracts must not fall back to first-member ordering', () {
    final rustApi = readSource('rust/src/api.rs');

    expectSourceContains(
      rustApi,
      'ApiErrorCode::NotMember',
      fileLabel: 'rust/src/api.rs',
      requirementLabel:
          'return stable not-member error for caller-scoped lookup miss',
    );
    expectSourceOmits(
      rustApi,
      'unwrap_or_else(|| "member".to_string())',
      fileLabel: 'rust/src/api.rs',
      violationLabel: 'fall back to fabricated member role on lookup miss',
    );
    expectSourceOmits(
      rustApi,
      'to_pool_detail_dto(&pool, fallback_endpoint_id(&pool))',
      fileLabel: 'rust/src/api.rs',
      violationLabel: 'compute pool detail role from first member ordering',
    );
    expectSourceOmits(
      rustApi,
      'to_pool_dto(pool, fallback_endpoint_id(pool))',
      fileLabel: 'rust/src/api.rs',
      violationLabel: 'compute pool list role from first member ordering',
    );
  });

  test('flutter must not reintroduce includeDeleted query switches', () {
    final cardApiClient = readSource('lib/features/cards/card_api_client.dart');
    final cardsController = readSource(
      'lib/features/cards/cards_controller.dart',
    );

    expectSourceContains(
      cardApiClient,
      'frb.queryCardNotes(query: query, poolId: poolId, includeDeleted: false)',
      fileLabel: 'FrbCardApiClient',
      requirementLabel:
          'call rust query api with poolId but without exposing deleted policy to flutter',
    );
    expectSourceOmits(
      cardApiClient,
      'bool includeDeleted',
      fileLabel: 'FrbCardApiClient',
      violationLabel:
          'reintroduce deleted-policy parameter into production api surface',
    );
    expectSourceOmits(
      cardApiClient,
      'frb.queryCardNotes(query: query, includeDeleted: false)',
      fileLabel: 'FrbCardApiClient',
      violationLabel:
          'hard-code deleted policy flag in production rust query call',
    );
    expectSourceOmits(
      cardsController,
      'includeDeleted:',
      fileLabel: 'CardsController',
      violationLabel: 'pass deleted-policy flag from flutter controller',
    );
  });
}
