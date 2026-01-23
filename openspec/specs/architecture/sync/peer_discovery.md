# Peer Discovery Architecture Specification
# 对等点发现架构规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: Active

**Dependencies**: [./service.md](./service.md), [../storage/device_config.md](../storage/device_config.md)
**依赖**: [./service.md](./service.md), [../storage/device_config.md](../storage/device_config.md)

**Related Tests**: `rust/tests/peer_discovery_test.rs`
**相关测试**: `rust/tests/peer_discovery_test.rs`

---

## Overview
## 概述

This specification defines the peer discovery mechanism for CardMind's P2P synchronization, using mDNS (Multicast DNS) for automatic local network discovery with privacy protection.

本规格定义了 CardMind P2P 同步的对等点发现机制，使用 mDNS（多播 DNS）进行自动本地网络发现并提供隐私保护。

**Key Features**:
**核心特性**:
- **Zero-Configuration**: Automatic peer discovery without manual setup
- **零配置**: 无需手动设置的自动对等点发现
- **Local Network Only**: Discovery limited to local network for privacy
- **仅限本地网络**: 发现限制在本地网络以保护隐私
- **Pool-Based Filtering**: Only discover peers in the same pool
- **基于池的过滤**: 仅发现同一池中的对等点
- **Privacy Protection**: Device names obfuscated in mDNS announcements
- **隐私保护**: mDNS 公告中的设备名称混淆

---

## Requirement: mDNS Service Discovery
## 需求：mDNS 服务发现

The system SHALL use mDNS to discover CardMind peers on the local network.

系统应使用 mDNS 在本地网络上发现 CardMind 对等点。

### Scenario: Announce service on local network
### 场景：在本地网络上公告服务

- **GIVEN**: A device has joined a pool
- **前置条件**: 设备已加入池
- **WHEN**: The sync service starts
- **操作**: 同步服务启动
- **THEN**: The device SHALL announce itself via mDNS
- **预期结果**: 设备应通过 mDNS 公告自己
- **AND**: The announcement SHALL include pool_id (hashed)
- **并且**: 公告应包含 pool_id（哈希）
- **AND**: The announcement SHALL include device_id (obfuscated)
- **并且**: 公告应包含 device_id（混淆）
- **AND**: The announcement SHALL include service port
- **并且**: 公告应包含服务端口

**mDNS Service Type**:
**mDNS 服务类型**:
```
_cardmind._tcp.local
```

**Service Instance Name Format**:
**服务实例名称格式**:
```
<obfuscated_device_id>._cardmind._tcp.local
```

**TXT Record Fields**:
**TXT 记录字段**:
```
pool_hash=<sha256(pool_id)[:16]>
version=1.0.0
protocol=loro-sync
```

**Implementation**:
**实现**:

```
function announce_service(device_id, pool_id, port):
    // Step 1: Initialize mDNS service daemon
    // 步骤1：初始化 mDNS 服务守护进程
    mdns_daemon = create_mdns_daemon()

    // Step 2: Obfuscate identifiers for privacy protection
    // 步骤2：混淆标识符以保护隐私
    // Design decision: Use SHA256 hash to prevent device tracking
    // 设计决策：使用 SHA256 哈希防止设备跟踪
    obfuscated_device_id = hash_sha256(device_id).take_first(8_chars)
    pool_hash = hash_sha256(pool_id).take_first(16_chars)

    // Step 3: Construct service information
    // 步骤3：构造服务信息
    service_info = {
        service_type: "_cardmind._tcp.local",
        instance_name: obfuscated_device_id + "._cardmind._tcp.local",
        hostname: get_local_hostname() + ".local",
        port: port,
        txt_records: {
            "pool_hash": pool_hash,
            "version": "1.0.0",
            "protocol": "loro-sync"
        }
    }

    // Step 4: Register service with mDNS
    // 步骤4：向 mDNS 注册服务
    // Note: Service will be announced on all network interfaces
    // 注意：服务将在所有网络接口上公告
    mdns_daemon.register(service_info)

    log("mDNS service announced successfully")
    return success
```

### Scenario: Discover peers on local network
### 场景：在本地网络上发现对等点

- **GIVEN**: Multiple devices in the same pool are on the local network
- **前置条件**: 同一池中的多个设备在本地网络上
- **WHEN**: A device starts peer discovery
- **操作**: 设备启动对等点发现
- **THEN**: The device SHALL discover other CardMind instances
- **预期结果**: 设备应发现其他 CardMind 实例
- **AND**: Only peers with matching pool_hash SHALL be discovered
- **并且**: 仅应发现具有匹配 pool_hash 的对等点
- **AND**: Discovered peers SHALL be added to the peer list
- **并且**: 发现的对等点应添加到对等点列表

**Implementation**:
**实现**:

```
function discover_peers(pool_id, on_peer_discovered_callback):
    // Step 1: Initialize mDNS browser
    // 步骤1：初始化 mDNS 浏览器
    mdns_daemon = create_mdns_daemon()

    // Step 2: Calculate expected pool hash for filtering
    // 步骤2：计算预期的池哈希用于过滤
    // Design decision: Hash pool_id to match announced services
    // 设计决策：哈希 pool_id 以匹配公告的服务
    expected_pool_hash = hash_sha256(pool_id).take_first(16_chars)

    // Step 3: Start browsing for CardMind services
    // 步骤3：开始浏览 CardMind 服务
    service_type = "_cardmind._tcp.local"
    event_stream = mdns_daemon.browse(service_type)

    // Step 4: Process discovery events asynchronously
    // 步骤4：异步处理发现事件
    // Note: Runs in background to continuously monitor network
    // 注意：在后台运行以持续监控网络
    spawn_background_task:
        for each event in event_stream:
            if event.type == "ServiceResolved":
                // Extract service information
                // 提取服务信息
                peer_pool_hash = event.txt_records.get("pool_hash")

                // Filter by pool membership
                // 按池成员资格过滤
                if peer_pool_hash == expected_pool_hash:
                    // Create peer information
                    // 创建对等点信息
                    discovered_peer = {
                        address: event.ip_address,
                        port: event.port,
                        pool_hash: peer_pool_hash
                    }

                    // Notify application of discovered peer
                    // 通知应用程序发现的对等点
                    on_peer_discovered_callback(discovered_peer)

            else if event.type == "ServiceRemoved":
                // Handle peer going offline
                // 处理对等点离线
                log("Peer removed from network")

    return success

// Data structure for discovered peer
// 发现的对等点的数据结构
structure DiscoveredPeer:
    address: IP address or null
    port: network port number
    pool_hash: hashed pool identifier
```

---

## Requirement: Pool-Based Filtering
## 需求：基于池的过滤

The system SHALL only discover and connect to peers in the same pool.

系统应仅发现并连接到同一池中的对等点。

### Scenario: Filter peers by pool hash
### 场景：按池哈希过滤对等点

- **GIVEN**: Device A is in pool_1
- **前置条件**: 设备 A 在 pool_1 中
- **AND**: Device B is in pool_1
- **并且**: 设备 B 在 pool_1 中
- **AND**: Device C is in pool_2
- **并且**: 设备 C 在 pool_2 中
- **WHEN**: Device A discovers peers
- **操作**: 设备 A 发现对等点
- **THEN**: Device A SHALL discover Device B
- **预期结果**: 设备 A 应发现设备 B
- **AND**: Device A SHALL NOT discover Device C
- **并且**: 设备 A 不应发现设备 C

**Rationale**:
**理由**:
- Prevents accidental data leakage between pools
- 防止池之间的意外数据泄漏
- Ensures privacy and data isolation
- 确保隐私和数据隔离
- Reduces network traffic by filtering early
- 通过早期过滤减少网络流量

---

## Requirement: Privacy Protection
## 需求：隐私保护

The system SHALL protect user privacy by obfuscating device identifiers in mDNS announcements.

系统应通过在 mDNS 公告中混淆设备标识符来保护用户隐私。

### Scenario: Device ID is obfuscated
### 场景：设备 ID 被混淆

- **GIVEN**: A device with ID "device_12345"
- **前置条件**: 设备 ID 为 "device_12345"
- **WHEN**: The device announces itself via mDNS
- **操作**: 设备通过 mDNS 公告自己
- **THEN**: The mDNS instance name SHALL NOT contain the full device ID
- **预期结果**: mDNS 实例名称不应包含完整的设备 ID
- **AND**: The instance name SHALL use a hash of the device ID
- **并且**: 实例名称应使用设备 ID 的哈希

### Scenario: Pool ID is hashed
### 场景：池 ID 被哈希

- **GIVEN**: A device in pool "pool_abc123"
- **前置条件**: 设备在池 "pool_abc123" 中
- **WHEN**: The device announces itself via mDNS
- **操作**: 设备通过 mDNS 公告自己
- **THEN**: The TXT record SHALL contain a hash of the pool ID
- **预期结果**: TXT 记录应包含池 ID 的哈希
- **AND**: The TXT record SHALL NOT contain the full pool ID
- **并且**: TXT 记录不应包含完整的池 ID

**Privacy Considerations**:
**隐私考虑**:
- **Device ID Obfuscation**: Prevents tracking of specific devices
- **设备 ID 混淆**: 防止跟踪特定设备
- **Pool ID Hashing**: Prevents pool enumeration attacks
- **池 ID 哈希**: 防止池枚举攻击
- **Local Network Only**: mDNS is not routable beyond local network
- **仅限本地网络**: mDNS 不可路由到本地网络之外
- **No Personal Information**: No user names or device names in announcements
- **无个人信息**: 公告中无用户名或设备名

---

## Requirement: Connection Establishment
## 需求：连接建立

The system SHALL establish P2P connections to discovered peers.

系统应建立到发现的对等点的 P2P 连接。

### Scenario: Connect to discovered peer
### 场景：连接到发现的对等点

- **GIVEN**: A peer has been discovered via mDNS
- **前置条件**: 通过 mDNS 发现了对等点
- **WHEN**: Attempting to connect to the peer
- **操作**: 尝试连接到对等点
- **THEN**: A TCP connection SHALL be established
- **预期结果**: 应建立 TCP 连接
- **AND**: The connection SHALL be authenticated
- **并且**: 连接应被认证
- **AND**: The peer SHALL be added to the active peer list
- **并且**: 对等点应添加到活动对等点列表

**Implementation**:
**实现**:

```
function connect_to_peer(discovered_peer, pool_id):
    // Step 1: Validate peer address
    // 步骤1：验证对等点地址
    if discovered_peer.address is null:
        return error("Invalid peer address")

    // Step 2: Establish TCP connection
    // 步骤2：建立 TCP 连接
    // Note: Uses discovered IP address and port
    // 注意：使用发现的 IP 地址和端口
    tcp_stream = connect_tcp(discovered_peer.address, discovered_peer.port)

    // Step 3: Create peer connection wrapper
    // 步骤3：创建对等点连接包装器
    peer_connection = create_peer_connection(tcp_stream)

    // Step 4: Perform authentication handshake
    // 步骤4：执行认证握手
    // Design decision: Verify pool membership before data exchange
    // 设计决策：在数据交换前验证池成员资格
    peer_connection.perform_handshake(pool_id)

    log("Successfully connected to peer")
    return peer_connection


function perform_handshake(connection, our_pool_id):
    // Handshake protocol to verify pool membership
    // 握手协议以验证池成员资格

    // Step 1: Send our pool ID to peer
    // 步骤1：向对等点发送我们的池 ID
    connection.send_message({
        type: "PoolId",
        pool_id: our_pool_id
    })

    // Step 2: Receive peer's pool ID
    // 步骤2：接收对等点的池 ID
    peer_message = connection.receive_message()
    if peer_message.type != "PoolId":
        return error("Invalid handshake message")

    // Step 3: Verify pool IDs match
    // 步骤3：验证池 ID 匹配
    // Design decision: Reject connection if pools don't match
    // 设计决策：如果池不匹配则拒绝连接
    if peer_message.pool_id != our_pool_id:
        return error("Pool mismatch - peer in different pool")

    // Step 4: Exchange protocol versions
    // 步骤4：交换协议版本
    connection.send_message({
        type: "Version",
        version: "1.0.0"
    })

    peer_version = connection.receive_message()
    if peer_version.type != "Version":
        return error("Invalid handshake message")

    // Step 5: Verify version compatibility
    // 步骤5：验证版本兼容性
    // Note: Simple major version check for compatibility
    // 注意：简单的主版本检查以确保兼容性
    if not is_compatible_version(peer_version.version):
        return error("Incompatible protocol version")

    log("Handshake completed successfully")
    return success


function is_compatible_version(peer_version):
    // Check if protocol versions are compatible
    // 检查协议版本是否兼容
    // Design decision: Major version must match (1.x.x compatible with 1.y.z)
    // 设计决策：主版本必须匹配（1.x.x 与 1.y.z 兼容）
    our_major_version = extract_major_version("1.0.0")
    peer_major_version = extract_major_version(peer_version)

    return our_major_version == peer_major_version
```

---

## Requirement: Peer Lifecycle Management
## 需求：对等点生命周期管理

The system SHALL manage the lifecycle of peer connections, including detection of offline peers.

系统应管理对等点连接的生命周期，包括检测离线对等点。

### Scenario: Detect peer going offline
### 场景：检测对等点离线

- **GIVEN**: A peer is connected
- **前置条件**: 对等点已连接
- **WHEN**: The peer goes offline
- **操作**: 对等点离线
- **THEN**: The mDNS service SHALL detect the removal
- **预期结果**: mDNS 服务应检测到移除
- **AND**: The peer SHALL be removed from the active peer list
- **并且**: 对等点应从活动对等点列表中移除
- **AND**: The connection SHALL be closed
- **并且**: 连接应被关闭

### Scenario: Reconnect to peer when it comes back online
### 场景：对等点重新上线时重新连接

- **GIVEN**: A peer was previously connected but went offline
- **前置条件**: 对等点之前已连接但已离线
- **WHEN**: The peer comes back online
- **操作**: 对等点重新上线
- **THEN**: The peer SHALL be rediscovered via mDNS
- **预期结果**: 应通过 mDNS 重新发现对等点
- **AND**: A new connection SHALL be established automatically
- **并且**: 应自动建立新连接

---

## Implementation Details
## 实现细节

**Technology Stack**:
**技术栈**:
- **mdns-sd**: Rust mDNS library for service discovery
- **mdns-sd**: 用于服务发现的 Rust mDNS 库
- **tokio**: Async runtime for network operations
- **tokio**: 用于网络操作的异步运行时
- **sha2**: SHA-256 hashing for privacy protection
- **sha2**: 用于隐私保护的 SHA-256 哈希

**Design Patterns**:
**设计模式**:
- **Observer Pattern**: Callback-based peer discovery
- **观察者模式**: 基于回调的对等点发现
- **Service Discovery Pattern**: mDNS for zero-configuration networking
- **服务发现模式**: 用于零配置网络的 mDNS
- **Privacy by Design**: Obfuscation and hashing built-in
- **隐私设计**: 内置混淆和哈希

**Performance Considerations**:
**性能考虑**:
- **Lazy Discovery**: Only discover when needed
- **延迟发现**: 仅在需要时发现
- **Connection Pooling**: Reuse connections to same peers
- **连接池**: 复用到相同对等点的连接
- **Timeout Handling**: Detect and remove stale connections
- **超时处理**: 检测并移除过期连接

---

## Test Coverage
## 测试覆盖

**Test File**: `rust/tests/peer_discovery_test.rs`
**测试文件**: `rust/tests/peer_discovery_test.rs`

**Unit Tests**:
**单元测试**:
- `test_announce_service()` - Service announcement
- `test_announce_service()` - 服务公告
- `test_discover_peers()` - Peer discovery
- `test_discover_peers()` - 对等点发现
- `test_pool_filtering()` - Pool-based filtering
- `test_pool_filtering()` - 基于池的过滤
- `test_device_id_obfuscation()` - Device ID obfuscation
- `test_device_id_obfuscation()` - 设备 ID 混淆
- `test_pool_id_hashing()` - Pool ID hashing
- `test_pool_id_hashing()` - 池 ID 哈希
- `test_connection_establishment()` - Connection establishment
- `test_connection_establishment()` - 连接建立
- `test_peer_offline_detection()` - Offline detection
- `test_peer_offline_detection()` - 离线检测

**Integration Tests**:
**集成测试**:
- Multi-device discovery scenario
- 多设备发现场景
- Cross-pool isolation test
- 跨池隔离测试
- Reconnection after network interruption
- 网络中断后重新连接

**Acceptance Criteria**:
**验收标准**:
- [ ] All unit tests pass
- [ ] 所有单元测试通过
- [ ] Peers discovered within 5 seconds
- [ ] 5 秒内发现对等点
- [ ] Pool filtering works correctly
- [ ] 池过滤正确工作
- [ ] Privacy protection verified
- [ ] 隐私保护已验证
- [ ] Code review approved
- [ ] 代码审查通过

---

## Related Documents
## 相关文档

**Architecture Specs**:
**架构规格**:
- [./service.md](./service.md) - P2P sync service
- [./service.md](./service.md) - P2P 同步服务
- [./conflict_resolution.md](./conflict_resolution.md) - Conflict resolution
- [./conflict_resolution.md](./conflict_resolution.md) - 冲突解决
- [../storage/device_config.md](../storage/device_config.md) - Device configuration
- [../storage/device_config.md](../storage/device_config.md) - 设备配置

**Domain Specs**:
**领域规格**:
- [../../domain/pool/model.md](../../domain/pool/model.md) - Pool model
- [../../domain/pool/model.md](../../domain/pool/model.md) - 池模型

**ADRs**:
**架构决策记录**:
- [../../../docs/adr/0004-mdns-discovery.md](../../../docs/adr/0004-mdns-discovery.md) - mDNS discovery decision
- [../../../docs/adr/0004-mdns-discovery.md](../../../docs/adr/0004-mdns-discovery.md) - mDNS 发现决策

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23

**Authors**: CardMind Team
**作者**: CardMind Team
