# DeviceConfig 存储架构规格
- 相关文档:
  - [数据池领域模型](../../domain/pool.md)
  - [同步服务](../sync/service.md)
- 测试覆盖:
  - `rust/tests/device_config_feature_test.rs`
  - `test/unit/providers/device_manager_provider_unit_test.dart`

## 概述

DeviceConfig 用于持久化本地设备身份与当前池状态，确保重启后保持一致。核心字段为 `peer_id` 与可选 `pool_id`。

## 关键约束

- `peer_id` 在首次启动生成并持久化，后续保持不变
- `pool_id` 可选，加入池时写入，退出池时清空
- 配置变更需立即持久化到本地

## 关键场景

### 场景：首次启动创建配置

- **GIVEN** 本地无配置文件
- **WHEN** 应用启动
- **THEN** 生成并持久化 `peer_id`，`pool_id = None`

### 场景：加入与退出更新配置

- **GIVEN** 设备加入或退出数据池
- **WHEN** 更新配置
- **THEN** `pool_id` 被设置或清空并持久化
