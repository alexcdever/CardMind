# DeviceConfig 存储架构规格

**状态**: 活跃
**依赖**: [../../domain/pool.md](../../domain/pool.md)
**相关测试**: `rust/tests/device_config_feature_test.rs`

---

## 概述

本规格定义了单池架构中设备配置的结构和管理方法。系统使用 JSON 格式将设备配置持久化到本地文件系统，确保设备身份（peer_id）和池成员资格在应用重启后保持一致。

**技术栈**:
- **serde_json** = "1.0" - JSON 序列化/反序列化
- **tokio::fs** - 异步文件操作

**核心特性**:
- **单池约束**: 每个设备最多只能加入一个池
- **自动持久化**: 配置变更自动保存到磁盘
- **peer_id 作为设备标识**: 来源于持久化密钥对
- **零配置**: 首次启动自动创建配置

---

## 需求：设备配置结构

系统应提供包含 peer_id、设备名称和可选池 ID 的设备配置结构。
该结构应仅保留单一的 `pool_id`，并且不应包含 `joined_pools`、`resident_pools` 或 `last_selected_pool` 等旧字段。

### 场景：定义设备配置结构

- **前置条件**: 系统需要持久化设备身份信息
- **操作**: 定义 DeviceConfig 数据结构
- **预期结果**: 包含 peer_id、device_name、pool_id、updated_at
- **并且**: pool_id 为可选单值

**数据结构**:

```
structure DeviceConfig:
    // 设备唯一标识符（PeerId 字符串）
    // 由持久化密钥对派生，可能在加入池时生成
    peer_id: Optional<String>

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

- **前置条件**: 应用首次启动，无配置文件
- **操作**: 调用 load_or_create()
- **预期结果**: 应创建新配置，pool_id = None
- **并且**: 配置文件应被保存到 ~/.cardmind/config/device_config.json

### 场景：后续启动加载现有配置

- **前置条件**: 存在上次会话的配置文件
- **操作**: 调用 load_or_create()
- **预期结果**: 应加载现有配置
- **并且**: peer_id（若存在）应保持不变

**实现逻辑**:

```
function load_or_create():
    // 步骤1：检查配置文件是否存在
    config_path = get_config_file_path()
    
    if file_exists(config_path):
        // 从磁盘加载现有配置
        // 设计决策：使用 JSON 格式便于调试和手动编辑
        json_data = read_file(config_path)
        config = deserialize_from_json(json_data)
        
        log_debug("Loaded existing device config: " + config.peer_id)
        return config
    else:
        // 步骤2：创建新配置
        device_name = generate_default_device_name()
        
        config = DeviceConfig {
            peer_id: None,
            device_name: device_name,
            pool_id: None,
            updated_at: current_timestamp()
        }

        // 步骤3：持久化到磁盘
        // 注意：确保配置目录存在
        ensure_config_directory_exists()
        save_config_to_file(config)

        log_info("Created new device config")
        return config

function get_config_file_path():
    // 获取配置文件路径
    // 设计决策：使用用户主目录下的 .cardmind 文件夹
    home_dir = get_home_directory()
    return home_dir + "/.cardmind/config/device_config.json"

function generate_default_device_name():
    // 生成默认设备名称
    // 格式：<主机名>-<随机后缀>
    hostname = get_hostname()
    random_suffix = generate_short_random_suffix()
    
    return hostname + "-" + random_suffix

function ensure_config_directory_exists():
    // 确保配置目录存在
    config_dir = get_home_directory() + "/.cardmind/config"
    
    if not directory_exists(config_dir):
        create_directory_recursive(config_dir)
```

---

## 需求：加入池（单池约束）

系统应强制要求设备最多只能加入一个池。

### 场景：成功加入第一个池

- **前置条件**: 设备未加入任何池
- **操作**: 加入 pool_A
- **预期结果**: pool_id 应被设置为 pool_A
- **并且**: 配置应被持久化

### 场景：拒绝加入第二个池

- **前置条件**: 设备已加入 pool_A
- **操作**: 尝试加入 pool_B
- **预期结果**: 操作应失败并返回 AlreadyJoinedError
- **并且**: pool_id 应保持为 pool_A

### 场景：加入失败时保持配置不变

- **前置条件**: 设备已加入 pool_A
- **操作**: 尝试非法操作（加入 pool_B）
- **预期结果**: 配置应保持不变
- **并且**: 持久化文件也应保持不变

**实现逻辑**:

```
function join_pool(new_pool_id):
    // 步骤1：验证输入
    if new_pool_id is empty:
        return error "InvalidPoolId"
    
    // 步骤2：强制单池约束
    // 设计决策：每个设备只允许一个池以保持简单性
    if pool_id is not None:
        log_warn("Attempted to join pool " + new_pool_id + " while already in pool " + pool_id)
        return error "AlreadyJoinedPool"

    // 步骤3：更新配置
    pool_id = new_pool_id
    updated_at = current_timestamp()

    // 步骤4：持久化变更
    // 注意：自动保存确保配置立即持久化
    result = save_config_to_file()
    
    if result is error:
        // 回滚变更
        pool_id = None
        return error "FailedToSaveConfig"

    log_info("Successfully joined pool: " + new_pool_id)
    return success
```

---

## 需求：退出池并清理

系统应提供退出当前池并清理所有本地数据的方法。

### 场景：退出时清空 pool_id

- **前置条件**: 设备已加入池
- **操作**: 退出池
- **预期结果**: pool_id 应被设置为 None
- **并且**: 配置应被持久化

### 场景：未加入时退出应失败

- **前置条件**: 设备未加入任何池
- **操作**: 尝试退出
- **预期结果**: 操作应失败并返回 NotJoinedPool 错误

### 场景：退出时清理本地数据

- **前置条件**: 设备已加入池并有数据
- **操作**: 退出池
- **预期结果**: 所有本地卡片应被删除
- **并且**: 所有本地池元数据应被删除
- **并且**: Keyring 中的池密码应被删除

**实现逻辑**:

```
async function leave_pool():
    // 步骤1：验证前置条件
    if pool_id is None:
        log_warn("Attempted to leave pool when not joined")
        return error "NotJoinedPool"

    // 步骤2：保存当前池 ID 用于清理
    current_pool_id = pool_id
    
    // 步骤3：清理所有本地数据
    // 设计决策：删除所有本地数据以防止孤立数据
    // 注意：包括卡片、池元数据和同步状态
    try:
        // 清理 Loro 文档
        cleanup_loro_documents(current_pool_id)
        
        // 清理 SQLite 缓存
        cleanup_sqlite_cache(current_pool_id)
        
        // 删除 Keyring 中的池密码
        delete_pool_password_from_keyring(current_pool_id)
        
        log_info("Cleaned up local data for pool: " + current_pool_id)
    catch error:
        log_error("Failed to cleanup local data: " + error)
        // 继续执行，即使清理失败也要更新配置

    // 步骤4：更新配置
    pool_id = None
    updated_at = current_timestamp()

    // 步骤5：持久化变更
    save_config_to_file()

    log_info("Successfully left pool: " + current_pool_id)
    return success

function cleanup_loro_documents(pool_id):
    // 删除指定池的所有 Loro 文档
    // 设计决策：删除 .loro 文件以释放磁盘空间
    loro_dir = get_loro_directory()
    
    // 删除池文档
    pool_file = loro_dir + "/pool_" + pool_id + ".loro"
    if file_exists(pool_file):
        delete_file(pool_file)
    
    // 删除所有卡片文档
    card_files = list_files(loro_dir, pattern: "card_*.loro")
    for each file in card_files:
        delete_file(file)

function cleanup_sqlite_cache(pool_id):
    // 清理 SQLite 缓存中的池数据
    db = open_sqlite_connection()
    
    // 删除卡片-池绑定
    db.execute("DELETE FROM card_pool_bindings WHERE pool_id = ?", pool_id)
    
    // 删除池元数据
    db.execute("DELETE FROM pools WHERE pool_id = ?", pool_id)
    
    // 删除孤立卡片（不属于任何池的卡片）
    db.execute("DELETE FROM cards WHERE id NOT IN (SELECT card_id FROM card_pool_bindings)")
    
    db.close()
```

---

## 需求：查询方法

系统应提供查询当前池 ID 和加入状态的方法。

### 场景：未加入时获取池 ID

- **前置条件**: 新设备未加入任何池
- **操作**: 调用 get_pool_id()
- **预期结果**: 应返回 None

### 场景：已加入时获取池 ID

- **前置条件**: 设备已加入 pool_A
- **操作**: 调用 get_pool_id()
- **预期结果**: 应返回 Some("pool_A")

### 场景：检查加入状态

- **前置条件**: 各种设备状态
- **操作**: 调用 is_joined()
- **预期结果**: 应返回正确的布尔值

**实现逻辑**:

```
function get_pool_id():
    // 返回当前池 ID，如果未加入则返回 None
    // 设计决策：直接返回字段值，无需额外验证
    return pool_id

function is_joined():
    // 检查设备是否已加入池
    // 设计决策：简单的空值检查
    return pool_id is not None

function get_peer_id():
    // 返回设备唯一标识符
    return peer_id
```

---

## 需求：设备名称管理

系统应提供获取和设置设备名称的方法。

### 场景：生成默认设备名称

- **前置条件**: 新设备配置
- **操作**: 检查设备名称
- **预期结果**: 应自动生成默认名称（格式：<主机名>-<随机后缀>）

### 场景：允许设置自定义设备名称

- **前置条件**: 设备配置
- **操作**: 设置自定义名称
- **预期结果**: 名称应被保存
- **并且**: 配置应被持久化

### 场景：设备名称验证

- **前置条件**: 尝试设置设备名称
- **操作**: 提供空名称或过长名称
- **预期结果**: 应返回验证错误

**实现逻辑**:

```
function get_device_name():
    // 返回当前设备名称
    return device_name

function set_device_name(new_name):
    // 步骤1：验证输入
    // 设计决策：限制名称长度以防止 UI 显示问题
    if new_name is empty:
        return error "DeviceNameCannotBeEmpty"
    
    if length(new_name) > 50:
        return error "DeviceNameTooLong"
    
    // 步骤2：更新设备名称
    device_name = new_name
    updated_at = current_timestamp()
    
    // 步骤3：持久化变更
    result = save_config_to_file()
    
    if result is error:
        // 回滚变更
        device_name = old_name
        return error "FailedToSaveConfig"
    
    log_info("Device name updated to: " + new_name)
    return success
```

---

## 需求：配置持久化

系统应以 JSON 格式将设备配置持久化到 ~/.cardmind/config/device_config.json。

### 场景：持久化设备配置文件

- **前置条件**: 配置发生变更
- **操作**: 保存配置到磁盘
- **预期结果**: 配置文件应按 JSON 格式写入
- **并且**: 写入应使用原子替换

**文件路径**: `~/.cardmind/config/device_config.json`

**格式**:
```json
{
  "peer_id": "12D3KooWQ1examplePeerId",
  "device_name": "MacBook Pro-3b7e8",
  "pool_id": "018dcc2b-b42f-7c7a-b7e8-3b5c3b7e8b7f",
  "updated_at": 1705171200
}
```

**实现逻辑**:

```
function save_config_to_file():
    // 步骤1：序列化配置为 JSON
    // 设计决策：使用缩进格式便于人工阅读
    config_data = {
        "peer_id": peer_id,
        "device_name": device_name,
        "pool_id": pool_id,
        "updated_at": updated_at
    }
    
    json_string = serialize_to_json(config_data, pretty: true)
    
    // 步骤2：原子写入文件
    // 设计决策：先写临时文件，再重命名以确保原子性
    config_path = get_config_file_path()
    temp_path = config_path + ".tmp"
    
    try:
        // 写入临时文件
        write_file(temp_path, json_string)
        
        // 原子重命名
        // 注意：重命名操作在大多数文件系统上是原子的
        rename_file(temp_path, config_path)
        
        log_debug("Config saved successfully")
        return success
    catch error:
        // 清理临时文件
        if file_exists(temp_path):
            delete_file(temp_path)
        
        log_error("Failed to save config: " + error)
        return error "FailedToSaveConfig"

function load_config_from_file():
    // 步骤1：读取 JSON 文件
    config_path = get_config_file_path()
    
    if not file_exists(config_path):
        return error "ConfigFileNotFound"
    
    try:
        json_string = read_file(config_path)
        
        // 步骤2：反序列化为配置对象
        // 设计决策：验证必需字段存在
        config_data = deserialize_from_json(json_string)
        
        // 步骤3：验证配置完整性
        if not config_data.has_field("device_name"):
            return error "InvalidConfig: missing device_name"
        
        // 步骤4：构造配置对象
        config = DeviceConfig {
            peer_id: config_data.peer_id,
            device_name: config_data.device_name,
            pool_id: config_data.pool_id,
            updated_at: config_data.updated_at
        }
        
        return config
    catch error:
        log_error("Failed to load config: " + error)
        return error "FailedToLoadConfig"
```

---

## 需求：与 CardStore 集成

系统应与 CardStore 集成，自动将创建的卡片关联到当前池。

### 场景：创建卡片时自动添加到当前池

- **前置条件**: 设备已加入 pool_A
- **操作**: 创建卡片
- **预期结果**: 卡片应自动添加到 pool_A

### 场景：未加入池时创建卡片应失败

- **前置条件**: 设备未加入任何池
- **操作**: 尝试创建卡片
- **预期结果**: 应返回 NotJoinedPool 错误

**实现逻辑**:

```
function create_card(title, content):
    // 步骤1：验证设备已加入池
    config = load_device_config()
    
    if config.pool_id is None:
        log_warn("Cannot create card: device not joined to any pool")
        return error "NotJoinedPool"
    
    // 步骤2：在 Loro 存储中创建卡片
    // 设计决策：使用 CRDT 实现无冲突复制
    card_id = generate_uuid_v7()
    
    card = Card {
        id: card_id,
        title: title,
        content: content,
        created_at: current_timestamp(),
        updated_at: current_timestamp(),
        deleted: false
    }
    
    // 创建 Loro 文档
    loro_doc = create_loro_document()
    card_map = loro_doc.get_map("card")
    card_map.set("id", card.id)
    card_map.set("title", card.title)
    card_map.set("content", card.content)
    card_map.set("created_at", card.created_at)
    card_map.set("updated_at", card.updated_at)
    card_map.set("deleted", card.deleted)
    
    // 提交变更
    loro_doc.commit()
    
    // 步骤3：自动关联到当前池
    // 注意：卡片必须属于池才能进行同步
    add_card_to_pool(card.id, config.pool_id)
    
    log_info("Created card " + card.id + " in pool " + config.pool_id)
    return card
```

---

## 需求：与 P2P 同步集成

系统应与同步服务集成，根据 pool_id 过滤同步操作。

### 场景：同步前验证池成员资格

- **前置条件**: 设备尝试同步
- **操作**: 检查设备是否已加入池
- **预期结果**: 未加入池时应拒绝同步

### 场景：仅同步当前池数据

- **前置条件**: 设备已加入 pool_A
- **操作**: 与对等点同步
- **预期结果**: 仅应同步 pool_A 的数据

**实现逻辑**:

```
async function sync_with_peer(peer_id):
    // 步骤1：验证设备已加入池
    config = load_device_config()
    
    if config.pool_id is None:
        log_warn("Cannot sync: device not joined to any pool")
        return error "NotJoinedPool"

    // 步骤2：验证对等点在同一池中
    // 设计决策：通过连接后的握手校验 pool_hash
    if not has_completed_pool_handshake(peer_id):
        log_warn("Pool mismatch: handshake not verified for " + peer_id)
        return error "PoolMismatch"

    // 步骤3：仅同步当前池的数据
    // 设计决策：按 pool_id 过滤同步以防止跨池数据泄露
    sync_result = await sync_pool_data(config.pool_id, peer_id)
    
    if sync_result is success:
        log_info("Successfully synced with peer " + peer_id)
    else:
        log_error("Sync failed with peer " + peer_id + ": " + sync_result.error)
    
    return sync_result

function sync_pool_data(pool_id, peer_id):
    // 同步指定池的所有数据
    // 步骤1：获取池的所有卡片 ID
    card_ids = get_pool_card_ids(pool_id)
    
    // 步骤2：为每张卡片同步 Loro 文档
    for each card_id in card_ids:
        loro_doc = load_loro_document(card_id)
        
        // 导出本地更新
        local_updates = loro_doc.export_updates()
        
        // 发送到对等点
        send_updates_to_peer(peer_id, card_id, local_updates)
        
        // 接收对等点更新
        remote_updates = receive_updates_from_peer(peer_id, card_id)
        
        // 合并更新
        loro_doc.import_updates(remote_updates)
        loro_doc.commit()
    
    // 步骤3：同步池元数据
    pool_loro_doc = load_pool_loro_document(pool_id)
    sync_document_with_peer(pool_loro_doc, peer_id)
    
    return success
```

---

## 补充说明

**技术栈**:
- **serde_json** = "1.0" - JSON 序列化/反序列化
- **tokio::fs** - 异步文件操作
- **std::path::PathBuf** - 跨平台路径处理

**设计模式**:
- **单例模式**: DeviceConfig 在应用生命周期内保持单例
- **延迟初始化**: 首次访问时加载或创建配置
- **原子写入**: 使用临时文件+重命名确保配置完整性

**性能考虑**:
- **内存缓存**: 配置加载后缓存在内存中
- **原子操作**: 文件写入使用原子重命名
- **最小 I/O**: 仅在配置变更时写入磁盘

**错误处理**:
- **配置损坏**: 自动备份并重新创建
- **磁盘满**: 返回明确错误，不破坏现有配置
- **权限问题**: 提示用户检查文件权限

---

## 相关文档

**领域规格**:
- [../../domain/pool.md](../../domain/pool.md) - 池领域模型

**相关架构规格**:
- [./card_store.md](./card_store.md) - CardStore 实现
- [./pool_store.md](./pool_store.md) - PoolStore 实现
- [../security/keyring.md](../security/keyring.md) - Keyring 密码存储

**架构决策记录**:
- ADR-0001: 单池约束 - 每设备单池设计决策
- ADR-0002: 双层架构 - Loro + SQLite 架构

---

## 测试覆盖

**测试文件**: `rust/tests/device_config_feature_test.rs`

**单元测试**:
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
- `it_should_validate_device_name_length()` - 验证名称长度
- `it_should_reject_empty_device_name()` - 拒绝空名称
- `it_should_persist_config_atomically()` - 原子持久化
- `it_should_handle_corrupted_config_file()` - 处理损坏配置

**功能测试**:
- `test_first_launch_flow()` - 首次启动流程
- `test_join_pool_flow()` - 加入池流程
- `test_leave_pool_flow()` - 退出池流程
- `test_config_persistence_across_restarts()` - 重启后配置持久性
- `test_single_pool_constraint_enforcement()` - 单池约束强制执行
- `test_card_creation_integration()` - 卡片创建集成
- `test_sync_integration()` - 同步集成

**验收标准**:
- [x] 所有单元测试通过
- [x] 功能测试通过
- [x] 单池约束正确执行
- [x] 配置持久化可靠
- [x] 代码审查通过
- [x] 文档已更新
