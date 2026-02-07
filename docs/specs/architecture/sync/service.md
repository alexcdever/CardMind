# P2P 同步服务架构规格

## 概述

本规格定义了 CardMind 的 P2P 同步服务架构，包括服务初始化、对等点发现、同步状态跟踪和数据同步实现。

**技术栈**:
- **tokio** - 异步运行时
- **loro** = "1.0" - CRDT 文档同步
- **libp2p mdns** - 对等点发现

**核心职责**:
- 管理 P2P 连接和数据同步
- 跟踪在线对等点和同步状态
- 协调对等点发现和连接建立
- 处理同步错误和重试

---

## 需求：同步服务创建和初始化

系统应提供管理 P2P 连接和数据同步的同步服务。

### 场景：使用有效配置创建同步服务

- **前置条件**: 设备已加入池，具备可用的 PeerId 与监听端口
- **操作**: 创建新的 SyncService
- **预期结果**: 服务应成功初始化
- **并且**: 准备好接受连接

### 场景：同步服务跟踪在线对等点

- **前置条件**: 同步服务正在运行
- **操作**: 对等点加入网络
- **预期结果**: 服务应跟踪在线对等点数量
- **并且**: 计数应可通过 SyncStatus 访问

---

## 需求：同步状态报告

系统应提供反映当前同步状态的 SyncStatus 结构。

### 场景：初始同步状态的在线对等点为零

- **前置条件**: 新创建的 SyncService
- **操作**: 请求 SyncStatus
- **预期结果**: online_peers 计数应为 0
- **并且**: syncing_peers 计数应为 0

### 场景：同步状态反映独立副本

- **前置条件**: SyncService 正在运行
- **操作**: 多个线程请求 SyncStatus
- **预期结果**: 每个请求应返回独立副本
- **并且**: 对一个副本的修改不应影响其他副本

---

## 需求：对等点发现

系统应支持对等点发现机制，包括用于本地网络发现的 libp2p mDNS。

### 场景：加入池后启用 mDNS 对等点发现

- **前置条件**: 设备已加入池
- **操作**: 启动同步服务
- **预期结果**: 服务应发现其他 CardMind 实例
- **并且**: 发现事件触发连接尝试

---

## 需求：启动与错误码

系统应提供语义化错误码以指示 mDNS 启动失败或非法状态。

### 场景：未加入池时启动同步服务

- **前置条件**: 设备未加入池
- **操作**: 调用同步服务初始化
- **预期结果**: 返回 `INVALID_STATE: NOT_JOINED_POOL`

### 场景：mDNS 启动失败

- **前置条件**: 设备已加入池
- **操作**: 启动 mDNS
- **预期结果**: 返回结构化错误码

**错误码**:
- `MdnsError::PermissionDenied` - 权限不足
- `MdnsError::SocketUnavailable` - 端口/套接字不可用
- `MdnsError::Unsupported` - 平台不支持
- `MdnsError::StartFailed` - 其他启动失败

---

## 需求：P2P 数据同步

系统应在同一池中的对等点之间同步 Loro 文档。

### 场景：向已连接的对等点同步更改

- **前置条件**: 同一池中的两台设备
- **并且**: 两台设备都在线并已连接
- **操作**: 设备 A 对卡片进行更改
- **预期结果**: 更改应同步到设备 B
- **并且**: 设备 B 应反映更新的卡片

### 场景：使用 CRDT 处理同步冲突

- **前置条件**: 两台设备同时更改同一张卡片
- **操作**: 同步更改
- **预期结果**: Loro CRDT 应自动合并更改
- **并且**: 两台设备应收敛到相同状态

---

## 需求：按池过滤同步

系统应仅同步当前池内的数据。

### 场景：仅同步当前池数据

- **前置条件**: 设备在 pool_A 中
- **并且**: 网络上存在 pool_B
- **操作**: 与对等点同步
- **预期结果**: 仅应同步 pool_A 数据
- **并且**: pool_B 数据不应被传输

---

## 补充说明

**技术栈**:
- **tokio** - 异步运行时和网络 I/O
- **loro** = "1.0" - CRDT 文档同步
- **libp2p mdns** - 对等点发现

**设计模式**:
- **服务模式**: SyncService 作为中心协调器
- **观察者模式**: 状态变更通知
- **发布-订阅**: 对等点间消息传递

**并发模型**:
- **异步 I/O**: 使用 tokio 处理网络操作
- **线程安全集合**: 跟踪在线对等点
- **任务生成**: 每个连接独立任务

---

## 相关文档

**领域规格**:
- [../../domain/sync.md](../../domain/sync.md) - 同步领域模型
- [../../domain/pool.md](../../domain/pool.md) - 池领域模型

**相关架构规格**:
- [../storage/device_config.md](../storage/device_config.md) - 设备配置存储
- [../storage/card_store.md](../storage/card_store.md) - CardStore 实现
- [./peer_discovery.md](./peer_discovery.md) - 对等点发现
- [./conflict_resolution.md](./conflict_resolution.md) - 冲突解决
- [./subscription.md](./subscription.md) - 订阅机制

**架构决策记录**:
- ADR-0002: 双层架构 - 读写分离设计
- ADR-0003: Loro CRDT - CRDT 库选择

---

## 测试覆盖

**测试文件**: `rust/tests/sync_integration_feature_test.rs`

**单元测试**:
- `it_should_create_sync_service_with_valid_config()` - 创建同步服务
- `it_should_reject_invalid_config()` - 拒绝无效配置
- `it_should_track_online_peers()` - 跟踪在线对等点
- `it_should_handle_peer_disconnection()` - 处理断开连接
- `it_should_return_initial_status_with_zero_peers()` - 初始状态
- `it_should_return_independent_status_copies()` - 独立副本
- `it_should_discover_peers_via_mdns()` - mDNS 发现
- `it_should_reject_peer_on_pool_hash_mismatch()` - 握手池校验

**功能测试**:
- `it_should_sync_changes_between_peers()` - 对等点间同步
- `it_should_handle_concurrent_changes()` - CRDT 冲突解决
- `it_should_filter_sync_by_pool()` - 基于池的过滤
- `it_should_broadcast_to_multiple_peers()` - 多对等点广播
- `it_should_handle_network_interruption()` - 网络中断恢复

**验收标准**:
- [x] 所有单元测试通过
- [x] 功能测试通过
- [x] 对等点发现在本地网络上工作
- [x] CRDT 正确合并并发更改
- [x] 池过滤正确执行
- [x] 代码审查通过
