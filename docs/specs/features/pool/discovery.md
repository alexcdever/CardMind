# 池发现规格

**状态**: 生效中
**依赖**: [../../domain/pool.md](../../domain/pool.md), [../../architecture/sync/peer_discovery.md](../../architecture/sync/peer_discovery.md), [../../architecture/sync/service.md](../../architecture/sync/service.md)
**相关测试**: `test/feature/features/p2p_sync_feature_test.dart`

---

## 概述

定义池发现与加入的业务规则：仅通过二维码组池，加入需处于同一局域网；加入成功后启动 mDNS 监听与广播以发现对等设备。

---

## GIVEN-WHEN-THEN 场景

### 场景：生成二维码加入信息

- **GIVEN**: 设备已加入某个池
- **WHEN**: 请求生成加入信息
- **THEN**: 系统生成包含池 ID 的二维码数据

### 场景：同局域网内通过二维码加入

- **GIVEN**: 设备与池所在设备处于同一局域网
- **WHEN**: 扫描二维码并发起加入请求
- **THEN**: 系统允许加入并开始同步

### 场景：非同局域网拒绝加入

- **GIVEN**: 设备与池所在设备不在同一局域网
- **WHEN**: 扫描二维码并发起加入请求
- **THEN**: 系统拒绝加入并返回错误 `LAN_REQUIRED`

### 场景：加入后启动对等发现

- **GIVEN**: 设备成功加入某个池
- **WHEN**: 加入流程完成
- **THEN**: 系统启动 mDNS 监听与广播
