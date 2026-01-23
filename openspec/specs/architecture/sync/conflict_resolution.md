# Conflict Resolution Architecture Specification
# 冲突解决架构规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: Active

**Dependencies**: [../../domain/sync/model.md](../../domain/sync/model.md), [../storage/dual_layer.md](../storage/dual_layer.md), [../storage/loro_integration.md](../storage/loro_integration.md)
**依赖**: [../../domain/sync/model.md](../../domain/sync/model.md), [../storage/dual_layer.md](../storage/dual_layer.md), [../storage/loro_integration.md](../storage/loro_integration.md)

**Related Tests**: `rust/tests/conflict_resolution_test.rs`
**相关测试**: `rust/tests/conflict_resolution_test.rs`

---

## Overview
## 概述

This specification defines the conflict resolution mechanism for CardMind's P2P synchronization, using Loro CRDT (Conflict-free Replicated Data Type) to automatically merge concurrent edits without user intervention.

本规格定义了 CardMind P2P 同步的冲突解决机制，使用 Loro CRDT（无冲突复制数据类型）自动合并并发编辑，无需用户干预。

**Key Principles**:
**核心原则**:
- **Automatic Conflict Resolution**: No user intervention required
- **自动冲突解决**: 无需用户干预
- **Eventual Consistency**: All devices converge to the same state
- **最终一致性**: 所有设备收敛到相同状态
- **Causality Preservation**: Maintains causal relationships between edits
- **因果关系保持**: 维护编辑之间的因果关系
- **Commutative Operations**: Order of operations doesn't affect final state
- **可交换操作**: 操作顺序不影响最终状态

---

## Requirement: CRDT-Based Conflict Resolution
## 需求：基于 CRDT 的冲突解决

The system SHALL use Loro CRDT to automatically resolve conflicts without user intervention.

系统应使用 Loro CRDT 自动解决冲突，无需用户干预。

### Scenario: Concurrent edits to different fields
### 场景：对不同字段的并发编辑

- **GIVEN**: Device A edits card title to "New Title"
- **前置条件**: 设备 A 将卡片标题编辑为 "New Title"
- **AND**: Device B edits card content to "New Content" (concurrently)
- **并且**: 设备 B 将卡片内容编辑为 "New Content"（并发）
- **WHEN**: Both devices sync their changes
- **操作**: 两个设备同步它们的变更
- **THEN**: The final card SHALL have both changes
- **预期结果**: 最终卡片应具有两个变更
- **AND**: Title SHALL be "New Title"
- **并且**: 标题应为 "New Title"
- **AND**: Content SHALL be "New Content"
- **并且**: 内容应为 "New Content"
- **AND**: No data SHALL be lost
- **并且**: 不应丢失任何数据

**Implementation**:
**实现**:

```
// Pseudocode: Merge concurrent field edits
// 伪代码：合并并发字段编辑

function merge_concurrent_field_edits(crdt_document, remote_updates):
    // Step 1: Import remote updates into local CRDT document
    // 步骤1：将远程更新导入本地CRDT文档
    // Design decision: CRDT automatically handles field-level merging
    // 设计决策：CRDT自动处理字段级合并
    crdt_document.import(remote_updates)

    // Step 2: CRDT automatically merges changes
    // 步骤2：CRDT自动合并变更
    // Note: No manual conflict resolution needed
    // 注意：无需手动冲突解决
    // - Different fields are merged independently
    // - 不同字段独立合并
    // - Each field retains its latest value
    // - 每个字段保留其最新值

    return success
```

### Scenario: Concurrent edits to the same field (Last-Write-Wins)
### 场景：对同一字段的并发编辑（最后写入优先）

- **GIVEN**: Device A sets title to "Title A" at timestamp T1
- **前置条件**: 设备 A 在时间戳 T1 将标题设置为 "Title A"
- **AND**: Device B sets title to "Title B" at timestamp T2 (T2 > T1)
- **并且**: 设备 B 在时间戳 T2 将标题设置为 "Title B"（T2 > T1）
- **WHEN**: Both devices sync their changes
- **操作**: 两个设备同步它们的变更
- **THEN**: The final title SHALL be "Title B"
- **预期结果**: 最终标题应为 "Title B"
- **AND**: The later timestamp SHALL win
- **并且**: 较晚的时间戳应获胜

**Rationale**:
**理由**:
- Loro uses Last-Write-Wins (LWW) for simple scalar values
- Loro 对简单标量值使用最后写入优先（LWW）
- Timestamp-based ordering ensures deterministic resolution
- 基于时间戳的排序确保确定性解决
- All devices converge to the same final value
- 所有设备收敛到相同的最终值

**Implementation**:
**实现**:

```
// Pseudocode: Last-Write-Wins resolution
// 伪代码：最后写入优先解决

function demonstrate_last_write_wins():
    // Step 1: Device A sets field value
    // 步骤1：设备A设置字段值
    doc_a = create_crdt_document()
    doc_a.set_field("title", "Title A")

    // Step 2: Device B sets same field value (concurrently)
    // 步骤2：设备B设置相同字段值（并发）
    doc_b = create_crdt_document()
    doc_b.set_field("title", "Title B")

    // Step 3: Bidirectional sync
    // 步骤3：双向同步
    // Design decision: Use Lamport timestamps for deterministic ordering
    // 设计决策：使用Lamport时间戳实现确定性排序
    updates_from_b = doc_b.export_updates()
    doc_a.import(updates_from_b)

    updates_from_a = doc_a.export_updates()
    doc_b.import(updates_from_a)

    // Step 4: Convergence
    // 步骤4：收敛
    // Note: Both documents converge to the value with later timestamp
    // 注意：两个文档收敛到具有较晚时间戳的值
    // - Timestamp comparison is deterministic
    // - 时间戳比较是确定性的
    // - All devices reach same final state
    // - 所有设备达到相同最终状态

    assert doc_a.get_field("title") == doc_b.get_field("title")

    return success
```

---

## Requirement: Text Editing Conflict Resolution
## 需求：文本编辑冲突解决

The system SHALL use Loro's Text CRDT for collaborative text editing with automatic conflict resolution.

系统应使用 Loro 的 Text CRDT 进行协作文本编辑并自动解决冲突。

### Scenario: Concurrent text insertions at different positions
### 场景：在不同位置的并发文本插入

- **GIVEN**: Card content is "Hello World"
- **前置条件**: 卡片内容为 "Hello World"
- **AND**: Device A inserts "Beautiful " at position 6 → "Hello Beautiful World"
- **并且**: 设备 A 在位置 6 插入 "Beautiful " → "Hello Beautiful World"
- **AND**: Device B inserts "!" at position 11 → "Hello World!" (concurrently)
- **并且**: 设备 B 在位置 11 插入 "!" → "Hello World!"（并发）
- **WHEN**: Both devices sync their changes
- **操作**: 两个设备同步它们的变更
- **THEN**: The final content SHALL be "Hello Beautiful World!"
- **预期结果**: 最终内容应为 "Hello Beautiful World!"
- **AND**: Both insertions SHALL be preserved
- **并且**: 两个插入都应被保留

**Implementation**:
**实现**:

```
// Pseudocode: Merge concurrent text insertions
// 伪代码：合并并发文本插入

function merge_text_insertions():
    // Step 1: Device A performs text operations
    // 步骤1：设备A执行文本操作
    doc_a = create_crdt_document()
    text_a = doc_a.get_text_field("content")
    text_a.insert(position=0, text="Hello World")
    text_a.insert(position=6, text="Beautiful ")  // Result: "Hello Beautiful World"

    // Step 2: Device B performs text operations (from same base)
    // 步骤2：设备B执行文本操作（从相同基础）
    doc_b = create_crdt_document()
    text_b = doc_b.get_text_field("content")
    text_b.insert(position=0, text="Hello World")
    text_b.insert(position=11, text="!")  // Result: "Hello World!"

    // Step 3: Bidirectional sync
    // 步骤3：双向同步
    // Design decision: Text CRDT tracks character-level operations
    // 设计决策：文本CRDT跟踪字符级操作
    updates_from_b = doc_b.export_updates()
    doc_a.import(updates_from_b)

    updates_from_a = doc_a.export_updates()
    doc_b.import(updates_from_a)

    // Step 4: Convergence
    // 步骤4：收敛
    // Note: Both insertions are preserved in final result
    // 注意：两个插入都在最终结果中保留
    // - Character positions are tracked by unique IDs
    // - 字符位置通过唯一ID跟踪
    // - Insertions are merged based on causal relationships
    // - 插入基于因果关系合并

    assert text_a.to_string() == "Hello Beautiful World!"
    assert text_b.to_string() == "Hello Beautiful World!"

    return success
```

### Scenario: Concurrent text deletions
### 场景：并发文本删除

- **GIVEN**: Card content is "Hello Beautiful World"
- **前置条件**: 卡片内容为 "Hello Beautiful World"
- **AND**: Device A deletes "Beautiful " → "Hello World"
- **并且**: 设备 A 删除 "Beautiful " → "Hello World"
- **AND**: Device B deletes "Hello " → "Beautiful World" (concurrently)
- **并且**: 设备 B 删除 "Hello " → "Beautiful World"（并发）
- **WHEN**: Both devices sync their changes
- **操作**: 两个设备同步它们的变更
- **THEN**: The final content SHALL be "World"
- **预期结果**: 最终内容应为 "World"
- **AND**: Both deletions SHALL be applied
- **并且**: 两个删除都应被应用

**Rationale**:
**理由**:
- Loro's Text CRDT tracks character-level operations
- Loro 的 Text CRDT 跟踪字符级操作
- Deletions are applied based on character IDs, not positions
- 删除基于字符 ID 应用，而非位置
- Ensures consistent results regardless of operation order
- 确保无论操作顺序如何都有一致的结果

---

## Requirement: List Conflict Resolution
## 需求：列表冲突解决

The system SHALL use Loro's List CRDT for managing arrays (e.g., Pool.card_ids) with automatic conflict resolution.

系统应使用 Loro 的 List CRDT 管理数组（例如 Pool.card_ids）并自动解决冲突。

### Scenario: Concurrent additions to card list
### 场景：对卡片列表的并发添加

- **GIVEN**: Pool has card_ids = ["card1", "card2"]
- **前置条件**: 池有 card_ids = ["card1", "card2"]
- **AND**: Device A adds "card3" → ["card1", "card2", "card3"]
- **并且**: 设备 A 添加 "card3" → ["card1", "card2", "card3"]
- **AND**: Device B adds "card4" → ["card1", "card2", "card4"] (concurrently)
- **并且**: 设备 B 添加 "card4" → ["card1", "card2", "card4"]（并发）
- **WHEN**: Both devices sync their changes
- **操作**: 两个设备同步它们的变更
- **THEN**: The final list SHALL contain all cards
- **预期结果**: 最终列表应包含所有卡片
- **AND**: The list SHALL be ["card1", "card2", "card3", "card4"]
- **并且**: 列表应为 ["card1", "card2", "card3", "card4"]

**Implementation**:
**实现**:

```
// Pseudocode: Merge concurrent list additions
// 伪代码：合并并发列表添加

function merge_list_additions():
    // Step 1: Device A performs list operations
    // 步骤1：设备A执行列表操作
    doc_a = create_crdt_document()
    list_a = doc_a.get_list_field("card_ids")
    list_a.append("card1")
    list_a.append("card2")
    list_a.append("card3")

    // Step 2: Device B performs list operations (from same base)
    // 步骤2：设备B执行列表操作（从相同基础）
    doc_b = create_crdt_document()
    list_b = doc_b.get_list_field("card_ids")
    list_b.append("card1")
    list_b.append("card2")
    list_b.append("card4")

    // Step 3: Bidirectional sync
    // 步骤3：双向同步
    // Design decision: List CRDT preserves all additions
    // 设计决策：列表CRDT保留所有添加
    updates_from_b = doc_b.export_updates()
    doc_a.import(updates_from_b)

    updates_from_a = doc_a.export_updates()
    doc_b.import(updates_from_a)

    // Step 4: Convergence
    // 步骤4：收敛
    // Note: Both lists converge to contain all unique items
    // 注意：两个列表收敛为包含所有唯一项
    // - List elements are tracked by unique IDs
    // - 列表元素通过唯一ID跟踪
    // - Order is preserved based on causal relationships
    // - 顺序基于因果关系保留

    final_list_a = list_a.to_array()
    final_list_b = list_b.to_array()

    assert final_list_a == final_list_b
    assert "card3" in final_list_a
    assert "card4" in final_list_a

    return success
```

### Scenario: Concurrent removal from list
### 场景：从列表并发移除

- **GIVEN**: Pool has card_ids = ["card1", "card2", "card3"]
- **前置条件**: 池有 card_ids = ["card1", "card2", "card3"]
- **AND**: Device A removes "card2" → ["card1", "card3"]
- **并且**: 设备 A 移除 "card2" → ["card1", "card3"]
- **AND**: Device B removes "card3" → ["card1", "card2"] (concurrently)
- **并且**: 设备 B 移除 "card3" → ["card1", "card2"]（并发）
- **WHEN**: Both devices sync their changes
- **操作**: 两个设备同步它们的变更
- **THEN**: The final list SHALL be ["card1"]
- **预期结果**: 最终列表应为 ["card1"]
- **AND**: Both removals SHALL be applied
- **并且**: 两个移除都应被应用

---

## Requirement: Causality Preservation
## 需求：因果关系保持

The system SHALL preserve causal relationships between operations.

系统应保持操作之间的因果关系。

### Scenario: Dependent operations maintain causality
### 场景：依赖操作维护因果关系

- **GIVEN**: Device A creates card "card1"
- **前置条件**: 设备 A 创建卡片 "card1"
- **AND**: Device A adds "card1" to pool (causally dependent)
- **并且**: 设备 A 将 "card1" 添加到池（因果依赖）
- **WHEN**: Device B syncs these changes
- **操作**: 设备 B 同步这些变更
- **THEN**: Device B SHALL receive the card creation first
- **预期结果**: 设备 B 应首先接收卡片创建
- **AND**: Then receive the pool addition
- **并且**: 然后接收池添加
- **AND**: The causal order SHALL be preserved
- **并且**: 因果顺序应被保留

**Rationale**:
**理由**:
- Loro uses Lamport timestamps to track causality
- Loro 使用 Lamport 时间戳跟踪因果关系
- Operations are applied in causal order
- 操作按因果顺序应用
- Prevents inconsistent states (e.g., adding non-existent card to pool)
- 防止不一致状态（例如，将不存在的卡片添加到池）

**Implementation**:
**实现**:

```
// Pseudocode: Causality preservation
// 伪代码：因果关系保持

function demonstrate_causality():
    // Step 1: Device A performs causally related operations
    // 步骤1：设备A执行因果相关的操作
    doc_a = create_crdt_document()

    // Operation 1: Create card
    // 操作1：创建卡片
    cards_map = doc_a.get_map_field("cards")
    cards_map.set("card1", "Card 1 content")

    // Operation 2: Add card to pool (depends on operation 1)
    // 操作2：将卡片添加到池（依赖于操作1）
    // Design decision: Second operation is causally dependent on first
    // 设计决策：第二个操作因果依赖于第一个
    pool_list = doc_a.get_list_field("pool_card_ids")
    pool_list.append("card1")

    // Step 2: Export updates with causal ordering
    // 步骤2：导出带有因果顺序的更新
    // Note: CRDT tracks causal relationships using version vectors
    // 注意：CRDT使用版本向量跟踪因果关系
    updates = doc_a.export_updates()

    // Step 3: Device B imports updates
    // 步骤3：设备B导入更新
    doc_b = create_crdt_document()
    doc_b.import(updates)

    // Step 4: Verify causal order is preserved
    // 步骤4：验证因果顺序被保留
    // Note: CRDT ensures operation 1 is applied before operation 2
    // 注意：CRDT确保操作1在操作2之前应用
    // - Prevents inconsistent states
    // - 防止不一致状态
    // - Maintains data integrity
    // - 维护数据完整性

    assert doc_b.get_map_field("cards").has_key("card1")
    assert doc_b.get_list_field("pool_card_ids").length() == 1

    return success
```

---

## Requirement: Conflict-Free Convergence
## 需求：无冲突收敛

The system SHALL guarantee that all devices converge to the same final state.

系统应保证所有设备收敛到相同的最终状态。

### Scenario: Multiple devices converge after complex edits
### 场景：多个设备在复杂编辑后收敛

- **GIVEN**: Three devices (A, B, C) make concurrent edits
- **前置条件**: 三个设备（A、B、C）进行并发编辑
- **WHEN**: All devices sync with each other
- **操作**: 所有设备相互同步
- **THEN**: All devices SHALL have identical final state
- **预期结果**: 所有设备应具有相同的最终状态
- **AND**: The convergence SHALL be deterministic
- **并且**: 收敛应是确定性的
- **AND**: No manual conflict resolution SHALL be required
- **并且**: 不应需要手动冲突解决

**Mathematical Guarantee**:
**数学保证**:
- CRDTs guarantee Strong Eventual Consistency (SEC)
- CRDT 保证强最终一致性（SEC）
- If all devices receive all updates, they converge to the same state
- 如果所有设备接收所有更新，它们收敛到相同状态
- Convergence is independent of message delivery order
- 收敛与消息传递顺序无关

---

## Implementation Details
## 实现细节

**Technology Stack**:
**技术栈**:
- **Loro**: CRDT library (v0.16+)
- **Loro**: CRDT 库（v0.16+）
- **Lamport Timestamps**: For causality tracking
- **Lamport 时间戳**: 用于因果关系跟踪
- **Version Vectors**: For tracking document versions
- **版本向量**: 用于跟踪文档版本

**CRDT Types Used**:
**使用的 CRDT 类型**:
- **Map CRDT**: For card fields (title, content, etc.)
- **Map CRDT**: 用于卡片字段（标题、内容等）
- **Text CRDT**: For collaborative text editing
- **Text CRDT**: 用于协作文本编辑
- **List CRDT**: For arrays (Pool.card_ids, Pool.device_ids)
- **List CRDT**: 用于数组（Pool.card_ids、Pool.device_ids）

**Design Patterns**:
**设计模式**:
- **CRDT Pattern**: Conflict-free replicated data types
- **CRDT 模式**: 无冲突复制数据类型
- **Operation-Based CRDT**: Operations are replicated, not state
- **基于操作的 CRDT**: 复制操作，而非状态
- **Eventual Consistency**: All replicas converge eventually
- **最终一致性**: 所有副本最终收敛

**Performance Considerations**:
**性能考虑**:
- **Incremental Sync**: Only sync changes, not full documents
- **增量同步**: 仅同步变更，而非完整文档
- **Compact Representation**: Loro uses efficient binary format
- **紧凑表示**: Loro 使用高效的二进制格式
- **Memory Efficiency**: Garbage collection of old operations
- **内存效率**: 旧操作的垃圾回收

---

## Test Coverage
## 测试覆盖

**Test File**: `rust/tests/conflict_resolution_test.rs`
**测试文件**: `rust/tests/conflict_resolution_test.rs`

**Unit Tests**:
**单元测试**:
- `test_concurrent_field_edits()` - Different field edits
- `test_concurrent_field_edits()` - 不同字段编辑
- `test_lww_same_field()` - Last-write-wins
- `test_lww_same_field()` - 最后写入优先
- `test_text_insertions()` - Concurrent text insertions
- `test_text_insertions()` - 并发文本插入
- `test_text_deletions()` - Concurrent text deletions
- `test_text_deletions()` - 并发文本删除
- `test_list_additions()` - Concurrent list additions
- `test_list_additions()` - 并发列表添加
- `test_list_removals()` - Concurrent list removals
- `test_list_removals()` - 并发列表移除
- `test_causality_preservation()` - Causality preservation
- `test_causality_preservation()` - 因果关系保持
- `test_three_way_convergence()` - Multi-device convergence
- `test_three_way_convergence()` - 多设备收敛

**Integration Tests**:
**集成测试**:
- Complex multi-device editing scenario
- 复杂的多设备编辑场景
- Network partition and recovery
- 网络分区和恢复
- Stress test with 100+ concurrent operations
- 100+ 并发操作的压力测试

**Acceptance Criteria**:
**验收标准**:
- [ ] All unit tests pass
- [ ] 所有单元测试通过
- [ ] Convergence guaranteed in all scenarios
- [ ] 所有场景中保证收敛
- [ ] No data loss in conflict scenarios
- [ ] 冲突场景中无数据丢失
- [ ] Performance acceptable (< 100ms merge time)
- [ ] 性能可接受（< 100ms 合并时间）
- [ ] Code review approved
- [ ] 代码审查通过

---

## Related Documents
## 相关文档

**Domain Specs**:
**领域规格**:
- [../../domain/sync/model.md](../../domain/sync/model.md) - Sync domain model
- [../../domain/sync/model.md](../../domain/sync/model.md) - 同步领域模型

**Architecture Specs**:
**架构规格**:
- [../storage/dual_layer.md](../storage/dual_layer.md) - Dual-layer architecture
- [../storage/dual_layer.md](../storage/dual_layer.md) - 双层架构
- [../storage/loro_integration.md](../storage/loro_integration.md) - Loro integration
- [../storage/loro_integration.md](../storage/loro_integration.md) - Loro 集成
- [./service.md](./service.md) - P2P sync service
- [./service.md](./service.md) - P2P 同步服务
- [./peer_discovery.md](./peer_discovery.md) - Peer discovery
- [./peer_discovery.md](./peer_discovery.md) - 对等点发现

**ADRs**:
**架构决策记录**:
- [../../../docs/adr/0003-loro-crdt.md](../../../docs/adr/0003-loro-crdt.md) - Loro CRDT selection
- [../../../docs/adr/0003-loro-crdt.md](../../../docs/adr/0003-loro-crdt.md) - Loro CRDT 选择

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23

**Authors**: CardMind Team
**作者**: CardMind Team
