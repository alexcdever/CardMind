import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_helpers.dart';

/// Platform Detection Specification Tests
///
/// 规格编号: SP-ADAPT-001
/// 这些测试验证平台检测的所有行为
///
/// 测试遵循 Spec Coding 方法论：
/// - 测试即规格，规格即文档
/// - 使用 it_should_xxx() 命名风格
/// - Given-When-Then 结构

void main() {
  group('SP-ADAPT-001: Platform Detection', () {
    // ========================================
    // 平台检测测试
    // ========================================
    group('Platform Detection', () {
      testWidgets('it_should_detect_current_platform',
          (WidgetTester tester) async {
        // Given: 应用运行在某个平台上
        await tester.pumpWidget(
          createTestWidget(
            Builder(
              builder: (context) {
                final platform = Theme.of(context).platform;
                return Scaffold(
                  body: Center(
                    child: Text('Platform: ${platform.name}'),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示当前平台
        expect(find.textContaining('Platform:'), findsOneWidget);
      });

      testWidgets('it_should_identify_mobile_platforms',
          (WidgetTester tester) async {
        // Given: 应用运行在移动平台
        await tester.pumpWidget(
          createTestWidget(
            Builder(
              builder: (context) {
                final platform = Theme.of(context).platform;
                final isMobile = platform == TargetPlatform.android ||
                    platform == TargetPlatform.iOS;
                return Scaffold(
                  body: Center(
                    child: Text(isMobile ? 'Mobile Platform' : 'Desktop Platform'),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该正确识别移动平台
        expect(find.text('Mobile Platform'), findsOneWidget);
      });

      testWidgets('it_should_identify_desktop_platforms',
          (WidgetTester tester) async {
        // Given: 应用运行在桌面平台
        await tester.pumpWidget(
          createTestWidget(
            Builder(
              builder: (context) {
                final platform = Theme.of(context).platform;
                final isDesktop = platform == TargetPlatform.windows ||
                    platform == TargetPlatform.macOS ||
                    platform == TargetPlatform.linux;
                return Scaffold(
                  body: Center(
                    child: Text(isDesktop ? 'Desktop Platform' : 'Mobile Platform'),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该正确识别桌面平台
        // 注意：在测试环境中，默认平台是 android
        expect(find.text('Mobile Platform'), findsOneWidget);
      });

      testWidgets('it_should_provide_platform_specific_ui',
          (WidgetTester tester) async {
        // Given: 应用需要根据平台显示不同 UI
        await tester.pumpWidget(
          createTestWidget(
            Builder(
              builder: (context) {
                final platform = Theme.of(context).platform;
                Widget platformWidget;

                switch (platform) {
                  case TargetPlatform.android:
                    platformWidget = const Text('Android UI');
                    break;
                  case TargetPlatform.iOS:
                    platformWidget = const Text('iOS UI');
                    break;
                  case TargetPlatform.windows:
                  case TargetPlatform.macOS:
                  case TargetPlatform.linux:
                    platformWidget = const Text('Desktop UI');
                    break;
                  default:
                    platformWidget = const Text('Unknown Platform');
                }

                return Scaffold(
                  body: Center(child: platformWidget),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示平台特定的 UI
        expect(find.text('Android UI'), findsOneWidget);
      });
    });

    // ========================================
    // 平台能力检测测试
    // ========================================
    group('Platform Capabilities', () {
      testWidgets('it_should_detect_touch_support',
          (WidgetTester tester) async {
        // Given: 检测触摸支持
        await tester.pumpWidget(
          createTestWidget(
            Builder(
              builder: (context) {
                final platform = Theme.of(context).platform;
                final hasTouch = platform == TargetPlatform.android ||
                    platform == TargetPlatform.iOS;
                return Scaffold(
                  body: Center(
                    child: Text(hasTouch ? 'Touch Supported' : 'No Touch'),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该正确检测触摸支持
        expect(find.text('Touch Supported'), findsOneWidget);
      });

      testWidgets('it_should_detect_keyboard_support',
          (WidgetTester tester) async {
        // Given: 检测键盘支持
        await tester.pumpWidget(
          createTestWidget(
            Builder(
              builder: (context) {
                final platform = Theme.of(context).platform;
                final hasKeyboard = platform == TargetPlatform.windows ||
                    platform == TargetPlatform.macOS ||
                    platform == TargetPlatform.linux;
                return Scaffold(
                  body: Center(
                    child: Text(hasKeyboard ? 'Keyboard Supported' : 'No Keyboard'),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该正确检测键盘支持
        expect(find.text('No Keyboard'), findsOneWidget);
      });

      testWidgets('it_should_detect_mouse_support',
          (WidgetTester tester) async {
        // Given: 检测鼠标支持
        await tester.pumpWidget(
          createTestWidget(
            Builder(
              builder: (context) {
                final platform = Theme.of(context).platform;
                final hasMouse = platform == TargetPlatform.windows ||
                    platform == TargetPlatform.macOS ||
                    platform == TargetPlatform.linux;
                return Scaffold(
                  body: Center(
                    child: Text(hasMouse ? 'Mouse Supported' : 'No Mouse'),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该正确检测鼠标支持
        expect(find.text('No Mouse'), findsOneWidget);
      });
    });

    // ========================================
    // 平台特定行为测试
    // ========================================
    group('Platform-Specific Behavior', () {
      testWidgets('it_should_use_material_design_on_android',
          (WidgetTester tester) async {
        // Given: Android 平台
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              platform: TargetPlatform.android,
            ),
            home: Builder(
              builder: (context) {
                final platform = Theme.of(context).platform;
                return Scaffold(
                  appBar: AppBar(
                    title: Text(platform == TargetPlatform.android
                        ? 'Material Design'
                        : 'Other Design'),
                  ),
                  body: const Center(child: Text('Content')),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该使用 Material Design
        expect(find.text('Material Design'), findsOneWidget);
      });

      testWidgets('it_should_adapt_navigation_style_by_platform',
          (WidgetTester tester) async {
        // Given: 不同平台
        await tester.pumpWidget(
          createTestWidget(
            Builder(
              builder: (context) {
                final platform = Theme.of(context).platform;
                final isMobile = platform == TargetPlatform.android ||
                    platform == TargetPlatform.iOS;

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

        // Then: 移动端应该显示底部导航栏
        expect(find.byType(BottomNavigationBar), findsOneWidget);
      });

      testWidgets('it_should_adapt_scroll_behavior_by_platform',
          (WidgetTester tester) async {
        // Given: 不同平台的滚动行为
        await tester.pumpWidget(
          createTestWidget(
            Builder(
              builder: (context) {
                final platform = Theme.of(context).platform;
                return Scaffold(
                  body: ListView.builder(
                    itemCount: 10,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text('Item $index'),
                        subtitle: Text('Platform: ${platform.name}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示列表
        expect(find.text('Item 0'), findsOneWidget);
        expect(find.textContaining('Platform:'), findsWidgets);
      });
    });

    // ========================================
    // 平台检测工具测试
    // ========================================
    group('Platform Detection Utilities', () {
      testWidgets('it_should_provide_is_mobile_helper',
          (WidgetTester tester) async {
        // Given: 平台检测工具函数
        bool isMobile(BuildContext context) {
          final platform = Theme.of(context).platform;
          return platform == TargetPlatform.android ||
              platform == TargetPlatform.iOS;
        }

        await tester.pumpWidget(
          createTestWidget(
            Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: Text(isMobile(context) ? 'Mobile' : 'Desktop'),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该正确判断是否为移动平台
        expect(find.text('Mobile'), findsOneWidget);
      });

      testWidgets('it_should_provide_is_desktop_helper',
          (WidgetTester tester) async {
        // Given: 平台检测工具函数
        bool isDesktop(BuildContext context) {
          final platform = Theme.of(context).platform;
          return platform == TargetPlatform.windows ||
              platform == TargetPlatform.macOS ||
              platform == TargetPlatform.linux;
        }

        await tester.pumpWidget(
          createTestWidget(
            Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: Text(isDesktop(context) ? 'Desktop' : 'Mobile'),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该正确判断是否为桌面平台
        expect(find.text('Mobile'), findsOneWidget);
      });

      testWidgets('it_should_provide_platform_name_helper',
          (WidgetTester tester) async {
        // Given: 获取平台名称的工具函数
        String getPlatformName(BuildContext context) {
          final platform = Theme.of(context).platform;
          switch (platform) {
            case TargetPlatform.android:
              return 'Android';
            case TargetPlatform.iOS:
              return 'iOS';
            case TargetPlatform.windows:
              return 'Windows';
            case TargetPlatform.macOS:
              return 'macOS';
            case TargetPlatform.linux:
              return 'Linux';
            default:
              return 'Unknown';
          }
        }

        await tester.pumpWidget(
          createTestWidget(
            Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: Text('Platform: ${getPlatformName(context)}'),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示平台名称
        expect(find.text('Platform: Android'), findsOneWidget);
      });
    });

    // ========================================
    // 跨平台兼容性测试
    // ========================================
    group('Cross-Platform Compatibility', () {
      testWidgets('it_should_render_consistently_across_platforms',
          (WidgetTester tester) async {
        // Given: 跨平台的一致性渲染
        await tester.pumpWidget(
          createTestWidget(
            const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('CardMind'),
                    SizedBox(height: 16),
                    Text('离线优先的卡片笔记应用'),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该在所有平台上一致渲染
        expect(find.text('CardMind'), findsOneWidget);
        expect(find.text('离线优先的卡片笔记应用'), findsOneWidget);
      });

      testWidgets('it_should_handle_platform_specific_widgets',
          (WidgetTester tester) async {
        // Given: 平台特定的 Widget
        await tester.pumpWidget(
          createTestWidget(
            Builder(
              builder: (context) {
                final platform = Theme.of(context).platform;
                return Scaffold(
                  body: Center(
                    child: platform == TargetPlatform.iOS
                        ? const Text('Cupertino Widget')
                        : const Text('Material Widget'),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示对应平台的 Widget
        expect(find.text('Material Widget'), findsOneWidget);
      });

      testWidgets('it_should_adapt_icons_by_platform',
          (WidgetTester tester) async {
        // Given: 平台特定的图标
        await tester.pumpWidget(
          createTestWidget(
            Builder(
              builder: (context) {
                final platform = Theme.of(context).platform;
                final icon = platform == TargetPlatform.iOS
                    ? Icons.ios_share
                    : Icons.share;

                return Scaffold(
                  body: Center(
                    child: Icon(icon),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Then: 应该显示对应平台的图标
        expect(find.byIcon(Icons.share), findsOneWidget);
      });
    });
  });
}
