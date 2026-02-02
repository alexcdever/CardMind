# mDNS 隐私保护架构规格

**版本**: 1.0.0
**状态**: 活跃
**依赖**: [../../domain/pool/model.md](../../domain/pool/model.md), [../../domain/sync/model.md](../../domain/sync/model.md)
**相关测试**: `rust/tests/p2p/discovery_test.rs`

---

## 概述


本规格定义了 CardMind 中 mDNS 设备发现的隐私保护机制。系统在局域网内广播设备信息时，仅暴露非敏感信息（设备 ID、默认设备昵称、数据池 ID），不暴露数据池名称、成员列表、卡片数量等敏感信息，确保未授权设备无法获取用户隐私数据。

**技术栈**:
- libp2p = "0.54" - P2P 网络库（包含 mDNS 特性）
- Noise 协议 - 加密认证
- Yamux - 连接多路复用

---

## 需求：最小信息暴露


系统应在 mDNS 广播中仅暴露非敏感信息，包括设备 ID、默认设备昵称和数据池 ID。

### 场景：设备发现时广播信息

- **前置条件**: 设备启动 mDNS 发现服务
- **操作**: 广播设备信息到局域网
- **预期结果**: 应仅包含设备 ID、默认昵称、数据池 ID 列表
- **并且**: 不应包含数据池名称、成员列表、卡片数量、密码哈希

**暴露的信息**:
- ✅ `device_id`: UUID v7 格式的设备标识符
- ✅ `device_name`: 默认昵称（格式：`"Unknown-{UUID前5位}"`）
- ✅ `pools[].pool_id`: 数据池 ID 列表

**隐藏的信息**:
- ❌ `pool_name`: 数据池名称
- ❌ `member_list`: 成员列表
- ❌ `card_count`: 卡片数量
- ❌ `password_hash`: 密码哈希
- ❌ `user_defined_nickname`: 用户自定义设备昵称

**实现逻辑**:

```
// 设备信息（广播到 mDNS）
structure DeviceInfo:
    device_id: String           // UUID v7
    device_name: String         // 默认昵称
    pools: List<PoolInfo>       // 数据池列表

// 数据池信息（仅包含 ID）
structure PoolInfo:
    pool_id: String             // UUID v7

// 序列化设备信息（用于 mDNS 广播）
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

## 需求：默认设备昵称生成


系统应生成默认设备昵称，格式为 "Unknown-{UUID前5位}"，不使用用户自定义昵称。

### 场景：生成设备昵称

- **前置条件**: 设备 ID 为 "018c8a1b-2c3d-7e4f-8a9b-0c1d2e3f4a5b"
- **操作**: 生成默认设备昵称
- **预期结果**: 昵称应为 "Unknown-018c8"
- **并且**: 不应使用用户在设置中配置的自定义昵称

**理由**:
- 防止用户昵称泄露个人信息（如真实姓名、设备型号）
- 提供基本的设备区分能力
- 保持一致的隐私保护策略

**实现逻辑**:

```
// 生成默认设备昵称
// 设计决策：使用 UUID 前缀保证唯一性而不暴露用户信息
function generate_device_name(device_id):
    short_id = device_id[0:5]  // 取前5个字符
    return "Unknown-" + short_id
```

---

## 需求：密码验证后获取详情


系统应要求新设备输入密码验证后，才能获取数据池的完整信息（名称、成员列表等）。

### 场景：新设备加入数据池

- **前置条件**: 新设备通过 mDNS 发现数据池 ID
- **操作**: 新设备尝试加入数据池
- **预期结果**: 系统应要求输入密码
- **并且**: 密码验证成功后，应能获取数据池名称、成员列表等详细信息

**实现逻辑**:

```
// 加入数据池（需要密码验证）
function join_pool(pool_id, password):
    // 步骤1：连接到拥有该数据池的设备
    peer = find_peer_with_pool(pool_id)

    // 步骤2：发送加入请求（包含密码）
    // 设计决策：包含时间戳以防止重放攻击
    request = JoinRequest {
        pool_id: pool_id,
        device_id: local_device_id,
        password: password,
        timestamp: current_time()
    }

    // 步骤3：通过 Noise 加密传输
    response = send_encrypted(peer, request)

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

## 需求：加密传输


系统应使用 Noise 协议加密 P2P 通信，防止中间人攻击和窃听。

### 场景：设备间通信

- **前置条件**: 两个设备建立 P2P 连接
- **操作**: 传输数据池信息或卡片数据
- **预期结果**: 所有数据应使用 Noise 协议加密
- **并且**: 未加密的数据不应在网络上传输

**实现逻辑**:

```
// 启动 mDNS 发现服务
function start_discovery():
    // 步骤1：创建 libp2p Swarm
    // 设计决策：使用 Noise 加密，Yamux 多路复用
    swarm = create_swarm_with_noise_and_yamux()

    // 步骤2：配置 mDNS 行为
    mdns = Mdns.new()

    // 步骤3：广播设备信息
    device_info = get_device_info()
    broadcast(serialize_device_info(device_info))

    // 步骤4：监听其他设备
    loop:
        peer = await mdns.discover_peer()
        handle_discovered_peer(peer)
```

---

## 需求：数据池 ID 不泄露内容


系统应使用 UUID v7 作为数据池 ID，确保 ID 本身不包含任何业务信息。

### 场景：广播数据池 ID

- **前置条件**: 设备拥有数据池 "工作笔记"
- **操作**: 广播数据池 ID
- **预期结果**: 广播的 ID 应为 UUID v7 格式（如 "018c8a1b-2c3d-7e4f-8a9b-0c1d2e3f4a5b"）
- **并且**: ID 不应包含数据池名称、创建时间等信息

---

## 测试覆盖

**测试文件**: `rust/tests/p2p/discovery_test.rs`

**单元测试**:
- `test_generate_device_name()` - 测试默认昵称生成
- `test_serialize_device_info()` - 测试设备信息序列化
- `test_device_info_no_sensitive_data()` - 测试设备信息不包含敏感数据
- `test_pool_info_only_id()` - 测试数据池信息仅包含 ID

**集成测试**:
- `test_mdns_discovery()` - 测试 mDNS 设备发现
- `test_join_pool_with_password()` - 测试密码验证后加入数据池
- `test_encrypted_communication()` - 测试加密通信

**隐私测试**:
- `test_no_pool_name_in_broadcast()` - 测试广播中不包含数据池名称
- `test_no_member_list_in_broadcast()` - 测试广播中不包含成员列表
- `test_no_user_nickname_in_broadcast()` - 测试广播中不包含用户昵称
- `test_password_required_for_details()` - 测试获取详情需要密码

**验收标准**:
- [x] 所有单元测试通过
- [x] 所有隐私测试通过
- [x] mDNS 广播仅包含非敏感信息
- [x] 默认昵称格式正确
- [x] 密码验证后才能获取详情
- [x] 代码审查通过
- [x] 文档已更新

---

## 相关文档

**相关规格**:
- [../../domain/pool/model.md](../../domain/pool/model.md) - 数据池领域模型
- [../../domain/sync/model.md](../../domain/sync/model.md) - 同步模型
- [../sync/peer_discovery.md](../sync/peer_discovery.md) - mDNS 设备发现
- [./password.md](./password.md) - bcrypt 密码管理

**架构决策记录**:
- [../../../docs/adr/0003-p2p-sync-architecture.md](../../../docs/adr/0003-p2p-sync-architecture.md) - P2P 同步架构

---

**最后更新**: 2026-01-23
**作者**: CardMind Team
