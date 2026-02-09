# 池发现规格
- 相关文档:
  - [池加入](joining.md)
  - [mDNS 发现](../../architecture/sync/peer_discovery.md)
- 测试覆盖:
  - `rust/tests/mdns_discovery_feature_test.rs`
  - `test/unit/services/qr_code_parser_unit_test.dart`

## 概述

定义池发现与加入入口：仅通过二维码加入；加入前不监听/广播 mDNS，加入后启用 mDNS。

## GIVEN-WHEN-THEN 场景

### 场景：生成二维码加入信息

- **GIVEN** 设备已加入某个池
- **WHEN** 请求生成加入二维码
- **THEN** 二维码包含 `multiaddr` 与 `pool_id` 明文

### 场景：扫码后发起加入

- **GIVEN** 扫描二维码获得 `multiaddr` 与 `pool_id`
- **WHEN** 用户手动输入 secretkey 并发起加入请求
- **THEN** 客户端仅发送 `pool_id` 哈希与 `secretkey` 哈希

### 场景：加入后启动对等发现

- **GIVEN** 设备成功加入某个池
- **WHEN** 加入流程完成
- **THEN** 系统启动 mDNS 监听与广播
