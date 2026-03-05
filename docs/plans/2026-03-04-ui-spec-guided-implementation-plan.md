input: UI 规格驱动实施设计（分阶段 + 受控补规格）
output: 可直接执行的任务化实施计划（TDD + 门禁）
pos: UI 规格驱动实施计划（修改需同步 DIR.md）
# UI Spec-Guided Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement UI behavior in phased delivery (P1:S1+S2, P2:S3, P3:S4+S5) fully aligned with `docs/specs/ui-interaction.md` while preserving spec-first governance.

**Architecture:** Reuse existing app shell + feature page/controller boundaries and enforce spec clauses through behavior-level tests first. Each task maps MUST/FORBIDDEN requirements to observable UI outcomes (route, feedback, dialog, action availability). Spec gaps are patched minimally in `docs/specs/ui-interaction.md` only when implementation cannot be decided from current text.

**Tech Stack:** Flutter (Dart), flutter_test, existing governance guards (`docs/standards/ui-interaction-governance.md`, `test/interaction_guard_test.dart`)

---

## Execution Rules (Mandatory)

1. Use strict TDD for every task: Red -> Green -> Blue -> Commit.
2. Keep each task independently verifiable; do not batch unrelated changes.
3. Never change behavior without corresponding test assertions.
4. If spec ambiguity blocks implementation, first patch `docs/specs/ui-interaction.md` minimally, then continue.

### Complete TDD Workflow Requirement

Every task MUST explicitly include the complete sequence `Red -> Green -> Blue -> Commit`（红 -> 绿 -> 蓝 -> 提交）:

1. Red: write the failing test and verify it fails (`Expected: FAIL`).
2. Green: implement the minimal behavior and verify it passes (`Expected: PASS`).
3. Blue refactor: refactor without behavior change and re-run related tests.
4. Commit: only after Blue refactor verification succeeds.

---

### Task 1: P1-S1 引导分流 + 主壳返回语义对齐

**Files:**
- Modify: `lib/features/onboarding/onboarding_page.dart`
- Modify: `lib/app/navigation/app_shell_page.dart`
- Modify: `lib/app/navigation/app_shell_controller.dart`
- Test: `test/features/onboarding/onboarding_page_test.dart`
- Test: `test/app/app_shell_navigation_test.dart`

**Step 1: Write failing tests (S1 acceptance)**

```dart
testWidgets('onboarding shows exactly two primary entrances', ...);
testWidgets('shell non-cards back goes to cards root first', ...);
testWidgets('cards root back shows exit confirmation', ...);
```

**Step 2: Run tests to verify failures**

Run: `flutter test test/features/onboarding/onboarding_page_test.dart test/app/app_shell_navigation_test.dart -r compact`
Expected: FAIL on at least one S1 assertion

**Step 3: Minimal implementation**

```dart
// Ensure onboarding entry set only: local / create-or-join.
// Ensure shell back policy: non-cards -> cards root, then exit confirm.
```

**Step 4: Re-run targeted tests**

Run: `flutter test test/features/onboarding/onboarding_page_test.dart test/app/app_shell_navigation_test.dart -r compact`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/onboarding/onboarding_page.dart lib/app/navigation/app_shell_page.dart lib/app/navigation/app_shell_controller.dart test/features/onboarding/onboarding_page_test.dart test/app/app_shell_navigation_test.dart
git commit -m "feat(ui-s1): align onboarding split and shell back semantics"
```

**Step 6: Blue refactor verification**

Run: `flutter test test/features/onboarding/onboarding_page_test.dart test/app/app_shell_navigation_test.dart -r compact`
Expected: PASS after Blue refactor

---

### Task 2: P1-S2 卡片编辑主流程（保存反馈 + 离开保护）

**Files:**
- Modify: `lib/features/cards/cards_page.dart`
- Modify: `lib/features/editor/editor_page.dart`
- Modify: `lib/features/editor/editor_controller.dart`
- Test: `test/features/cards/cards_page_test.dart`
- Test: `test/features/editor/editor_page_test.dart`
- Test: `test/features/editor/editor_shortcuts_test.dart`

**Step 1: Write failing tests (S2 acceptance)**

```dart
testWidgets('save shows processing then success feedback', ...);
testWidgets('dirty editor leaving shows 3-way guard dialog', ...);
testWidgets('sync degraded does not block local save path', ...);
```

**Step 2: Run tests to verify failures**

Run: `flutter test test/features/cards/cards_page_test.dart test/features/editor/editor_page_test.dart test/features/editor/editor_shortcuts_test.dart -r compact`
Expected: FAIL where feedback/guard behavior mismatches

**Step 3: Minimal implementation**

```dart
// Keep editor state transitions explicit: saving -> success/failure.
// Ensure leave guard options: save and leave / discard / cancel.
// Preserve local save in degraded sync mode.
```

**Step 4: Re-run targeted tests**

Run: `flutter test test/features/cards/cards_page_test.dart test/features/editor/editor_page_test.dart test/features/editor/editor_shortcuts_test.dart -r compact`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/cards/cards_page.dart lib/features/editor/editor_page.dart lib/features/editor/editor_controller.dart test/features/cards/cards_page_test.dart test/features/editor/editor_page_test.dart test/features/editor/editor_shortcuts_test.dart
git commit -m "feat(ui-s2): enforce editor feedback and leave-guard flow"
```

**Step 6: Blue refactor verification**

Run: `flutter test test/features/cards/cards_page_test.dart test/features/editor/editor_page_test.dart test/features/editor/editor_shortcuts_test.dart -r compact`
Expected: PASS after Blue refactor

---

### Task 3: P2-S3 池生命周期（创建/加入/审批/退出）与错误恢复

**Files:**
- Modify: `lib/features/pool/pool_page.dart`
- Modify: `lib/features/pool/pool_controller.dart`
- Modify: `lib/features/pool/join_error_mapper.dart`
- Test: `test/features/pool/pool_page_test.dart`
- Test: `test/features/pool/join_error_mapper_test.dart`

**Step 1: Write failing tests (S3 acceptance)**

```dart
testWidgets('join failure shows semantic reason and next action', ...);
testWidgets('approve/reject updates pending request state', ...);
testWidgets('exit partial cleanup shows retry cleanup action', ...);
```

**Step 2: Run tests to verify failures**

Run: `flutter test test/features/pool/pool_page_test.dart test/features/pool/join_error_mapper_test.dart -r compact`
Expected: FAIL on at least one lifecycle/recovery assertion

**Step 3: Minimal implementation**

```dart
// Align pool states with spec 6.2 + 6.6 mapping.
// Ensure failure UI always exposes actionable next step.
```

**Step 4: Re-run targeted tests**

Run: `flutter test test/features/pool/pool_page_test.dart test/features/pool/join_error_mapper_test.dart -r compact`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/pool/pool_page.dart lib/features/pool/pool_controller.dart lib/features/pool/join_error_mapper.dart test/features/pool/pool_page_test.dart test/features/pool/join_error_mapper_test.dart
git commit -m "feat(ui-s3): align pool lifecycle and failure recovery semantics"
```

**Step 6: Blue refactor verification**

Run: `flutter test test/features/pool/pool_page_test.dart test/features/pool/join_error_mapper_test.dart -r compact`
Expected: PASS after Blue refactor

---

### Task 4: P3-S4 设置可达性 + S5 同步异常可处理

**Files:**
- Modify: `lib/features/settings/settings_page.dart`
- Modify: `lib/features/cards/cards_page.dart`
- Modify: `lib/features/pool/pool_page.dart`
- Test: `test/features/settings/settings_page_test.dart`
- Test: `test/features/cards/cards_sync_navigation_test.dart`
- Test: `test/features/pool/pool_sync_interaction_test.dart`

**Step 1: Write failing tests (S4/S5 acceptance)**

```dart
testWidgets('from settings cards and pool are reachable in one action', ...);
testWidgets('sync error exposes retry/reconnect without blocking local work', ...);
```

**Step 2: Run tests to verify failures**

Run: `flutter test test/features/settings/settings_page_test.dart test/features/cards/cards_sync_navigation_test.dart test/features/pool/pool_sync_interaction_test.dart -r compact`
Expected: FAIL where one-step reachability or non-blocking handling mismatches

**Step 3: Minimal implementation**

```dart
// Enforce one-action route transitions from settings.
// Keep sync exception globally visible and actionable, non-blocking.
```

**Step 4: Re-run targeted tests**

Run: `flutter test test/features/settings/settings_page_test.dart test/features/cards/cards_sync_navigation_test.dart test/features/pool/pool_sync_interaction_test.dart -r compact`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/settings/settings_page.dart lib/features/cards/cards_page.dart lib/features/pool/pool_page.dart test/features/settings/settings_page_test.dart test/features/cards/cards_sync_navigation_test.dart test/features/pool/pool_sync_interaction_test.dart
git commit -m "feat(ui-s4s5): ensure settings reachability and actionable sync handling"
```

**Step 6: Blue refactor verification**

Run: `flutter test test/features/settings/settings_page_test.dart test/features/cards/cards_sync_navigation_test.dart test/features/pool/pool_sync_interaction_test.dart -r compact`
Expected: PASS after Blue refactor

---

### Task 5: Governance + Full Verification Gate

**Files:**
- Modify (if needed): `docs/specs/ui-interaction.md`
- Modify (if needed): `docs/specs/DIR.md`
- Modify (if needed): `docs/DIR.md`
- Test: `docs/standards/ui-interaction-governance.md`
- Test: `test/interaction_guard_test.dart`

**Step 1: Add failing guard test only if new spec clauses were added**

```dart
test('governance docs include new minimal clause', ...);
```

**Step 2: Run governance guards**

Run: `flutter test docs/standards/ui-interaction-governance.md test/interaction_guard_test.dart -r compact`
Expected: PASS

**Step 3: Run global verification**

Run: `flutter analyze`
Expected: PASS (No issues found)

Run: `flutter test`
Expected: PASS

**Step 4: Commit**

```bash
git add docs/specs/ui-interaction.md docs/specs/DIR.md docs/DIR.md docs/standards/ui-interaction-governance.md test/interaction_guard_test.dart
git commit -m "test(governance): enforce ui-spec guided implementation gates"
```
