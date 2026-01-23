# mDNS Privacy Protection Architecture Specification
# mDNS 隐私保护架构规格

**Version**: 1.0.0
**版本**: 1.0.0
**Status**: Active
**状态**: Active
**Dependencies**: [../../domain/pool/model.md](../../domain/pool/model.md), [../../domain/sync/model.md](../../domain/sync/model.md)
**依赖**: [../../domain/pool/model.md](../../domain/pool/model.md), [../../domain/sync/model.md](../../domain/sync/model.md)
**Related Tests**: `rust/tests/p2p/discovery_test.rs`
**相关测试**: `rust/tests/p2p/discovery_test.rs`

---

## Overview
## 概述

This specification defines the privacy protection mechanism for mDNS device discovery in CardMind. When broadcasting device information on the local network, the system only exposes non-sensitive information (device ID, default device nickname, pool ID), without exposing sensitive information such as pool names, member lists, or card counts, ensuring unauthorized devices cannot access user privacy data.

本规格定义了 CardMind 中 mDNS 设备发现的隐私保护机制。系统在局域网内广播设备信息时，仅暴露非敏感信息（设备 ID、默认设备昵称、数据池 ID），不暴露数据池名称、成员列表、卡片数量等敏感信息，确保未授权设备无法获取用户隐私数据。

**Technology Stack**:
**技术栈**:
- libp2p = "0.54" - P2P networking library (with mDNS feature)
- libp2p = "0.54" - P2P 网络库（包含 mDNS 特性）
- Noise protocol - Encrypted authentication
- Noise 协议 - 加密认证
- Yamux - Connection multiplexing
- Yamux - 连接多路复用

---

## Requirement: Minimal Information Exposure
## 需求：最小信息暴露

The system SHALL only expose non-sensitive information in mDNS broadcasts, including device ID, default device nickname, and pool ID.

系统应在 mDNS 广播中仅暴露非敏感信息，包括设备 ID、默认设备昵称和数据池 ID。

### Scenario: Broadcast information during device discovery
### 场景：设备发现时广播信息

- **GIVEN**: Device starts mDNS discovery service
- **前置条件**: 设备启动 mDNS 发现服务
- **WHEN**: Broadcast device information to local network
- **操作**: 广播设备信息到局域网
- **THEN**: Only device ID, default nickname, and pool ID list SHALL be included
- **预期结果**: 应仅包含设备 ID、默认昵称、数据池 ID 列表
- **AND**: Pool names, member lists, card counts, password hashes SHALL NOT be included
- **并且**: 不应包含数据池名称、成员列表、卡片数量、密码哈希

**Exposed Information**:
**暴露的信息**:
- ✅ `device_id`: Device identifier in UUID v7 format / UUID v7 格式的设备标识符
- ✅ `device_name`: Default nickname (format: `"Unknown-{first 5 chars of UUID}"`) / 默认昵称（格式：`"Unknown-{UUID前5位}"`）
- ✅ `pools[].pool_id`: List of pool IDs / 数据池 ID 列表

**Hidden Information**:
**隐藏的信息**:
- ❌ `pool_name`: Pool name / 数据池名称
- ❌ `member_list`: Member list / 成员列表
- ❌ `card_count`: Card count / 卡片数量
- ❌ `password_hash`: Password hash / 密码哈希
- ❌ `user_defined_nickname`: User-defined device nickname / 用户自定义设备昵称

**Implementation Logic**:
**实现逻辑**:

```
// Device information (broadcast to mDNS)
// 设备信息（广播到 mDNS）
structure DeviceInfo:
    device_id: String           // UUID v7
    device_name: String         // Default nickname
    pools: List<PoolInfo>       // Pool list

// Pool information (ID only)
// 数据池信息（仅包含 ID）
structure PoolInfo:
    pool_id: String             // UUID v7

// Serialize device information (for mDNS broadcast)
// 序列化设备信息（用于 mDNS 广播）
// Design decision: Only include non-sensitive fields
// 设计决策：仅包含非敏感字段
function serialize_device_info(device_info):
    json = {
        "device_id": device_info.device_id,
        "device_name": generate_device_name(device_info.device_id),
        "pools": [
            {"pool_id": pool.pool_id}
            for pool in device_info.pools
        ]
    }
    return json
```

---

## Requirement: Default Device Nickname Generation
## 需求：默认设备昵称生成

The system SHALL generate default device nicknames in the format "Unknown-{first 5 chars of UUID}", without using user-defined nicknames.

系统应生成默认设备昵称，格式为 "Unknown-{UUID前5位}"，不使用用户自定义昵称。

### Scenario: Generate device nickname
### 场景：生成设备昵称

- **GIVEN**: Device ID is "018c8a1b-2c3d-7e4f-8a9b-0c1d2e3f4a5b"
- **前置条件**: 设备 ID 为 "018c8a1b-2c3d-7e4f-8a9b-0c1d2e3f4a5b"
- **WHEN**: Generate default device nickname
- **操作**: 生成默认设备昵称
- **THEN**: Nickname SHALL be "Unknown-018c8"
- **预期结果**: 昵称应为 "Unknown-018c8"
- **AND**: User-configured custom nickname in settings SHALL NOT be used
- **并且**: 不应使用用户在设置中配置的自定义昵称

**Rationale**:
**理由**:
- Prevent user nicknames from leaking personal information (e.g., real name, device model)
- 防止用户昵称泄露个人信息（如真实姓名、设备型号）
- Provide basic device differentiation capability
- 提供基本的设备区分能力
- Maintain consistent privacy protection policy
- 保持一致的隐私保护策略

**Implementation Logic**:
**实现逻辑**:

```
// Generate default device nickname
// 生成默认设备昵称
// Design decision: Use UUID prefix for uniqueness without exposing user info
// 设计决策：使用 UUID 前缀保证唯一性而不暴露用户信息
function generate_device_name(device_id):
    short_id = device_id[0:5]  // Take first 5 chars
    return "Unknown-" + short_id
```

---

## Requirement: Obtain Details After Password Verification
## 需求：密码验证后获取详情

The system SHALL require new devices to verify passwords before obtaining complete pool information (name, member list, etc.).

系统应要求新设备输入密码验证后，才能获取数据池的完整信息（名称、成员列表等）。

### Scenario: New device joins pool
### 场景：新设备加入数据池

- **GIVEN**: New device discovers pool ID through mDNS
- **前置条件**: 新设备通过 mDNS 发现数据池 ID
- **WHEN**: New device attempts to join pool
- **操作**: 新设备尝试加入数据池
- **THEN**: System SHALL require password input
- **预期结果**: 系统应要求输入密码
- **AND**: After successful password verification, pool name, member list, and other details SHALL be accessible
- **并且**: 密码验证成功后，应能获取数据池名称、成员列表等详细信息

**Implementation Logic**:
**实现逻辑**:

```
// Join pool (requires password verification)
// 加入数据池（需要密码验证）
function join_pool(pool_id, password):
    // Step 1: Connect to device owning the pool
    // 步骤1：连接到拥有该数据池的设备
    peer = find_peer_with_pool(pool_id)

    // Step 2: Send join request (with password)
    // 步骤2：发送加入请求（包含密码）
    // Design decision: Include timestamp to prevent replay attacks
    // 设计决策：包含时间戳以防止重放攻击
    request = JoinRequest {
        pool_id: pool_id,
        device_id: local_device_id,
        password: password,
        timestamp: current_time()
    }

    // Step 3: Transmit via Noise encryption
    // 步骤3：通过 Noise 加密传输
    response = send_encrypted(peer, request)

    // Step 4: Obtain complete information after verification
    // 步骤4：验证成功后获取完整信息
    if response.success:
        pool_details = response.pool_details
        display("Pool name: " + pool_details.name)
        display("Member list: " + pool_details.members)
        return ok()
    else:
        return error("incorrect_password")
```

---

## Requirement: Encrypted Transport
## 需求：加密传输

The system SHALL use Noise protocol to encrypt P2P communication, preventing man-in-the-middle attacks and eavesdropping.

系统应使用 Noise 协议加密 P2P 通信，防止中间人攻击和窃听。

### Scenario: Communication between devices
### 场景：设备间通信

- **GIVEN**: Two devices establish P2P connection
- **前置条件**: 两个设备建立 P2P 连接
- **WHEN**: Transmit pool information or card data
- **操作**: 传输数据池信息或卡片数据
- **THEN**: All data SHALL be encrypted using Noise protocol
- **预期结果**: 所有数据应使用 Noise 协议加密
- **AND**: Unencrypted data SHALL NOT be transmitted over network
- **并且**: 未加密的数据不应在网络上传输

**Implementation Logic**:
**实现逻辑**:

```
// Start mDNS discovery service
// 启动 mDNS 发现服务
function start_discovery():
    // Step 1: Create libp2p Swarm
    // 步骤1：创建 libp2p Swarm
    // Design decision: Use Noise for encryption, Yamux for multiplexing
    // 设计决策：使用 Noise 加密，Yamux 多路复用
    swarm = create_swarm_with_noise_and_yamux()

    // Step 2: Configure mDNS behavior
    // 步骤2：配置 mDNS 行为
    mdns = Mdns.new()

    // Step 3: Broadcast device information
    // 步骤3：广播设备信息
    device_info = get_device_info()
    broadcast(serialize_device_info(device_info))

    // Step 4: Listen for other devices
    // 步骤4：监听其他设备
    loop:
        peer = await mdns.discover_peer()
        handle_discovered_peer(peer)
```

---

## Requirement: Pool ID Does Not Leak Content
## 需求：数据池 ID 不泄露内容

The system SHALL use UUID v7 as pool ID, ensuring the ID itself contains no business information.

系统应使用 UUID v7 作为数据池 ID，确保 ID 本身不包含任何业务信息。

### Scenario: Broadcast pool ID
### 场景：广播数据池 ID

- **GIVEN**: Device owns pool "Work Notes"
- **前置条件**: 设备拥有数据池 "工作笔记"
- **WHEN**: Broadcast pool ID
- **操作**: 广播数据池 ID
- **THEN**: Broadcast ID SHALL be in UUID v7 format (e.g., "018c8a1b-2c3d-7e4f-8a9b-0c1d2e3f4a5b")
- **预期结果**: 广播的 ID 应为 UUID v7 格式（如 "018c8a1b-2c3d-7e4f-8a9b-0c1d2e3f4a5b"）
- **AND**: ID SHALL NOT contain pool name, creation time, or other information
- **并且**: ID 不应包含数据池名称、创建时间等信息

---

## Test Coverage
## 测试覆盖

**Test File**: `rust/tests/p2p/discovery_test.rs`
**测试文件**: `rust/tests/p2p/discovery_test.rs`

**Unit Tests**:
**单元测试**:
- `test_generate_device_name()` - Test default nickname generation
- `test_generate_device_name()` - 测试默认昵称生成
- `test_serialize_device_info()` - Test device info serialization
- `test_serialize_device_info()` - 测试设备信息序列化
- `test_device_info_no_sensitive_data()` - Test device info contains no sensitive data
- `test_device_info_no_sensitive_data()` - 测试设备信息不包含敏感数据
- `test_pool_info_only_id()` - Test pool info only contains ID
- `test_pool_info_only_id()` - 测试数据池信息仅包含 ID

**Integration Tests**:
**集成测试**:
- `test_mdns_discovery()` - Test mDNS device discovery
- `test_mdns_discovery()` - 测试 mDNS 设备发现
- `test_join_pool_with_password()` - Test joining pool after password verification
- `test_join_pool_with_password()` - 测试密码验证后加入数据池
- `test_encrypted_communication()` - Test encrypted communication
- `test_encrypted_communication()` - 测试加密通信

**Privacy Tests**:
**隐私测试**:
- `test_no_pool_name_in_broadcast()` - Test pool name not in broadcast
- `test_no_pool_name_in_broadcast()` - 测试广播中不包含数据池名称
- `test_no_member_list_in_broadcast()` - Test member list not in broadcast
- `test_no_member_list_in_broadcast()` - 测试广播中不包含成员列表
- `test_no_user_nickname_in_broadcast()` - Test user nickname not in broadcast
- `test_no_user_nickname_in_broadcast()` - 测试广播中不包含用户昵称
- `test_password_required_for_details()` - Test password required for details
- `test_password_required_for_details()` - 测试获取详情需要密码

**Acceptance Criteria**:
**验收标准**:
- [x] All unit tests pass
- [x] 所有单元测试通过
- [x] All privacy tests pass
- [x] 所有隐私测试通过
- [x] mDNS broadcasts only contain non-sensitive information
- [x] mDNS 广播仅包含非敏感信息
- [x] Default nickname format correct
- [x] 默认昵称格式正确
- [x] Details only available after password verification
- [x] 密码验证后才能获取详情
- [x] Noise encryption works correctly
- [x] Noise 加密正常工作
- [x] Code review approved
- [x] 代码审查通过
- [x] Documentation updated
- [x] 文档已更新

---

## Related Documents
## 相关文档

**Related Specs**:
**相关规格**:
- [../../domain/pool/model.md](../../domain/pool/model.md) - Pool domain model
- [../../domain/pool/model.md](../../domain/pool/model.md) - 数据池领域模型
- [../../domain/sync/model.md](../../domain/sync/model.md) - Sync model
- [../../domain/sync/model.md](../../domain/sync/model.md) - 同步模型
- [../sync/peer_discovery.md](../sync/peer_discovery.md) - mDNS peer discovery
- [../sync/peer_discovery.md](../sync/peer_discovery.md) - mDNS 设备发现
- [./password.md](./password.md) - bcrypt password management
- [./password.md](./password.md) - bcrypt 密码管理

**ADRs**:
**架构决策记录**:
- [../../../docs/adr/0003-p2p-sync-architecture.md](../../../docs/adr/0003-p2p-sync-architecture.md) - P2P sync architecture
- [../../../docs/adr/0003-p2p-sync-architecture.md](../../../docs/adr/0003-p2p-sync-architecture.md) - P2P 同步架构

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23
**Authors**: CardMind Team
**作者**: CardMind Team
