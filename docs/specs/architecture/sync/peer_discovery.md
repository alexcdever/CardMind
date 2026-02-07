# 对等点发现架构规格

**状态**: 活跃
**依赖**: [./service.md](./service.md), [../storage/device_config.md](../storage/device_config.md)
**相关测试**: `rust/tests/mdns_discovery_feature_test.rs`

---

## 概述

本规格定义了 CardMind P2P 同步的对等点发现机制，使用 libp2p mDNS 在本地网络中自动发现对等点，并在连接后完成池验证。

**技术栈**:
- **libp2p mdns** - 对等点发现
- **tokio** - 异步运行时

**核心特性**:
- **零配置**: 无需手动设置的自动对等点发现
- **仅限本地网络**: 发现限制在本地网络以保护隐私
- **连接后池验证**: 发现后连接，握手阶段验证是否同池
- **隐私保护**: mDNS 不携带池信息或用户信息

---

## 需求：mDNS 服务发现

系统应使用 libp2p mDNS 在本地网络上发现 CardMind 对等点。

### 场景：加入池后启动 mDNS 发现

- **前置条件**: 设备已加入池
- **操作**: 同步服务启动
- **预期结果**: 设备通过 libp2p mDNS 广播并监听对等点
- **并且**: 广播中不包含池信息或用户信息

### 场景：在本地网络上发现对等点

- **前置条件**: 同一池中的多个设备在本地网络上
- **操作**: 设备启动对等点发现
- **预期结果**: 设备应发现其他 CardMind 实例
- **并且**: 发现事件应触发连接尝试
- **并且**: 池验证在连接后的握手阶段完成

**实现逻辑**:

```
function discover_peers():
    // libp2p mDNS 行为启动后自动广播与监听
    // 发现事件仅用于触发连接尝试，不做池过滤
    on mdns_event.discovered(peer_id, multiaddr):
        log_info("Discovered peer: " + peer_id)
        attempt_connection(peer_id, multiaddr)
    on mdns_event.expired(peer_id):
        log_info("Peer expired: " + peer_id)
        mark_peer_offline(peer_id)

// 发现的对等点的数据结构
structure DiscoveredPeer:
    peer_id: string
    multiaddr: string
```

---

## 需求：隐私保护

系统应避免在 mDNS 广播中暴露池与用户信息。

### 场景：设备 ID 被混淆

- **前置条件**: 设备已加入池并启动 mDNS
- **操作**: 设备通过 mDNS 广播自己
- **预期结果**: 广播中不包含 pool_id、pool_name 或 password

**隐私考虑**:
- **仅限本地网络**: mDNS 不可路由到本地网络之外
- **无池信息**: 广播不包含 pool_id/pool_name/password
- **无个人信息**: 广播不包含用户昵称或成员信息

---

## 需求：连接建立

系统应建立到发现的对等点的 P2P 连接。

### 场景：连接到发现的对等点

- **前置条件**: 通过 mDNS 发现了对等点
- **操作**: 尝试连接到对等点
- **预期结果**: 应建立 TCP 连接
- **并且**: 连接应被认证
- **并且**: 对等点应添加到活动对等点列表

**实现逻辑**:

```
function connect_to_peer(discovered_peer, pool_id, pool_password):
    // 步骤1：验证对等点地址
    if discovered_peer.address is null:
        log_error("Invalid peer address")
        return error "InvalidPeerAddress"

    // 步骤2：建立 TCP 连接
    // 注意：使用发现的 IP 地址和端口
    try:
        tcp_stream = connect_tcp(discovered_peer.address, discovered_peer.port, timeout: 10_seconds)
    catch error:
        log_error("Failed to connect to peer: " + error)
        return error "ConnectionFailed"

    // 步骤3：创建对等点连接包装器
    peer_connection = create_peer_connection(tcp_stream)

    // 步骤4：执行认证握手
    // 设计决策：在数据交换前验证池成员资格
    result = perform_handshake(peer_connection, pool_id, pool_password)
    
    if result is error:
        tcp_stream.close()
        return result

    log_info("Successfully connected to peer: " + discovered_peer.hostname)
    return peer_connection


function perform_handshake(connection, our_pool_id, pool_password):
    // 握手协议以验证池成员资格（使用 pool_hash）

    // 步骤1：向对等点发送我们的 pool_hash
    // 设计决策：pool_hash = HKDF-SHA256(salt=pool_id, input=password, len=32)
    our_pool_hash = derive_pool_hash(our_pool_id, pool_password)
    try:
        connection.send_message({
            type: "PoolHash",
            pool_hash: our_pool_hash
        })
    catch error:
        log_error("Failed to send pool ID: " + error)
        return error "HandshakeFailed"

    // 步骤2：接收对等点的 pool_hash
    try:
        peer_message = connection.receive_message(timeout: 5_seconds)
    catch error:
        log_error("Failed to receive peer pool ID: " + error)
        return error "HandshakeFailed"
    
    if peer_message.type != "PoolHash":
        log_error("Invalid handshake message type: " + peer_message.type)
        return error "InvalidHandshake"

    // 步骤3：验证 pool_hash 匹配
    // 设计决策：如果不匹配则拒绝连接
    if peer_message.pool_hash != our_pool_hash:
        log_warn("Pool mismatch: peer hash != our hash")
        return error "PoolMismatch"

    log_info("Handshake completed successfully")
    return success
```

---

## 需求：对等点生命周期管理

系统应管理对等点连接的生命周期，包括检测离线对等点。

### 场景：检测对等点离线

- **前置条件**: 对等点已连接
- **操作**: 对等点离线
- **预期结果**: mDNS 服务应检测到移除
- **并且**: 对等点应从活动对等点列表中移除
- **并且**: 连接应被关闭

### 场景：对等点重新上线时重新连接

- **前置条件**: 对等点之前已连接但已离线
- **操作**: 对等点重新上线
- **预期结果**: 应通过 mDNS 重新发现对等点
- **并且**: 应自动建立新连接

**实现逻辑**:

```
function on_peer_removed(hostname):
    // 处理对等点离线事件
    // 步骤1：从活动对等点列表中移除
    peer = find_peer_by_hostname(hostname)
    
    if peer is not null:
        // 步骤2：关闭连接
        if peer.connection is not null:
            peer.connection.close()
        
        // 步骤3：从列表中移除
        remove_peer_from_list(peer)
        
        log_info("Peer removed: " + hostname)
    else:
        log_debug("Peer not found in active list: " + hostname)

function on_peer_rediscovered(discovered_peer):
    // 处理对等点重新上线
    // 步骤1：检查是否已连接
    existing_peer = find_peer_by_address(discovered_peer.address)
    
    if existing_peer is not null:
        log_debug("Peer already connected: " + discovered_peer.hostname)
        return
    
    // 步骤2：尝试重新连接
    log_info("Peer rediscovered, attempting to reconnect: " + discovered_peer.hostname)
    
    connection = connect_to_peer(discovered_peer, current_pool_id)
    
    if connection is not error:
        add_peer_to_list(discovered_peer, connection)
        log_info("Successfully reconnected to peer: " + discovered_peer.hostname)
    else:
        log_warn("Failed to reconnect to peer: " + connection.error)

structure PeerManager:
    active_peers: list of Peer
    
    function add_peer(discovered_peer, connection):
        peer = Peer {
            hostname: discovered_peer.hostname,
            address: discovered_peer.address,
            port: discovered_peer.port,
            connection: connection,
            last_seen: current_timestamp()
        }
        
        active_peers.add(peer)
        log_info("Added peer to active list: " + peer.hostname)
    
    function remove_peer(peer):
        active_peers.remove(peer)
        log_info("Removed peer from active list: " + peer.hostname)
    
    function find_peer_by_hostname(hostname):
        for each peer in active_peers:
            if peer.hostname == hostname:
                return peer
        return null
    
    function find_peer_by_address(address):
        for each peer in active_peers:
            if peer.address == address:
                return peer
        return null
```

---

## 补充说明

**技术栈**:
- **libp2p mdns** - 对等点发现
- **tokio** - 异步运行时
- **hkdf** + **sha2** - pool_hash 派生

**设计模式**:
- **观察者模式**: 基于回调的对等点发现
- **服务发现模式**: 用于零配置网络的 mDNS
- **隐私设计**: 内置混淆和哈希

**性能考虑**:
- **延迟发现**: 仅在需要时发现
- **连接池**: 复用到相同对等点的连接
- **超时处理**: 检测并移除过期连接

**网络配置**:
- **mDNS 端口**: 5353（标准 mDNS 端口）
- **服务端口**: 可配置（默认 8080）
- **发现间隔**: 持续监听
- **连接超时**: 10 秒

---

## 相关文档

**架构规格**:
- [./service.md](./service.md) - P2P 同步服务
- [./conflict_resolution.md](./conflict_resolution.md) - 冲突解决
- [../storage/device_config.md](../storage/device_config.md) - 设备配置

**领域规格**:
- [../../domain/pool.md](../../domain/pool.md) - 池模型

**架构决策记录**:
- ADR-0004: mDNS 发现 - mDNS 对等点发现决策

---

## 测试覆盖

**测试文件**: `rust/tests/mdns_discovery_feature_test.rs`

**单元测试**:
- `test_mdns_discovery_creation()` - mDNS 初始化
- `test_mdns_peer_discovery()` - mDNS 互发现
- `it_should_reject_peer_on_pool_hash_mismatch()` - 握手池校验
- `it_should_not_start_p2p_when_not_joined()` - 未加入池不启动

**功能测试**:
- `test_multi_device_discovery()` - 多设备发现场景
- `test_network_interruption_recovery()` - 网络中断后重新连接

**验收标准**:
- [x] 所有单元测试通过
- [x] 5 秒内发现对等点
- [x] 连接后池校验正确执行
- [x] 隐私保护已验证
- [x] 代码审查通过
