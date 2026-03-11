input: 已批准的架构规格设计与 spec-first 文档落地需求
output: 项目级架构规格实施计划（新增 formal spec + 对齐索引与相关规格引用）
pos: architecture 规格文档实施计划，执行前需先读对应设计稿
# Architecture Spec Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add `docs/specs/architecture.md` as the formal project-level architecture spec, index it correctly, and align related spec references so later implementation work can rely on it as the top-level architecture constraint.

**Architecture:** Keep design, spec, and plan strictly separated. Use `docs/plans/2026-03-09-architecture-spec-design.md` as decision context, write the normative architecture rules only in `docs/specs/architecture.md`, then align `docs/specs/DIR.md` and only the minimum necessary wording in related specs to make the new hierarchy explicit.

**Tech Stack:** Markdown documentation, repo documentation standards in `docs/standards/`, spec files in `docs/specs/`, git

---

## Execution Rules (Mandatory)

1. Task 1 MUST create the formal architecture spec before any downstream wording alignment.
2. Every task MUST follow `Red -> Green -> Blue -> Commit`, even for documentation-only changes.
3. Do not move normative architecture content into `docs/plans/`.
4. Keep `docs/specs/architecture.md` at the `原则级 + 关键结构约束` level; do not turn it into an implementation blueprint.
5. Any touched directory index file (`DIR.md`) MUST stay truthful.

## Worktree Requirement

Before executing Task 1 implementation work:

1. Create an isolated worktree under `.worktrees/`.
2. Recommended branch name: `architecture-spec`.
3. Verify the current documentation baseline before editing.

Run:

```bash
git worktree add ".worktrees/architecture-spec" -b "architecture-spec"
rg -n "architecture\.md|架构规格" docs/specs docs/plans
```

Expected: worktree created successfully; no existing formal `docs/specs/architecture.md` is present.

---

### Task 1: Create the formal architecture spec

**Files:**
- Create: `docs/specs/architecture.md`
- Modify: `docs/specs/DIR.md`
- Reference: `docs/specs/_template.md`
- Reference: `docs/specs/shared-domain-contract.md`
- Reference: `docs/plans/2026-03-09-architecture-spec-design.md`

**Step 1: Write the failing documentation guard by listing required sections**

The new spec must include all of the following sections and constraints:

```text
- 0. 使用说明
- 1. 目的与范围
- 2. 术语
- 3. 规范性规则
- 4. 顶层架构职责
- 5. 读写分离与数据流
- 6. 中层结构约束
- 7. 一致性、错误与恢复原则
- 8. 禁止事项
- 9. 验收标准（黑盒）
- Flutter = 前端；Rust = 后端；FRB = 语言边界
- LoroDoc = 唯一真实信源；SQLite = 查询侧读模型
- 所有查询只能走 SQLite
- 所有业务写入必须先落 LoroDoc
```

**Step 2: Verify RED by confirming the file does not exist yet**

Run:

```bash
test -f docs/specs/architecture.md && echo "unexpected exists" || echo "missing"
```

Expected: `missing`

Run:

```bash
rg -n "LoroDoc =|SQLite =|所有查询只能走 SQLite|所有业务写入必须先落 LoroDoc" docs/specs/architecture.md
```

Expected: command fails because the file is absent.

**Step 3: Write the minimal specification**

Create `docs/specs/architecture.md` with these required outcomes:

```text
- It is a formal spec, not a design doc or migration plan.
- It defines architecture scope, terms, and normative rule strength.
- It states Flutter only owns UI / interaction orchestration / presentation state / backend calls.
- It states Rust owns domain rules / business writes / projection driving / sync / stable contracts.
- It states FRB is only the language boundary.
- It states LoroDoc is the only source of truth for card-note and pool metadata.
- It states SQLite is only the query-side read model.
- It states all queries go through SQLite and all business writes go through Rust into LoroDoc.
- It states projection and sync failures cannot be disguised as business write failure.
- It includes black-box Given/When/Then acceptance scenarios.
```

Update `docs/specs/DIR.md` with a truthful one-line index entry for `architecture.md`.

**Step 4: Verify GREEN**

Run:

```bash
rg -n "## 0\.|## 1\.|## 2\.|## 3\.|## 4\.|## 5\.|## 6\.|## 7\.|## 8\.|## 9\." docs/specs/architecture.md
```

Expected: all required sections are found.

Run:

```bash
rg -n "Flutter.*前端|Rust.*后端|FRB.*语言边界|LoroDoc.*唯一真实信源|SQLite.*查询侧读模型|所有查询.*SQLite|所有业务写入.*LoroDoc" docs/specs/architecture.md
```

Expected: all core architecture constraints are found.

Run:

```bash
rg -n "architecture\.md" docs/specs/DIR.md
```

Expected: one truthful index entry is found.

**Step 5: Blue refactor**

Tighten wording so the document remains language-agnostic where possible, while still preserving the chosen architecture names (`Flutter`, `Rust`, `FRB`, `LoroDoc`, `SQLite`) as explicit project constraints.

**Step 6: Re-run verification after Blue**

Run the three commands from Step 4 again.

Expected: PASS.

**Step 7: Commit**

```bash
git add docs/specs/architecture.md docs/specs/DIR.md
git commit -m "docs: add architecture spec"
```

---

### Task 2: Align shared cross-spec hierarchy wording

**Files:**
- Modify: `docs/specs/shared-domain-contract.md`
- Modify: `docs/specs/DIR.md` (only if the index text needs wording alignment)
- Reference: `docs/specs/architecture.md`

**Step 1: Write the failing doc check**

Document the needed hierarchy clarification:

```text
- shared-domain-contract remains the cross-domain behavior contract
- architecture becomes the project-level architecture constraint
- shared-domain-contract should not imply it is the only upper-layer constraint for all specs
```

**Step 2: Verify RED**

Run:

```bash
rg -n "作为分域规格之上的总则|与分域规格关系与演进" docs/specs/shared-domain-contract.md
```

Expected: current wording is present and does not yet mention the new architecture spec relationship.

**Step 3: Write the minimal wording update**

Required outcomes in `docs/specs/shared-domain-contract.md`:

```text
- Keep shared-domain-contract focused on shared behavior rules.
- Clarify that domain specs must also comply with project-level architecture constraints where applicable.
- Do not copy architecture rules into shared-domain-contract.
```

If no wording change is actually needed after careful read, record that conclusion in the task execution notes and skip the file edit; do not make no-op changes.

**Step 4: Verify GREEN**

Run:

```bash
rg -n "架构规格|architecture\.md|项目级架构约束" docs/specs/shared-domain-contract.md
```

Expected: either matches are present after the edit, or the executor has explicit written rationale for why no change was needed.

**Step 5: Blue refactor**

Remove duplicate wording so the file still reads as a concise shared contract rather than an index of every other spec.

**Step 6: Re-run verification after Blue**

Run the same `rg` command again if the file changed.

Expected: PASS.

**Step 7: Commit**

```bash
git add docs/specs/shared-domain-contract.md docs/specs/DIR.md
git commit -m "docs: align shared contract with architecture spec"
```

If no file change was needed, skip this commit and continue.

---

### Task 3: Align domain spec references with the new architecture layer

**Files:**
- Modify: `docs/specs/card-note.md`
- Modify: `docs/specs/pool.md`
- Modify: `docs/specs/DIR.md` (only if wording needs refresh)
- Reference: `docs/specs/architecture.md`

**Step 1: Write the failing doc check**

Each domain spec should be checked for whether it needs a minimal statement such as:

```text
- This domain spec defines domain behavior only.
- If implementation or behavior touches project architecture boundaries, it must also comply with docs/specs/architecture.md.
```

**Step 2: Verify RED**

Run:

```bash
rg -n "architecture\.md|架构规格|项目级架构约束" docs/specs/card-note.md docs/specs/pool.md
```

Expected: no matches yet.

**Step 3: Write the minimal update**

Required outcomes:

```text
- Add only the smallest wording needed to make the relationship explicit.
- Keep card-note and pool focused on domain behavior.
- Do not duplicate source-of-truth, projection, or FRB details already owned by architecture.md unless needed for clarity.
```

If, after review, either file is already sufficiently scoped without explicit reference, document that rationale during execution and skip that file.

**Step 4: Verify GREEN**

Run:

```bash
rg -n "architecture\.md|架构规格|项目级架构约束" docs/specs/card-note.md docs/specs/pool.md
```

Expected: only the intended minimal reference wording is present in touched files.

**Step 5: Blue refactor**

Remove any redundant wording that makes domain specs feel implementation-aware.

**Step 6: Re-run verification after Blue**

Run the same `rg` command again.

Expected: PASS.

**Step 7: Commit**

```bash
git add docs/specs/card-note.md docs/specs/pool.md docs/specs/DIR.md
git commit -m "docs: align domain specs with architecture layer"
```

If no file change was needed, skip this commit and continue.

---

### Task 4: Run final documentation verification and capture the new baseline

**Files:**
- Verify: `docs/specs/architecture.md`
- Verify: `docs/specs/shared-domain-contract.md`
- Verify: `docs/specs/card-note.md`
- Verify: `docs/specs/pool.md`
- Verify: `docs/specs/DIR.md`
- Verify: `docs/DIR.md`

**Step 1: Write the failing verification checklist**

The final baseline must prove:

```text
- architecture.md exists and is indexed
- no normative architecture content remains only in plans without a formal spec counterpart
- shared/domain specs do not conflict with the new architecture layer
- directory indexes remain truthful
```

**Step 2: Verify RED by searching for missing or conflicting markers before final pass**

Run:

```bash
rg -n "architecture\.md" docs/specs/DIR.md docs/specs/shared-domain-contract.md docs/specs/card-note.md docs/specs/pool.md
```

Expected: this may still be incomplete before the final pass, depending on Task 2 and Task 3 outcomes.

**Step 3: Perform the minimal final cleanup**

Required outcomes:

```text
- Fix any stale index wording.
- Fix any conflicting or misleading cross-reference language.
- Do not broaden scope beyond documentation consistency.
```

**Step 4: Verify GREEN**

Run:

```bash
rg -n "architecture\.md" docs/specs/DIR.md docs/specs/shared-domain-contract.md docs/specs/card-note.md docs/specs/pool.md
```

Expected: the intended references are present and no stale wording remains in touched files.

Run:

```bash
git diff --check
```

Expected: no whitespace or patch-format issues.

**Step 5: Blue refactor**

Do one final wording pass for concision and consistency with `docs/specs/_template.md` and `docs/standards/spec-first-execution.md`.

**Step 6: Re-run verification after Blue**

Run the two commands from Step 4 again.

Expected: PASS.

**Step 7: Commit**

```bash
git add docs/specs/architecture.md docs/specs/shared-domain-contract.md docs/specs/card-note.md docs/specs/pool.md docs/specs/DIR.md docs/DIR.md
git commit -m "docs: finalize architecture spec alignment"
```

---

## Expected End State

1. `docs/specs/architecture.md` exists as the formal source for project-level architecture constraints.
2. `docs/specs/DIR.md` truthfully indexes the new spec.
3. Shared and domain specs are either explicitly aligned to the new architecture layer or deliberately left unchanged with documented rationale.
4. Future implementation plans can cite `docs/specs/architecture.md` instead of relying on design docs as normative sources.
