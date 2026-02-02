# P2P 同步服务架构规格

**版本**: 1.0.0
**状态**: 活跃
**依赖**: [../../domain/pool/model.md](../../domain/pool/model.md), [../../domain/sync/model.md](../../domain/sync/model.md), [../storage/device_config.md](../storage/device_config.md)
**相关测试**: `rust/tests/sync_service_test.rs`

---

## 概述


本规格定义了 CardMind 的 P2P 同步服务架构，包括服务初始化、对等点发现、同步状态跟踪和数据同步实现。

---

## 需求：同步服务创建和初始化


系统应提供管理 P2P 连接和数据同步的同步服务。

### 场景：使用有效配置创建同步服务

- **前置条件**：具有对等点 ID 和端口的有效 SyncConfig
- **操作**：创建新的 SyncService
- **预期结果**：服务应成功初始化
- **并且**：准备好接受连接

**伪代码**:

```
function create_sync_service(config):
    // 使用配置初始化服务
    service = new SyncService()
    service.peer_id = config.peer_id
    service.listen_port = config.port

    // 初始化对等点跟踪
    // 设计决策：使用线程安全集合以支持并发访问
    service.online_peers = create_concurrent_set()
    service.syncing_peers = create_concurrent_set()

    // 启动网络监听器
    // 注意：监听器在后台运行以接受传入连接
    start_network_listener(service.listen_port)

    return service
```

### 场景：同步服务跟踪在线对等点

- **前置条件**：同步服务正在运行
- **操作**：对等点加入网络
- **预期结果**：服务应跟踪在线对等点数量
- **并且**：计数应可通过 SyncStatus 访问

**伪代码**:

```
function handle_peer_connection(peer_info):
    // 步骤1：验证对等点在同一池中
    if peer_info.pool_id != current_pool_id:
        reject_connection("Different pool")
        return

    // 步骤2：添加到在线对等点
    // 设计决策：通过唯一ID跟踪对等点以防止重复
    online_peers.add(peer_info.peer_id)

    // 步骤3：更新同步状态
    // 注意：状态从对等点集合按需计算
    notify_status_changed()
```

---

## 需求：同步状态报告


系统应提供反映当前同步状态的 SyncStatus 结构。

### 场景：初始同步状态的在线对等点为零

- **前置条件**：新创建的 SyncService
- **操作**：请求 SyncStatus
- **预期结果**：online_peers 计数应为 0
- **并且**：syncing_peers 计数应为 0

**伪代码**:

```
function get_sync_status():
    // 创建独立的状态快照
    // 设计决策：返回副本以防止外部修改
    status = new SyncStatus()
    status.online_peers = count(online_peers)
    status.syncing_peers = count(syncing_peers)
    status.last_sync_time = get_last_sync_timestamp()

    return status
```

### 场景：同步状态反映独立副本

- **前置条件**：SyncService 正在运行
- **操作**：多个线程请求 SyncStatus
- **预期结果**：每个请求应返回独立副本
- **并且**：对一个副本的修改不应影响其他副本

---

## 需求：对等点发现


系统应支持对等点发现机制，包括用于本地网络发现的 mDNS。

### 场景：启用 mDNS 对等点发现

- **前置条件**：同步服务已配置 mDNS
- **操作**：在本地网络上发现对等点
- **预期结果**：服务应找到其他 CardMind 实例
- **并且**：将它们添加到对等点列表

**伪代码**:

```
function discover_peers_via_mdns():
    // 步骤1：广播服务公告
    // 设计决策：使用mDNS实现零配置本地网络发现
    announce_service(
        service_name: "cardmind-sync",
        port: listen_port,
        metadata: {
            peer_id: self.peer_id,
            pool_id: current_pool_id
        }
    )

    // 步骤2：监听对等点公告
    on_peer_discovered(peer_info):
        // 仅连接同一池中的对等点
        if peer_info.pool_id == current_pool_id:
            attempt_connection(peer_info)
```

---

## 需求：P2P 数据同步


系统应在同一池中的对等点之间同步 Loro 文档。

### 场景：向已连接的对等点同步更改

- **前置条件**：同一池中的两台设备
- **并且**：两台设备都在线并已连接
- **操作**：设备 A 对卡片进行更改
- **预期结果**：更改应同步到设备 B
- **并且**：设备 B 应反映更新的卡片

**伪代码**:

```
function sync_card_change(card_id, local_changes):
    // 步骤1：从本地存储获取卡片
    card = get_card_from_store(card_id)

    // 步骤2：转换为CRDT表示
    // 设计决策：使用CRDT实现自动冲突解决
    crdt_doc = create_crdt_document()
    crdt_doc.add_field("title", card.title)
    crdt_doc.add_field("content", card.content)
    crdt_doc.add_field("updated_at", card.updated_at)

    // 步骤3：广播到池中所有在线对等点
    // 注意：仅发送到同一池中的对等点
    for each peer in online_peers:
        if peer.pool_id == current_pool_id:
            send_sync_message(peer, crdt_doc)
```

### 场景：使用 CRDT 处理同步冲突

- **前置条件**：两台设备同时更改同一张卡片
- **操作**：同步更改
- **预期结果**：Loro CRDT 应自动合并更改
- **并且**：两台设备应收敛到相同状态

**伪代码**:

```
function handle_incoming_sync(peer_id, crdt_doc):
    // 步骤1：获取卡片的本地版本
    card_id = crdt_doc.get_id()
    local_crdt = get_local_crdt_document(card_id)

    // 步骤2：合并传入的更改
    // 设计决策：CRDT自动解决冲突
    // 注意：简单字段使用最后写入优先，文本使用操作转换
    merged_crdt = local_crdt.merge(crdt_doc)

    // 步骤3：更新本地存储
    card = convert_crdt_to_card(merged_crdt)
    update_card_in_store(card)

    // 步骤4：如果需要，传播到其他对等点
    if has_new_changes(merged_crdt):
        broadcast_to_other_peers(merged_crdt, exclude: peer_id)
```

---

## 需求：按池过滤同步


系统应仅同步当前池内的数据。

### 场景：仅同步当前池数据

- **前置条件**：设备在 pool_A 中
- **并且**：网络上存在 pool_B
- **操作**：与对等点同步
- **预期结果**：仅应同步 pool_A 数据
- **并且**：pool_B 数据不应被传输

**伪代码**:

```
function filter_sync_by_pool(sync_message):
    // 步骤1：从消息中提取池ID
    message_pool_id = sync_message.pool_id

    // 步骤2：验证池成员资格
    // 设计决策：拒绝跨池同步以维护数据隔离
    if message_pool_id != current_pool_id:
        reject_message("Pool mismatch")
        return

    // 步骤3：仅处理当前池的同步
    // 注意：这确保了不同池之间的数据隐私
    process_sync_message(sync_message)
```

---


## 测试覆盖

**测试文件**: `rust/tests/sp_sync_006_spec.rs`

**单元测试**:
- `it_should_create_sync_service_with_valid_config()` - 创建同步服务
- `it_should_track_online_peers()` - 跟踪在线对等点
- `it_should_return_initial_status_with_zero_peers()` - 初始状态
- `it_should_return_independent_status_copies()` - 独立副本
- `it_should_discover_peers_via_mdns()` - mDNS 发现

**集成测试**:
- `it_should_sync_changes_between_peers()` - 对等点间同步
- `it_should_handle_concurrent_changes()` - CRDT 冲突解决
- `it_should_filter_sync_by_pool()` - 基于池的过滤

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 集成测试通过
- [ ] 对等点发现在本地网络上工作
- [ ] CRDT 正确合并并发更改
- [ ] 代码审查通过
- [ ] 文档已更新

---


## 相关文档

**领域规格**:
- [../../domain/sync/model.md](../../domain/sync/model.md) - 同步领域模型
- [../../domain/pool/model.md](../../domain/pool/model.md) - 池领域模型

**相关架构规格**:
- [../storage/device_config.md](../storage/device_config.md) - 设备配置存储
- [../storage/card_store.md](../storage/card_store.md) - CardStore 实现

**架构决策记录**:
- [../../../docs/adr/0002-dual-layer-architecture.md](../../../docs/adr/0002-dual-layer-architecture.md) - 双层架构
- [../../../docs/adr/0003-loro-crdt.md](../../../docs/adr/0003-loro-crdt.md) - Loro CRDT 用于无冲突同步

**实现指南**:
- [../../../docs/architecture/sync_mechanism.md](../../../docs/architecture/sync_mechanism.md) - 详细同步实现

---

**最后更新**: 2026-01-21
**作者**: CardMind Team
