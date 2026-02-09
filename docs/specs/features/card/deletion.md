# 卡片删除业务规格
- 相关文档:
  - [卡片领域模型](../../domain/card.md)
  - [池同步](../pool/sync.md)
- 测试覆盖:
  - `rust/tests/card_store_feature_test.rs`
  - `test/feature/features/card_management_feature_test.dart`

## 概述

本规格定义卡片删除的业务规则：删除采用软删除，需显式确认；数据池卡片的删除变更进入同步流程。

## GIVEN-WHEN-THEN 场景

### 场景：确认后软删除

- **GIVEN** 卡片存在且未被删除
- **WHEN** 提交带删除确认的请求
- **THEN** 系统将卡片标记为 `deleted = true`
- **AND** `updated_at` 更新为当前时间戳
- **AND** `last_edit_peer` 更新为当前节点 PeerId
- **AND** 若卡片归属数据池，则变更进入同步流程

### 场景：未确认则不删除

- **GIVEN** 卡片存在且未被删除
- **WHEN** 提交未包含确认标记的删除请求
- **THEN** 系统不应更改卡片状态
