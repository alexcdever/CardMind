input: 已批准的文档治理重构设计，目标为移除文档门禁脚本/测试并内化标准
output: 可执行的任务化实施计划，覆盖删除、标准更新、引用清理与验证步骤
pos: 指导按 Red -> Green -> Blue -> Commit 节奏完成文档治理重构实现

# Doc Governance Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove all documentation-constraint scripts/tests, migrate fractal + TDD rules into standards, and fully retire UI-governance gate artifacts.

**Architecture:** This refactor removes repository-level documentation hard gates and replaces them with standards-driven governance in `docs/standards`. Implementation proceeds in small batches: first remove enforcement code, then update canonical standards, then clean references and verify no dangling paths remain.

**Tech Stack:** Dart/Flutter test tooling, markdown standards docs, git.

---

## Global Execution Rule

All tasks must follow complete TDD workflow: **Red -> Green -> Blue -> Commit**.

- Red: write/adjust checks or expectations first and verify failing state when applicable.
- Green: apply minimal change to satisfy the check.
- Blue: refactor wording/structure for clarity while keeping behavior.
- Commit: commit only after verification commands pass.

### Task 1: Remove fractal documentation gate toolchain

**Files:**
- Delete: `tool/fractal_doc_check.dart`
- Delete: `tool/fractal_doc_checker.dart`
- Delete: `tool/fractal_doc_bootstrap.dart`
- Delete: `test/fractal_doc_checker_test.dart`

**Step 1: Red - define failing expectation for toolchain presence**

Run: `git ls-files tool test | rg "fractal_doc_(check|checker|bootstrap)|fractal_doc_checker_test.dart"`
Expected: PASS with file list present (baseline proves gate exists and must be removed).

**Step 2: Green - delete the toolchain and its tests**

Delete the four files listed above.

**Step 3: Blue - ensure no stale internal references remain**

Run: `rg "fractal_doc_check|fractal_doc_checker|fractal_doc_bootstrap" docs test tool`
Expected: only intended historical notes or zero matches after later tasks.

**Step 4: Verification - confirm removal took effect**

Run: `git ls-files tool test | rg "fractal_doc_(check|checker|bootstrap)|fractal_doc_checker_test.dart"`
Expected: FAIL/empty result (files removed).

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor(docs-gate): remove fractal doc enforcement toolchain"
```

### Task 2: Remove plan/UI documentation guard tests

**Files:**
- Delete: `test/plan_tdd_guard_test.dart`
- Delete: `test/ui_interaction_governance_docs_test.dart`

**Step 1: Red - capture current guard test footprint**

Run: `git ls-files test | rg "plan_tdd_guard_test.dart|ui_interaction_governance_docs_test.dart"`
Expected: PASS with both file paths listed.

**Step 2: Green - delete guard tests**

Delete the two files listed above.

**Step 3: Blue - scan for references to removed tests in docs/commands**

Run: `rg "plan_tdd_guard_test|ui_interaction_governance_docs_test|dart run tool/fractal_doc_check.dart --base" docs test`
Expected: matches may remain and will be removed in Task 4.

**Step 4: Verification - guard tests are gone from tracked files**

Run: `git ls-files test | rg "plan_tdd_guard_test.dart|ui_interaction_governance_docs_test.dart"`
Expected: FAIL/empty result.

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor(docs-gate): remove plan and UI governance guard tests"
```

### Task 3: Remove UI governance gate documents

**Files:**
- Delete: `docs/plans/2026-02-27-ui-interaction-governance-design.md`
- Delete: `docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md`
- Delete: `docs/plans/2026-02-27-ui-interaction-release-gate.md`
- Modify: `docs/plans/DIR.md`

**Step 1: Red - verify target docs exist in index**

Run: `rg "2026-02-27-ui-interaction-(governance-design|acceptance-matrix|release-gate).md" docs/plans/DIR.md`
Expected: PASS with 3 entries.

**Step 2: Green - delete docs and remove their DIR index lines**

Delete three docs and remove corresponding lines from `docs/plans/DIR.md`.

**Step 3: Blue - keep DIR chronological and wording consistent**

Normalize nearby `docs/plans/DIR.md` descriptions if line continuity is broken.

**Step 4: Verification - ensure no index residue**

Run: `rg "2026-02-27-ui-interaction-(governance-design|acceptance-matrix|release-gate).md" docs/plans`
Expected: no active index references (historical mention acceptable only if intentional and explicit).

**Step 5: Commit**

```bash
git add -A
git commit -m "docs(plans): retire UI governance gate artifacts"
```

### Task 4: Internalize policy in standards docs

**Files:**
- Modify: `docs/standards/documentation.md`
- Modify: `docs/standards/tdd.md`

**Step 1: Red - identify old hard-gate wording and command references**

Run: `rg "fractal_doc_check|DIR.md|Red -> Green -> Blue -> Commit|门禁|guard|硬阻断" docs/standards/documentation.md docs/standards/tdd.md`
Expected: PASS with current wording to be updated.

**Step 2: Green - update standards to policy-driven governance**

Required content updates:
- In `docs/standards/documentation.md`, define fractal documentation rules as mandatory policy (headers + DIR indexing expectations) without requiring repo script gate.
- In `docs/standards/tdd.md`, define complete Red/Green/Blue/Commit as mandatory engineering process without requiring plan keyword guard tests.

**Step 3: Blue - tighten language for AI executability**

Ensure clauses are explicit and machine-followable:
- use MUST/SHOULD wording,
- separate normative rules from examples,
- avoid topic-specific UI governance coupling.

**Step 4: Verification - standards contain canonical policy statements**

Run: `rg "MUST|Red|Green|Blue|Commit|DIR.md|input:|output:|pos:" docs/standards/documentation.md docs/standards/tdd.md`
Expected: PASS with clear normative statements present.

**Step 5: Commit**

```bash
git add docs/standards/documentation.md docs/standards/tdd.md
git commit -m "docs(standards): internalize fractal and complete TDD policies"
```

### Task 5: Global reference cleanup and final verification

**Files:**
- Modify: `docs/plans/DIR.md` (if new plan entries are added)
- Modify: any file containing stale references

**Step 1: Red - locate all stale references**

Run:

```bash
rg "fractal_doc_check|fractal_doc_checker|fractal_doc_bootstrap|plan_tdd_guard_test|ui_interaction_governance_docs_test|2026-02-27-ui-interaction-(governance-design|acceptance-matrix|release-gate).md" docs test tool
```

Expected: matches indicate remaining cleanup scope.

**Step 2: Green - remove or rewrite stale references**

Update matched files to either:
- remove obsolete command/path, or
- replace with new policy statement in standards.

**Step 3: Blue - keep documentation consistent and minimal (YAGNI)**

Remove duplicate explanations and keep one canonical rule source in `docs/standards`.

**Step 4: Verification - repo health checks**

Run:

```bash
flutter analyze
flutter test
```

Expected: PASS without any dependency on deleted doc-gate tests/scripts.

Run:

```bash
rg "fractal_doc_check|plan_tdd_guard_test|ui_interaction_governance_docs_test" docs test tool
```

Expected: no active operational references.

**Step 5: Commit**

```bash
git add -A
git commit -m "chore(docs): cleanup stale doc-gate references after policy migration"
```

## Done Criteria

- No documentation-constraint gate scripts/tests remain in repository.
- UI governance gate docs are removed and no longer indexed.
- `docs/standards/documentation.md` and `docs/standards/tdd.md` are the canonical governance source.
- Full verification commands pass.
