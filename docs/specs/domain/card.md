# 卡片领域模型规格
- 相关文档:
  - [池模型](pool.md)
  - [同步模型](sync.md)
  - [通用类型](types.md)
  - [卡片存储](../architecture/storage/card_store.md)
  - [Loro 集成](../architecture/storage/loro_integration.md)
- 测试覆盖:
  - `rust/tests/common_types_feature_test.rs`
  - `test/unit/providers/card_provider_unit_test.dart`

## 概述

本规格定义 Card 领域实体，用于描述单个卡片的核心属性与业务规则。卡片以 Markdown 纯文本存储内容，支持软删除与归属（本地/数据池）。

## 数据结构

- `id`: UUID v7
- `title`: 字符串
- `content`: Markdown 纯文本字符串
- `created_at`: Unix 毫秒时间戳
- `updated_at`: Unix 毫秒时间戳
- `deleted`: 布尔值，默认 `false`
- `owner_type`: `local | pool`
- `pool_id`: UUID v7（仅当 `owner_type = pool` 时必填）
- `last_edit_peer`: 最后编辑节点的 libp2p PeerId（必填）

## 规则与约束

- `title` 不能为空，长度 ≤ 200 字符
- `content` 不能为空，必须包含至少一个非空白字符
- `created_at`、`updated_at` 必须为正整数，且 `updated_at >= created_at`
- `owner_type = pool` 时必须提供 `pool_id`
- `owner_type = local` 时 `pool_id` 必须为空
- `last_edit_peer` 在创建与更新时必须写入当前节点 PeerId
- `id` 必须为有效 UUID v7

## 行为

- **创建**: 生成 `id`，初始化 `created_at/updated_at`，`deleted = false`，写入 `owner_type/pool_id`，并记录 `last_edit_peer`
- **更新**: 修改 `title/content` 时，更新 `updated_at` 与 `last_edit_peer`
- **软删除**: 将 `deleted` 设为 `true`，并更新 `updated_at` 与 `last_edit_peer`

## 关键场景

### 场景：UUID v7 按创建时间有序

- **GIVEN** 顺序创建两张卡片
- **WHEN** 卡片 A 在卡片 B 之前创建
- **THEN** 卡片 A 的 `id` 在字典序上小于卡片 B

### 场景：软删除保留数据

- **GIVEN** 卡片存在且未删除
- **WHEN** 执行软删除
- **THEN** `deleted` 设为 `true`
- **AND** 卡片数据应保留
