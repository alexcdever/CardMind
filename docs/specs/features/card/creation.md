# 卡片创建业务规格
- 相关文档:
  - [卡片领域模型](../../domain/card.md)
  - [单池约束](../pool/single_pool_constraint.md)
  - [卡片存储](../../architecture/storage/card_store.md)
- 测试覆盖:
  - `rust/tests/card_store_feature_test.rs`
  - `test/feature/specs/card_creation_spec_feature_test.dart`

## 概述

本规格定义卡片创建的业务规则：标题与内容必填；未加入数据池时创建本地卡片，已加入数据池时仅允许创建数据池卡片；创建时写入时间戳与 `last_edit_peer`。

## GIVEN-WHEN-THEN 场景

### 场景：未加入数据池时创建本地卡片

- **GIVEN** 调用方未加入任何数据池
- **WHEN** 提交有效标题与内容的创建请求
- **THEN** 系统应创建本地卡片
- **AND** `owner_type = local` 且 `pool_id` 为空
- **AND** `created_at` 与 `updated_at` 设为当前时间戳
- **AND** `last_edit_peer` 设为当前节点 PeerId

### 场景：已加入数据池时创建池内卡片

- **GIVEN** 调用方已加入某个数据池
- **WHEN** 提交有效标题与内容的创建请求
- **THEN** 系统应创建数据池卡片
- **AND** `owner_type = pool` 且 `pool_id` 为当前数据池 ID
- **AND** `created_at` 与 `updated_at` 设为当前时间戳
- **AND** `last_edit_peer` 设为当前节点 PeerId
- **AND** 变更进入同步流程

### 场景：拒绝空标题或空内容创建

- **GIVEN** 标题为空或仅包含空白字符，或内容为空/仅空白
- **WHEN** 提交创建请求
- **THEN** 系统应拒绝创建
- **AND** 返回明确错误原因
