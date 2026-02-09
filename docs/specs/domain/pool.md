# 数据池领域模型规格
- 相关文档:
  - [卡片领域模型](card.md)
  - [同步领域模型](sync.md)
  - [通用类型](types.md)
  - [池存储](../architecture/storage/pool_store.md)
- 测试覆盖:
  - `rust/tests/pool_model_feature_test.rs`
  - `test/feature/features/pool_management_feature_test.dart`

## 概述

本规格定义数据池（Pool）领域实体与核心约束。数据池元数据以 Loro 文件存储并在池内同步。

## 数据结构

- `pool_id`: UUID v7
- `name`: 字符串（必填）
- `secretkey`: 字符串（必填，明文保存）
- `created_at`: Unix 毫秒时间戳
- `updated_at`: Unix 毫秒时间戳
- `card_ids`: UUID v7 列表（仅数据池卡片，集合语义，仅增不减，包含已删除）
- `nodes`: 成员列表
  - `peer_id`: libp2p PeerId
  - `nickname`: 非空字符串
  - `device_os`: 字符串
  - `joined_at`: Unix 毫秒时间戳

## 规则与约束

- `pool_id` 必须为 UUID v7
- `name` 与 `secretkey` 均为必填且非空
- `secretkey` 明文存储，哈希按需计算
- `card_ids` 仅记录数据池卡片，且去重为集合
- `card_ids` 仅追加，不删除；软删除卡片仍保留 ID
- `nodes` 列表不含在线状态，仅记录成员
- `nickname` 必填且可由节点本人修改，不要求唯一
- 默认昵称为 `peer_id` 前五位拼接 `device_os`
- 成员离开后从 `nodes` 列表移除
- 每个 App 最多加入一个数据池

## 行为

- **加入**: 校验通过后写入成员记录并同步池元数据
- **默认昵称**: 加入时为节点生成默认昵称
- **迁移**: 加入后自动迁移本地卡片为数据池卡片（保留卡片 ID）
- **退出**: 删除本地数据池卡片与池元数据，不恢复为本地卡片

## 关键场景

### 场景：加入后自动迁移本地卡片

- **GIVEN** 设备加入数据池且本地存在卡片
- **WHEN** 加入流程完成
- **THEN** 本地卡片转换为数据池卡片并保留原 ID

### 场景：退出后清理数据池数据

- **GIVEN** 设备已加入数据池
- **WHEN** 执行退出
- **THEN** 本地数据池卡片与池元数据被删除
