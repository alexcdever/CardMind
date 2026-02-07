# Flutter Widget 测试最佳实践

本文档提供 Flutter Widget 测试的最佳实践指南，帮助团队编写高质量、可维护的测试代码。

## 目录

1. [测试命名规范](#测试命名规范)
2. [测试结构](#测试结构)
3. [Given-When-Then 模式](#given-when-then-模式)
4. [Mock 使用指南](#mock-使用指南)
5. [常见测试场景](#常见测试场景)
6. [性能优化](#性能优化)
7. [常见陷阱](#常见陷阱)

---

## 测试命名规范

### ✅ 推荐：使用 `it_should_xxx()` 命名风格

```dart
testWidgets('it_should_display_fab_button_on_home_screen', (tester) async {
  // 测试代码
});
```

**优点**：
- 清晰表达预期行为
- 易于搜索和过滤
- 符合 Spec Coding 方法论
- 测试名称即文档

### ❌ 避免：模糊或技术性的命名

```dart
// 不好的命名
testWidgets('test1', (tester) async { });
testWidgets('fab_test', (tester) async { });
testWidgets('home_screen', (tester) async { });
```

---

## 测试结构

### 使用 `group()` 组织测试

```dart
void main() {
  group('SP-FLUT-003: UI Interaction', () {
    // Setup
    late MockCardApi mockApi;

    setUp(() {
      mockApi = MockCardApi();
    });

    tearDown(() {
      mockApi.reset();
    });

    group('FAB Button Tests', () {
      testWidgets('it_should_display_fab_button', (tester) async {
        // 测试代码
      });
    });

    group('Card Creation Tests', () {
      testWidgets('it_should_create_card_on_fab_tap', (tester) async {
        // 测试代码
      });
    });
  });
}
```

**优点**：
- 清晰的层次结构
- 共享 setup/teardown 逻辑
- 易于运行特定测试组

---

## Given-When-Then 模式

### 标准结构

```dart
testWidgets('it_should_save_card_automatically', (tester) async {
  // Given: 用户在编辑器中输入内容
  await tester.pumpWidget(createTestWidget(CardEditor()));
  await tester.enterText(find.byType(TextField), 'Test content');

  // When: 等待自动保存触发（3秒）
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();

  // Then: 卡片应该被保存
  expect(mockApi.createCardCallCount, equals(1));
  expect(mockApi.lastCreatedCard?.content, equals('Test content'));
});
```

**关键点**：
- 使用注释明确标记三个阶段
- Given: 设置前置条件
- When: 执行操作
- Then: 验证结果

---

## Mock 使用指南

### 1. 使用现有的 Mock 类

```dart
// 使用项目中的 MockCardApi
final mockApi = MockCardApi();

// 配置 Mock 行为
mockApi.shouldThrowError = true;
mockApi.delayMs = 100;

// 验证调用
expect(mockApi.createCardCallCount, equals(1));
```

### 2. 创建自定义 Mock

```dart
class MockNavigationService {
  final List<String> navigationHistory = [];

  void push(String route) {
    navigationHistory.add(route);
  }

  bool hasNavigatedTo(String route) {
    return navigationHistory.contains(route);
  }
}
```

### 3. Mock 最佳实践

✅ **推荐**：
- 在 `setUp()` 中创建 Mock
- 在 `tearDown()` 中重置 Mock
- 使用 Mock 隔离外部依赖
- 验证 Mock 的调用次数和参数

❌ **避免**：
- 在测试间共享 Mock 状态
- 过度 Mock（Mock 太多细节）
- Mock 内部实现细节

---

## 常见测试场景

### 1. 测试 Widget 渲染

```dart
testWidgets('it_should_display_card_list', (tester) async {
  // Given: 有 3 张卡片
  mockApi.addCard(Card(id: '1', title: 'Card 1'));
  mockApi.addCard(Card(id: '2', title: 'Card 2'));
  mockApi.addCard(Card(id: '3', title: 'Card 3'));

  // When: 渲染主页
  await tester.pumpWidget(createTestWidget(HomeScreen()));
  await tester.pumpAndSettle();

  // Then: 应该显示 3 张卡片
  expect(find.text('Card 1'), findsOneWidget);
  expect(find.text('Card 2'), findsOneWidget);
  expect(find.text('Card 3'), findsOneWidget);
});
```

### 2. 测试用户交互

```dart
testWidgets('it_should_open_editor_on_fab_tap', (tester) async {
  // Given: 用户在主页
  await tester.pumpWidget(createTestWidget(HomeScreen()));
  await tester.pumpAndSettle();

  // When: 用户点击 FAB 按钮
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();

  // Then: 应该打开编辑器
  expect(find.byType(CardEditor), findsOneWidget);
});
```

### 3. 测试响应式布局

```dart
testWidgets('it_should_show_mobile_layout_on_small_screen', (tester) async {
  // Given: 屏幕宽度为 400px（移动端）
  setScreenSize(tester, const Size(400, 800));

  // When: 渲染主页
  await tester.pumpWidget(createTestWidget(HomeScreen()));
  await tester.pumpAndSettle();

  // Then: 应该显示底部导航栏
  expect(find.byType(BottomNavigationBar), findsOneWidget);
  expect(find.byType(NavigationRail), findsNothing);
});
```

### 4. 测试异步操作

```dart
testWidgets('it_should_show_loading_indicator_during_sync', (tester) async {
  // Given: 同步需要 1 秒
  mockSyncManager.delayMs = 1000;

  await tester.pumpWidget(createTestWidget(HomeScreen()));

  // When: 触发同步
  await tester.tap(find.byIcon(Icons.sync));
  await tester.pump(); // 触发初始渲染

  // Then: 应该显示加载指示器
  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  // When: 等待同步完成
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();

  // Then: 加载指示器应该消失
  expect(find.byType(CircularProgressIndicator), findsNothing);
});
```

### 5. 测试表单验证

```dart
testWidgets('it_should_show_error_for_empty_title', (tester) async {
  // Given: 用户在编辑器中
  await tester.pumpWidget(createTestWidget(CardEditor()));

  // When: 用户尝试保存空标题
  await tester.tap(find.byIcon(Icons.save));
  await tester.pumpAndSettle();

  // Then: 应该显示错误消息
  expect(find.text('标题不能为空'), findsOneWidget);
  expect(mockApi.createCardCallCount, equals(0)); // 不应该调用 API
});
```

### 6. 测试错误处理

```dart
testWidgets('it_should_show_error_message_on_sync_failure', (tester) async {
  // Given: 同步会失败
  mockSyncManager.shouldThrowError = true;

  await tester.pumpWidget(createTestWidget(HomeScreen()));

  // When: 触发同步
  await tester.tap(find.byIcon(Icons.sync));
  await tester.pumpAndSettle();

  // Then: 应该显示错误消息
  expect(find.text('同步失败'), findsOneWidget);
  expect(find.byType(SnackBar), findsOneWidget);
});
```

---

## 性能优化

### 1. 使用 `pump()` 而不是 `pumpAndSettle()`

```dart
// ❌ 慢：等待所有动画完成
await tester.pumpAndSettle();

// ✅ 快：只触发一帧
await tester.pump();

// ✅ 快：等待特定时长
await tester.pump(const Duration(milliseconds: 100));
```

**何时使用**：
- `pump()`: 测试动画中间状态
- `pumpAndSettle()`: 测试最终状态

### 2. 避免不必要的 Widget 重建

```dart
// ❌ 慢：每次都重建整个 App
await tester.pumpWidget(MaterialApp(home: MyWidget()));

// ✅ 快：使用辅助函数
await tester.pumpWidget(createTestWidget(MyWidget()));
```

### 3. 并行运行测试

```bash
# 使用并发运行测试
flutter test --concurrency=4
```

### 4. 减少 Mock 延迟

```dart
// ❌ 慢：模拟真实延迟
mockApi.delayMs = 1000;

// ✅ 快：只在必要时使用延迟
mockApi.delayMs = 0; // 默认值
```

---

## 常见陷阱

### 1. 忘记等待异步操作

```dart
// ❌ 错误：没有等待
await tester.tap(find.byType(FloatingActionButton));
expect(find.byType(CardEditor), findsOneWidget); // 可能失败

// ✅ 正确：等待动画完成
await tester.tap(find.byType(FloatingActionButton));
await tester.pumpAndSettle();
expect(find.byType(CardEditor), findsOneWidget);
```

### 2. 测试间共享状态

```dart
// ❌ 错误：全局变量在测试间共享
final mockApi = MockCardApi(); // 在 main() 外部

void main() {
  testWidgets('test1', (tester) async {
    mockApi.createCard(...); // 影响其他测试
  });
}

// ✅ 正确：在 setUp() 中创建
void main() {
  late MockCardApi mockApi;

  setUp(() {
    mockApi = MockCardApi();
  });
}
```

### 3. 过度依赖 `findsOneWidget`

```dart
// ❌ 脆弱：如果有多个相同文本会失败
expect(find.text('Card'), findsOneWidget);

// ✅ 更好：使用更具体的查找器
expect(find.ancestor(
  of: find.text('Card'),
  matching: find.byType(ListTile),
), findsOneWidget);
```

### 4. 忘记清理资源

```dart
// ❌ 错误：没有清理
testWidgets('test', (tester) async {
  setScreenSize(tester, const Size(400, 800));
  // 测试代码
  // 忘记重置屏幕尺寸
});

// ✅ 正确：使用 addTearDown
void setScreenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
  });
}
```

### 5. 测试实现细节而非行为

```dart
// ❌ 错误：测试内部状态
expect(widget.controller.text, equals('Hello'));

// ✅ 正确：测试用户可见的行为
expect(find.text('Hello'), findsOneWidget);
```

---

## 检查清单

在提交测试代码前，请确认：

- [ ] 所有测试使用 `it_should_xxx()` 命名
- [ ] 每个测试有清晰的 Given-When-Then 注释
- [ ] 使用 `group()` 组织相关测试
- [ ] Mock 在 `setUp()` 中创建，在 `tearDown()` 中重置
- [ ] 异步操作后使用 `pump()` 或 `pumpAndSettle()`
- [ ] 测试行为而非实现细节
- [ ] 测试覆盖正常流程、错误情况和边缘情况
- [ ] 测试执行速度合理（避免不必要的延迟）
- [ ] 测试可以独立运行（不依赖其他测试）
- [ ] 测试名称清晰描述预期行为

---

## 参考资源

- [Flutter 官方测试文档](https://docs.flutter.dev/testing)
- [Spec Coding 方法论](../../../openspec/specs/SPEC_CODING_GUIDE.md)
- [测试模板](../../test/templates/spec_test_template.dart)
- [测试辅助工具](../../test/helpers/test_helpers.dart)
