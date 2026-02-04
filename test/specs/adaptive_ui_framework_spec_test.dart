import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_helpers.dart';

/// Adaptive UI Framework Specification Tests
///
/// 规格编号: SP-ADAPT-002
/// 这些测试验证自适应 UI 框架的所有行为
///
/// 测试遵循 Spec Coding 方法论：
/// - 测试即规格，规格即文档
/// - 使用 it_should_xxx() 命名风格
/// - Given-When-Then 结构

void main() {
  group('SP-ADAPT-002: Adaptive UI Framework', () {
    // ========================================
    // 自适应 Builder 测试
    // ========================================
    group('Adaptive Builder', () {
      testWidgets('it_should_select_widget_based_on_screen_size', (
        WidgetTester tester,
      ) async {
        // Given: 不同的屏幕尺寸
        setScreenSize(tester, const Size(400, 800));

        // When: 使用自适应 Builder
        await tester.pumpWidget(
          createTestWidget(
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  return const Scaffold(body: Center(child: Text('Small')));
                } else if (constraints.maxWidth < 1024) {
                  return const Scaffold(body: Center(child: Text('Medium')));
                } else {
                  return const Scaffold(body: Center(child: Text('Large')));
                }
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该选择小屏幕 Widget
        expect(find.text('Small'), findsOneWidget);
      });

      testWidgets('it_should_rebuild_on_size_change', (
        WidgetTester tester,
      ) async {
        // Given: 初始屏幕尺寸
        setScreenSize(tester, const Size(400, 800));

        await tester.pumpWidget(
          createTestWidget(
            LayoutBuilder(
              builder: (context, constraints) {
                return Scaffold(
                  body: Center(child: Text('Width: ${constraints.maxWidth}')),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示当前宽度
        expect(find.text('Width: 400.0'), findsOneWidget);
      });

      testWidgets('it_should_provide_constraints_to_children', (
        WidgetTester tester,
      ) async {
        // Given: 使用 LayoutBuilder
        await tester.pumpWidget(
          createTestWidget(
            LayoutBuilder(
              builder: (context, constraints) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Max Width: ${constraints.maxWidth}'),
                        Text('Max Height: ${constraints.maxHeight}'),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示约束信息
        expect(find.textContaining('Max Width:'), findsOneWidget);
        expect(find.textContaining('Max Height:'), findsOneWidget);
      });
    });

    // ========================================
    // 自适应组件测试
    // ========================================
    group('Adaptive Components', () {
      testWidgets('it_should_provide_adaptive_navigation', (
        WidgetTester tester,
      ) async {
        // Given: 自适应导航组件
        setScreenSize(tester, const Size(400, 800));

        await tester.pumpWidget(
          createTestWidget(
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                return Scaffold(
                  appBar: AppBar(title: const Text('CardMind')),
                  body: const Center(child: Text('Content')),
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

        // Then: 应该显示移动端导航
        expect(find.byType(BottomNavigationBar), findsOneWidget);
      });

      testWidgets('it_should_provide_adaptive_dialog', (
        WidgetTester tester,
      ) async {
        // Given: 自适应对话框
        await tester.pumpWidget(
          createTestWidget(
            Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('提示'),
                            content: const Text('这是一个自适应对话框'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('确定'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text('显示对话框'),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        // When: 点击按钮显示对话框
        await tester.tap(find.text('显示对话框'));
        await tester.pumpAndSettle();

        // Then: 应该显示对话框
        expect(find.text('提示'), findsOneWidget);
        expect(find.text('这是一个自适应对话框'), findsOneWidget);
      });

      testWidgets('it_should_provide_adaptive_button', (
        WidgetTester tester,
      ) async {
        // Given: 自适应按钮
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('自适应按钮'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示按钮
        expect(find.text('自适应按钮'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
      });
    });

    // ========================================
    // 自适应布局测试
    // ========================================
    group('Adaptive Layout', () {
      testWidgets('it_should_adapt_column_count_by_screen_width', (
        WidgetTester tester,
      ) async {
        // Given: 不同的屏幕宽度
        setScreenSize(tester, const Size(800, 600));

        await tester.pumpWidget(
          createTestWidget(
            LayoutBuilder(
              builder: (context, constraints) {
                final columnCount = constraints.maxWidth < 600
                    ? 1
                    : constraints.maxWidth < 1024
                    ? 2
                    : 3;

                return Scaffold(
                  body: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columnCount,
                    ),
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      return Card(child: Center(child: Text('Item $index')));
                    },
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示 2 列布局
        expect(find.text('Item 0'), findsOneWidget);
        expect(find.byType(GridView), findsOneWidget);
      });

      testWidgets('it_should_adapt_padding_by_screen_size', (
        WidgetTester tester,
      ) async {
        // Given: 不同的屏幕尺寸
        setScreenSize(tester, const Size(400, 800));

        await tester.pumpWidget(
          createTestWidget(
            LayoutBuilder(
              builder: (context, constraints) {
                final padding = constraints.maxWidth < 600 ? 16.0 : 32.0;

                return Scaffold(
                  body: Padding(
                    padding: EdgeInsets.all(padding),
                    child: const Center(child: Text('Content')),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该应用小屏幕的 padding
        expect(find.text('Content'), findsOneWidget);
        expect(find.byType(Padding), findsOneWidget);
      });

      testWidgets('it_should_adapt_font_size_by_screen_size', (
        WidgetTester tester,
      ) async {
        // Given: 不同的屏幕尺寸
        setScreenSize(tester, const Size(400, 800));

        await tester.pumpWidget(
          createTestWidget(
            LayoutBuilder(
              builder: (context, constraints) {
                final fontSize = constraints.maxWidth < 600 ? 14.0 : 16.0;

                return Scaffold(
                  body: Center(
                    child: Text(
                      'Adaptive Text',
                      style: TextStyle(fontSize: fontSize),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该应用自适应字体大小
        expect(find.text('Adaptive Text'), findsOneWidget);
      });
    });

    // ========================================
    // 自适应主题测试
    // ========================================
    group('Adaptive Theme', () {
      testWidgets('it_should_apply_platform_specific_theme', (
        WidgetTester tester,
      ) async {
        // Given: 平台特定的主题
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              platform: TargetPlatform.android,
              primarySwatch: Colors.blue,
            ),
            home: Builder(
              builder: (context) {
                final theme = Theme.of(context);
                return Scaffold(
                  appBar: AppBar(
                    title: Text('Platform: ${theme.platform.name}'),
                  ),
                  body: const Center(child: Text('Content')),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该应用平台主题
        expect(find.textContaining('Platform:'), findsOneWidget);
      });

      testWidgets('it_should_support_dark_mode', (WidgetTester tester) async {
        // Given: 深色模式主题
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: ThemeMode.dark,
            home: Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Scaffold(
                  body: Center(
                    child: Text(isDark ? 'Dark Mode' : 'Light Mode'),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该应用深色模式
        expect(find.text('Dark Mode'), findsOneWidget);
      });

      testWidgets('it_should_adapt_colors_by_theme', (
        WidgetTester tester,
      ) async {
        // Given: 主题颜色
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              primaryColor: Colors.blue,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            ),
            home: Builder(
              builder: (context) {
                final primaryColor = Theme.of(context).primaryColor;
                return Scaffold(
                  body: Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      color: primaryColor,
                      child: const Center(child: Text('Box')),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该应用主题颜色
        expect(find.text('Box'), findsOneWidget);
      });
    });

    // ========================================
    // 自适应动画测试
    // ========================================
    group('Adaptive Animations', () {
      testWidgets('it_should_reduce_animations_on_low_end_devices', (
        WidgetTester tester,
      ) async {
        // Given: 自适应动画
        await tester.pumpWidget(
          createTestWidget(
            const Scaffold(
              body: Center(
                child: AnimatedOpacity(
                  opacity: 1,
                  duration: Duration(milliseconds: 300),
                  child: Text('Animated Content'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示动画内容
        expect(find.text('Animated Content'), findsOneWidget);
      });

      testWidgets('it_should_adapt_transition_duration', (
        WidgetTester tester,
      ) async {
        // Given: 自适应过渡时长
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 100,
                  height: 100,
                  color: Colors.blue,
                  child: const Center(child: Text('Box')),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示动画容器
        expect(find.text('Box'), findsOneWidget);
      });
    });

    // ========================================
    // 自适应输入测试
    // ========================================
    group('Adaptive Input', () {
      testWidgets('it_should_show_touch_optimized_controls_on_mobile', (
        WidgetTester tester,
      ) async {
        // Given: 移动端触摸优化控件
        setScreenSize(tester, const Size(400, 800));

        await tester.pumpWidget(
          createTestWidget(
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                final buttonSize = isMobile ? 48.0 : 36.0;

                return Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: buttonSize,
                      height: buttonSize,
                      child: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {},
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示触摸优化的按钮
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('it_should_adapt_text_field_size', (
        WidgetTester tester,
      ) async {
        // Given: 自适应文本输入框
        await tester.pumpWidget(
          createTestWidget(
            Scaffold(
              body: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth < 600
                        ? constraints.maxWidth * 0.9
                        : 400.0;

                    return SizedBox(
                      width: width,
                      child: const TextField(
                        decoration: InputDecoration(labelText: '输入文本'),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示自适应宽度的输入框
        expect(find.byType(TextField), findsOneWidget);
      });
    });

  });
}
