# 单池模型规格

**版本**: 1.0.0
**状态**: 活跃
**依赖**: [types.md](types.md), [../architecture/storage/device_config.md](../architecture/storage/device_config.md)
**相关测试**: `rust/tests/pool_model_test.rs`

---

## 概述

本规格定义了单池模型,其中每张卡片仅属于一个池,每个设备最多只能加入一个池。当设备创建新卡片时,卡片自动属于设备已加入的池。

**技术栈**:
- **uuid** = "1.6" - UUID v7 生成
- **bcrypt** = "0.15" - 密码哈希验证
- **serde** = "1.0" - 序列化/反序列化

**核心原则**:
- **单池约束**: 每个设备最多加入一个池
- **自动归属**: 新卡片自动属于已加入的池
- **数据隔离**: 不同池的数据完全隔离
- **清理机制**: 离开池时清除所有相关数据

---

## 需求：单池约束

系统应强制要求设备最多只能加入一个池用于个人笔记。

### 场景：设备成功加入第一个池

- **前置条件**: 设备未加入任何池
- **操作**: 设备使用有效密码加入池
- **预期结果**: 该池应添加到设备的已加入池列表
- **并且**: 应开始该池的同步

**实现逻辑**:

```
function join_pool(device_config, pool_id, password):
    // 步骤1：检查单池约束
    // 设计决策：每个设备最多只能加入一个池
    if device_config.is_joined():
        current_pool = device_config.get_pool_id()
        return error "AlreadyJoinedPool: " + current_pool
    
    // 步骤2：验证池存在
    pool = load_pool(pool_id)
    if pool is error:
        return error "PoolNotFound: " + pool_id
    
    // 步骤3：验证密码
    // 安全：使用 bcrypt 恒定时间比较
    if not verify_password(password, pool.password_hash):
        return error "InvalidPassword"
    
    // 步骤4：将设备添加到池的设备列表
    device_id = device_config.device_id
    result = add_device_to_pool(pool_id, device_id)
    
    if result is error:
        return result
    
    // 步骤5：更新设备配置
    // 注意：这建立了设备-池关系
    device_config.set_pool_id(pool_id)
    device_config.save()
    
    // 步骤6：启动同步服务
    // 设计决策：加入池后立即开始同步
    start_sync_service(pool_id)
    
    log_info("Device " + device_id + " joined pool: " + pool_id)
    return success

function verify_password(password, password_hash):
    // 使用 bcrypt 验证密码
    // 安全：恒定时间比较防止时序攻击
    try:
        is_valid = bcrypt_verify(password, password_hash)
        return is_valid
    catch error:
        log_error("Password verification failed: " + error)
        return false
```

### 场景：设备拒绝加入第二个池

- **前置条件**: 设备已加入一个池
- **操作**: 设备尝试加入第二个池
- **预期结果**: 系统应拒绝该请求
- **并且**: 返回表明违反单池约束的错误

**实现逻辑**:

```
function enforce_single_pool_constraint(device_config, new_pool_id):
    // 强制执行单池约束
    // 设计决策：在应用层强制执行,确保数据一致性
    
    // 步骤1：检查设备是否已加入池
    if not device_config.is_joined():
        return success  // 未加入任何池,可以继续
    
    // 步骤2：获取当前池信息
    current_pool_id = device_config.get_pool_id()
    current_pool = load_pool(current_pool_id)
    
    // 步骤3：检查是否尝试加入不同的池
    if new_pool_id != current_pool_id:
        // 构造友好的错误消息
        pool_name = current_pool.pool_name
        error_message = "您已经加入了笔记空间'" + pool_name + "'"
        
        log_warn("Device attempted to join second pool: " + new_pool_id)
        return error "AlreadyJoinedPool: " + error_message
    
    // 步骤4：如果是同一个池,允许重新加入（幂等操作）
    log_debug("Device re-joining same pool: " + current_pool_id)
    return success

function get_joined_pool_info(device_config):
    // 获取已加入池的信息
    if not device_config.is_joined():
        return None
    
    pool_id = device_config.get_pool_id()
    pool = load_pool(pool_id)
    
    return {
        pool_id: pool_id,
        pool_name: pool.pool_name,
        joined_at: device_config.get_joined_at(),
        device_count: length(pool.device_ids)
    }
```

---

## 需求：在已加入池中创建卡片

当设备创建新卡片时,卡片应自动归属于设备已加入的池。

### 场景：创建卡片自动加入池

- **前置条件**: 设备已加入一个池
- **操作**: 用户创建新卡片
- **预期结果**: 卡片应在已加入的池中创建
- **并且**: 该池中的所有设备应可见该卡片

**实现逻辑**:

```
function create_card_in_pool(device_config, title, content):
    // 步骤1：验证设备已加入池
    // 设计决策：卡片必须属于某个池
    if not device_config.is_joined():
        return error "NotJoinedPool: 请先加入或创建笔记空间"
    
    // 步骤2：获取当前池 ID
    pool_id = device_config.get_pool_id()
    
    // 步骤3：创建卡片
    card = create_card(title, content)
    card.last_edit_device = device_config.device_id
    
    // 步骤4：将卡片添加到池
    // 注意：这建立了卡片-池关系
    result = add_card_to_pool(pool_id, card.id)
    
    if result is error:
        return result
    
    // 步骤5：保存卡片到 Loro 文档
    save_card_to_loro(card)
    
    // 步骤6：触发同步
    // 设计决策：新卡片立即同步到池中所有设备
    sync_card_to_pool(pool_id, card.id)
    
    log_info("Created card " + card.id + " in pool: " + pool_id)
    return card

function add_card_to_pool(pool_id, card_id):
    // 将卡片添加到池的卡片列表
    
    // 步骤1：加载池文档
    pool = load_pool(pool_id)
    if pool is error:
        return pool
    
    // 步骤2：检查卡片是否已在池中（幂等操作）
    if pool.card_ids.contains(card_id):
        log_debug("Card already in pool: " + card_id)
        return success
    
    // 步骤3：添加卡片 ID 到池
    pool.card_ids.append(card_id)
    pool.updated_at = get_current_timestamp_millis()
    
    // 步骤4：保存池文档
    save_pool(pool)
    
    log_debug("Added card " + card_id + " to pool: " + pool_id)
    return success

function sync_card_to_pool(pool_id, card_id):
    // 将新卡片同步到池中所有在线设备
    
    // 步骤1：获取池中所有在线设备
    online_devices = get_online_devices_in_pool(pool_id)
    
    // 步骤2：导出卡片更新
    card_updates = export_card_updates(card_id)
    
    // 步骤3：广播到所有在线设备
    for each device_id in online_devices:
        send_sync_message(device_id, {
            type: "CardCreated",
            pool_id: pool_id,
            card_id: card_id,
            updates: card_updates
        })
    
    log_debug("Synced card " + card_id + " to " + length(online_devices) + " devices")
    return success
```

### 场景：未加入池时创建卡片失败

- **前置条件**: 设备未加入任何池
- **操作**: 用户尝试创建新卡片
- **预期结果**: 系统应拒绝该请求
- **并且**: 返回表明未加入池的错误

**实现逻辑**:

```
function validate_can_create_card(device_config):
    // 验证设备是否可以创建卡片
    // 设计决策：必须先加入池才能创建卡片
    
    // 步骤1：检查设备是否已加入池
    if not device_config.is_joined():
        return error {
            code: "NotJoinedPool",
            message: "请先加入或创建笔记空间",
            action: "show_onboarding"
        }
    
    // 步骤2：验证池仍然存在
    pool_id = device_config.get_pool_id()
    pool = load_pool(pool_id)
    
    if pool is error:
        // 池已被删除,清理设备配置
        device_config.leave_pool()
        
        return error {
            code: "PoolNotFound",
            message: "笔记空间不存在,请重新加入",
            action: "show_onboarding"
        }
    
    // 步骤3：验证设备仍在池的设备列表中
    device_id = device_config.device_id
    if not pool.device_ids.contains(device_id):
        // 设备已被从池中移除
        device_config.leave_pool()
        
        return error {
            code: "DeviceRemovedFromPool",
            message: "您已被移出笔记空间",
            action: "show_onboarding"
        }
    
    return success

function handle_create_card_error(error):
    // 处理创建卡片错误
    
    if error.code == "NotJoinedPool":
        // 显示引导流程
        show_onboarding_screen()
        return
    
    if error.code == "PoolNotFound":
        // 显示池不存在提示
        show_error_dialog(error.message)
        show_onboarding_screen()
        return
    
    if error.code == "DeviceRemovedFromPool":
        // 显示被移除提示
        show_error_dialog(error.message)
        show_onboarding_screen()
        return
    
    // 其他错误
    show_error_dialog("创建卡片失败: " + error.message)
```

---

## 需求：设备离开池

当设备离开池时,系统应清除与该池关联的所有数据。

### 场景：设备离开池并清除数据

- **前置条件**: 设备已加入包含卡片的池
- **操作**: 设备离开该池
- **预期结果**: 所有池数据应从设备清除
- **并且**: 设备应不再与该池同步

**实现逻辑**:

```
function leave_pool(device_config):
    // 步骤1：验证设备已加入池
    if not device_config.is_joined():
        log_warn("Device not joined to any pool")
        return error "NotJoinedPool"
    
    pool_id = device_config.get_pool_id()
    device_id = device_config.device_id
    
    // 步骤2：停止同步服务
    // 设计决策：先停止同步,防止数据继续流入
    stop_sync_service()
    
    // 步骤3：从池的设备列表中移除设备
    // 注意：此变更将通过 P2P 同步到其他设备
    try:
        remove_device_from_pool(pool_id, device_id)
    catch error:
        // 即使移除失败,也继续清理本地数据
        log_error("Failed to remove device from pool: " + error)
    
    // 步骤4：清除所有本地数据
    // 设计决策：完全清理确保没有孤立数据
    delete_all_pool_data(pool_id)
    
    // 步骤5：清除设备配置
    device_config.leave_pool()
    device_config.save()
    
    log_info("Device left pool: " + pool_id)
    return success

function delete_all_pool_data(pool_id):
    // 清除池相关的所有本地数据
    
    // 步骤1：获取池中所有卡片 ID
    pool = load_pool(pool_id)
    card_ids = []
    
    if pool is not error:
        card_ids = pool.card_ids
    
    // 步骤2：删除所有卡片 Loro 文档
    for each card_id in card_ids:
        card_dir = get_loro_directory() + "/" + card_id
        if directory_exists(card_dir):
            delete_directory_recursive(card_dir)
            log_debug("Deleted card directory: " + card_id)
    
    // 步骤3：删除池 Loro 文档
    pool_dir = get_loro_directory() + "/" + pool_id
    if directory_exists(pool_dir):
        delete_directory_recursive(pool_dir)
        log_debug("Deleted pool directory: " + pool_id)
    
    // 步骤4：清除 SQLite 缓存
    // 注意：从缓存中移除所有池相关数据
    db = get_sqlite_connection()
    
    // 删除卡片数据
    db.execute("DELETE FROM cards WHERE id IN (
        SELECT card_id FROM card_pool_bindings WHERE pool_id = ?
    )", [pool_id])
    
    // 删除绑定关系
    db.execute("DELETE FROM card_pool_bindings WHERE pool_id = ?", [pool_id])
    
    // 删除池元数据
    db.execute("DELETE FROM pools WHERE pool_id = ?", [pool_id])
    
    // 步骤5：清除内存缓存
    clear_pool_cache(pool_id)
    
    log_info("Deleted all local data for pool: " + pool_id)
    return success

function remove_device_from_pool(pool_id, device_id):
    // 从池的设备列表中移除设备
    
    // 步骤1：加载池文档
    pool = load_pool(pool_id)
    if pool is error:
        return pool
    
    // 步骤2：移除设备 ID
    if pool.device_ids.contains(device_id):
        pool.device_ids.remove(device_id)
        pool.updated_at = get_current_timestamp_millis()
        
        // 步骤3：保存池文档
        save_pool(pool)
        
        // 步骤4：触发同步
        // 注意：通知其他设备此设备已离开
        sync_pool_to_devices(pool_id)
        
        log_debug("Removed device " + device_id + " from pool: " + pool_id)
    
    return success

function confirm_leave_pool(device_config):
    // 确认离开池操作
    // 设计决策：离开池是破坏性操作,需要用户确认
    
    pool_id = device_config.get_pool_id()
    pool = load_pool(pool_id)
    
    if pool is error:
        return true  // 池不存在,直接清理
    
    // 显示确认对话框
    card_count = length(pool.card_ids)
    message = "确定要退出笔记空间'" + pool.pool_name + "'吗？\n" +
              "这将删除本设备上的 " + card_count + " 张卡片。\n" +
              "其他设备上的数据不受影响。"
    
    return show_confirmation_dialog(message)
```

---

## 需求：单池行为规则

系统应强制执行单池模型的核心行为规则。

### 规则 1：设备最多加入一个池

- **给定**: 设备已加入 Pool A
- **当**: 设备尝试加入 Pool B
- **那么**: 系统应拒绝请求并提示"您已经加入了笔记空间'工作笔记'"

**实现逻辑**:

```
function validate_join_pool_request(device_config, new_pool_id):
    // 验证加入池请求
    
    // 规则 1：单池约束
    if device_config.is_joined():
        current_pool_id = device_config.get_pool_id()
        
        if new_pool_id != current_pool_id:
            current_pool = load_pool(current_pool_id)
            pool_name = current_pool.pool_name
            
            return error {
                code: "AlreadyJoinedPool",
                message: "您已经加入了笔记空间'" + pool_name + "'",
                current_pool_id: current_pool_id,
                current_pool_name: pool_name
            }
    
    return success
```

### 规则 2：卡片自动归属

- **给定**: 设备已加入 Pool A,用户创建新卡片
- **当**: 卡片创建成功
- **那么**: 卡片自动属于 Pool A

**实现逻辑**:

```
function auto_assign_card_to_pool(card, device_config):
    // 自动将卡片分配到设备已加入的池
    // 规则 2：卡片自动归属
    
    // 步骤1：获取设备已加入的池
    if not device_config.is_joined():
        return error "NotJoinedPool"
    
    pool_id = device_config.get_pool_id()
    
    // 步骤2：自动添加到池
    result = add_card_to_pool(pool_id, card.id)
    
    if result is error:
        return result
    
    log_info("Card " + card.id + " auto-assigned to pool: " + pool_id)
    return success
```

### 规则 3：退出空间数据清理

- **给定**: 用户退出当前空间
- **当**: 退出操作完成
- **那么**: 清理本地该空间的所有数据
- **并且**: 设备回到"未加入空间"状态

**实现逻辑**:

```
function complete_leave_pool_workflow(device_config):
    // 完整的离开池工作流
    // 规则 3：退出空间数据清理
    
    // 步骤1：确认操作
    if not confirm_leave_pool(device_config):
        return error "UserCancelled"
    
    // 步骤2：执行离开操作
    result = leave_pool(device_config)
    
    if result is error:
        return result
    
    // 步骤3：验证设备状态
    // 注意：设备应回到"未加入空间"状态
    assert not device_config.is_joined()
    assert device_config.get_pool_id() is None
    
    // 步骤4：显示成功消息
    show_success_message("已退出笔记空间,本地数据已清理")
    
    // 步骤5：导航到引导页面
    navigate_to_onboarding()
    
    log_info("Leave pool workflow completed")
    return success
```

---

## 实现细节

**技术栈**:
- **uuid** = "1.6" - UUID v7 生成
- **bcrypt** = "0.15" - 密码哈希验证
- **serde** = "1.0" - 序列化/反序列化
- **tokio** - 异步运行时

**数据结构**:
```rust
pub struct Pool {
    pub pool_id: String,              // UUID v7
    pub pool_name: String,            // 池名称
    pub password_hash: String,        // bcrypt 哈希
    pub card_ids: Vec<String>,        // 卡片 ID 列表
    pub device_ids: Vec<String>,      // 设备 ID 列表
    pub created_at: i64,             // Unix 毫秒
    pub updated_at: i64,             // Unix 毫秒
}

pub struct DeviceConfig {
    pub device_id: String,            // UUID v7
    pub pool_id: Option<String>,      // 已加入的池 ID
    pub joined_at: Option<i64>,       // 加入时间
}
```

**设计模式**:
- **约束强制模式**: 应用层强制单池约束
- **自动归属模式**: 新卡片自动属于已加入的池
- **清理模式**: 离开池时完全清理本地数据
- **确认模式**: 破坏性操作需要用户确认

**约束规则**:
- **单池约束**: 每个设备最多加入一个池
- **卡片归属**: 每张卡片必须属于某个池
- **数据隔离**: 不同池的数据完全隔离
- **清理完整性**: 离开池时清除所有相关数据

**错误处理**:
- **AlreadyJoinedPool**: 尝试加入第二个池
- **NotJoinedPool**: 未加入池时创建卡片
- **PoolNotFound**: 池不存在
- **DeviceRemovedFromPool**: 设备被从池中移除
- **InvalidPassword**: 密码验证失败

**性能特征**:
- **加入池**: < 100ms
- **创建卡片**: < 10ms
- **离开池**: < 1s (取决于数据量)
- **数据清理**: O(n) 其中 n 是卡片数量

---

## 测试覆盖

**测试文件**: `rust/tests/pool_model_test.rs`

**单元测试**:
- `test_join_first_pool()` - 成功加入第一个池
- `test_reject_second_pool()` - 拒绝加入第二个池
- `test_create_card_in_pool()` - 在池中创建卡片
- `test_create_card_without_pool()` - 未加入池时创建卡片失败
- `test_leave_pool()` - 离开池
- `test_data_cleanup_on_leave()` - 离开池时数据清理
- `test_auto_assign_card()` - 卡片自动归属
- `test_single_pool_constraint()` - 单池约束强制执行
- `test_pool_not_found()` - 池不存在错误处理
- `test_device_removed_from_pool()` - 设备被移除错误处理

**集成测试**:
- `test_pool_lifecycle()` - 完整池生命周期
- `test_multi_device_pool()` - 多设备池场景
- `test_concurrent_join_attempts()` - 并发加入尝试
- `test_leave_and_rejoin()` - 离开后重新加入

**验收标准**:
- [x] 所有单元测试通过
- [x] 单池约束强制执行
- [x] 卡片自动归属到池
- [x] 离开池时数据完全清理
- [x] 错误消息友好且准确
- [x] 代码审查通过

---

## 相关文档

**领域规格**:
- [card.md](card.md) - 卡片领域模型
- [sync.md](sync.md) - 同步领域模型
- [types.md](types.md) - 共享类型定义

**架构规格**:
- [../architecture/storage/pool_store.md](../architecture/storage/pool_store.md) - PoolStore 实现
- [../architecture/storage/device_config.md](../architecture/storage/device_config.md) - DeviceConfig 实现
- [../architecture/sync/service.md](../architecture/sync/service.md) - P2P 同步服务

**架构决策记录**:
- ADR-0001: 单池所有权模型 - 每设备单池设计决策

---

**最后更新**: 2026-02-02
**作者**: CardMind Team
