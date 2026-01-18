# CardMind 测试指南

## 目录

- [概述](#概述)
- [测试架构](#测试架构)
- [运行测试](#运行测试)
- [编写测试](#编写测试)
- [测试类型](#测试类型)
- [最佳实践](#最佳实践)
- [常见问题](#常见问题)

## 概述

CardMind 采用 **Spec Coding** 方法论进行测试驱动开发（TDD）：

- **测试即规格**：测试用例就是功能规格说明
- **规格即文档**：测试代码本身就是最准确的文档
- **Given-When-Then**：使用 BDD 风格的测试结构

### 测试统计

- ✅ **通过**: 579 个测试
- ⚠️ **失败**: 47 个测试（需要完整集成环境）
- 📊 **成功率**: 92.5%
- 🎯 **规格覆盖**: 19/19 规格 (100%)

## 测试架构

```
test/
├── specs/              # 规格测试（Spec Coding）
│   ├── adaptive_ui_system_spec_test.dart
│   ├── card_editor_spec_test.dart
│   ├── home_screen_ui_spec_test.dart
│   └── ...
├── widgets/            # Widget 单元测试
│   ├── note_card_test.dart
│   ├── fullscreen_editor_test.dart
│   └── ...
├── screens/            # Screen 集成测试
│   └── home_screen_adaptive_test.dart
├── integration/        # 端到端集成测试
│   └── user_journey_test.dart
├── helpers/            # 测试辅助工具
│   ├── mock_card_service.dart
│   ├── mock_utils.dart
│   └── test_helpers.dart
└── templates/          # 测试模板
    └── spec_test_template.dart
```

## 运行测试

### 基本命令

```bash
# 运行所有测试
flutter test

# 运行特定目录的测试
flutter test test/specs/
flutter test test/widgets/
flutter test test/screens/

# 运行单个测试文件
flutter test test/specs/home_screen_ui_spec_test.dart

# 运行特定测试用例
flutter test --plain-name 'it_should_display_app_bar_with_title'

# 生成覆盖率报告
flutter test --coverage
```

### 代码质量检查

```bash
# 静态分析
flutter analyze

# 代码格式化
dart format .

# 自动修复问题
dart fix --apply

# 验证项目约束
dart tool/validate_constraints.dart
```

## 编写测试

### Spec Coding 测试模板

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 规格编号: SP-XXX-XXX
/// 功能描述
///
/// 测试遵循 Spec Coding 方法论：
/// - 测试即规格，规格即文档
/// - 使用 it_should_xxx() 命名风格
/// - Given-When-Then 结构

void main() {
  group('SP-XXX-XXX: Feature Name', () {
    late MockService mockService;

    setUp(() {
      mockService = MockService();
    });

    group('Scenario Group', () {
      testWidgets('it_should_do_something', (WidgetTester tester) async {
        // Given: 前置条件
        await mockService.setupData();

        // When: 执行操作
        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.byType(Button));
        await tester.pumpAndSettle();

        // Then: 验证结果
        expect(find.text('Expected Result'), findsOneWidget);
      });
    });
  });
}
```

### 测试命名规范

使用 `it_should_xxx()` 格式，清晰描述测试意图：

```dart
// ✅ 好的命名
testWidgets('it_should_display_card_title', ...);
testWidgets('it_should_create_card_when_fab_tapped', ...);
testWidgets('it_should_filter_cards_by_search_query', ...);

// ❌ 不好的命名
testWidgets('test1', ...);
testWidgets('card display', ...);
testWidgets('testCardCreation', ...);
```

### Given-When-Then 结构

```dart
testWidgets('it_should_update_card_when_save_button_pressed', (tester) async {
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

## 测试类型

### 1. 规格测试 (Spec Tests)

**位置**: `test/specs/`

**目的**: 验证功能规格的完整实现

**特点**:
- 直接对应规格文档（如 `SP-UI-001`）
- 覆盖所有 Scenario
- 包含正常流程和边缘情况

**示例**:
```dart
// test/specs/home_screen_ui_spec_test.dart
group('SP-UI-005: Home Screen UI', () {
  group('UI Layout Tests', () {
    testWidgets('it_should_display_app_bar_with_title', ...);
    testWidgets('it_should_display_sync_status_indicator', ...);
  });

  group('Search Functionality Tests', () {
    testWidgets('it_should_filter_cards_by_title', ...);
    testWidgets('it_should_be_case_insensitive', ...);
  });
});
```

### 2. Widget 测试 (Widget Tests)

**位置**: `test/widgets/`

**目的**: 测试单个 Widget 的行为

**特点**:
- 隔离测试单个组件
- 使用 Mock 依赖
- 快速执行

**示例**:
```dart
// test/widgets/note_card_test.dart
testWidgets('it_should_display_card_information', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: NoteCard(
        card: testCard,
        currentDevice: 'test-device',
        onUpdate: (_) {},
        onDelete: (_) {},
      ),
    ),
  );

  expect(find.text(testCard.title), findsOneWidget);
  expect(find.text(testCard.content), findsOneWidget);
});
```

### 3. Screen 测试 (Screen Tests)

**位置**: `test/screens/`

**目的**: 测试完整屏幕的集成行为

**特点**:
- 测试多个 Widget 的交互
- 验证响应式布局
- 测试导航流程

**示例**:
```dart
// test/screens/home_screen_adaptive_test.dart
testWidgets('it_should_display_mobile_layout_on_small_screen', (tester) async {
  tester.binding.window.physicalSizeTestValue = const Size(400, 800);
  
  await tester.pumpWidget(createHomeScreen());
  
  expect(find.byType(MobileNav), findsOneWidget);
  expect(find.byType(ThreeColumnLayout), findsNothing);
});
```

### 4. 集成测试 (Integration Tests)

**位置**: `test/integration/`

**目的**: 测试完整的用户旅程

**特点**:
- 端到端测试
- 模拟真实用户操作
- 验证多个功能的协作

**示例**:
```dart
// test/integration/user_journey_test.dart
testWidgets('it_should_complete_card_creation_journey', (tester) async {
  // 1. 启动应用
  await tester.pumpWidget(const CardMindApp());
  
  // 2. 点击创建按钮
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  
  // 3. 输入内容
  await tester.enterText(find.byType(TextField).first, 'My Note');
  
  // 4. 保存
  await tester.tap(find.text('保存'));
  await tester.pumpAndSettle();
  
  // 5. 验证卡片显示
  expect(find.text('My Note'), findsOneWidget);
});
```

## 最佳实践

### 1. 使用 Mock 服务

```dart
// ✅ 好的做法：使用 Mock 避免依赖 Rust Bridge
final mockCardService = MockCardService();
final provider = CardProvider(cardService: mockCardService);

// ❌ 不好的做法：直接使用真实服务
final provider = CardProvider(); // 需要 Rust Bridge 初始化
```

### 2. 显式加载数据

```dart
// ✅ 好的做法：在测试中显式加载数据
Widget createHomeScreen() {
  final provider = CardProvider(cardService: mockCardService);
  provider.loadCards(); // 显式加载
  
  return ChangeNotifierProvider.value(
    value: provider,
    child: const HomeScreen(),
  );
}

// ❌ 不好的做法：期望自动加载
Widget createHomeScreen() {
  return ChangeNotifierProvider(
    create: (_) => CardProvider(cardService: mockCardService),
    child: const HomeScreen(),
  );
}
```

### 3. 精确定位 UI 元素

```dart
// ✅ 好的做法：使用 ancestor 精确定位
final closeButton = find.ancestor(
  of: find.byIcon(Icons.close),
  matching: find.byType(IconButton),
).first;
await tester.tap(closeButton);

// ❌ 不好的做法：模糊查找可能找到多个
await tester.tap(find.byIcon(Icons.close)); // 可能有多个 close 图标
```

### 4. 注入测试依赖

```dart
// ✅ 好的做法：支持测试注入
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.syncStatusStream, // 用于测试
  });

  final Stream<SyncStatus>? syncStatusStream;
}

// 测试中使用
HomeScreen(
  syncStatusStream: Stream.value(SyncStatus.disconnected()),
)
```

### 5. 使用合理的超时和等待

```dart
// ✅ 好的做法：使用 pump() 或 pumpAndSettle()
await tester.pump(); // 单次渲染
await tester.pumpAndSettle(); // 等待所有动画完成

// ⚠️ 注意：pumpAndSettle() 可能在无限动画时超时
// 对于有持续动画的 Widget，使用 pump() + Duration
await tester.pump(const Duration(milliseconds: 100));
```

### 6. 性能测试的宽松限制

```dart
// ✅ 好的做法：测试环境允许更宽松的时间限制
final stopwatch = Stopwatch()..start();
await tester.pumpWidget(widget);
await tester.pumpAndSettle();
stopwatch.stop();

// 测试环境性能与生产环境不同
expect(stopwatch.elapsedMilliseconds, lessThan(200)); // 而不是 16ms

// ❌ 不好的做法：使用生产环境的严格限制
expect(duration.inMilliseconds, lessThan(16)); // 在测试环境中不现实
```

## 常见问题

### Q1: 测试失败：flutter_rust_bridge has not been initialized

**原因**: 测试尝试调用 Rust 代码，但没有初始化 Rust Bridge

**解决方案**:
```dart
// 使用 Mock 服务替代真实服务
final mockCardService = MockCardService();
final provider = CardProvider(cardService: mockCardService);

// 或者注入 Mock Stream
HomeScreen(
  syncStatusStream: Stream.value(SyncStatus.disconnected()),
)
```

### Q2: 测试失败：Found multiple widgets with icon

**原因**: 多个 Widget 使用相同的图标

**解决方案**:
```dart
// 使用 ancestor 或 descendant 精确定位
final closeButton = find.ancestor(
  of: find.byIcon(Icons.close),
  matching: find.byType(IconButton),
).first;

// 或使用 widgetWithText
final chip = find.widgetWithText(Chip, 'tag1');
```

### Q3: 测试失败：pumpAndSettle timed out

**原因**: Widget 有无限动画或持续的 Stream

**解决方案**:
```dart
// 使用 pump() 替代 pumpAndSettle()
await tester.pump();

// 或使用有限次数的 pump
await tester.pump(const Duration(milliseconds: 100));
```

### Q4: 测试中卡片数据没有显示

**原因**: CardProvider 没有加载数据

**解决方案**:
```dart
Widget createHomeScreen() {
  final provider = CardProvider(cardService: mockCardService);
  provider.loadCards(); // 显式加载数据
  
  return ChangeNotifierProvider.value(
    value: provider,
    child: const HomeScreen(),
  );
}
```

### Q5: 性能测试总是失败

**原因**: 测试环境性能与生产环境不同

**解决方案**:
```dart
// 使用更宽松的时间限制
expect(duration.inMilliseconds, lessThan(200)); // 而不是 16ms

// 添加注释说明
// 注意：测试环境允许更宽松的时间限制
// 生产环境的实际性能会更好
```

## 相关文档

- [测试模板](TEST_TEMPLATE.md) - 测试代码模板
- [测试最佳实践](BEST_PRACTICES.md) - 详细的最佳实践指南
- [Mock API 使用指南](MOCK_API_GUIDE.md) - Mock 服务使用说明
- [测试-规格映射](TEST_SPEC_MAPPING.md) - 测试与规格的对应关系

## 参考资源

- [Flutter 测试文档](https://docs.flutter.dev/testing)
- [Spec Coding 方法论](../../openspec/specs/SPEC_CODING_GUIDE.md)
- [CardMind 规格中心](../../openspec/specs/README.md)

---

**最后更新**: 2026-01-19
