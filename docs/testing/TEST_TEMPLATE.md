# 测试模板

本文档提供 CardMind 项目的测试代码模板，帮助开发者快速编写符合规范的测试。

## 目录

- [Spec 测试模板](#spec-测试模板)
- [Widget 测试模板](#widget-测试模板)
- [Screen 测试模板](#screen-测试模板)
- [Integration 测试模板](#integration-测试模板)

---

## Spec 测试模板

用于验证功能规格的完整实现。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/widgets/your_widget.dart';
import 'package:cardmind/models/your_model.dart';
import '../helpers/mock_card_service.dart';
import '../helpers/test_helpers.dart';

/// [Feature Name] Specification Tests
///
/// 规格编号: SP-XXX-XXX
/// 这些测试验证 [功能描述] 的所有交互行为
///
/// 测试遵循 Spec Coding 方法论：
/// - 测试即规格，规格即文档
/// - 使用 it_should_xxx() 命名风格
/// - Given-When-Then 结构

void main() {
  group('SP-XXX-XXX: [Feature Name]', () {
    late MockCardService mockCardService;

    setUp(() {
      mockCardService = MockCardService();
    });

    tearDown(() {
      mockCardService.reset();
    });

    // ========================================
    // Helper: 创建测试 Widget
    // ========================================
    Widget createTestWidget({
      // 添加可配置参数
      String? customParam,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: YourWidget(
            // 传入参数
          ),
        ),
      );
    }

    // ========================================
    // [Scenario Group Name] Tests
    // ========================================

    group('[Scenario Group Name]', () {
      testWidgets('it_should_do_something_when_condition_met',
          (WidgetTester tester) async {
        // Given: 前置条件描述
        await mockCardService.createCard('Test Card', 'Content');

        // When: 执行操作
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Button));
        await tester.pumpAndSettle();

        // Then: 验证结果
        expect(find.text('Expected Result'), findsOneWidget);
        expect(mockCardService.createCardCallCount, equals(1));
      });

      testWidgets('it_should_handle_error_case',
          (WidgetTester tester) async {
        // Given: 错误条件
        mockCardService.shouldThrowError = true;
        mockCardService.errorMessage = 'Test error';

        // When: 执行操作
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Button));
        await tester.pumpAndSettle();

        // Then: 验证错误处理
        expect(find.text('Test error'), findsOneWidget);
      });
    });

    // ========================================
    // Edge Cases Tests
    // ========================================

    group('Edge Cases', () {
      testWidgets('it_should_handle_empty_state',
          (WidgetTester tester) async {
        // Given: 空状态
        // When: 渲染 Widget
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Then: 显示空状态
        expect(find.text('No data'), findsOneWidget);
      });
    });

    // ========================================
    // Performance Tests
    // ========================================

    group('Performance Tests', () {
      testWidgets('it_should_render_within_reasonable_time',
          (WidgetTester tester) async {
        // Given: 准备渲染
        final stopwatch = Stopwatch()..start();

        // When: 渲染 Widget
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        stopwatch.stop();

        // Then: 渲染时间合理（测试环境允许更宽松的限制）
        expect(stopwatch.elapsedMilliseconds, lessThan(200));
      });
    });
  });
}
```

---

## Widget 测试模板

用于测试单个 Widget 的行为。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/widgets/your_widget.dart';
import 'package:cardmind/models/your_model.dart';

void main() {
  group('YourWidget Tests', () {
    late YourModel testModel;

    setUp(() {
      testModel = YourModel(
        id: 'test-id',
        name: 'Test Name',
        // 其他字段
      );
    });

    testWidgets('it_should_display_basic_information',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: YourWidget(
            model: testModel,
            onAction: (_) {},
          ),
        ),
      );

      expect(find.text('Test Name'), findsOneWidget);
    });

    testWidgets('it_should_call_callback_when_button_pressed',
        (WidgetTester tester) async {
      bool callbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: YourWidget(
            model: testModel,
            onAction: (_) {
              callbackCalled = true;
            },
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(callbackCalled, isTrue);
    });

    testWidgets('it_should_update_when_model_changes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: YourWidget(
            model: testModel,
            onAction: (_) {},
          ),
        ),
      );

      // 更新 model
      final newModel = testModel.copyWith(name: 'New Name');

      await tester.pumpWidget(
        MaterialApp(
          home: YourWidget(
            model: newModel,
            onAction: (_) {},
          ),
        ),
      );

      expect(find.text('New Name'), findsOneWidget);
    });
  });
}
```

---

## Screen 测试模板

用于测试完整屏幕的集成行为。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/screens/your_screen.dart';
import 'package:cardmind/providers/your_provider.dart';
import 'package:provider/provider.dart';
import '../helpers/mock_card_service.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('YourScreen Tests', () {
    late MockCardService mockCardService;

    setUp(() {
      mockCardService = MockCardService();
    });

    Widget createScreen() {
      final provider = YourProvider(cardService: mockCardService);
      provider.loadData();

      return MaterialApp(
        home: ChangeNotifierProvider.value(
          value: provider,
          child: const YourScreen(),
        ),
      );
    }

    testWidgets('it_should_display_screen_layout',
        (WidgetTester tester) async {
      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Screen Title'), findsOneWidget);
    });

    testWidgets('it_should_adapt_to_mobile_layout',
        (WidgetTester tester) async {
      // Given: 移动端屏幕尺寸
      setScreenSize(tester, const Size(400, 800));

      // When: 渲染屏幕
      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Then: 显示移动端布局
      expect(find.byType(MobileLayout), findsOneWidget);
      expect(find.byType(DesktopLayout), findsNothing);
    });

    testWidgets('it_should_adapt_to_desktop_layout',
        (WidgetTester tester) async {
      // Given: 桌面端屏幕尺寸
      setScreenSize(tester, const Size(1440, 900));

      // When: 渲染屏幕
      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Then: 显示桌面端布局
      expect(find.byType(DesktopLayout), findsOneWidget);
      expect(find.byType(MobileLayout), findsNothing);
    });

    testWidgets('it_should_navigate_to_detail_screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // 点击导航到详情
      await tester.tap(find.text('View Details'));
      await tester.pumpAndSettle();

      // 验证导航
      expect(find.byType(DetailScreen), findsOneWidget);
    });
  });
}
```

---

## Integration 测试模板

用于测试完整的用户旅程。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/main.dart';
import 'package:cardmind/screens/home_screen.dart';
import 'package:cardmind/screens/editor_screen.dart';

void main() {
  group('User Journey Tests', () {
    testWidgets('it_should_complete_create_and_edit_journey',
        (WidgetTester tester) async {
      // Given: 应用启动
      await tester.pumpWidget(const CardMindApp());
      await tester.pumpAndSettle();

      // When: 用户创建新卡片
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Then: 进入编辑器
      expect(find.byType(EditorScreen), findsOneWidget);

      // When: 用户输入内容
      await tester.enterText(find.byType(TextField).first, 'My Note');
      await tester.enterText(find.byType(TextField).at(1), 'Note content');

      // When: 用户保存
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Then: 返回主屏幕并显示新卡片
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('My Note'), findsOneWidget);

      // When: 用户点击卡片编辑
      await tester.tap(find.text('My Note'));
      await tester.pumpAndSettle();

      // Then: 再次进入编辑器
      expect(find.byType(EditorScreen), findsOneWidget);
      expect(find.text('My Note'), findsOneWidget);
    });

    testWidgets('it_should_handle_search_and_filter_journey',
        (WidgetTester tester) async {
      // Given: 应用有多张卡片
      await tester.pumpWidget(const CardMindApp());
      await tester.pumpAndSettle();

      // 创建多张卡片
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Card $i');
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
      }

      // When: 用户搜索
      await tester.enterText(find.byType(TextField).first, 'Card 1');
      await tester.pumpAndSettle();

      // Then: 只显示匹配的卡片
      expect(find.text('Card 1'), findsOneWidget);
      expect(find.text('Card 0'), findsNothing);
      expect(find.text('Card 2'), findsNothing);
    });
  });
}
```

---

## 测试辅助函数模板

### Mock Service 模板

```dart
import 'package:cardmind/services/your_service.dart';
import 'package:cardmind/models/your_model.dart';

class MockYourService extends YourService {
  final List<YourModel> _data = [];
  
  bool shouldThrowError = false;
  String? errorMessage;
  int delayMs = 0;
  
  int methodCallCount = 0;

  void reset() {
    _data.clear();
    shouldThrowError = false;
    errorMessage = null;
    delayMs = 0;
    methodCallCount = 0;
  }

  @override
  Future<YourModel> yourMethod(String param) async {
    methodCallCount++;

    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    if (shouldThrowError) {
      throw Exception(errorMessage ?? 'Method failed');
    }

    final result = YourModel(/* ... */);
    _data.add(result);
    return result;
  }

  @override
  Future<List<YourModel>> getData() async {
    if (shouldThrowError) {
      throw Exception(errorMessage ?? 'Get data failed');
    }
    return List.from(_data);
  }
}
```

### Test Helper 函数模板

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 设置屏幕尺寸
void setScreenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// 创建测试用的 MaterialApp
Widget createTestApp(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: child,
    ),
  );
}

/// 等待特定条件
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final end = DateTime.now().add(timeout);
  
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (tester.any(finder)) {
      return;
    }
  }
  
  throw TimeoutException('Timeout waiting for $finder');
}
```

---

## 命名规范

### 测试文件命名

```
功能名_test.dart          # Widget 测试
功能名_spec_test.dart     # Spec 测试
功能名_integration_test.dart  # 集成测试
```

### 测试用例命名

使用 `it_should_xxx()` 格式：

```dart
// ✅ 好的命名
testWidgets('it_should_display_card_title', ...);
testWidgets('it_should_create_card_when_fab_tapped', ...);
testWidgets('it_should_filter_cards_by_search_query', ...);
testWidgets('it_should_handle_network_error_gracefully', ...);

// ❌ 不好的命名
testWidgets('test1', ...);
testWidgets('card display', ...);
testWidgets('testCardCreation', ...);
testWidgets('should display title', ...); // 缺少 it_
```

### Group 命名

```dart
// ✅ 好的 group 命名
group('UI Layout Tests', () { ... });
group('Search Functionality Tests', () { ... });
group('Error Handling Tests', () { ... });
group('Performance Tests', () { ... });
group('Edge Cases', () { ... });

// ❌ 不好的 group 命名
group('Tests', () { ... });
group('test group 1', () { ... });
```

---

## Given-When-Then 注释

每个测试用例都应该有清晰的 Given-When-Then 注释：

```dart
testWidgets('it_should_update_card_when_save_button_pressed',
    (WidgetTester tester) async {
  // Given: 卡片编辑器已打开，用户修改了标题
  await tester.pumpWidget(createEditor(card: testCard));
  await tester.enterText(find.byType(TextField).first, 'New Title');

  // When: 用户点击保存按钮
  await tester.tap(find.text('保存'));
  await tester.pumpAndSettle();

  // Then: 卡片标题应该更新
  expect(savedCard.title, equals('New Title'));
  expect(find.text('保存成功'), findsOneWidget);
});
```

---

## 常用断言

```dart
// 查找 Widget
expect(find.text('Hello'), findsOneWidget);
expect(find.byType(Button), findsWidgets);
expect(find.byIcon(Icons.add), findsNothing);

// 验证值
expect(value, equals(expected));
expect(value, isTrue);
expect(value, isFalse);
expect(value, isNull);
expect(value, isNotNull);

// 验证数字
expect(count, greaterThan(0));
expect(duration, lessThan(100));
expect(value, inRange(0, 10));

// 验证列表
expect(list, isEmpty);
expect(list, isNotEmpty);
expect(list, hasLength(3));
expect(list, contains('item'));

// 验证异常
expect(() => throwError(), throwsException);
expect(() => throwError(), throwsA(isA<CustomException>()));
```

---

## 相关文档

- [测试指南](TESTING_GUIDE.md) - 完整的测试编写指南
- [最佳实践](BEST_PRACTICES.md) - 测试最佳实践
- [Mock API 指南](MOCK_API_GUIDE.md) - Mock 服务使用说明

---

**最后更新**: 2026-01-19
