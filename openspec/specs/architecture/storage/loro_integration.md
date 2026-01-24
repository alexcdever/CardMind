# Loro Integration Architecture Specification
# Loro 集成架构规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: Active

**Dependencies**: [./dual_layer.md](./dual_layer.md), [../sync/subscription.md](../sync/subscription.md)
**依赖**: [./dual_layer.md](./dual_layer.md), [../sync/subscription.md](../sync/subscription.md)

**Related Tests**: `rust/tests/loro_integration_test.rs`
**相关测试**: `rust/tests/loro_integration_test.rs`

---

## Overview
## 概述

This specification defines the integration of Loro CRDT library into CardMind, including document management, serialization, P2P synchronization, and version control.

本规格定义了 Loro CRDT 库集成到 CardMind 中，包括文档管理、序列化、P2P 同步和版本控制。

**Loro Version**: v0.16+
**Loro 版本**: v0.16+

**Key Features**:
**核心特性**:
- CRDT-based conflict-free synchronization
- 基于 CRDT 的无冲突同步
- Efficient binary serialization
- 高效的二进制序列化
- Incremental updates for P2P sync
- P2P 同步的增量更新
- Version vector tracking
- 版本向量跟踪

---

## Requirement: Loro Document Lifecycle
## 需求：Loro 文档生命周期

The system SHALL manage Loro document lifecycle including creation, loading, modification, and persistence.

系统应管理 Loro 文档生命周期，包括创建、加载、修改和持久化。

### Scenario: Create new Loro document
### 场景：创建新 Loro 文档

**Implementation**:
**实现**:

```
function create_card_document(card):
    // Step 1: Initialize CRDT document
    // 步骤1：初始化 CRDT 文档
    // Design decision: Each card is a separate CRDT document for independent sync
    // 设计决策：每张卡片是独立的 CRDT 文档以实现独立同步
    crdt_doc = create_new_crdt_document()

    // Step 2: Store card fields in CRDT map structure
    // 步骤2：将卡片字段存储在 CRDT 映射结构中
    // Note: Map structure allows field-level conflict resolution
    // 注意：映射结构允许字段级冲突解决
    card_map = crdt_doc.get_map("card")
    card_map.set("id", card.id)
    card_map.set("title", card.title)
    card_map.set("content", card.content)
    card_map.set("created_at", card.created_at)
    card_map.set("updated_at", card.updated_at)
    card_map.set("deleted", card.deleted)

    return crdt_doc

function create_pool_document(pool):
    // Step 1: Initialize CRDT document for pool
    // 步骤1：为池初始化 CRDT 文档
    crdt_doc = create_new_crdt_document()

    // Step 2: Store pool metadata in map
    // 步骤2：在映射中存储池元数据
    pool_map = crdt_doc.get_map("pool")
    pool_map.set("pool_id", pool.pool_id)
    pool_map.set("pool_name", pool.pool_name)
    pool_map.set("password_hash", pool.password_hash)
    pool_map.set("created_at", pool.created_at)
    pool_map.set("updated_at", pool.updated_at)

    // Step 3: Store card and device lists
    // 步骤3：存储卡片和设备列表
    // Design decision: Use CRDT list for automatic ordering and conflict-free insertion
    // 设计决策：使用 CRDT 列表实现自动排序和无冲突插入
    card_list = crdt_doc.get_list("card_ids")
    for each card_id in pool.card_ids:
        card_list.append(card_id)

    device_list = crdt_doc.get_list("device_ids")
    for each device_id in pool.device_ids:
        device_list.append(device_id)

    return crdt_doc
```

### Scenario: Load Loro document from disk
### 场景：从磁盘加载 Loro 文档

**Implementation**:
**实现**:

```
function load_document(file_path):
    // Step 1: Read binary snapshot from disk
    // 步骤1：从磁盘读取二进制快照
    binary_data = read_file(file_path)

    // Step 2: Create new CRDT document and import snapshot
    // 步骤2：创建新 CRDT 文档并导入快照
    // Note: Snapshot contains full document state
    // 注意：快照包含完整文档状态
    crdt_doc = create_new_crdt_document()
    crdt_doc.import_snapshot(binary_data)

    return crdt_doc

function save_document(crdt_doc, file_path):
    // Step 1: Export document as binary snapshot
    // 步骤1：将文档导出为二进制快照
    // Design decision: Use snapshot format for disk storage (self-contained)
    // 设计决策：使用快照格式进行磁盘存储（自包含）
    binary_snapshot = crdt_doc.export_snapshot()

    // Step 2: Write to disk
    // 步骤2：写入磁盘
    write_file(file_path, binary_snapshot)

    return success
```

---

## Requirement: Incremental Synchronization
## 需求：增量同步

The system SHALL support incremental synchronization using Loro's version vectors.

系统应使用 Loro 的版本向量支持增量同步。

### Scenario: Export incremental updates
### 场景：导出增量更新

**Implementation**:
**实现**:

```
function export_updates(crdt_doc, since_version):
    // Export only operations that occurred after the specified version
    // 仅导出指定版本之后发生的操作
    // Design decision: Use version vectors to track causal history
    // 设计决策：使用版本向量跟踪因果历史
    // Note: This enables efficient incremental sync over network
    // 注意：这使得网络上的高效增量同步成为可能
    incremental_updates = crdt_doc.export_from_version(since_version)

    return incremental_updates

function import_updates(crdt_doc, binary_updates):
    // Step 1: Import operations from peer
    // 步骤1：从对等点导入操作
    // Note: CRDT automatically handles conflict resolution
    // 注意：CRDT 自动处理冲突解决
    crdt_doc.import_operations(binary_updates)

    // Step 2: Document state is now merged
    // 步骤2：文档状态现已合并
    // Design decision: No manual conflict resolution needed
    // 设计决策：无需手动冲突解决

    return success

function get_current_version(crdt_doc):
    // Get version vector representing current document state
    // 获取表示当前文档状态的版本向量
    // Note: Version vector tracks all peer contributions
    // 注意：版本向量跟踪所有对等点的贡献
    version_vector = crdt_doc.get_version_vector()

    return version_vector
```

### Scenario: Sync between two devices
### 场景：两个设备之间同步

**Implementation**:
**实现**:

```
function sync_with_peer(local_doc, peer_version, peer_connection):
    // Bidirectional sync protocol between two devices
    // 两个设备之间的双向同步协议

    // Step 1: Export local changes since peer's last known version
    // 步骤1：导出自对等点最后已知版本以来的本地更改
    // Design decision: Only send what peer doesn't have
    // 设计决策：仅发送对等点没有的内容
    local_updates = export_updates(local_doc, peer_version)

    // Step 2: Send updates to peer over network
    // 步骤2：通过网络将更新发送到对等点
    peer_connection.send(local_updates)

    // Step 3: Receive peer's updates
    // 步骤3：接收对等点的更新
    // Note: Peer sends their changes since our last known version
    // 注意：对等点发送自我们最后已知版本以来的更改
    peer_updates = peer_connection.receive()

    // Step 4: Merge peer's changes into local document
    // 步骤4：将对等点的更改合并到本地文档
    // Note: CRDT ensures convergence without conflicts
    // 注意：CRDT 确保无冲突收敛
    import_updates(local_doc, peer_updates)

    // Step 5: Both devices now have identical state
    // 步骤5：两个设备现在具有相同状态
    log("Sync completed successfully")

    return success
```

---

## Requirement: Document Serialization
## 需求：文档序列化

The system SHALL use Loro's efficient binary serialization for storage and network transfer.

系统应使用 Loro 的高效二进制序列化进行存储和网络传输。

### Scenario: Snapshot vs incremental updates
### 场景：快照 vs 增量更新

**Snapshot Format**:
**快照格式**:
- Full document state
- 完整文档状态
- Used for initial sync and disk persistence
- 用于初始同步和磁盘持久化
- Larger size but self-contained
- 更大但自包含

**Incremental Updates Format**:
**增量更新格式**:
- Only operations since a version
- 仅自某版本以来的操作
- Used for P2P sync
- 用于 P2P 同步
- Smaller size, requires base version
- 更小，需要基础版本

**Implementation**:
**实现**:

```
function export_snapshot(crdt_doc):
    // Export complete document state as binary snapshot
    // 将完整文档状态导出为二进制快照
    // Use case: Disk storage, initial sync
    // 用例：磁盘存储、初始同步
    snapshot_binary = crdt_doc.export_full_snapshot()

    return snapshot_binary

function import_snapshot(crdt_doc, snapshot_binary):
    // Import complete document state from snapshot
    // 从快照导入完整文档状态
    // Note: Replaces entire document state
    // 注意：替换整个文档状态
    crdt_doc.import_full_snapshot(snapshot_binary)

    return success

function get_snapshot_size(crdt_doc):
    // Calculate size of full snapshot
    // 计算完整快照的大小
    // Design decision: Used to decide between snapshot vs incremental sync
    // 设计决策：用于决定快照同步还是增量同步
    snapshot = crdt_doc.export_full_snapshot()
    size = byte_length(snapshot)

    return size

function get_incremental_size(crdt_doc, since_version):
    // Calculate size of incremental updates
    // 计算增量更新的大小
    // Note: Compare with snapshot size to choose optimal sync method
    // 注意：与快照大小比较以选择最优同步方法
    updates = crdt_doc.export_from_version(since_version)
    size = byte_length(updates)

    return size
```

---

## Requirement: Memory Management
## 需求：内存管理

The system SHALL manage Loro document memory efficiently with caching and garbage collection.

系统应通过缓存和垃圾回收高效管理 Loro 文档内存。

### Scenario: In-memory document cache
### 场景：内存文档缓存

**Implementation**:
**实现**:

```
class DocumentCache:
    // LRU cache for frequently accessed CRDT documents
    // 频繁访问的 CRDT 文档的 LRU 缓存
    // Design decision: Keep hot documents in memory to avoid disk I/O
    // 设计决策：将热文档保存在内存中以避免磁盘 I/O

    cache_storage: LRU_map
    max_cache_size: integer

    function initialize(max_size):
        // Create cache with maximum size limit
        // 创建具有最大大小限制的缓存
        this.cache_storage = create_lru_cache(max_size)
        this.max_cache_size = max_size

    function get_or_load(document_id, file_path):
        // Step 1: Check if document is in cache
        // 步骤1：检查文档是否在缓存中
        if cache_storage.contains(document_id):
            return cache_storage.get(document_id)

        // Step 2: Cache miss - load from disk
        // 步骤2：缓存未命中 - 从磁盘加载
        // Note: LRU automatically evicts least recently used document
        // 注意：LRU 自动驱逐最近最少使用的文档
        crdt_doc = load_document(file_path)
        cache_storage.put(document_id, crdt_doc)

        return crdt_doc

    function put(document_id, crdt_doc):
        // Add or update document in cache
        // 在缓存中添加或更新文档
        cache_storage.put(document_id, crdt_doc)

    function remove(document_id):
        // Remove document from cache
        // 从缓存中移除文档
        cache_storage.remove(document_id)

    function clear():
        // Clear all cached documents
        // 清除所有缓存的文档
        cache_storage.clear()
```

### Scenario: Garbage collection of old operations
### 场景：旧操作的垃圾回收

**Implementation**:
**实现**:

```
function compact_document(crdt_doc):
    // Reduce document size by removing operation history
    // 通过移除操作历史减少文档大小
    // Design decision: Keep only current state, discard historical operations
    // 设计决策：仅保留当前状态，丢弃历史操作

    // Step 1: Export current state as snapshot
    // 步骤1：将当前状态导出为快照
    current_state = crdt_doc.export_full_snapshot()

    // Step 2: Create new document from snapshot
    // 步骤2：从快照创建新文档
    // Note: New document has same state but no operation history
    // 注意：新文档具有相同状态但没有操作历史
    compacted_doc = create_new_crdt_document()
    compacted_doc.import_full_snapshot(current_state)

    return compacted_doc

function should_compact(crdt_doc):
    // Determine if document should be compacted
    // 确定文档是否应该压缩
    // Design decision: Compact when operation history is 3x larger than state
    // 设计决策：当操作历史比状态大 3 倍时压缩

    // Step 1: Calculate snapshot size (current state only)
    // 步骤1：计算快照大小（仅当前状态）
    snapshot_size = get_snapshot_size(crdt_doc)

    // Step 2: Calculate full size (state + all operations)
    // 步骤2：计算完整大小（状态 + 所有操作）
    full_size = get_incremental_size(crdt_doc, empty_version)

    // Step 3: Compare sizes
    // 步骤3：比较大小
    // Note: Threshold balances memory usage vs sync efficiency
    // 注意：阈值平衡内存使用与同步效率
    if full_size > snapshot_size * 3:
        return true
    else:
        return false
```

---

## Requirement: Error Handling
## 需求：错误处理

The system SHALL handle Loro-specific errors gracefully.

系统应优雅地处理 Loro 特定错误。

**Error Types**:
**错误类型**:

```
// CRDT-specific error types
// CRDT 特定的错误类型

error ImportError:
    // Failed to import updates into CRDT document
    // 无法将更新导入 CRDT 文档
    message: string

error ExportError:
    // Failed to export updates from CRDT document
    // 无法从 CRDT 文档导出更新
    message: string

error InvalidFormatError:
    // Binary data is not valid CRDT format
    // 二进制数据不是有效的 CRDT 格式
    message: string

error VersionMismatchError:
    // Version vector mismatch during sync
    // 同步期间版本向量不匹配
    expected_version: string
    actual_version: string

error DocumentNotFoundError:
    // Requested document does not exist
    // 请求的文档不存在
    document_id: string
```

---

## Implementation Details
## 实现细节

**Technology Stack**:
**技术栈**:
- **Loro**: v0.16+ CRDT library
- **Loro**: v0.16+ CRDT 库
- **lru**: LRU cache for document management
- **lru**: 文档管理的 LRU 缓存

**Design Patterns**:
**设计模式**:
- **Repository Pattern**: Document storage abstraction
- **仓储模式**: 文档存储抽象
- **Cache-Aside Pattern**: LRU cache for hot documents
- **旁路缓存模式**: 热文档的 LRU 缓存
- **Factory Pattern**: Document creation
- **工厂模式**: 文档创建

**Performance Characteristics**:
**性能特征**:
- **Snapshot Size**: ~1KB per card
- **快照大小**: 每张卡片约 1KB
- **Incremental Update**: ~100 bytes per operation
- **增量更新**: 每个操作约 100 字节
- **Import Speed**: ~1ms per update
- **导入速度**: 每次更新约 1ms
- **Export Speed**: ~0.5ms per update
- **导出速度**: 每次更新约 0.5ms

---

## Test Coverage
## 测试覆盖

**Test File**: `rust/tests/loro_integration_test.rs`
**测试文件**: `rust/tests/loro_integration_test.rs`

**Unit Tests**:
**单元测试**:
- `test_create_document()` - Document creation
- `test_create_document()` - 文档创建
- `test_load_save_document()` - Persistence
- `test_load_save_document()` - 持久化
- `test_incremental_sync()` - Incremental updates
- `test_incremental_sync()` - 增量更新
- `test_document_cache()` - Cache management
- `test_document_cache()` - 缓存管理
- `test_garbage_collection()` - Compaction
- `test_garbage_collection()` - 压缩

**Acceptance Criteria**:
**验收标准**:
- [ ] All unit tests pass
- [ ] 所有单元测试通过
- [ ] Incremental sync works
- [ ] 增量同步工作正常
- [ ] Cache improves performance
- [ ] 缓存提高性能
- [ ] Code review approved
- [ ] 代码审查通过

---

## Related Documents
## 相关文档

**Architecture Specs**:
**架构规格**:
- [./dual_layer.md](./dual_layer.md) - Dual-layer architecture
- [./dual_layer.md](./dual_layer.md) - 双层架构
- [../sync/subscription.md](../sync/subscription.md) - Subscription mechanism
- [../sync/subscription.md](../sync/subscription.md) - 订阅机制
- [../sync/conflict_resolution.md](../sync/conflict_resolution.md) - Conflict resolution
- [../sync/conflict_resolution.md](../sync/conflict_resolution.md) - 冲突解决

**ADRs**:
**架构决策记录**:
- [../../../docs/adr/0003-loro-crdt.md](../../../docs/adr/0003-loro-crdt.md) - Loro CRDT selection
- [../../../docs/adr/0003-loro-crdt.md](../../../docs/adr/0003-loro-crdt.md) - Loro CRDT 选择

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23

**Authors**: CardMind Team
**作者**: CardMind Team
