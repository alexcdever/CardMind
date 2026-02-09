# 同步服务架构规格
- 相关文档:
  - [同步领域模型](../../domain/sync.md)
  - [池认证与安全](../../features/pool/auth_security.md)
- 测试覆盖:
  - `rust/tests/sync_integration_feature_test.rs`
  - `test/feature/features/p2p_sync_feature_test.dart`

## 概述

同步服务负责池内数据同步与网络会话管理，基于 libp2p 进行节点通信，并在同步前校验 `pool_id` 哈希。

## 关键约束

- 同步仅针对数据池数据
- 同步请求必须携带 `pool_id` 哈希
- 校验失败时拒绝同步并返回原因

## 关键场景

### 场景：同步前校验

- **GIVEN** 请求携带 `pool_id` 哈希
- **WHEN** 发起同步
- **THEN** 哈希匹配才允许同步

### 场景：加入后启动同步

- **GIVEN** 设备加入数据池
- **WHEN** 加入完成
- **THEN** 同步服务立即启动并拉取池元数据与卡片
