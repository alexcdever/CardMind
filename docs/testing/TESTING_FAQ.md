# 测试常见问题和解决方案（FAQ）

本文档收集了 CardMind 项目中测试相关的常见问题和解决方案。

## 目录

- [测试环境问题](#测试环境问题)
- [测试编写问题](#测试编写问题)
- [测试运行问题](#测试运行问题)
- [测试失败问题](#测试失败问题)
- [覆盖率问题](#覆盖率问题)
- [CI/CD 问题](#cicd-问题)
- [最佳实践问题](#最佳实践问题)

---

## 测试环境问题

### Q1: 测试运行时提示 "Rust Bridge not initialized"

**问题描述**:
```
Error: Rust Bridge not initialized
```

**原因**: 测试环境中没有初始化 Rust Bridge，导致无法调用 Rust 后端功能。

**解决方案**:

**方案 A: Mock Rust API**（推荐用于单元测试）
```dart
import 'package:mockito/mockito.dart';

class MockCardApi extends Mock implements CardApi {}

void main() {
  late MockCardApi mockApi;
  
  setUp(() {
    mockApi = MockCardApi();
    // 注入 Mock API
    getIt.registerSingleton<CardApi>(mockApi);
  });
  
  test('it_should_create_card', () {
    when(mockApi.createCard(any)).thenAnswer((_) async => mockCard);
    // 测试逻辑
  });
}
```

**方案 B: 跳过需要 Rust Bridge 的测试**（临时方案）
```dart
test('it_should_sync_with_backend', () {
  // 需要完整集成环境
}, skip: 'Requires Rust Bridge initialization');
```

**方案 C: 设置集成测试环境**（用于集成测试）
```dart
void main() {
  setUpAll(() async {
    // 初始化 Rust Bridge
    await RustLib.init();
  });
  
  // 集成测试
}
```

---

### Q2: 测试运行时提示 "No MediaQuery widget found"

**问题描述**:
```
Error: No MediaQuery widget found
```

**原因**: Widget 测试中没有提供 `MediaQuery` 上下文。

**解决方案**:

```dart
testWidgets('it_should_render_widget', (tester) async {
  await tester.pumpWidget(
    MaterialApp(  // MaterialApp 自动提供 MediaQuery
      home: MyWidget(),
    ),
  );
  
  // 或者手动提供 MediaQuery
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(),
      child: MyWidget(),
    ),
  );
});
```

---

### Q3: 测试运行时提示 "No Directionality widget found"

**问题描述**:
```
Error: No Directionality widget found
```

**原因**: Widget 需要文本方向信息，但没有提供 `Directionality` 或 `MaterialApp`。

**解决方案**:

```dart
testWidgets('it_should_render_text', (tester) async {
  await tester.pumpWidget(
    MaterialApp(  // MaterialApp 自动提供 Directionality
      home: MyWidget(),
    ),
  );
  
  // 或者手动提供 Directionality
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MyWidget(),
    ),
  );
});
```

---

## 测试编写问题

### Q4: 如何测试异步操作？

**问题描述**: 需要测试异步函数或 Future。

**解决方案**:

```dart
test('it_should_load_data_asynchronously', () async {
  // 使用 async/await
  final result = await loadData();
  expect(result, isNotNull);
});

testWidgets('it_should_show_loading_indicator', (tester) async {
  await tester.pumpWidget(MyApp());
  
  // 触发异步操作
  await tester.tap(find.byType(ElevatedButton));
  await tester.pump();  // 触发一帧
  
  // 验证 loading 状态
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  
  // 等待异步操作完成
  await tester.pumpAndSettle();  // 等待所有动画和异步操作完成
  
  // 验证结果
  expect(find.text('Data loaded'), findsOneWidget);
});
```

**注意**: 
- `pump()`: 触发一帧渲染
- `pumpAndSettle()`: 等待所有动画和异步操作完成（有超时限制）
- `pump(Duration)`: 触发指定时长的动画

---

### Q5: 如何测试 Stream？

**问题描述**: 需要测试 Stream 数据流。

**解决方案**:

```dart
test('it_should_emit_values_from_stream', () async {
  final stream = Stream.fromIterable([1, 2, 3]);
  
  // 方法 1: 使用 expectLater
  expectLater(stream, emitsInOrder([1, 2, 3]));
  
  // 方法 2: 使用 await for
  final values = <int>[];
  await for (final value in stream) {
    values.add(value);
  }
  expect(values, [1, 2, 3]);
});

testWidgets('it_should_update_ui_from_stream', (tester) async {
  final controller = StreamController<String>();
  
  await tester.pumpWidget(
    MaterialApp(
      home: StreamBuilder<String>(
        stream: controller.stream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Text(snapshot.data!);
          }
          return const Text('Loading');
        },
      ),
    ),
  );
  
  // 初始状态
  expect(find.text('Loading'), findsOneWidget);
  
  // 发送数据
  controller.add('Hello');
  await tester.pump();
  
  // 验证更新
  expect(find.text('Hello'), findsOneWidget);
  
  // 清理
  await controller.close();
});
```

---

### Q6: 如何测试 Provider 状态管理？

**问题描述**: 需要测试使用 Provider 的 Widget。

**解决方案**:

```dart
testWidgets('it_should_update_when_provider_changes', (tester) async {
  final model = MyModel();
  
  await tester.pumpWidget(
    ChangeNotifierProvider<MyModel>.value(
      value: model,
      child: MaterialApp(
        home: MyWidget(),
      ),
    ),
  );
  
  // 初始状态
  expect(find.text('Count: 0'), findsOneWidget);
  
  // 修改状态
  model.increment();
  await tester.pump();
  
  // 验证更新
  expect(find.text('Count: 1'), findsOneWidget);
});
```

---

### Q7: 如何测试导航（路由跳转）？

**问题描述**: 需要测试页面跳转。

**解决方案**:

```dart
testWidgets('it_should_navigate_to_detail_page', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomePage(),
      routes: {
        '/detail': (context) => DetailPage(),
      },
    ),
  );
  
  // 触发导航
  await tester.tap(find.text('Go to Detail'));
  await tester.pumpAndSettle();
  
  // 验证导航成功
  expect(find.byType(DetailPage), findsOneWidget);
  expect(find.byType(HomePage), findsNothing);
});

// 测试返回导航
testWidgets('it_should_navigate_back', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DetailPage(),
    ),
  );
  
  // 触发返回
  await tester.tap(find.byIcon(Icons.arrow_back));
  await tester.pumpAndSettle();
  
  // 验证返回成功（需要配合 Navigator observer）
});
```

---

## 测试运行问题

### Q8: 测试运行很慢怎么办？

**问题描述**: 测试套件运行时间过长。

**解决方案**:

**方案 A: 并行运行测试**
```bash
# 使用多个并发进程
flutter test --concurrency=4

# 或在 CI 中配置
flutter test --concurrency=8
```

**方案 B: 减少 pumpAndSettle 使用**
```dart
// ❌ 慢：等待所有动画完成
await tester.pumpAndSettle();

// ✅ 快：只触发必要的帧
await tester.pump();
await tester.pump(const Duration(milliseconds: 100));
```

**方案 C: 跳过慢速测试**
```dart
test('it_should_handle_large_dataset', () {
  // 慢速测试
}, skip: 'Slow test, run manually');

// 或使用 tags
test('it_should_handle_large_dataset', () {
  // 慢速测试
}, tags: ['slow']);

// 运行时排除慢速测试
// flutter test --exclude-tags=slow
```

**方案 D: 优化测试数据**
```dart
// ❌ 慢：使用大量数据
final cards = List.generate(1000, (i) => Card(...));

// ✅ 快：使用最小必要数据
final cards = [Card(...), Card(...)];  // 只用 2 个测试
```

---

### Q9: 测试运行时提示 "pumpAndSettle timeout"

**问题描述**:
```
Error: pumpAndSettle timed out
```

**原因**: 有无限循环的动画或异步操作。

**解决方案**:

**方案 A: 增加超时时间**
```dart
await tester.pumpAndSettle(const Duration(seconds: 10));
```

**方案 B: 使用 pump 代替 pumpAndSettle**
```dart
// 不等待所有动画完成
await tester.pump();
await tester.pump(const Duration(milliseconds: 300));
```

**方案 C: 检查并修复无限动画**
```dart
// 检查是否有无限循环的动画
// 例如：CircularProgressIndicator 会一直旋转

// 解决方法：在测试中 mock 掉无限动画
testWidgets('it_should_show_loading', (tester) async {
  await tester.pumpWidget(MyApp());
  
  // 只验证 loading 存在，不等待完成
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  // 不调用 pumpAndSettle
});
```

---

### Q10: 如何运行特定的测试？

**问题描述**: 只想运行某些测试，不想运行全部。

**解决方案**:

```bash
# 运行特定文件
flutter test test/specs/card_creation_spec_test.dart

# 运行特定目录
flutter test test/specs/

# 运行匹配名称的测试
flutter test --name "card creation"

# 运行带特定 tag 的测试
flutter test --tags=unit

# 排除特定 tag 的测试
flutter test --exclude-tags=slow

# 运行单个测试（使用 solo）
test('it_should_work', () {
  // 测试逻辑
}, solo: true);  // 只运行这个测试
```

---

## 测试失败问题

### Q11: 测试失败提示 "Expected: 1, Actual: 0"

**问题描述**: Finder 找不到预期的 Widget。

**解决方案**:

**步骤 1: 打印 Widget 树**
```dart
testWidgets('debug test', (tester) async {
  await tester.pumpWidget(MyApp());
  
  // 打印整个 Widget 树
  debugDumpApp();
  
  // 或打印渲染树
  debugDumpRenderTree();
});
```

**步骤 2: 检查 Widget 是否渲染**
```dart
// 检查 Widget 类型
expect(find.byType(MyWidget), findsOneWidget);

// 检查文本（注意大小写和空格）
expect(find.text('Hello'), findsOneWidget);

// 使用更宽松的匹配
expect(find.textContaining('Hello'), findsOneWidget);

// 检查 Key
expect(find.byKey(const Key('my-widget')), findsOneWidget);
```

**步骤 3: 确保 Widget 已渲染**
```dart
await tester.pumpWidget(MyApp());
await tester.pump();  // 触发一帧渲染

// 如果是异步加载的 Widget
await tester.pumpAndSettle();
```

---

### Q12: 测试失败提示 "Multiple widgets found"

**问题描述**:
```
Error: Expected to find one widget, but found 2
```

**原因**: Finder 找到了多个匹配的 Widget。

**解决方案**:

```dart
// ❌ 问题：找到多个
await tester.tap(find.byIcon(Icons.close));

// ✅ 解决方案 1: 使用 first
await tester.tap(find.byIcon(Icons.close).first);

// ✅ 解决方案 2: 使用 at(index)
await tester.tap(find.byIcon(Icons.close).at(0));

// ✅ 解决方案 3: 使用更具体的 Finder
await tester.tap(find.descendant(
  of: find.byType(AppBar),
  matching: find.byIcon(Icons.close),
));

// ✅ 解决方案 4: 使用 Key
await tester.tap(find.byKey(const Key('close-button')));
```

---

### Q13: 测试失败提示 "setState called after dispose"

**问题描述**:
```
Error: setState() called after dispose()
```

**原因**: Widget 已经销毁，但仍然尝试调用 setState。

**解决方案**:

```dart
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  Future<void> loadData() async {
    final data = await fetchData();
    
    // ✅ 检查 mounted 状态
    if (!mounted) return;
    
    setState(() {
      _data = data;
    });
  }
  
  @override
  void dispose() {
    // 取消异步操作
    _subscription?.cancel();
    super.dispose();
  }
}
```

---

## 覆盖率问题

### Q14: 如何生成测试覆盖率报告？

**问题描述**: 需要查看代码覆盖率。

**解决方案**:

```bash
# 生成覆盖率数据
flutter test --coverage

# 查看覆盖率文件
cat coverage/lcov.info

# 生成 HTML 报告（需要安装 lcov）
# macOS: brew install lcov
# Ubuntu: sudo apt-get install lcov

genhtml coverage/lcov.info -o coverage/html

# 打开报告
open coverage/html/index.html  # macOS
xdg-open coverage/html/index.html  # Linux
```

**在 VS Code 中查看覆盖率**:
1. 安装 "Coverage Gutters" 插件
2. 运行 `flutter test --coverage`
3. 按 `Cmd+Shift+P` → "Coverage Gutters: Display Coverage"

---

### Q15: 覆盖率报告中包含生成的文件怎么办？

**问题描述**: 覆盖率报告包含 `*.g.dart`、`*.freezed.dart` 等生成文件。

**解决方案**:

创建 `coverage_filter.sh` 脚本：
```bash
#!/bin/bash

# 过滤生成的文件
lcov --remove coverage/lcov.info \
  '**/*.g.dart' \
  '**/*.freezed.dart' \
  '**/generated/**' \
  '**/l10n/**' \
  -o coverage/lcov_filtered.info

# 生成 HTML 报告
genhtml coverage/lcov_filtered.info -o coverage/html
```

运行：
```bash
flutter test --coverage
bash coverage_filter.sh
```

---

## CI/CD 问题

### Q16: CI 中测试失败，但本地通过？

**问题描述**: 本地测试通过，但 CI 中失败。

**可能原因和解决方案**:

**原因 1: 依赖版本不一致**
```yaml
# .github/workflows/flutter_tests.yml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.16.0'  # 锁定版本
    channel: 'stable'
```

**原因 2: 时区或语言环境不同**
```dart
// 在测试中固定时区
test('it_should_format_date', () {
  // 使用 UTC 时间
  final date = DateTime.utc(2024, 1, 1);
  expect(formatDate(date), '2024-01-01');
});
```

**原因 3: 文件路径问题（Windows vs Linux）**
```dart
// ❌ 硬编码路径分隔符
final path = 'data/cards/123.json';

// ✅ 使用 path 包
import 'package:path/path.dart' as p;
final path = p.join('data', 'cards', '123.json');
```

**原因 4: 并发问题**
```bash
# 减少并发数
flutter test --concurrency=1
```

---

### Q17: 如何在 CI 中跳过某些测试？

**问题描述**: 某些测试需要特定环境，在 CI 中无法运行。

**解决方案**:

```dart
// 方法 1: 使用环境变量
test('it_should_connect_to_real_backend', () {
  // 测试逻辑
}, skip: Platform.environment['CI'] == 'true' 
    ? 'Skipped in CI' 
    : false);

// 方法 2: 使用 tags
test('it_should_test_integration', () {
  // 测试逻辑
}, tags: ['integration']);

// CI 中排除 integration 测试
// flutter test --exclude-tags=integration
```

---

## 最佳实践问题

### Q18: 测试命名有什么规范？

**问题描述**: 如何命名测试？

**解决方案**:

遵循 Spec Coding 方法论：

```dart
// ✅ 推荐：使用 it_should_xxx() 风格
test('it_should_create_card_when_valid_input_provided', () {
  // Given-When-Then 结构
  
  // Given: 准备测试数据
  final title = 'Test Card';
  final content = 'Test Content';
  
  // When: 执行操作
  final card = createCard(title, content);
  
  // Then: 验证结果
  expect(card.title, title);
  expect(card.content, content);
});

// ❌ 避免：模糊的命名
test('test card creation', () { ... });
test('card test', () { ... });
```

**命名模式**:
- `it_should_<action>_when_<condition>()`
- `it_should_<action>_given_<precondition>()`
- `it_should_not_<action>_when_<condition>()`

---

### Q19: 如何组织测试代码？

**问题描述**: 测试文件结构如何组织？

**解决方案**:

```dart
void main() {
  // 1. 共享的测试数据和 Mock
  late MockCardApi mockApi;
  late CardService service;
  
  // 2. setUp: 每个测试前执行
  setUp(() {
    mockApi = MockCardApi();
    service = CardService(mockApi);
  });
  
  // 3. tearDown: 每个测试后执行
  tearDown(() {
    // 清理资源
  });
  
  // 4. setUpAll: 所有测试前执行一次
  setUpAll(() {
    // 初始化全局资源
  });
  
  // 5. tearDownAll: 所有测试后执行一次
  tearDownAll(() {
    // 清理全局资源
  });
  
  // 6. 使用 group 组织相关测试
  group('Card Creation', () {
    test('it_should_create_card_with_valid_input', () { ... });
    test('it_should_reject_empty_title', () { ... });
  });
  
  group('Card Deletion', () {
    test('it_should_soft_delete_card', () { ... });
    test('it_should_not_delete_nonexistent_card', () { ... });
  });
}
```

---

### Q20: 如何编写可维护的测试？

**问题描述**: 测试代码难以维护。

**解决方案**:

**原则 1: DRY（Don't Repeat Yourself）**
```dart
// ❌ 重复代码
test('test 1', () {
  await tester.pumpWidget(MaterialApp(home: MyWidget()));
  // ...
});

test('test 2', () {
  await tester.pumpWidget(MaterialApp(home: MyWidget()));
  // ...
});

// ✅ 提取辅助函数
Future<void> pumpMyWidget(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(home: MyWidget()));
}

test('test 1', () async {
  await pumpMyWidget(tester);
  // ...
});
```

**原则 2: 单一职责**
```dart
// ❌ 测试太多东西
test('it_should_do_everything', () {
  // 测试创建
  // 测试更新
  // 测试删除
  // 测试验证
});

// ✅ 每个测试只测一件事
test('it_should_create_card', () { ... });
test('it_should_update_card', () { ... });
test('it_should_delete_card', () { ... });
```

**原则 3: 清晰的 Given-When-Then**
```dart
test('it_should_show_error_when_title_empty', () {
  // Given: 准备空标题
  final title = '';
  
  // When: 尝试创建卡片
  final result = validateTitle(title);
  
  // Then: 应该返回错误
  expect(result.isValid, false);
  expect(result.error, 'Title cannot be empty');
});
```

---

## 相关文档

- [测试指南](TESTING_GUIDE.md) - 完整的测试编写指南
- [测试-规格映射](TEST_SPEC_MAPPING.md) - 测试与规格的映射关系
- [最佳实践](BEST_PRACTICES.md) - 测试最佳实践

---

**最后更新**: 2026-01-19
**维护者**: CardMind Team

**贡献**: 如果你遇到了新的问题和解决方案，欢迎补充到本文档！
