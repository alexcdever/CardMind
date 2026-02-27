# CardMind 移动端与桌面端 UI 交互 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将已批准的页面级交互设计落地为 Flutter 首版 UI，覆盖首次启动分流、卡片/池/设置三大主导航、跨端触摸与键鼠交互差异。

**Architecture:** 采用单一 Flutter UI 架构，通过 `NavigationRail`（桌面）与 `BottomNavigationBar`（移动）做同构信息架构映射。页面状态先用本地内存 ViewModel 驱动，按“离线优先 + 同步异常不阻断编辑”原则实现状态分层与错误反馈。测试以 Widget Test 为主，先写失败测试，再补最小实现。

**Tech Stack:** Flutter, Dart, flutter_test, Material 3

---

### Task 1: 建立应用壳层与三主导航骨架

**Files:**
- Create: `lib/app/app.dart`
- Create: `lib/app/layout/adaptive_shell.dart`
- Create: `lib/app/navigation/app_section.dart`
- Modify: `lib/main.dart`
- Test: `test/app/adaptive_shell_test.dart`

**Step 1: Write the failing test**

```dart
testWidgets('uses bottom nav on mobile width', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: AdaptiveShellForTest(width: 390)));
  expect(find.byType(BottomNavigationBar), findsOneWidget);
  expect(find.byType(NavigationRail), findsNothing);
});

testWidgets('uses navigation rail on desktop width', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: AdaptiveShellForTest(width: 1200)));
  expect(find.byType(NavigationRail), findsOneWidget);
  expect(find.byType(BottomNavigationBar), findsNothing);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/app/adaptive_shell_test.dart`
Expected: FAIL（`AdaptiveShell` 相关类型不存在）

**Step 3: Write minimal implementation**

```dart
enum AppSection { cards, pool, settings }

class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key, required this.child, required this.section});
  final Widget child;
  final AppSection section;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 900;
    return desktop
        ? Row(children: [NavigationRail(destinations: const [], selectedIndex: 0), Expanded(child: child)])
        : Scaffold(bottomNavigationBar: const BottomNavigationBar(items: []), body: child);
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/app/adaptive_shell_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/main.dart lib/app/app.dart lib/app/layout/adaptive_shell.dart lib/app/navigation/app_section.dart test/app/adaptive_shell_test.dart
git commit -m "feat(ui): add adaptive app shell with three-section navigation"
```

---

### Task 2: 实现首次启动分流（仅两个入口）

**Files:**
- Create: `lib/features/onboarding/onboarding_page.dart`
- Create: `lib/features/onboarding/onboarding_controller.dart`
- Create: `lib/features/onboarding/onboarding_state.dart`
- Modify: `lib/app/app.dart`
- Test: `test/features/onboarding/onboarding_page_test.dart`

**Step 1: Write the failing test**

```dart
testWidgets('shows only two primary actions', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: OnboardingPage()));
  expect(find.text('先本地使用'), findsOneWidget);
  expect(find.text('创建或加入数据池'), findsOneWidget);
  expect(find.text('稍后再说'), findsNothing);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/onboarding_page_test.dart`
Expected: FAIL（页面不存在）

**Step 3: Write minimal implementation**

```dart
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(onPressed: () {}, child: const Text('先本地使用')),
          OutlinedButton(onPressed: () {}, child: const Text('创建或加入数据池')),
        ],
      ),
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/onboarding_page_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/onboarding/onboarding_page.dart lib/features/onboarding/onboarding_controller.dart lib/features/onboarding/onboarding_state.dart lib/app/app.dart test/features/onboarding/onboarding_page_test.dart
git commit -m "feat(ui): add onboarding split between local-first and pool flow"
```

---

### Task 3: 实现卡片列表页（高频主工作区）

**Files:**
- Create: `lib/features/cards/cards_page.dart`
- Create: `lib/features/cards/cards_controller.dart`
- Create: `lib/features/cards/card_summary.dart`
- Test: `test/features/cards/cards_page_test.dart`

**Step 1: Write the failing test**

```dart
testWidgets('renders search, list, and create action', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: CardsPage()));
  expect(find.byType(TextField), findsOneWidget);
  expect(find.byIcon(Icons.add), findsOneWidget);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/cards/cards_page_test.dart`
Expected: FAIL（`CardsPage` 不存在）

**Step 3: Write minimal implementation**

```dart
class CardsPage extends StatelessWidget {
  const CardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: const [TextField(decoration: InputDecoration(hintText: '搜索卡片'))],
      ),
      floatingActionButton: FloatingActionButton(onPressed: null, child: const Icon(Icons.add)),
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/cards/cards_page_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/cards/cards_page.dart lib/features/cards/cards_controller.dart lib/features/cards/card_summary.dart test/features/cards/cards_page_test.dart
git commit -m "feat(ui): add cards page with search and create affordance"
```

---

### Task 4: 实现卡片编辑页与离开保护

**Files:**
- Create: `lib/features/editor/editor_page.dart`
- Create: `lib/features/editor/editor_controller.dart`
- Test: `test/features/editor/editor_page_test.dart`

**Step 1: Write the failing test**

```dart
testWidgets('shows unsaved changes dialog when leaving', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: EditorPage()));
  await tester.enterText(find.byType(TextField).first, 'new title');
  await tester.tap(find.byTooltip('Back'));
  await tester.pumpAndSettle();
  expect(find.text('保存并离开'), findsOneWidget);
  expect(find.text('放弃更改'), findsOneWidget);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/editor/editor_page_test.dart`
Expected: FAIL（对话框与页面不存在）

**Step 3: Write minimal implementation**

```dart
class EditorPage extends StatefulWidget {
  const EditorPage({super.key});
  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  bool dirty = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: _onBack), title: const Text('编辑卡片')),
      body: TextField(onChanged: (_) => dirty = true),
    );
  }

  Future<void> _onBack() async { /* showDialog with save/discard/cancel */ }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/editor/editor_page_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/editor/editor_page.dart lib/features/editor/editor_controller.dart test/features/editor/editor_page_test.dart
git commit -m "feat(ui): add editor leave guard and local-save feedback"
```

---

### Task 5: 实现池页面三态与审批交互

**Files:**
- Create: `lib/features/pool/pool_page.dart`
- Create: `lib/features/pool/pool_controller.dart`
- Create: `lib/features/pool/pool_state.dart`
- Create: `lib/features/pool/join_error_mapper.dart`
- Test: `test/features/pool/pool_page_test.dart`
- Test: `test/features/pool/join_error_mapper_test.dart`

**Step 1: Write the failing tests**

```dart
test('maps ADMIN_OFFLINE to retry message', () {
  expect(mapJoinError('ADMIN_OFFLINE'), contains('稍后重试'));
});

testWidgets('shows join actions when not joined', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: PoolPage(state: PoolState.notJoined())));
  expect(find.text('创建池'), findsOneWidget);
  expect(find.text('扫码加入'), findsOneWidget);
});
```

**Step 2: Run tests to verify they fail**

Run: `flutter test test/features/pool/join_error_mapper_test.dart test/features/pool/pool_page_test.dart`
Expected: FAIL（映射器与页面状态未实现）

**Step 3: Write minimal implementation**

```dart
String mapJoinError(String code) {
  switch (code) {
    case 'ADMIN_OFFLINE':
      return '管理员离线，请稍后重试';
    default:
      return '请求失败，请重试';
  }
}
```

```dart
sealed class PoolState {
  const PoolState();
  const factory PoolState.notJoined() = PoolNotJoined;
  const factory PoolState.joined() = PoolJoined;
  const factory PoolState.error(String code) = PoolError;
}
```

**Step 4: Run tests to verify they pass**

Run: `flutter test test/features/pool/join_error_mapper_test.dart test/features/pool/pool_page_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/pool/pool_page.dart lib/features/pool/pool_controller.dart lib/features/pool/pool_state.dart lib/features/pool/join_error_mapper.dart test/features/pool/pool_page_test.dart test/features/pool/join_error_mapper_test.dart
git commit -m "feat(ui): add pool states, approval actions, and join error mapping"
```

---

### Task 6: 实现设置页与池入口回流

**Files:**
- Create: `lib/features/settings/settings_page.dart`
- Create: `lib/features/settings/settings_controller.dart`
- Test: `test/features/settings/settings_page_test.dart`

**Step 1: Write the failing test**

```dart
testWidgets('exposes pool entry from settings', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
  expect(find.text('创建或加入数据池'), findsOneWidget);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/settings_page_test.dart`
Expected: FAIL（页面不存在）

**Step 3: Write minimal implementation**

```dart
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const ListTile(title: Text('设备信息')),
        ListTile(title: const Text('创建或加入数据池'), onTap: () {}),
      ],
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/settings/settings_page_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/settings/settings_page.dart lib/features/settings/settings_controller.dart test/features/settings/settings_page_test.dart
git commit -m "feat(ui): add settings page with pool re-entry"
```

---

### Task 7: 实现中间态同步提示策略（弱提示/异常高亮）

**Files:**
- Create: `lib/features/sync/sync_banner.dart`
- Create: `lib/features/sync/sync_status.dart`
- Modify: `lib/features/cards/cards_page.dart`
- Modify: `lib/features/pool/pool_page.dart`
- Test: `test/features/sync/sync_banner_test.dart`

**Step 1: Write the failing tests**

```dart
testWidgets('shows subtle label in healthy status', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: SyncBanner(status: SyncStatus.healthy)));
  expect(find.text('本地已保存'), findsOneWidget);
});

testWidgets('shows highlighted warning in error status', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: SyncBanner(status: SyncStatus.error('REQUEST_TIMEOUT'))));
  expect(find.textContaining('同步异常'), findsOneWidget);
});
```

**Step 2: Run tests to verify they fail**

Run: `flutter test test/features/sync/sync_banner_test.dart`
Expected: FAIL（组件与状态未定义）

**Step 3: Write minimal implementation**

```dart
enum SyncStatusKind { healthy, syncing, error }

class SyncStatus {
  const SyncStatus.healthy() : kind = SyncStatusKind.healthy, code = null;
  const SyncStatus.error(this.code) : kind = SyncStatusKind.error;
  final SyncStatusKind kind;
  final String? code;
}
```

```dart
class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key, required this.status});
  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.kind == SyncStatusKind.error) {
      return MaterialBanner(content: const Text('同步异常，请前往池页面处理'), actions: [TextButton(onPressed: () {}, child: const Text('查看'))]);
    }
    return const Text('本地已保存');
  }
}
```

**Step 4: Run tests to verify they pass**

Run: `flutter test test/features/sync/sync_banner_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/sync/sync_banner.dart lib/features/sync/sync_status.dart lib/features/cards/cards_page.dart lib/features/pool/pool_page.dart test/features/sync/sync_banner_test.dart
git commit -m "feat(ui): add tiered sync feedback for healthy and error states"
```

---

### Task 8: 桌面键鼠效率交互（右键菜单 + 快捷键）

**Files:**
- Create: `lib/features/cards/cards_desktop_interactions.dart`
- Modify: `lib/features/cards/cards_page.dart`
- Modify: `lib/features/editor/editor_page.dart`
- Test: `test/features/cards/cards_desktop_interactions_test.dart`
- Test: `test/features/editor/editor_shortcuts_test.dart`

**Step 1: Write the failing tests**

```dart
testWidgets('opens context menu on secondary tap', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: CardsPage()));
  final gesture = await tester.startGesture(const Offset(40, 120), kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
  await gesture.up();
  await tester.pumpAndSettle();
  expect(find.text('删除'), findsOneWidget);
});

testWidgets('saves with cmd/ctrl+s shortcut', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: EditorPage()));
  await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
  expect(find.text('本地已保存'), findsOneWidget);
});
```

**Step 2: Run tests to verify they fail**

Run: `flutter test test/features/cards/cards_desktop_interactions_test.dart test/features/editor/editor_shortcuts_test.dart`
Expected: FAIL（右键菜单和快捷键保存未实现）

**Step 3: Write minimal implementation**

```dart
class CardsDesktopInteractions {
  void showContextMenu(BuildContext context, Offset position) {
    showMenu(context: context, position: RelativeRect.fromLTRB(position.dx, position.dy, 0, 0), items: const [PopupMenuItem(value: 'delete', child: Text('删除'))]);
  }
}
```

```dart
return Shortcuts(
  shortcuts: const {SingleActivator(LogicalKeyboardKey.keyS, control: true): SaveIntent()},
  child: Actions(actions: {SaveIntent: CallbackAction<SaveIntent>(onInvoke: (_) => controller.save())}, child: ...),
);
```

**Step 4: Run tests to verify they pass**

Run: `flutter test test/features/cards/cards_desktop_interactions_test.dart test/features/editor/editor_shortcuts_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/cards/cards_desktop_interactions.dart lib/features/cards/cards_page.dart lib/features/editor/editor_page.dart test/features/cards/cards_desktop_interactions_test.dart test/features/editor/editor_shortcuts_test.dart
git commit -m "feat(ui): add desktop context menu and keyboard save shortcut"
```

---

### Task 9: 集成回归与文档同步

**Files:**
- Modify: `test/widget_test.dart`
- Modify: `lib/DIR.md`
- Modify: `docs/plans/DIR.md`

**Step 1: Write/adjust failing smoke test to target new app shell**

```dart
testWidgets('app boots into onboarding or cards flow', (tester) async {
  await tester.pumpWidget(const MyApp());
  expect(find.text('先本地使用').evaluate().isNotEmpty || find.text('搜索卡片').evaluate().isNotEmpty, true);
});
```

**Step 2: Run full Flutter tests and verify failures first**

Run: `flutter test`
Expected: FAIL（旧计数器测试与新结构不一致）

**Step 3: Update smoke tests and directory docs minimally**

```text
DIR.md 中登记 app/layout/navigation/features 目录与职责。
```

**Step 4: Run verification suite**

Run: `flutter analyze && flutter test`
Expected: PASS

**Step 5: Commit**

```bash
git add test/widget_test.dart lib/DIR.md docs/plans/DIR.md
git commit -m "test(ui): align smoke tests and directory docs for new interaction shell"
```
