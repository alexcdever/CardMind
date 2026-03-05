input: 桌面端池成功态到卡片列表导航闭环设计
output: 可执行的任务化实施步骤与验证命令
pos: 导航闭环修复实施计划（保持引导页规格不变）
# Desktop Pool-to-Cards Navigation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix desktop UX so users can reach the cards list in one action after pool creation/join success, without changing onboarding spec semantics.

**Architecture:** Reuse app-shell section switching as the single navigation authority. Add an explicit "go to cards" action in pool joined state and wire it through shell-level section change rather than local page push. Protect behavior with widget tests that assert one-step reachability and bidirectional navigation.

**Tech Stack:** Flutter (Dart), flutter_test, existing app shell/navigation structure

---

## Mandatory TDD Workflow

Every task MUST follow `Red -> Green -> Blue -> Commit`:

1. Red: write failing test and verify `Expected: FAIL`.
2. Green: implement minimal code and verify `Expected: PASS`.
3. Blue refactor: refactor without behavior changes and re-run tests.
4. Commit only after Blue verification passes.

---

### Task 1: Add one-step "go to cards" entry in PoolJoined UI

**Files:**
- Modify: `lib/features/pool/pool_page.dart`
- Modify: `lib/app/navigation/app_shell_page.dart` (if callback plumbing needed)
- Test: `test/features/pool/pool_page_test.dart`

**Step 1: Write the failing test**

```dart
testWidgets('joined pool state exposes one-step go-to-cards action', (tester) async {
  // expect button/action visible in PoolJoined view
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/pool/pool_page_test.dart -r compact`
Expected: FAIL because action is missing

**Step 3: Write minimal implementation**

```dart
// In PoolJoined section, add explicit action (e.g., "去卡片")
// and route through shell section switch callback.
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/pool/pool_page_test.dart -r compact`
Expected: PASS

**Step 5: Blue refactor verification**

Run: `flutter test test/features/pool/pool_page_test.dart -r compact`
Expected: PASS after refactor

**Step 6: Commit**

```bash
git add lib/features/pool/pool_page.dart lib/app/navigation/app_shell_page.dart test/features/pool/pool_page_test.dart
git commit -m "fix(desktop-nav): add one-step pool-joined to cards entry"
```

---

### Task 2: Verify one-step reachability via shell-level semantics

**Files:**
- Modify: `test/app/app_shell_navigation_test.dart`
- Modify: `lib/app/navigation/app_shell_controller.dart` (only if needed)

**Step 1: Write failing integration-oriented widget test**

```dart
testWidgets('after pool joined, go-to-cards action switches shell section to cards', (tester) async {
  // assert AppSection.cards reached in one action
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/app/app_shell_navigation_test.dart -r compact`
Expected: FAIL on section switch assertion

**Step 3: Minimal implementation**

```dart
// Ensure action dispatches shell section change,
// avoid local Navigator push hacks.
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/app/app_shell_navigation_test.dart -r compact`
Expected: PASS

**Step 5: Blue refactor verification**

Run: `flutter test test/app/app_shell_navigation_test.dart -r compact`
Expected: PASS after refactor

**Step 6: Commit**

```bash
git add test/app/app_shell_navigation_test.dart lib/app/navigation/app_shell_controller.dart
git commit -m "test(desktop-nav): enforce shell-level one-step pool-to-cards reachability"
```

---

### Task 3: Guard regression + full verification

**Files:**
- Modify (if needed): `docs/specs/ui-interaction.md` (only if unavoidable ambiguity discovered)
- Test: `docs/specs/ui-interaction.md`
- Test: `test/interaction_guard_test.dart`

**Step 1: Add failing guard assertion only if new clause added**

```dart
test('ui-interaction spec contains pool-joined to cards one-step reachability clause', () {
  // only if spec text changed
});
```

**Step 2: Run guard tests**

Run: `flutter test test/interaction_guard_test.dart test/interaction_guard_test.dart -r compact`
Expected: PASS

**Step 3: Run analyzer and full tests**

Run: `flutter analyze`
Expected: PASS

Run: `flutter test`
Expected: PASS

**Step 4: Commit**

```bash
git add docs/specs/ui-interaction.md docs/specs/ui-interaction.md test/interaction_guard_test.dart
git commit -m "test(governance): keep desktop pool-to-cards navigation closure green"
```
