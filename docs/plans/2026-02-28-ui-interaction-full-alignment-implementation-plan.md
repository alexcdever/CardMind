input: 已批准的 S1-S5 全量对齐设计与治理约束
output: 可执行的任务化实施步骤与验证命令
pos: UI 交互全量对齐实施计划（修改需同步 DIR.md）
# UI Interaction Full Alignment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deliver one-pass S1~S5 UI interaction alignment for CardMind with strict gate compliance (`flutter analyze`, full tests, governance guards, and doc checks all green).

**Architecture:** Keep the existing Flutter shell and feature modules, then close gaps by scenario (S1 to S5): onboarding split, card-note CRUD, pool CRUD/workflows, settings tab reachability, and global sync exception handling. Use TDD in small increments: add/adjust one failing test, implement minimal behavior, rerun targeted tests, then move to next slice.

**Tech Stack:** Flutter (Material 3), Dart, flutter_test, existing governance/doc gate scripts

---

### Task 1: Baseline S1~S5 and gate gaps

**Files:**
- Modify: `docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md`
- Modify: `docs/plans/2026-02-27-ui-interaction-release-gate.md`
- Test: `test/ui_interaction_governance_docs_test.dart`

**Step 1: Write the failing test update for clarified S2/S3/S4 wording**

```dart
test('acceptance matrix reflects card-note CRUD and pool CRUD scope', () {
  // assert doc text includes:
  // - S2: 卡片笔记增删改查
  // - S3: 数据池增删改查与流程动作
  // - S4: 设置页通过 Tab 可切换到卡片/池
});
```

**Step 2: Run doc governance test to verify it fails first**

Run: `flutter test test/ui_interaction_governance_docs_test.dart -r compact`
Expected: FAIL with missing/old wording assertions

**Step 3: Apply minimal doc edits to reflect approved design language**

```markdown
- S2 卡片笔记管理：增删改查
- S3 池管理：增删改查 + 创建/加入/审批/退出
- S4 设置：Tab 可一步切换至卡片页和池页
```

**Step 4: Re-run doc governance test**

Run: `flutter test test/ui_interaction_governance_docs_test.dart -r compact`
Expected: PASS

**Step 5: Commit**

```bash
git add docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md docs/plans/2026-02-27-ui-interaction-release-gate.md test/ui_interaction_governance_docs_test.dart
git commit -m "docs(governance): align S2-S4 acceptance wording with approved design"
```

---

### Task 2: Enforce settings-page tab navigation reachability (S4)

**Files:**
- Modify: `lib/app/layout/adaptive_shell.dart`
- Modify: `lib/features/settings/settings_page.dart`
- Test: `test/features/settings/settings_page_test.dart`
- Test: `test/app/adaptive_shell_test.dart`

**Step 1: Write failing tests for tab switching from settings**

```dart
testWidgets('from settings, tab switches to cards in one action', (tester) async {
  // open shell with settings selected
  // tap cards tab
  // expect cards marker visible
});

testWidgets('from settings, tab switches to pool in one action', (tester) async {
  // open shell with settings selected
  // tap pool tab
  // expect pool marker visible
});
```

**Step 2: Run targeted tests to verify failure**

Run: `flutter test test/features/settings/settings_page_test.dart test/app/adaptive_shell_test.dart -r compact`
Expected: FAIL for missing navigation callback behavior

**Step 3: Implement minimal callback wiring for `BottomNavigationBar` and `NavigationRail`**

```dart
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key, required this.section, required this.child, required this.onSectionChanged});
  final ValueChanged<AppSection> onSectionChanged;
  // pass onTap / onDestinationSelected -> onSectionChanged(AppSection.values[index])
}
```

**Step 4: Re-run targeted tests**

Run: `flutter test test/features/settings/settings_page_test.dart test/app/adaptive_shell_test.dart -r compact`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/app/layout/adaptive_shell.dart lib/features/settings/settings_page.dart test/features/settings/settings_page_test.dart test/app/adaptive_shell_test.dart
git commit -m "feat(ui): make settings-to-cards-pool tab switching one-step"
```

---

### Task 3: Close S2 card-note CRUD behavior and assertions

**Files:**
- Modify: `lib/features/cards/cards_page.dart`
- Modify: `lib/features/editor/editor_page.dart`
- Modify: `lib/features/editor/editor_controller.dart`
- Test: `test/features/cards/cards_page_test.dart`
- Test: `test/features/editor/editor_page_test.dart`

**Step 1: Add failing tests for CRUD-visible outcomes**

```dart
testWidgets('create note opens editor and save feedback is visible', (tester) async {
  // tap add -> editor
  // enter content -> save
  // expect "本地已保存" visible
});

testWidgets('delete or restore action changes list state', (tester) async {
  // invoke delete/restore action
  // assert list item visibility/state text changes
});
```

**Step 2: Run targeted tests and confirm failures**

Run: `flutter test test/features/cards/cards_page_test.dart test/features/editor/editor_page_test.dart -r compact`
Expected: FAIL for missing delete/restore or save-state assertions

**Step 3: Implement minimal CRUD UI state and leave-guard completeness**

```dart
// cards_page.dart
// provide deterministic in-memory list state for create/delete/restore/search assertions

// editor_page.dart
// keep save CTA and explicit "本地已保存" state text
// keep leave guard: 保存并离开 / 放弃更改 / 取消
```

**Step 4: Re-run targeted tests**

Run: `flutter test test/features/cards/cards_page_test.dart test/features/editor/editor_page_test.dart -r compact`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/cards/cards_page.dart lib/features/editor/editor_page.dart lib/features/editor/editor_controller.dart test/features/cards/cards_page_test.dart test/features/editor/editor_page_test.dart
git commit -m "feat(cards): complete note CRUD interaction coverage for S2"
```

---

### Task 4: Expand S3 pool CRUD/workflow coverage including recovery

**Files:**
- Modify: `lib/features/pool/pool_page.dart`
- Modify: `lib/features/pool/pool_controller.dart`
- Modify: `lib/features/pool/pool_state.dart`
- Test: `test/features/pool/pool_page_test.dart`

**Step 1: Add failing tests for pool CRUD + workflow transitions**

```dart
testWidgets('approve/reject updates pending list with observable result', (tester) async {
  // tap approve or reject
  // expect item removed on success OR retained with error on failure
});

testWidgets('exit pool partial cleanup shows retry action', (tester) async {
  // simulate partial fail
  // expect retry cleanup action visible
});
```

**Step 2: Run targeted pool tests to verify failures**

Run: `flutter test test/features/pool/pool_page_test.dart -r compact`
Expected: FAIL for missing approval/partial-cleanup behavior

**Step 3: Implement minimal deterministic workflow state transitions**

```dart
// pool_state.dart: include joined/pending/error/partial-cleanup variants as needed
// pool_page.dart: render action buttons with non-empty callbacks and stable text keys
```

**Step 4: Re-run pool tests**

Run: `flutter test test/features/pool/pool_page_test.dart -r compact`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/pool/pool_page.dart lib/features/pool/pool_controller.dart lib/features/pool/pool_state.dart test/features/pool/pool_page_test.dart
git commit -m "feat(pool): complete CRUD workflow interactions and recovery states"
```

---

### Task 5: Complete join-error mapping UX actions (S3 failure branch)

**Files:**
- Modify: `lib/features/pool/join_error_mapper.dart`
- Modify: `lib/features/pool/pool_page.dart`
- Test: `test/features/pool/join_error_mapper_test.dart`
- Test: `test/features/pool/pool_page_test.dart`

**Step 1: Add failing tests for all 7 error codes with next-step actions**

```dart
for (final code in [
  'POOL_NOT_FOUND',
  'INVALID_POOL_HASH',
  'INVALID_KEY_HASH',
  'ADMIN_OFFLINE',
  'REQUEST_TIMEOUT',
  'REJECTED_BY_ADMIN',
  'ALREADY_MEMBER',
]) {
  test('maps $code to readable message and action', () {
    final mapped = mapJoinError(code);
    expect(mapped.message.isNotEmpty, isTrue);
    expect(mapped.primaryActionLabel.isNotEmpty, isTrue);
  });
}
```

**Step 2: Run targeted tests to verify failures**

Run: `flutter test test/features/pool/join_error_mapper_test.dart test/features/pool/pool_page_test.dart -r compact`
Expected: FAIL for unmapped codes or missing action labels

**Step 3: Implement full mapping and UI action binding**

```dart
class JoinErrorUiModel {
  final String message;
  final String primaryActionLabel;
  final JoinAction action;
}

JoinErrorUiModel mapJoinError(String code) { ... }
```

**Step 4: Re-run targeted tests**

Run: `flutter test test/features/pool/join_error_mapper_test.dart test/features/pool/pool_page_test.dart -r compact`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/pool/join_error_mapper.dart lib/features/pool/pool_page.dart test/features/pool/join_error_mapper_test.dart test/features/pool/pool_page_test.dart
git commit -m "feat(pool): map all join error codes to actionable UX"
```

---

### Task 6: Ensure S5 global sync exception is actionable and non-blocking

**Files:**
- Modify: `lib/features/sync/sync_banner.dart`
- Modify: `lib/features/cards/cards_page.dart`
- Test: `test/features/sync/sync_banner_test.dart`
- Test: `test/features/cards/cards_sync_navigation_test.dart`

**Step 1: Add failing tests for actionability + non-blocking edit flow**

```dart
testWidgets('sync error banner has view action that navigates to handling page', (tester) async {
  // tap view
  // assert pool error handling page appears
});

testWidgets('sync error does not block creating/editing note', (tester) async {
  // with error status, tap add and enter editor
  // expect editor still reachable
});
```

**Step 2: Run targeted tests to confirm failures**

Run: `flutter test test/features/sync/sync_banner_test.dart test/features/cards/cards_sync_navigation_test.dart -r compact`
Expected: FAIL if action or non-blocking guarantee is incomplete

**Step 3: Implement minimal banner and cards-page behavior updates**

```dart
if (status.kind == SyncStatusKind.error) {
  return MaterialBanner(
    content: Text(messageFor(status.code)),
    actions: [TextButton(onPressed: onView, child: const Text('查看'))],
  );
}
```

**Step 4: Re-run targeted tests**

Run: `flutter test test/features/sync/sync_banner_test.dart test/features/cards/cards_sync_navigation_test.dart -r compact`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/sync/sync_banner.dart lib/features/cards/cards_page.dart test/features/sync/sync_banner_test.dart test/features/cards/cards_sync_navigation_test.dart
git commit -m "fix(sync): make global error feedback actionable without blocking local flow"
```

---

### Task 7: Run interaction guard and remove any invalid handlers

**Files:**
- Modify: `lib/**/*.dart` (only files flagged by guard)
- Test: `test/interaction_guard_test.dart`

**Step 1: Run guard test to detect violations**

Run: `flutter test test/interaction_guard_test.dart -r compact`
Expected: FAIL if any `onPressed: () {}` / `onTap: () {}` / unqualified `onPressed: null` exists

**Step 2: Fix one violation at a time with explicit behavior or documented disabled rationale**

```dart
// bad
onPressed: () {},

// good
onPressed: _handleJoinRetry,
```

**Step 3: Re-run guard test**

Run: `flutter test test/interaction_guard_test.dart -r compact`
Expected: PASS

**Step 4: Commit**

```bash
git add lib test/interaction_guard_test.dart
git commit -m "chore(ui): satisfy interaction guard constraints"
```

---

### Task 8: Full gate run and final verification

**Files:**
- Modify: only files needed to fix final gate failures

**Step 1: Run analyzer**

Run: `flutter analyze`
Expected: PASS (no errors)

**Step 2: Run full tests**

Run: `flutter test`
Expected: PASS

**Step 3: Run governance docs and interaction guards explicitly**

Run: `flutter test test/ui_interaction_governance_docs_test.dart && flutter test test/interaction_guard_test.dart`
Expected: PASS

**Step 4: Run fractal doc check**

Run: `dart run tool/fractal_doc_check.dart --base HEAD~1`
Expected: PASS

**Step 5: Final commit (if fixes were required in this task)**

```bash
git add <files-fixed-during-gate-run>
git commit -m "chore(release): clear full UI interaction gates for S1-S5"
```
