# P2P Sync Service Architecture Specification
# P2P 同步服务架构规格

**Version**: 1.0.0
**版本**: 1.0.0
**Status**: Active
**状态**: Active
**Dependencies**: [../../domain/pool/model.md](../../domain/pool/model.md), [../../domain/sync/model.md](../../domain/sync/model.md), [../storage/device_config.md](../storage/device_config.md)
**依赖**: [../../domain/pool/model.md](../../domain/pool/model.md), [../../domain/sync/model.md](../../domain/sync/model.md), [../storage/device_config.md](../storage/device_config.md)
**Related Tests**: `rust/tests/sp_sync_006_spec.rs`
**相关测试**: `rust/tests/sp_sync_006_spec.rs`

---

## Overview
## 概述

This specification defines the P2P sync service architecture for CardMind, including service initialization, peer discovery, sync status tracking, and data synchronization implementation.

本规格定义了 CardMind 的 P2P 同步服务架构，包括服务初始化、对等点发现、同步状态跟踪和数据同步实现。

---

## Requirement: Sync service creation and initialization
## 需求：同步服务创建和初始化

The system SHALL provide a sync service that manages P2P connections and data synchronization.

系统应提供管理 P2P 连接和数据同步的同步服务。

### Scenario: Create sync service with valid config
### 场景：使用有效配置创建同步服务

- **GIVEN** a valid SyncConfig with peer ID and port
- **前置条件**：具有对等点 ID 和端口的有效 SyncConfig
- **WHEN** creating a new SyncService
- **操作**：创建新的 SyncService
- **THEN** the service SHALL initialize successfully
- **预期结果**：服务应成功初始化
- **AND** be ready to accept connections
- **并且**：准备好接受连接

**Pseudocode**:
**伪代码**:

```
function create_sync_service(config):
    // Initialize service with configuration
    // 使用配置初始化服务
    service = new SyncService()
    service.peer_id = config.peer_id
    service.listen_port = config.port

    // Initialize peer tracking
    // 初始化对等点跟踪
    // Design decision: Use thread-safe collection for concurrent access
    // 设计决策：使用线程安全集合以支持并发访问
    service.online_peers = create_concurrent_set()
    service.syncing_peers = create_concurrent_set()

    // Start network listener
    // 启动网络监听器
    // Note: Listener runs in background to accept incoming connections
    // 注意：监听器在后台运行以接受传入连接
    start_network_listener(service.listen_port)

    return service
```

### Scenario: Sync service tracks online peers
### 场景：同步服务跟踪在线对等点

- **GIVEN** a sync service is running
- **前置条件**：同步服务正在运行
- **WHEN** peers join the network
- **操作**：对等点加入网络
- **THEN** the service SHALL track online peer count
- **预期结果**：服务应跟踪在线对等点数量
- **AND** the count SHALL be accessible via SyncStatus
- **并且**：计数应可通过 SyncStatus 访问

**Pseudocode**:
**伪代码**:

```
function handle_peer_connection(peer_info):
    // Step 1: Validate peer is in same pool
    // 步骤1：验证对等点在同一池中
    if peer_info.pool_id != current_pool_id:
        reject_connection("Different pool")
        return

    // Step 2: Add to online peers
    // 步骤2：添加到在线对等点
    // Design decision: Track peers by unique ID to prevent duplicates
    // 设计决策：通过唯一ID跟踪对等点以防止重复
    online_peers.add(peer_info.peer_id)

    // Step 3: Update sync status
    // 步骤3：更新同步状态
    // Note: Status is computed on-demand from peer collections
    // 注意：状态从对等点集合按需计算
    notify_status_changed()
```

---

## Requirement: Sync status reporting
## 需求：同步状态报告

The system SHALL provide a SyncStatus struct that reflects the current sync state.

系统应提供反映当前同步状态的 SyncStatus 结构。

### Scenario: Initial sync status has zero online peers
### 场景：初始同步状态的在线对等点为零

- **GIVEN** a newly created SyncService
- **前置条件**：新创建的 SyncService
- **WHEN** requesting SyncStatus
- **操作**：请求 SyncStatus
- **THEN** the online_peers count SHALL be 0
- **预期结果**：online_peers 计数应为 0
- **AND** syncing_peers count SHALL be 0
- **并且**：syncing_peers 计数应为 0

**Pseudocode**:
**伪代码**:

```
function get_sync_status():
    // Create independent status snapshot
    // 创建独立的状态快照
    // Design decision: Return copy to prevent external mutation
    // 设计决策：返回副本以防止外部修改
    status = new SyncStatus()
    status.online_peers = count(online_peers)
    status.syncing_peers = count(syncing_peers)
    status.last_sync_time = get_last_sync_timestamp()

    return status
```

### Scenario: Sync status reflects independent copies
### 场景：同步状态反映独立副本

- **GIVEN** a SyncService is running
- **前置条件**：SyncService 正在运行
- **WHEN** multiple threads request SyncStatus
- **操作**：多个线程请求 SyncStatus
- **THEN** each request SHALL return an independent copy
- **预期结果**：每个请求应返回独立副本
- **AND** modifications to one copy SHALL NOT affect others
- **并且**：对一个副本的修改不应影响其他副本

---

## Requirement: Peer discovery
## 需求：对等点发现

The system SHALL support peer discovery mechanisms including mDNS for local network discovery.

系统应支持对等点发现机制，包括用于本地网络发现的 mDNS。

### Scenario: mDNS peer discovery enabled
### 场景：启用 mDNS 对等点发现

- **GIVEN** the sync service is configured with mDNS
- **前置条件**：同步服务已配置 mDNS
- **WHEN** discovering peers on the local network
- **操作**：在本地网络上发现对等点
- **THEN** the service SHALL find other CardMind instances
- **预期结果**：服务应找到其他 CardMind 实例
- **AND** add them to the peer list
- **并且**：将它们添加到对等点列表

**Pseudocode**:
**伪代码**:

```
function discover_peers_via_mdns():
    // Step 1: Broadcast service announcement
    // 步骤1：广播服务公告
    // Design decision: Use mDNS for zero-config local network discovery
    // 设计决策：使用mDNS实现零配置本地网络发现
    announce_service(
        service_name: "cardmind-sync",
        port: listen_port,
        metadata: {
            peer_id: self.peer_id,
            pool_id: current_pool_id
        }
    )

    // Step 2: Listen for peer announcements
    // 步骤2：监听对等点公告
    on_peer_discovered(peer_info):
        // Only connect to peers in same pool
        // 仅连接同一池中的对等点
        if peer_info.pool_id == current_pool_id:
            attempt_connection(peer_info)
```

---

## Requirement: P2P data synchronization
## 需求：P2P 数据同步

The system SHALL synchronize Loro documents between peers in the same pool.

系统应在同一池中的对等点之间同步 Loro 文档。

### Scenario: Sync changes to connected peers
### 场景：向已连接的对等点同步更改

- **GIVEN** two devices in the same pool
- **前置条件**：同一池中的两台设备
- **AND** both devices are online and connected
- **并且**：两台设备都在线并已连接
- **WHEN** device A makes a change to a card
- **操作**：设备 A 对卡片进行更改
- **THEN** the change SHALL be synced to device B
- **预期结果**：更改应同步到设备 B
- **AND** device B SHALL reflect the updated card
- **并且**：设备 B 应反映更新的卡片

**Pseudocode**:
**伪代码**:

```
function sync_card_change(card_id, local_changes):
    // Step 1: Get card from local store
    // 步骤1：从本地存储获取卡片
    card = get_card_from_store(card_id)

    // Step 2: Convert to CRDT representation
    // 步骤2：转换为CRDT表示
    // Design decision: Use CRDT for automatic conflict resolution
    // 设计决策：使用CRDT实现自动冲突解决
    crdt_doc = create_crdt_document()
    crdt_doc.add_field("title", card.title)
    crdt_doc.add_field("content", card.content)
    crdt_doc.add_field("updated_at", card.updated_at)

    // Step 3: Broadcast to all online peers in pool
    // 步骤3：广播到池中所有在线对等点
    // Note: Only send to peers in same pool
    // 注意：仅发送到同一池中的对等点
    for each peer in online_peers:
        if peer.pool_id == current_pool_id:
            send_sync_message(peer, crdt_doc)
```

### Scenario: Handle sync conflicts with CRDT
### 场景：使用 CRDT 处理同步冲突

- **GIVEN** two devices make concurrent changes to the same card
- **前置条件**：两台设备同时更改同一张卡片
- **WHEN** syncing the changes
- **操作**：同步更改
- **THEN** Loro CRDT SHALL automatically merge the changes
- **预期结果**：Loro CRDT 应自动合并更改
- **AND** both devices SHALL converge to the same state
- **并且**：两台设备应收敛到相同状态

**Pseudocode**:
**伪代码**:

```
function handle_incoming_sync(peer_id, crdt_doc):
    // Step 1: Get local version of the card
    // 步骤1：获取卡片的本地版本
    card_id = crdt_doc.get_id()
    local_crdt = get_local_crdt_document(card_id)

    // Step 2: Merge incoming changes
    // 步骤2：合并传入的更改
    // Design decision: CRDT automatically resolves conflicts
    // 设计决策：CRDT自动解决冲突
    // Note: Last-write-wins for simple fields, operational transform for text
    // 注意：简单字段使用最后写入优先，文本使用操作转换
    merged_crdt = local_crdt.merge(crdt_doc)

    // Step 3: Update local storage
    // 步骤3：更新本地存储
    card = convert_crdt_to_card(merged_crdt)
    update_card_in_store(card)

    // Step 4: Propagate to other peers if needed
    // 步骤4：如果需要，传播到其他对等点
    if has_new_changes(merged_crdt):
        broadcast_to_other_peers(merged_crdt, exclude: peer_id)
```

---

## Requirement: Sync filtering by pool
## 需求：按池过滤同步

The system SHALL only sync data within the current pool.

系统应仅同步当前池内的数据。

### Scenario: Only sync current pool data
### 场景：仅同步当前池数据

- **GIVEN** a device is in pool_A
- **前置条件**：设备在 pool_A 中
- **AND** pool_B exists on the network
- **并且**：网络上存在 pool_B
- **WHEN** syncing with peers
- **操作**：与对等点同步
- **THEN** only pool_A data SHALL be synced
- **预期结果**：仅应同步 pool_A 数据
- **AND** pool_B data SHALL NOT be transferred
- **并且**：pool_B 数据不应被传输

**Pseudocode**:
**伪代码**:

```
function filter_sync_by_pool(sync_message):
    // Step 1: Extract pool ID from message
    // 步骤1：从消息中提取池ID
    message_pool_id = sync_message.pool_id

    // Step 2: Validate pool membership
    // 步骤2：验证池成员资格
    // Design decision: Reject cross-pool sync to maintain data isolation
    // 设计决策：拒绝跨池同步以维护数据隔离
    if message_pool_id != current_pool_id:
        reject_message("Pool mismatch")
        return

    // Step 3: Process sync for current pool only
    // 步骤3：仅处理当前池的同步
    // Note: This ensures data privacy between different pools
    // 注意：这确保了不同池之间的数据隐私
    process_sync_message(sync_message)
```

---

## Test Coverage
## 测试覆盖

**Test File**: `rust/tests/sp_sync_006_spec.rs`
**测试文件**: `rust/tests/sp_sync_006_spec.rs`

**Unit Tests**:
**单元测试**:
- `it_should_create_sync_service_with_valid_config()` - Create sync service
- 创建同步服务
- `it_should_track_online_peers()` - Track online peers
- 跟踪在线对等点
- `it_should_return_initial_status_with_zero_peers()` - Initial status
- 初始状态
- `it_should_return_independent_status_copies()` - Independent copies
- 独立副本
- `it_should_discover_peers_via_mdns()` - mDNS discovery
- mDNS 发现

**Integration Tests**:
**集成测试**:
- `it_should_sync_changes_between_peers()` - Sync between peers
- 对等点间同步
- `it_should_handle_concurrent_changes()` - CRDT conflict resolution
- CRDT 冲突解决
- `it_should_filter_sync_by_pool()` - Pool-based filtering
- 基于池的过滤

**Acceptance Criteria**:
**验收标准**:
- [ ] All unit tests pass
- [ ] 所有单元测试通过
- [ ] Integration tests pass
- [ ] 集成测试通过
- [ ] Peer discovery works on local network
- [ ] 对等点发现在本地网络上工作
- [ ] CRDT correctly merges concurrent changes
- [ ] CRDT 正确合并并发更改
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Domain Specs**:
**领域规格**:
- [../../domain/sync/model.md](../../domain/sync/model.md) - Sync domain model
- 同步领域模型
- [../../domain/pool/model.md](../../domain/pool/model.md) - Pool domain model
- 池领域模型

**Related Architecture Specs**:
**相关架构规格**:
- [../storage/device_config.md](../storage/device_config.md) - Device configuration storage
- 设备配置存储
- [../storage/card_store.md](../storage/card_store.md) - CardStore implementation
- CardStore 实现

**ADRs**:
**架构决策记录**:
- [../../../docs/adr/0002-dual-layer-architecture.md](../../../docs/adr/0002-dual-layer-architecture.md) - Dual-layer architecture
- 双层架构
- [../../../docs/adr/0003-loro-crdt.md](../../../docs/adr/0003-loro-crdt.md) - Loro CRDT for conflict-free sync
- Loro CRDT 用于无冲突同步

**Implementation Guides**:
**实现指南**:
- [../../../docs/architecture/sync_mechanism.md](../../../docs/architecture/sync_mechanism.md) - Detailed sync implementation
- 详细同步实现

---

**Last Updated**: 2026-01-21
**最后更新**: 2026-01-21
**Authors**: CardMind Team
**作者**: CardMind Team
