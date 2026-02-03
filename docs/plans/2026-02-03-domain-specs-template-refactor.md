# Domain Specs Template Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 统一 `docs/specs/domain/**` 文档为 keyring 模板结构，移除版本字段并重写表述以提高一致性与可读性。

**Architecture:** 以 `docs/specs/architecture/security/keyring.md` 为模板，保留“标题/元数据/概述/需求-场景/测试覆盖”为最小结构，缺失项用“待补充/不适用”占位，不改变领域规则或结论。

**Tech Stack:** Markdown

## 统一模板片段（应用到所有 domain 规格）

```markdown
# <标题>

**状态**: <活跃/草案/...>
**依赖**: <相关规格或无>
**相关测试**: <测试路径或待补充>

---

## 概述
<说明范围、背景、核心规则>

## 需求：<需求名>
<需求描述>

### 场景：<场景名>
- **前置条件**: ...
- **操作**: ...
- **预期结果**: ...
- **并且**: ...

**实现逻辑**:
```
<如有实现流程或伪代码则补齐>
```

---

## 测试覆盖
**测试文件**: <路径或待补充>
```

## Task 1: Refactor card domain spec

**Files:**
- Modify: `docs/specs/domain/card.md`
- Test: N/A (docs-only)

**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按统一模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 所有必含段落齐全且表达对齐模板。

**Step 5: Commit**
```bash
git add docs/specs/domain/card.md
git commit -m "docs(domain): refactor card spec template"
```

### Task 2: Refactor pool domain spec

**Files:**
- Modify: `docs/specs/domain/pool.md`
- Test: N/A (docs-only)

**Step 1: Write the failing test**
- 建立结构检查清单。

**Step 2: Run test to verify it fails**
- 手工对照原文。
- Expected: 存在模板缺项或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重构并补齐缺失段落。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/domain/pool.md
git commit -m "docs(domain): refactor pool spec template"
```

### Task 3: Refactor sync domain spec

**Files:**
- Modify: `docs/specs/domain/sync.md`
- Test: N/A (docs-only)

**Step 1: Write the failing test**
- 建立结构检查清单。

**Step 2: Run test to verify it fails**
- 手工对照原文。
- Expected: 存在模板缺项或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重构并补齐缺失段落。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/domain/sync.md
git commit -m "docs(domain): refactor sync spec template"
```

### Task 4: Refactor types domain spec

**Files:**
- Modify: `docs/specs/domain/types.md`
- Test: N/A (docs-only)

**Step 1: Write the failing test**
- 建立结构检查清单。

**Step 2: Run test to verify it fails**
- 手工对照原文。
- Expected: 存在模板缺项或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重构并补齐缺失段落。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/domain/types.md
git commit -m "docs(domain): refactor types spec template"
```

