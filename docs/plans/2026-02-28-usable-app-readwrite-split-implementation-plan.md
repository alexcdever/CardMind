# Usable App Read/Write Split Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deliver a fully usable CardMind app with complete S1-S5 UI flows, card CRUD, full pool lifecycle, and read/write split architecture (Loro write model + SQLite read model + FRB sync integration).

**Architecture:** Keep Loro as source of truth for card and pool writes. Add projection pipeline from Loro subscription events into SQLite read models for complex queries and fast UI rendering. Connect app shell navigation to all feature pages, then close lifecycle gaps in card and pool domains, with sync failures always non-blocking for local editing.

**Tech Stack:** Flutter (Material 3), Dart, flutter_test, sqlite3/Drift (existing project choice), flutter_rust_bridge, Rust/iroh sync backend

## Mandatory Execution Rule (TDD Red-Green-Blue)

- Every task in this plan MUST be executed as **Red -> Green -> Blue -> Commit**.
- Red: write/adjust failing tests first and run to confirm expected failure.
- Green: implement the minimal code and run tests to confirm pass.
- Blue: refactor to production-quality structure without behavior change, then rerun the same tests to confirm pass.
- Commit is allowed only after Blue verification passes.
- If a task block below lists only Red/Green checks, Blue is still mandatory and must be reported explicitly in execution logs.

---

### Task 1: Wire root app shell and cross-platform navigation

**Files:**
- Modify: `lib/app/app.dart`
- Modify: `lib/app/layout/adaptive_shell.dart`
- Create: `lib/app/navigation/app_shell_controller.dart`
- Create: `lib/app/navigation/app_shell_page.dart`
- Test: `test/app/adaptive_shell_test.dart`
- Test: `test/app/app_shell_navigation_test.dart`

**Step 1: Write the failing test**

```dart
testWidgets('after onboarding local entry, app shows shell bottom nav on mobile', (tester) async {
  await tester.pumpWidget(const CardMindApp());
  await tester.tap(find.text('先本地使用'));
  await tester.pumpAndSettle();
  expect(find.byType(BottomNavigationBar), findsOneWidget);
  expect(find.text('卡片'), findsWidgets);
  expect(find.text('数据池'), findsWidgets);
  expect(find.text('设置'), findsWidgets);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/app/app_shell_navigation_test.dart -r compact`
Expected: FAIL with missing shell page/controller wiring

**Step 3: Write minimal implementation**

```dart
class AppShellPage extends StatefulWidget { ... }
// uses AdaptiveShell(section, onSectionChanged, child)
// maps AppSection.cards -> CardsPage
// maps AppSection.pool -> PoolPage
// maps AppSection.settings -> SettingsPage
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/app/app_shell_navigation_test.dart test/app/adaptive_shell_test.dart -r compact`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/app/app.dart lib/app/layout/adaptive_shell.dart lib/app/navigation/app_shell_controller.dart lib/app/navigation/app_shell_page.dart test/app/adaptive_shell_test.dart test/app/app_shell_navigation_test.dart
git commit -m "feat(shell): wire adaptive navigation shell as primary workspace"
```

---

### Task 2: Add domain models for Loro write side and SQLite read side

**Files:**
- Create: `lib/features/cards/domain/card_note.dart`
- Create: `lib/features/cards/domain/card_note_projection.dart`
- Create: `lib/features/pool/domain/pool_entity.dart`
- Create: `lib/features/pool/domain/pool_member.dart`
- Create: `lib/features/pool/domain/pool_request.dart`
- Test: `test/features/cards/domain/card_note_projection_test.dart`
- Test: `test/features/pool/domain/pool_entity_test.dart`

**Step 1: Write the failing test**

```dart
test('card projection keeps deleted flag and updatedAt ordering key', () {
  final note = CardNote(...);
  final row = CardNoteProjection.fromNote(note);
  expect(row.deleted, isTrue);
  expect(row.updatedAtMicros, greaterThan(0));
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/cards/domain/card_note_projection_test.dart test/features/pool/domain/pool_entity_test.dart -r compact`
Expected: FAIL with missing domain types

**Step 3: Write minimal implementation**

```dart
class CardNote { final String id; final String title; ... }
class CardNoteProjection { final String id; final int updatedAtMicros; ... }
class PoolEntity { final String poolId; final String name; final bool dissolved; ... }
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/cards/domain/card_note_projection_test.dart test/features/pool/domain/pool_entity_test.dart -r compact`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/cards/domain/card_note.dart lib/features/cards/domain/card_note_projection.dart lib/features/pool/domain/pool_entity.dart lib/features/pool/domain/pool_member.dart lib/features/pool/domain/pool_request.dart test/features/cards/domain/card_note_projection_test.dart test/features/pool/domain/pool_entity_test.dart
git commit -m "feat(domain): add card and pool entities for rw split"
```

---

### Task 3: Implement SQLite read model repositories

**Files:**
- Create: `lib/features/cards/data/cards_read_repository.dart`
- Create: `lib/features/cards/data/sqlite_cards_read_repository.dart`
- Create: `lib/features/pool/data/pool_read_repository.dart`
- Create: `lib/features/pool/data/sqlite_pool_read_repository.dart`
- Create: `lib/features/shared/data/app_database.dart`
- Test: `test/features/cards/data/sqlite_cards_read_repository_test.dart`
- Test: `test/features/pool/data/sqlite_pool_read_repository_test.dart`

**Step 1: Write the failing test**

```dart
test('search returns notes ordered by updatedAt desc', () async {
  final repo = SqliteCardsReadRepository.inMemory();
  await repo.upsertProjection(...older...);
  await repo.upsertProjection(...newer...);
  final rows = await repo.search('');
  expect(rows.first.id, 'newer');
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/cards/data/sqlite_cards_read_repository_test.dart test/features/pool/data/sqlite_pool_read_repository_test.dart -r compact`
Expected: FAIL with missing repositories/schema

**Step 3: Write minimal implementation**

```dart
abstract class CardsReadRepository {
  Future<List<CardNoteProjection>> search(String query, {bool includeDeleted = false});
  Future<void> upsertProjection(CardNoteProjection row);
}
```

```dart
class SqliteCardsReadRepository implements CardsReadRepository { ... }
class SqlitePoolReadRepository implements PoolReadRepository { ... }
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/cards/data/sqlite_cards_read_repository_test.dart test/features/pool/data/sqlite_pool_read_repository_test.dart -r compact`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/cards/data/cards_read_repository.dart lib/features/cards/data/sqlite_cards_read_repository.dart lib/features/pool/data/pool_read_repository.dart lib/features/pool/data/sqlite_pool_read_repository.dart lib/features/shared/data/app_database.dart test/features/cards/data/sqlite_cards_read_repository_test.dart test/features/pool/data/sqlite_pool_read_repository_test.dart
git commit -m "feat(data): add sqlite read repositories for cards and pool"
```

---

### Task 4: Implement Loro write repositories and mutation services

**Files:**
- Create: `lib/features/cards/data/cards_write_repository.dart`
- Create: `lib/features/cards/data/loro_cards_write_repository.dart`
- Create: `lib/features/cards/application/cards_command_service.dart`
- Create: `lib/features/pool/data/pool_write_repository.dart`
- Create: `lib/features/pool/data/loro_pool_write_repository.dart`
- Create: `lib/features/pool/application/pool_command_service.dart`
- Test: `test/features/cards/application/cards_command_service_test.dart`
- Test: `test/features/pool/application/pool_command_service_test.dart`

**Step 1: Write the failing test**

```dart
test('delete then restore card toggles deleted flag in write side', () async {
  final writeRepo = InMemoryCardsWriteRepository();
  final service = CardsCommandService(writeRepo);
  await service.createNote('n1', 'A', 'body');
  await service.deleteNote('n1');
  await service.restoreNote('n1');
  expect((await writeRepo.getById('n1'))!.deleted, isFalse);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/cards/application/cards_command_service_test.dart test/features/pool/application/pool_command_service_test.dart -r compact`
Expected: FAIL with missing command services/write repositories

**Step 3: Write minimal implementation**

```dart
class CardsCommandService {
  Future<void> createNote(...)
  Future<void> updateNote(...)
  Future<void> deleteNote(String id)
  Future<void> restoreNote(String id)
}
```

```dart
class PoolCommandService {
  Future<void> createPool(...)
  Future<void> editPoolInfo(...)
  Future<void> requestJoin(...)
  Future<void> approve(...)
  Future<void> reject(...)
  Future<void> leavePool(...)
  Future<void> dissolvePool(...)
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/cards/application/cards_command_service_test.dart test/features/pool/application/pool_command_service_test.dart -r compact`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/cards/data/cards_write_repository.dart lib/features/cards/data/loro_cards_write_repository.dart lib/features/cards/application/cards_command_service.dart lib/features/pool/data/pool_write_repository.dart lib/features/pool/data/loro_pool_write_repository.dart lib/features/pool/application/pool_command_service.dart test/features/cards/application/cards_command_service_test.dart test/features/pool/application/pool_command_service_test.dart
git commit -m "feat(write): add loro-backed command services for cards and pool lifecycle"
```

---

### Task 5: Add Loro-to-SQLite projection pipeline

**Files:**
- Create: `lib/features/shared/projection/loro_projection_event.dart`
- Create: `lib/features/shared/projection/loro_projection_worker.dart`
- Create: `lib/features/cards/projection/cards_projection_handler.dart`
- Create: `lib/features/pool/projection/pool_projection_handler.dart`
- Test: `test/features/shared/projection/loro_projection_worker_test.dart`
- Test: `test/features/cards/projection/cards_projection_handler_test.dart`
- Test: `test/features/pool/projection/pool_projection_handler_test.dart`

**Step 1: Write the failing test**

```dart
test('on card-updated event, projection worker upserts sqlite row', () async {
  final readRepo = FakeCardsReadRepository();
  final worker = LoroProjectionWorker(cardsHandler: CardsProjectionHandler(readRepo));
  await worker.handle(LoroProjectionEvent.cardUpsert(...));
  expect(readRepo.upsertedIds, contains('card-1'));
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/shared/projection/loro_projection_worker_test.dart test/features/cards/projection/cards_projection_handler_test.dart test/features/pool/projection/pool_projection_handler_test.dart -r compact`
Expected: FAIL with missing projection worker/handlers

**Step 3: Write minimal implementation**

```dart
sealed class LoroProjectionEvent { ... }
class LoroProjectionWorker { Future<void> handle(LoroProjectionEvent event) async { ... } }
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/shared/projection/loro_projection_worker_test.dart test/features/cards/projection/cards_projection_handler_test.dart test/features/pool/projection/pool_projection_handler_test.dart -r compact`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/shared/projection/loro_projection_event.dart lib/features/shared/projection/loro_projection_worker.dart lib/features/cards/projection/cards_projection_handler.dart lib/features/pool/projection/pool_projection_handler.dart test/features/shared/projection/loro_projection_worker_test.dart test/features/cards/projection/cards_projection_handler_test.dart test/features/pool/projection/pool_projection_handler_test.dart
git commit -m "feat(projection): add loro subscription to sqlite projection pipeline"
```

---

### Task 6: Complete cards UI with full CRUD backed by repositories

**Files:**
- Modify: `lib/features/cards/cards_controller.dart`
- Modify: `lib/features/cards/cards_page.dart`
- Modify: `lib/features/editor/editor_controller.dart`
- Modify: `lib/features/editor/editor_page.dart`
- Test: `test/features/cards/cards_page_test.dart`
- Test: `test/features/editor/editor_page_test.dart`

**Step 1: Write the failing test**

```dart
testWidgets('create-edit-save appears in cards list through read model', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: CardsPage()));
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, 'Title 1');
  await tester.tap(find.byIcon(Icons.save_outlined));
  await tester.pumpAndSettle();
  expect(find.text('Title 1'), findsOneWidget);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/cards/cards_page_test.dart test/features/editor/editor_page_test.dart -r compact`
Expected: FAIL with list not backed by repository/projection

**Step 3: Write minimal implementation**

```dart
class CardsController extends ChangeNotifier {
  Future<void> load({String query = ''})
  Future<void> create(...)
  Future<void> delete(String id)
  Future<void> restore(String id)
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/cards/cards_page_test.dart test/features/editor/editor_page_test.dart -r compact`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/cards/cards_controller.dart lib/features/cards/cards_page.dart lib/features/editor/editor_controller.dart lib/features/editor/editor_page.dart test/features/cards/cards_page_test.dart test/features/editor/editor_page_test.dart
git commit -m "feat(cards): complete repository-backed note CRUD and editor loop"
```

---

### Task 7: Complete pool UI lifecycle including edit and dissolve

**Files:**
- Modify: `lib/features/pool/pool_controller.dart`
- Modify: `lib/features/pool/pool_page.dart`
- Modify: `lib/features/pool/pool_state.dart`
- Modify: `lib/features/pool/join_error_mapper.dart`
- Test: `test/features/pool/pool_page_test.dart`
- Test: `test/features/pool/join_error_mapper_test.dart`

**Step 1: Write the failing test**

```dart
testWidgets('owner can edit pool info and dissolve pool', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: PoolPage(state: PoolState.joinedAsOwner())));
  await tester.tap(find.text('编辑池信息'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, 'New Pool Name');
  await tester.tap(find.text('保存'));
  await tester.pumpAndSettle();
  expect(find.text('New Pool Name'), findsOneWidget);
  await tester.tap(find.text('解散池'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('确认解散'));
  await tester.pumpAndSettle();
  expect(find.text('创建池'), findsOneWidget);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/pool/pool_page_test.dart test/features/pool/join_error_mapper_test.dart -r compact`
Expected: FAIL with missing edit/dissolve lifecycle actions

**Step 3: Write minimal implementation**

```dart
// pool_state adds owner/member role and editable pool info fields
// pool_page renders edit dialog and dissolve confirmation for owner
// pool_controller routes actions to pool command service
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/pool/pool_page_test.dart test/features/pool/join_error_mapper_test.dart -r compact`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/pool/pool_controller.dart lib/features/pool/pool_page.dart lib/features/pool/pool_state.dart lib/features/pool/join_error_mapper.dart test/features/pool/pool_page_test.dart test/features/pool/join_error_mapper_test.dart
git commit -m "feat(pool): complete full lifecycle with edit, leave, and dissolve actions"
```

---

### Task 8: Integrate FRB sync feedback and non-blocking guarantees

**Files:**
- Modify: `lib/features/sync/sync_controller.dart`
- Modify: `lib/features/sync/sync_service.dart`
- Modify: `lib/features/sync/sync_banner.dart`
- Modify: `lib/features/cards/cards_page.dart`
- Modify: `lib/features/pool/pool_page.dart`
- Test: `test/features/sync/sync_controller_test.dart`
- Test: `test/features/sync/sync_banner_test.dart`
- Test: `test/features/cards/cards_sync_navigation_test.dart`
- Test: `test/features/pool/pool_sync_interaction_test.dart`

**Step 1: Write the failing test**

```dart
testWidgets('sync error banner action navigates to pool handling without blocking note creation', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: CardsPage(syncStatus: SyncStatus.error('REQUEST_TIMEOUT'))));
  await tester.tap(find.text('查看'));
  await tester.pumpAndSettle();
  expect(find.textContaining('加入失败:'), findsOneWidget);
  await tester.pageBack();
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  expect(find.text('编辑卡片'), findsOneWidget);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/sync/sync_controller_test.dart test/features/sync/sync_banner_test.dart test/features/cards/cards_sync_navigation_test.dart test/features/pool/pool_sync_interaction_test.dart -r compact`
Expected: FAIL with incomplete frb sync action wiring or blocking flows

**Step 3: Write minimal implementation**

```dart
class SyncService {
  Future<void> retry();
  Future<void> reconnect();
  Stream<SyncStatus> watchStatus();
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/sync/sync_controller_test.dart test/features/sync/sync_banner_test.dart test/features/cards/cards_sync_navigation_test.dart test/features/pool/pool_sync_interaction_test.dart -r compact`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/sync/sync_controller.dart lib/features/sync/sync_service.dart lib/features/sync/sync_banner.dart lib/features/cards/cards_page.dart lib/features/pool/pool_page.dart test/features/sync/sync_controller_test.dart test/features/sync/sync_banner_test.dart test/features/cards/cards_sync_navigation_test.dart test/features/pool/pool_sync_interaction_test.dart
git commit -m "feat(sync): integrate actionable non-blocking sync feedback across domains"
```

---

### Task 9: Governance alignment, guards, and full gate run

**Files:**
- Modify: `docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md`
- Modify: `docs/plans/2026-02-27-ui-interaction-release-gate.md`
- Modify: `docs/plans/2026-02-27-mobile-desktop-ui-interaction-design.md`
- Modify: `docs/plans/2026-02-28-ui-interaction-full-alignment-design.md`
- Modify: `docs/plans/DIR.md`
- Modify: `test/ui_interaction_governance_docs_test.dart`
- Modify: `test/interaction_guard_test.dart`

**Step 1: Write the failing test**

```dart
test('governance docs include pool edit and dissolve lifecycle coverage', () {
  final matrix = File('docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md').readAsStringSync();
  expect(matrix, contains('编辑池信息'));
  expect(matrix, contains('解散池'));
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/ui_interaction_governance_docs_test.dart -r compact`
Expected: FAIL with missing lifecycle language in governance docs

**Step 3: Write minimal implementation**

```markdown
- S3 覆盖：创建池、加入池、审批、编辑池信息、成员退出、所有者解散池。
```

**Step 4: Run full verification suite**

Run: `flutter analyze && flutter test && flutter test test/ui_interaction_governance_docs_test.dart && flutter test test/interaction_guard_test.dart && dart run tool/fractal_doc_check.dart --base HEAD~1`
Expected: PASS all checks

**Step 5: Commit**

```bash
git add docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md docs/plans/2026-02-27-ui-interaction-release-gate.md docs/plans/2026-02-27-mobile-desktop-ui-interaction-design.md docs/plans/2026-02-28-ui-interaction-full-alignment-design.md docs/plans/DIR.md test/ui_interaction_governance_docs_test.dart test/interaction_guard_test.dart
git commit -m "chore(gate): align governance and clear full usable-app gates"
```
