# 冲突解决架构规格

**版本**: 1.0.0

**状态**: 活跃

**依赖**: [../../domain/sync/model.md](../../domain/sync/model.md), [../storage/dual_layer.md](../storage/dual_layer.md), [../storage/loro_integration.md](../storage/loro_integration.md)

**相关测试**: `rust/tests/conflict_resolution_test.rs`

---

## 概述


本规格定义了 CardMind P2P 同步的冲突解决机制，使用 Loro CRDT（无冲突复制数据类型）自动合并并发编辑，无需用户干预。

**核心原则**:
- **自动冲突解决**: 无需用户干预
- **最终一致性**: 所有设备收敛到相同状态
- **因果关系保持**: 维护编辑之间的因果关系
- **可交换操作**: 操作顺序不影响最终状态

---

## 需求：基于 CRDT 的冲突解决


系统应使用 Loro CRDT 自动解决冲突，无需用户干预。

### 场景：对不同字段的并发编辑

- **前置条件**: 设备 A 将卡片标题编辑为 "New Title"
- **并且**: 设备 B 将卡片内容编辑为 "New Content"（并发）
- **操作**: 两个设备同步它们的变更
- **预期结果**: 最终卡片应具有两个变更
- **并且**: 标题应为 "New Title"
- **并且**: 内容应为 "New Content"
- **并且**: 不应丢失任何数据

**实现**:

```
// 伪代码：合并并发字段编辑

function merge_concurrent_field_edits(crdt_document, remote_updates):
    // 步骤1：将远程更新导入本地CRDT文档
    // 设计决策：CRDT自动处理字段级合并
    crdt_document.import(remote_updates)

    // 步骤2：CRDT自动合并变更
    // 注意：无需手动冲突解决
    // - 不同字段独立合并
    // - 每个字段保留其最新值

    return success
```

### 场景：对同一字段的并发编辑（最后写入优先）

- **前置条件**: 设备 A 在时间戳 T1 将标题设置为 "Title A"
- **并且**: 设备 B 在时间戳 T2 将标题设置为 "Title B"（T2 > T1）
- **操作**: 两个设备同步它们的变更
- **预期结果**: 最终标题应为 "Title B"
- **并且**: 较晚的时间戳应获胜

**理由**:
- Loro 对简单标量值使用最后写入优先（LWW）
- 基于时间戳的排序确保确定性解决
- 所有设备收敛到相同的最终值

**实现**:

```
// 伪代码：最后写入优先解决

function demonstrate_last_write_wins():
    // 步骤1：设备A设置字段值
    doc_a = create_crdt_document()
    doc_a.set_field("title", "Title A")

    // 步骤2：设备B设置相同字段值（并发）
    doc_b = create_crdt_document()
    doc_b.set_field("title", "Title B")

    // 步骤3：双向同步
    // 设计决策：使用Lamport时间戳实现确定性排序
    updates_from_b = doc_b.export_updates()
    doc_a.import(updates_from_b)

    updates_from_a = doc_a.export_updates()
    doc_b.import(updates_from_a)

    // 步骤4：收敛
    // 注意：两个文档收敛到具有较晚时间戳的值
    // - 时间戳比较是确定性的
    // - 所有设备达到相同最终状态

    assert doc_a.get_field("title") == doc_b.get_field("title")

    return success
```

---

## 需求：文本编辑冲突解决


系统应使用 Loro 的 Text CRDT 进行协作文本编辑并自动解决冲突。

### 场景：在不同位置的并发文本插入

- **前置条件**: 卡片内容为 "Hello World"
- **并且**: 设备 A 在位置 6 插入 "Beautiful " → "Hello Beautiful World"
- **并且**: 设备 B 在位置 11 插入 "!" → "Hello World!"（并发）
- **操作**: 两个设备同步它们的变更
- **预期结果**: 最终内容应为 "Hello Beautiful World!"
- **并且**: 两个插入都应被保留

**实现**:

```
// 伪代码：合并并发文本插入

function merge_text_insertions():
    // 步骤1：设备A执行文本操作
    doc_a = create_crdt_document()
    text_a = doc_a.get_text_field("content")
    text_a.insert(position=0, text="Hello World")
    text_a.insert(position=6, text="Beautiful ")  // Result: "Hello Beautiful World"

    // 步骤2：设备B执行文本操作（从相同基础）
    doc_b = create_crdt_document()
    text_b = doc_b.get_text_field("content")
    text_b.insert(position=0, text="Hello World")
    text_b.insert(position=11, text="!")  // Result: "Hello World!"

    // 步骤3：双向同步
    // 设计决策：文本CRDT跟踪字符级操作
    updates_from_b = doc_b.export_updates()
    doc_a.import(updates_from_b)

    updates_from_a = doc_a.export_updates()
    doc_b.import(updates_from_a)

    // 步骤4：收敛
    // 注意：两个插入都在最终结果中保留
    // - 字符位置通过唯一ID跟踪
    // - 插入基于因果关系合并

    assert text_a.to_string() == "Hello Beautiful World!"
    assert text_b.to_string() == "Hello Beautiful World!"

    return success
```

### 场景：并发文本删除

- **前置条件**: 卡片内容为 "Hello Beautiful World"
- **并且**: 设备 A 删除 "Beautiful " → "Hello World"
- **并且**: 设备 B 删除 "Hello " → "Beautiful World"（并发）
- **操作**: 两个设备同步它们的变更
- **预期结果**: 最终内容应为 "World"
- **并且**: 两个删除都应被应用

**理由**:
- Loro's Text CRDT tracks character-level operations
- Loro 的 Text CRDT 跟踪字符级操作
- 删除基于字符 ID 应用，而非位置
- 确保无论操作顺序如何都有一致的结果

---

## 需求：列表冲突解决


系统应使用 Loro 的 List CRDT 管理数组（例如 Pool.card_ids）并自动解决冲突。

### 场景：对卡片列表的并发添加

- **前置条件**: 池有 card_ids = ["card1", "card2"]
- **并且**: 设备 A 添加 "card3" → ["card1", "card2", "card3"]
- **并且**: 设备 B 添加 "card4" → ["card1", "card2", "card4"]（并发）
- **操作**: 两个设备同步它们的变更
- **预期结果**: 最终列表应包含所有卡片
- **并且**: 列表应为 ["card1", "card2", "card3", "card4"]

**实现**:

```
// 伪代码：合并并发列表添加

function merge_list_additions():
    // 步骤1：设备A执行列表操作
    doc_a = create_crdt_document()
    list_a = doc_a.get_list_field("card_ids")
    list_a.append("card1")
    list_a.append("card2")
    list_a.append("card3")

    // 步骤2：设备B执行列表操作（从相同基础）
    doc_b = create_crdt_document()
    list_b = doc_b.get_list_field("card_ids")
    list_b.append("card1")
    list_b.append("card2")
    list_b.append("card4")

    // 步骤3：双向同步
    // 设计决策：列表CRDT保留所有添加
    updates_from_b = doc_b.export_updates()
    doc_a.import(updates_from_b)

    updates_from_a = doc_a.export_updates()
    doc_b.import(updates_from_a)

    // 步骤4：收敛
    // 注意：两个列表收敛为包含所有唯一项
    // - List elements are tracked by unique IDs
    // - 列表元素通过唯一ID跟踪
    // - 顺序基于因果关系保留

    final_list_a = list_a.to_array()
    final_list_b = list_b.to_array()

    assert final_list_a == final_list_b
    assert "card3" in final_list_a
    assert "card4" in final_list_a

    return success
```

### 场景：从列表并发移除

- **前置条件**: 池有 card_ids = ["card1", "card2", "card3"]
- **并且**: 设备 A 移除 "card2" → ["card1", "card3"]
- **并且**: 设备 B 移除 "card3" → ["card1", "card2"]（并发）
- **操作**: 两个设备同步它们的变更
- **预期结果**: 最终列表应为 ["card1"]
- **并且**: 两个移除都应被应用

---

## 需求：因果关系保持


系统应保持操作之间的因果关系。

### 场景：依赖操作维护因果关系

- **前置条件**: 设备 A 创建卡片 "card1"
- **并且**: 设备 A 将 "card1" 添加到池（因果依赖）
- **操作**: 设备 B 同步这些变更
- **预期结果**: 设备 B 应首先接收卡片创建
- **并且**: 然后接收池添加
- **并且**: 因果顺序应被保留

**理由**:
- Loro 使用 Lamport 时间戳跟踪因果关系
- 操作按因果顺序应用
- 防止不一致状态（例如，将不存在的卡片添加到池）

**实现**:

```
// 伪代码：因果关系保持

function demonstrate_causality():
    // 步骤1：设备A执行因果相关的操作
    doc_a = create_crdt_document()

    // 操作1：创建卡片
    cards_map = doc_a.get_map_field("cards")
    cards_map.set("card1", "Card 1 content")

    // 操作2：将卡片添加到池（依赖于操作1）
    // 设计决策：第二个操作因果依赖于第一个
    pool_list = doc_a.get_list_field("pool_card_ids")
    pool_list.append("card1")

    // 步骤2：导出带有因果顺序的更新
    // 注意：CRDT使用版本向量跟踪因果关系
    updates = doc_a.export_updates()

    // 步骤3：设备B导入更新
    doc_b = create_crdt_document()
    doc_b.import(updates)

    // 步骤4：验证因果顺序被保留
    // 注意：CRDT确保操作1在操作2之前应用
    // - Prevents inconsistent states
    // - 防止不一致状态
    // - 维护数据完整性

    assert doc_b.get_map_field("cards").has_key("card1")
    assert doc_b.get_list_field("pool_card_ids").length() == 1

    return success
```

---

## 需求：无冲突收敛


系统应保证所有设备收敛到相同的最终状态。

### 场景：多个设备在复杂编辑后收敛

- **前置条件**: 三个设备（A、B、C）进行并发编辑
- **操作**: 所有设备相互同步
- **预期结果**: 所有设备应具有相同的最终状态
- **并且**: 收敛应是确定性的
- **并且**: 不应需要手动冲突解决

**数学保证**:
- CRDT 保证强最终一致性（SEC）
- 如果所有设备接收所有更新，它们收敛到相同状态
- 收敛与消息传递顺序无关

---


## 实现细节

**技术栈**:
- **Lamport 时间戳**: 用于因果关系跟踪
- **版本向量**: 用于跟踪文档版本

**使用的 CRDT 类型**:

**设计模式**:
- **CRDT 模式**: 无冲突复制数据类型
- **基于操作的 CRDT**: 复制操作，而非状态
- **最终一致性**: 所有副本最终收敛

**性能考虑**:
- **增量同步**: 仅同步变更，而非完整文档
- **紧凑表示**: Loro 使用高效的二进制格式
- **内存效率**: 旧操作的垃圾回收

---


## 测试覆盖

**测试文件**: `rust/tests/conflict_resolution_test.rs`

**单元测试**:
- `test_concurrent_field_edits()` - 不同字段编辑
- `test_lww_same_field()` - 最后写入优先
- `test_text_insertions()` - 并发文本插入
- `test_text_deletions()` - 并发文本删除
- `test_list_additions()` - 并发列表添加
- `test_list_removals()` - 并发列表移除
- `test_causality_preservation()` - 因果关系保持
- `test_three_way_convergence()` - 多设备收敛

**集成测试**:
- 复杂的多设备编辑场景
- 网络分区和恢复
- 100+ 并发操作的压力测试

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 所有场景中保证收敛
- [ ] 冲突场景中无数据丢失
- [ ] 性能可接受（< 100ms 合并时间）
- [ ] 代码审查通过

---


## 相关文档

**领域规格**:
- [../../domain/sync/model.md](../../domain/sync/model.md) - 同步领域模型

**架构规格**:
- [../storage/dual_layer.md](../storage/dual_layer.md) - 双层架构
- [../storage/loro_integration.md](../storage/loro_integration.md) - Loro 集成
- [./service.md](./service.md) - P2P 同步服务
- [./peer_discovery.md](./peer_discovery.md) - 对等点发现

**架构决策记录**:
- [../../../docs/adr/0003-loro-crdt.md](../../../docs/adr/0003-loro-crdt.md) - Loro CRDT 选择

---

**最后更新**: 2026-01-23

**作者**: CardMind Team
