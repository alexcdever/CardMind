input: 已批准的“移除引导页并改为卡片列表直达”设计文档
output: 可执行的 TDD 任务分解、文件清单、验证命令与提交建议
pos: 首屏入口与池入口收敛改造实施计划（含规格、测试、文档索引同步）
# Remove Onboarding Direct Cards Entry Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove onboarding as the app entry, make cards list the default first screen, and keep pool create/join entry only in the Pool tab with updated copy.

**Architecture:** Apply a spec-first change: update UI spec and acceptance wording first, then switch app home to `AppShellPage` and delete onboarding module and tests. Keep shell navigation semantics and pool state machine intact, only refine unjoined pool copy for discoverability.

**Tech Stack:** Flutter (Dart), flutter_test, docs/specs markdown governance

---

## Mandatory TDD Workflow

Every task MUST follow `Red -> Green -> Blue -> Commit`:

1. Red: write failing test/guard and verify `Expected: FAIL`.
2. Green: implement minimal changes and verify `Expected: PASS`.
3. Blue: refactor without behavior change and re-run targeted tests.
4. Commit only after Blue verification passes.

---

### Task 1: Update UI spec from onboarding split to direct cards entry

**Files:**
- Modify: `docs/specs/ui-interaction.md`
- Modify (if referenced wording requires sync): `docs/specs/ui-interaction.md`
- Test: `docs/standards/ui-interaction-governance.md`

**Step 1: Write failing governance doc test updates**

```dart
test('design doc uses direct cards entry wording instead of onboarding split', () {
  final content = File('docs/specs/ui-interaction.md').readAsStringSync();
  expect(content, contains('首屏默认卡片')); // new wording
  expect(content.contains('首屏 MUST 显示两个主动作：`先本地使用`、`创建/加入池`'), isFalse);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test docs/standards/ui-interaction-governance.md -r compact`
Expected: FAIL because spec still contains onboarding-first clauses

**Step 3: Apply minimal spec edits**

```md
- Remove S1 onboarding-first clauses and onboarding route mapping row
+ Add direct-cards-first constraints and pool-entry-in-tab wording
```

**Step 4: Run test to verify it passes**

Run: `flutter test docs/standards/ui-interaction-governance.md -r compact`
Expected: PASS

**Step 5: Blue refactor verification**

Run: `flutter test docs/standards/ui-interaction-governance.md -r compact`
Expected: PASS after wording cleanup/refactor

**Step 6: Commit**

```bash
git add docs/specs/ui-interaction.md docs/standards/ui-interaction-governance.md docs/specs/ui-interaction.md
git commit -m "docs(ui-spec): switch first-screen contract to direct cards entry"
```

---

### Task 2: Switch app home to shell and lock default cards tab behavior

**Files:**
- Modify: `lib/app/app.dart`
- Modify: `test/widget_test.dart`
- Modify: `test/app/app_shell_navigation_test.dart`
- Modify: `lib/DIR.md`
- Modify: `lib/app/DIR.md` (only if file role text changes)

**Step 1: Write failing app-entry tests**

```dart
testWidgets('app boots directly into shell cards section', (tester) async {
  await tester.pumpWidget(const CardMindApp());
  expect(find.text('搜索卡片'), findsOneWidget);
  expect(find.text('先本地使用'), findsNothing);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart test/app/app_shell_navigation_test.dart -r compact`
Expected: FAIL because app home is still onboarding

**Step 3: Minimal implementation**

```dart
// app.dart
home: const AppShellPage();
```

Also update file headers and `DIR.md` entries to reflect new entry semantics.

**Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart test/app/app_shell_navigation_test.dart -r compact`
Expected: PASS

**Step 5: Blue refactor verification**

Run: `flutter test test/widget_test.dart test/app/app_shell_navigation_test.dart -r compact`
Expected: PASS after comment/header cleanup

**Step 6: Commit**

```bash
git add lib/app/app.dart lib/DIR.md lib/app/DIR.md test/widget_test.dart test/app/app_shell_navigation_test.dart
git commit -m "feat(app-entry): boot into shell cards by default"
```

---

### Task 3: Remove onboarding module and its obsolete tests

**Files:**
- Delete: `lib/features/onboarding/onboarding_page.dart`
- Delete: `lib/features/onboarding/onboarding_controller.dart`
- Delete: `lib/features/onboarding/onboarding_state.dart`
- Modify/Delete: `lib/features/onboarding/DIR.md` (delete if directory removed, otherwise empty-directory handling)
- Delete: `test/features/onboarding/onboarding_page_test.dart`
- Modify: `lib/DIR.md`
- Modify: `test/DIR.md`

**Step 1: Write failing reference guard test**

```dart
test('app code no longer references onboarding module', () {
  final app = File('lib/app/app.dart').readAsStringSync();
  expect(app.contains('features/onboarding'), isFalse);
});
```

**Step 2: Run test to verify it fails (if references remain)**

Run: `flutter test test/widget_test.dart -r compact`
Expected: FAIL before reference cleanup (or compile error after partial deletion)

**Step 3: Minimal implementation**

```text
Delete onboarding files and onboarding widget test; fix imports/usages.
Update DIR.md indexes to remove onboarding entries.
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart test/app/app_shell_navigation_test.dart -r compact`
Expected: PASS

**Step 5: Blue refactor verification**

Run: `flutter test test/widget_test.dart test/app/app_shell_navigation_test.dart -r compact`
Expected: PASS after dead-reference cleanup

**Step 6: Commit**

```bash
git add -A
git commit -m "refactor(onboarding): remove obsolete onboarding flow and tests"
```

---

### Task 4: Update Pool unjoined copy without changing behavior

**Files:**
- Modify: `lib/features/pool/pool_page.dart`
- Modify: `test/features/pool/pool_page_test.dart`
- Modify: `lib/features/pool/DIR.md` (if page responsibility wording changes)

**Step 1: Write failing copy test**

```dart
testWidgets('pool unjoined state shows create/join guidance copy', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: PoolPage(state: PoolState.notJoined())));
  expect(find.textContaining('在这里创建或加入数据池'), findsOneWidget);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/pool/pool_page_test.dart -r compact`
Expected: FAIL because new guidance copy is missing

**Step 3: Minimal implementation**

```dart
// In PoolNotJoined branch, add visible guidance text above actions.
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/pool/pool_page_test.dart -r compact`
Expected: PASS

**Step 5: Blue refactor verification**

Run: `flutter test test/features/pool/pool_page_test.dart -r compact`
Expected: PASS after layout cleanup

**Step 6: Commit**

```bash
git add lib/features/pool/pool_page.dart lib/features/pool/DIR.md test/features/pool/pool_page_test.dart
git commit -m "feat(pool-ui): clarify unjoined tab copy for create-or-join"
```

---

### Task 5: Full regression, docs index sync, and final verification

**Files:**
- Modify: `docs/plans/DIR.md` (ensure both new design and this plan indexed)
- Modify: `test/DIR.md` / `lib/DIR.md` (final consistency pass)

**Step 1: Run fractal doc checker**

Run: `遵循 docs/standards/documentation.md 与 docs/standards/tdd.md`
Expected: PASS

**Step 2: Run focused tests**

Run: `flutter test test/widget_test.dart test/app/app_shell_navigation_test.dart test/features/pool/pool_page_test.dart docs/standards/ui-interaction-governance.md -r compact`
Expected: PASS

**Step 3: Run full checks**

Run: `flutter analyze`
Expected: PASS

Run: `flutter test`
Expected: PASS

**Step 4: Commit final governance sync**

```bash
git add docs/plans/DIR.md lib/DIR.md test/DIR.md
git commit -m "docs(governance): sync indexes after onboarding removal"
```

---

## Execution Notes

- Keep commits single-intent and in task order.
- Avoid introducing new navigation architecture.
- Preserve shell back behavior and pool error recovery behavior exactly.
- If any guard test conflicts with updated spec wording, update guard tests in same task as spec edit.
