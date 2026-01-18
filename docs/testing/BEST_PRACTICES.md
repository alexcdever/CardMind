# 测试最佳实践

本文档总结 CardMind 项目的测试最佳实践，帮助开发者编写高质量、可维护的测试代码。

## 目录

- [测试设计原则](#测试设计原则)
- [测试结构](#测试结构)
- [Mock 和依赖注入](#mock-和依赖注入)
- [UI 测试技巧](#ui-测试技巧)
- [性能测试](#性能测试)
- [常见陷阱](#常见陷阱)
- [代码审查清单](#代码审查清单)

---

## 测试设计原则

### 1. FIRST 原则

好的测试应该遵循 FIRST 原则：

- **Fast (快速)**: 测试应该快速执行
- **Independent (独立)**: 测试之间不应该有依赖
- **Repeatable (可重复)**: 测试结果应该一致
- **Self-Validating (自验证)**: 测试应该自动判断通过或失败
- **Timely (及时)**: 测试应该及时编写（TDD）

### 2. AAA 模式 (Arrange-Act-Assert)

在 CardMind 中我们使用 Given-When-Then，这是 AAA 的变体：

```dart
testWidgets('it_should_create_card_when_button_pressed', (tester) async {
  // Given (Arrange): 准备测试环境
  await mockCardService.initialize();
  await tester.pumpWidget(createHomeScreen());
  
  // When (Act): 执行操作
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  
  // Then (Assert): 验证结果
  expect(mockCardService.createCardCallCount, equals(1));
  expect(find.text('新卡片'), findsOneWidget);
});
```

### 3. 单一职责

每个测试只验证一个行为：

```dart
// ✅ 好的做法：每个测试验证一个行为
testWidgets('it_should_display_card_title', (tester) async {
  await tester.pumpWidget(createCard(title: 'Test'));
  expect(find.text('Test'), findsOneWidget);
});

testWidgets('it_should_display_card_content', (tester) async {
  await tester.pumpWidget(createCard(content: 'Content'));
  expect(find.text('Content'), findsOneWidget);
});

// ❌ 不好的做法：一个测试验证多个行为
testWidgets('it_should_display_card', (tester) async {
  await tester.pumpWidget(createCard(title: 'Test', content: 'Content'));
  expect(find.text('Test'), findsOneWidget);
  expect(find.text('Content'), findsOneWidget);
  expect(find.byType(Icon), findsWidgets);
  expect(find.byType(Button), findsOneWidget);
  // ... 太多验证
});
```

### 4. 测试金字塔

遵循测试金字塔原则：

```
        /\
       /  \      E2E Tests (少量)
      /____\     
     /      \    Integration Tests (适量)
    /________\   
   /          \  Unit Tests (大量)
  /____________\ 
```

- **单元测试 (70%)**: 快速、隔离、大量
- **集成测试 (20%)**: 测试组件协作
- **E2E 测试 (10%)**: 测试完整用户旅程

---

## 测试结构

### 1. 使用 Group 组织测试

```dart
void main() {
  group('CardWidget Tests', () {
    group('Display Tests', () {
      testWidgets('it_should_display_title', ...);
      testWidgets('it_should_display_content', ...);
    });
    
    group('Interaction Tests', () {
      testWidgets('it_should_handle_tap', ...);
      testWidgets('it_should_handle_long_press', ...);
    });
    
    group('Edge Cases', () {
      testWidgets('it_should_handle_empty_title', ...);
      testWidgets('it_should_handle_null_content', ...);
    });
  });
}
```

### 2. 使用 setUp 和 tearDown

```dart
void main() {
  group('HomeScreen Tests', () {
    late MockCardService mockCardService;
    late CardProvider provider;

    setUp(() {
      // 每个测试前执行
      mockCardService = MockCardService();
      provider = CardProvider(cardService: mockCardService);
    });

    tearDown(() {
      // 每个测试后执行
      mockCardService.reset();
      provider.dispose();
    });

    testWidgets('it_should_load_cards', (tester) async {
      // 测试代码
    });
  });
}
```

### 3. 使用 setUpAll 和 tearDownAll

```dart
void main() {
  group('Integration Tests', () {
    setUpAll(() {
      // 所有测试前执行一次（用于昂贵的初始化）
      initializeTestEnvironment();
    });

    tearDownAll(() {
      // 所有测试后执行一次（用于清理）
      cleanupTestEnvironment();
    });

    // 测试用例...
  });
}
```

---

## Mock 和依赖注入

### 1. 使用 Mock 服务

```dart
// ✅ 好的做法：使用 Mock 避免真实依赖
class MockCardService extends CardService {
  final List<Card> _cards = [];
  bool shouldThrowError = false;
  
  @override
  Future<Card> createCard(String title, String content) async {
    if (shouldThrowError) {
      throw Exception('Create failed');
    }
    final card = Card(id: 'test-id', title: title, content: content);
    _cards.add(card);
    return card;
  }
}

// 在测试中使用
final mockService = MockCardService();
final provider = CardProvider(cardService: mockService);

// ❌ 不好的做法：使用真实服务
final provider = CardProvider(); // 需要 Rust Bridge 初始化
```

### 2. 依赖注入

```dart
// ✅ 好的做法：支持依赖注入
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.syncStatusStream, // 可选参数用于测试
  });

  final Stream<SyncStatus>? syncStatusStream;
  
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// 在测试中注入 Mock
HomeScreen(
  syncStatusStream: Stream.value(SyncStatus.disconnected()),
)

// ❌ 不好的做法：硬编码依赖
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // 硬编码，无法测试
    _stream = sync_api.getSyncStatusStream();
  }
}
```

### 3. 控制 Mock 行为

```dart
testWidgets('it_should_handle_error', (tester) async {
  // Given: Mock 配置为抛出错误
  mockCardService.shouldThrowError = true;
  mockCardService.errorMessage = 'Network error';
  
  // When: 执行操作
  await tester.pumpWidget(createHomeScreen());
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  
  // Then: 验证错误处理
  expect(find.text('Network error'), findsOneWidget);
});

testWidgets('it_should_handle_delay', (tester) async {
  // Given: Mock 配置延迟
  mockCardService.delayMs = 1000;
  
  // When: 执行操作
  await tester.pumpWidget(createHomeScreen());
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pump(); // 不等待完成
  
  // Then: 验证加载状态
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  
  // 等待完成
  await tester.pumpAndSettle();
  expect(find.byType(CircularProgressIndicator), findsNothing);
});
```

---

## UI 测试技巧

### 1. 精确定位 Widget

```dart
// ✅ 好的做法：使用精确的 Finder
// 使用 ancestor 定位
final closeButton = find.ancestor(
  of: find.byIcon(Icons.close),
  matching: find.byType(IconButton),
).first;

// 使用 descendant 定位
final chipDeleteButton = find.descendant(
  of: find.widgetWithText(Chip, 'tag1'),
  matching: find.byIcon(Icons.close),
);

// 使用 widgetWithText 精确匹配
final saveButton = find.widgetWithText(ElevatedButton, '保存');

// ❌ 不好的做法：模糊查找
final button = find.byIcon(Icons.close); // 可能找到多个
final text = find.text('保存'); // 可能在多个 Widget 中
```

### 2. 等待渲染

```dart
// ✅ 好的做法：根据情况选择合适的等待方式
// 等待所有动画完成
await tester.pumpAndSettle();

// 单次渲染（用于无限动画）
await tester.pump();

// 等待特定时间
await tester.pump(const Duration(milliseconds: 100));

// 等待多次渲染
for (int i = 0; i < 5; i++) {
  await tester.pump(const Duration(milliseconds: 100));
}

// ❌ 不好的做法：不等待或等待不当
await tester.pumpWidget(widget);
// 立即验证，可能还没渲染完成
expect(find.text('Result'), findsOneWidget);
```

### 3. 处理异步操作

```dart
testWidgets('it_should_load_data_asynchronously', (tester) async {
  // Given: 配置异步加载
  mockCardService.delayMs = 500;
  
  await tester.pumpWidget(createHomeScreen());
  
  // When: 触发加载
  await tester.tap(find.text('刷新'));
  await tester.pump(); // 开始异步操作
  
  // Then: 验证加载状态
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  
  // 等待异步操作完成
  await tester.pumpAndSettle();
  
  // Then: 验证加载完成
  expect(find.byType(CircularProgressIndicator), findsNothing);
  expect(find.text('数据已加载'), findsOneWidget);
});
```

### 4. 测试响应式布局

```dart
testWidgets('it_should_adapt_to_screen_size', (tester) async {
  // Given: 移动端尺寸
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  
  // When: 渲染
  await tester.pumpWidget(createHomeScreen());
  await tester.pumpAndSettle();
  
  // Then: 验证移动端布局
  expect(find.byType(MobileLayout), findsOneWidget);
  
  // When: 改变为桌面端尺寸
  tester.view.physicalSize = const Size(1440, 900);
  await tester.pumpAndSettle();
  
  // Then: 验证桌面端布局
  expect(find.byType(DesktopLayout), findsOneWidget);
});
```

### 5. 测试滚动

```dart
testWidgets('it_should_scroll_to_bottom', (tester) async {
  await tester.pumpWidget(createLongList());
  
  // 滚动到底部
  await tester.drag(
    find.byType(ListView),
    const Offset(0, -500), // 向上滚动 500 像素
  );
  await tester.pumpAndSettle();
  
  // 验证底部元素可见
  expect(find.text('Item 99'), findsOneWidget);
});

testWidgets('it_should_scroll_to_specific_item', (tester) async {
  await tester.pumpWidget(createLongList());
  
  // 滚动到特定元素
  await tester.scrollUntilVisible(
    find.text('Item 50'),
    500.0, // 每次滚动 500 像素
  );
  
  expect(find.text('Item 50'), findsOneWidget);
});
```

---

## 性能测试

### 1. 测试渲染性能

```dart
testWidgets('it_should_render_within_reasonable_time', (tester) async {
  // Given: 准备渲染
  final stopwatch = Stopwatch()..start();
  
  // When: 渲染 Widget
  await tester.pumpWidget(createComplexWidget());
  await tester.pumpAndSettle();
  stopwatch.stop();
  
  // Then: 验证渲染时间
  // 注意：测试环境允许更宽松的时间限制
  expect(stopwatch.elapsedMilliseconds, lessThan(200));
  
  // 添加注释说明
  // 生产环境的实际性能会更好
});
```

### 2. 测试大数据集性能

```dart
testWidgets('it_should_handle_large_dataset_efficiently', (tester) async {
  // Given: 大量数据
  mockCardService.cardCount = 1000;
  
  final stopwatch = Stopwatch()..start();
  
  // When: 渲染列表
  await tester.pumpWidget(createHomeScreen());
  await tester.pumpAndSettle();
  stopwatch.stop();
  
  // Then: 验证性能
  expect(stopwatch.elapsedMilliseconds, lessThan(500));
  
  // 验证虚拟化（只渲染可见项）
  final listView = tester.widget<ListView>(find.byType(ListView));
  expect(listView.semanticChildCount, equals(1000));
});
```

### 3. 避免性能测试的常见问题

```dart
// ❌ 不好的做法：使用生产环境的严格限制
testWidgets('it_should_render_in_16ms', (tester) async {
  final stopwatch = Stopwatch()..start();
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
  stopwatch.stop();
  
  // 测试环境无法达到 16ms
  expect(stopwatch.elapsedMilliseconds, lessThan(16)); // 会失败
});

// ✅ 好的做法：使用合理的测试环境限制
testWidgets('it_should_render_within_reasonable_time', (tester) async {
  final stopwatch = Stopwatch()..start();
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
  stopwatch.stop();
  
  // 测试环境允许更宽松的限制
  expect(stopwatch.elapsedMilliseconds, lessThan(200));
  
  // 注释说明：生产环境性能会更好
});
```

---

## 常见陷阱

### 1. 避免测试实现细节

```dart
// ❌ 不好的做法：测试实现细节
testWidgets('it_should_call_setState', (tester) async {
  // 不要测试 setState 是否被调用
  // 这是实现细节
});

// ✅ 好的做法：测试行为
testWidgets('it_should_update_display_when_data_changes', (tester) async {
  await tester.pumpWidget(createWidget());
  
  // 触发数据变化
  await tester.tap(find.text('更新'));
  await tester.pumpAndSettle();
  
  // 验证 UI 更新
  expect(find.text('新数据'), findsOneWidget);
});
```

### 2. 避免脆弱的测试

```dart
// ❌ 不好的做法：依赖具体的文本内容
testWidgets('it_should_display_error', (tester) async {
  expect(find.text('Error: Network connection failed at 192.168.1.1'), 
         findsOneWidget);
});

// ✅ 好的做法：验证关键信息
testWidgets('it_should_display_error', (tester) async {
  expect(find.textContaining('Error'), findsOneWidget);
  expect(find.textContaining('Network'), findsOneWidget);
});

// 或使用语义化的 Key
testWidgets('it_should_display_error', (tester) async {
  expect(find.byKey(const Key('error_message')), findsOneWidget);
});
```

### 3. 避免测试之间的依赖

```dart
// ❌ 不好的做法：测试之间有依赖
int globalCounter = 0;

testWidgets('test1', (tester) async {
  globalCounter++;
  expect(globalCounter, equals(1));
});

testWidgets('test2', (tester) async {
  // 依赖 test1 的执行
  expect(globalCounter, equals(1)); // 如果 test1 没执行会失败
});

// ✅ 好的做法：每个测试独立
testWidgets('test1', (tester) async {
  int counter = 0;
  counter++;
  expect(counter, equals(1));
});

testWidgets('test2', (tester) async {
  int counter = 0;
  counter++;
  expect(counter, equals(1));
});
```

### 4. 避免过度 Mock

```dart
// ❌ 不好的做法：Mock 所有东西
class MockEverything {
  // Mock 了太多内部实现
}

// ✅ 好的做法：只 Mock 外部依赖
class MockCardService extends CardService {
  // 只 Mock 外部服务
}

// 真实的 Widget 和 Model 不需要 Mock
final card = Card(title: 'Test', content: 'Content');
final widget = NoteCard(card: card);
```

---

## 代码审查清单

在提交测试代码前，检查以下项目：

### 基本要求
- [ ] 所有测试都通过
- [ ] 测试命名使用 `it_should_xxx()` 格式
- [ ] 使用 Given-When-Then 注释
- [ ] 每个测试只验证一个行为
- [ ] 测试之间相互独立

### 代码质量
- [ ] 没有硬编码的值（使用常量或变量）
- [ ] 没有重复代码（使用 Helper 函数）
- [ ] Mock 服务在 tearDown 中重置
- [ ] 使用精确的 Finder（避免模糊查找）
- [ ] 适当使用 setUp 和 tearDown

### 覆盖率
- [ ] 测试了正常流程
- [ ] 测试了错误情况
- [ ] 测试了边缘情况
- [ ] 测试了性能要求（如果有）

### 文档
- [ ] 测试文件有清晰的文档注释
- [ ] 复杂的测试有额外的注释说明
- [ ] 规格编号正确（如 SP-XXX-XXX）

### 性能
- [ ] 测试执行时间合理（< 5 秒）
- [ ] 没有不必要的 pumpAndSettle
- [ ] 没有不必要的延迟

---

## 参考资源

- [Flutter 测试文档](https://docs.flutter.dev/testing)
- [测试指南](TESTING_GUIDE.md)
- [测试模板](TEST_TEMPLATE.md)
- [Mock API 指南](MOCK_API_GUIDE.md)

---

**最后更新**: 2026-01-19
