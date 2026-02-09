# 池同步规格
- 相关文档:
  - [同步领域模型](../../domain/sync.md)
  - [池认证与安全](auth_security.md)
  - [双层存储](../../architecture/storage/dual_layer.md)
- 测试覆盖:
  - `rust/tests/sync_feature_test.rs`
  - `test/feature/features/p2p_sync_feature_test.dart`

## 概述

定义池内同步的业务规则：加入池后立即同步；同步请求仅校验 `pool_id` 哈希；同步包含池元数据与池内卡片；冲突由 CRDT 自动合并。

## GIVEN-WHEN-THEN 场景

### 场景：加入后自动启动同步

- **GIVEN** 设备成功加入某个池
- **WHEN** 加入流程完成
- **THEN** 同步服务立即启动并拉取池元数据与卡片

### 场景：同步请求校验

- **GIVEN** 请求携带 `pool_id` 哈希
- **WHEN** 发起同步
- **THEN** 仅当哈希匹配时允许同步

### 场景：并发变更自动合并

- **GIVEN** 多设备对同一数据产生并发变更
- **WHEN** 同步发生冲突
- **THEN** 系统使用 CRDT 自动合并并收敛到一致结果
