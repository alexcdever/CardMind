# secretkey 管理架构规格（临时方案）
- 相关文档:
  - [数据池领域模型](../../domain/pool.md)
  - [池加入](../../features/pool/joining.md)
  - [池同步](../../features/pool/sync.md)
- 测试覆盖:
  - `rust/tests/security_password_feature_test.rs`
  - 暂无（Flutter）

## 概述

当前阶段仅定义最小可用的 secretkey 处理规则。secretkey 明文保存在数据池元数据中；加入时校验 secretkey 哈希，同步时仅校验 pool_id 哈希。

## 规则与约束

- 哈希算法：SHA-256 + 十六进制编码
- secretkey 必须非空
- secretkey 明文保存在池元数据并同步到所有节点
- 不提供强度校验、重放防护、内存清零或 Keyring 存储

## GIVEN-WHEN-THEN 场景

### 场景：计算 secretkey 哈希

- **GIVEN** 用户提供明文 secretkey
- **WHEN** 计算哈希
- **THEN** 返回 64 字符十六进制字符串

### 场景：加入时校验 secretkey 哈希

- **GIVEN** 加入请求携带 `pool_id` 哈希与 `secretkey` 哈希
- **WHEN** 目标节点校验
- **THEN** 哈希一致则允许加入

### 场景：同步时仅校验 pool_id 哈希

- **GIVEN** 同步请求携带 `pool_id` 哈希
- **WHEN** 目标节点校验
- **THEN** 哈希一致则允许同步
