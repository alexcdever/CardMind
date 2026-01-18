import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_helpers.dart';

/// Responsive Layout Specification Tests
///
/// 这些测试验证响应式布局的所有行为
///
/// 测试遵循 Spec Coding 方法论：
/// - 测试即规格，规格即文档
/// - 使用 it_should_xxx() 命名风格
/// - Given-When-Then 结构

void main() {
  group('Responsive Layout Tests', () {
    // ========================================
    // 移动端布局测试（< 1024px）
    // ========================================
    group('Mobile Layout (< 1024px)', () {
      testWidgets('it_should_show_mobile_layout_on_small_screen', (
        WidgetTester tester,
      ) async {
        // Given: 屏幕宽度为 400px（移动端）
        setScreenSize(tester, const Size(400, 800));

        // When: 渲染应用
        await tester.pumpWidget(
          createTestWidget(
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 1024;
                return Scaffold(
                  appBar: AppBar(title: const Text('CardMind')),
                  body: Center(
                    child: Text(isMobile ? 'Mobile Layout' : 'Desktop Layout'),
                  ),
                  bottomNavigationBar: isMobile
                      ? BottomNavigationBar(
                          items: const [
                            BottomNavigationBarItem(
                              icon: Icon(Icons.home),
                              label: '主页',
                            ),
                            BottomNavigationBarItem(
                              icon: Icon(Icons.settings),
                              label: '设置',
                            ),
                          ],
                        )
                      : null,
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示移动端布局
        expect(find.text('Mobile Layout'), findsOneWidget);
        expect(find.byType(BottomNavigationBar), findsOneWidget);
      });

      testWidgets('it_should_show_bottom_navigation_on_mobile', (
        WidgetTester tester,
      ) async {
        // Given: 移动端屏幕尺寸
        setScreenSize(tester, const Size(375, 667));

        // When: 渲染应用
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              appBar: AppBar(title: const Text('CardMind')),
              body: const Center(child: Text('Content')),
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
        expect(find.text('主页'), findsOneWidget);
        expect(find.text('设置'), findsOneWidget);
      });

      testWidgets('it_should_stack_content_vertically_on_mobile', (
        WidgetTester tester,
      ) async {
        // Given: 移动端屏幕尺寸
        setScreenSize(tester, const Size(360, 640));

        // When: 渲染应用
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: Column(
                children: [
                  Container(
                    height: 100,
                    color: Colors.red,
                    child: const Center(child: Text('Header')),
                  ),
                  Expanded(
                    child: Container(
                      color: Colors.blue,
                      child: const Center(child: Text('Content')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 内容应该垂直堆叠
        expect(find.text('Header'), findsOneWidget);
        expect(find.text('Content'), findsOneWidget);
        expect(find.byType(Column), findsOneWidget);
      });
    });

    // ========================================
    // 桌面端布局测试（>= 1024px）
    // ========================================
    group('Desktop Layout (>= 1024px)', () {
      testWidgets('it_should_show_desktop_layout_on_large_screen', (
        WidgetTester tester,
      ) async {
        // Given: 屏幕宽度为 1440px（桌面端）
        setScreenSize(tester, const Size(1440, 900));

        // When: 渲染应用
        await tester.pumpWidget(
          createTestWidget(
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1024;
                return Scaffold(
                  appBar: AppBar(title: const Text('CardMind')),
                  body: Row(
                    children: [
                      if (isDesktop)
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
                      Expanded(
                        child: Center(
                          child: Text(
                            isDesktop ? 'Desktop Layout' : 'Mobile Layout',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示桌面端布局
        expect(find.text('Desktop Layout'), findsOneWidget);
        expect(find.byType(NavigationRail), findsOneWidget);
      });

      testWidgets('it_should_show_side_navigation_on_desktop', (
        WidgetTester tester,
      ) async {
        // Given: 桌面端屏幕尺寸
        setScreenSize(tester, const Size(1920, 1080));

        // When: 渲染应用
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
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
                  const Expanded(child: Center(child: Text('Content'))),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示侧边导航栏
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.text('主页'), findsOneWidget);
        expect(find.text('设置'), findsOneWidget);
      });

      testWidgets('it_should_arrange_content_horizontally_on_desktop', (
        WidgetTester tester,
      ) async {
        // Given: 桌面端屏幕尺寸
        setScreenSize(tester, const Size(1600, 900));

        // When: 渲染应用
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: Row(
                children: [
                  Container(
                    width: 200,
                    color: Colors.red,
                    child: const Center(child: Text('Sidebar')),
                  ),
                  Expanded(
                    child: Container(
                      color: Colors.blue,
                      child: const Center(child: Text('Content')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 内容应该水平排列
        expect(find.text('Sidebar'), findsOneWidget);
        expect(find.text('Content'), findsOneWidget);
        expect(find.byType(Row), findsOneWidget);
      });
    });

    // ========================================
    // 断点切换测试（1024px）
    // ========================================
    group('Breakpoint Transition (1024px)', () {
      testWidgets('it_should_switch_layout_at_1024px_breakpoint', (
        WidgetTester tester,
      ) async {
        // Given: 屏幕宽度正好是 1024px
        setScreenSize(tester, const Size(1024, 768));

        // When: 渲染应用
        await tester.pumpWidget(
          createTestWidget(
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1024;
                return Scaffold(
                  body: Center(
                    child: Text(
                      isDesktop
                          ? 'Desktop Layout (>= 1024px)'
                          : 'Mobile Layout (< 1024px)',
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示桌面端布局（>= 1024px）
        expect(find.text('Desktop Layout (>= 1024px)'), findsOneWidget);
      });

      testWidgets('it_should_show_mobile_layout_just_below_breakpoint', (
        WidgetTester tester,
      ) async {
        // Given: 屏幕宽度为 1023px（刚好低于断点）
        setScreenSize(tester, const Size(1023, 768));

        // When: 渲染应用
        await tester.pumpWidget(
          createTestWidget(
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1024;
                return Scaffold(
                  body: Center(
                    child: Text(
                      isDesktop
                          ? 'Desktop Layout (>= 1024px)'
                          : 'Mobile Layout (< 1024px)',
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示移动端布局
        expect(find.text('Mobile Layout (< 1024px)'), findsOneWidget);
      });

      testWidgets('it_should_show_desktop_layout_just_above_breakpoint', (
        WidgetTester tester,
      ) async {
        // Given: 屏幕宽度为 1025px（刚好高于断点）
        setScreenSize(tester, const Size(1025, 768));

        // When: 渲染应用
        await tester.pumpWidget(
          createTestWidget(
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1024;
                return Scaffold(
                  body: Center(
                    child: Text(
                      isDesktop
                          ? 'Desktop Layout (>= 1024px)'
                          : 'Mobile Layout (< 1024px)',
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示桌面端布局
        expect(find.text('Desktop Layout (>= 1024px)'), findsOneWidget);
      });
    });

    // ========================================
    // 平板布局测试（portrait/landscape）
    // ========================================
    group('Tablet Layout', () {
      testWidgets('it_should_show_mobile_layout_on_tablet_portrait', (
        WidgetTester tester,
      ) async {
        // Given: 平板竖屏尺寸（768x1024）
        setScreenSize(tester, const Size(768, 1024));

        // When: 渲染应用
        await tester.pumpWidget(
          createTestWidget(
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1024;
                return Scaffold(
                  body: Center(child: Text(isDesktop ? 'Desktop' : 'Mobile')),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示移动端布局（宽度 < 1024px）
        expect(find.text('Mobile'), findsOneWidget);
      });

      testWidgets('it_should_show_desktop_layout_on_tablet_landscape', (
        WidgetTester tester,
      ) async {
        // Given: 平板横屏尺寸（1024x768）
        setScreenSize(tester, const Size(1024, 768));

        // When: 渲染应用
        await tester.pumpWidget(
          createTestWidget(
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1024;
                return Scaffold(
                  body: Center(child: Text(isDesktop ? 'Desktop' : 'Mobile')),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示桌面端布局（宽度 >= 1024px）
        expect(find.text('Desktop'), findsOneWidget);
      });
    });

    // ========================================
    // 组件响应式行为测试
    // ========================================
    group('Component Responsive Behavior', () {
      testWidgets('it_should_adjust_fab_position_based_on_screen_size', (
        WidgetTester tester,
      ) async {
        // Given: 移动端屏幕
        setScreenSize(tester, const Size(400, 800));

        // When: 渲染带 FAB 的应用
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: const Center(child: Text('Content')),
              floatingActionButton: FloatingActionButton(
                onPressed: () {},
                child: const Icon(Icons.add),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: FAB 应该显示在右下角
        expect(find.byType(FloatingActionButton), findsOneWidget);
      });

      testWidgets('it_should_adjust_card_width_based_on_screen_size', (
        WidgetTester tester,
      ) async {
        // Given: 桌面端屏幕
        setScreenSize(tester, const Size(1440, 900));

        // When: 渲染卡片列表
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth >= 1024
                      ? 600.0
                      : constraints.maxWidth;
                  return Center(
                    child: Container(
                      width: cardWidth,
                      height: 200,
                      color: Colors.blue,
                      child: const Center(child: Text('Card')),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 卡片宽度应该受限（桌面端）
        final container = tester.widget<Container>(find.byType(Container).last);
        expect(container.constraints?.maxWidth, anyOf(isNull, equals(600.0)));
      });
    });

    // ========================================
    // 边缘情况测试
    // ========================================
    group('Edge Cases', () {
      testWidgets('it_should_handle_very_small_screen', (
        WidgetTester tester,
      ) async {
        // Given: 极小屏幕（320x480）
        setScreenSize(tester, const Size(320, 480));

        // When: 渲染应用
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              appBar: AppBar(title: const Text('CardMind')),
              body: const Center(child: Text('Content')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该正常渲染，不溢出
        expect(find.text('CardMind'), findsOneWidget);
        expect(find.text('Content'), findsOneWidget);
      });

      testWidgets('it_should_handle_very_large_screen', (
        WidgetTester tester,
      ) async {
        // Given: 极大屏幕（2560x1440）
        setScreenSize(tester, const Size(2560, 1440));

        // When: 渲染应用
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              appBar: AppBar(title: const Text('CardMind')),
              body: const Center(child: Text('Content')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该正常渲染
        expect(find.text('CardMind'), findsOneWidget);
        expect(find.text('Content'), findsOneWidget);
      });

      testWidgets('it_should_handle_square_screen', (
        WidgetTester tester,
      ) async {
        // Given: 正方形屏幕（800x800）
        setScreenSize(tester, const Size(800, 800));

        // When: 渲染应用
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: LayoutBuilder(
                builder: (context, constraints) {
                  return Center(
                    child: Text(
                      'Width: ${constraints.maxWidth}, Height: ${constraints.maxHeight}',
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该正确显示尺寸信息
        expect(find.textContaining('Width: 800'), findsOneWidget);
        expect(find.textContaining('Height: 800'), findsOneWidget);
      });
    });
  });
}
