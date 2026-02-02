# Loro 集成架构规格

**状态**: 活跃
**依赖**: [./dual_layer.md](./dual_layer.md), [../sync/subscription.md](../sync/subscription.md)
**相关测试**: `rust/tests/loro_integration_test.rs`

---

## 概述

本规格定义了 Loro CRDT 库集成到 CardMind 中，包括文档管理、序列化、P2P 同步和版本控制。

**技术栈**:
- **loro** = "1.0" - CRDT 文档库
- **lru** = "0.12" - LRU 缓存实现
- **tokio** - 异步运行时
- **bincode** = "1.3" - 二进制序列化

**核心特性**:
- 基于 CRDT 的无冲突同步
- 高效的二进制序列化
- P2P 同步的增量更新
- 版本向量跟踪

---

## 需求：Loro 文档生命周期

系统应管理 Loro 文档生命周期，包括创建、加载、修改和持久化。

### 场景：创建新卡片 Loro 文档

- **前置条件**: 用户创建新卡片
- **操作**: 初始化 Loro 文档
- **预期结果**: 应创建包含卡片数据的 CRDT 文档
- **并且**: 文档应持久化到磁盘

**实现逻辑**:

```
function create_card_document(card):
    // 步骤1：初始化 CRDT 文档
    // 设计决策：每张卡片是独立的 CRDT 文档以实现独立同步
    crdt_doc = create_new_crdt_document()

    // 步骤2：将卡片字段存储在 CRDT 映射结构中
    // 注意：映射结构允许字段级冲突解决
    card_map = crdt_doc.get_map("card")
    card_map.set("id", card.id)
    card_map.set("title", card.title)
    card_map.set("content", card.content)
    card_map.set("created_at", card.created_at)
    card_map.set("updated_at", card.updated_at)
    card_map.set("deleted", card.deleted)
    
    // 步骤3：提交初始状态
    crdt_doc.commit()
    
    // 步骤4：持久化到磁盘
    file_path = get_card_document_path(card.id)
    save_document(crdt_doc, file_path)

    log_debug("Created Loro document for card: " + card.id)
    return crdt_doc
```

### 场景：创建新池 Loro 文档

- **前置条件**: 用户创建新数据池
- **操作**: 初始化池 Loro 文档
- **预期结果**: 应创建包含池元数据的 CRDT 文档
- **并且**: 列表字段应使用 CRDT List 类型

**实现逻辑**:

```
function create_pool_document(pool):
    // 步骤1：为池初始化 CRDT 文档
    crdt_doc = create_new_crdt_document()

    // 步骤2：在映射中存储池元数据
    pool_map = crdt_doc.get_map("pool")
    pool_map.set("pool_id", pool.pool_id)
    pool_map.set("pool_name", pool.pool_name)
    pool_map.set("password_hash", pool.password_hash)
    pool_map.set("created_at", pool.created_at)
    pool_map.set("updated_at", pool.updated_at)

    // 步骤3：存储卡片和设备列表
    // 设计决策：使用 CRDT 列表实现自动排序和无冲突插入
    card_list = crdt_doc.get_list("card_ids")
    for each card_id in pool.card_ids:
        card_list.append(card_id)

    device_list = crdt_doc.get_list("device_ids")
    for each device_id in pool.device_ids:
        device_list.append(device_id)
    
    // 步骤4：提交初始状态
    crdt_doc.commit()
    
    // 步骤5：持久化到磁盘
    file_path = get_pool_document_path(pool.pool_id)
    save_document(crdt_doc, file_path)

    log_debug("Created Loro document for pool: " + pool.pool_id)
    return crdt_doc
```

### 场景：从磁盘加载 Loro 文档

- **前置条件**: Loro 文档已保存到磁盘
- **操作**: 加载文档
- **预期结果**: 应从二进制快照恢复完整文档状态
- **并且**: 文档应可立即使用

**实现逻辑**:

```
function load_document(file_path):
    // 步骤1：验证文件存在
    if not file_exists(file_path):
        return error "DocumentNotFound"
    
    // 步骤2：从磁盘读取二进制快照
    try:
        binary_data = read_file(file_path)
    catch error:
        log_error("Failed to read document file: " + error)
        return error "FileReadError"

    // 步骤3：创建新 CRDT 文档并导入快照
    // 注意：快照包含完整文档状态
    crdt_doc = create_new_crdt_document()
    
    try:
        crdt_doc.import_snapshot(binary_data)
    catch error:
        log_error("Failed to import snapshot: " + error)
        return error "InvalidFormatError"

    log_debug("Loaded Loro document from: " + file_path)
    return crdt_doc

function save_document(crdt_doc, file_path):
    // 步骤1：将文档导出为二进制快照
    // 设计决策：使用快照格式进行磁盘存储（自包含）
    try:
        binary_snapshot = crdt_doc.export_snapshot()
    catch error:
        log_error("Failed to export snapshot: " + error)
        return error "ExportError"

    // 步骤2：确保目录存在
    directory = get_directory_from_path(file_path)
    ensure_directory_exists(directory)

    // 步骤3：原子写入磁盘
    // 设计决策：先写临时文件，再重命名以确保原子性
    temp_path = file_path + ".tmp"
    
    try:
        write_file(temp_path, binary_snapshot)
        rename_file(temp_path, file_path)
    catch error:
        // 清理临时文件
        if file_exists(temp_path):
            delete_file(temp_path)
        log_error("Failed to save document: " + error)
        return error "FileWriteError"

    log_debug("Saved Loro document to: " + file_path)
    return success

function get_card_document_path(card_id):
    // 获取卡片文档的文件路径
    // 格式: data/loro/<card_id>/snapshot.loro
    loro_dir = get_loro_directory()
    return loro_dir + "/" + card_id + "/snapshot.loro"

function get_pool_document_path(pool_id):
    // 获取池文档的文件路径
    // 格式: data/loro/<pool_id>/snapshot.loro
    loro_dir = get_loro_directory()
    return loro_dir + "/" + pool_id + "/snapshot.loro"
```

---

## 需求：增量同步

系统应使用 Loro 的版本向量支持增量同步。

### 场景：导出增量更新

- **前置条件**: 本地文档有新变更
- **操作**: 导出自指定版本以来的更新
- **预期结果**: 应返回仅包含新操作的二进制数据
- **并且**: 数据大小应小于完整快照

**实现逻辑**:

```
function export_updates(crdt_doc, since_version):
    // 仅导出指定版本之后发生的操作
    // 设计决策：使用版本向量跟踪因果历史
    // 注意：这使得网络上的高效增量同步成为可能
    
    try:
        incremental_updates = crdt_doc.export_from_version(since_version)
    catch error:
        log_error("Failed to export updates: " + error)
        return error "ExportError"

    log_debug("Exported " + byte_length(incremental_updates) + " bytes of updates")
    return incremental_updates

function import_updates(crdt_doc, binary_updates):
    // 步骤1：验证更新数据
    if binary_updates is empty:
        return success  // 无更新需要导入

    // 步骤2：从对等点导入操作
    // 注意：CRDT 自动处理冲突解决
    try:
        crdt_doc.import_operations(binary_updates)
    catch error:
        log_error("Failed to import updates: " + error)
        return error "ImportError"

    // 步骤3：提交变更
    // 设计决策：导入后立即提交以触发订阅
    crdt_doc.commit()

    log_debug("Imported " + byte_length(binary_updates) + " bytes of updates")
    return success

function get_current_version(crdt_doc):
    // 获取表示当前文档状态的版本向量
    // 注意：版本向量跟踪所有对等点的贡献
    version_vector = crdt_doc.get_version_vector()

    return version_vector
```

### 场景：两个设备之间同步

- **前置条件**: 两个设备在同一池中
- **操作**: 执行双向同步
- **预期结果**: 两个设备应交换增量更新
- **并且**: 同步后两个设备应有相同状态

**实现逻辑**:

```
function sync_with_peer(local_doc, peer_version, peer_connection):
    // 两个设备之间的双向同步协议

    // 步骤1：获取本地版本
    local_version = get_current_version(local_doc)

    // 步骤2：导出自对等点最后已知版本以来的本地更改
    // 设计决策：仅发送对等点没有的内容
    local_updates = export_updates(local_doc, peer_version)
    
    if local_updates is error:
        return local_updates

    // 步骤3：通过网络将更新发送到对等点
    try:
        peer_connection.send({
            type: "Updates",
            version: local_version,
            data: local_updates
        })
    catch error:
        log_error("Failed to send updates to peer: " + error)
        return error "NetworkError"

    // 步骤4：接收对等点的更新
    // 注意：对等点发送自我们最后已知版本以来的更改
    try:
        peer_message = peer_connection.receive()
    catch error:
        log_error("Failed to receive updates from peer: " + error)
        return error "NetworkError"

    // 步骤5：将对等点的更改合并到本地文档
    // 注意：CRDT 确保无冲突收敛
    if peer_message.data is not empty:
        result = import_updates(local_doc, peer_message.data)
        
        if result is error:
            return result

    // 步骤6：两个设备现在具有相同状态
    log_info("Sync completed successfully with peer")

    return success
```

---

## 需求：文档序列化

系统应使用 Loro 的高效二进制序列化进行存储和网络传输。

### 场景：快照 vs 增量更新

- **前置条件**: 需要同步文档
- **操作**: 选择最优同步方法
- **预期结果**: 应根据大小选择快照或增量更新
- **并且**: 应选择数据量更小的方法

**快照格式**:
- 完整文档状态
- 用于初始同步和磁盘持久化
- 更大但自包含

**增量更新格式**:
- 仅自某版本以来的操作
- 用于 P2P 同步
- 更小，需要基础版本

**实现逻辑**:

```
function export_snapshot(crdt_doc):
    // 将完整文档状态导出为二进制快照
    // 用例：磁盘存储、初始同步
    try:
        snapshot_binary = crdt_doc.export_full_snapshot()
    catch error:
        log_error("Failed to export snapshot: " + error)
        return error "ExportError"

    return snapshot_binary

function import_snapshot(crdt_doc, snapshot_binary):
    // 从快照导入完整文档状态
    // 注意：替换整个文档状态
    try:
        crdt_doc.import_full_snapshot(snapshot_binary)
    catch error:
        log_error("Failed to import snapshot: " + error)
        return error "ImportError"

    return success

function get_snapshot_size(crdt_doc):
    // 计算完整快照的大小
    // 设计决策：用于决定快照同步还是增量同步
    snapshot = export_snapshot(crdt_doc)
    
    if snapshot is error:
        return snapshot
    
    size = byte_length(snapshot)
    return size

function get_incremental_size(crdt_doc, since_version):
    // 计算增量更新的大小
    // 注意：与快照大小比较以选择最优同步方法
    updates = export_updates(crdt_doc, since_version)
    
    if updates is error:
        return updates
    
    size = byte_length(updates)
    return size

function choose_sync_method(crdt_doc, peer_version):
    // 选择最优同步方法
    // 设计决策：比较快照和增量大小，选择更小的
    
    // 步骤1：计算快照大小
    snapshot_size = get_snapshot_size(crdt_doc)
    
    if snapshot_size is error:
        return error "CannotCalculateSize"
    
    // 步骤2：计算增量大小
    incremental_size = get_incremental_size(crdt_doc, peer_version)
    
    if incremental_size is error:
        return error "CannotCalculateSize"
    
    // 步骤3：选择更小的方法
    if incremental_size < snapshot_size:
        log_debug("Using incremental sync: " + incremental_size + " < " + snapshot_size)
        return "incremental"
    else:
        log_debug("Using snapshot sync: " + snapshot_size + " <= " + incremental_size)
        return "snapshot"
```

---

## 需求：内存管理

系统应通过缓存和垃圾回收高效管理 Loro 文档内存。

### 场景：内存文档缓存

- **前置条件**: 频繁访问某些文档
- **操作**: 使用 LRU 缓存
- **预期结果**: 热文档应保持在内存中
- **并且**: 冷文档应被自动驱逐

**实现逻辑**:

```
structure DocumentCache:
    // 频繁访问的 CRDT 文档的 LRU 缓存
    // 设计决策：将热文档保存在内存中以避免磁盘 I/O

    cache_storage: LRU_map
    max_cache_size: integer

    function initialize(max_size):
        // 创建具有最大大小限制的缓存
        this.cache_storage = create_lru_cache(max_size)
        this.max_cache_size = max_size
        
        log_info("Document cache initialized with max size: " + max_size)

    function get_or_load(document_id, file_path):
        // 步骤1：检查文档是否在缓存中
        if cache_storage.contains(document_id):
            log_debug("Cache hit for document: " + document_id)
            return cache_storage.get(document_id)

        // 步骤2：缓存未命中 - 从磁盘加载
        // 注意：LRU 自动驱逐最近最少使用的文档
        log_debug("Cache miss for document: " + document_id)
        
        crdt_doc = load_document(file_path)
        
        if crdt_doc is error:
            return crdt_doc
        
        // 步骤3：添加到缓存
        cache_storage.put(document_id, crdt_doc)

        return crdt_doc

    function put(document_id, crdt_doc):
        // 在缓存中添加或更新文档
        cache_storage.put(document_id, crdt_doc)
        
        log_debug("Document cached: " + document_id)

    function remove(document_id):
        // 从缓存中移除文档
        cache_storage.remove(document_id)
        
        log_debug("Document removed from cache: " + document_id)

    function clear():
        // 清除所有缓存的文档
        cache_storage.clear()
        
        log_info("Document cache cleared")
    
    function get_cache_stats():
        // 获取缓存统计信息
        return {
            size: cache_storage.size(),
            max_size: max_cache_size,
            hit_rate: cache_storage.get_hit_rate()
        }
```

### 场景：旧操作的垃圾回收

- **前置条件**: 文档操作历史过大
- **操作**: 压缩文档
- **预期结果**: 应移除操作历史
- **并且**: 应保留当前状态

**实现逻辑**:

```
function compact_document(crdt_doc):
    // 通过移除操作历史减少文档大小
    // 设计决策：仅保留当前状态，丢弃历史操作

    // 步骤1：将当前状态导出为快照
    current_state = export_snapshot(crdt_doc)
    
    if current_state is error:
        return current_state

    // 步骤2：从快照创建新文档
    // 注意：新文档具有相同状态但没有操作历史
    compacted_doc = create_new_crdt_document()
    result = import_snapshot(compacted_doc, current_state)
    
    if result is error:
        return result

    log_info("Document compacted successfully")
    return compacted_doc

function should_compact(crdt_doc):
    // 确定文档是否应该压缩
    // 设计决策：当操作历史比状态大 3 倍时压缩

    // 步骤1：计算快照大小（仅当前状态）
    snapshot_size = get_snapshot_size(crdt_doc)
    
    if snapshot_size is error:
        return false

    // 步骤2：计算完整大小（状态 + 所有操作）
    empty_version = create_empty_version_vector()
    full_size = get_incremental_size(crdt_doc, empty_version)
    
    if full_size is error:
        return false

    // 步骤3：比较大小
    // 注意：阈值平衡内存使用与同步效率
    threshold = snapshot_size * 3
    
    if full_size > threshold:
        log_info("Document should be compacted: " + full_size + " > " + threshold)
        return true
    else:
        return false

function auto_compact_if_needed(document_id, crdt_doc):
    // 自动压缩文档（如果需要）
    // 设计决策：在保存前检查是否需要压缩
    
    if should_compact(crdt_doc):
        compacted_doc = compact_document(crdt_doc)
        
        if compacted_doc is not error:
            // 保存压缩后的文档
            file_path = get_card_document_path(document_id)
            save_document(compacted_doc, file_path)
            
            return compacted_doc
    
    return crdt_doc
```

---

## 需求：错误处理

系统应优雅地处理 Loro 特定错误。

### 场景：处理导入错误

- **前置条件**: 接收到损坏的更新数据
- **操作**: 尝试导入
- **预期结果**: 应返回明确的错误
- **并且**: 不应破坏现有文档状态

### 场景：处理版本不匹配

- **前置条件**: 对等点版本向量不兼容
- **操作**: 尝试同步
- **预期结果**: 应返回版本不匹配错误
- **并且**: 应建议使用快照同步

**错误类型**:

```
error ImportError:
    // 无法将更新导入 CRDT 文档
    message: string
    cause: optional error

error ExportError:
    // 无法从 CRDT 文档导出更新
    message: string
    cause: optional error

error InvalidFormatError:
    // 二进制数据不是有效的 CRDT 格式
    message: string
    data_size: integer

error VersionMismatchError:
    // 同步期间版本向量不匹配
    expected_version: string
    actual_version: string

error DocumentNotFoundError:
    // 请求的文档不存在
    document_id: string
    file_path: string

error FileReadError:
    // 无法读取文档文件
    file_path: string
    cause: error

error FileWriteError:
    // 无法写入文档文件
    file_path: string
    cause: error

error NetworkError:
    // 网络通信失败
    message: string
    peer_id: string
```

**实现逻辑**:

```
function handle_import_error(error, crdt_doc, peer_id):
    // 处理导入错误
    // 设计决策：记录错误并建议回退到快照同步
    
    log_error("Import failed from peer " + peer_id + ": " + error.message)
    
    // 建议使用快照同步
    return {
        action: "use_snapshot_sync",
        reason: "incremental_import_failed"
    }

function handle_version_mismatch(error, crdt_doc, peer_id):
    // 处理版本不匹配
    // 设计决策：强制快照同步以重新建立共同基础
    
    log_warn("Version mismatch with peer " + peer_id)
    log_warn("Expected: " + error.expected_version)
    log_warn("Actual: " + error.actual_version)
    
    return {
        action: "force_snapshot_sync",
        reason: "version_mismatch"
    }
```

---

## 补充说明

**技术栈**:
- **loro** = "1.0" - CRDT 文档库
- **lru** = "0.12" - LRU 缓存实现
- **tokio** - 异步运行时
- **bincode** = "1.3" - 二进制序列化

**设计模式**:
- **仓储模式**: 文档存储抽象
- **旁路缓存模式**: 热文档的 LRU 缓存
- **工厂模式**: 文档创建
- **策略模式**: 同步方法选择（快照 vs 增量）

**性能特征**:
- **快照大小**: 每张卡片约 1KB
- **增量更新**: 每个操作约 100 字节
- **导入速度**: 每次更新约 1ms
- **导出速度**: 每次更新约 0.5ms
- **缓存命中率**: > 80%（热文档）

**内存管理**:
- **文档缓存**: 最多 100 个文档
- **自动压缩**: 当历史 > 状态 × 3 时触发
- **LRU 驱逐**: 自动移除冷文档

---

## 相关文档

**架构规格**:
- [./dual_layer.md](./dual_layer.md) - 双层架构
- [./card_store.md](./card_store.md) - CardStore 实现
- [./pool_store.md](./pool_store.md) - PoolStore 实现
- [../sync/subscription.md](../sync/subscription.md) - 订阅机制
- [../sync/conflict_resolution.md](../sync/conflict_resolution.md) - 冲突解决

**架构决策记录**:
- ADR-0003: Loro CRDT - CRDT 库选择理由

---

## 测试覆盖

**测试文件**: `rust/tests/loro_integration_test.rs`

**单元测试**:
- `test_create_card_document()` - 卡片文档创建
- `test_create_pool_document()` - 池文档创建
- `test_load_save_document()` - 文档持久化
- `test_export_import_updates()` - 增量更新
- `test_incremental_sync()` - 增量同步
- `test_snapshot_sync()` - 快照同步
- `test_document_cache()` - 缓存管理
- `test_cache_hit_miss()` - 缓存命中/未命中
- `test_garbage_collection()` - 文档压缩
- `test_should_compact()` - 压缩判断
- `test_choose_sync_method()` - 同步方法选择
- `test_error_handling()` - 错误处理
- `test_version_vector()` - 版本向量跟踪

**集成测试**:
- `test_end_to_end_sync()` - 端到端同步
- `test_multi_device_sync()` - 多设备同步
- `test_concurrent_edits()` - 并发编辑
- `test_network_failure_recovery()` - 网络故障恢复

**验收标准**:
- [x] 所有单元测试通过
- [x] 增量同步工作正常
- [x] 缓存提高性能
- [x] 文档压缩正常工作
- [x] 错误处理健壮
- [x] 代码审查通过
