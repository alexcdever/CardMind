# Architecture Specs Template Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 统一 `docs/specs/architecture/**` 文档为 keyring 模板结构，移除版本字段并重写表述以提高一致性与可读性。

**Architecture:** 以 `docs/specs/architecture/security/keyring.md` 为模板，保留“标题/元数据/概述/需求-场景/测试覆盖”为最小结构，缺失项用“待补充/不适用”占位，不改变技术决策。

**Tech Stack:** Markdown

## 统一模板片段（应用到所有架构规格）

```markdown
# <标题>

**状态**: <活跃/草案/...>
**依赖**: <相关规格或无>
**相关测试**: <测试路径或待补充>

---

## 概述
<说明范围、背景、核心机制>

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

## Task 1: Refactor dual-layer spec

**Files:**
- Modify: `docs/specs/architecture/storage/dual_layer.md`
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
git add docs/specs/architecture/storage/dual_layer.md
git commit -m "docs(architecture): refactor dual layer spec template"
```

### Task 2: Refactor card store spec

**Files:**
- Modify: `docs/specs/architecture/storage/card_store.md`
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
git add docs/specs/architecture/storage/card_store.md
git commit -m "docs(architecture): refactor card store spec template"
```

### Task 3: Refactor pool store spec

**Files:**
- Modify: `docs/specs/architecture/storage/pool_store.md`
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
git add docs/specs/architecture/storage/pool_store.md
git commit -m "docs(architecture): refactor pool store spec template"
```

### Task 4: Refactor sqlite cache spec

**Files:**
- Modify: `docs/specs/architecture/storage/sqlite_cache.md`
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
git add docs/specs/architecture/storage/sqlite_cache.md
git commit -m "docs(architecture): refactor sqlite cache spec template"
```

### Task 5: Refactor loro integration spec

**Files:**
- Modify: `docs/specs/architecture/storage/loro_integration.md`
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
git add docs/specs/architecture/storage/loro_integration.md
git commit -m "docs(architecture): refactor loro integration spec template"
```

### Task 6: Refactor device config spec

**Files:**
- Modify: `docs/specs/architecture/storage/device_config.md`
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
git add docs/specs/architecture/storage/device_config.md
git commit -m "docs(architecture): refactor device config spec template"
```

### Task 7: Refactor sync service spec

**Files:**
- Modify: `docs/specs/architecture/sync/service.md`
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
git add docs/specs/architecture/sync/service.md
git commit -m "docs(architecture): refactor sync service spec template"
```

### Task 8: Refactor peer discovery spec

**Files:**
- Modify: `docs/specs/architecture/sync/peer_discovery.md`
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
git add docs/specs/architecture/sync/peer_discovery.md
git commit -m "docs(architecture): refactor peer discovery spec template"
```

### Task 9: Refactor conflict resolution spec

**Files:**
- Modify: `docs/specs/architecture/sync/conflict_resolution.md`
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
git add docs/specs/architecture/sync/conflict_resolution.md
git commit -m "docs(architecture): refactor conflict resolution spec template"
```

### Task 10: Refactor subscription spec

**Files:**
- Modify: `docs/specs/architecture/sync/subscription.md`
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
git add docs/specs/architecture/sync/subscription.md
git commit -m "docs(architecture): refactor subscription spec template"
```

### Task 11: Refactor password spec

**Files:**
- Modify: `docs/specs/architecture/security/password.md`
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
git add docs/specs/architecture/security/password.md
git commit -m "docs(architecture): refactor password spec template"
```

### Task 12: Refactor privacy spec

**Files:**
- Modify: `docs/specs/architecture/security/privacy.md`
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
git add docs/specs/architecture/security/privacy.md
git commit -m "docs(architecture): refactor privacy spec template"
```

### Task 13: Refactor keyring spec (align template baseline)

**Files:**
- Modify: `docs/specs/architecture/security/keyring.md`
- Test: N/A (docs-only)

**Step 1: Write the failing test**
- 建立结构检查清单（重点检查移除版本字段）。

**Step 2: Run test to verify it fails**
- 手工对照原文。
- Expected: 元数据仍包含版本或结构细节不统一。

**Step 3: Write minimal implementation**
- 移除版本字段并统一元数据格式。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整且元数据一致。

**Step 5: Commit**
```bash
git add docs/specs/architecture/security/keyring.md
git commit -m "docs(architecture): align keyring spec template"
```

