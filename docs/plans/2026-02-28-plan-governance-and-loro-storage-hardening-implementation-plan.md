# Plan Governance and Loro Storage Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enforce Red-Green-Blue execution standards across all `docs/plans/*plan*.md` and replace in-memory storage stand-ins with real file-backed Loro + SQLite read/write split behavior.

**Architecture:** Execute in two phases. Phase A normalizes plan-document governance with automated guards so future plans cannot regress to Red/Green-only wording. Phase B hardens runtime storage by implementing file-backed `LoroDoc` lifecycle (snapshot/update, 4MB compaction rule) and projecting write-side events into SQLite read models.

**Tech Stack:** Flutter, Dart, flutter_test, dart:io, sqlite3/Drift (repo standard), flutter_rust_bridge integration surface, Loro document persistence

## Mandatory Execution Rule (TDD Red-Green-Blue)

- Every task in this plan MUST be executed as **Red -> Green -> Blue -> Commit**.
- Red: write/adjust failing tests first and run to confirm expected failure.
- Green: implement the minimal code and run tests to confirm pass.
- Blue: refactor for maintainability without behavior change, rerun the same tests, then continue.
- Commit is allowed only after Blue verification passes.

---

### Task 1: Add plan-governance guard for `docs/plans/*plan*.md`

**Files:**
- Create: `test/plan_tdd_blue_guard_test.dart`
- Modify: `test/ui_interaction_governance_docs_test.dart`

**Step 1: Write the failing test**

```dart
test('every docs/plans/*plan*.md includes red-green-blue rule', () {
  // scan docs/plans for *plan*.md
  // assert each file includes: Red, Green, Blue, and Blue-before-Commit wording
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/plan_tdd_blue_guard_test.dart -r compact`
Expected: FAIL with missing Blue rule in historical plan files

**Step 3: Write minimal implementation**

```dart
final planFiles = Directory('docs/plans')
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('plan.md') || f.path.endsWith('implementation-plan.md'));
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/plan_tdd_blue_guard_test.dart -r compact`
Expected: PASS

**Step 5: Blue refactor and verify**

Run: `flutter test test/plan_tdd_blue_guard_test.dart test/ui_interaction_governance_docs_test.dart -r compact`
Expected: PASS after extracting shared scan/match helpers and cleanup

**Step 6: Commit**

```bash
git add test/plan_tdd_blue_guard_test.dart test/ui_interaction_governance_docs_test.dart
git commit -m "test(governance): enforce red-green-blue in all plan docs"
```

---

### Task 2: Backfill Red-Green-Blue rule block in all historical `*plan*.md`

**Files:**
- Modify: `docs/plans/*plan*.md` (all matched files)
- Modify: `docs/plans/DIR.md`

**Step 1: Write the failing test case list expectation**

```dart
test('plan guard validates all current plan files', () {
  // assert known file count and all pass regex checks
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/plan_tdd_blue_guard_test.dart -r compact`
Expected: FAIL listing plan files missing Blue rule block

**Step 3: Write minimal implementation**

```markdown
## Mandatory Execution Rule (TDD Red-Green-Blue)
- Every task in this plan MUST be executed as **Red -> Green -> Blue -> Commit**.
- ...
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/plan_tdd_blue_guard_test.dart -r compact`
Expected: PASS

**Step 5: Blue refactor and verify**

Run: `flutter test test/plan_tdd_blue_guard_test.dart && dart run tool/fractal_doc_check.dart --base HEAD~1`
Expected: PASS after wording normalization and duplicate-section cleanup

**Step 6: Commit**

```bash
git add docs/plans test/plan_tdd_blue_guard_test.dart
git commit -m "docs(plans): backfill red-green-blue governance across plan documents"
```

---

### Task 3: Implement file-backed LoroDoc store with required path layout

**Files:**
- Create: `lib/features/shared/storage/loro_doc_path.dart`
- Create: `lib/features/shared/storage/loro_doc_store.dart`
- Test: `test/features/shared/storage/loro_doc_path_test.dart`
- Test: `test/features/shared/storage/loro_doc_store_test.dart`

**Step 1: Write the failing test**

```dart
test('uses data/loro/{kind}/{uuidv7}/{snapshot|update}', () {
  final paths = LoroDocPath.forEntity(kind: 'card-note', id: '019...');
  expect(paths.snapshot.path, contains('data/loro/card-note/019.../snapshot'));
  expect(paths.update.path, contains('data/loro/card-note/019.../update'));
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/shared/storage/loro_doc_path_test.dart test/features/shared/storage/loro_doc_store_test.dart -r compact`
Expected: FAIL with missing path/store types

**Step 3: Write minimal implementation**

```dart
class LoroDocStore {
  Future<void> ensureCreated(...); // creates snapshot and update on first create
  Future<Uint8List> load(...);     // snapshot + update replay
  Future<void> appendUpdate(...);  // append to single update file
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/shared/storage/loro_doc_path_test.dart test/features/shared/storage/loro_doc_store_test.dart -r compact`
Expected: PASS

**Step 5: Blue refactor and verify**

Run: `flutter test test/features/shared/storage/loro_doc_path_test.dart test/features/shared/storage/loro_doc_store_test.dart -r compact`
Expected: PASS after extracting file I/O helpers and error messages

**Step 6: Commit**

```bash
git add lib/features/shared/storage/loro_doc_path.dart lib/features/shared/storage/loro_doc_store.dart test/features/shared/storage/loro_doc_path_test.dart test/features/shared/storage/loro_doc_store_test.dart
git commit -m "feat(storage): add file-backed loro doc path and store"
```

---

### Task 4: Add 4MB update-compaction rule on load

**Files:**
- Modify: `lib/features/shared/storage/loro_doc_store.dart`
- Test: `test/features/shared/storage/loro_doc_store_test.dart`

**Step 1: Write the failing test**

```dart
test('when update file > 4MB, compacts into snapshot then clears update', () async {
  // arrange oversized update file
  // load doc
  // expect snapshot changed and update file length == 0
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/shared/storage/loro_doc_store_test.dart -r compact`
Expected: FAIL with missing compaction behavior

**Step 3: Write minimal implementation**

```dart
if (await updateFile.length() > 4 * 1024 * 1024) {
  await _compact(snapshotFile, updateFile);
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/shared/storage/loro_doc_store_test.dart -r compact`
Expected: PASS

**Step 5: Blue refactor and verify**

Run: `flutter test test/features/shared/storage/loro_doc_store_test.dart -r compact`
Expected: PASS after extracting threshold/config constants and compaction helpers

**Step 6: Commit**

```bash
git add lib/features/shared/storage/loro_doc_store.dart test/features/shared/storage/loro_doc_store_test.dart
git commit -m "feat(storage): enforce 4MB update compaction on load"
```

---

### Task 5: Replace card write/read stand-ins with real Loro store + SQLite read model

**Files:**
- Modify: `lib/features/cards/data/loro_cards_write_repository.dart`
- Modify: `lib/features/shared/data/app_database.dart`
- Modify: `lib/features/cards/data/sqlite_cards_read_repository.dart`
- Modify: `lib/features/cards/cards_controller.dart`
- Test: `test/features/cards/data/sqlite_cards_read_repository_test.dart`
- Test: `test/features/cards/application/cards_command_service_test.dart`
- Test: `test/features/cards/cards_page_test.dart`

**Step 1: Write the failing test**

```dart
test('card create persists to loro files and query returns from sqlite projection', () async {
  // create card -> verify snapshot/update files exist
  // project -> query sqlite -> expect card row
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/cards/data/sqlite_cards_read_repository_test.dart test/features/cards/application/cards_command_service_test.dart test/features/cards/cards_page_test.dart -r compact`
Expected: FAIL with in-memory store assumptions

**Step 3: Write minimal implementation**

```dart
class LoroCardsWriteRepository implements CardsWriteRepository {
  // read/write through LoroDocStore + entity path rule
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/cards/data/sqlite_cards_read_repository_test.dart test/features/cards/application/cards_command_service_test.dart test/features/cards/cards_page_test.dart -r compact`
Expected: PASS

**Step 5: Blue refactor and verify**

Run: `flutter test test/features/cards/data/sqlite_cards_read_repository_test.dart test/features/cards/application/cards_command_service_test.dart test/features/cards/cards_page_test.dart -r compact`
Expected: PASS after projection orchestration cleanup

**Step 6: Commit**

```bash
git add lib/features/cards/data/loro_cards_write_repository.dart lib/features/shared/data/app_database.dart lib/features/cards/data/sqlite_cards_read_repository.dart lib/features/cards/cards_controller.dart test/features/cards/data/sqlite_cards_read_repository_test.dart test/features/cards/application/cards_command_service_test.dart test/features/cards/cards_page_test.dart
git commit -m "feat(cards): use real loro persistence and sqlite read projection"
```

---

### Task 6: Replace pool-meta write/read stand-ins with real Loro store + SQLite read model

**Files:**
- Modify: `lib/features/pool/data/loro_pool_write_repository.dart`
- Modify: `lib/features/pool/data/sqlite_pool_read_repository.dart`
- Modify: `lib/features/pool/pool_controller.dart`
- Modify: `lib/features/pool/pool_page.dart`
- Test: `test/features/pool/data/sqlite_pool_read_repository_test.dart`
- Test: `test/features/pool/application/pool_command_service_test.dart`
- Test: `test/features/pool/pool_page_test.dart`

**Step 1: Write the failing test**

```dart
test('pool meta persists to data/loro/pool-meta/{uuidv7} and remains queryable after compaction', () async {
  // persist, force update > 4MB, reload, query sqlite, assert pool info and role state
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/pool/data/sqlite_pool_read_repository_test.dart test/features/pool/application/pool_command_service_test.dart test/features/pool/pool_page_test.dart -r compact`
Expected: FAIL with in-memory pool store assumptions

**Step 3: Write minimal implementation**

```dart
class LoroPoolWriteRepository implements PoolWriteRepository {
  // file-backed pool-meta persistence via LoroDocStore
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/pool/data/sqlite_pool_read_repository_test.dart test/features/pool/application/pool_command_service_test.dart test/features/pool/pool_page_test.dart -r compact`
Expected: PASS

**Step 5: Blue refactor and verify**

Run: `flutter test test/features/pool/data/sqlite_pool_read_repository_test.dart test/features/pool/application/pool_command_service_test.dart test/features/pool/pool_page_test.dart -r compact`
Expected: PASS after lifecycle state transition cleanup

**Step 6: Commit**

```bash
git add lib/features/pool/data/loro_pool_write_repository.dart lib/features/pool/data/sqlite_pool_read_repository.dart lib/features/pool/pool_controller.dart lib/features/pool/pool_page.dart test/features/pool/data/sqlite_pool_read_repository_test.dart test/features/pool/application/pool_command_service_test.dart test/features/pool/pool_page_test.dart
git commit -m "feat(pool): persist pool meta via loro files and sqlite projections"
```

---

### Task 7: Final gates and doc consistency verification

**Files:**
- Modify: `docs/plans/DIR.md` (if additional plan docs added)
- Modify: any files required to fix final gate failures

**Step 1: Run analyzer**

Run: `flutter analyze`
Expected: PASS

**Step 2: Run full tests**

Run: `flutter test`
Expected: PASS

**Step 3: Run governance tests**

Run: `flutter test test/ui_interaction_governance_docs_test.dart && flutter test test/plan_tdd_blue_guard_test.dart && flutter test test/interaction_guard_test.dart`
Expected: PASS

**Step 4: Run fractal doc check**

Run: `dart run tool/fractal_doc_check.dart --base HEAD~1`
Expected: PASS

**Step 5: Blue cleanup and commit**

Run: `git add <final-fixes> && git commit -m "chore(gate): clear governance and storage hardening gates"`
Expected: commit created only after all checks pass
