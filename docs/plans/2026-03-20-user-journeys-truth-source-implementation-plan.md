# User Journeys Truth Source Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增 `docs/specs/user-journeys.md`，把个人多设备主路径正式化为旅程层下游产品规格，并对齐规格索引与相关文档引用。

**Architecture:** 本计划只做文档层实现，不修改功能代码。先新增 `docs/specs/user-journeys.md`，将五阶段旅程、总原则、与 `docs/specs/product.md` 的上下位关系正式化；再更新 `docs/specs/DIR.md`、`docs/DIR.md` 和 `docs/plans/DIR.md` 等索引；必要时补充对现有上游/下游文档的轻量引用，但不扩张到 UI、roadmap 或功能实现。

**Tech Stack:** Markdown 文档、git、现有 specs/plans 体系

---

## File Structure

- Create: `docs/specs/user-journeys.md`
  - 正式旅程层下游产品规格；定义总原则、五阶段旅程、成立/断裂信号，以及与 `product.md` / 下游规格的关系。
- Modify: `docs/specs/DIR.md`
  - 登记新的正式规格文档。
- Modify: `docs/DIR.md`
  - 如有必要，补充 `specs/` 目录对“旅程层下游产品规格”的描述。
- Verify: `docs/plans/DIR.md`
  - 验证本实施计划文件的索引登记状态，不重复登记已有条目。
- Optional Modify: `docs/specs/product.md`
  - 仅在必要时补一条对 `docs/specs/user-journeys.md` 的下游引用；若现有结构已足够清楚，则不改。

---

## Chunk 1: Create The Formal Journey Spec

### Task 1: Add `docs/specs/user-journeys.md`

**Files:**
- Create: `docs/specs/user-journeys.md`
- Reference: `docs/specs/product.md`
- Reference: `docs/plans/2026-03-20-user-journeys-truth-source-design.md`
- Reference: `docs/plans/2026-03-19-cardmind-product-audit.md`

- [ ] **Step 1: Write the failing structure skeleton**

Create `docs/specs/user-journeys.md` with these exact top-level sections:

```md
# 用户旅程规格

## 文档导读（AI/渐进式加载）
## 1. 目的与范围
## 2. 与 `docs/specs/product.md` 的关系
## 3. 用户旅程总原则
## 4. 阶段一：首次理解
## 5. 阶段二：开始记录
## 6. 阶段三：跨设备延续
## 7. 阶段四：异常与恢复
## 8. 阶段五：长期使用与信任稳定
## 9. 与下游规格和后续规划的关系
```

- [ ] **Step 2: Verify the structure exists**

Run: `rg "^## " docs/specs/user-journeys.md`
Expected: 输出 10 个二级标题，且与计划中的章节名一致

- [ ] **Step 3: Write `文档导读` and `1. 目的与范围` only**

Required content:
- 本规格是受 `docs/specs/product.md` 约束的旅程层下游产品规格
- 主要用途是产品校准，而不是页面设计、实现细节或测试脚本说明
- 只覆盖个人多设备主路径
- 不覆盖完整数据池协作旅程、UI 布局、Rust/Flutter/FRB 细节

- [ ] **Step 4: Verify scope wording**

Run: `rg "产品校准|个人多设备主路径|不覆盖完整数据池协作旅程|不覆盖.*FRB" docs/specs/user-journeys.md`
Expected: 文档前部能命中这些范围约束

- [ ] **Step 5: Write `2. 与 docs/specs/product.md 的关系` and `3. 用户旅程总原则` only**

Required content:
- 明确 `product.md` 是上位产品真相源，`user-journeys.md` 是其约束下的旅程层下游规格
- 明确本规格回答“产品如何在真实用户身上成立”
- 写入总原则：
  - 先记录，再理解复杂机制
  - 主路径优先于扩展能力
  - 异常恢复属于主路径的一部分
  - 可信任比功能堆叠更重要

- [ ] **Step 6: Verify relationship and principles**

Run: `rg "上位产品真相源|旅程层下游规格|先记录，再理解复杂机制|异常恢复属于主路径的一部分" docs/specs/user-journeys.md`
Expected: 关系与总原则内容存在

- [ ] **Step 7: Write the five stage sections with uniform format**

For each stage section (`4`-`8`), use exactly these subheadings in this order:

```md
### 用户此时想完成什么
### 用户此时最在意什么
### 产品必须提供的体验承诺
### 旅程成立信号
### 旅程断裂信号
```

Stage-specific minimum semantics:
- `阶段一：首次理解` - 用户应快速理解“这不是普通云笔记，我可以先记，再逐步理解同步与流转”
- `阶段二：开始记录` - 用户应先获得低阻力、直接的个人记录正反馈
- `阶段三：跨设备延续` - 用户应感知为“同一份笔记数据的连续使用”
- `阶段四：异常与恢复` - 用户应知道内容是否安全、当前状态是什么、下一步是什么
- `阶段五：长期使用与信任稳定` - 用户应形成可长期依赖的信任，而非偶尔成功一次

Constraint:
- 用稳定、可判定、非界面化语言
- 不写页面布局、组件、API、Rust/Flutter/FRB 细节

- [ ] **Step 8: Verify uniform stage format**

Run: `python3 - <<'PY'
from pathlib import Path
text = Path('docs/specs/user-journeys.md').read_text()
sections = [
    '## 4. 阶段一：首次理解',
    '## 5. 阶段二：开始记录',
    '## 6. 阶段三：跨设备延续',
    '## 7. 阶段四：异常与恢复',
    '## 8. 阶段五：长期使用与信任稳定',
]
headers = [
    '### 用户此时想完成什么',
    '### 用户此时最在意什么',
    '### 产品必须提供的体验承诺',
    '### 旅程成立信号',
    '### 旅程断裂信号',
]
for i, section in enumerate(sections):
    start = text.index(section)
    end = text.index(sections[i+1]) if i + 1 < len(sections) else text.index('## 9. 与下游规格和后续规划的关系')
    chunk = text[start:end]
    positions = [chunk.find(h) for h in headers]
    print(section, positions)
PY`
Expected: 5 个阶段各输出一组严格递增的非 `-1` 位置，表示每个阶段都按顺序包含 5 个固定三级标题

- [ ] **Step 9: Write `9. 与下游规格和后续规划的关系` only**

Required content:
- 指向 `docs/specs/ui-interaction.md`、`docs/specs/card-note.md`、`docs/specs/pool.md`
- 明确本规格为交互、领域规格与后续规划提供校准依据
- 不把具体 roadmap 决策写死

- [ ] **Step 10: Verify downstream relationship section**

Run: `rg "ui-interaction.md|card-note.md|pool.md|校准依据" docs/specs/user-journeys.md`
Expected: 下游衔接与用途表述存在

- [ ] **Step 11: Run document quality verification**

Run: `git diff --check`
Expected: no whitespace or patch formatting issues

- [ ] **Step 12: Commit task 1**

```bash
git add docs/specs/user-journeys.md
git commit -m "docs: add user journeys truth source spec"
```

---

## Chunk 2: Align Indexes And Minimal Cross-References

### Task 2: Update directory indexes

**Files:**
- Modify: `docs/specs/DIR.md`
- Modify: `docs/DIR.md`
- Optional Modify: `docs/specs/product.md`

- [ ] **Step 1: Add `user-journeys.md` to `docs/specs/DIR.md`**

Add a one-line index entry that clearly describes this file as a journey-layer downstream product spec supporting personal multi-device primary journeys.

- [ ] **Step 2: Verify spec index entry**

Run: `rg "user-journeys.md|旅程" docs/specs/DIR.md`
Expected: 索引中出现新规格条目

- [ ] **Step 3: Update `docs/DIR.md` only if current wording is insufficient**

Only modify `docs/DIR.md` if its current `specs/` 目录描述无法涵盖“旅程层下游产品规格”这一语义。
If its current wording already broadly covers formal product/engineering specs without conflict, it MUST remain unchanged.

- [ ] **Step 4: Verify root index alignment**

Run: `rg "specs/|旅程|产品" docs/DIR.md docs/specs/DIR.md`
Expected: 根目录索引与 specs 索引的语义不冲突

- [ ] **Step 5: Add minimal cross-reference to `docs/specs/product.md` only if needed**

Only modify `docs/specs/product.md` if its `## 8. 与现有正式规格的关系` 无法表达存在一个承接产品目标的旅程层下游规格。
If the current generic downstream description is already semantically sufficient, it MUST remain unchanged.
If modification is required, add only one minimal line in `## 8. 与现有正式规格的关系` referencing `docs/specs/user-journeys.md` as the journey-layer downstream spec.

- [ ] **Step 6: Verify optional reference decision**

Run: `rg "user-journeys.md" docs/specs/product.md docs/specs/DIR.md`
Expected: 新规格至少在 `docs/specs/DIR.md` 中出现；若 `product.md` 被改，则该引用也应可见

- [ ] **Step 7: Run final verification for chunk 2**

Run: `git diff --check`
Expected: no whitespace or patch formatting issues

- [ ] **Step 8: Commit task 2**

```bash
git add docs/specs/DIR.md docs/DIR.md docs/specs/product.md
git commit -m "docs: align indexes for user journeys spec"
```

If `docs/DIR.md` or `docs/specs/product.md` were intentionally unchanged, only stage the files that actually changed.

---

## Chunk 3: Final Handoff Verification

### Task 3: Verify the repository-level handoff state

**Files:**
- Verify: `docs/specs/user-journeys.md`
- Verify: `docs/specs/DIR.md`
- Verify: `docs/plans/DIR.md`

- [ ] **Step 1: Verify this implementation plan is already indexed**

Run: `rg "2026-03-20-user-journeys-truth-source-implementation-plan.md" docs/plans/DIR.md`
Expected: 计划索引中已存在该条目；若不存在，停止执行并先更新计划

- [ ] **Step 2: Run final repository-level verification for this plan**

Run: `rg "用户旅程|多设备主路径" docs/specs/user-journeys.md docs/specs/DIR.md docs/plans/DIR.md`
Expected: 新规格、规格索引、计划索引之间形成可追踪链路

- [ ] **Step 3: Run final formatting verification**

Run: `git diff --check`
Expected: no whitespace or patch formatting issues

- [ ] **Step 4: Commit task 3 only if any tracked file changed in this chunk**

If this chunk did not require any file edits, do not create an empty commit.
If a file was changed, use:

```bash
git add <changed-files>
git commit -m "docs: finalize user journeys spec handoff"
```

---

## Final Verification

- [ ] Run: `rg "上位产品真相源|旅程层下游规格|旅程成立信号|旅程断裂信号" docs/specs/user-journeys.md`
Expected: 规格中能直接看到层级关系与阶段判断结构

- [ ] Run: `rg "user-journeys.md" docs/specs/DIR.md`
Expected: 新规格已登记

- [ ] Run: `git status --short`
Expected: 在所有计划内提交完成后，工作区干净

---

## Notes For The Implementer

- 不要把这份规格写成页面说明、组件设计或测试脚本说明。
- 不要把数据池协作扩展成与个人多设备主路径并列的主线旅程。
- 如果某一阶段的表述无法帮助判断“旅程是否成立”，应回退并重写，而不是继续堆砌描述。
- 如果发现 `docs/specs/product.md` 与旅程规格存在语义冲突，应停下来更新计划或请人确认，而不是靠直觉改写产品目标。
- `docs/plans/DIR.md` 中本计划条目已存在，不应重复登记。
