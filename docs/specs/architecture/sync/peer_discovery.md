# 对等点发现架构规格

**状态**: 活跃
**依赖**: [./service.md](./service.md), [../storage/device_config.md](../storage/device_config.md)
**相关测试**: `rust/tests/peer_discovery_test.rs`

---

## 概述

本规格定义了 CardMind P2P 同步的对等点发现机制，使用 mDNS（多播 DNS）进行自动本地网络发现并提供隐私保护。

**技术栈**:
- **mdns-sd** = "0.10" - Rust mDNS 库
- **tokio** - 异步运行时
- **sha2** = "0.10" - SHA-256 哈希

**核心特性**:
- **零配置**: 无需手动设置的自动对等点发现
- **仅限本地网络**: 发现限制在本地网络以保护隐私
- **基于池的过滤**: 仅发现同一池中的对等点
- **隐私保护**: mDNS 公告中的设备名称混淆

---

## 需求：mDNS 服务发现

系统应使用 mDNS 在本地网络上发现 CardMind 对等点。

### 场景：在本地网络上公告服务

- **前置条件**: 设备已加入池
- **操作**: 同步服务启动
- **预期结果**: 设备应通过 mDNS 公告自己
- **并且**: 公告应包含 pool_id（哈希）
- **并且**: 公告应包含 device_id（混淆）
- **并且**: 公告应包含服务端口

**服务类型**:
```
_cardmind._tcp.local
```

**服务实例名称格式**:
```
<obfuscated_device_id>._cardmind._tcp.local
```

**TXT 记录**:
```
pool_hash=<sha256(pool_id)[:16]>
version=1.0.0
protocol=loro-sync
```

**实现逻辑**:

```
function announce_service(device_id, pool_id, port):
    // 步骤1：初始化 mDNS 服务守护进程
    mdns_daemon = create_mdns_daemon()

    // 步骤2：混淆标识符以保护隐私
    // 设计决策：使用 SHA256 哈希防止设备跟踪
    obfuscated_device_id = hash_sha256(device_id).take_first(8_chars)
    pool_hash = hash_sha256(pool_id).take_first(16_chars)

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

    // 步骤4：向 mDNS 注册服务
    // 注意：服务将在所有网络接口上公告
    try:
        mdns_daemon.register(service_info)
        log_info("mDNS service announced successfully on port " + port)
        return success
    catch error:
        log_error("Failed to announce mDNS service: " + error)
        return error

function hash_sha256(input):
    // 使用 SHA-256 哈希输入字符串
    hash = sha256_hash(input)
    hex_string = to_hex_string(hash)
    return hex_string

function get_local_hostname():
    // 获取本地主机名
    // 设计决策：使用系统主机名作为 mDNS 主机名
    hostname = system_hostname()
    
    if hostname is empty:
        // 回退到默认名称
        hostname = "cardmind-device"
    
    return hostname
```

### 场景：在本地网络上发现对等点

- **前置条件**: 同一池中的多个设备在本地网络上
- **操作**: 设备启动对等点发现
- **预期结果**: 设备应发现其他 CardMind 实例
- **并且**: 仅应发现具有匹配 pool_hash 的对等点
- **并且**: 发现的对等点应添加到对等点列表

**实现逻辑**:

```
function discover_peers(pool_id, on_peer_discovered_callback):
    // 步骤1：初始化 mDNS 浏览器
    mdns_daemon = create_mdns_daemon()

    // 步骤2：计算预期的池哈希用于过滤
    // 设计决策：哈希 pool_id 以匹配公告的服务
    expected_pool_hash = hash_sha256(pool_id).take_first(16_chars)

    // 步骤3：开始浏览 CardMind 服务
    service_type = "_cardmind._tcp.local"
    
    try:
        event_stream = mdns_daemon.browse(service_type)
    catch error:
        log_error("Failed to start mDNS browsing: " + error)
        return error

    // 步骤4：异步处理发现事件
    // 注意：在后台运行以持续监控网络
    spawn_background_task:
        for each event in event_stream:
            if event.type == "ServiceResolved":
                // 提取服务信息
                peer_pool_hash = event.txt_records.get("pool_hash")

                // 按池成员资格过滤
                if peer_pool_hash == expected_pool_hash:
                    // 创建对等点信息
                    discovered_peer = {
                        address: event.ip_address,
                        port: event.port,
                        pool_hash: peer_pool_hash,
                        hostname: event.hostname
                    }

                    log_info("Discovered peer: " + event.hostname + " at " + event.ip_address)

                    // 通知应用程序发现的对等点
                    on_peer_discovered_callback(discovered_peer)
                else:
                    log_debug("Filtered out peer from different pool")

            else if event.type == "ServiceRemoved":
                // 处理对等点离线
                log_info("Peer removed from network: " + event.hostname)
                on_peer_removed_callback(event.hostname)

    log_info("Peer discovery started for pool: " + pool_id)
    return success

// 发现的对等点的数据结构
structure DiscoveredPeer:
    address: IP address or null
    port: network port number
    pool_hash: hashed pool identifier
    hostname: string
```

---

## 需求：基于池的过滤

系统应仅发现并连接到同一池中的对等点。

### 场景：按池哈希过滤对等点

- **前置条件**: 设备 A 在 pool_1 中
- **并且**: 设备 B 在 pool_1 中
- **并且**: 设备 C 在 pool_2 中
- **操作**: 设备 A 发现对等点
- **预期结果**: 设备 A 应发现设备 B
- **并且**: 设备 A 不应发现设备 C

**理由**:
- 防止池之间的意外数据泄漏
- 确保隐私和数据隔离
- 通过早期过滤减少网络流量

**实现逻辑**:

```
function filter_peer_by_pool(peer_pool_hash, expected_pool_hash):
    // 验证对等点是否在同一池中
    // 设计决策：使用哈希比较以保护隐私
    
    if peer_pool_hash == expected_pool_hash:
        log_debug("Peer pool hash matches")
        return true
    else:
        log_debug("Peer pool hash does not match: " + peer_pool_hash + " != " + expected_pool_hash)
        return false
```

---

## 需求：隐私保护

系统应通过在 mDNS 公告中混淆设备标识符来保护用户隐私。

### 场景：设备 ID 被混淆

- **前置条件**: 设备 ID 为 "device_12345"
- **操作**: 设备通过 mDNS 公告自己
- **预期结果**: mDNS 实例名称不应包含完整的设备 ID
- **并且**: 实例名称应使用设备 ID 的哈希

### 场景：池 ID 被哈希

- **前置条件**: 设备在池 "pool_abc123" 中
- **操作**: 设备通过 mDNS 公告自己
- **预期结果**: TXT 记录应包含池 ID 的哈希
- **并且**: TXT 记录不应包含完整的池 ID

**隐私考虑**:
- **设备 ID 混淆**: 防止跟踪特定设备
- **池 ID 哈希**: 防止池枚举攻击
- **仅限本地网络**: mDNS 不可路由到本地网络之外
- **无个人信息**: 公告中无用户名或设备名

**实现逻辑**:

```
function obfuscate_device_id(device_id):
    // 混淆设备 ID 以保护隐私
    // 设计决策：使用 SHA-256 哈希的前 8 个字符
    
    hash = hash_sha256(device_id)
    obfuscated = hash.take_first(8_chars)
    
    log_debug("Device ID obfuscated: " + device_id + " -> " + obfuscated)
    return obfuscated

function hash_pool_id(pool_id):
    // 哈希池 ID 以保护隐私
    // 设计决策：使用 SHA-256 哈希的前 16 个字符
    
    hash = hash_sha256(pool_id)
    pool_hash = hash.take_first(16_chars)
    
    log_debug("Pool ID hashed: " + pool_id + " -> " + pool_hash)
    return pool_hash
```

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
function connect_to_peer(discovered_peer, pool_id):
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
    result = perform_handshake(peer_connection, pool_id)
    
    if result is error:
        tcp_stream.close()
        return result

    log_info("Successfully connected to peer: " + discovered_peer.hostname)
    return peer_connection


function perform_handshake(connection, our_pool_id):
    // 握手协议以验证池成员资格

    // 步骤1：向对等点发送我们的池 ID
    try:
        connection.send_message({
            type: "PoolId",
            pool_id: our_pool_id
        })
    catch error:
        log_error("Failed to send pool ID: " + error)
        return error "HandshakeFailed"

    // 步骤2：接收对等点的池 ID
    try:
        peer_message = connection.receive_message(timeout: 5_seconds)
    catch error:
        log_error("Failed to receive peer pool ID: " + error)
        return error "HandshakeFailed"
    
    if peer_message.type != "PoolId":
        log_error("Invalid handshake message type: " + peer_message.type)
        return error "InvalidHandshake"

    // 步骤3：验证池 ID 匹配
    // 设计决策：如果池不匹配则拒绝连接
    if peer_message.pool_id != our_pool_id:
        log_warn("Pool mismatch: peer in " + peer_message.pool_id + ", we are in " + our_pool_id)
        return error "PoolMismatch"

    // 步骤4：交换协议版本
    try:
        connection.send_message({
            type: "Version",
            version: "1.0.0"
        })
        
        peer_version = connection.receive_message(timeout: 5_seconds)
    catch error:
        log_error("Failed to exchange version: " + error)
        return error "HandshakeFailed"
    
    if peer_version.type != "Version":
        log_error("Invalid version message type: " + peer_version.type)
        return error "InvalidHandshake"

    // 步骤5：验证版本兼容性
    // 注意：简单的主版本检查以确保兼容性
    if not is_compatible_version(peer_version.version):
        log_warn("Incompatible protocol version: " + peer_version.version)
        return error "IncompatibleVersion"

    log_info("Handshake completed successfully")
    return success


function is_compatible_version(peer_version):
    // 检查协议版本是否兼容
    // 设计决策：主版本必须匹配（1.x.x 与 1.y.z 兼容）
    our_major_version = extract_major_version("1.0.0")
    peer_major_version = extract_major_version(peer_version)

    return our_major_version == peer_major_version

function extract_major_version(version_string):
    // 从版本字符串中提取主版本号
    // 例如: "1.2.3" -> 1
    parts = version_string.split(".")
    
    if parts.length > 0:
        return parse_int(parts[0])
    else:
        return 0
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
- **mdns-sd** = "0.10" - Rust mDNS 库
- **tokio** - 异步运行时
- **sha2** = "0.10" - SHA-256 哈希

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
- [../../domain/pool/model.md](../../domain/pool/model.md) - 池模型

**架构决策记录**:
- ADR-0004: mDNS 发现 - mDNS 对等点发现决策

---

## 测试覆盖

**测试文件**: `rust/tests/peer_discovery_test.rs`

**单元测试**:
- `test_announce_service()` - 服务公告
- `test_discover_peers()` - 对等点发现
- `test_pool_filtering()` - 基于池的过滤
- `test_device_id_obfuscation()` - 设备 ID 混淆
- `test_pool_id_hashing()` - 池 ID 哈希
- `test_connection_establishment()` - 连接建立
- `test_handshake_success()` - 握手成功
- `test_handshake_pool_mismatch()` - 池不匹配
- `test_handshake_version_incompatible()` - 版本不兼容
- `test_peer_offline_detection()` - 离线检测
- `test_peer_reconnection()` - 重新连接
- `test_extract_major_version()` - 版本提取

**集成测试**:
- `test_multi_device_discovery()` - 多设备发现场景
- `test_cross_pool_isolation()` - 跨池隔离测试
- `test_network_interruption_recovery()` - 网络中断后重新连接

**验收标准**:
- [x] 所有单元测试通过
- [x] 5 秒内发现对等点
- [x] 池过滤正确工作
- [x] 隐私保护已验证
- [x] 握手协议正确执行
- [x] 代码审查通过
