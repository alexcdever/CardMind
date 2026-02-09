# 通用类型系统规格
- 相关文档:
  - [卡片领域模型](card.md)
  - [数据池领域模型](pool.md)
- 测试覆盖:
  - `rust/tests/common_types_feature_test.rs`
  - `test/unit/utils/time_formatter_unit_test.dart`

## 概述

本规格定义系统内通用类型与约束，确保跨层数据一致性。

## 类型定义

- `UUIDv7`: 全局唯一标识，按时间排序
- `TimestampMs`: Unix 毫秒时间戳（UTC）
- `Hash256Hex`: SHA-256 十六进制字符串（64 字符）
- `PeerId`: libp2p PeerId 字符串
- `OwnerType`: `local | pool`

## 约束

- `UUIDv7` 必须为有效 UUID v7 格式
- `TimestampMs` 为非负整数，且 `updated_at >= created_at`
- `Hash256Hex` 长度为 64，字符集为 `[0-9a-f]`
- `PeerId` 为 libp2p 标准文本格式
- `OwnerType = pool` 时必须提供 `pool_id`

## 关键场景

### 场景：UUID v7 按时间排序

- **GIVEN** 顺序生成多个 UUID v7
- **WHEN** 按生成顺序比较
- **THEN** UUID 字典序应与时间顺序一致
