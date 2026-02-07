# 同步领域模型规格

## 概述

本规格定义了同步领域模型，包括版本追踪、冲突解决策略和分布式卡片协作的同步状态管理。

**技术栈**:
- **loro** = "1.0" - CRDT 文档同步
- **tokio** - 异步运行时
- **serde** = "1.0" - 序列化/反序列化

**核心特性**:
- 版本向量追踪
- CRDT 自动冲突解决
- 增量同步
- 双向同步
- 原子性保证

---

## 需求：版本追踪

系统应追踪每张卡片和每个池的同步版本，以支持增量更新。

### 场景：按卡片追踪版本

- **前置条件**: 数据池中存在一张卡片
- **操作**: 卡片被修改
- **预期结果**: 系统应生成新的版本标识符
- **并且**: 版本应与卡片的 CRDT 状态一起存储

**实现逻辑**:

```
function track_card_version(card_id):
    // 步骤1：获取卡片的 Loro 文档
    loro_doc = load_loro_document(card_id)
    
    if loro_doc is error:
        return loro_doc
    
    // 步骤2：获取当前版本向量
    // 设计决策：版本向量跟踪所有设备的贡献
    version_vector = loro_doc.get_version_vector()
    
    // 步骤3：存储版本信息
    // 注意：版本向量与 CRDT 状态一起持久化
    version_info = {
        card_id: card_id,
        version: version_vector,
        timestamp: get_current_timestamp_millis()
    }
    
    log_debug("Tracked version for card " + card_id + ": " + version_vector)
    return version_info

function update_card_version(card_id):
    // 卡片修改时更新版本
    
    // 步骤1：获取 Loro 文档
    loro_doc = load_loro_document(card_id)
    
    // 步骤2：提交变更
    // 注意：commit() 会自动增加版本向量
    loro_doc.commit()
    
    // 步骤3：获取新版本
    new_version = loro_doc.get_version_vector()
    
    log_debug("Updated card version: " + new_version)
    return new_version
```

### 场景：增量同步使用版本

- **前置条件**: 设备 A 已同步到版本 V1
- **操作**: 设备 A 请求同步
- **预期结果**: 系统应仅发送版本 V1 之后的变更
- **并且**: 系统不应发送已同步的数据

**实现逻辑**:

```
function perform_incremental_sync(card_id, peer_version):
    // 步骤1：获取本地 Loro 文档
    local_doc = load_loro_document(card_id)
    
    if local_doc is error:
        return local_doc
    
    // 步骤2：导出自对等点版本以来的增量更新
    // 设计决策：仅发送对等点没有的操作
    incremental_updates = local_doc.export_from_version(peer_version)
    
    // 步骤3：计算更新大小
    update_size = byte_length(incremental_updates)
    
    log_debug("Exported " + update_size + " bytes of incremental updates")
    
    return {
        card_id: card_id,
        from_version: peer_version,
        to_version: local_doc.get_version_vector(),
        updates: incremental_updates,
        size: update_size
    }

function apply_incremental_updates(card_id, updates):
    // 应用增量更新到本地文档
    
    // 步骤1：获取本地文档
    local_doc = load_loro_document(card_id)
    
    // 步骤2：导入增量更新
    // 注意：CRDT 自动处理冲突
    result = local_doc.import_operations(updates)
    
    if result is error:
        return result
    
    // 步骤3：提交变更
    local_doc.commit()
    
    // 步骤4：保存到磁盘
    save_loro_document(card_id, local_doc)
    
    log_debug("Applied incremental updates to card: " + card_id)
    return success
```

---

## 需求：基于 CRDT 的冲突解决

系统应使用 CRDT（无冲突复制数据类型）自动解决冲突，无需用户干预。

### 场景：并发编辑自动合并

- **前置条件**: 设备 A 和设备 B 都在离线状态下编辑同一张卡片
- **操作**: 两个设备同步它们的变更
- **预期结果**: 系统应使用 CRDT 规则合并两个编辑
- **并且**: 两个设备应收敛到相同的最终状态
- **并且**: 不应需要用户干预

**实现逻辑**:

```
function merge_concurrent_edits(card_id, device_a_updates, device_b_updates):
    // 步骤1：创建新的 CRDT 文档
    merged_doc = create_crdt_document()
    
    // 步骤2：导入设备 A 的更新
    // 设计决策：CRDT 保证操作可交换
    result_a = merged_doc.import_operations(device_a_updates)
    
    if result_a is error:
        return result_a
    
    // 步骤3：导入设备 B 的更新
    // 注意：导入顺序不影响最终结果
    result_b = merged_doc.import_operations(device_b_updates)
    
    if result_b is error:
        return result_b
    
    // 步骤4：提交合并结果
    merged_doc.commit()
    
    // 步骤5：验证收敛性
    // 注意：两个设备应该得到相同的最终状态
    final_version = merged_doc.get_version_vector()
    
    log_info("Merged concurrent edits for card " + card_id)
    log_debug("Final version: " + final_version)
    
    return {
        card_id: card_id,
        merged_doc: merged_doc,
        final_version: final_version
    }

function verify_convergence(device_a_doc, device_b_doc):
    // 验证两个设备收敛到相同状态
    
    // 步骤1：获取版本向量
    version_a = device_a_doc.get_version_vector()
    version_b = device_b_doc.get_version_vector()
    
    // 步骤2：比较版本向量
    if version_a != version_b:
        log_error("Convergence failed: version mismatch")
        return false
    
    // 步骤3：比较文档内容
    content_a = device_a_doc.export_snapshot()
    content_b = device_b_doc.export_snapshot()
    
    if content_a != content_b:
        log_error("Convergence failed: content mismatch")
        return false
    
    log_info("Convergence verified successfully")
    return true
```

### 场景：简单字段采用最后写入优先

- **前置条件**: 设备 A 在时间 T1 将标题设置为 "A"
- **并且**: 设备 B 在时间 T2 将标题设置为 "B"（T2 > T1）
- **操作**: 两个变更都被同步
- **预期结果**: 最终标题应为 "B"
- **并且**: 较晚的时间戳应获胜

**实现逻辑**:

```
function apply_last_write_wins(field_name, value_a, timestamp_a, value_b, timestamp_b):
    // 简单字段的最后写入优先策略
    // 设计决策：使用 Lamport 时间戳确定顺序
    
    // 步骤1：比较时间戳
    if timestamp_a > timestamp_b:
        winner = value_a
        winner_timestamp = timestamp_a
        log_debug("Value A wins: " + value_a)
    else if timestamp_b > timestamp_a:
        winner = value_b
        winner_timestamp = timestamp_b
        log_debug("Value B wins: " + value_b)
    else:
        // 步骤2：时间戳相同时使用设备 ID 作为决胜因素
        // 注意：确保确定性结果
        if device_id_a < device_id_b:
            winner = value_a
            winner_timestamp = timestamp_a
        else:
            winner = value_b
            winner_timestamp = timestamp_b
        
        log_debug("Tie-breaker used, winner: " + winner)
    
    return {
        field: field_name,
        value: winner,
        timestamp: winner_timestamp
    }

function merge_card_fields(card_a, card_b):
    // 合并两张卡片的字段
    
    merged_card = create_empty_card()
    
    // 步骤1：合并标题（最后写入优先）
    title_result = apply_last_write_wins(
        "title",
        card_a.title, card_a.updated_at,
        card_b.title, card_b.updated_at
    )
    merged_card.title = title_result.value
    
    // 步骤2：合并内容（使用 Text CRDT）
    // 注意：内容使用操作转换,不是最后写入优先
    merged_card.content = merge_text_crdt(card_a.content, card_b.content)
    
    // 步骤3：合并标签（使用集合并集）
    merged_card.tags = merge_tags_as_set(card_a.tags, card_b.tags)
    
    // 步骤4：使用最新的时间戳
    merged_card.updated_at = max(card_a.updated_at, card_b.updated_at)
    
    return merged_card
```

---

## 需求：同步状态管理

系统应为每个对等设备维护同步状态，以追踪同步进度。

### 场景：按对等设备追踪同步状态

- **前置条件**: 设备 A 与设备 B 同步
- **操作**: 同步成功完成
- **预期结果**: 系统应记录设备 B 的最后同步版本
- **并且**: 系统应使用此版本进行下一次增量同步

**实现逻辑**:

```
structure SyncState:
    peer_id: String                    // 对等设备 ID
    last_sync_version: VersionVector   // 最后同步的版本
    last_sync_time: i64               // 最后同步时间戳
    sync_status: SyncStatus           // 同步状态

enum SyncStatus:
    Idle                              // 空闲
    Syncing                           // 同步中
    Failed                            // 失败
    Completed                         // 完成

function update_sync_state(peer_id, new_version):
    // 步骤1：获取或创建同步状态
    sync_state = get_sync_state(peer_id)
    
    if sync_state is None:
        sync_state = SyncState {
            peer_id: peer_id,
            last_sync_version: create_empty_version(),
            last_sync_time: 0,
            sync_status: Idle
        }
    
    // 步骤2：更新版本和时间戳
    sync_state.last_sync_version = new_version
    sync_state.last_sync_time = get_current_timestamp_millis()
    sync_state.sync_status = Completed
    
    // 步骤3：持久化同步状态
    // 设计决策：持久化确保重启后可恢复
    save_sync_state(sync_state)
    
    log_debug("Updated sync state for peer: " + peer_id)
    return sync_state

function get_last_sync_version(peer_id):
    // 获取对等设备的最后同步版本
    sync_state = get_sync_state(peer_id)
    
    if sync_state is None:
        // 首次同步,返回空版本
        return create_empty_version()
    
    return sync_state.last_sync_version
```

### 场景：同步状态在重启后持久化

- **前置条件**: 设备 A 已与设备 B 同步
- **操作**: 设备 A 重启
- **预期结果**: 同步状态应从持久化存储中恢复
- **并且**: 下一次同步应从最后已知版本继续

**实现逻辑**:

```
function save_sync_state(sync_state):
    // 持久化同步状态到磁盘
    
    // 步骤1：序列化同步状态
    serialized = serialize_to_json(sync_state)
    
    // 步骤2：写入文件
    // 设计决策：使用 JSON 格式便于调试
    file_path = get_sync_state_path(sync_state.peer_id)
    write_file(file_path, serialized)
    
    log_debug("Saved sync state for peer: " + sync_state.peer_id)
    return success

function load_sync_state(peer_id):
    // 从磁盘加载同步状态
    
    // 步骤1：检查文件是否存在
    file_path = get_sync_state_path(peer_id)
    
    if not file_exists(file_path):
        log_debug("No sync state found for peer: " + peer_id)
        return None
    
    // 步骤2：读取并反序列化
    try:
        serialized = read_file(file_path)
        sync_state = deserialize_from_json(serialized)
        
        log_debug("Loaded sync state for peer: " + peer_id)
        return sync_state
    catch error:
        log_error("Failed to load sync state: " + error)
        return None

function restore_sync_states_on_startup():
    // 启动时恢复所有同步状态
    
    // 步骤1：扫描同步状态目录
    sync_state_dir = get_sync_state_directory()
    state_files = list_files(sync_state_dir)
    
    // 步骤2：加载所有状态
    restored_count = 0
    for each file in state_files:
        peer_id = extract_peer_id_from_filename(file)
        sync_state = load_sync_state(peer_id)
        
        if sync_state is not None:
            cache_sync_state(sync_state)
            restored_count = restored_count + 1
    
    log_info("Restored " + restored_count + " sync states")
    return restored_count
```

---

## 需求：同步方向

系统应支持双向同步，允许推送和拉取变更。

### 场景：设备推送本地变更

- **前置条件**: 设备 A 有本地变更
- **操作**: 设备 A 发起与设备 B 的同步
- **预期结果**: 设备 A 应将其变更推送到设备 B
- **并且**: 设备 B 应将变更应用到其本地状态

**实现逻辑**:

```
function push_local_changes(peer_id, card_id):
    // 步骤1：获取对等设备的最后同步版本
    peer_version = get_last_sync_version(peer_id)
    
    // 步骤2：导出增量更新
    updates = perform_incremental_sync(card_id, peer_version)
    
    if updates is error:
        return updates
    
    // 步骤3：发送更新到对等设备
    // 设计决策：使用异步消息传递
    result = send_sync_message(peer_id, {
        type: "Push",
        card_id: card_id,
        from_version: peer_version,
        to_version: updates.to_version,
        updates: updates.updates
    })
    
    if result is error:
        return result
    
    // 步骤4：更新同步状态
    update_sync_state(peer_id, updates.to_version)
    
    log_info("Pushed changes to peer: " + peer_id)
    return success
```

### 场景：设备拉取远程变更

- **前置条件**: 设备 B 有设备 A 没有的变更
- **操作**: 设备 A 发起与设备 B 的同步
- **预期结果**: 设备 A 应从设备 B 拉取变更
- **并且**: 设备 A 应将变更应用到其本地状态

**实现逻辑**:

```
function pull_remote_changes(peer_id, card_id):
    // 步骤1：获取本地版本
    local_version = get_card_version(card_id)
    
    // 步骤2：请求对等设备的增量更新
    request = {
        type: "PullRequest",
        card_id: card_id,
        local_version: local_version
    }
    
    response = send_sync_message(peer_id, request)
    
    if response is error:
        return response
    
    // 步骤3：应用接收到的更新
    if response.updates is not empty:
        result = apply_incremental_updates(card_id, response.updates)
        
        if result is error:
            return result
        
        // 步骤4：更新同步状态
        update_sync_state(peer_id, response.to_version)
        
        log_info("Pulled changes from peer: " + peer_id)
    else:
        log_debug("No new changes from peer: " + peer_id)
    
    return success

function bidirectional_sync(peer_id, card_id):
    // 双向同步：同时推送和拉取
    
    // 步骤1：推送本地变更
    push_result = push_local_changes(peer_id, card_id)
    
    if push_result is error:
        log_error("Push failed: " + push_result.error)
    
    // 步骤2：拉取远程变更
    pull_result = pull_remote_changes(peer_id, card_id)
    
    if pull_result is error:
        log_error("Pull failed: " + pull_result.error)
    
    // 步骤3：检查是否都成功
    if push_result is success and pull_result is success:
        log_info("Bidirectional sync completed for card: " + card_id)
        return success
    else:
        return error "PartialSyncFailure"
```

---

## 需求：同步原子性

每个同步操作应是原子的，要么完全成功，要么完全失败。

### 场景：同步完全成功

- **前置条件**: 设备 A 发起与设备 B 的同步
- **操作**: 所有变更成功传输
- **预期结果**: 同步状态应被更新
- **并且**: 两个设备应具有一致的数据

**实现逻辑**:

```
function atomic_sync(peer_id, card_ids):
    // 原子同步多张卡片
    // 设计决策：要么全部成功,要么全部失败
    
    // 步骤1：开始同步事务
    transaction = begin_sync_transaction(peer_id)
    
    try:
        // 步骤2：同步所有卡片
        for each card_id in card_ids:
            result = bidirectional_sync(peer_id, card_id)
            
            if result is error:
                // 同步失败,回滚事务
                throw error "SyncFailed: " + card_id
        
        // 步骤3：提交事务
        transaction.commit()
        
        log_info("Atomic sync completed for " + length(card_ids) + " cards")
        return success
    catch error:
        // 步骤4：回滚事务
        transaction.rollback()
        
        log_error("Atomic sync failed, rolled back: " + error)
        return error
```

### 场景：同步失败并回滚

- **前置条件**: 设备 A 发起与设备 B 的同步
- **操作**: 同步期间发生错误
- **预期结果**: 同步应被中止
- **并且**: 不应应用部分变更
- **并且**: 同步状态应保持在先前版本

**实现逻辑**:

```
function rollback_sync(peer_id, transaction):
    // 回滚同步事务
    
    // 步骤1：恢复同步状态
    // 设计决策：保持最后成功同步的版本
    previous_state = transaction.get_previous_sync_state()
    restore_sync_state(peer_id, previous_state)
    
    // 步骤2：丢弃未提交的变更
    // 注意：Loro 文档的变更在 commit() 前不会持久化
    discard_uncommitted_changes()
    
    // 步骤3：清理临时数据
    transaction.cleanup()
    
    log_info("Rolled back sync for peer: " + peer_id)
    return success
```

---

## 需求：无冲突标签合并

系统应使用集合并集合并来自多个设备的标签，无冲突。

### 场景：使用集合并集合并标签

- **前置条件**: 设备 A 为卡片添加标签 "work"
- **并且**: 设备 B 为同一张卡片添加标签 "urgent"
- **操作**: 两个设备同步
- **预期结果**: 卡片应具有两个标签：["work", "urgent"]
- **并且**: 不应丢失任何标签

**实现逻辑**:

```
function merge_tags_as_set(tags_a, tags_b):
    // 使用集合并集合并标签
    // 设计决策：标签是集合,使用并集操作
    
    // 步骤1：转换为集合
    set_a = convert_to_set(tags_a)
    set_b = convert_to_set(tags_b)
    
    // 步骤2：计算并集
    merged_set = set_union(set_a, set_b)
    
    // 步骤3：转换回列表
    merged_tags = convert_to_vec(merged_set)
    
    // 步骤4：排序以确保确定性结果
    sort(merged_tags)
    
    log_debug("Merged tags: " + merged_tags)
    return merged_tags

function demonstrate_tag_merge():
    // 演示标签合并
    
    // 设备 A 添加标签
    tags_a = ["work"]
    
    // 设备 B 添加标签
    tags_b = ["urgent"]
    
    // 合并
    merged = merge_tags_as_set(tags_a, tags_b)
    
    // 验证结果
    assert merged.contains("work")
    assert merged.contains("urgent")
    assert length(merged) == 2
    
    log_info("Tag merge demonstration successful")
    return success
```

---

## 补充说明

**数据结构**:
```rust
pub struct SyncState {
    pub peer_id: String,
    pub last_sync_version: VersionVector,
    pub last_sync_time: i64,
    pub sync_status: SyncStatus,
}

pub enum SyncStatus {
    Idle,
    Syncing,
    Failed,
    Completed,
}

pub struct VersionVector {
    // Loro 内部版本向量表示
}
```

**设计模式**:
- **版本向量模式**: 追踪因果历史
- **CRDT 模式**: 无冲突自动合并
- **事务模式**: 原子性同步
- **状态机模式**: 同步状态管理

**冲突解决策略**:
- **简单字段**: 最后写入优先（LWW）
- **文本内容**: 操作转换（OT）
- **标签列表**: 集合并集
- **列表字段**: CRDT List

**性能特征**:
- **增量同步**: O(n) 其中 n 是变更数量
- **版本比较**: O(1)
- **合并操作**: O(n) 其中 n 是操作数量

---

## 相关文档

**领域规格**:
- [card.md](card.md) - 卡片领域模型
- [pool.md](pool.md) - 池领域模型
- [types.md](types.md) - 共享类型定义

**架构规格**:
- [../architecture/sync/service.md](../architecture/sync/service.md) - 同步服务
- [../architecture/sync/conflict_resolution.md](../architecture/sync/conflict_resolution.md) - 冲突解决
- [../architecture/sync/subscription.md](../architecture/sync/subscription.md) - 订阅机制
- [../architecture/storage/loro_integration.md](../architecture/storage/loro_integration.md) - Loro 集成

**架构决策记录**:
- ADR-0002: 双层架构 - 读写分离设计
- ADR-0003: Loro CRDT - CRDT 库选择

---

## 测试覆盖

**测试文件**: `rust/tests/sync_feature_test.rs`

**单元测试**:
- `test_version_tracking()` - 版本追踪
- `test_incremental_sync()` - 增量同步
- `test_concurrent_edit_merge()` - 并发编辑合并
- `test_sync_state_persistence()` - 同步状态持久化
- `test_last_write_wins()` - 最后写入优先
- `test_tag_merge()` - 标签合并
- `test_bidirectional_sync()` - 双向同步
- `test_atomic_sync()` - 原子性同步
- `test_sync_rollback()` - 同步回滚
- `test_convergence()` - 收敛性验证

**功能测试**:
- `test_multi_device_sync()` - 多设备同步
- `test_offline_sync()` - 离线同步
- `test_network_failure_recovery()` - 网络故障恢复
- `test_concurrent_sync_sessions()` - 并发同步会话

**验收标准**:
- [x] 所有单元测试通过
- [x] CRDT 冲突解决工作正常
- [x] 增量同步高效
- [x] 同步状态正确持久化
- [x] 原子性保证有效
- [x] 收敛性验证通过
- [x] 代码审查通过
