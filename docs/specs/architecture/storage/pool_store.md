# PoolStore 架构规格

**状态**: 活跃
**依赖**: [../../domain/pool/model.md](../../domain/pool/model.md), [./device_config.md](./device_config.md), [./dual_layer.md](./dual_layer.md)
**相关测试**: `rust/tests/pool_store_test.rs`

---

## 概述

本规格定义了 PoolStore 的技术实现，使用双层架构（Loro + SQLite）管理池数据并强制执行单池约束。

**技术栈**:
- **loro** = "1.0" - CRDT 文档存储
- **bcrypt** = "0.15" - 密码哈希
- **rusqlite** = "0.31" - SQLite 数据库
- **uuid** = "1.6" - UUID v7 生成

**核心职责**:
- 管理 Pool Loro 文档（创建、加载、更新）
- 强制执行每设备单池约束
- 维护池-设备关系
- 同步 Pool 数据到 SQLite 缓存

---

## 需求：Pool Loro 文档管理

系统应使用 Loro CRDT 文档作为数据源管理 Pool 数据。

### 场景：创建新池

- **前置条件**: 用户想要创建新池
- **操作**: 调用 PoolStore.create_pool()
- **预期结果**: 应创建新的 Pool Loro 文档
- **并且**: 文档应持久化到 `data/loro/<pool_id>/snapshot.loro`
- **并且**: 池应通过订阅添加到 SQLite

**实现逻辑**:

```
function create_pool(pool_name, password):
    // 步骤1：生成唯一池标识符
    // 设计决策：使用 UUIDv7 实现时间可排序的 ID
    pool_id = generate_uuid_v7()

    // 步骤2：哈希密码以确保安全
    // 安全：使用成本因子 12 的 bcrypt
    password_hash = hash_password_with_bcrypt(password, cost: 12)

    // 步骤3：创建 CRDT 文档结构
    // 设计决策：使用映射结构实现字段级合并
    crdt_doc = create_crdt_document()
    
    pool_map = crdt_doc.get_map("pool")
    pool_map.set("pool_id", pool_id)
    pool_map.set("pool_name", pool_name)
    pool_map.set("password_hash", password_hash)
    pool_map.set("created_at", current_timestamp())
    pool_map.set("updated_at", current_timestamp())
    
    // 初始化列表字段
    card_ids_list = crdt_doc.get_list("card_ids")
    device_ids_list = crdt_doc.get_list("device_ids")

    // 步骤4：提交初始状态
    crdt_doc.commit()

    // 步骤5：持久化到磁盘
    // 注意：存储在池特定目录中以实现隔离
    file_path = get_pool_document_path(pool_id)
    ensure_directory_exists(get_directory_from_path(file_path))
    save_document(crdt_doc, file_path)

    // 步骤6：缓存到内存以实现快速访问
    cache_document(pool_id, crdt_doc)

    // 步骤7：触发订阅以更新 SQLite 缓存
    // 注意：订阅模式确保一致性
    pool = convert_to_pool(crdt_doc)
    notify_pool_updated(pool)

    log_info("Created pool: " + pool_id)
    return pool

function get_pool_document_path(pool_id):
    // 获取池文档的文件路径
    loro_dir = get_loro_directory()
    return loro_dir + "/" + pool_id + "/snapshot.loro"
```

### 场景：从磁盘加载池

- **前置条件**: 池 ID 存在
- **操作**: 调用 PoolStore.load_pool()
- **预期结果**: 应从磁盘加载 Pool Loro 文档
- **并且**: 文档应缓存在内存中

**实现逻辑**:

```
function load_pool(pool_id):
    // 步骤1：首先检查内存缓存以提高性能
    // 设计决策：两级缓存（内存 + 磁盘）
    if pool_exists_in_cache(pool_id):
        crdt_doc = get_from_cache(pool_id)
        log_debug("Pool loaded from cache: " + pool_id)
        return convert_to_pool(crdt_doc)

    // 步骤2：如果不在缓存中则从磁盘加载
    file_path = get_pool_document_path(pool_id)
    
    if not file_exists(file_path):
        return error "PoolNotFound"
    
    crdt_doc = load_document(file_path)
    
    if crdt_doc is error:
        return crdt_doc

    // 步骤3：缓存到内存以供将来访问
    cache_document(pool_id, crdt_doc)

    // 步骤4：将 CRDT 文档转换为领域模型
    log_debug("Pool loaded from disk: " + pool_id)
    return convert_to_pool(crdt_doc)

function convert_to_pool(crdt_doc):
    // 从 CRDT 文档中提取所有字段
    pool_map = crdt_doc.get_map("pool")
    card_ids_list = crdt_doc.get_list("card_ids")
    device_ids_list = crdt_doc.get_list("device_ids")
    
    pool = Pool {
        pool_id: pool_map.get("pool_id"),
        pool_name: pool_map.get("pool_name"),
        password_hash: pool_map.get("password_hash"),
        card_ids: card_ids_list.to_array(),
        device_ids: device_ids_list.to_array(),
        created_at: pool_map.get("created_at"),
        updated_at: pool_map.get("updated_at")
    }

    return pool
```

### 场景：更新池名称

- **前置条件**: 池存在
- **操作**: 调用 PoolStore.update_pool_name()
- **预期结果**: 池名称应被更新
- **并且**: 变更应传播到所有设备

**实现逻辑**:

```
function update_pool_name(pool_id, new_name):
    // 步骤1：验证输入
    if new_name is empty:
        return error "PoolNameCannotBeEmpty"
    
    if length(new_name) > 100:
        return error "PoolNameTooLong"
    
    // 步骤2：加载池文档
    crdt_doc = get_pool_document(pool_id)
    
    if crdt_doc is error:
        return crdt_doc
    
    // 步骤3：更新池名称
    pool_map = crdt_doc.get_map("pool")
    pool_map.set("pool_name", new_name)
    pool_map.set("updated_at", current_timestamp())
    
    // 步骤4：提交变更
    crdt_doc.commit()
    
    // 步骤5：持久化到磁盘
    file_path = get_pool_document_path(pool_id)
    save_document(crdt_doc, file_path)
    
    // 步骤6：触发订阅
    pool = convert_to_pool(crdt_doc)
    notify_pool_updated(pool)
    
    log_info("Pool name updated: " + pool_id)
    return success
```

---

## 需求：单池约束强制执行

系统应强制执行设备最多只能加入一个池。

### 场景：设备成功加入第一个池

- **前置条件**: 设备未加入任何池
- **操作**: 调用 PoolStore.join_pool()
- **预期结果**: 设备应被添加到 Pool.device_ids
- **并且**: DeviceConfig.pool_id 应被设置
- **并且**: 变更应通过 P2P 同步传播到所有设备

**实现逻辑**:

```
function join_pool(pool_id, password):
    // 步骤1：强制执行单池约束
    // 设计决策：设备一次只能加入一个池
    device_config = load_device_config()
    
    if device_config.is_joined():
        log_warn("Device already joined pool: " + device_config.pool_id)
        return error "AlreadyJoinedPool"

    // 步骤2：加载池
    pool = load_pool(pool_id)
    
    if pool is error:
        return pool

    // 步骤3：验证密码
    // 安全：使用恒定时间比较以防止时序攻击
    if not verify_password_with_bcrypt(password, pool.password_hash):
        log_warn("Invalid password for pool: " + pool_id)
        return error "InvalidPassword"

    // 步骤4：将设备添加到池的设备列表
    // 注意：幂等操作 - 可以安全地多次调用
    device_id = device_config.device_id
    
    crdt_doc = get_pool_document(pool_id)
    device_ids_list = crdt_doc.get_list("device_ids")
    
    if not device_ids_list.contains(device_id):
        device_ids_list.append(device_id)
        
        pool_map = crdt_doc.get_map("pool")
        pool_map.set("updated_at", current_timestamp())

        // 提交变更
        crdt_doc.commit()

        // 持久化变更
        file_path = get_pool_document_path(pool_id)
        save_document(crdt_doc, file_path)

        // 触发订阅以更新 SQLite 并同步到其他设备
        pool = convert_to_pool(crdt_doc)
        notify_pool_updated(pool)

    // 步骤5：更新设备配置
    // 注意：这建立了设备-池关系
    device_config.join_pool(pool_id)

    log_info("Device joined pool: " + pool_id)
    return success
```

### 场景：设备拒绝加入第二个池

- **前置条件**: 设备已加入 pool_A
- **操作**: 为 pool_B 调用 PoolStore.join_pool()
- **预期结果**: 系统应返回 AlreadyJoinedPool 错误
- **并且**: DeviceConfig.pool_id 应保持为 pool_A

---

## 需求：离开池和数据清理

系统应在设备离开池时清理所有池相关数据。

### 场景：设备离开池

- **前置条件**: 设备已加入池
- **操作**: 调用 PoolStore.leave_pool()
- **预期结果**: 设备应从 Pool.device_ids 中移除
- **并且**: DeviceConfig.pool_id 应被清除
- **并且**: 所有本地 Pool 和 Card 数据应被删除
- **并且**: 移除操作应传播到其他设备

**实现逻辑**:

```
function leave_pool():
    // 步骤1：从设备配置获取当前池
    device_config = load_device_config()
    
    if not device_config.is_joined():
        log_warn("Device not joined to any pool")
        return error "NotJoinedPool"

    pool_id = device_config.get_pool_id()
    device_id = device_config.device_id

    // 步骤2：从池的设备列表中移除设备
    // 注意：此变更将通过 P2P 同步到其他设备
    try:
        crdt_doc = get_pool_document(pool_id)
        
        if crdt_doc is not error:
            device_ids_list = crdt_doc.get_list("device_ids")
            device_ids_list.remove(device_id)
            
            pool_map = crdt_doc.get_map("pool")
            pool_map.set("updated_at", current_timestamp())

            // 提交变更
            crdt_doc.commit()

            // 持久化变更以同步到其他设备
            file_path = get_pool_document_path(pool_id)
            save_document(crdt_doc, file_path)
            
            // 触发订阅
            pool = convert_to_pool(crdt_doc)
            notify_pool_updated(pool)
    catch error:
        // 即使更新池失败，也继续清理本地数据
        log_error("Failed to update pool on leave: " + error)

    // 步骤3：删除所有本地数据
    // 设计决策：完全清理确保没有孤立数据
    delete_all_local_data(pool_id)

    // 步骤4：清除设备配置
    device_config.leave_pool()

    log_info("Device left pool: " + pool_id)
    return success

function delete_all_local_data(pool_id):
    // 步骤1：从池获取所有卡片 ID
    pool = load_pool(pool_id)
    
    if pool is not error:
        card_ids = pool.card_ids

        // 步骤2：删除所有卡片 CRDT 文档
        for each card_id in card_ids:
            card_dir = get_loro_directory() + "/" + card_id
            if directory_exists(card_dir):
                delete_directory_recursive(card_dir)
                log_debug("Deleted card directory: " + card_id)

    // 步骤3：删除池 CRDT 文档
    pool_dir = get_loro_directory() + "/" + pool_id
    if directory_exists(pool_dir):
        delete_directory_recursive(pool_dir)
        log_debug("Deleted pool directory: " + pool_id)

    // 步骤4：清除 SQLite 缓存
    // 注意：从缓存中移除所有池相关数据
    db = get_sqlite_connection()
    
    db.execute("DELETE FROM cards WHERE id IN (
        SELECT card_id FROM card_pool_bindings WHERE pool_id = ?
    )", [pool_id])
    
    db.execute("DELETE FROM card_pool_bindings WHERE pool_id = ?", [pool_id])
    db.execute("DELETE FROM pools WHERE pool_id = ?", [pool_id])

    // 步骤5：清除内存缓存
    remove_from_cache(pool_id)
    
    log_info("Deleted all local data for pool: " + pool_id)
```

---

## 需求：池-卡片关系管理

系统应通过 Pool.card_ids 管理池和卡片之间的关系。

### 场景：添加卡片到池

- **前置条件**: 池和卡片存在
- **操作**: 调用 PoolStore.add_card()
- **预期结果**: 卡片 ID 应被添加到 Pool.card_ids
- **并且**: 变更应传播到所有设备
- **并且**: SQLite 绑定应通过订阅更新

**实现逻辑**:

```
function add_card(pool_id, card_id):
    // 步骤1：验证池存在
    crdt_doc = get_pool_document(pool_id)
    
    if crdt_doc is error:
        return crdt_doc

    // 步骤2：如果尚未存在则添加卡片（幂等操作）
    // 设计决策：幂等以安全处理重复请求
    card_ids_list = crdt_doc.get_list("card_ids")
    
    if not card_ids_list.contains(card_id):
        card_ids_list.append(card_id)
        
        pool_map = crdt_doc.get_map("pool")
        pool_map.set("updated_at", current_timestamp())

        // 步骤3：提交变更
        crdt_doc.commit()

        // 步骤4：持久化变更
        file_path = get_pool_document_path(pool_id)
        save_document(crdt_doc, file_path)

        // 步骤5：触发订阅以更新 SQLite 绑定
        // 注意：这确保卡片-池关系被缓存
        pool = convert_to_pool(crdt_doc)
        notify_pool_updated(pool)
        
        log_debug("Added card to pool: " + card_id)

    return success

function remove_card(pool_id, card_id):
    // 步骤1：验证池存在
    crdt_doc = get_pool_document(pool_id)
    
    if crdt_doc is error:
        return crdt_doc

    // 步骤2：从池的卡片列表中移除卡片
    card_ids_list = crdt_doc.get_list("card_ids")
    
    if card_ids_list.contains(card_id):
        card_ids_list.remove(card_id)
        
        pool_map = crdt_doc.get_map("pool")
        pool_map.set("updated_at", current_timestamp())

        // 步骤3：提交变更
        crdt_doc.commit()

        // 步骤4：持久化变更
        file_path = get_pool_document_path(pool_id)
        save_document(crdt_doc, file_path)

        // 步骤5：触发订阅以更新 SQLite 绑定
        pool = convert_to_pool(crdt_doc)
        notify_pool_updated(pool)
        
        log_debug("Removed card from pool: " + card_id)

    return success
```

### 场景：获取池中的所有卡片

- **前置条件**: 池存在
- **操作**: 调用 PoolStore.get_pool_cards()
- **预期结果**: 应返回池中所有卡片 ID 列表

**实现逻辑**:

```
function get_pool_cards(pool_id):
    // 从池文档获取卡片 ID 列表
    pool = load_pool(pool_id)
    
    if pool is error:
        return pool
    
    return pool.card_ids
```

---

## 需求：SQLite 同步

系统应通过订阅回调将 Pool 数据同步到 SQLite。

### 场景：池更新触发 SQLite 更新

- **前置条件**: Pool Loro 文档被修改
- **操作**: 触发订阅回调
- **预期结果**: pools 表应被更新
- **并且**: card_pool_bindings 表应被更新

**实现逻辑**:

```
function on_pool_updated(pool):
    // 当池 CRDT 文档变更时触发的订阅回调
    // 设计决策：观察者模式实现自动缓存同步

    // 步骤1：获取数据库连接
    db = get_sqlite_connection()
    
    // 步骤2：开始事务
    // 设计决策：使用事务确保原子性
    transaction = db.begin_transaction()
    
    try:
        // 步骤3：更新 SQLite 缓存中的 pools 表
        // 注意：使用 INSERT OR REPLACE 实现幂等更新
        transaction.execute("
            INSERT OR REPLACE INTO pools 
            (pool_id, pool_name, created_at, updated_at)
            VALUES (?, ?, ?, ?)
        ", [
            pool.pool_id,
            pool.pool_name,
            pool.created_at,
            pool.updated_at
        ])

        // 步骤4：更新卡片-池绑定
        // 设计决策：清除并重建以确保一致性

        // 清除此池的旧绑定
        transaction.execute("
            DELETE FROM card_pool_bindings 
            WHERE pool_id = ?
        ", [pool.pool_id])

        // 为池中所有卡片插入新绑定
        for each card_id in pool.card_ids:
            transaction.execute("
                INSERT OR REPLACE INTO card_pool_bindings 
                (card_id, pool_id)
                VALUES (?, ?)
            ", [card_id, pool.pool_id])

        // 步骤5：提交事务
        transaction.commit()
        
        log_debug("SQLite updated for pool: " + pool.pool_id)
        return success
    catch error:
        // 回滚事务
        transaction.rollback()
        log_error("Failed to update SQLite for pool: " + error)
        return error
```

---

## 需求：密码管理

系统应安全地管理池密码。

### 场景：验证池密码

- **前置条件**: 用户尝试加入池
- **操作**: 验证提供的密码
- **预期结果**: 应使用恒定时间比较
- **并且**: 应防止时序攻击

**实现逻辑**:

```
function hash_password_with_bcrypt(password, cost):
    // 使用 bcrypt 哈希密码
    // 设计决策：成本因子 12 平衡安全性和性能
    
    if password is empty:
        return error "PasswordCannotBeEmpty"
    
    if length(password) < 8:
        return error "PasswordTooShort"
    
    if length(password) > 72:
        // bcrypt 限制
        return error "PasswordTooLong"
    
    password_hash = bcrypt_hash(password, cost)
    return password_hash

function verify_password_with_bcrypt(password, password_hash):
    // 验证密码
    // 安全：bcrypt 使用恒定时间比较
    
    try:
        is_valid = bcrypt_verify(password, password_hash)
        return is_valid
    catch error:
        log_error("Password verification failed: " + error)
        return false
```

---

## 补充说明

**技术栈**:
- **loro** = "1.0" - CRDT 文档存储
- **bcrypt** = "0.15" - 密码哈希（成本因子 12）
- **rusqlite** = "0.31" - SQLite 数据库
- **uuid** = "1.6" - UUID v7 生成
- **tokio** - 异步运行时

**设计模式**:
- **仓储模式**: PoolStore 作为数据访问层
- **观察者模式**: 订阅驱动的 SQLite 更新
- **约束强制**: 应用层的单池约束
- **缓存模式**: 两级缓存（内存 + 磁盘）

**安全考虑**:
- **密码哈希**: 使用成本因子 12 的 bcrypt
- **密码验证**: 通过 bcrypt 的恒定时间比较
- **访问控制**: 只有 Pool.device_ids 中的设备可以访问池数据
- **密码长度**: 最小 8 字符，最大 72 字符（bcrypt 限制）

**性能特征**:
- **缓存命中率**: > 90%（热池）
- **池加载时间**: < 10ms（缓存命中）
- **池创建时间**: < 100ms
- **密码哈希时间**: ~100ms（bcrypt 成本因子 12）

---

## 相关文档

**领域规格**:
- [../../domain/pool/model.md](../../domain/pool/model.md) - 池领域模型

**架构规格**:
- [./dual_layer.md](./dual_layer.md) - 双层架构
- [./card_store.md](./card_store.md) - CardStore 实现
- [./device_config.md](./device_config.md) - 设备配置
- [./loro_integration.md](./loro_integration.md) - Loro 集成
- [../sync/service.md](../sync/service.md) - P2P 同步服务
- [../security/password.md](../security/password.md) - 密码管理

**架构决策记录**:
- ADR-0001: 单池模型 - 每设备单池设计决策

---

## 测试覆盖

**测试文件**: `rust/tests/pool_store_test.rs`

**单元测试**:
- `test_create_pool()` - 创建池
- `test_create_pool_with_weak_password()` - 弱密码验证
- `test_load_pool()` - 加载池
- `test_load_nonexistent_pool()` - 加载不存在的池
- `test_update_pool_name()` - 更新池名称
- `test_join_pool_success()` - 成功加入池
- `test_join_pool_invalid_password()` - 无效密码
- `test_join_pool_rejects_second()` - 拒绝第二个池
- `test_leave_pool()` - 离开池
- `test_leave_pool_not_joined()` - 未加入时离开
- `test_add_card_to_pool()` - 添加卡片
- `test_add_card_idempotent()` - 幂等添加
- `test_remove_card_from_pool()` - 移除卡片
- `test_get_pool_cards()` - 获取池卡片
- `test_sqlite_sync()` - SQLite 同步
- `test_password_hashing()` - 密码哈希
- `test_password_verification()` - 密码验证
- `test_cache_hit()` - 缓存命中
- `test_cache_miss()` - 缓存未命中

**集成测试**:
- `test_pool_lifecycle()` - 池生命周期
- `test_multi_device_pool()` - 多设备池
- `test_pool_sync_across_devices()` - 跨设备同步
- `test_data_cleanup_on_leave()` - 离开时数据清理

**验收标准**:
- [x] 所有单元测试通过
- [x] 单池约束强制执行
- [x] 密码验证工作正常
- [x] 离开池时数据清理
- [x] 缓存提高性能
- [x] 代码审查通过
