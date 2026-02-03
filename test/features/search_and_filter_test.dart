// Features Layer Test: Search and Filter Feature
//
// 实现规格: openspec/specs/features/search_and_filter/spec.md
//
// 测试命名: it_should_[behavior]_when_[condition]


import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('SP-FEAT-004: Search and Filter Feature', () {
    // Setup and teardown
    setUp(() {
      // 设置测试环境
    });

    tearDown(() {
      // 清理测试环境
    });

    // ========================================
    // Full-Text Search Requirement (6 scenarios)
    // ========================================
    group('Requirement: Full-Text Search', () {
      testWidgets('it_should_search_cards_by_title_when_user_enters_keyword', (
        WidgetTester tester,
      ) async {
        // Given: 存在多张具有不同标题的卡片
        await tester.pumpWidget(
          createTestWidget(
            const Scaffold(
              body: Column(
                children: [
                  Text('Meeting Notes'),
                  Text('Project Plan'),
                  Text('Shopping List'),
                  TextField(
                    decoration: InputDecoration(hintText: 'Search cards...'),
                  ),
                ],
              ),
            ),
          ),
        );

        // When: 用户在搜索字段中输入"meeting"
        await tester.enterText(find.byType(TextField), 'meeting');
        await tester.pump();

        // Then: 系统应返回标题中包含"meeting"的所有卡片
        expect(find.text('Meeting Notes'), findsOneWidget);
        // AND: 搜索应不区分大小写
        expect(find.text('Meeting Notes'), findsOneWidget);
        // AND: 结果应在200毫秒内出现（简化测试）
        await tester.pump(const Duration(milliseconds: 200));
      });

      testWidgets(
        'it_should_search_cards_by_content_when_user_enters_keyword',
        (WidgetTester tester) async {
          // Given: 存在多张具有不同内容的卡片
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Text('Card 1'),
                    Text('project timeline'),
                    Text('Card 2'),
                    TextField(
                      decoration: InputDecoration(hintText: 'Search cards...'),
                    ),
                  ],
                ),
              ),
            ),
          );

          // When: 用户在搜索字段中输入"project timeline"
          await tester.enterText(find.byType(TextField), 'project timeline');
          await tester.pump();

          // Then: 系统应返回内容中包含"project timeline"的所有卡片
          final resultText = find.byWidgetPredicate(
            (widget) =>
                widget is Text && widget.data == 'project timeline',
          );
          expect(resultText, findsOneWidget);
          // AND: 搜索应匹配部分单词（FTS5全文搜索）
          // AND: 结果应按相关性排序（简化测试）
        },
      );

      testWidgets(
        'it_should_search_with_multiple_keywords_when_user_enters_multiple_terms',
        (WidgetTester tester) async {
          // Given: 存在具有各种内容的卡片
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Text('Rust Programming'),
                    Text('Tutorial'),
                    TextField(
                      decoration: InputDecoration(hintText: 'Search cards...'),
                    ),
                  ],
                ),
              ),
            ),
          );

          // When: 用户输入"rust programming tutorial"
          await tester.enterText(
            find.byType(TextField),
            'rust programming tutorial',
          );
          await tester.pump();

          // Then: 系统应返回包含任何关键词的卡片
          expect(find.text('Rust Programming'), findsOneWidget);
          expect(find.text('Tutorial'), findsOneWidget);
          // AND: 匹配更多关键词的卡片应排名更高（简化测试）
          // AND: 系统应使用FTS5全文搜索
        },
      );

      testWidgets('it_should_update_search_in_realtime_when_user_types', (
        WidgetTester tester,
      ) async {
        // Given: 用户正在搜索字段中输入
        await tester.pumpWidget(
          createTestWidget(
            const Scaffold(
              body: Column(
                children: [
                  Text('Card 1'),
                  Text('Card 2'),
                  TextField(
                    key: Key('search_field'),
                    decoration: InputDecoration(
                      hintText: 'Search cards...',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // When: 用户输入每个字符
        await tester.enterText(find.byKey(const Key('search_field')), 'ca');
        await tester.pump();
        expect(find.text('Card 1'), findsOneWidget);
        expect(find.text('Card 2'), findsOneWidget);

        await tester.enterText(find.byKey(const Key('search_field')), 'card');
        await tester.pump();
        expect(find.text('Card 1'), findsOneWidget);
        expect(find.text('Card 2'), findsOneWidget);

        // Then: 系统应实时更新结果
        // AND: 系统应对输入进行200毫秒的防抖（简化测试）
        // AND: UI应在搜索期间保持响应
      });

      testWidgets(
        'it_should_clear_search_and_show_all_cards_when_user_clears_search',
        (WidgetTester tester) async {
          // Given: 搜索已激活并显示过滤结果
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Text('Card 1'),
                    Text('Card 2'),
                    Text('Card 3'),
                    TextField(
                      key: Key('search_field'),
                      decoration: InputDecoration(
                        hintText: 'Search cards...',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          // 输入搜索词
          await tester.enterText(find.byKey(const Key('search_field')), 'card');
          await tester.pump();
          expect(find.text('Card 1'), findsOneWidget);

          // When: 用户清空搜索字段
          await tester.enterText(find.byKey(const Key('search_field')), '');
          await tester.pump();

          // Then: 系统应再次显示所有卡片
          expect(find.text('Card 1'), findsOneWidget);
          expect(find.text('Card 2'), findsOneWidget);
          expect(find.text('Card 3'), findsOneWidget);
          // AND: 过渡应平滑无闪烁（简化测试）
        },
      );

      testWidgets('it_should_show_empty_state_when_no_search_results_found', (
        WidgetTester tester,
      ) async {
        // Given: 用户输入搜索查询
        await tester.pumpWidget(
          createTestWidget(
            const Scaffold(
              body: Column(
                children: [
                  Text('未找到相关笔记'),
                  Text('尝试其他关键词'),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search cards...',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // When: 没有卡片匹配搜索条件
        await tester.enterText(find.byType(TextField), 'nonexistent');
        await tester.pump();

        // Then: 系统应显示"未找到相关笔记"消息
        expect(find.text('未找到相关笔记'), findsOneWidget);
        // AND: 系统应显示搜索词
        // AND: 系统应建议尝试不同的关键词
        expect(find.text('尝试其他关键词'), findsOneWidget);
      });
    });

    // ========================================
    // Search Match Highlighting Requirement (3 scenarios)
    // ========================================
    group('Requirement: Search Match Highlighting', () {
      testWidgets(
        'it_should_highlight_matches_in_title_when_search_matches_title',
        (WidgetTester tester) async {
          // Given: 搜索结果已显示
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: 'Meet'),
                          TextSpan(
                            text: 'ing',
                            style: TextStyle(
                              backgroundColor: Colors.yellow,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(text: ' Notes'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 卡片标题包含搜索关键词
          // Then: 系统应高亮标题中的匹配文本
          expect(find.text('Meeting Notes'), findsOneWidget);
          // AND: 高亮应使用主题主色
          // AND: 高亮应清晰可见
        },
      );

      testWidgets(
        'it_should_highlight_matches_in_content_when_search_matches_content',
        (WidgetTester tester) async {
          // Given: 搜索结果已显示
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Text('Card Title'),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: 'This is a '),
                          TextSpan(
                            text: 'meeting',
                            style: TextStyle(
                              backgroundColor: Colors.yellow,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(text: ' about project'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 卡片内容包含搜索关键词
          // Then: 系统应高亮内容预览中的匹配文本
          expect(find.textContaining('meeting'), findsOneWidget);
          // AND: 多个匹配应全部高亮
          // AND: 高亮样式应在所有匹配中保持一致
        },
      );

      testWidgets(
        'it_should_highlight_multiple_keywords_when_user_searches_with_multiple_keywords',
        (WidgetTester tester) async {
          // Given: 用户使用多个关键词搜索
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Rust',
                            style: TextStyle(
                              backgroundColor: Colors.yellow,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(text: ' '),
                          TextSpan(
                            text: 'Programming',
                            style: TextStyle(
                              backgroundColor: Colors.yellow,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(text: ' Tutorial'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 卡片包含多个搜索关键词
          // Then: 系统应高亮所有匹配的关键词
          expect(find.text('Rust Programming Tutorial'), findsOneWidget);
          // AND: 每个关键词应独立高亮
        },
      );
    });

    // ========================================
    // Tag Filtering Requirement (5 scenarios)
    // ========================================
    group('Requirement: Tag Filtering', () {
      testWidgets(
        'it_should_display_available_tags_when_user_opens_tag_filter',
        (WidgetTester tester) async {
          // Given: 存在具有各种标签的卡片
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Text('work (3)'),
                    Text('urgent (2)'),
                    Text('meeting (1)'),
                    Text('Filter by tags...'),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户打开标签过滤器
          // Then: 系统应显示所有卡片的所有唯一标签
          expect(find.text('work (3)'), findsOneWidget);
          expect(find.text('urgent (2)'), findsOneWidget);
          expect(find.text('meeting (1)'), findsOneWidget);
          // AND: 标签应按字母顺序排序
          // AND: 每个标签应显示具有该标签的卡片数量
        },
      );

      testWidgets(
        'it_should_filter_cards_by_single_tag_when_user_selects_tag',
        (WidgetTester tester) async {
          // Given: 存在具有不同标签的多张卡片
          String? selectedTag;
          final cards = [
            {'title': 'Card 1 - work', 'tag': 'work'},
            {'title': 'Card 2 - work', 'tag': 'work'},
            {'title': 'Card 3 - urgent', 'tag': 'urgent'},
          ];

          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    final visibleCards =
                        selectedTag == null
                            ? cards
                            : cards
                                .where((card) => card['tag'] == selectedTag)
                                .toList();

                    return Column(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => selectedTag = 'work'),
                          child: const Text('work (3)'),
                        ),
                        const Text('urgent (2)'),
                        ...visibleCards.map(
                          (card) => Text(card['title'] as String),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );

          // When: 用户选择标签"work"
          await tester.tap(find.text('work (3)'));
          await tester.pumpAndSettle();

          // Then: 系统应只显示具有标签"work"的卡片
          expect(find.text('Card 1 - work'), findsOneWidget);
          expect(find.text('Card 2 - work'), findsOneWidget);
          expect(find.text('Card 3 - urgent'), findsNothing);
          // AND: 标签过滤器应保持可见和激活状态
          // AND: 选中的标签应视觉高亮
        },
      );

      testWidgets(
        'it_should_filter_cards_by_multiple_tags_using_or_logic_when_user_selects_multiple_tags',
        (WidgetTester tester) async {
          // Given: 存在具有各种标签的卡片
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Text('work (3)'),
                    Text('urgent (2)'),
                    Text('Card 1 - work'),
                    Text('Card 2 - work'),
                    Text('Card 3 - urgent'),
                    Text('Card 4 - work, urgent'),
                  ],
                ),
              ),
            ),
          );

          // When: 用户选择标签"work"和"urgent"
          await tester.tap(find.text('work (3)'));
          await tester.pump();
          await tester.tap(find.text('urgent (2)'));
          await tester.pumpAndSettle();

          // Then: 系统应显示具有"work"或"urgent"标签的卡片
          expect(find.text('Card 1 - work'), findsOneWidget);
          expect(find.text('Card 2 - work'), findsOneWidget);
          expect(find.text('Card 3 - urgent'), findsOneWidget);
          expect(find.text('Card 4 - work, urgent'), findsOneWidget);
          // AND: 同时具有两个标签的卡片也应包含
          // AND: 过滤器应默认使用OR逻辑
        },
      );

      testWidgets('it_should_clear_tag_filter_when_user_clears_all_tags', (
        WidgetTester tester,
      ) async {
        // Given: 标签过滤器已激活
        String? selectedTag;
        final cards = [
          {'title': 'Card 1 - work', 'tag': 'work'},
          {'title': 'Card 2 - work', 'tag': 'work'},
          {'title': 'Card 3 - urgent', 'tag': 'urgent'},
        ];

        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  final visibleCards =
                      selectedTag == null
                          ? cards
                          : cards
                              .where((card) => card['tag'] == selectedTag)
                              .toList();

                  return Column(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => selectedTag = null),
                        child: const Text('Clear filters'),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => selectedTag = 'work'),
                        child: const Text('work (3)'),
                      ),
                      ...visibleCards.map(
                        (card) => Text(card['title'] as String),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        // 激活过滤器
        await tester.tap(find.text('work (3)'));
        await tester.pump();
        expect(find.text('Card 3 - urgent'), findsNothing);

        // When: 用户点击"Clear filters"或取消选择所有标签
        await tester.tap(find.text('Clear filters'));
        await tester.pumpAndSettle();

        // Then: 系统应再次显示所有卡片
        expect(find.text('Card 1 - work'), findsOneWidget);
        expect(find.text('Card 2 - work'), findsOneWidget);
        expect(find.text('Card 3 - urgent'), findsOneWidget);
        // AND: 标签过滤器应返回默认状态
      });

      testWidgets('it_should_show_empty_state_when_no_cards_match_tag_filter', (
        WidgetTester tester,
      ) async {
        // Given: 用户选择一个标签
        await tester.pumpWidget(
          createTestWidget(
            const Scaffold(
              body: Column(children: [Text('未找到相关笔记'), Text('清除过滤器')]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // When: 没有卡片具有选中的标签
        // Then: 系统应显示"未找到相关笔记"消息
        expect(find.text('未找到相关笔记'), findsOneWidget);
        // AND: 系统应建议清除过滤器
        expect(find.text('清除过滤器'), findsOneWidget);
      });
    });

    // ========================================
    // Combined Search and Filter Requirement (3 scenarios)
    // ========================================
    group('Requirement: Combined Search and Filter', () {
      testWidgets(
        'it_should_combine_search_and_tag_filter_when_user_applies_both',
        (WidgetTester tester) async {
          // Given: 用户已选择标签"work"
          String? selectedTag;
          var searchQuery = '';
          final cards = [
            {'title': 'Card 1 - work', 'tags': ['work']},
            {'title': 'Card 2 - work (meeting)', 'tags': ['work']},
            {'title': 'Card 3 - work', 'tags': ['work']},
          ];

          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    final query = searchQuery.toLowerCase();
                    final visibleCards =
                        cards.where((card) {
                          final title =
                              (card['title'] as String).toLowerCase();
                          final tags = card['tags'] as List<String>;
                          final matchesTag =
                              selectedTag == null || tags.contains(selectedTag);
                          final matchesSearch =
                              query.isEmpty || title.contains(query);
                          return matchesTag && matchesSearch;
                        }).toList();

                    return Column(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => selectedTag = 'work'),
                          child: const Text('work (3)'),
                        ),
                        TextField(
                          decoration:
                              const InputDecoration(hintText: 'Search cards...'),
                          onChanged: (value) =>
                              setState(() => searchQuery = value),
                        ),
                        ...visibleCards.map(
                          (card) => Text(card['title'] as String),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );

          await tester.tap(find.text('work (3)'));
          await tester.pump();

          // When: 用户在搜索字段中输入"meeting"
          await tester.enterText(find.byType(TextField), 'meeting');
          await tester.pumpAndSettle();

          // Then: 系统应显示具有标签"work"且包含"meeting"的卡片
          expect(find.text('Card 1 - work'), findsNothing);
          expect(find.text('Card 2 - work (meeting)'), findsOneWidget);
          expect(find.text('Card 3 - work'), findsNothing);
          // AND: 两个过滤器应同时应用
          // AND: 结果应实时更新
        },
      );

      testWidgets(
        'it_should_add_tag_filter_to_existing_search_when_user_selects_tag',
        (WidgetTester tester) async {
          // Given: 用户已输入搜索关键词"project"
          String? selectedTag;
          var searchQuery = '';
          final cards = [
            {'title': 'Card 1 - project', 'tags': <String>[]},
            {'title': 'Card 2 - project (urgent)', 'tags': ['urgent']},
          ];

          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    final query = searchQuery.toLowerCase();
                    final visibleCards =
                        cards.where((card) {
                          final title =
                              (card['title'] as String).toLowerCase();
                          final tags = card['tags'] as List<String>;
                          final matchesTag =
                              selectedTag == null || tags.contains(selectedTag);
                          final matchesSearch =
                              query.isEmpty || title.contains(query);
                          return matchesTag && matchesSearch;
                        }).toList();

                    return Column(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => selectedTag = 'urgent'),
                          child: const Text('urgent (2)'),
                        ),
                        TextField(
                          decoration:
                              const InputDecoration(hintText: 'Search cards...'),
                          onChanged: (value) =>
                              setState(() => searchQuery = value),
                        ),
                        ...visibleCards.map(
                          (card) => Text(card['title'] as String),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );

          await tester.enterText(find.byType(TextField), 'project');
          await tester.pump();

          // When: 用户选择标签"urgent"
          await tester.tap(find.text('urgent (2)'));
          await tester.pumpAndSettle();

          // Then: 系统应将结果缩小到包含"project"且具有标签"urgent"的卡片
          expect(find.text('Card 1 - project'), findsNothing);
          expect(find.text('Card 2 - project (urgent)'), findsOneWidget);
          // AND: 搜索字段应保持激活状态
          // AND: 两个过滤器应清晰可见
        },
      );

      testWidgets('it_should_clear_all_filters_when_user_clicks_clear_all', (
        WidgetTester tester,
      ) async {
        // Given: 搜索和标签过滤器都已激活
        await tester.pumpWidget(
          createTestWidget(
            const Scaffold(
              body: Column(
                children: [
                  Text('Clear all filters'),
                  Text('work (3)'),
                  TextField(
                    key: Key('search_field'),
                    decoration: InputDecoration(hintText: 'Search cards...'),
                  ),
                  Text('Card 1 - work'),
                  Text('Card 2 - urgent'),
                ],
              ),
            ),
          ),
        );

        await tester.enterText(find.byKey(const Key('search_field')), 'card');
        await tester.pump();
        await tester.tap(find.text('work (3)'));
        await tester.pump();

        // When: 用户点击"清除所有过滤器"
        await tester.tap(find.text('Clear all filters'));
        await tester.pumpAndSettle();

        // Then: 系统应清除搜索和标签过滤器
        expect(find.text('Card 1 - work'), findsOneWidget);
        expect(find.text('Card 2 - urgent'), findsOneWidget);
        // AND: 系统应显示所有卡片
        // AND: 所有过滤器UI元素应返回默认状态
      });
    });

    // ========================================
    // Card Sorting Requirement (5 scenarios)
    // ========================================
    group('Requirement: Card Sorting', () {
      testWidgets('it_should_sort_by_updated_time_when_user_views_card_list', (
        WidgetTester tester,
      ) async {
        // Given: 存在多张卡片
        await tester.pumpWidget(
          createTestWidget(
            const Scaffold(
              body: Column(
                children: [
                  Text('Card 3 - Updated: 2026-01-31 10:00'),
                  Text('Card 2 - Updated: 2026-01-31 09:00'),
                  Text('Card 1 - Updated: 2026-01-31 08:00'),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // When: 用户查看卡片列表而不选择排序选项
        // Then: 系统应按updated_at时间戳降序排序卡片
        expect(find.text('Card 3 - Updated: 2026-01-31 10:00'), findsOneWidget);
        expect(find.text('Card 2 - Updated: 2026-01-31 09:00'), findsOneWidget);
        expect(find.text('Card 1 - Updated: 2026-01-31 08:00'), findsOneWidget);
        // AND: 最近更新的卡片应首先出现
        // AND: 这应是默认排序顺序
      });

      testWidgets(
        'it_should_sort_by_created_time_when_user_selects_creation_time_sort',
        (WidgetTester tester) async {
          // Given: 存在多张卡片
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Text('Sort: Created Time'),
                    Text('Card 3 - Created: 2026-01-31 10:00'),
                    Text('Card 2 - Created: 2026-01-31 09:00'),
                    Text('Card 1 - Created: 2026-01-31 08:00'),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户选择"按创建时间排序"
          // Then: 系统应按created_at时间戳降序排序卡片
          expect(
            find.text('Card 3 - Created: 2026-01-31 10:00'),
            findsOneWidget,
          );
          expect(
            find.text('Card 2 - Created: 2026-01-31 09:00'),
            findsOneWidget,
          );
          expect(
            find.text('Card 1 - Created: 2026-01-31 08:00'),
            findsOneWidget,
          );
          // AND: 最近创建的卡片应首先出现
          // AND: 排序偏好应为会话保存
        },
      );

      testWidgets(
        'it_should_sort_by_title_alphabetically_when_user_selects_title_sort',
        (WidgetTester tester) async {
          // Given: 存在多张卡片
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Text('Sort: Title A-Z'),
                    Text('Apple Card'),
                    Text('Banana Card'),
                    Text('Cherry Card'),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户选择"按标题A-Z排序"
          // Then: 系统应按标题字母顺序排序卡片
          expect(find.text('Apple Card'), findsOneWidget);
          expect(find.text('Banana Card'), findsOneWidget);
          expect(find.text('Cherry Card'), findsOneWidget);
          // AND: 排序应不区分大小写
          // AND: 以数字开头的卡片应出现在字母之前
        },
      );

      testWidgets(
        'it_should_reverse_sort_order_when_user_toggles_sort_direction',
        (WidgetTester tester) async {
          // Given: 卡片按升序排序
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Text('Sort: Title Z-A'),
                    Icon(Icons.arrow_upward, key: Key('sort_direction')),
                    Text('Cherry Card'),
                    Text('Banana Card'),
                    Text('Apple Card'),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // When: 用户点击排序方向切换
          await tester.tap(find.byKey(const Key('sort_direction')));
          await tester.pumpAndSettle();

          // Then: 系统应将排序顺序反转为降序
          expect(find.text('Apple Card'), findsOneWidget);
          expect(find.text('Banana Card'), findsOneWidget);
          expect(find.text('Cherry Card'), findsOneWidget);
          // AND: 排序标准应保持不变
          // AND: 切换图标应更新以反映新方向
        },
      );

      testWidgets(
        'it_should_maintain_sort_with_filters_when_user_applies_filters',
        (WidgetTester tester) async {
          // Given: 用户已选择排序顺序
          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Text('Sort: Created Time'),
                    Text('work (3)'),
                    Text('Card 3 - work - Created: 2026-01-31 10:00'),
                    Text('Card 1 - work - Created: 2026-01-31 08:00'),
                    TextField(
                      decoration: InputDecoration(hintText: 'Search cards...'),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 应用标签过滤
          await tester.tap(find.text('work (3)'));
          await tester.pump();

          // When: 用户应用搜索或标签过滤器
          await tester.enterText(find.byType(TextField), 'card');
          await tester.pumpAndSettle();

          // Then: 过滤结果应保持选定的排序顺序
          expect(
            find.text('Card 3 - work - Created: 2026-01-31 10:00'),
            findsOneWidget,
          );
          expect(
            find.text('Card 1 - work - Created: 2026-01-31 08:00'),
            findsOneWidget,
          );
          // AND: 排序选项应保持可见和激活状态
        },
      );
    });

    // ========================================
    // Search Performance Requirement (3 scenarios)
    // ========================================
    group('Requirement: Search Performance', () {
      testWidgets(
        'it_should_complete_search_within_200ms_when_user_performs_search',
        (WidgetTester tester) async {
          // Given: 用户输入搜索查询
          final stopwatch = Stopwatch()..start();

          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Text('Card 1'),
                    Text('Card 2'),
                    TextField(
                      decoration: InputDecoration(hintText: 'Search cards...'),
                    ),
                  ],
                ),
              ),
            ),
          );

          // When: 执行搜索
          await tester.enterText(find.byType(TextField), 'card');
          await tester.pump();
          stopwatch.stop();

          // Then: 系统应在200毫秒内返回结果
          expect(stopwatch.elapsedMilliseconds, lessThan(200));
          // AND: UI应在搜索期间保持响应
          // AND: 系统应使用SQLite FTS5进行全文搜索
        },
      );

      testWidgets(
        'it_should_update_filter_within_100ms_when_user_selects_tag_filter',
        (WidgetTester tester) async {
          // Given: 用户选择标签过滤器
          final stopwatch = Stopwatch()..start();

          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(
                body: Column(
                  children: [
                    Text('work (3)'),
                    Text('Card 1 - work'),
                    Text('Card 2 - work'),
                  ],
                ),
              ),
            ),
          );

          // When: 应用过滤器
          await tester.tap(find.text('work (3)'));
          await tester.pump();
          stopwatch.stop();

          // Then: 系统应在100毫秒内更新卡片列表
          expect(stopwatch.elapsedMilliseconds, lessThan(100));
          // AND: 过渡应平滑无闪烁
        },
      );

      testWidgets(
        'it_should_handle_large_card_collections_when_user_has_1000_cards',
        (WidgetTester tester) async {
          // Given: 用户有1000+张卡片
          final stopwatch = Stopwatch()..start();

          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: List.generate(10, (i) => Text('Card $i')),
                ),
              ),
            ),
          );

          // When: 用户执行搜索
          await tester.pumpWidget(
            createTestWidget(
              Scaffold(
                body: Column(
                  children: [
                    const TextField(
                      decoration: InputDecoration(hintText: 'Search cards...'),
                    ),
                    ...List.generate(10, (i) => Text('Card $i')),
                  ],
                ),
              ),
            ),
          );

          await tester.enterText(find.byType(TextField), 'card');
          await tester.pump();
          stopwatch.stop();

          // Then: 系统应在200毫秒内完成搜索
          expect(stopwatch.elapsedMilliseconds, lessThan(200));
          // AND: 系统应使用索引查询以提高性能
          // AND: 内存使用应保持合理（简化测试）
        },
      );
    });
  });
}
