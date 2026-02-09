# 卡片存储架构规格
- 相关文档:
  - [卡片领域模型](../../domain/card.md)
  - [双层存储](dual_layer.md)
- 测试覆盖:
  - `rust/tests/card_store_feature_test.rs`
  - `test/unit/providers/card_provider_unit_test.dart`

## 概述

CardStore 负责卡片的写入与读取：写入落到 Loro 文档，读取来自 SQLite 缓存。每张卡片对应一个独立 Loro 文件。

## 关键约束

- 卡片 Loro 文件路径：`data/loro/<base64(uuid)>/`
- 写入流程必须先更新 Loro，再通过订阅更新 SQLite
- 卡片字段包含 `owner_type`、`pool_id` 与 `last_edit_peer`

## 关键场景

### 场景：创建卡片写入 Loro

- **GIVEN** 提交卡片创建请求
- **WHEN** 写入 Loro 文档并 `commit()`
- **THEN** SQLite 缓存收到订阅更新

### 场景：软删除同步到缓存

- **GIVEN** 卡片被标记为删除
- **WHEN** `commit()` 触发订阅
- **THEN** SQLite 中该卡片 `deleted = true`
