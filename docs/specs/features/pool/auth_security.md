# 池认证与安全规格
- 相关文档:
  - [secretkey 管理](../../architecture/security/password.md)
  - [池加入](joining.md)
  - [池同步](sync.md)
- 测试覆盖:
  - `rust/tests/security_password_feature_test.rs`
  - `test/feature/features/p2p_sync_feature_test.dart`

## 概述

定义池认证与校验规则：加入时校验 `pool_id` 哈希与 `secretkey` 哈希；同步时仅校验 `pool_id` 哈希；哈希算法统一为 SHA-256 十六进制。

## GIVEN-WHEN-THEN 场景

### 场景：加入时校验通过

- **GIVEN** `pool_id` 哈希与 `secretkey` 哈希均匹配
- **WHEN** 发起加入请求
- **THEN** 系统允许加入并返回池元数据

### 场景：加入校验失败

- **GIVEN** `pool_id` 哈希或 `secretkey` 哈希不匹配
- **WHEN** 发起加入请求
- **THEN** 系统拒绝加入并返回具体错误原因

### 场景：同步时校验通过

- **GIVEN** 请求携带 `pool_id` 哈希且与本地池匹配
- **WHEN** 发起同步
- **THEN** 系统允许同步
