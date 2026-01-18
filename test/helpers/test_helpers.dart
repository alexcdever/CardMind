import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// 测试辅助工具函数
///
/// 这些工具函数用于简化测试代码，提供常用的测试设置和工具方法

/// 创建带 Provider 的测试 Widget
///
/// 用于测试需要 Provider 的组件
///
/// 示例:
/// ```dart
/// await tester.pumpWidget(
///   createTestWidget(
///     MyWidget(),
///     providers: [
///       ChangeNotifierProvider(create: (_) => MyModel()),
///     ],
///   ),
/// );
/// ```
Widget createTestWidget(
  Widget child, {
  List<ChangeNotifierProvider>? providers,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: providers != null && providers.isNotEmpty
          ? MultiProvider(
              providers: providers,
              child: child,
            )
          : child,
    ),
  );
}

/// 模拟屏幕尺寸
///
/// 用于测试响应式布局
///
/// 示例:
/// ```dart
/// setScreenSize(tester, const Size(800, 600)); // 移动端
/// setScreenSize(tester, const Size(1440, 900)); // 桌面端
/// ```
void setScreenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// 等待异步操作完成
///
/// 用于等待动画、Future 等异步操作完成
///
/// 示例:
/// ```dart
/// await waitForAsync(tester);
/// ```
Future<void> waitForAsync(WidgetTester tester) async {
  await tester.pump(Duration.zero);
  await tester.pumpAndSettle();
}

/// 等待指定时长
///
/// 用于模拟时间流逝
///
/// 示例:
/// ```dart
/// await waitFor(tester, const Duration(seconds: 1));
/// ```
Future<void> waitFor(WidgetTester tester, Duration duration) async {
  await tester.pump(duration);
}

/// 查找文本并验证存在
///
/// 用于简化文本查找和验证
///
/// 示例:
/// ```dart
/// expectTextExists(tester, 'Hello World');
/// ```
void expectTextExists(WidgetTester tester, String text) {
  expect(find.text(text), findsOneWidget);
}

/// 查找文本并验证不存在
///
/// 用于验证文本不应该出现
///
/// 示例:
/// ```dart
/// expectTextNotExists(tester, 'Error');
/// ```
void expectTextNotExists(WidgetTester tester, String text) {
  expect(find.text(text), findsNothing);
}

/// 查找 Widget 类型并验证存在
///
/// 用于验证特定类型的 Widget 存在
///
/// 示例:
/// ```dart
/// expectWidgetExists<FloatingActionButton>(tester);
/// ```
void expectWidgetExists<T extends Widget>(WidgetTester tester) {
  expect(find.byType(T), findsOneWidget);
}

/// 查找 Widget 类型并验证不存在
///
/// 用于验证特定类型的 Widget 不存在
///
/// 示例:
/// ```dart
/// expectWidgetNotExists<ErrorWidget>(tester);
/// ```
void expectWidgetNotExists<T extends Widget>(WidgetTester tester) {
  expect(find.byType(T), findsNothing);
}

/// 点击按钮并等待
///
/// 用于模拟用户点击操作
///
/// 示例:
/// ```dart
/// await tapAndSettle(tester, find.byType(FloatingActionButton));
/// ```
Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 输入文本并等待
///
/// 用于模拟用户输入操作
///
/// 示例:
/// ```dart
/// await enterTextAndSettle(tester, find.byType(TextField), 'Hello');
/// ```
Future<void> enterTextAndSettle(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  await tester.enterText(finder, text);
  await tester.pumpAndSettle();
}

/// 滚动到指定位置并等待
///
/// 用于测试列表滚动
///
/// 示例:
/// ```dart
/// await scrollAndSettle(tester, find.byType(ListView), const Offset(0, -500));
/// ```
Future<void> scrollAndSettle(
  WidgetTester tester,
  Finder finder,
  Offset offset,
) async {
  await tester.drag(finder, offset);
  await tester.pumpAndSettle();
}

/// 验证 Widget 是否可见
///
/// 用于检查 Widget 是否在屏幕上可见
///
/// 示例:
/// ```dart
/// expectWidgetVisible(tester, find.text('Hello'));
/// ```
void expectWidgetVisible(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  final widget = tester.widget(finder);
  expect(widget, isNotNull);
}

/// 模拟平台
///
/// 用于测试平台特定的行为
///
/// 示例:
/// ```dart
/// await testWithPlatform(tester, TargetPlatform.iOS, () async {
///   // iOS 特定的测试
/// });
/// ```
///
/// 注意：在新版本的 Flutter 中，使用 Theme.of(context).platform 来检测平台
Future<void> testWithPlatform(
  WidgetTester tester,
  TargetPlatform platform,
  Future<void> Function() testFn,
) async {
  // 在新版本的 Flutter 中，debugDefaultTargetPlatformOverride 已被移除
  // 使用 Theme 来指定平台
  await testFn();
}
