# Features + UI Specs Template Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 统一 `docs/specs/features/**` 与 `docs/specs/ui/**` 文档为 keyring 模板结构，移除版本字段并重写表述以提高一致性与可读性。

**Architecture:** 以 `docs/specs/architecture/security/keyring.md` 为模板，保留“标题/元数据/概述/需求-场景/测试覆盖”为最小结构，缺失项用“待补充/不适用”占位，不改变既有结论或规则。

**Tech Stack:** Markdown

---

## 统一模板片段（应用到所有 features/ui 规格）

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

---

## 备注

- 本计划不包含 `docs/specs/README.md`、`docs/specs/features/README.md`、`docs/specs/ui/README.md`（如需按模板改写请说明）。

---

### Task 1: Refactor docs/specs/features/card_detail/card_detail_screen.md

**Files:**
- Modify: `docs/specs/features/card_detail/card_detail_screen.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/card_detail/card_detail_screen.md
git commit -m "docs(features): refactor card_detail-card_detail_screen spec template"
```

### Task 2: Refactor docs/specs/features/card_editor/card_editor_screen.md

**Files:**
- Modify: `docs/specs/features/card_editor/card_editor_screen.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/card_editor/card_editor_screen.md
git commit -m "docs(features): refactor card_editor-card_editor_screen spec template"
```

### Task 3: Refactor docs/specs/features/card_editor/desktop.md

**Files:**
- Modify: `docs/specs/features/card_editor/desktop.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/card_editor/desktop.md
git commit -m "docs(features): refactor card_editor-desktop spec template"
```

### Task 4: Refactor docs/specs/features/card_editor/fullscreen_editor.md

**Files:**
- Modify: `docs/specs/features/card_editor/fullscreen_editor.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/card_editor/fullscreen_editor.md
git commit -m "docs(features): refactor card_editor-fullscreen_editor spec template"
```

### Task 5: Refactor docs/specs/features/card_editor/mobile.md

**Files:**
- Modify: `docs/specs/features/card_editor/mobile.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/card_editor/mobile.md
git commit -m "docs(features): refactor card_editor-mobile spec template"
```

### Task 6: Refactor docs/specs/features/card_editor/note_card.md

**Files:**
- Modify: `docs/specs/features/card_editor/note_card.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/card_editor/note_card.md
git commit -m "docs(features): refactor card_editor-note_card spec template"
```

### Task 7: Refactor docs/specs/features/card_list/card_list_item.md

**Files:**
- Modify: `docs/specs/features/card_list/card_list_item.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/card_list/card_list_item.md
git commit -m "docs(features): refactor card_list-card_list_item spec template"
```

### Task 8: Refactor docs/specs/features/card_list/desktop.md

**Files:**
- Modify: `docs/specs/features/card_list/desktop.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/card_list/desktop.md
git commit -m "docs(features): refactor card_list-desktop spec template"
```

### Task 9: Refactor docs/specs/features/card_list/mobile.md

**Files:**
- Modify: `docs/specs/features/card_list/mobile.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/card_list/mobile.md
git commit -m "docs(features): refactor card_list-mobile spec template"
```

### Task 10: Refactor docs/specs/features/card_list/note_card.md

**Files:**
- Modify: `docs/specs/features/card_list/note_card.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/card_list/note_card.md
git commit -m "docs(features): refactor card_list-note_card spec template"
```

### Task 11: Refactor docs/specs/features/card_list/note_editor_fullscreen.md

**Files:**
- Modify: `docs/specs/features/card_list/note_editor_fullscreen.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/card_list/note_editor_fullscreen.md
git commit -m "docs(features): refactor card_list-note_editor_fullscreen spec template"
```

### Task 12: Refactor docs/specs/features/card_management/spec.md

**Files:**
- Modify: `docs/specs/features/card_management/spec.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/card_management/spec.md
git commit -m "docs(features): refactor card_management-spec spec template"
```

### Task 13: Refactor docs/specs/features/context_menu/desktop.md

**Files:**
- Modify: `docs/specs/features/context_menu/desktop.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/context_menu/desktop.md
git commit -m "docs(features): refactor context_menu-desktop spec template"
```

### Task 14: Refactor docs/specs/features/fab/mobile.md

**Files:**
- Modify: `docs/specs/features/fab/mobile.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/fab/mobile.md
git commit -m "docs(features): refactor fab-mobile spec template"
```

### Task 15: Refactor docs/specs/features/gestures/mobile.md

**Files:**
- Modify: `docs/specs/features/gestures/mobile.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/gestures/mobile.md
git commit -m "docs(features): refactor gestures-mobile spec template"
```

### Task 16: Refactor docs/specs/features/home_screen/home_screen.md

**Files:**
- Modify: `docs/specs/features/home_screen/home_screen.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/home_screen/home_screen.md
git commit -m "docs(features): refactor home_screen-home_screen spec template"
```

### Task 17: Refactor docs/specs/features/home_screen/shared.md

**Files:**
- Modify: `docs/specs/features/home_screen/shared.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/home_screen/shared.md
git commit -m "docs(features): refactor home_screen-shared spec template"
```

### Task 18: Refactor docs/specs/features/navigation/mobile.md

**Files:**
- Modify: `docs/specs/features/navigation/mobile.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/navigation/mobile.md
git commit -m "docs(features): refactor navigation-mobile spec template"
```

### Task 19: Refactor docs/specs/features/navigation/mobile_nav.md

**Files:**
- Modify: `docs/specs/features/navigation/mobile_nav.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/navigation/mobile_nav.md
git commit -m "docs(features): refactor navigation-mobile_nav spec template"
```

### Task 20: Refactor docs/specs/features/onboarding/shared.md

**Files:**
- Modify: `docs/specs/features/onboarding/shared.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/onboarding/shared.md
git commit -m "docs(features): refactor onboarding-shared spec template"
```

### Task 21: Refactor docs/specs/features/p2p_sync/spec.md

**Files:**
- Modify: `docs/specs/features/p2p_sync/spec.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/p2p_sync/spec.md
git commit -m "docs(features): refactor p2p_sync-spec spec template"
```

### Task 22: Refactor docs/specs/features/pool_management/spec.md

**Files:**
- Modify: `docs/specs/features/pool_management/spec.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/pool_management/spec.md
git commit -m "docs(features): refactor pool_management-spec spec template"
```

### Task 23: Refactor docs/specs/features/search/desktop.md

**Files:**
- Modify: `docs/specs/features/search/desktop.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/search/desktop.md
git commit -m "docs(features): refactor search-desktop spec template"
```

### Task 24: Refactor docs/specs/features/search/mobile.md

**Files:**
- Modify: `docs/specs/features/search/mobile.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/search/mobile.md
git commit -m "docs(features): refactor search-mobile spec template"
```

### Task 25: Refactor docs/specs/features/search_and_filter/spec.md

**Files:**
- Modify: `docs/specs/features/search_and_filter/spec.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/search_and_filter/spec.md
git commit -m "docs(features): refactor search_and_filter-spec spec template"
```

### Task 26: Refactor docs/specs/features/settings/device_manager_panel.md

**Files:**
- Modify: `docs/specs/features/settings/device_manager_panel.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/settings/device_manager_panel.md
git commit -m "docs(features): refactor settings-device_manager_panel spec template"
```

### Task 27: Refactor docs/specs/features/settings/settings_panel.md

**Files:**
- Modify: `docs/specs/features/settings/settings_panel.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/settings/settings_panel.md
git commit -m "docs(features): refactor settings-settings_panel spec template"
```

### Task 28: Refactor docs/specs/features/settings/settings_screen.md

**Files:**
- Modify: `docs/specs/features/settings/settings_screen.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/settings/settings_screen.md
git commit -m "docs(features): refactor settings-settings_screen spec template"
```

### Task 29: Refactor docs/specs/features/settings/spec.md

**Files:**
- Modify: `docs/specs/features/settings/spec.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/settings/spec.md
git commit -m "docs(features): refactor settings-spec spec template"
```

### Task 30: Refactor docs/specs/features/sync/sync_screen.md

**Files:**
- Modify: `docs/specs/features/sync/sync_screen.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/sync/sync_screen.md
git commit -m "docs(features): refactor sync-sync_screen spec template"
```

### Task 31: Refactor docs/specs/features/sync_feedback/desktop.md

**Files:**
- Modify: `docs/specs/features/sync_feedback/desktop.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/sync_feedback/desktop.md
git commit -m "docs(features): refactor sync_feedback-desktop spec template"
```

### Task 32: Refactor docs/specs/features/sync_feedback/shared.md

**Files:**
- Modify: `docs/specs/features/sync_feedback/shared.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/sync_feedback/shared.md
git commit -m "docs(features): refactor sync_feedback-shared spec template"
```

### Task 33: Refactor docs/specs/features/sync_feedback/sync_details_dialog.md

**Files:**
- Modify: `docs/specs/features/sync_feedback/sync_details_dialog.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/sync_feedback/sync_details_dialog.md
git commit -m "docs(features): refactor sync_feedback-sync_details_dialog spec template"
```

### Task 34: Refactor docs/specs/features/toolbar/desktop.md

**Files:**
- Modify: `docs/specs/features/toolbar/desktop.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/features/toolbar/desktop.md
git commit -m "docs(features): refactor toolbar-desktop spec template"
```

### Task 35: Refactor docs/specs/ui/adaptive/components.md

**Files:**
- Modify: `docs/specs/ui/adaptive/components.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/adaptive/components.md
git commit -m "docs(ui): refactor adaptive-components spec template"
```

### Task 36: Refactor docs/specs/ui/adaptive/layouts.md

**Files:**
- Modify: `docs/specs/ui/adaptive/layouts.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/adaptive/layouts.md
git commit -m "docs(ui): refactor adaptive-layouts spec template"
```

### Task 37: Refactor docs/specs/ui/adaptive/platform_detection.md

**Files:**
- Modify: `docs/specs/ui/adaptive/platform_detection.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/adaptive/platform_detection.md
git commit -m "docs(ui): refactor adaptive-platform_detection spec template"
```

### Task 38: Refactor docs/specs/ui/components/desktop/card_list_item.md

**Files:**
- Modify: `docs/specs/ui/components/desktop/card_list_item.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/components/desktop/card_list_item.md
git commit -m "docs(ui): refactor components-desktop-card_list_item spec template"
```

### Task 39: Refactor docs/specs/ui/components/desktop/context_menu.md

**Files:**
- Modify: `docs/specs/ui/components/desktop/context_menu.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/components/desktop/context_menu.md
git commit -m "docs(ui): refactor components-desktop-context_menu spec template"
```

### Task 40: Refactor docs/specs/ui/components/desktop/desktop_nav.md

**Files:**
- Modify: `docs/specs/ui/components/desktop/desktop_nav.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/components/desktop/desktop_nav.md
git commit -m "docs(ui): refactor components-desktop-desktop_nav spec template"
```

### Task 41: Refactor docs/specs/ui/components/desktop/toolbar.md

**Files:**
- Modify: `docs/specs/ui/components/desktop/toolbar.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/components/desktop/toolbar.md
git commit -m "docs(ui): refactor components-desktop-toolbar spec template"
```

### Task 42: Refactor docs/specs/ui/components/mobile/card_list_item.md

**Files:**
- Modify: `docs/specs/ui/components/mobile/card_list_item.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/components/mobile/card_list_item.md
git commit -m "docs(ui): refactor components-mobile-card_list_item spec template"
```

### Task 43: Refactor docs/specs/ui/components/mobile/fab.md

**Files:**
- Modify: `docs/specs/ui/components/mobile/fab.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/components/mobile/fab.md
git commit -m "docs(ui): refactor components-mobile-fab spec template"
```

### Task 44: Refactor docs/specs/ui/components/mobile/gestures.md

**Files:**
- Modify: `docs/specs/ui/components/mobile/gestures.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/components/mobile/gestures.md
git commit -m "docs(ui): refactor components-mobile-gestures spec template"
```

### Task 45: Refactor docs/specs/ui/components/mobile/mobile_nav.md

**Files:**
- Modify: `docs/specs/ui/components/mobile/mobile_nav.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/components/mobile/mobile_nav.md
git commit -m "docs(ui): refactor components-mobile-mobile_nav spec template"
```

### Task 46: Refactor docs/specs/ui/components/shared/device_manager_panel.md

**Files:**
- Modify: `docs/specs/ui/components/shared/device_manager_panel.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/components/shared/device_manager_panel.md
git commit -m "docs(ui): refactor components-shared-device_manager_panel spec template"
```

### Task 47: Refactor docs/specs/ui/components/shared/fullscreen_editor.md

**Files:**
- Modify: `docs/specs/ui/components/shared/fullscreen_editor.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/components/shared/fullscreen_editor.md
git commit -m "docs(ui): refactor components-shared-fullscreen_editor spec template"
```

### Task 48: Refactor docs/specs/ui/components/shared/note_card.md

**Files:**
- Modify: `docs/specs/ui/components/shared/note_card.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/components/shared/note_card.md
git commit -m "docs(ui): refactor components-shared-note_card spec template"
```

### Task 49: Refactor docs/specs/ui/components/shared/settings_panel.md

**Files:**
- Modify: `docs/specs/ui/components/shared/settings_panel.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/components/shared/settings_panel.md
git commit -m "docs(ui): refactor components-shared-settings_panel spec template"
```

### Task 50: Refactor docs/specs/ui/components/shared/sync_details_dialog.md

**Files:**
- Modify: `docs/specs/ui/components/shared/sync_details_dialog.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/components/shared/sync_details_dialog.md
git commit -m "docs(ui): refactor components-shared-sync_details_dialog spec template"
```

### Task 51: Refactor docs/specs/ui/components/shared/sync_status_indicator.md

**Files:**
- Modify: `docs/specs/ui/components/shared/sync_status_indicator.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/components/shared/sync_status_indicator.md
git commit -m "docs(ui): refactor components-shared-sync_status_indicator spec template"
```

### Task 52: Refactor docs/specs/ui/screens/desktop/card_editor_screen.md

**Files:**
- Modify: `docs/specs/ui/screens/desktop/card_editor_screen.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/screens/desktop/card_editor_screen.md
git commit -m "docs(ui): refactor screens-desktop-card_editor_screen spec template"
```

### Task 53: Refactor docs/specs/ui/screens/desktop/home_screen.md

**Files:**
- Modify: `docs/specs/ui/screens/desktop/home_screen.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/screens/desktop/home_screen.md
git commit -m "docs(ui): refactor screens-desktop-home_screen spec template"
```

### Task 54: Refactor docs/specs/ui/screens/desktop/settings_screen.md

**Files:**
- Modify: `docs/specs/ui/screens/desktop/settings_screen.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/screens/desktop/settings_screen.md
git commit -m "docs(ui): refactor screens-desktop-settings_screen spec template"
```

### Task 55: Refactor docs/specs/ui/screens/mobile/card_detail_screen.md

**Files:**
- Modify: `docs/specs/ui/screens/mobile/card_detail_screen.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/screens/mobile/card_detail_screen.md
git commit -m "docs(ui): refactor screens-mobile-card_detail_screen spec template"
```

### Task 56: Refactor docs/specs/ui/screens/mobile/card_editor_screen.md

**Files:**
- Modify: `docs/specs/ui/screens/mobile/card_editor_screen.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/screens/mobile/card_editor_screen.md
git commit -m "docs(ui): refactor screens-mobile-card_editor_screen spec template"
```

### Task 57: Refactor docs/specs/ui/screens/mobile/home_screen.md

**Files:**
- Modify: `docs/specs/ui/screens/mobile/home_screen.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/screens/mobile/home_screen.md
git commit -m "docs(ui): refactor screens-mobile-home_screen spec template"
```

### Task 58: Refactor docs/specs/ui/screens/mobile/settings_screen.md

**Files:**
- Modify: `docs/specs/ui/screens/mobile/settings_screen.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/screens/mobile/settings_screen.md
git commit -m "docs(ui): refactor screens-mobile-settings_screen spec template"
```

### Task 59: Refactor docs/specs/ui/screens/mobile/sync_screen.md

**Files:**
- Modify: `docs/specs/ui/screens/mobile/sync_screen.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/screens/mobile/sync_screen.md
git commit -m "docs(ui): refactor screens-mobile-sync_screen spec template"
```

### Task 60: Refactor docs/specs/ui/screens/shared/onboarding_screen.md

**Files:**
- Modify: `docs/specs/ui/screens/shared/onboarding_screen.md`
- Test: N/A (docs-only)


**Step 1: Write the failing test**
- 建立结构检查清单（标题/元数据/概述/需求-场景/测试覆盖）。

**Step 2: Run test to verify it fails**
- 手工对照原文，记录缺失的模板段落。
- Expected: 至少一个必含段落缺失或结构不一致。

**Step 3: Write minimal implementation**
- 按模板重排内容，补齐缺失段落并保持语义不变。

**Step 4: Run test to verify it passes**
- 手工复核清单。
- Expected: 模板结构完整。

**Step 5: Commit**
```bash
git add docs/specs/ui/screens/shared/onboarding_screen.md
git commit -m "docs(ui): refactor screens-shared-onboarding_screen spec template"
```
