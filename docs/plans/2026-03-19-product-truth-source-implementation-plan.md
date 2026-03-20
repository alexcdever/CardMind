# Product Truth Source Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立 CardMind 的产品级真相源文档，并对齐 README、用户指南与目录索引，使后续 AI 和人类实现都以统一产品目标与阶段目标为准。

**Architecture:** 本计划先在 `docs/specs/` 新增一份产品级上位文档，把审计中高/中置信度的产品判断收束为正式公开约束；再把公开入口文档与说明文档对齐到这份真相源。私有背景继续保留在本地 `AGENT.local.md`，不进入版本控制。整个实施以最小文档面改动完成，不触碰功能代码。

**Tech Stack:** Markdown 文档、目录索引治理、git、现有 specs/plans/README 文档体系

---

## File Structure

- Create: `docs/specs/product.md`
  - 产品级上位真相源，定义终极目标、当前阶段目标、目标用户、核心价值、非目标、与 `architecture/pool/card-note/ui-interaction` 的关系。
- Modify: `docs/specs/DIR.md`
  - 登记新的正式规格文档。
- Modify: `docs/DIR.md`
  - 若需要，补充 `specs/` 下新增产品级真相源的目录语义。
- Modify: `README.md`
  - 用一段简化说明对外表达产品定位，并引用 `docs/specs/product.md` 作为正式来源。
- Modify: `docs/user-guide.md`
  - 收敛为面向当前公开能力的用户说明，删去或标注未被当前规格支持的超前描述。
- Modify: `docs/plans/DIR.md`
  - 登记本实施计划文件。

---

## Chunk 1: Build The Product Truth Source Spec

### Task 1: Add `docs/specs/product.md`

**Files:**
- Create: `docs/specs/product.md`
- Modify: `docs/specs/DIR.md`
- Modify: `docs/DIR.md`
- Reference: `docs/plans/2026-03-19-cardmind-product-audit.md`
- Reference: `README.md`

- [ ] **Step 1: Write the spec skeleton with explicit sections**

Create `docs/specs/product.md` with these exact top-level sections:

```md
# 产品定位与阶段目标规格

## 文档导读（AI/渐进式加载）
## 1. 目的与范围
## 2. 终极目标
## 3. 当前阶段目标
## 4. 目标用户
## 5. 核心价值承诺
## 6. 核心能力与能力边界
## 7. 非目标
## 8. 与现有正式规格的关系
## 9. 验收与演进规则
```

- [ ] **Step 2: Run structure verification**

Run: `rg "^## " docs/specs/product.md`
Expected: 输出 9 个二级标题，且与计划中的章节名一致

- [ ] **Step 3: Write `## 2. 终极目标` only**

Write `## 2. 终极目标` using wording that explicitly presents this as the current formalized product direction derived from the audit, while allowing equivalent wording if it preserves the same meaning:

```md
## 2. 终极目标

基于当前审计结论，CardMind 的公开产品终极目标定义为：成为一款面向多设备个人用户、用于同步和流转笔记数据的应用。
```

- [ ] **Step 4: Verify the goal section exists**

Run: `rg "^## 2\. 终极目标|多设备个人用户|同步和流转笔记数据" docs/specs/product.md`
Expected: `## 2. 终极目标` 存在，且文中明确包含“多设备个人用户”与“同步和流转笔记数据”这两个核心方向表达

- [ ] **Step 5: Write `## 3. 当前阶段目标` only**

```md
## 3. 当前阶段目标

当前阶段优先证明以下三件事：
1. 个人用户可在本地优先前提下稳定创建、编辑、查询笔记。
2. 同一用户跨设备同步笔记数据的体验可解释、可恢复、可长期信任。
3. 数据池协作能力作为同步与流转模型的扩展能力存在，但不得压过个人多设备主路径的优先级。
```

- [ ] **Step 6: Verify stage goals exist**

Run: `rg "^## 3\. 当前阶段目标|当前阶段优先证明以下三件事|个人用户可在本地优先前提下稳定创建" docs/specs/product.md`
Expected: `## 3. 当前阶段目标` 与阶段目标内容存在

- [ ] **Step 7: Write `## 4. 目标用户` and `## 7. 非目标` only**

Required content:
- `## 4. 目标用户` 明确当前主目标用户是拥有多设备场景的个人用户
- `## 7. 非目标` 明确当前阶段不以复杂团队协作、多角色组织流程、扩张型平台化能力为第一优先级

- [ ] **Step 8: Verify user and non-goal sections**

Run: `rg "^## 4\. 目标用户|^## 7\. 非目标|团队协作|多设备场景" docs/specs/product.md`
Expected: 目标用户与非目标章节都存在，且命中关键约束

- [ ] **Step 9: Write `## 5. 核心价值承诺` and `## 6. 核心能力与能力边界` only**

Required content:
- 为什么“本地优先 / 低感知同步 / 数据流转”服务于目标用户
- 数据池协作是服务个人多设备主路径的扩展能力，而不是更高优先级主目标

- [ ] **Step 10: Verify value and boundary sections**

Run: `rg "^## 5\. 核心价值承诺|^## 6\. 核心能力与能力边界|本地优先|低感知同步|数据池协作" docs/specs/product.md`
Expected: 核心价值与能力边界章节都存在

- [ ] **Step 11: Write `## 8. 与现有正式规格的关系` and `## 9. 验收与演进规则` only**

Required content:
- 引用 `docs/specs/architecture.md`、`docs/specs/pool.md`、`docs/specs/card-note.md`、`docs/specs/ui-interaction.md`
- 明确后续若产品目标发生变化，需先更新该产品级真相源，再更新下游规格或实现

- [ ] **Step 12: Run consistency verification**

Run: `rg "多设备个人用户|同步和流转笔记数据|当前阶段目标|非目标" docs/specs/product.md`
Expected: 四类关键信号都能在新规格中找到

- [ ] **Step 13: Update directory indexes**

Update:
- `docs/specs/DIR.md`
- `docs/DIR.md`

Required content:
- 在 `docs/specs/DIR.md` 中新增 `product.md` 条目，说明它是产品级真相源
- 在 `docs/DIR.md` 中让 `specs/` 的目录说明能涵盖“产品级正式规格”

- [ ] **Step 14: Verify index alignment**

Run: `rg "product.md|产品级" docs/specs/DIR.md docs/DIR.md`
Expected: 两个索引文件都能反映新文档的定位

- [ ] **Step 15: Commit chunk 1**

```bash
git add docs/specs/product.md docs/specs/DIR.md docs/DIR.md
git commit -m "docs: add product truth source spec"
```

---

## Chunk 2: Align Public Entry Docs To The New Truth Source

### Task 2: Update `README.md`

**Files:**
- Modify: `README.md`
- Reference: `docs/specs/product.md`

- [ ] **Step 1: Write the failing alignment checklist**

Before editing, define this checklist in your working notes and verify `README.md` does not yet fully satisfy it:

```text
1. README 是否明确“多设备个人用户”
2. README 是否明确“同步和流转笔记数据”
3. README 是否说明数据池协作是服务该目标的能力
4. README 是否引用正式产品真相源
```

- [ ] **Step 2: Verify current mismatch**

Run: `rg "多设备|流转|product.md" README.md`
Expected: 至少缺少其中 1-2 项，证明 README 尚未对齐

- [ ] **Step 3: Update README minimally**

Modify the opening product description so it conveys:
- CardMind 面向多设备个人用户
- 核心目标是同步和流转笔记数据
- 数据池协作是该目标下的扩展能力
- 正式产品定位以 `docs/specs/product.md` 为准

Keep the README concise; do not duplicate the full product spec.

- [ ] **Step 4: Verify README alignment**

Run: `rg "多设备|个人用户|同步|流转|docs/specs/product.md" README.md`
Expected: 新的 README 命中这些关键表达

- [ ] **Step 5: Commit README alignment**

```bash
git add README.md
git commit -m "docs: align readme with product goal"
```

### Task 3: Update `docs/user-guide.md`

**Files:**
- Modify: `docs/user-guide.md`
- Reference: `docs/specs/product.md`
- Reference: `docs/specs/ui-interaction.md`
- Reference: `docs/specs/pool.md`
- Reference: `docs/specs/card-note.md`

- [ ] **Step 1: Mark potentially drifting sections**

Search for user-guide claims identified by the audit as drift-risk candidates, including:

```text
导出 JSON
回收站
冲突时手动选择
重新连接
扫码加入
```

- [ ] **Step 2: Verify drift candidates**

Run: `rg "导出 JSON|回收站|手动选择|重新连接|扫码加入" docs/user-guide.md`
Expected: 找到至少部分审计已点名的漂移风险条目，用于后续人工对齐

- [ ] **Step 3: Rewrite guide for truthfulness**

Adjust `docs/user-guide.md` so that it:
- only promises behavior supported by current formal specs
- removes or softens unsupported claims
- explicitly frames the product around personal multi-device note sync/flow
- keeps user-facing language readable and non-technical

- [ ] **Step 4: Verify truthfulness pass**

Run: `rg "导出 JSON|回收站|手动选择" docs/user-guide.md`
Expected: 上述高风险强承诺字面已不再出现

- [ ] **Step 5: Add explicit truth-source disclaimer to the guide**

Add one short note near the introduction or scope area of `docs/user-guide.md` stating that the guide only describes the currently supported public behavior, and formal product/behavior constraints are defined by the relevant documents under `docs/specs/`.

- [ ] **Step 6: Verify disclaimer exists**

Run: `rg "当前支持的公开行为|docs/specs/" docs/user-guide.md`
Expected: 用户指南中存在对正式规格作为真相源的限制性说明

- [ ] **Step 7: Commit guide alignment**

```bash
git add docs/user-guide.md
git commit -m "docs: align user guide with current product truth"
```

---

## Chunk 3: Close The Loop For Planning And Navigation

### Task 4: Update plan index

**Files:**
- Modify: `docs/plans/DIR.md`

- [ ] **Step 1: Add the new implementation plan to `docs/plans/DIR.md`**

Add an index entry for:

```text
2026-03-19-product-truth-source-implementation-plan.md - 实现计划 - 产品级真相源文档与公开入口文档对齐
```

- [ ] **Step 2: Verify plan index alignment**

Run: `rg "2026-03-19-product-truth-source-implementation-plan.md" docs/plans/DIR.md`
Expected: 计划索引中存在该计划条目

- [ ] **Step 3: Run final documentation verification**

Run: `git diff --check`
Expected: no whitespace or patch formatting issues

- [ ] **Step 4: Commit planning handoff**

```bash
git add docs/plans/DIR.md
git commit -m "docs: hand off audit to product truth source plan"
```

---

## Final Verification

- [ ] Run: `rg "多设备个人用户|同步和流转笔记数据" docs/specs/product.md`
Expected: 核心产品目标在正式规格中有明确字面表达

- [ ] Run: `rg "多设备|个人用户|同步|流转" README.md docs/user-guide.md`
Expected: 入口文档与用户指南都能反映产品方向，但不要求与正式规格逐字一致

- [ ] Run: `rg "product.md" docs/specs/DIR.md README.md`
Expected: formal truth source is indexed and referenced

- [ ] Run: `git status --short`
Expected: working tree clean after all planned commits

---

## Notes For The Implementer

- Do not move private author background into tracked files; keep it in local-only context such as `AGENT.local.md`.
- Do not expand this phase into UI redesign or sync behavior changes.
- If you discover that existing formal specs conflict with the new product truth source, stop and update the plan rather than silently reconciling by intuition.
