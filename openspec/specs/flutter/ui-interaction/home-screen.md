# 主页交互规格说明书

## 📋 规格编号: SP-FLUT-008
**依赖**: SP-SPM-001（单池模型核心规格）, SP-FLUT-007（初始化流程）  
**版本**: 1.0.0  
**状态**: 待实施

---

## 1. 概述

### 1.1 目标
定义CardMind Flutter应用主页的交互规范，确保：
- 卡片列表展示符合单池模型
- 同步状态清晰可见
- 用户操作响应及时

### 1.2 主页结构
```
┌─────────────────────────────────────┐
│ 顶部栏                              │
│   [Pool名称] [同步状态图标]          │
├─────────────────────────────────────┤
│                                     │
│  卡片列表                           │
│  ┌─────────────────────────────┐   │
│  │ 卡片1                       │   │
│  │ 预览内容...                 │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ 卡片2                       │   │
│  └─────────────────────────────┘   │
│                                     │
│                            [+] FAB  │
└─────────────────────────────────────┘
```

**注**: FAB（浮动操作按钮）位于右下角，用于快速创建新卡片。详见 SP-FLUT-011（移动端）和 SP-FLUT-012（桌面端）。

---

## 2. 状态管理

### 2.1 主页状态模型
```dart
class HomeScreenState extends ChangeNotifier {
  /// 当前池信息
  PoolInfo? _currentPool;
  
  /// 卡片列表
  List<Card> _cards = [];
  
  /// 同步状态
  SyncStatus _syncStatus = SyncStatus.disconnected();
  
  /// 搜索关键词
  String _searchQuery = '';
  
  /// 加载状态
  bool _isLoading = false;
  
  /// 错误信息
  String? _errorMessage;
  
  // Getters
  List<Card> get visibleCards => _getFilteredCards();
  SyncStatus get syncStatus => _syncStatus;
  bool get isLoading => _isLoading;
}
```

### 2.2 卡片模型
```dart
class Card {
  final String id;
  final String title;
  final String contentPreview;
  final DateTime updatedAt;
  final bool isSynced;
  
  Card({
    required this.id,
    required this.title,
    required this.contentPreview,
    required this.updatedAt,
    this.isSynced = true,
  });
  
  /// 从API模型转换
  factory Card.fromApiModel(ApiCard card) {
    return Card(
      id: card.id,
      title: card.title,
      contentPreview: _truncateContent(card.content),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(card.updatedAt),
      isSynced: card.updatedAt > 0, // 示例逻辑
    );
  }
}
```

---

## 3. 功能规格

### 3.1 卡片列表展示

#### Spec-HOME-001: 显示当前池的卡片
```dart
/// it_should_display_all_cards_from_current_pool()
Widget buildCardList() {
  return FutureBuilder<List<Card>>(
    future: CardApi.getAllCards(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }
      
      if (snapshot.hasError) {
        return ErrorView(error: snapshot.error.toString());
      }
      
      final cards = snapshot.data!;
      return ListView.builder(
        itemCount: cards.length,
        itemBuilder: (context, index) => CardWidget(card: cards[index]),
      );
    },
  );
}

/// it_should_show_empty_state_when_no_cards()
Widget buildEmptyState() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.note_add, size: 64, color: Colors.grey),
        Text('还没有笔记'),
        ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/create-card'),
          child: Text('创建第一张笔记'),
        ),
      ],
    ),
  );
}
```

#### Spec-HOME-002: 卡片搜索
```dart
/// it_should_filter_cards_by_search_query()
class SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = Provider.of<HomeScreenState>(context);
    
    return TextField(
      onChanged: (query) => state.updateSearchQuery(query),
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: '搜索笔记...',
      ),
    );
  }
}

/// it_should_show_search_results()
Widget buildSearchResults(String query) {
  return FutureBuilder<List<Card>>(
    future: CardApi.searchCards(query),
    builder: (context, snapshot) {
      if (snapshot.hasData && snapshot.data!.isEmpty) {
        return Center(child: Text('未找到相关笔记'));
      }
      
      return ListView.builder(
        itemCount: snapshot.data?.length ?? 0,
        itemBuilder: (context, index) => 
          CardWidget(card: snapshot.data![index]),
      );
    },
  );
}
```

### 3.2 同步状态展示

#### Spec-HOME-003: 显示同步状态
```dart
/// it_should_show_sync_status_indicator()
Widget buildSyncStatusIndicator() {
  return StreamBuilder<SyncStatus>(
    stream: SyncApi.statusStream,
    builder: (context, snapshot) {
      final status = snapshot.data ?? SyncStatus.disconnected();
      
      return Row(
        children: [
          Icon(
            status.isActive ? Icons.cloud_done : Icons.cloud_off,
            color: status.isActive ? Colors.green : Colors.grey,
          ),
          Text(_getSyncStatusText(status)),
        ],
      );
    },
  );
}

String _getSyncStatusText(SyncStatus status) {
  if (!status.isActive) return '未同步';
  if (status.syncingPeers > 0) return '同步中...';
  return '已同步';
}

/// it_should_show_syncing_indicator_when_active()
Widget buildSyncingIndicator() {
  return FutureBuilder<SyncStatus>(
    future: SyncApi.getSyncStatus(),
    builder: (context, snapshot) {
      if (snapshot.hasData && snapshot.data!.syncingPeers > 0) {
        return Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('正在同步...'),
          ],
        );
      }
      return SizedBox.shrink();
    },
  );
}
```

### 3.3 卡片操作

#### Spec-HOME-004: 创建新卡片
```dart
/// it_should_show_fab_button_on_home_screen()
Widget buildFloatingActionButton() {
  return FloatingActionButton(
    onPressed: () => Navigator.pushNamed(context, '/create-card'),
    child: Icon(Icons.add),
    tooltip: '创建新卡片',
  );
}

/// it_should_navigate_to_card_editor_when_fab_tapped()
void onCreateCard(BuildContext context) {
  Navigator.pushNamed(context, '/create-card');
}

/// it_should_save_card_and_update_list()
Future<void> onSaveCard(String title, String content) async {
  setLoading(true);

  try {
    final card = await CardApi.createCard(title, content);
    _cards.insert(0, card);
    notifyListeners();

    Navigator.pop(context);
  } catch (e) {
    _errorMessage = '保存失败: $e';
  } finally {
    setLoading(false);
  }
}
```

**注**: FAB 按钮的详细交互规格见 SP-FLUT-011（移动端 UI 交互规格）和 SP-FLUT-012（桌面端 UI 交互规格）。

#### Spec-HOME-005: 打开/编辑卡片
```dart
/// it_should_navigate_to_card_detail()
void onCardTap(BuildContext context, Card card) {
  Navigator.pushNamed(
    context,
    '/card-detail',
    arguments: {'cardId': card.id},
  );
}

/// it_should_update_card_in_list_after_edit()
Future<void> onUpdateCard(Card updatedCard) async {
  final index = _cards.indexWhere((c) => c.id == updatedCard.id);
  if (index != -1) {
    _cards[index] = updatedCard;
    notifyListeners();
  }
}
```

#### Spec-HOME-006: 删除卡片
```dart
/// it_should_soft_delete_card_and_remove_from_list()
Future<void> onDeleteCard(String cardId) async {
  try {
    await CardApi.deleteCard(cardId);
    _cards.removeWhere((c) => c.id == cardId);
    notifyListeners();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已删除笔记')),
    );
  } catch (e) {
    _errorMessage = '删除失败: $e';
  }
}

/// it_should_show_undo_option_after_deletion()
void showDeleteSnackbar(String cardId) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('已删除笔记'),
      action: SnackBarAction(
        label: '撤销',
        onPressed: () => _undoDelete(cardId),
      ),
    ),
  );
}
```

---

## 4. 测试规格

### 4.1 卡片列表测试
```dart
/// it_should_display_cards_from_api()
test('display cards from API', () async {
  final state = HomeScreenState();
  await state.loadCards();
  
  expect(state.cards, isNotEmpty);
  expect(state.visibleCards.length, equals(state.cards.length));
});

/// it_should_filter_cards_by_search_query()
test('filter cards by search query', () async {
  final state = HomeScreenState();
  await state.loadCards();
  
  state.updateSearchQuery('test');
  
  expect(
    state.visibleCards.every((c) => c.title.contains('test')),
    isTrue,
  );
});
```

### 4.2 同步状态测试
```dart
/// it_should_update_sync_status_when_changed()
test('update sync status when changed', () async {
  final state = HomeScreenState();
  
  SyncApi.statusStream.listen((status) {
    expect(state.syncStatus, equals(status));
  });
  
  await SyncApi.startSync();
});

/// it_should_show_disconnected_when_sync_inactive()
test('show disconnected when sync inactive', () {
  final state = HomeScreenState();
  state.updateSyncStatus(SyncStatus.disconnected());
  
  expect(state.syncStatus.isActive, isFalse);
});
```

### 4.3 卡片操作测试
```dart
/// it_should_add_new_card_to_list()
test('add new card to list', () async {
  final state = HomeScreenState();
  await state.loadCards();
  
  final initialCount = state.cards.length;
  await state.onSaveCard('New Title', 'New Content');
  
  expect(state.cards.length, equals(initialCount + 1));
});

/// it_should_remove_card_from_list_after_deletion()
test('remove card from list after deletion', () async {
  final state = HomeScreenState();
  await state.loadCards();
  
  final cardToDelete = state.cards.first;
  await state.onDeleteCard(cardToDelete.id);
  
  expect(
    state.cards.any((c) => c.id == cardToDelete.id),
    isFalse,
  );
});
```

---

## 5. 实施检查清单

- [ ] 实现`HomeScreenState`状态管理
- [ ] 实现卡片列表UI
- [ ] 实现搜索功能
- [ ] 实现同步状态指示器
- [ ] 实现新建卡片功能
- [ ] 实现卡片编辑功能
- [ ] 实现卡片删除功能
- [ ] 编写单元测试
- [ ] 编写集成测试
- [ ] 验证与Rust API的桥接

---

## 6. 版本历史

| 版本 | 日期 | 变更 |
|-----|------|------|
| 1.0.0 | 2026-01-14 | 初始版本 |

---

## Test Implementation

### Test File
`test/specs/home_screen_spec_test.dart`

### Test Coverage
- ✅ Home Screen Layout Tests (8 tests)
- ✅ Card List Display Tests (6 tests)
- ✅ Search Functionality Tests (7 tests)
- ✅ Card Actions Tests (5 tests)
- ✅ Empty State Tests (4 tests)
- ✅ Performance Tests (3 tests)

### Running Tests
```bash
flutter test test/specs/home_screen_spec_test.dart
```

### Coverage Report
Last updated: 2026-01-18
- Scenarios covered: 33/33 (100%)
- Test cases: 33
- All tests passing: ✅

### Test Examples
```dart
testWidgets('it_should_display_card_list_on_home_screen', (WidgetTester tester) async {
  // Given: 用户有多个卡片
  mockCardService.cards = [card1, card2, card3];
  
  // When: 主屏幕加载
  await tester.pumpWidget(createTestWidget(HomeScreen()));
  await tester.pumpAndSettle();
  
  // Then: 应该显示所有卡片
  expect(find.byType(NoteCard), findsNWidgets(3));
});
```

### Related Specs
- SP-UI-005: [home_screen_ui_spec_test.dart](../../test/specs/home_screen_ui_spec_test.dart)
- SP-UI-007: [note_card_component_spec_test.dart](../../test/specs/note_card_component_spec_test.dart)
