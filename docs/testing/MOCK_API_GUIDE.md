# Mock API 使用指南

本文档详细说明如何在 CardMind 项目中使用 Mock 服务进行测试。

## 目录

- [为什么使用 Mock](#为什么使用-mock)
- [MockCardService 使用指南](#mockcardservice-使用指南)
- [创建自定义 Mock](#创建自定义-mock)
- [Mock 配置技巧](#mock-配置技巧)
- [常见场景](#常见场景)
- [最佳实践](#最佳实践)

---

## 为什么使用 Mock

### 问题：真实服务的限制

在测试中使用真实服务会遇到以下问题：

```dart
// ❌ 使用真实服务的问题
testWidgets('it_should_create_card', (tester) async {
  final provider = CardProvider(); // 使用真实 CardService
  
  // 问题 1: 需要初始化 Rust Bridge
  await RustLib.init(); // 复杂的初始化
  
  // 问题 2: 需要真实的文件系统
  await provider.initialize('/path/to/data'); // 需要真实路径
  
  // 问题 3: 测试速度慢
  await provider.createCard('Test', 'Content'); // 真实的文件 I/O
  
  // 问题 4: 测试不稳定
  // 可能因为文件系统、权限等问题失败
  
  // 问题 5: 难以测试错误情况
  // 如何模拟网络错误、磁盘满等情况？
});
```

### 解决方案：使用 Mock

```dart
// ✅ 使用 Mock 的优势
testWidgets('it_should_create_card', (tester) async {
  final mockService = MockCardService();
  final provider = CardProvider(cardService: mockService);
  
  // 优势 1: 无需初始化 Rust Bridge
  // 优势 2: 无需真实文件系统
  // 优势 3: 测试速度快（内存操作）
  // 优势 4: 测试稳定可靠
  // 优势 5: 轻松测试各种情况
  
  await provider.createCard('Test', 'Content');
  
  expect(mockService.createCardCallCount, equals(1));
});
```

---

## MockCardService 使用指南

### 基本使用

```dart
import '../helpers/mock_card_service.dart';

void main() {
  group('CardProvider Tests', () {
    late MockCardService mockCardService;
    late CardProvider provider;

    setUp(() {
      mockCardService = MockCardService();
      provider = CardProvider(cardService: mockCardService);
    });

    tearDown(() {
      mockCardService.reset();
    });

    testWidgets('it_should_create_card', (tester) async {
      // 使用 Mock 创建卡片
      final card = await provider.createCard('Test', 'Content');
      
      expect(card.title, equals('Test'));
      expect(card.content, equals('Content'));
      expect(mockCardService.createCardCallCount, equals(1));
    });
  });
}
```

### 可用的 Mock 方法

MockCardService 实现了 CardService 的所有方法：

```dart
class MockCardService extends CardService {
  // 数据存储
  final List<Card> _cards = [];
  
  // 配置选项
  bool shouldThrowError = false;
  String? errorMessage;
  int delayMs = 0;
  
  // 调用计数
  int initializeCallCount = 0;
  int createCardCallCount = 0;
  int getAllCardsCallCount = 0;
  int getActiveCardsCallCount = 0;
  int getCardByIdCallCount = 0;
  int updateCardCallCount = 0;
  int deleteCardCallCount = 0;
  int getCardCountCallCount = 0;
  
  // 方法实现
  @override
  Future<void> initialize(String storagePath) async { ... }
  
  @override
  Future<Card> createCard(String title, String content) async { ... }
  
  @override
  Future<List<Card>> getAllCards() async { ... }
  
  @override
  Future<List<Card>> getActiveCards() async { ... }
  
  @override
  Future<Card> getCardById(String id) async { ... }
  
  @override
  Future<void> updateCard(String id, {String? title, String? content}) async { ... }
  
  @override
  Future<void> deleteCard(String id) async { ... }
  
  @override
  Future<(int, int, int)> getCardCount() async { ... }
  
  // 辅助方法
  void reset() { ... }
  void addCard(Card card) { ... }
  set cardCount(int count) { ... }
}
```

---

## Mock 配置技巧

### 1. 预填充数据

```dart
testWidgets('it_should_display_existing_cards', (tester) async {
  // 方法 1: 使用 createCard
  await mockCardService.createCard('Card 1', 'Content 1');
  await mockCardService.createCard('Card 2', 'Content 2');
  
  // 方法 2: 使用 addCard
  mockCardService.addCard(Card(
    id: 'test-id',
    title: 'Card 3',
    content: 'Content 3',
    createdAt: DateTime.now().millisecondsSinceEpoch,
    updatedAt: DateTime.now().millisecondsSinceEpoch,
    deleted: false,
    tags: [],
  ));
  
  // 方法 3: 批量设置（用于性能测试）
  mockCardService.cardCount = 1000; // 创建 1000 张卡片
  
  await tester.pumpWidget(createHomeScreen());
  await tester.pumpAndSettle();
  
  expect(find.text('Card 1'), findsOneWidget);
});
```

### 2. 模拟错误

```dart
testWidgets('it_should_handle_create_error', (tester) async {
  // 配置 Mock 抛出错误
  mockCardService.shouldThrowError = true;
  mockCardService.errorMessage = 'Network error';
  
  await tester.pumpWidget(createHomeScreen());
  
  // 触发创建操作
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  
  // 验证错误处理
  expect(find.text('Network error'), findsOneWidget);
  expect(find.byType(SnackBar), findsOneWidget);
});

testWidgets('it_should_handle_not_found_error', (tester) async {
  // 配置特定方法抛出错误
  mockCardService.shouldThrowError = true;
  mockCardService.errorMessage = 'Card not found: invalid-id';
  
  // 尝试获取不存在的卡片
  expect(
    () => mockCardService.getCardById('invalid-id'),
    throwsException,
  );
});
```

### 3. 模拟延迟

```dart
testWidgets('it_should_show_loading_indicator', (tester) async {
  // 配置延迟
  mockCardService.delayMs = 1000;
  
  await tester.pumpWidget(createHomeScreen());
  
  // 触发加载
  await tester.tap(find.text('刷新'));
  await tester.pump(); // 不等待完成
  
  // 验证加载指示器
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  
  // 等待完成
  await tester.pumpAndSettle();
  
  // 验证加载完成
  expect(find.byType(CircularProgressIndicator), findsNothing);
});
```

### 4. 验证调用次数

```dart
testWidgets('it_should_call_service_methods', (tester) async {
  await tester.pumpWidget(createHomeScreen());
  
  // 初始状态
  expect(mockCardService.getActiveCardsCallCount, equals(0));
  
  // 触发加载
  await provider.loadCards();
  
  // 验证调用次数
  expect(mockCardService.getActiveCardsCallCount, equals(1));
  
  // 再次加载
  await provider.loadCards();
  
  expect(mockCardService.getActiveCardsCallCount, equals(2));
});
```

### 5. 重置 Mock 状态

```dart
void main() {
  group('Tests', () {
    late MockCardService mockCardService;

    setUp(() {
      mockCardService = MockCardService();
    });

    tearDown(() {
      // 每个测试后重置
      mockCardService.reset();
    });

    testWidgets('test1', (tester) async {
      await mockCardService.createCard('Card 1', 'Content');
      expect(mockCardService.createCardCallCount, equals(1));
    });

    testWidgets('test2', (tester) async {
      // reset() 已在 tearDown 中调用
      // 计数器已重置为 0
      expect(mockCardService.createCardCallCount, equals(0));
    });
  });
}
```

---

## 创建自定义 Mock

### 基本模板

```dart
import 'package:cardmind/services/your_service.dart';
import 'package:cardmind/models/your_model.dart';

class MockYourService extends YourService {
  // 数据存储
  final List<YourModel> _data = [];
  
  // 配置选项
  bool shouldThrowError = false;
  String? errorMessage;
  int delayMs = 0;
  
  // 调用计数
  int methodCallCount = 0;

  // 重置方法
  void reset() {
    _data.clear();
    shouldThrowError = false;
    errorMessage = null;
    delayMs = 0;
    methodCallCount = 0;
  }

  // 实现服务方法
  @override
  Future<YourModel> yourMethod(String param) async {
    methodCallCount++;

    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    if (shouldThrowError) {
      throw Exception(errorMessage ?? 'Method failed');
    }

    final result = YourModel(
      id: 'mock-id-${_data.length}',
      name: param,
      // 其他字段
    );
    
    _data.add(result);
    return result;
  }

  @override
  Future<List<YourModel>> getData() async {
    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    if (shouldThrowError) {
      throw Exception(errorMessage ?? 'Get data failed');
    }

    return List.from(_data);
  }
}
```

### 高级功能

```dart
class AdvancedMockService extends YourService {
  // 记录所有调用
  final List<MethodCall> _callHistory = [];
  
  // 配置不同方法的行为
  final Map<String, MockBehavior> _behaviors = {};
  
  void configureBehavior(String method, MockBehavior behavior) {
    _behaviors[method] = behavior;
  }
  
  @override
  Future<YourModel> yourMethod(String param) async {
    // 记录调用
    _callHistory.add(MethodCall('yourMethod', [param]));
    
    // 获取配置的行为
    final behavior = _behaviors['yourMethod'];
    if (behavior != null) {
      if (behavior.shouldThrow) {
        throw Exception(behavior.errorMessage);
      }
      if (behavior.delayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: behavior.delayMs));
      }
      if (behavior.returnValue != null) {
        return behavior.returnValue as YourModel;
      }
    }
    
    // 默认行为
    return YourModel(/* ... */);
  }
  
  // 验证方法
  bool wasCalledWith(String method, List<dynamic> args) {
    return _callHistory.any((call) => 
      call.method == method && 
      _listsEqual(call.args, args)
    );
  }
  
  int getCallCount(String method) {
    return _callHistory.where((call) => call.method == method).length;
  }
}

class MethodCall {
  final String method;
  final List<dynamic> args;
  
  MethodCall(this.method, this.args);
}

class MockBehavior {
  final bool shouldThrow;
  final String? errorMessage;
  final int delayMs;
  final dynamic returnValue;
  
  MockBehavior({
    this.shouldThrow = false,
    this.errorMessage,
    this.delayMs = 0,
    this.returnValue,
  });
}
```

---

## 常见场景

### 场景 1: 测试空状态

```dart
testWidgets('it_should_display_empty_state', (tester) async {
  // Mock 返回空列表（默认行为）
  await tester.pumpWidget(createHomeScreen());
  await tester.pumpAndSettle();
  
  expect(find.text('还没有笔记'), findsOneWidget);
  expect(find.byType(EmptyStateWidget), findsOneWidget);
});
```

### 场景 2: 测试加载状态

```dart
testWidgets('it_should_show_loading_state', (tester) async {
  // 配置延迟以捕获加载状态
  mockCardService.delayMs = 1000;
  
  final provider = CardProvider(cardService: mockCardService);
  
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: const HomeScreen(),
    ),
  );
  
  // 触发加载
  provider.loadCards();
  await tester.pump();
  
  // 验证加载状态
  expect(provider.isLoading, isTrue);
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  
  // 等待完成
  await tester.pumpAndSettle();
  expect(provider.isLoading, isFalse);
});
```

### 场景 3: 测试错误处理

```dart
testWidgets('it_should_display_error_message', (tester) async {
  // 配置错误
  mockCardService.shouldThrowError = true;
  mockCardService.errorMessage = 'Failed to load cards';
  
  final provider = CardProvider(cardService: mockCardService);
  
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: const HomeScreen(),
    ),
  );
  
  // 触发加载
  await provider.loadCards();
  await tester.pumpAndSettle();
  
  // 验证错误显示
  expect(provider.hasError, isTrue);
  expect(provider.error, contains('Failed to load cards'));
  expect(find.text('Failed to load cards'), findsOneWidget);
});
```

### 场景 4: 测试 CRUD 操作

```dart
testWidgets('it_should_perform_crud_operations', (tester) async {
  // Create
  final card = await mockCardService.createCard('Test', 'Content');
  expect(card.title, equals('Test'));
  expect(mockCardService.createCardCallCount, equals(1));
  
  // Read
  final cards = await mockCardService.getActiveCards();
  expect(cards, hasLength(1));
  expect(mockCardService.getActiveCardsCallCount, equals(1));
  
  // Update
  await mockCardService.updateCard(card.id, title: 'Updated');
  final updated = await mockCardService.getCardById(card.id);
  expect(updated.title, equals('Updated'));
  expect(mockCardService.updateCardCallCount, equals(1));
  
  // Delete
  await mockCardService.deleteCard(card.id);
  final activeCards = await mockCardService.getActiveCards();
  expect(activeCards, isEmpty);
  expect(mockCardService.deleteCardCallCount, equals(1));
});
```

### 场景 5: 测试性能

```dart
testWidgets('it_should_handle_large_dataset', (tester) async {
  // 批量创建数据
  mockCardService.cardCount = 1000;
  
  final stopwatch = Stopwatch()..start();
  
  await tester.pumpWidget(createHomeScreen());
  await tester.pumpAndSettle();
  
  stopwatch.stop();
  
  // 验证性能
  expect(stopwatch.elapsedMilliseconds, lessThan(500));
  
  // 验证数据加载
  final cards = await mockCardService.getActiveCards();
  expect(cards, hasLength(1000));
});
```

---

## 最佳实践

### 1. 始终在 tearDown 中重置

```dart
setUp(() {
  mockCardService = MockCardService();
});

tearDown(() {
  mockCardService.reset(); // 重要！
});
```

### 2. 使用描述性的错误消息

```dart
// ✅ 好的做法
mockCardService.shouldThrowError = true;
mockCardService.errorMessage = 'Network timeout after 30 seconds';

// ❌ 不好的做法
mockCardService.shouldThrowError = true;
mockCardService.errorMessage = 'Error';
```

### 3. 验证调用次数

```dart
testWidgets('it_should_call_service_once', (tester) async {
  await provider.createCard('Test', 'Content');
  
  // 验证只调用一次
  expect(mockCardService.createCardCallCount, equals(1));
  
  // 验证没有调用其他方法
  expect(mockCardService.updateCardCallCount, equals(0));
  expect(mockCardService.deleteCardCallCount, equals(0));
});
```

### 4. 测试边界条件

```dart
testWidgets('it_should_handle_empty_title', (tester) async {
  final card = await mockCardService.createCard('', 'Content');
  expect(card.title, isEmpty);
});

testWidgets('it_should_handle_long_content', (tester) async {
  final longContent = 'A' * 10000;
  final card = await mockCardService.createCard('Test', longContent);
  expect(card.content, hasLength(10000));
});
```

### 5. 隔离测试

```dart
// ✅ 好的做法：每个测试独立
testWidgets('test1', (tester) async {
  final mockService = MockCardService();
  // 测试代码
});

testWidgets('test2', (tester) async {
  final mockService = MockCardService();
  // 测试代码
});

// ❌ 不好的做法：共享状态
final globalMockService = MockCardService();

testWidgets('test1', (tester) async {
  // 使用 globalMockService
});

testWidgets('test2', (tester) async {
  // 依赖 test1 的状态
});
```

---

## 故障排除

### 问题 1: Mock 数据没有显示

```dart
// 问题：创建了数据但 UI 没有显示
testWidgets('it_should_display_cards', (tester) async {
  await mockCardService.createCard('Test', 'Content');
  
  await tester.pumpWidget(createHomeScreen());
  await tester.pumpAndSettle();
  
  // 找不到卡片
  expect(find.text('Test'), findsNothing); // 失败
});

// 解决方案：显式加载数据
testWidgets('it_should_display_cards', (tester) async {
  await mockCardService.createCard('Test', 'Content');
  
  final provider = CardProvider(cardService: mockCardService);
  provider.loadCards(); // 显式加载
  
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: const HomeScreen(),
    ),
  );
  await tester.pumpAndSettle();
  
  expect(find.text('Test'), findsOneWidget); // 成功
});
```

### 问题 2: 测试之间相互影响

```dart
// 问题：第二个测试受第一个测试影响
testWidgets('test1', (tester) async {
  await mockCardService.createCard('Card 1', 'Content');
  expect(mockCardService.createCardCallCount, equals(1));
});

testWidgets('test2', (tester) async {
  // 期望 0，但实际是 1（如果没有 reset）
  expect(mockCardService.createCardCallCount, equals(0)); // 可能失败
});

// 解决方案：在 tearDown 中重置
tearDown(() {
  mockCardService.reset();
});
```

### 问题 3: 异步操作没有完成

```dart
// 问题：测试在异步操作完成前结束
testWidgets('it_should_load_data', (tester) async {
  mockCardService.delayMs = 500;
  
  await tester.pumpWidget(createHomeScreen());
  // 没有等待异步操作完成
  
  expect(find.text('Data'), findsNothing); // 数据还没加载
});

// 解决方案：等待异步操作完成
testWidgets('it_should_load_data', (tester) async {
  mockCardService.delayMs = 500;
  
  await tester.pumpWidget(createHomeScreen());
  await tester.pumpAndSettle(); // 等待所有异步操作完成
  
  expect(find.text('Data'), findsOneWidget); // 成功
});
```

---

## 相关文档

- [测试指南](TESTING_GUIDE.md) - 完整的测试编写指南
- [测试模板](TEST_TEMPLATE.md) - 测试代码模板
- [最佳实践](BEST_PRACTICES.md) - 测试最佳实践

---

**最后更新**: 2026-01-19
