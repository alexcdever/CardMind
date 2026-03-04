# UI Interaction Full S1-S5 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement full S1-S5 UI interaction behavior from `docs/specs/ui-interaction.md` with independent, shippable micro-iterations and per-iteration governance gates.

**Architecture:** Keep mobile/desktop as independent UI implementations, and enforce semantic parity through scenario-driven widget tests. Execute each scenario (`S1` to `S5`) as a closed loop: failing tests first, minimal code changes, governance docs sync, and gate verification. Use observable behavior assertions only (texts/dialogs/navigation/actions), not implementation details.

**Tech Stack:** Flutter (`material`), Dart widget tests (`flutter_test`), existing app shell/controllers/pages, governance docs and guard tests.

---

### Task 1: Baseline spec mapping scaffold

**Files:**
- Modify: `docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md`
- Modify: `docs/plans/2026-02-27-ui-interaction-release-gate.md`
- Test: `test/ui_interaction_governance_docs_test.dart`

**Step 1: Write the failing test**

Add a failing assertion in `test/ui_interaction_governance_docs_test.dart` that requires S1-S5 entries to exist in acceptance matrix/release gate for this plan cycle.

**Step 2: Run test to verify it fails**

Run: `flutter test test/ui_interaction_governance_docs_test.dart`
Expected: FAIL with missing S1-S5 mapping markers.

**Step 3: Write minimal implementation**

Update the two governance docs with explicit S1-S5 checklist rows/sections and plan filename references.

**Step 4: Run test to verify it passes**

Run: `flutter test test/ui_interaction_governance_docs_test.dart`
Expected: PASS.

**Step 5: Commit**

```bash
git add test/ui_interaction_governance_docs_test.dart docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md docs/plans/2026-02-27-ui-interaction-release-gate.md
git commit -m "test(governance): require S1-S5 matrix and gate mapping"
```

### Task 2: S1 first-screen default cards and back semantics tests

**Files:**
- Modify: `test/app/app_shell_navigation_test.dart`
- Modify: `test/interaction_guard_test.dart`

**Step 1: Write the failing test**

In `test/app/app_shell_navigation_test.dart`, add/adjust tests for:
- cold start lands on cards root,
- back from non-cards returns to cards first,
- back on cards root shows exit confirm,
- cancel on dialog stays in cards root.

Add one guard assertion in `test/interaction_guard_test.dart` to ensure exit confirm actions are not empty/no-op handlers.

**Step 2: Run test to verify it fails**

Run: `flutter test test/app/app_shell_navigation_test.dart test/interaction_guard_test.dart`
Expected: FAIL on at least one S1 scenario assertion.

**Step 3: Write minimal implementation**

Apply minimal changes in shell navigation/back handling if needed so tests pass without altering unrelated flows.

**Step 4: Run test to verify it passes**

Run: `flutter test test/app/app_shell_navigation_test.dart test/interaction_guard_test.dart`
Expected: PASS.

**Step 5: Commit**

```bash
git add test/app/app_shell_navigation_test.dart test/interaction_guard_test.dart lib/app/navigation/app_shell_page.dart
git commit -m "test(shell): lock S1 cards-entry and two-stage back semantics"
```

### Task 3: S1 governance sync for scenario closure

**Files:**
- Modify: `docs/plans/2026-02-27-ui-interaction-governance-design.md`
- Modify: `docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md`
- Modify: `docs/plans/2026-02-27-ui-interaction-release-gate.md`

**Step 1: Write the failing test**

Extend governance doc test to require explicit S1 completion evidence (test names + expected observable outcomes).

**Step 2: Run test to verify it fails**

Run: `flutter test test/ui_interaction_governance_docs_test.dart`
Expected: FAIL with S1 evidence missing.

**Step 3: Write minimal implementation**

Add S1 evidence entries into governance docs, including command lines and result criteria.

**Step 4: Run test to verify it passes**

Run: `flutter test test/ui_interaction_governance_docs_test.dart`
Expected: PASS.

**Step 5: Commit**

```bash
git add test/ui_interaction_governance_docs_test.dart docs/plans/2026-02-27-ui-interaction-governance-design.md docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md docs/plans/2026-02-27-ui-interaction-release-gate.md
git commit -m "docs(governance): record S1 completion evidence"
```

### Task 4: S2 cards CRUD + leave guard failing tests

**Files:**
- Modify: `test/features/cards/cards_page_test.dart`
- Modify: `test/features/editor/editor_page_test.dart`

**Step 1: Write the failing test**

Add/adjust tests for S2:
- create/edit/save gives visible save feedback,
- list reflects new card,
- dirty leave shows three decisions: save-and-leave, discard, cancel,
- failure/interruption path keeps editing context recoverable.

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/cards/cards_page_test.dart test/features/editor/editor_page_test.dart`
Expected: FAIL for at least one leave-guard/save-feedback requirement.

**Step 3: Write minimal implementation**

Patch minimal behavior in cards/editor pages/controllers to satisfy observable S2 behavior only.

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/cards/cards_page_test.dart test/features/editor/editor_page_test.dart`
Expected: PASS.

**Step 5: Commit**

```bash
git add test/features/cards/cards_page_test.dart test/features/editor/editor_page_test.dart lib/features/cards/cards_page.dart lib/features/editor/editor_page.dart lib/features/editor/editor_controller.dart
git commit -m "feat(cards): enforce S2 save feedback and dirty-leave guard"
```

### Task 5: S2 search semantics (Active Note, title+body, case-insensitive)

**Files:**
- Modify: `test/features/cards/cards_page_test.dart`
- Modify: `test/features/cards/data/sqlite_cards_read_repository_test.dart`
- Modify: `lib/features/cards/cards_controller.dart`
- Modify: `lib/features/cards/data/sqlite_cards_read_repository.dart`

**Step 1: Write the failing test**

Add tests asserting search filters Active Note records and matches title/body substring case-insensitively.

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/cards/cards_page_test.dart test/features/cards/data/sqlite_cards_read_repository_test.dart`
Expected: FAIL with mismatch in filtering/matching semantics.

**Step 3: Write minimal implementation**

Implement minimal query/filter logic to satisfy S2 search semantics.

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/cards/cards_page_test.dart test/features/cards/data/sqlite_cards_read_repository_test.dart`
Expected: PASS.

**Step 5: Commit**

```bash
git add test/features/cards/cards_page_test.dart test/features/cards/data/sqlite_cards_read_repository_test.dart lib/features/cards/cards_controller.dart lib/features/cards/data/sqlite_cards_read_repository.dart
git commit -m "feat(cards-search): align S2 Active Note substring matching semantics"
```

### Task 6: S2 governance sync and gates

**Files:**
- Modify: `docs/plans/2026-02-27-ui-interaction-governance-design.md`
- Modify: `docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md`
- Modify: `docs/plans/2026-02-27-ui-interaction-release-gate.md`

**Step 1: Write the failing test**

Require S2 success/failure mapping rows in governance docs test.

**Step 2: Run test to verify it fails**

Run: `flutter test test/ui_interaction_governance_docs_test.dart`
Expected: FAIL for missing S2 mapping evidence.

**Step 3: Write minimal implementation**

Add S2 mapping entries and gate checklist references.

**Step 4: Run test to verify it passes**

Run: `flutter test test/ui_interaction_governance_docs_test.dart`
Expected: PASS.

**Step 5: Commit**

```bash
git add test/ui_interaction_governance_docs_test.dart docs/plans/2026-02-27-ui-interaction-governance-design.md docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md docs/plans/2026-02-27-ui-interaction-release-gate.md
git commit -m "docs(governance): record S2 acceptance and gate evidence"
```

### Task 7: S3 pool flows failing tests (create/join/approval/exit)

**Files:**
- Modify: `test/features/pool/pool_page_test.dart`
- Modify: `test/features/pool/pool_sync_interaction_test.dart`
- Modify: `test/features/pool/join_error_mapper_test.dart`

**Step 1: Write the failing test**

Add/adjust S3 tests for:
- unjoined/joined/error three-state visibility,
- join failure shows "what happened + next step",
- approval success and failure-retry behavior,
- exit partial cleanup exposes retry action.

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/pool/pool_page_test.dart test/features/pool/pool_sync_interaction_test.dart test/features/pool/join_error_mapper_test.dart`
Expected: FAIL on at least one failure-recovery assertion.

**Step 3: Write minimal implementation**

Apply minimal updates in pool page/controller/error mapping so observable flows match S3 contract.

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/pool/pool_page_test.dart test/features/pool/pool_sync_interaction_test.dart test/features/pool/join_error_mapper_test.dart`
Expected: PASS.

**Step 5: Commit**

```bash
git add test/features/pool/pool_page_test.dart test/features/pool/pool_sync_interaction_test.dart test/features/pool/join_error_mapper_test.dart lib/features/pool/pool_page.dart lib/features/pool/pool_controller.dart lib/features/pool/join_error_mapper.dart
git commit -m "feat(pool): align S3 failure semantics and recovery actions"
```

### Task 8: S3 stable error-code path coverage hardening

**Files:**
- Modify: `test/features/pool/join_error_mapper_test.dart`
- Modify: `test/features/pool/pool_page_test.dart`

**Step 1: Write the failing test**

Add dedicated failure-path tests for at least one stable code (for example `POOL_NOT_FOUND` or `REQUEST_TIMEOUT`) including expected primary action label and follow-up action availability.

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/pool/join_error_mapper_test.dart test/features/pool/pool_page_test.dart`
Expected: FAIL with missing code mapping assertion.

**Step 3: Write minimal implementation**

Update mapping/presentation minimally to satisfy stable-code behavior.

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/pool/join_error_mapper_test.dart test/features/pool/pool_page_test.dart`
Expected: PASS.

**Step 5: Commit**

```bash
git add test/features/pool/join_error_mapper_test.dart test/features/pool/pool_page_test.dart lib/features/pool/join_error_mapper.dart
git commit -m "test(pool): enforce stable error-code recovery coverage for S3"
```

### Task 9: S3 governance sync and gates

**Files:**
- Modify: `docs/plans/2026-02-27-ui-interaction-governance-design.md`
- Modify: `docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md`
- Modify: `docs/plans/2026-02-27-ui-interaction-release-gate.md`

**Step 1: Write the failing test**

Update governance docs test to require S3 stable-error evidence references.

**Step 2: Run test to verify it fails**

Run: `flutter test test/ui_interaction_governance_docs_test.dart`
Expected: FAIL with missing S3 evidence.

**Step 3: Write minimal implementation**

Append S3 evidence rows and gate commands to governance docs.

**Step 4: Run test to verify it passes**

Run: `flutter test test/ui_interaction_governance_docs_test.dart`
Expected: PASS.

**Step 5: Commit**

```bash
git add test/ui_interaction_governance_docs_test.dart docs/plans/2026-02-27-ui-interaction-governance-design.md docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md docs/plans/2026-02-27-ui-interaction-release-gate.md
git commit -m "docs(governance): add S3 gate evidence and error-code coverage"
```

### Task 10: S4 settings one-step reachability tests

**Files:**
- Modify: `test/features/settings/settings_page_test.dart`
- Modify: `test/app/adaptive_shell_test.dart`

**Step 1: Write the failing test**

Add/adjust tests proving from settings you can reach cards or pool in one action and without multi-hop back-chain dependence.

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/settings_page_test.dart test/app/adaptive_shell_test.dart`
Expected: FAIL on one-step reachability assertion.

**Step 3: Write minimal implementation**

Implement minimal settings/shell navigation updates to satisfy one-step reachability.

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/settings/settings_page_test.dart test/app/adaptive_shell_test.dart`
Expected: PASS.

**Step 5: Commit**

```bash
git add test/features/settings/settings_page_test.dart test/app/adaptive_shell_test.dart lib/features/settings/settings_page.dart lib/app/layout/adaptive_shell.dart
git commit -m "feat(settings): enforce S4 one-step reachability to cards and pool"
```

### Task 11: S4 governance sync and gates

**Files:**
- Modify: `docs/plans/2026-02-27-ui-interaction-governance-design.md`
- Modify: `docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md`
- Modify: `docs/plans/2026-02-27-ui-interaction-release-gate.md`

**Step 1: Write the failing test**

Add S4-specific evidence requirement to governance docs guard test.

**Step 2: Run test to verify it fails**

Run: `flutter test test/ui_interaction_governance_docs_test.dart`
Expected: FAIL with missing S4 references.

**Step 3: Write minimal implementation**

Record S4 scenario checks and pass criteria in governance docs.

**Step 4: Run test to verify it passes**

Run: `flutter test test/ui_interaction_governance_docs_test.dart`
Expected: PASS.

**Step 5: Commit**

```bash
git add test/ui_interaction_governance_docs_test.dart docs/plans/2026-02-27-ui-interaction-governance-design.md docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md docs/plans/2026-02-27-ui-interaction-release-gate.md
git commit -m "docs(governance): add S4 reachability evidence"
```

### Task 12: S5 sync degraded behavior tests

**Files:**
- Modify: `test/features/sync/sync_banner_test.dart`
- Modify: `test/features/cards/cards_sync_navigation_test.dart`
- Modify: `test/features/sync/sync_controller_test.dart`

**Step 1: Write the failing test**

Add/adjust tests for S5:
- sync exception prompt provides `retry` or `reconnect`,
- degraded remains non-blocking for local card save,
- degraded prompt layer stays informative but non-modal.

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/sync/sync_banner_test.dart test/features/cards/cards_sync_navigation_test.dart test/features/sync/sync_controller_test.dart`
Expected: FAIL on non-blocking degraded or action availability assertion.

**Step 3: Write minimal implementation**

Apply minimal sync banner/controller updates to preserve local edit/save continuity in degraded state.

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/sync/sync_banner_test.dart test/features/cards/cards_sync_navigation_test.dart test/features/sync/sync_controller_test.dart`
Expected: PASS.

**Step 5: Commit**

```bash
git add test/features/sync/sync_banner_test.dart test/features/cards/cards_sync_navigation_test.dart test/features/sync/sync_controller_test.dart lib/features/sync/sync_banner.dart lib/features/sync/sync_controller.dart
git commit -m "feat(sync): enforce S5 degraded non-blocking behavior and recovery actions"
```

### Task 13: S5 governance sync and gates

**Files:**
- Modify: `docs/plans/2026-02-27-ui-interaction-governance-design.md`
- Modify: `docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md`
- Modify: `docs/plans/2026-02-27-ui-interaction-release-gate.md`

**Step 1: Write the failing test**

Update governance docs guard test to require S5 degraded/non-blocking evidence.

**Step 2: Run test to verify it fails**

Run: `flutter test test/ui_interaction_governance_docs_test.dart`
Expected: FAIL for missing S5 record.

**Step 3: Write minimal implementation**

Add S5 evidence and gate checks to governance docs.

**Step 4: Run test to verify it passes**

Run: `flutter test test/ui_interaction_governance_docs_test.dart`
Expected: PASS.

**Step 5: Commit**

```bash
git add test/ui_interaction_governance_docs_test.dart docs/plans/2026-02-27-ui-interaction-governance-design.md docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md docs/plans/2026-02-27-ui-interaction-release-gate.md
git commit -m "docs(governance): add S5 degraded recovery evidence"
```

### Task 14: Cross-scenario gate run and regression safety

**Files:**
- Modify: `docs/plans/2026-02-27-ui-interaction-release-gate.md`

**Step 1: Write the failing test**

Add/adjust release gate checks so final gate requires all S1-S5 markers and guard commands.

**Step 2: Run test to verify it fails**

Run: `flutter test test/ui_interaction_governance_docs_test.dart`
Expected: FAIL before final gate entries are complete.

**Step 3: Write minimal implementation**

Finalize release-gate checklist with S1-S5 signoff rows and exact command list.

**Step 4: Run test to verify it passes**

Run:
- `flutter test test/ui_interaction_governance_docs_test.dart`
- `flutter test test/interaction_guard_test.dart`
- `flutter test test/app/app_shell_navigation_test.dart`
- `flutter test test/features/cards/cards_page_test.dart`
- `flutter test test/features/editor/editor_page_test.dart`
- `flutter test test/features/pool/pool_page_test.dart`
- `flutter test test/features/settings/settings_page_test.dart`
- `flutter test test/features/sync/sync_banner_test.dart`

Expected: PASS across suite.

**Step 5: Commit**

```bash
git add docs/plans/2026-02-27-ui-interaction-release-gate.md test/ui_interaction_governance_docs_test.dart
git commit -m "docs(release-gate): finalize S1-S5 mandatory gate checklist"
```

### Task 15: Final verification and handoff

**Files:**
- Modify: `docs/plans/2026-03-05-ui-interaction-full-s1-s5-implementation-plan.md`

**Step 1: Write the failing test**

N/A (verification task).

**Step 2: Run test to verify it fails**

N/A.

**Step 3: Write minimal implementation**

Add final execution notes (completed command outputs summary and remaining risk items) to this plan doc.

**Step 4: Run test to verify it passes**

Run:
- `flutter test test/ui_interaction_governance_docs_test.dart`
- `flutter test test/interaction_guard_test.dart`
- `flutter test`

Expected: PASS (or documented known failures outside S1-S5 scope).

**Step 5: Commit**

```bash
git add docs/plans/2026-03-05-ui-interaction-full-s1-s5-implementation-plan.md
git commit -m "docs(plans): add execution notes for S1-S5 rollout"
```

## Execution Notes

- Follow strict red-green-refactor for every code task: @superpowers/test-driven-development.
- If any test fails unexpectedly, run root-cause flow before fixing: @superpowers/systematic-debugging.
- Before claiming completion for each task/iteration, run required checks and capture evidence: @superpowers/verification-before-completion.
- For iterative implementation in this session, prefer: @superpowers/subagent-driven-development.
- For separate focused execution session, use: @superpowers/executing-plans.

## Final Execution Notes (Completed)

### Command Summary
- Governance/doc guard:
  - `flutter test test/ui_interaction_governance_docs_test.dart`
  - `flutter test test/interaction_guard_test.dart`
- Scenario regression slices:
  - `flutter test test/app/app_shell_navigation_test.dart`
  - `flutter test test/features/cards/cards_page_test.dart`
  - `flutter test test/features/editor/editor_page_test.dart`
  - `flutter test test/features/pool/pool_page_test.dart`
  - `flutter test test/features/settings/settings_page_test.dart`
  - `flutter test test/features/sync/sync_banner_test.dart`
- Scenario-focused suites were also run per task (cards/pool/sync sub-suites) in red-green-refactor cycles.

### Result Snapshot
- S1-S5 task chain completed in strict order with per-task commit.
- Required governance guards passed repeatedly after each task:
  - `test/ui_interaction_governance_docs_test.dart`
  - `test/interaction_guard_test.dart`
- Cross-scenario gate suite in Task 14 passed for all listed commands.

### Remaining Risks
- Governance evidence currently references concrete test names/commands; future test renames require synchronized doc updates.
- Some recovery prompts use fixed copy; if product wording policy changes, behavior tests and governance docs should be updated together.
- Full-repo `flutter test` remains the final broad-scope confidence run and should stay in release validation.
