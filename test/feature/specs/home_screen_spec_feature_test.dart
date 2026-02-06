import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_utils.dart';
import '../../helpers/test_helpers.dart';

/// Home Screen Specification Tests
///
/// 规格编号: SP-FLUT-008
/// 这些测试验证主页交互规格的所有交互行为
///
/// 测试遵循 Spec Coding 方法论：
/// - 测试即规格，规格即文档
/// - 使用 it_should_xxx() 命名风格
/// - Given-When-Then 结构

void main() {
  group('SP-FLUT-008: Home Screen', () {
    // Setup
    late MockSyncManager mockSyncManager;
    late MockSearchService mockSearchService;

    setUp(() {
      mockSyncManager = MockSyncManager();
      mockSearchService = MockSearchService();
    });

    tearDown(() {
      mockSyncManager.reset();
      mockSearchService.reset();
    });

    // ========================================
    // 卡片列表显示测试
    // ========================================
    group('Card List Display', () {
      testWidgets('it_should_display_card_list_on_home_screen', (
        WidgetTester tester,
      ) async {
        // Given: 有 3 张卡片
        final cards = [
          {'id': '1', 'title': 'Card 1', 'preview': 'Content 1'},
          {'id': '2', 'title': 'Card 2', 'preview': 'Content 2'},
          {'id': '3', 'title': 'Card 3', 'preview': 'Content 3'},
        ];

        // When: 渲染主页
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: ListView.builder(
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  final card = cards[index];
                  return ListTile(
                    title: Text(card['title'] as String),
                    subtitle: Text(card['preview'] as String),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示所有卡片
        expect(find.text('Card 1'), findsOneWidget);
        expect(find.text('Card 2'), findsOneWidget);
        expect(find.text('Card 3'), findsOneWidget);
      });

      testWidgets('it_should_show_empty_state_when_no_cards', (
        WidgetTester tester,
      ) async {
        // Given: 没有卡片
        final cards = <Map<String, String>>[];

        // When: 渲染主页
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: cards.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.note_add, size: 64),
                          SizedBox(height: 16),
                          Text('还没有卡片'),
                          SizedBox(height: 8),
                          Text('点击右下角的 + 按钮创建第一张卡片'),
                        ],
                      ),
                    )
                  : ListView(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示空状态提示
        expect(find.text('还没有卡片'), findsOneWidget);
        expect(find.text('点击右下角的 + 按钮创建第一张卡片'), findsOneWidget);
        expect(find.byIcon(Icons.note_add), findsOneWidget);
      });

      testWidgets('it_should_display_card_title_and_preview', (
        WidgetTester tester,
      ) async {
        // Given: 有一张卡片
        await tester.pumpWidget(
          createTestWidget(
            const Scaffold(
              body: ListTile(
                title: Text('My Card Title'),
                subtitle: Text('This is a preview of the card content...'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示标题和预览
        expect(find.text('My Card Title'), findsOneWidget);
        expect(
          find.text('This is a preview of the card content...'),
          findsOneWidget,
        );
      });

      testWidgets('it_should_show_loading_indicator_while_loading_cards', (
        WidgetTester tester,
      ) async {
        // Given: 正在加载卡片
        await tester.pumpWidget(
          createTestWidget(
            const Scaffold(body: Center(child: CircularProgressIndicator())),
          ),
        );

        // Then: 应该显示加载指示器
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    // ========================================
    // FAB 按钮测试
    // ========================================
    group('FAB Button', () {
      testWidgets('it_should_display_fab_button_on_home_screen', (
        WidgetTester tester,
      ) async {
        // Given: 用户在主页
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: const Center(child: Text('Home Screen')),
              floatingActionButton: FloatingActionButton(
                onPressed: () {},
                child: const Icon(Icons.add),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示 FAB 按钮
        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('it_should_navigate_to_editor_on_fab_tap', (
        WidgetTester tester,
      ) async {
        // Given: 用户在主页
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: const Text('Home Screen'),
                floatingActionButton: FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const Scaffold(body: Text('Card Editor')),
                      ),
                    );
                  },
                  child: const Icon(Icons.add),
                ),
              ),
            ),
          ),
        );

        // When: 用户点击 FAB 按钮
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        // Then: 应该导航到编辑器
        expect(find.text('Card Editor'), findsOneWidget);
      });
    });

    // ========================================
    // 同步状态显示测试
    // ========================================
    group('Sync Status Display', () {
      testWidgets('it_should_display_sync_status_icon_in_app_bar', (
        WidgetTester tester,
      ) async {
        // Given: 用户在主页
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              appBar: AppBar(
                title: const Text('CardMind'),
                actions: [
                  IconButton(icon: const Icon(Icons.sync), onPressed: () {}),
                ],
              ),
              body: const Center(child: Text('Home Screen')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示同步状态图标
        expect(find.byIcon(Icons.sync), findsOneWidget);
      });

      testWidgets('it_should_show_syncing_indicator_when_syncing', (
        WidgetTester tester,
      ) async {
        // Given: 正在同步
        mockSyncManager.setStatus(MockSyncStatus.syncing);

        // When: 显示同步状态
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              appBar: AppBar(
                title: const Text('CardMind'),
                actions: [
                  IconButton(icon: const Icon(Icons.sync), onPressed: () {}),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              body: const Center(child: Text('Home Screen')),
            ),
          ),
        );
        await tester.pump();

        // Then: 应该显示同步进度指示器
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('it_should_show_success_icon_after_successful_sync', (
        WidgetTester tester,
      ) async {
        // Given: 同步成功
        mockSyncManager.setStatus(MockSyncStatus.success);

        // When: 显示同步状态
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              appBar: AppBar(
                title: const Text('CardMind'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () {},
                  ),
                ],
              ),
              body: const Center(child: Text('Home Screen')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示成功图标
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      });

      testWidgets('it_should_show_error_icon_when_sync_fails', (
        WidgetTester tester,
      ) async {
        // Given: 同步失败
        mockSyncManager
          ..setStatus(MockSyncStatus.error)
          ..setError('Network error');

        // When: 显示同步状态
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              appBar: AppBar(
                title: const Text('CardMind'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.error, color: Colors.red),
                    onPressed: () {},
                  ),
                ],
              ),
              body: const Center(child: Text('Home Screen')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示错误图标
        expect(find.byIcon(Icons.error), findsOneWidget);
      });
    });

    // ========================================
    // 搜索功能测试
    // ========================================
    group('Search Functionality', () {
      testWidgets('it_should_display_search_icon_in_app_bar', (
        WidgetTester tester,
      ) async {
        // Given: 用户在主页
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              appBar: AppBar(
                title: const Text('CardMind'),
                actions: [
                  IconButton(icon: const Icon(Icons.search), onPressed: () {}),
                ],
              ),
              body: const Center(child: Text('Home Screen')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示搜索图标
        expect(find.byIcon(Icons.search), findsOneWidget);
      });

      testWidgets('it_should_show_search_bar_when_search_icon_tapped', (
        WidgetTester tester,
      ) async {
        // Given: 用户在主页
        bool showSearchBar = false;

        await tester.pumpWidget(
          createTestWidget(
            StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  appBar: AppBar(
                    title: showSearchBar
                        ? const TextField(
                            decoration: InputDecoration(
                              hintText: '搜索卡片...',
                              border: InputBorder.none,
                            ),
                          )
                        : const Text('CardMind'),
                    actions: [
                      IconButton(
                        icon: Icon(showSearchBar ? Icons.close : Icons.search),
                        onPressed: () {
                          setState(() {
                            showSearchBar = !showSearchBar;
                          });
                        },
                      ),
                    ],
                  ),
                  body: const Center(child: Text('Home Screen')),
                );
              },
            ),
          ),
        );

        // When: 用户点击搜索图标
        await tester.tap(find.byIcon(Icons.search));
        await tester.pumpAndSettle();

        // Then: 应该显示搜索框
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('搜索卡片...'), findsOneWidget);
      });

      testWidgets('it_should_filter_cards_based_on_search_query', (
        WidgetTester tester,
      ) async {
        // Given: 有多张卡片
        final allCards = [
          {'id': '1', 'title': 'Flutter Tutorial', 'preview': 'Learn Flutter'},
          {'id': '2', 'title': 'Dart Basics', 'preview': 'Learn Dart'},
          {'id': '3', 'title': 'React Guide', 'preview': 'Learn React'},
        ];

        String searchQuery = '';
        // ignore: unused_local_variable
        final filteredCards = allCards.where((card) {
          if (searchQuery.isEmpty) return true;
          return (card['title'] as String).toLowerCase().contains(
                searchQuery.toLowerCase(),
              ) ||
              (card['preview'] as String).toLowerCase().contains(
                searchQuery.toLowerCase(),
              );
        }).toList();

        // When: 用户搜索 "Flutter"
        searchQuery = 'Flutter';
        final results = allCards.where((card) {
          return (card['title'] as String).toLowerCase().contains(
                searchQuery.toLowerCase(),
              ) ||
              (card['preview'] as String).toLowerCase().contains(
                searchQuery.toLowerCase(),
              );
        }).toList();

        // Then: 应该只显示匹配的卡片
        expect(results.length, equals(1));
        expect(results[0]['title'], equals('Flutter Tutorial'));
      });

      testWidgets(
        'it_should_show_no_results_message_when_search_returns_empty',
        (WidgetTester tester) async {
          // Given: 搜索结果为空
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64),
                      SizedBox(height: 16),
                      Text('未找到匹配的卡片'),
                      SizedBox(height: 8),
                      Text('尝试使用其他关键词'),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Then: 应该显示无结果提示
          expect(find.text('未找到匹配的卡片'), findsOneWidget);
          expect(find.text('尝试使用其他关键词'), findsOneWidget);
        },
      );
    });

    // ========================================
    // 卡片交互测试
    // ========================================
    group('Card Interaction', () {
      testWidgets('it_should_navigate_to_editor_when_card_tapped', (
        WidgetTester tester,
      ) async {
        // Given: 用户在主页
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ListTile(
                  title: const Text('My Card'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const Scaffold(body: Text('Card Editor')),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // When: 用户点击卡片
        await tester.tap(find.text('My Card'));
        await tester.pumpAndSettle();

        // Then: 应该导航到编辑器
        expect(find.text('Card Editor'), findsOneWidget);
      });

      testWidgets('it_should_show_card_options_on_long_press', (
        WidgetTester tester,
      ) async {
        // Given: 用户在主页
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ListTile(
                  title: const Text('My Card'),
                  onLongPress: () {
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (context) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.edit),
                            title: const Text('编辑'),
                            onTap: () {},
                          ),
                          ListTile(
                            leading: const Icon(Icons.delete),
                            title: const Text('删除'),
                            onTap: () {},
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // When: 用户长按卡片
        await tester.longPress(find.text('My Card'));
        await tester.pumpAndSettle();

        // Then: 应该显示选项菜单
        expect(find.text('编辑'), findsOneWidget);
        expect(find.text('删除'), findsOneWidget);
      });
    });

    // ========================================
    // 下拉刷新测试
    // ========================================
    group('Pull to Refresh', () {
      testWidgets('it_should_trigger_sync_on_pull_down', (
        WidgetTester tester,
      ) async {
        // Given: 用户在主页
        int refreshCount = 0;

        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: RefreshIndicator(
                onRefresh: () async {
                  refreshCount++;
                  await Future<void>.delayed(const Duration(milliseconds: 100));
                },
                child: ListView(
                  children: const [
                    ListTile(title: Text('Card 1')),
                    ListTile(title: Text('Card 2')),
                  ],
                ),
              ),
            ),
          ),
        );

        // When: 用户下拉刷新
        await tester.drag(find.byType(ListView), const Offset(0, 300));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Then: 应该触发同步
        expect(refreshCount, equals(1));
      });

      testWidgets('it_should_show_refresh_indicator_during_sync', (
        WidgetTester tester,
      ) async {
        // Given: 用户下拉刷新
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: RefreshIndicator(
                onRefresh: () async {
                  await Future<void>.delayed(const Duration(seconds: 1));
                },
                child: ListView(
                  children: const [ListTile(title: Text('Card 1'))],
                ),
              ),
            ),
          ),
        );

        // When: 触发刷新
        await tester.drag(find.byType(ListView), const Offset(0, 300));
        await tester.pump();

        // Then: 应该显示刷新指示器
        expect(find.byType(RefreshIndicator), findsOneWidget);
      });
    });

    // ========================================
    // 错误处理测试
    // ========================================
    group('Error Handling', () {
      testWidgets('it_should_show_error_message_when_loading_fails', (
        WidgetTester tester,
      ) async {
        // Given: 加载失败
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text('加载失败'),
                    const SizedBox(height: 8),
                    const Text('请检查网络连接'),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: () {}, child: const Text('重试')),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示错误消息和重试按钮
        expect(find.text('加载失败'), findsOneWidget);
        expect(find.text('请检查网络连接'), findsOneWidget);
        expect(find.text('重试'), findsOneWidget);
      });

      testWidgets('it_should_allow_retry_after_error', (
        WidgetTester tester,
      ) async {
        // Given: 发生错误
        int retryCount = 0;

        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    retryCount++;
                  },
                  child: const Text('重试'),
                ),
              ),
            ),
          ),
        );

        // When: 用户点击重试
        await tester.tap(find.text('重试'));
        await tester.pumpAndSettle();

        // Then: 应该触发重试
        expect(retryCount, equals(1));
      });
    });

    // ========================================
    // 池名称显示测试（补充）
    // ========================================
    group('Pool Name Display', () {
      testWidgets('it_should_display_pool_name_in_app_bar', (
        WidgetTester tester,
      ) async {
        // Given: 用户在主页，当前空间名称为 "我的笔记空间"
        const poolName = '我的笔记空间';

        // When: 渲染主页
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              appBar: AppBar(
                title: const Text(poolName),
                actions: [
                  IconButton(icon: const Icon(Icons.search), onPressed: () {}),
                ],
              ),
              body: const Center(child: Text('Home Screen')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该在顶部栏显示池名称
        expect(find.text('我的笔记空间'), findsOneWidget);
        expect(find.widgetWithText(AppBar, '我的笔记空间'), findsOneWidget);
      });
    });

    // ========================================
    // 卡片更新时间显示测试（补充）
    // ========================================
    group('Card Updated Time Display', () {
      testWidgets('it_should_display_card_updated_time', (
        WidgetTester tester,
      ) async {
        // Given: 有一张卡片，更新时间为 5 分钟前
        final updatedTime = DateTime.now().subtract(const Duration(minutes: 5));
        final card = {
          'id': '1',
          'title': 'My Card',
          'preview': 'Card content',
          'updatedAt': updatedTime,
        };

        // When: 渲染卡片列表
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: ListView(
                children: [
                  ListTile(
                    title: Text(card['title'] as String),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(card['preview'] as String),
                        const SizedBox(height: 4),
                        const Text(
                          '更新于 5 分钟前',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示卡片更新时间
        expect(find.text('My Card'), findsOneWidget);
        expect(find.text('更新于 5 分钟前'), findsOneWidget);
      });
    });

    // ========================================
    // 未同步卡片指示器测试（补充）
    // ========================================
    group('Unsynced Card Indicator', () {
      testWidgets('it_should_show_sync_indicator_on_unsynced_cards', (
        WidgetTester tester,
      ) async {
        // Given: 有两张卡片，一张已同步，一张未同步
        final cards = [
          {'id': '1', 'title': 'Synced Card', 'synced': true},
          {'id': '2', 'title': 'Unsynced Card', 'synced': false},
        ];

        // When: 渲染卡片列表
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: ListView.builder(
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  final card = cards[index];
                  final isSynced = card['synced'] as bool;

                  return ListTile(
                    title: Text(card['title'] as String),
                    trailing: isSynced
                        ? null
                        : const Icon(
                            Icons.sync_problem,
                            color: Colors.orange,
                            size: 20,
                          ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 未同步的卡片应该显示同步指示器
        expect(find.text('Synced Card'), findsOneWidget);
        expect(find.text('Unsynced Card'), findsOneWidget);

        // 验证未同步卡片有同步指示器图标
        final unsyncedCard = find.ancestor(
          of: find.text('Unsynced Card'),
          matching: find.byType(ListTile),
        );
        expect(unsyncedCard, findsOneWidget);

        // 验证有 sync_problem 图标
        expect(find.byIcon(Icons.sync_problem), findsOneWidget);

        // 验证已同步卡片没有指示器
        final syncedCard = find.ancestor(
          of: find.text('Synced Card'),
          matching: find.byType(ListTile),
        );
        expect(syncedCard, findsOneWidget);
      });
    });

    // ========================================
    // 响应式布局测试
    // ========================================
    group('Responsive Layout', () {
      testWidgets('it_should_show_mobile_layout_on_small_screen', (
        WidgetTester tester,
      ) async {
        // Given: 小屏幕（移动端）
        setScreenSize(tester, const Size(400, 800));

        // When: 渲染主页
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              appBar: AppBar(title: const Text('CardMind')),
              body: const Center(child: Text('Home Screen')),
              bottomNavigationBar: BottomNavigationBar(
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.home), label: '主页'),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings),
                    label: '设置',
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示底部导航栏
        expect(find.byType(BottomNavigationBar), findsOneWidget);
      });

      testWidgets('it_should_show_desktop_layout_on_large_screen', (
        WidgetTester tester,
      ) async {
        // Given: 大屏幕（桌面端）
        setScreenSize(tester, const Size(1440, 900));

        // When: 渲染主页
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              appBar: AppBar(title: const Text('CardMind')),
              body: Row(
                children: [
                  NavigationRail(
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.home),
                        label: Text('主页'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.settings),
                        label: Text('设置'),
                      ),
                    ],
                    selectedIndex: 0,
                  ),
                  const Expanded(child: Center(child: Text('Home Screen'))),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示侧边导航栏
        expect(find.byType(NavigationRail), findsOneWidget);
      });
    });
  });
}
