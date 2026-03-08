input: 2026-03-09 UI 重设计设计稿与正式规格冲突修复需求
output: 可执行的主页重设计任务化实施计划（spec-first + TDD + 小步提交）
pos: UI 重设计实施计划（修改需同步 DIR.md）
# UI Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Align the Flutter UI with `docs/plans/2026-03-09-ui-redesign-design.md` by first updating formal specs, then rebuilding navigation, layout, sync feedback placement, and terminology from `shell` to `homepage` / `主页` under strict TDD.

**Architecture:** Treat `Home Page` as the only top-level container and keep `cards / pool / settings` as the sole primary domains. Reuse the current app-level navigation/controller split, but rename shell-facing code to homepage-facing terminology, localize sync feedback to the pool domain, and enforce the redesign through widget tests before each implementation change.

**Tech Stack:** Flutter (Dart), `flutter_test`, existing app/navigation/widgets under `lib/app/` and `lib/features/`, formal specs in `docs/specs/`

---

## Execution Rules (Mandatory)

1. Task 1 MUST be formal spec CRUD and consistency updates before any behavior change.
2. Every task MUST follow `Red -> Green -> Blue -> Commit`.
3. Every commit MUST keep a single intent and use standard prefixes such as `docs:` / `feat(scope):` / `test(scope):`.
4. All code-facing and test-facing naming introduced by this plan MUST use `homepage` / `主页` instead of `shell`.
5. If an ambiguity appears during execution, update formal specs first, then continue implementation.

## Worktree Requirement

Before executing Task 1 implementation work:

1. Create an isolated worktree from the current repository using `.worktrees/`.
2. Recommended branch name: `ui-redesign-homepage`.
3. Verify the baseline with focused Flutter tests before continuing.

Run:

```bash
git worktree add ".worktrees/ui-redesign-homepage" -b "ui-redesign-homepage"
flutter test test/app/app_shell_navigation_test.dart test/app/adaptive_shell_test.dart -r compact
```

Expected: worktree created successfully; current homepage/navigation baseline tests pass before new edits.

---

### Task 1: Update formal UI specs to match the redesign

**Files:**
- Modify: `docs/specs/ui-interaction.md`
- Modify: `docs/specs/DIR.md` (only if file semantics/index text needs refresh)
- Modify: `docs/DIR.md` (only if directory semantics change)
- Test: `docs/specs/ui-interaction.md`

**Step 1: Write the failing documentation guard test by identifying contradictory clauses**

Document these required replacements in `docs/specs/ui-interaction.md`:

```text
- Replace shell-facing wording with homepage-facing wording in navigation/state sections.
- Replace settings-page requirements that mention pool entry / troubleshooting sections with blank-placeholder semantics.
- Replace global sync prompt/banner semantics with pool-local feedback semantics.
- Replace platform routing/state wording so the top-level container is Home Page.
```

**Step 2: Verify RED by reading the current spec and confirming contradictions still exist**

Run:

```bash
rg -n "主壳|Shell|设置页 MUST 包含|池相关入口|全局同步异常提示|全局提示 -> 池异常处理入口" docs/specs/ui-interaction.md
```

Expected: matches are found, proving the formal spec still contradicts the redesign.

**Step 3: Write the minimal spec update**

Required outcomes in `docs/specs/ui-interaction.md`:

```text
- Top-level navigation semantics use Home Page / 主页 instead of shell.
- Primary navigation is exactly Cards / Pool / Settings, with Cards as default.
- Settings is a blank placeholder in this version and exposes no pool entry.
- Back from Pool/Settings returns to Cards; back from Cards root opens exit confirm.
- Sync feedback is local to the pool domain; no global sync banner/page remains.
- Card CRUD remains available regardless of sync failures.
```

**Step 4: Verify GREEN by re-running the contradiction search**

Run:

```bash
rg -n "设置页 MUST 包含|池相关入口|全局同步异常提示|全局提示 -> 池异常处理入口" docs/specs/ui-interaction.md
```

Expected: no matches for removed semantics.

Run:

```bash
rg -n "Home Page|主页|卡片 / 池 / 设置|空白占位|局部反馈|不阻断本地卡片读写" docs/specs/ui-interaction.md
```

Expected: matches found for new semantics.

**Step 5: Blue refactor**

Tighten wording only; do not expand scope beyond the redesign decisions already locked.

**Step 6: Re-run verification after Blue**

Run the two `rg` commands from Step 4 again.

Expected: PASS.

**Step 7: Commit**

```bash
git add docs/specs/ui-interaction.md docs/specs/DIR.md docs/DIR.md
git commit -m "docs: align ui interaction spec with homepage redesign"
```

---

### Task 2: Rename app shell terminology to homepage terminology in app code and tests

**Files:**
- Modify: `lib/app/app.dart`
- Rename: `lib/app/navigation/app_shell_page.dart` -> `lib/app/navigation/app_homepage_page.dart`
- Rename: `lib/app/navigation/app_shell_controller.dart` -> `lib/app/navigation/app_homepage_controller.dart`
- Rename: `lib/app/layout/adaptive_shell.dart` -> `lib/app/layout/adaptive_homepage_scaffold.dart`
- Modify: `lib/app/navigation/app_section.dart`
- Rename: `test/app/app_shell_navigation_test.dart` -> `test/app/app_homepage_navigation_test.dart`
- Rename: `test/app/adaptive_shell_test.dart` -> `test/app/adaptive_homepage_scaffold_test.dart`

**Step 1: Write failing tests by renaming test targets and expected widget/class names**

Create/update tests so they expect homepage naming:

```dart
testWidgets('app cold start shows homepage bottom nav on mobile', ...);
testWidgets('back on non-cards tab switches homepage to cards first', ...);
testWidgets('desktop homepage scaffold supports keyboard section switching', ...);
```

**Step 2: Verify RED**

Run:

```bash
flutter test test/app/app_homepage_navigation_test.dart test/app/adaptive_homepage_scaffold_test.dart -r compact
```

Expected: FAIL because renamed files/classes do not exist yet.

**Step 3: Minimal implementation**

Required code changes:

```text
- Rename AppShellPage -> AppHomepagePage.
- Rename AppShellController -> AppHomepageController.
- Rename AdaptiveShell -> AdaptiveHomepageScaffold.
- Update imports/usages in app and tests.
- Update file headers and comments so they refer to 主页/homepage rather than shell.
```

**Step 4: Verify GREEN**

Run:

```bash
flutter test test/app/app_homepage_navigation_test.dart test/app/adaptive_homepage_scaffold_test.dart -r compact
```

Expected: PASS.

**Step 5: Blue refactor**

Simplify any leftover shell wording in helper types or test descriptions without changing behavior.

**Step 6: Re-run verification after Blue**

Run the same focused test command again.

Expected: PASS.

**Step 7: Commit**

```bash
git add lib/app/app.dart lib/app/navigation/app_homepage_page.dart lib/app/navigation/app_homepage_controller.dart lib/app/layout/adaptive_homepage_scaffold.dart lib/app/navigation/app_section.dart test/app/app_homepage_navigation_test.dart test/app/adaptive_homepage_scaffold_test.dart
git commit -m "refactor(homepage): replace shell naming across app navigation"
```

---

### Task 3: Enforce homepage navigation semantics and remove cross-domain pool shortcut

**Files:**
- Modify: `lib/app/navigation/app_homepage_page.dart`
- Modify: `lib/features/pool/pool_page.dart`
- Test: `test/app/app_homepage_navigation_test.dart`
- Test: `test/features/pool/pool_page_test.dart`

**Step 1: Write the failing tests**

```dart
testWidgets('back from pool returns to cards homepage section', ...);
testWidgets('back from settings returns to cards homepage section', ...);
testWidgets('cards root back shows exit confirmation dialog', ...);
testWidgets('joined pool state does not expose go-to-cards shortcut', ...);
```

**Step 2: Verify RED**

Run:

```bash
flutter test test/app/app_homepage_navigation_test.dart test/features/pool/pool_page_test.dart -r compact
```

Expected: FAIL because the pool joined UI still exposes the cross-domain shortcut and homepage semantics are not fully locked by the renamed tests.

**Step 3: Minimal implementation**

Required code changes:

```text
- Keep cards/pool/settings as the only primary destinations.
- Ensure back from pool/settings switches section to cards.
- Preserve cards-root exit confirmation behavior.
- Remove the joined-state `去卡片` / go-to-cards shortcut from PoolPage.
- Keep users inside the pool domain after create/join succeeds.
```

**Step 4: Verify GREEN**

Run the same focused test command again.

Expected: PASS.

**Step 5: Blue refactor**

Extract tiny helpers for section handling only if duplication appears.

**Step 6: Re-run verification after Blue**

Run the same focused test command again.

Expected: PASS.

**Step 7: Commit**

```bash
git add lib/app/navigation/app_homepage_page.dart lib/features/pool/pool_page.dart test/app/app_homepage_navigation_test.dart test/features/pool/pool_page_test.dart
git commit -m "feat(homepage): enforce redesign navigation semantics"
```

---

### Task 4: Localize sync feedback to the pool domain and remove global banners from cards

**Files:**
- Modify: `lib/features/cards/cards_page.dart`
- Modify: `lib/features/pool/pool_page.dart`
- Modify: `lib/features/sync/sync_banner.dart`
- Test: `test/features/cards/cards_page_test.dart`
- Test: `test/features/pool/pool_sync_interaction_test.dart`

**Step 1: Write the failing tests**

```dart
testWidgets('cards page does not show sync banner in homepage redesign', ...);
testWidgets('pool page shows local sync feedback for joined state', ...);
testWidgets('pool join failure shows what happened and next action together', ...);
testWidgets('sync failure does not block card CRUD interactions', ...);
```

**Step 2: Verify RED**

Run:

```bash
flutter test test/features/cards/cards_page_test.dart test/features/pool/pool_sync_interaction_test.dart -r compact
```

Expected: FAIL because cards still renders `SyncBanner` and pool-local behavior is incomplete.

**Step 3: Minimal implementation**

Required code changes:

```text
- Remove SyncBanner from CardsPage.
- Keep or adapt SyncBanner usage only inside PoolPage.
- Ensure pool failure/recovery UI keeps feedback adjacent to retry/reconnect/next-action controls.
- Preserve local card list create/delete/restore behavior regardless of sync state.
```

**Step 4: Verify GREEN**

Run the same focused test command again.

Expected: PASS.

**Step 5: Blue refactor**

Refine sync copy and helper branching without reintroducing any global banner behavior.

**Step 6: Re-run verification after Blue**

Run the same focused test command again.

Expected: PASS.

**Step 7: Commit**

```bash
git add lib/features/cards/cards_page.dart lib/features/pool/pool_page.dart lib/features/sync/sync_banner.dart test/features/cards/cards_page_test.dart test/features/pool/pool_sync_interaction_test.dart
git commit -m "feat(pool-sync): localize sync feedback to pool domain"
```

---

### Task 5: Rebuild homepage layouts for mobile and desktop under the same semantics

**Files:**
- Modify: `lib/app/layout/adaptive_homepage_scaffold.dart`
- Modify: `lib/app/navigation/app_homepage_page.dart`
- Modify: `lib/features/cards/cards_page.dart`
- Modify: `lib/features/pool/pool_page.dart`
- Modify: `lib/features/settings/settings_page.dart`
- Test: `test/app/adaptive_homepage_scaffold_test.dart`
- Test: `test/app/app_homepage_navigation_test.dart`
- Test: `test/features/settings/settings_page_test.dart`

**Step 1: Write the failing tests**

```dart
testWidgets('mobile homepage uses top area plus content plus bottom tabs', ...);
testWidgets('desktop homepage uses left navigation plus work area', ...);
testWidgets('settings page stays blank but reachable from primary navigation', ...);
testWidgets('primary navigation exposes exactly cards pool settings', ...);
```

**Step 2: Verify RED**

Run:

```bash
flutter test test/app/adaptive_homepage_scaffold_test.dart test/app/app_homepage_navigation_test.dart test/features/settings/settings_page_test.dart -r compact
```

Expected: FAIL on at least one layout/blank-settings assertion.

**Step 3: Minimal implementation**

Required code changes:

```text
- Mobile keeps bottom tabs fixed to Cards / Pool / Settings.
- Desktop keeps left navigation as the primary destination switcher.
- Homepage page composes domain content under one top-level container.
- SettingsPage remains a blank placeholder with no pool affordance.
```

**Step 4: Verify GREEN**

Run the same focused test command again.

Expected: PASS.

**Step 5: Blue refactor**

Extract shared destination metadata/tokens if needed; do not change navigation semantics.

**Step 6: Re-run verification after Blue**

Run the same focused test command again.

Expected: PASS.

**Step 7: Commit**

```bash
git add lib/app/layout/adaptive_homepage_scaffold.dart lib/app/navigation/app_homepage_page.dart lib/features/cards/cards_page.dart lib/features/pool/pool_page.dart lib/features/settings/settings_page.dart test/app/adaptive_homepage_scaffold_test.dart test/app/app_homepage_navigation_test.dart test/features/settings/settings_page_test.dart
git commit -m "feat(homepage-ui): rebuild homepage layouts for cards pool settings"
```

---

### Task 6: Full verification and terminology cleanup guard

**Files:**
- Modify (if needed): `test/interaction_guard_test.dart`
- Test: `lib/**/*.dart`
- Test: `test/**/*.dart`

**Step 1: Add/adjust failing guard coverage for terminology cleanup if needed**

```dart
test('homepage navigation files no longer use shell terminology', ...);
```

**Step 2: Verify RED if new guard was added**

Run:

```bash
flutter test test/interaction_guard_test.dart -r compact
```

Expected: FAIL if leftover `shell` terminology still appears in guarded app/test files.

**Step 3: Minimal implementation**

Required outcomes:

```text
- Remove leftover shell-facing naming from touched app/test files.
- Keep any untouched historical plan/docs references outside current scope unchanged.
```

**Step 4: Run focused guard and full affected verification**

Run:

```bash
flutter test test/interaction_guard_test.dart -r compact
flutter analyze
flutter test -r compact
```

Expected: PASS.

**Step 5: Blue refactor**

Final cleanup only; no behavior changes.

**Step 6: Re-run verification after Blue**

Run the three commands from Step 4 again.

Expected: PASS.

**Step 7: Commit**

```bash
git add test/interaction_guard_test.dart lib test
git commit -m "test(homepage): keep redesign terminology and behavior green"
```

---

## Completion Gate

After Task 6 passes:

1. Run `git status --short` and confirm only intended files changed.
2. Report completed tasks, verification commands, and commit list.
3. Invoke `superpowers:finishing-a-development-branch` before any merge/PR action.
