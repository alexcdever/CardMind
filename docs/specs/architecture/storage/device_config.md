# DeviceConfig 存储架构规格

**版本**: 1.0.0
**状态**: 活跃
**依赖**: [../../domain/pool/model.md](../../domain/pool/model.md)
**相关测试**: `rust/tests/device_config_test.rs`

---

## 概述

本规格定义了单池架构中设备配置的结构和管理方法。
它描述了当前稳定的配置结构，仅包含单一的 `pool_id` 字段。

---

## 需求：设备配置结构

系统应提供包含唯一设备 ID、设备名称和可选池 ID 的设备配置结构。
该结构应仅保留单一的 `pool_id`，并且不应包含 `joined_pools`、`resident_pools` 或 `last_selected_pool` 等旧字段。

**数据结构**:

```
    // 设备唯一标识符（UUID v7 格式）
    device_id: String

    // 设备昵称（自动生成，用户可修改）
    device_name: String

    // 当前加入的数据池 ID（单值，可选）
    // 设计决策：每设备单池以保持简单性
    pool_id: Optional<String>

    // 最后更新时间戳（Unix 时间戳）
    updated_at: Integer
```

---

## 需求：加载或创建设备配置

系统应提供加载现有配置或首次启动时创建新配置的方法。

### 场景：首次启动创建新配置

- **前置条件**：应用首次启动，无配置文件
- **操作**：调用 load_or_create()
- **预期结果**：应创建新配置，pool_id = None
- **并且**：配置文件应被保存

### 场景：后续启动加载现有配置

- **前置条件**：存在上次会话的配置文件
- **操作**：调用 load_or_create()
- **预期结果**：应加载现有配置
- **并且**：device_id 应保持不变

**伪代码**:

```
function load_or_create():
    // 步骤1：检查配置文件是否存在
    if config_file_exists():
        // 从磁盘加载现有配置
        return load_config_from_file()
    else:
        // 步骤2：创建新配置
        // 设计决策：生成 UUID v7 以实现时间可排序的设备 ID
        config = create_new_config(
            device_id: generate_uuid_v7(),
            device_name: generate_default_name(),
            pool_id: None,
            updated_at: current_timestamp()
        )

        // 步骤3：持久化到磁盘
        save_config_to_file(config)

        return config
```

---

## 需求：加入池（单池约束）

系统应强制要求设备最多只能加入一个池。

### 场景：成功加入第一个池

- **前置条件**：设备未加入任何池
- **操作**：加入 pool_A
- **预期结果**：pool_id 应被设置为 pool_A
- **并且**：配置应被持久化

### 场景：拒绝加入第二个池

- **前置条件**：设备已加入 pool_A
- **操作**：尝试加入 pool_B
- **预期结果**：操作应失败并返回 AlreadyJoinedError
- **并且**：pool_id 应保持为 pool_A

### 场景：加入失败时保持配置不变

- **前置条件**：设备已加入 pool_A
- **操作**：尝试非法操作（加入 pool_B）
- **预期结果**：配置应保持不变
- **并且**：持久化文件也应保持不变

**伪代码**:

```
function join_pool(new_pool_id):
    // 步骤1：强制单池约束
    // 设计决策：每个设备只允许一个池以保持简单性
    if pool_id is already set:
        return error "AlreadyJoinedPool"

    // 步骤2：更新配置
    pool_id = new_pool_id
    updated_at = current_timestamp()

    // 步骤3：持久化变更
    // 注意：自动保存确保配置立即持久化
    save_config_to_file()

    return success
```

---

## 需求：退出池并清理

系统应提供退出当前池并清理所有本地数据的方法。

### 场景：退出时清空 pool_id

- **前置条件**：设备已加入池
- **操作**：退出池
- **预期结果**：pool_id 应被设置为 None
- **并且**：配置应被持久化

### 场景：未加入时退出应失败

- **前置条件**：设备未加入任何池
- **操作**：尝试退出
- **预期结果**：操作应失败并返回 NotJoinedPool 错误

### 场景：退出时清理本地数据

- **前置条件**：设备已加入池并有数据
- **操作**：退出池
- **预期结果**：所有本地卡片应被删除
- **并且**：所有本地池应被删除

**伪代码**:

```
async function leave_pool():
    // 步骤1：验证前置条件
    if pool_id is None:
        return error "NotJoinedPool"

    // 步骤2：清理所有本地数据
    // 设计决策：删除所有本地数据以防止孤立数据
    // 注意：包括卡片、池元数据和同步状态
    current_pool_id = pool_id
    cleanup_all_local_data(current_pool_id)
    delete_pool_password(current_pool_id)

    // 步骤3：更新配置
    pool_id = None
    updated_at = current_timestamp()

    // 步骤4：持久化变更
    save_config_to_file()

    return success
```

---

## 需求：查询方法

系统应提供查询当前池 ID 和加入状态的方法。

### 场景：未加入时获取池 ID

- **前置条件**：新设备未加入任何池
- **操作**：调用 get_pool_id()
- **预期结果**：应返回 None

### 场景：已加入时获取池 ID

- **前置条件**：设备已加入 pool_A
- **操作**：调用 get_pool_id()
- **预期结果**：应返回 Some("pool_A")

### 场景：检查加入状态

- **前置条件**：各种设备状态
- **操作**：调用 is_joined()
- **预期结果**：应返回正确的布尔值

**伪代码**:

```
function get_pool_id():
    // 返回当前池 ID，如果未加入则返回 None
    return pool_id

function is_joined():
    // 检查设备是否已加入池
    return pool_id is not None
```

---

## 需求：设备名称管理

系统应提供获取和设置设备名称的方法。

### 场景：生成默认设备名称

- **前置条件**：新设备配置
- **操作**：检查设备名称
- **预期结果**：应自动生成默认名称

### 场景：允许设置自定义设备名称

- **前置条件**：设备配置
- **操作**：设置自定义名称
- **预期结果**：名称应被保存
- **并且**：配置应被持久化

**伪代码**:

```
function get_device_name():
    // 加载配置并返回设备名称
    config = load_or_create()
    return config.device_name

function set_device_name(new_name):
    // 更新设备名称并持久化
    device_name = new_name
    updated_at = current_timestamp()
    save_config_to_file()
    return success
```

---

## 需求：配置持久化

系统应以 JSON 格式将设备配置持久化到 ~/.cardmind/config/device_config.json。

**文件路径**: `~/.cardmind/config/device_config.json`

**格式**:
```json
{
  "device_id": "018dcc2b-b42f-7c7a-b7e8-3b5c3b7e8b7e",
  "device_name": "MacBook Pro-3b7e8",
  "pool_id": "018dcc2b-b42f-7c7a-b7e8-3b5c3b7e8b7f",
  "updated_at": 1705171200
}
```

**伪代码**:

```
function save_config():
    // 将配置序列化为 JSON 格式
    json_data = serialize_to_json(config)

    // 写入文件系统
    write_file(CONFIG_PATH, json_data)

    return success

function load_config():
    // 从文件系统读取 JSON
    json_data = read_file(CONFIG_PATH)

    // 反序列化为配置对象
    config = deserialize_from_json(json_data)

    return config
```

---

## 需求：与 CardStore 集成

系统应与 CardStore 集成，自动将创建的卡片关联到当前池。

### 场景：创建卡片时自动添加到当前池

- **前置条件**：设备已加入 pool_A
- **操作**：创建卡片
- **预期结果**：卡片应自动添加到 pool_A

**伪代码**:

```
function create_card(title, content):
    // 步骤1：在存储中创建卡片
    // 设计决策：使用 CRDT 实现无冲突复制
    card = create_card_in_crdt_store(title, content)

    // 步骤2：自动关联到当前池
    // 注意：卡片必须属于池才能进行同步
    config = load_device_config()
    if config.pool_id is not None:
        add_card_to_pool(card.id, config.pool_id)

    return card
```

---

## 需求：与 P2P 同步集成

系统应与同步服务集成，根据 pool_id 过滤同步操作。

**伪代码**:

```
async function sync_with_peer(peer_id):
    // 步骤1：验证设备已加入池
    config = load_device_config()
    if config.pool_id is None:
        return error "NotJoinedPool"

    // 步骤2：仅同步当前池的数据
    // 设计决策：按 pool_id 过滤同步以防止跨池数据泄露
    sync_pool_data(config.pool_id, peer_id)

    return success
```

---

## 测试覆盖

**单元测试** (强制):
- `it_creates_new_config_on_first_launch()` - 首次启动创建配置
- `it_loads_existing_config_on_subsequent_launch()` - 加载现有配置
- `it_should_allow_joining_first_pool_successfully()` - 加入第一个池
- `it_should_reject_joining_second_pool()` - 拒绝第二个池
- `it_should_preserve_config_when_join_fails()` - 失败时保持配置
- `it_should_clear_pool_id_on_leave()` - 退出时清空 pool_id
- `it_should_fail_when_leaving_without_joining()` - 未加入时退出失败
- `it_should_cleanup_local_data_on_leave()` - 退出时清理数据
- `get_pool_id_should_return_none_when_not_joined()` - 未加入时查询
- `get_pool_id_should_return_some_when_joined()` - 已加入时查询
- `is_joined_should_return_false_for_new_device()` - 检查加入状态
- `it_should_generate_default_device_name()` - 生成默认名称
- `it_should_allow_setting_custom_device_name()` - 设置自定义名称

**集成测试** (推荐):
- 首次启动流程
- 加入池流程
- 退出池流程
- 非法操作保护

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 集成测试通过
- [ ] 代码审查通过
- [ ] 文档已更新

---

## 相关文档

**领域规格**:
- [../../domain/pool/model.md](../../domain/pool/model.md) - 池领域模型

**相关架构规格**:
- [./card_store.md](./card_store.md) - CardStore 实现

**架构决策记录**:
- [../../../docs/adr/0002-dual-layer-architecture.md](../../../docs/adr/0002-dual-layer-architecture.md) - 双层架构

---

**最后更新**: 2026-01-21
**作者**: CardMind Team
