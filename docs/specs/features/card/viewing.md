# 卡片查看业务规格
- 相关文档:
  - [卡片领域模型](../../domain/card.md)
  - [SQLite 缓存](../../architecture/storage/sqlite_cache.md)
- 测试覆盖:
  - `rust/tests/sqlite_feature_test.rs`
  - `test/feature/screens/card_detail_screen_feature_test.dart`

## 概述

本规格定义卡片查看的业务规则。查看结果需包含标题、内容、时间戳、归属信息与 `last_edit_peer`（最后编辑节点 PeerId）。

## GIVEN-WHEN-THEN 场景

### 场景：查看卡片基础信息

- **GIVEN** 存在一张卡片
- **WHEN** 请求该卡片详情
- **THEN** 系统应返回标题与内容
- **AND** 返回 `created_at` 与 `updated_at`
- **AND** 返回 `owner_type` 与 `pool_id`（若为数据池卡片）
- **AND** 返回 `last_edit_peer`
