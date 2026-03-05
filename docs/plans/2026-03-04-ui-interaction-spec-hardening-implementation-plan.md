input: 已批准的 UI 规格补强设计（A11y/性能预算/i18n）
output: 可执行的任务化实施步骤与验证命令
pos: UI 交互规格补强实施计划（修改需同步 DIR.md）
# UI Interaction Spec Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement UI behavior and tests so the newly hardened UI spec (A11y, relaxed performance feedback, i18n resilience) is reflected in observable app behavior.

**Architecture:** Keep existing page/controller boundaries and add minimal, test-driven behavior slices per scenario. Prioritize observable outcomes over internal refactors: keyboard/focus reachability, visible progress feedback timing, and text-expansion-safe layouts. Reuse existing shell/pages/tests and avoid introducing new framework dependencies.

**Tech Stack:** Flutter (Material 3), Dart, flutter_test, existing governance guards

---

## 强制执行规则（TDD 红-绿-蓝）

- 本计划每个任务必须按 **Red -> Green -> Blue -> Commit** 执行。
- Red：先编写或调整失败测试，并运行确认按预期失败。
- Green：以最小实现使测试通过，并运行确认通过。
- Blue：在不改变行为前提下重构，复跑同一批测试后再继续。
- 仅当 Blue 阶段验证通过后才允许提交。

---

### Task 1: 补齐桌面端键盘可达与焦点可见（A11y）

**Files:**
- Modify: `lib/app/layout/adaptive_shell.dart`
- Modify: `lib/features/settings/settings_page.dart`
- Test: `test/app/adaptive_shell_test.dart`
- Test: `test/features/settings/settings_page_test.dart`

**Step 1: Write the failing tests**

```dart
testWidgets('desktop shell supports keyboard section switching', (tester) async {
  // Send keyboard navigation and Enter, expect section marker changes.
});

testWidgets('focus indicator remains visible on primary actions', (tester) async {
  // Move focus via Tab, expect focused action has visible focus state.
});
```

**Step 2: Run targeted tests to verify failure**

Run: `flutter test test/app/adaptive_shell_test.dart test/features/settings/settings_page_test.dart -r compact`
Expected: FAIL for missing/insufficient keyboard-focus behavior

**Step 3: Implement minimal keyboard/focus behavior**

```dart
// Wire keyboard shortcuts/focus traversal for shell destinations.
// Ensure focused controls use visible focus style.
```

**Step 4: Re-run targeted tests**

Run: `flutter test test/app/adaptive_shell_test.dart test/features/settings/settings_page_test.dart -r compact`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/app/layout/adaptive_shell.dart lib/features/settings/settings_page.dart test/app/adaptive_shell_test.dart test/features/settings/settings_page_test.dart
git commit -m "feat(ui-a11y): add keyboard reachability and visible focus states"
```

---

### Task 2: 统一关键动作的处理中反馈（宽松性能预算）

**Files:**
- Modify: `lib/features/editor/editor_controller.dart`
- Modify: `lib/features/editor/editor_page.dart`
- Modify: `lib/features/pool/pool_controller.dart`
- Modify: `lib/features/pool/pool_page.dart`
- Test: `test/features/editor/editor_page_test.dart`
- Test: `test/features/pool/pool_page_test.dart`

**Step 1: Write failing tests for visible progress feedback**

```dart
testWidgets('save action shows in-progress feedback before completion', (tester) async {
  // Trigger save, expect progress text/indicator visible.
});

testWidgets('join/exit pool flow keeps visible pending state', (tester) async {
  // Trigger request, expect pending feedback and recoverable action.
});
```

**Step 2: Run tests to verify failure**

Run: `flutter test test/features/editor/editor_page_test.dart test/features/pool/pool_page_test.dart -r compact`
Expected: FAIL for missing pending/processing feedback

**Step 3: Implement minimal pending-state UI**

```dart
// Surface explicit processing states in editor and pool flows.
// Keep cancel/back path available for long-running network operations.
```

**Step 4: Re-run targeted tests**

Run: `flutter test test/features/editor/editor_page_test.dart test/features/pool/pool_page_test.dart -r compact`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/editor/editor_controller.dart lib/features/editor/editor_page.dart lib/features/pool/pool_controller.dart lib/features/pool/pool_page.dart test/features/editor/editor_page_test.dart test/features/pool/pool_page_test.dart
git commit -m "feat(ui-feedback): ensure visible processing states for key actions"
```

---

### Task 3: 文案伸缩与布局韧性（i18n）

**Files:**
- Modify: `lib/features/cards/cards_page.dart`
- Modify: `lib/features/editor/editor_page.dart`
- Modify: `lib/features/pool/pool_page.dart`
- Test: `test/features/cards/cards_page_test.dart`
- Test: `test/features/editor/editor_page_test.dart`
- Test: `test/features/pool/pool_page_test.dart`

**Step 1: Write failing layout-resilience tests with long text**

```dart
testWidgets('primary actions remain reachable with long labels', (tester) async {
  // Inject long localized-like labels; verify action remains tappable/visible.
});

testWidgets('error/help text wraps without hiding critical controls', (tester) async {
  // Render long message; expect controls still reachable.
});
```

**Step 2: Run targeted tests to verify failure**

Run: `flutter test test/features/cards/cards_page_test.dart test/features/editor/editor_page_test.dart test/features/pool/pool_page_test.dart -r compact`
Expected: FAIL in at least one page for overflow/reachability

**Step 3: Implement minimal responsive text handling**

```dart
// Prefer wrapping and flexible layout containers.
// Keep primary actions in stable, reachable zones.
```

**Step 4: Re-run targeted tests**

Run: `flutter test test/features/cards/cards_page_test.dart test/features/editor/editor_page_test.dart test/features/pool/pool_page_test.dart -r compact`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/cards/cards_page.dart lib/features/editor/editor_page.dart lib/features/pool/pool_page.dart test/features/cards/cards_page_test.dart test/features/editor/editor_page_test.dart test/features/pool/pool_page_test.dart
git commit -m "feat(ui-i18n): harden layouts for long localized content"
```

---

### Task 4: 守卫测试与全量门禁收敛

**Files:**
- Modify: `docs/specs/ui-interaction.md` (only if needed for new clause assertions)
- Modify: `test/interaction_guard_test.dart` (only if needed)

**Step 1: Add/adjust failing guard tests for new spec clauses (if missing)**

```dart
test('ui-interaction spec includes A11y/performance/i18n acceptance clauses', () {
  // assert new sections and key lines exist
});
```

**Step 2: Run guard tests first**

Run: `flutter test test/interaction_guard_test.dart test/interaction_guard_test.dart -r compact`
Expected: PASS (or FAIL then fix minimal gaps)

**Step 3: Run full verification suite**

Run: `flutter analyze`
Expected: PASS (No issues found)

Run: `flutter test`
Expected: PASS

**Step 4: Commit**

```bash
git add docs/specs/ui-interaction.md test/interaction_guard_test.dart
git commit -m "test(ui-governance): enforce hardened ui spec guard coverage"
```
