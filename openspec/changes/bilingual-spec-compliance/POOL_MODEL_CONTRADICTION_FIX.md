# Pool Model Contradiction Fix Report
# 池模型矛盾修复报告

**Date** | **日期**: 2026-01-22
**Issue** | **问题**: Logical contradiction and incorrect terminology in pool model specifications
**Status** | **状态**: Fixed

---

## Problem Identified | 识别的问题

Multiple specification documents contained:
1. Contradictory statements about device pool membership
2. Incorrect use of "resident pool" terminology

多个规格文档包含：
1. 关于设备池成员资格的矛盾陈述
2. 错误使用"常驻池"术语

### Issue 1: Contradiction | 问题 1：矛盾

**Statement A** (in Overview sections):
- "each device can join multiple pools but has exactly one resident pool"
- "每个设备可以加入多个池但只有一个常驻池"

**Statement B** (in Requirement sections):
- "a device can join at most one pool for personal note-taking"
- "设备最多只能加入一个池用于个人笔记"

### Issue 2: Incorrect Terminology | 问题 2：错误术语

The term "resident pool" (常驻池) was used throughout the specifications, but this concept doesn't exist in the single pool model. The correct behavior is:
- A device can join at most one pool
- When a device creates a new card, it automatically belongs to the pool that the device has joined
- There is no separate "resident pool" concept

规格中使用了"常驻池"术语，但这个概念在单池模型中并不存在。正确的行为是：
- 设备最多只能加入一个池
- 当设备创建新卡片时，卡片自动属于设备已加入的池
- 没有单独的"常驻池"概念

---

## Root Cause | 根本原因

The specifications retained language from an earlier design iteration that:
1. Allowed multiple pool membership
2. Used a separate "resident pool" concept for card creation

规格保留了早期设计迭代中的语言：
1. 允许多池成员资格
2. 使用单独的"常驻池"概念进行卡片创建

---

## Correct Design | 正确设计

Based on comprehensive review of ADR-0001, implementation scenarios, and test cases:

基于对 ADR-0001、实现场景和测试用例的全面审查：

**Single Pool Model** | **单池模型**:
1. Each card belongs to exactly one pool | 每张卡片恰好属于一个池
2. Each device can join **at most one** pool | 每个设备**最多只能加入一个**池
3. When a device creates a new card, it automatically belongs to the pool that the device has joined | 当设备创建新卡片时，卡片自动属于设备已加入的池
4. Use case: Personal note-taking (one user = one pool) | 使用场景：个人笔记（一个用户 = 一个池）

**Rationale** | **理由**:
- Simplifies sync semantics | 简化同步语义
- Ensures reliable removal propagation | 确保可靠的删除传播
- Aligns with "personal notes" use case | 符合"个人笔记"使用场景
- Reduces implementation complexity | 降低实现复杂性

---

## Files Fixed | 修复的文件

### Core Specifications | 核心规格

#### 1. `openspec/specs/domain/pool_model.md`

**Overview section**:
```markdown
BEFORE: each device can join multiple pools but has exactly one resident pool
AFTER:  each device can join at most one pool. When a device creates a new card,
        it automatically belongs to the pool that the device has joined
```

**Requirement section**:
```markdown
BEFORE: Requirement: Card Creation in Resident Pool
AFTER:  Requirement: Card Creation in Joined Pool

BEFORE: device has a resident pool set
AFTER:  device has joined a pool

BEFORE: no resident pool configured
AFTER:  has not joined any pool
```

#### 2. `docs/adr/0001-单池所有权模型.md`

**Decision section**:
```markdown
BEFORE: Each device can join multiple pools (for syncing with others)
        Each device has exactly one resident pool (where new cards are created)

AFTER:  Each device can join at most one pool (for personal note-taking)
        When a device creates a new card, it automatically belongs to the pool
        that the device has joined
```

**Scenario section**:
```markdown
BEFORE: Scenario: Create card in resident pool
        GIVEN a device has a resident pool set

AFTER:  Scenario: Create card in joined pool
        GIVEN a device has joined a pool
```

#### 3. `openspec/specs/rust/single_pool_model_spec.md`

**Overview**:
```markdown
BEFORE: each device can join multiple pools but has exactly one resident pool
AFTER:  each device can join at most one pool. When a device creates a new card,
        it automatically belongs to the pool that the device has joined
```

**Requirement section**:
```markdown
BEFORE: Requirement: Card Creation in Resident Pool
AFTER:  Requirement: Card Creation in Joined Pool
```

### Example and Guide Documents | 示例和指南文档

#### 4. `openspec/specs/SPEC_EXAMPLE.md`

**Overview**:
```markdown
BEFORE: automatically associated with the device's resident pool
AFTER:  automatically associated with the pool that the device has joined
```

**Requirement and scenarios**:
```markdown
BEFORE: Requirement: Auto-Association with Resident Pool
        Scenario: Create card in resident pool successfully
        GIVEN a device has a resident pool configured
        error code NO_RESIDENT_POOL

AFTER:  Requirement: Auto-Association with Joined Pool
        Scenario: Create card in joined pool successfully
        GIVEN a device has joined a pool
        error code NO_POOL_JOINED
```

**Test cases**:
```markdown
BEFORE: it_should_add_card_to_resident_pool()
        it_should_reject_creation_without_resident_pool()

AFTER:  it_should_add_card_to_joined_pool()
        it_should_reject_creation_without_joined_pool()
```

#### 5. `openspec/specs/BILINGUAL_SPEC_GUIDE.md`

**Terminology table**:
```markdown
BEFORE: | Resident Pool | 常驻池 | Not "居民池" |
AFTER:  | Joined Pool | 已加入池 | Not "加入的池" |
```

### Implementation Status Documents | 实现状态文档

#### 6. `openspec/specs/rust/api_spec_implementation_status.md`

**API status**:
```markdown
BEFORE: set_resident_pool | ✅ 已实现 | 设置常驻池（单池模型返回错误）
        get_resident_pools | ✅ 已实现 | 获取常驻池
        is_pool_resident | ✅ 已实现 | 检查是否常驻池

AFTER:  set_resident_pool | ⚠️ 已废弃 | 单池模型中已废弃（加入池后新卡片自动属于该池）
        get_resident_pools | ⚠️ 已废弃 | 单池模型中已废弃
        is_pool_resident | ⚠️ 已废弃 | 单池模型中已废弃
```

#### 7. `openspec/specs/rust/test_naming_plan.md`

**Test status**:
```markdown
BEFORE: test_resident_pool() | 已废弃 | 删除 | 单池模型不需要常驻池
AFTER:  test_resident_pool() | 已废弃 | 删除 | 单池模型中设备加入池后新卡片自动属于该池
```

---

## Verification | 验证

All specifications now consistently state:

所有规格现在一致声明：

✅ Cards belong to exactly one pool | 卡片恰好属于一个池
✅ Devices can join at most one pool | 设备最多只能加入一个池
✅ New cards automatically belong to the joined pool | 新卡片自动属于已加入的池
✅ No "resident pool" concept exists | 不存在"常驻池"概念
✅ Scenarios enforce single-pool constraint | 场景强制执行单池约束
✅ Implementation rejects joining second pool | 实现拒绝加入第二个池

**Grep verification**:
```bash
$ grep -ri "resident pool\|常驻池" openspec/specs/
# No results - all references removed
```

---

## Impact | 影响

### Documentation | 文档

**Removed**:
- Ambiguity in pool model design | 消除了池模型设计中的歧义
- Incorrect "resident pool" terminology | 移除了错误的"常驻池"术语
- Contradictory statements | 移除了矛盾陈述

**Added**:
- Clear, consistent terminology | 清晰、一致的术语
- Accurate behavior description | 准确的行为描述
- Aligned all specifications with implementation | 使所有规格与实现保持一致

### Implementation | 实现

**No code changes required** | **无需代码更改**:
- Implementation already enforces correct behavior | 实现已经强制执行正确行为
- Test cases validate single-pool constraint | 测试用例验证单池约束
- APIs marked as deprecated are correctly documented | 已废弃的 API 已正确记录

### User Experience | 用户体验

**Improved clarity** | **提高清晰度**:
- Clear mental model: one user = one pool | 清晰的心智模型：一个用户 = 一个池
- Simplified pool management | 简化池管理
- Reliable sync behavior | 可靠的同步行为
- No confusion about "resident pool" vs "joined pool" | 不再混淆"常驻池"与"已加入池"

---

## Summary | 总结

**Files Modified** | **修改的文件**: 7 specification files
**Lines Changed** | **变更行数**: ~50 lines across all files
**Terminology Changes** | **术语变更**:
- "resident pool" → "joined pool" | "常驻池" → "已加入池"
- "has a resident pool set" → "has joined a pool" | "已设置常驻池" → "已加入一个池"
- "no resident pool" → "no pool joined" | "无常驻池" → "未加入池"

**Result** | **结果**:
- ✅ All contradictions resolved | 所有矛盾已解决
- ✅ Consistent terminology throughout | 术语在整个文档中保持一致
- ✅ Accurate reflection of implementation | 准确反映实现
- ✅ Clear single pool model semantics | 清晰的单池模型语义

---

## Related Documents | 相关文档

- [ADR-0001: Single Pool Ownership](../../docs/adr/0001-单池所有权模型.md)
- [Pool Model Specification](../specs/domain/pool_model.md)
- [Single Pool Model Spec (Rust)](../specs/rust/single_pool_model_spec.md)
- [Device Config Specification](../specs/domain/device_config.md)
- [Bilingual Spec Guide](../specs/BILINGUAL_SPEC_GUIDE.md)

---

**Fixed By** | **修复者**: Claude Code
**Reviewed By** | **审查者**: Pending
**Last Updated** | **最后更新**: 2026-01-22
