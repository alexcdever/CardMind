input: 已批准的引导与全局返回策略统一设计（方案 A）
output: 可执行的任务化实施步骤，覆盖跨端 back 行为与退出确认
pos: 引导与主壳返回策略统一实施计划（修改需同步 DIR.md）
# Onboarding Back Navigation Unification Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a unified back-navigation policy so onboarding pool entry supports system-return back to onboarding, app shell uses two-step back-to-cards behavior, and cards root shows exit confirmation.

**Architecture:** Keep the existing single-shell architecture and apply back-policy handling at the shell boundary (`AppShellPage`) while preserving onboarding->pool stack behavior via `Navigator.push`. Do not introduce nested tab navigators or global routing services. Add widget tests first, implement minimal behavior, then refactor for readability without changing behavior.

**Tech Stack:** Flutter (Material), Dart, flutter_test, existing UI governance/doc guard tests

## 强制执行规则（TDD 红-绿-蓝）

- 本计划每个任务必须按 **Red -> Green -> Blue -> Commit** 执行。
- Red：先编写失败测试，并运行确认按预期失败。
- Green：以最小实现使测试通过，并运行确认通过。
- Blue：在不改变行为前提下重构，并复跑同一批测试。
- 仅当 Blue 阶段验证通过后才允许提交。

---

### Task 1: Lock onboarding -> pool system-back return behavior

**Files:**
- Modify: `test/features/onboarding/onboarding_page_test.dart`
- Modify: `lib/features/onboarding/onboarding_page.dart` (only if test exposes regression)

**Step 1: Write the failing test**

```dart
testWidgets('pool path can return to onboarding via system back', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: OnboardingPage()));

  await tester.tap(find.text('创建或加入数据池'));
  await tester.pumpAndSettle();
  expect(find.text('创建池'), findsOneWidget);

  await tester.pageBack();
  await tester.pumpAndSettle();
  expect(find.text('创建或加入数据池'), findsOneWidget);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/onboarding_page_test.dart -r compact`
Expected: FAIL if route push/replacement behavior breaks return path

**Step 3: Write minimal implementation**

```dart
OutlinedButton(
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PoolPage(state: PoolState.notJoined()),
      ),
    );
  },
  child: const Text('创建或加入数据池'),
)
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/onboarding_page_test.dart -r compact`
Expected: PASS

**Step 5: Blue refactor**

- Keep route creation readable (optional helper method), no behavior changes.

**Step 6: Commit**

```bash
git add test/features/onboarding/onboarding_page_test.dart lib/features/onboarding/onboarding_page.dart
git commit -m "test(onboarding): lock system-back return from pool path"
```

---

### Task 2: Add shell-level two-step back policy (non-cards -> cards)

**Files:**
- Modify: `test/app/app_shell_navigation_test.dart`
- Modify: `lib/app/navigation/app_shell_page.dart`

**Step 1: Write the failing test**

```dart
testWidgets('back on non-cards tab switches to cards first', (tester) async {
  final controller = AppShellController(initialSection: AppSection.pool);
  await tester.pumpWidget(MaterialApp(home: AppShellPage(controller: controller)));

  await tester.pageBack();
  await tester.pumpAndSettle();

  expect(controller.section, AppSection.cards);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/app/app_shell_navigation_test.dart -r compact`
Expected: FAIL because shell currently has no back intercept behavior

**Step 3: Write minimal implementation**

```dart
PopScope(
  canPop: false,
  onPopInvokedWithResult: (didPop, _) {
    if (didPop) return;
    if (_controller.section != AppSection.cards) {
      _controller.setSection(AppSection.cards);
      return;
    }
    _showExitConfirmDialog();
  },
  child: AdaptiveShell(...),
)
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/app/app_shell_navigation_test.dart -r compact`
Expected: PASS

**Step 5: Blue refactor**

- Extract back decision logic into private method for readability.

**Step 6: Commit**

```bash
git add test/app/app_shell_navigation_test.dart lib/app/navigation/app_shell_page.dart
git commit -m "feat(navigation): shell back switches non-cards tab to cards"
```

---

### Task 3: Add cards-root exit confirmation dialog behavior

**Files:**
- Modify: `test/app/app_shell_navigation_test.dart`
- Modify: `lib/app/navigation/app_shell_page.dart`

**Step 1: Write the failing tests**

```dart
testWidgets('back on cards shows exit confirmation dialog', (tester) async {
  final controller = AppShellController(initialSection: AppSection.cards);
  await tester.pumpWidget(MaterialApp(home: AppShellPage(controller: controller)));

  await tester.pageBack();
  await tester.pumpAndSettle();

  expect(find.text('是否退出应用？'), findsOneWidget);
  expect(find.text('是'), findsOneWidget);
  expect(find.text('否'), findsOneWidget);
});

testWidgets('selecting 否 closes confirmation and stays on cards', (tester) async {
  final controller = AppShellController(initialSection: AppSection.cards);
  await tester.pumpWidget(MaterialApp(home: AppShellPage(controller: controller)));

  await tester.pageBack();
  await tester.pumpAndSettle();
  await tester.tap(find.text('否'));
  await tester.pumpAndSettle();

  expect(controller.section, AppSection.cards);
  expect(find.text('是否退出应用？'), findsNothing);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/app/app_shell_navigation_test.dart -r compact`
Expected: FAIL because dialog behavior is not yet implemented

**Step 3: Write minimal implementation**

```dart
Future<void> _showExitConfirmDialog(BuildContext context) async {
  final shouldExit = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: const Text('是否退出应用？'),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('否')),
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('是')),
      ],
    ),
  );
  if (shouldExit == true) {
    SystemNavigator.pop();
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/app/app_shell_navigation_test.dart -r compact`
Expected: PASS

**Step 5: Blue refactor**

- Add dialog re-entry guard to prevent stacked dialogs.

**Step 6: Commit**

```bash
git add test/app/app_shell_navigation_test.dart lib/app/navigation/app_shell_page.dart
git commit -m "feat(navigation): confirm app exit on cards root back"
```

---

### Task 4: Sync governance docs for global back policy change

**Files:**
- Modify: `docs/plans/2026-02-27-ui-interaction-governance-design.md`
- Modify: `docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md`
- Modify: `docs/plans/2026-02-27-ui-interaction-release-gate.md`
- Test: `test/ui_interaction_governance_docs_test.dart`

**Step 1: Write the failing test update**

```dart
test('governance docs include shell two-step back and exit confirmation', () {
  final design = File('docs/plans/2026-02-27-ui-interaction-governance-design.md').readAsStringSync();
  expect(design, contains('主壳双段返回'));
  expect(design, contains('是否退出应用'));
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/ui_interaction_governance_docs_test.dart -r compact`
Expected: FAIL with missing navigation policy wording

**Step 3: Write minimal implementation**

```markdown
- S1/S4 跨端返回策略：系统返回在主壳内执行“非卡片先回卡片，卡片再二次确认退出”。
- 卡片列表根页返回需弹出“是否退出应用？”并提供“是/否”动作。
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/ui_interaction_governance_docs_test.dart -r compact`
Expected: PASS

**Step 5: Blue refactor**

- Deduplicate repeated wording across three docs while preserving required keywords.

**Step 6: Commit**

```bash
git add docs/plans/2026-02-27-ui-interaction-governance-design.md docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md docs/plans/2026-02-27-ui-interaction-release-gate.md test/ui_interaction_governance_docs_test.dart
git commit -m "docs(governance): codify shell back policy and exit confirmation"
```

---

### Task 5: Final verification and plan guard alignment

**Files:**
- Modify: `test/plan_tdd_blue_guard_test.dart`

**Step 1: Write the failing test update**

```dart
test('plan guard validates all current plan files', () {
  // expected docs/plans/*plan*.md count increases by 1
  expect(planFiles.length, 15);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/plan_tdd_blue_guard_test.dart -r compact`
Expected: FAIL with stale plan file count

**Step 3: Write minimal implementation**

```dart
expect(planFiles.length, 15, reason: 'Unexpected docs/plans/*plan*.md file count');
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/plan_tdd_blue_guard_test.dart -r compact`
Expected: PASS

**Step 5: Blue refactor**

- Keep count assertion and helper names consistent; no behavior changes.

**Step 6: Commit**

```bash
git add test/plan_tdd_blue_guard_test.dart docs/plans/2026-03-01-onboarding-back-navigation-unification-implementation-plan.md docs/plans/DIR.md
git commit -m "docs(plans): add onboarding back-navigation implementation plan"
```

---

## Full Verification Before Merge

Run in order:

1. `flutter test test/features/onboarding/onboarding_page_test.dart test/app/app_shell_navigation_test.dart -r compact`
2. `flutter test test/interaction_guard_test.dart test/ui_interaction_governance_docs_test.dart -r compact`
3. `flutter test test/plan_tdd_blue_guard_test.dart -r compact`
4. `flutter analyze`

Expected: all PASS with no new interaction-guard violations.
