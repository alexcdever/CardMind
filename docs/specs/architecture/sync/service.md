# P2P 同步服务架构规格

**状态**: 活跃
**依赖**: [../../domain/pool.md](../../domain/pool.md), [../../domain/sync.md](../../domain/sync.md), [../storage/device_config.md](../storage/device_config.md)
**相关测试**: `rust/tests/sync_test.rs`

---

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

**实现逻辑**:

```
function create_sync_service(config):
    // 步骤1：验证配置
    if not config.is_joined_pool:
        return error "InvalidState: NotJoinedPool"

    if config.peer_id is empty:
        return error "InvalidConfig: peer_id is required"
    
    if config.port < 1024 or config.port > 65535:
        return error "InvalidConfig: invalid port number"
    
    // 步骤2：使用配置初始化服务
    service = new SyncService()
    service.peer_id = config.peer_id
    service.listen_port = config.port

    // 步骤3：初始化对等点跟踪
    // 设计决策：使用线程安全集合以支持并发访问
    service.online_peers = create_concurrent_set()
    service.syncing_peers = create_concurrent_set()
    service.last_sync_time = None

    // 步骤4：启动网络监听器
    // 注意：监听器在后台运行以接受传入连接
    listener = start_network_listener(service.listen_port)
    
    if listener is error:
        return error "FailedToStartListener: " + listener.error
    
    service.listener = listener

    log_info("Sync service created on port: " + service.listen_port)
    return service

function start_network_listener(port):
    // 启动 TCP 监听器以接受传入连接
    // 设计决策：使用异步监听器支持并发连接
    
    try:
        listener = bind_tcp_listener("0.0.0.0", port)
        
        // 在后台任务中处理传入连接
        spawn_background_task:
            loop forever:
                connection = listener.accept()
                
                if connection is not error:
                    // 为每个连接生成单独的任务
                    spawn_task:
                        handle_incoming_connection(connection)
        
        log_info("Network listener started on port: " + port)
        return listener
    catch error:
        log_error("Failed to start listener: " + error)
        return error
```

### 场景：同步服务跟踪在线对等点

- **前置条件**: 同步服务正在运行
- **操作**: 对等点加入网络
- **预期结果**: 服务应跟踪在线对等点数量
- **并且**: 计数应可通过 SyncStatus 访问

**实现逻辑**:

```
function handle_peer_connection(peer_info):
    // 步骤1：执行握手，验证是否同池
    if not perform_pool_handshake(peer_info.connection):
        log_warn("Rejecting peer due to pool mismatch")
        reject_connection("PoolMismatch")
        return

    // 步骤2：添加到在线对等点
    // 设计决策：通过唯一ID跟踪对等点以防止重复
    if not online_peers.contains(peer_info.peer_id):
        online_peers.add(peer_info.peer_id)
        
        log_info("Peer connected: " + peer_info.peer_id)

        // 步骤3：更新同步状态
        // 注意：状态从对等点集合按需计算
        notify_status_changed()
    else:
        log_debug("Peer already connected: " + peer_info.peer_id)

function handle_peer_disconnection(peer_id):
    // 处理对等点断开连接
    if online_peers.contains(peer_id):
        online_peers.remove(peer_id)
        syncing_peers.remove(peer_id)
        
        log_info("Peer disconnected: " + peer_id)
        notify_status_changed()
```

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

**实现逻辑**:

```
function get_sync_status():
    // 创建独立的状态快照
    // 设计决策：返回副本以防止外部修改
    status = new SyncStatus()
    status.online_peers = count(online_peers)
    status.syncing_peers = count(syncing_peers)
    status.last_sync_time = last_sync_time
    status.is_syncing = status.syncing_peers > 0

    return status

structure SyncStatus:
    online_peers: integer
    syncing_peers: integer
    last_sync_time: optional timestamp
    is_syncing: boolean
```

---

## 需求：对等点发现

系统应支持对等点发现机制，包括用于本地网络发现的 libp2p mDNS。

### 场景：加入池后启用 mDNS 对等点发现

- **前置条件**: 设备已加入池
- **操作**: 启动同步服务
- **预期结果**: 服务应发现其他 CardMind 实例
- **并且**: 发现事件触发连接尝试

**实现逻辑**:

```
function discover_peers_via_mdns():
    // libp2p mDNS 在启动后自动广播与监听
    // 设计决策：发现阶段不做池过滤
    on mdns_event.discovered(peer_info):
        attempt_connection(peer_info)
    on mdns_event.expired(peer_info):
        mark_peer_offline(peer_info.peer_id)

    log_info("mDNS peer discovery started")
    return success

function attempt_connection(peer_info):
    // 尝试连接到发现的对等点
    // 步骤1：检查是否已连接
    if online_peers.contains(peer_info.peer_id):
        log_debug("Already connected to peer")
        return
    
    // 步骤2：建立连接
    connection = connect_to_peer(peer_info, current_pool_id)
    
    if connection is error:
        log_warn("Failed to connect to peer: " + connection.error)
        return
    
    // 步骤3：添加到在线对等点
    handle_peer_connection({
        peer_id: peer_info.peer_id,
        connection: connection
    })
```

---

## 需求：启动与错误码

系统应提供语义化错误码以指示 mDNS 启动失败或非法状态。

### 场景：未加入池时启动同步服务

- **前置条件**: 设备未加入池
- **操作**: 调用同步服务初始化
- **预期结果**: 返回 `InvalidState: NotJoinedPool`

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

**实现逻辑**:

```
function sync_card_change(card_id, local_changes):
    // 步骤1：从本地存储获取卡片
    card = get_card_from_store(card_id)
    
    if card is error:
        log_error("Card not found: " + card_id)
        return error

    // 步骤2：获取卡片的 Loro 文档
    loro_doc = load_loro_document(card_id)
    
    if loro_doc is error:
        log_error("Failed to load Loro document: " + card_id)
        return error

    // 步骤3：导出增量更新
    // 设计决策：仅发送变更，而非完整文档
    updates = loro_doc.export_updates()

    // 步骤4：广播到池中所有在线对等点
    // 注意：仅发送到同一池中的对等点
    current_pool_id = get_current_pool_id()
    
    for each peer_id in online_peers:
        peer = get_peer_connection(peer_id)
        
        if peer.pool_id == current_pool_id:
            // 添加到同步对等点集合
            syncing_peers.add(peer_id)
            
            // 发送同步消息
            result = send_sync_message(peer, {
                type: "CardUpdate",
                card_id: card_id,
                updates: updates
            })
            
            if result is error:
                log_error("Failed to sync with peer " + peer_id + ": " + result.error)
                syncing_peers.remove(peer_id)
            else:
                log_debug("Synced card " + card_id + " to peer " + peer_id)
    
    // 步骤5：更新最后同步时间
    last_sync_time = current_timestamp()
    
    return success

function send_sync_message(peer, message):
    // 发送同步消息到对等点
    try:
        peer.connection.send(message)
        return success
    catch error:
        log_error("Failed to send message: " + error)
        return error
```

### 场景：使用 CRDT 处理同步冲突

- **前置条件**: 两台设备同时更改同一张卡片
- **操作**: 同步更改
- **预期结果**: Loro CRDT 应自动合并更改
- **并且**: 两台设备应收敛到相同状态

**实现逻辑**:

```
function handle_incoming_sync(peer_id, sync_message):
    // 步骤1：验证消息类型
    if sync_message.type != "CardUpdate":
        log_warn("Unknown sync message type: " + sync_message.type)
        return error "UnknownMessageType"
    
    // 步骤2：获取卡片的本地 Loro 文档
    card_id = sync_message.card_id
    local_loro_doc = load_loro_document(card_id)
    
    if local_loro_doc is error:
        log_error("Failed to load local document: " + card_id)
        return error

    // 步骤3：合并传入的更改
    // 设计决策：CRDT自动解决冲突
    // 注意：简单字段使用最后写入优先，文本使用操作转换
    result = local_loro_doc.import_updates(sync_message.updates)
    
    if result is error:
        log_error("Failed to import updates: " + result.error)
        return error

    // 步骤4：提交变更
    local_loro_doc.commit()

    // 步骤5：更新本地存储
    // 注意：订阅回调会自动更新 SQLite
    card = convert_loro_to_card(local_loro_doc)
    
    log_info("Successfully merged updates for card: " + card_id)

    // 步骤6：如果需要，传播到其他对等点
    // 设计决策：避免循环传播
    if has_new_changes(local_loro_doc):
        broadcast_to_other_peers(local_loro_doc, exclude: peer_id)

    return success

function has_new_changes(loro_doc):
    // 检查文档是否有新变更
    // 设计决策：比较版本向量
    current_version = loro_doc.get_version_vector()
    last_known_version = get_last_known_version(loro_doc.id)
    
    return current_version != last_known_version

function broadcast_to_other_peers(loro_doc, exclude):
    // 广播到其他对等点（排除发送者）
    updates = loro_doc.export_updates()
    
    for each peer_id in online_peers:
        if peer_id != exclude:
            peer = get_peer_connection(peer_id)
            send_sync_message(peer, {
                type: "CardUpdate",
                card_id: loro_doc.id,
                updates: updates
            })
```

---

## 需求：按池过滤同步

系统应仅同步当前池内的数据。

### 场景：仅同步当前池数据

- **前置条件**: 设备在 pool_A 中
- **并且**: 网络上存在 pool_B
- **操作**: 与对等点同步
- **预期结果**: 仅应同步 pool_A 数据
- **并且**: pool_B 数据不应被传输

**实现逻辑**:

```
function filter_sync_by_pool(sync_message):
    // 步骤1：从消息中提取池ID
    message_pool_id = sync_message.pool_id
    
    // 步骤2：获取当前池ID
    current_pool_id = get_current_pool_id()

    // 步骤3：验证池成员资格
    // 设计决策：拒绝跨池同步以维护数据隔离
    if message_pool_id != current_pool_id:
        log_warn("Rejecting sync from different pool: " + message_pool_id)
        reject_message("Pool mismatch")
        return error "PoolMismatch"

    // 步骤4：仅处理当前池的同步
    // 注意：这确保了不同池之间的数据隐私
    process_sync_message(sync_message)
    
    return success
```

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

**性能特征**:
- **连接建立**: < 1 秒
- **同步延迟**: < 100ms（本地网络）
- **并发连接**: 支持 100+ 对等点
- **内存使用**: ~10MB + 每连接 1MB

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

**测试文件**: `rust/tests/sync_service_test.rs`

**单元测试**:
- `it_should_create_sync_service_with_valid_config()` - 创建同步服务
- `it_should_reject_invalid_config()` - 拒绝无效配置
- `it_should_track_online_peers()` - 跟踪在线对等点
- `it_should_handle_peer_disconnection()` - 处理断开连接
- `it_should_return_initial_status_with_zero_peers()` - 初始状态
- `it_should_return_independent_status_copies()` - 独立副本
- `it_should_discover_peers_via_mdns()` - mDNS 发现
- `it_should_reject_peer_on_pool_hash_mismatch()` - 握手池校验

**集成测试**:
- `it_should_sync_changes_between_peers()` - 对等点间同步
- `it_should_handle_concurrent_changes()` - CRDT 冲突解决
- `it_should_filter_sync_by_pool()` - 基于池的过滤
- `it_should_broadcast_to_multiple_peers()` - 多对等点广播
- `it_should_handle_network_interruption()` - 网络中断恢复

**验收标准**:
- [x] 所有单元测试通过
- [x] 集成测试通过
- [x] 对等点发现在本地网络上工作
- [x] CRDT 正确合并并发更改
- [x] 池过滤正确执行
- [x] 代码审查通过
