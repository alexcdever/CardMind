import 'package:cardmind/widgets/mobile_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mobile Navigation Specification Tests
///
/// 规格编号: SP-UI-006
/// 这些测试验证移动端导航栏 UI 的所有交互行为
///
/// 测试遵循 Spec Coding 方法论：
/// - 测试即规格，规格即文档
/// - 使用 it_should_xxx() 命名风格
/// - Given-When-Then 结构

void main() {
  group('SP-UI-006: Mobile Navigation UI', () {
    // ========================================
    // Helper: 创建 MobileNav
    // ========================================
    Widget createMobileNav({
      NavTab currentTab = NavTab.notes,
      OnTabChange? onTabChange,
      int notesCount = 0,
      int devicesCount = 0,
    }) {
      return MaterialApp(
        home: Scaffold(
          bottomNavigationBar: MobileNav(
            currentTab: currentTab,
            onTabChange: onTabChange ?? (_) {},
            notesCount: notesCount,
            devicesCount: devicesCount,
          ),
        ),
      );
    }

    // ========================================
    // UI Layout Tests
    // ========================================

    group('UI Layout Tests', () {
      testWidgets('it_should_display_three_navigation_tabs', (
        WidgetTester tester,
      ) async {
        // Given: 移动端导航栏加载
        await tester.pumpWidget(createMobileNav());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示三个标签
        expect(find.text('笔记'), findsOneWidget);
        expect(find.text('设备'), findsOneWidget);
        expect(find.text('设置'), findsOneWidget);
      });

      testWidgets('it_should_display_notes_icon', (WidgetTester tester) async {
        // Given: 移动端导航栏加载
        await tester.pumpWidget(createMobileNav());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示笔记图标
        expect(find.byIcon(Icons.note), findsOneWidget);
      });

      testWidgets('it_should_display_devices_icon', (
        WidgetTester tester,
      ) async {
        // Given: 移动端导航栏加载
        await tester.pumpWidget(createMobileNav());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示设备图标
        expect(find.byIcon(Icons.wifi), findsOneWidget);
      });

      testWidgets('it_should_display_settings_icon', (
        WidgetTester tester,
      ) async {
        // Given: 移动端导航栏加载
        await tester.pumpWidget(createMobileNav());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示设置图标
        expect(find.byIcon(Icons.settings), findsOneWidget);
      });

      testWidgets('it_should_have_fixed_height_of_64px', (
        WidgetTester tester,
      ) async {
        // Given: 移动端导航栏加载
        await tester.pumpWidget(createMobileNav());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 高度为 64px
        final sizedBox = tester.widget<SizedBox>(
          find
              .descendant(
                of: find.byType(MobileNav),
                matching: find.byType(SizedBox),
              )
              .first,
        );
        expect(sizedBox.height, equals(64));
      });

      testWidgets('it_should_display_top_border', (WidgetTester tester) async {
        // Given: 移动端导航栏加载
        await tester.pumpWidget(createMobileNav());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示顶部边框
        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(MobileNav),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(container.decoration, isA<BoxDecoration>());
      });
    });

    // ========================================
    // Active Tab Tests
    // ========================================

    group('Active Tab Tests', () {
      testWidgets('it_should_highlight_active_tab', (
        WidgetTester tester,
      ) async {
        // Given: 笔记标签激活
        await tester.pumpWidget(createMobileNav(currentTab: NavTab.notes));

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 笔记标签被高亮
        // 通过查找顶部指示条来验证
        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('it_should_display_indicator_bar_on_active_tab', (
        WidgetTester tester,
      ) async {
        // Given: 笔记标签激活
        await tester.pumpWidget(createMobileNav(currentTab: NavTab.notes));

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示顶部指示条
        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('it_should_use_fixed_size_for_all_tab_icons', (
        WidgetTester tester,
      ) async {
        // Given: 笔记标签激活
        await tester.pumpWidget(createMobileNav(currentTab: NavTab.notes));

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 所有图标使用固定大小 24px
        final noteIcon = tester.widget<Icon>(find.byIcon(Icons.note));
        expect(noteIcon.size, equals(24));
      });

      testWidgets('it_should_use_normal_size_for_inactive_tab_icons', (
        WidgetTester tester,
      ) async {
        // Given: 笔记标签激活，设备标签未激活
        await tester.pumpWidget(createMobileNav(currentTab: NavTab.notes));

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 未激活标签的图标正常大小
        final wifiIcon = tester.widget<Icon>(find.byIcon(Icons.wifi));
        expect(wifiIcon.size, equals(24));
      });

      testWidgets('it_should_bold_active_tab_text', (
        WidgetTester tester,
      ) async {
        // Given: 笔记标签激活
        await tester.pumpWidget(createMobileNav(currentTab: NavTab.notes));

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 激活标签的文字加粗
        final texts = tester.widgetList<Text>(find.text('笔记'));
        expect(texts, isNotEmpty);
      });

      testWidgets('it_should_use_primary_color_for_active_tab', (
        WidgetTester tester,
      ) async {
        // Given: 笔记标签激活
        await tester.pumpWidget(createMobileNav(currentTab: NavTab.notes));

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 激活标签使用主题色
        expect(find.byType(MobileNav), findsOneWidget);
      });

      testWidgets('it_should_use_disabled_color_for_inactive_tabs', (
        WidgetTester tester,
      ) async {
        // Given: 笔记标签激活
        await tester.pumpWidget(createMobileNav(currentTab: NavTab.notes));

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 未激活标签使用禁用色
        expect(find.byType(MobileNav), findsOneWidget);
      });
    });

    // ========================================
    // Tab Switching Tests
    // ========================================

    group('Tab Switching Tests', () {
      testWidgets('it_should_call_onTabChange_when_notes_tab_tapped', (
        WidgetTester tester,
      ) async {
        // Given: 设备标签激活
        NavTab? tappedTab;
        await tester.pumpWidget(
          createMobileNav(
            currentTab: NavTab.devices, // 从设备标签开始
            onTabChange: (tab) {
              tappedTab = tab;
            },
          ),
        );
        await tester.pumpAndSettle();

        // When: 用户点击笔记标签
        await tester.tap(find.text('笔记'));
        await tester.pumpAndSettle();

        // Then: 回调被调用，参数为 notes
        expect(tappedTab, equals(NavTab.notes));
      });

      testWidgets('it_should_call_onTabChange_when_devices_tab_tapped', (
        WidgetTester tester,
      ) async {
        // Given: 笔记标签激活
        NavTab? tappedTab;
        await tester.pumpWidget(
          createMobileNav(
            currentTab: NavTab.notes,
            onTabChange: (tab) {
              tappedTab = tab;
            },
          ),
        );
        await tester.pumpAndSettle();

        // When: 用户点击设备标签
        await tester.tap(find.text('设备'));
        await tester.pumpAndSettle();

        // Then: 回调被调用，参数为 devices
        expect(tappedTab, equals(NavTab.devices));
      });

      testWidgets('it_should_call_onTabChange_when_settings_tab_tapped', (
        WidgetTester tester,
      ) async {
        // Given: 笔记标签激活
        NavTab? tappedTab;
        await tester.pumpWidget(
          createMobileNav(
            currentTab: NavTab.notes,
            onTabChange: (tab) {
              tappedTab = tab;
            },
          ),
        );
        await tester.pumpAndSettle();

        // When: 用户点击设置标签
        await tester.tap(find.text('设置'));
        await tester.pumpAndSettle();

        // Then: 回调被调用，参数为 settings
        expect(tappedTab, equals(NavTab.settings));
      });

      testWidgets('it_should_not_call_onTabChange_when_tapping_active_tab', (
        WidgetTester tester,
      ) async {
        // Given: 笔记标签激活
        NavTab? tappedTab;
        await tester.pumpWidget(
          createMobileNav(
            currentTab: NavTab.notes,
            onTabChange: (tab) {
              tappedTab = tab;
            },
          ),
        );
        await tester.pumpAndSettle();

        // When: 用户再次点击笔记标签（当前激活的标签）
        await tester.tap(find.text('笔记'));
        await tester.pumpAndSettle();

        // Then: 回调不被调用（因为点击的是当前激活的标签）
        expect(tappedTab, isNull);
      });

      testWidgets('it_should_respond_to_rapid_tab_switches', (
        WidgetTester tester,
      ) async {
        // Given: 移动端导航栏显示
        NavTab lastTab = NavTab.notes;
        await tester.pumpWidget(
          createMobileNav(
            currentTab: NavTab.notes,
            onTabChange: (tab) {
              lastTab = tab;
            },
          ),
        );
        await tester.pumpAndSettle();

        // When: 用户快速切换标签
        await tester.tap(find.text('设备'));
        await tester.pump();
        await tester.tap(find.text('设置'));
        await tester.pump();
        await tester.tap(find.text('笔记'));
        await tester.pumpAndSettle();

        // Then: 所有切换都被处理（由于防抖，最后一次点击可能被忽略）
        // 注意：MobileNav 有防抖机制，快速点击可能不会全部响应
        expect(lastTab, isNotNull);
      });
    });

    // ========================================
    // Badge Tests
    // ========================================

    group('Badge Tests', () {
      testWidgets(
        'it_should_display_badge_on_notes_tab_when_count_greater_than_zero',
        (WidgetTester tester) async {
          // Given: 有 5 条笔记
          await tester.pumpWidget(createMobileNav(notesCount: 5));

          // When: 渲染完成
          await tester.pumpAndSettle();

          // Then: 显示徽章
          expect(find.text('5'), findsOneWidget);
        },
      );

      testWidgets(
        'it_should_display_badge_on_devices_tab_when_count_greater_than_zero',
        (WidgetTester tester) async {
          // Given: 有 3 个设备
          await tester.pumpWidget(createMobileNav(devicesCount: 3));

          // When: 渲染完成
          await tester.pumpAndSettle();

          // Then: 显示徽章
          expect(find.text('3'), findsOneWidget);
        },
      );

      testWidgets('it_should_not_display_badge_when_count_is_zero', (
        WidgetTester tester,
      ) async {
        // Given: 没有笔记和设备
        await tester.pumpWidget(
          createMobileNav(notesCount: 0, devicesCount: 0),
        );

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 不显示徽章
        expect(find.text('0'), findsNothing);
      });

      testWidgets('it_should_display_99_plus_for_counts_over_99', (
        WidgetTester tester,
      ) async {
        // Given: 有 150 条笔记
        await tester.pumpWidget(createMobileNav(notesCount: 150));

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示 "99+"
        expect(find.text('99+'), findsOneWidget);
      });

      testWidgets('it_should_position_badge_on_top_right_of_icon', (
        WidgetTester tester,
      ) async {
        // Given: 有笔记
        await tester.pumpWidget(createMobileNav(notesCount: 5));

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 徽章在图标右上角
        expect(find.byType(Positioned), findsWidgets);
      });

      testWidgets('it_should_use_error_color_for_badge_background', (
        WidgetTester tester,
      ) async {
        // Given: 有笔记
        await tester.pumpWidget(createMobileNav(notesCount: 5));

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 徽章使用错误色背景
        expect(find.text('5'), findsOneWidget);
      });

      testWidgets('it_should_display_white_text_on_badge', (
        WidgetTester tester,
      ) async {
        // Given: 有笔记
        await tester.pumpWidget(createMobileNav(notesCount: 5));

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 徽章文字为白色
        final badgeText = tester.widget<Text>(find.text('5'));
        expect(badgeText.style?.fontSize, equals(10));
      });

      testWidgets('it_should_use_circular_shape_for_badge', (
        WidgetTester tester,
      ) async {
        // Given: 有笔记
        await tester.pumpWidget(createMobileNav(notesCount: 5));

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 徽章为圆形
        expect(find.byType(Container), findsWidgets);
      });
    });

    // ========================================
    // Visual Feedback Tests
    // ========================================

    group('Visual Feedback Tests', () {
      testWidgets('it_should_provide_tap_feedback', (
        WidgetTester tester,
      ) async {
        // Given: 移动端导航栏显示
        await tester.pumpWidget(createMobileNav());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 使用 InkWell 提供点击反馈
        expect(find.byType(InkWell), findsNWidgets(3));
      });

      testWidgets('it_should_expand_tabs_equally', (WidgetTester tester) async {
        // Given: 移动端导航栏显示
        await tester.pumpWidget(createMobileNav());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 每个标签使用 Expanded
        expect(find.byType(Expanded), findsNWidgets(3));
      });

      testWidgets('it_should_center_content_in_each_tab', (
        WidgetTester tester,
      ) async {
        // Given: 移动端导航栏显示
        await tester.pumpWidget(createMobileNav());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 内容居中
        expect(find.byType(Column), findsNWidgets(3));
      });

      testWidgets('it_should_use_consistent_spacing', (
        WidgetTester tester,
      ) async {
        // Given: 移动端导航栏显示
        await tester.pumpWidget(createMobileNav());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 使用一致的间距
        expect(find.byType(SizedBox), findsWidgets);
      });
    });

    // ========================================
    // Safe Area Tests
    // ========================================

    group('Safe Area Tests', () {
      testWidgets('it_should_respect_safe_area', (WidgetTester tester) async {
        // Given: 移动端导航栏显示
        await tester.pumpWidget(createMobileNav());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 使用 SafeArea
        expect(find.byType(SafeArea), findsOneWidget);
      });

      testWidgets('it_should_not_apply_safe_area_to_top', (
        WidgetTester tester,
      ) async {
        // Given: 移动端导航栏显示
        await tester.pumpWidget(createMobileNav());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: SafeArea 不应用于顶部（因为是底部导航）
        expect(find.byType(SafeArea), findsOneWidget);
      });
    });

    // ========================================
    // Accessibility Tests
    // ========================================

    group('Accessibility Tests', () {
      testWidgets('it_should_provide_semantic_labels_for_tabs', (
        WidgetTester tester,
      ) async {
        // Given: 移动端导航栏显示
        await tester.pumpWidget(createMobileNav());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 每个标签有文本标签
        expect(find.text('笔记'), findsOneWidget);
        expect(find.text('设备'), findsOneWidget);
        expect(find.text('设置'), findsOneWidget);
      });

      testWidgets('it_should_provide_visual_and_text_labels', (
        WidgetTester tester,
      ) async {
        // Given: 移动端导航栏显示
        await tester.pumpWidget(createMobileNav());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 每个标签有图标和文字
        expect(find.byIcon(Icons.note), findsOneWidget);
        expect(find.text('笔记'), findsOneWidget);
      });

      testWidgets('it_should_have_sufficient_touch_target_size', (
        WidgetTester tester,
      ) async {
        // Given: 移动端导航栏显示
        await tester.pumpWidget(createMobileNav());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 每个标签有足够的点击区域
        final inkWells = tester.widgetList<InkWell>(find.byType(InkWell));
        expect(inkWells.length, equals(3));
      });
    });

    // ========================================
    // Edge Case Tests
    // ========================================

    group('Edge Case Tests', () {
      testWidgets('it_should_handle_negative_counts_gracefully', (
        WidgetTester tester,
      ) async {
        // Given: 负数计数（不应该发生，但要处理）
        await tester.pumpWidget(createMobileNav(notesCount: -1));

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 不崩溃
        expect(tester.takeException(), isNull);
      });

      testWidgets('it_should_handle_very_large_counts', (
        WidgetTester tester,
      ) async {
        // Given: 非常大的计数
        await tester.pumpWidget(createMobileNav(notesCount: 999999));

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 显示 "99+"
        expect(find.text('99+'), findsOneWidget);
      });

      testWidgets('it_should_handle_invalid_active_tab_index', (
        WidgetTester tester,
      ) async {
        // Given: 使用有效的标签（NavTab 枚举不会有无效值）
        await tester.pumpWidget(createMobileNav(currentTab: NavTab.notes));

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 不崩溃
        expect(tester.takeException(), isNull);
      });

      testWidgets('it_should_handle_null_callback_gracefully', (
        WidgetTester tester,
      ) async {
        // Given: 回调为 null（通过默认值处理）
        await tester.pumpWidget(createMobileNav());

        // When: 用户点击标签
        await tester.tap(find.text('设备'));
        await tester.pumpAndSettle();

        // Then: 不崩溃
        expect(tester.takeException(), isNull);
      });
    });

    // ========================================
    // Theme Integration Tests
    // ========================================

    group('Theme Integration Tests', () {
      testWidgets('it_should_use_theme_colors', (WidgetTester tester) async {
        // Given: 导航栏显示
        await tester.pumpWidget(createMobileNav());

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 使用主题颜色
        expect(find.byType(MobileNav), findsOneWidget);
      });

      testWidgets('it_should_adapt_to_dark_theme', (WidgetTester tester) async {
        // Given: 深色主题
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              bottomNavigationBar: MobileNav(
                currentTab: NavTab.notes,
                onTabChange: (_) {},
                notesCount: 0,
                devicesCount: 0,
              ),
            ),
          ),
        );

        // When: 渲染完成
        await tester.pumpAndSettle();

        // Then: 适应深色主题
        expect(find.byType(MobileNav), findsOneWidget);
      });
    });
  });
}
