<!-- input: 项目需要统一的测试分类和命名规范
     output: 定义测试目录结构、文件命名、函数命名和边界测试要求的规范文档
     pos: docs/standards/testing.md - 测试规范文档，修改本文件需同步更新文件头和所属 DIR.md
     中文注释: 测试规范文档，定义测试分类体系和命名约定 -->

# 测试规范

本规范定义 CardMind 项目的测试分类体系和命名约定。

## 1. 测试分类体系

### 1.1 Flutter 测试 (`test/`)

```
test/
├── unit/              # 单元测试：纯 Dart 逻辑，无 UI
│   ├── domain/        # 领域模型测试
│   ├── data/          # 数据层测试
│   └── application/   # 应用服务测试
├── widget/            # 组件测试：单个 Widget
│   ├── pages/         # 页面级组件
│   └── components/    # 可复用组件
├── integration/       # 集成测试：多组件协作
│   ├── features/      # 功能流测试
│   └── infrastructure/# 基础设施测试
├── contract/          # 契约测试：API 契约
│   └── api/           # API 契约测试
├── e2e/              # 端到端测试：完整用户流程
└── architecture/      # 架构守护测试
```

### 1.2 Rust 测试 (`rust/tests/`)

```
rust/tests/
├── unit/              # 单元测试：纯函数和结构体
├── integration/       # 集成测试：模块间协作
├── contract/          # 契约测试：FFI 接口契约
└── performance/       # 性能测试：基准测试
```

## 2. 文件命名规范

### 2.1 Dart 测试文件

**格式**: `{被测对象}_{测试类型}_test.dart`

**示例**:
- `cards_controller_test.dart` - 控制器单元测试
- `cards_page_test.dart` - 页面组件测试
- `cards_pool_filter_test.dart` - 集成测试
- `cards_api_contract_test.dart` - 契约测试
- `cards_repository_benchmark_test.dart` - 性能测试

### 2.2 Rust 测试文件

**格式**: `{被测对象}_{测试类型}_test.rs`

**示例**:
- `card_model_test.rs` - 模型单元测试
- `pool_network_flow_test.rs` - 流程集成测试
- `sync_api_contract_test.rs` - API 契约测试
- `card_store_benchmark_test.rs` - 性能测试

## 3. 测试函数命名

### 3.1 Dart

**格式**: `test_{被测行为}_{预期结果}`

```dart
// 好示例
test('search_withEmptyQuery_returnsAllCards', () { ... });
test('save_whenNetworkError_showsErrorMessage', () { ... });
test('delete_givenDeletedCard_restoresCard', () { ... });

// 坏示例（不清晰）
test('search works', () { ... });
test('test 1', () { ... });
```

### 3.2 Rust

**格式**: `{被测行为}_{预期结果}`

```rust
#[test]
fn search_with_empty_query_returns_all_cards() { ... }

#[test]
fn save_when_network_error_shows_error_message() { ... }

#[test]
fn delete_given_deleted_card_restores_card() { ... }
```

## 4. 测试边界要求

每个功能必须测试以下边界条件：

### 4.1 必测边界（高优先级）

- [ ] **空值/空输入边界** - 空字符串、null、空列表
- [ ] **异常/错误边界** - 网络错误、超时、权限拒绝
- [ ] **输入边界** - 输入框焦点、键盘事件、表单验证
- [ ] **条件分支边界** - if/else、switch 的所有分支

### 4.2 建议测试边界（中优先级）

- [ ] **异步状态边界** - loading、error、success 状态
- [ ] **集合边界** - 空列表、单元素、大数据量
- [ ] **状态转换边界** - 初始化、销毁、页面生命周期
- [ ] **UI 响应式边界** - 布局断点、主题切换

### 4.3 可选边界（低优先级）

- [ ] **性能边界** - 防抖、节流、大数据量性能
- [ ] **并发边界** - 同时多个操作、竞态条件
- [ ] **资源边界** - 内存、存储、文件句柄

## 5. 测试覆盖率要求

### 5.1 最小覆盖率

- **单元测试**: 80%
- **组件测试**: 70%
- **集成测试**: 60%
- **边界条件**: 100%（高优先级边界必须全部覆盖）

### 5.2 覆盖率检查

运行质量检查时自动计算：

```bash
dart run tool/quality.dart flutter
```

## 6. 与边界扫描器的关联

测试规范中定义的测试分类，将作为边界扫描器识别"测试覆盖"的依据：

1. 扫描器识别到代码中的边界条件（如 `if (query.isEmpty)`）
2. 扫描器查找匹配测试：`test/*search*test.dart` 或 `test/*query*test.dart`
3. 扫描器检查测试函数名是否包含 `empty`、`null`、`error` 等关键词
4. 生成边界覆盖报告

## 7. 测试文件模板

### 7.1 Dart 单元测试模板

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/features/cards/cards_controller.dart';

void main() {
  group('CardsController', () {
    late CardsController controller;
    
    setUp(() {
      controller = CardsController();
    });
    
    tearDown(() {
      controller.dispose();
    });
    
    test('search_withEmptyQuery_returnsAllCards', () async {
      // Arrange
      await controller.load();
      final allCards = controller.items;
      
      // Act
      await controller.load(query: '');
      
      // Assert
      expect(controller.items.length, equals(allCards.length));
    });
    
    test('search_withNullQuery_throwsArgumentError', () async {
      // Arrange & Act & Assert
      expect(
        () => controller.load(query: null),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
```

### 7.2 Dart Widget 测试模板

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/features/cards/cards_page.dart';

void main() {
  testWidgets('searchField_withFocus_doesNotTriggerTabSwitch', (tester) async {
    // Arrange
    await tester.pumpWidget(MaterialApp(home: CardsPage()));
    final searchField = find.byType(TextField);
    
    // Act
    await tester.tap(searchField);
    await tester.enterText(searchField, '2');
    await tester.pump();
    
    // Assert
    expect(find.text('数据池'), findsNothing); // 未跳转到数据池 tab
  });
}
```

## 8. 最佳实践

### 8.1 测试独立性

- 每个测试应该独立运行，不依赖其他测试
- 使用 `setUp` 和 `tearDown` 管理测试状态
- 避免共享可变状态

### 8.2 测试可读性

- 测试名清晰描述行为和预期结果
- 使用 Arrange-Act-Assert 结构
- 避免复杂的嵌套和逻辑

### 8.3 测试可维护性

- 使用语义化的常量，避免魔法值
- 提取公共的测试辅助函数
- 及时更新测试以匹配代码变更

## 9. 相关文档

- `docs/standards/tdd.md` - TDD 开发规范
- `docs/standards/test-boundary-checklist.md` - 边界检查清单
- `AGENTS.md` - AI 开发流程（包含测试边界检查）
