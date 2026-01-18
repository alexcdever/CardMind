## Context

### Current State
- **19 个 Flutter/UI 规格文档**已完成，定义了完整的交互需求
- **仅 2 个规格测试文件**存在（`card_creation_spec_test.dart` 和 `sync_feedback_spec_test.dart`）
- **6 个组件级 widget 测试**存在，但覆盖不完整
- **手动测试依赖**：tasks.md 中有 7 个手动测试任务（13.2-13.9）
- **成功范例**：`card_creation_spec_test.dart` 展示了规格→测试的完美映射（30+ 测试用例）

### Constraints
- 必须使用 Flutter 内置的 `flutter_test` 框架（无需新增依赖）
- 测试必须遵循 Spec Coding 方法论（`it_should_xxx()` 命名，Given-When-Then 结构）
- 每个测试必须对应规格文档中的一个 Scenario
- 测试必须可以在 CI/CD 中自动运行
- 不能影响现有的测试和代码

### Stakeholders
- **开发团队**：需要自动化回归测试，减少手动测试成本
- **QA 团队**：需要可执行的测试规格，确保需求覆盖
- **维护者**：需要测试作为活文档，理解系统行为

## Goals / Non-Goals

**Goals:**
1. **100% 规格覆盖**：为所有 19 个 Flutter/UI 规格创建对应的测试文件
2. **自动化手动测试**：将 tasks.md 中的手动测试转化为自动化测试（80%+ 覆盖率）
3. **建立测试-规格映射**：在规格文档中添加测试覆盖清单，实现双向追溯
4. **CI/CD 集成**：在 GitHub Actions 中自动运行所有规格测试
5. **可维护性**：测试代码清晰、可读、易于扩展

**Non-Goals:**
- ❌ 不创建端到端（E2E）测试（仅限 widget 和集成测试）
- ❌ 不测试 Rust 后端逻辑（使用 Mock API）
- ❌ 不重构现有代码（仅添加测试）
- ❌ 不追求 100% 代码覆盖率（目标 80%+，重点是规格覆盖）
- ❌ 不测试第三方库的内部实现

## Decisions

### Decision 1: 测试文件组织结构

**选择**：三层测试结构（Specs → Widgets → Integration）

```
test/
├── specs/           # 规格级别测试（一对一映射规格文档）
├── widgets/         # 组件级别测试（独立组件的单元测试）
├── screens/         # 屏幕级别测试（完整屏幕的集成测试）
└── integration/     # 集成测试（跨屏幕的用户旅程）
```

**理由**：
- ✅ **清晰的职责分离**：每层测试有明确的目的和范围
- ✅ **规格追溯性**：`test/specs/` 直接对应 `openspec/specs/`
- ✅ **可维护性**：测试按功能模块组织，易于查找和修改
- ✅ **符合 Flutter 最佳实践**：遵循 Flutter 官方测试金字塔

**替代方案**：
- ❌ 平铺所有测试在 `test/` 根目录 → 难以管理和查找
- ❌ 按屏幕组织（`test/home/`, `test/editor/`）→ 规格追溯性差

### Decision 2: 测试命名规范

**选择**：使用 `it_should_xxx()` 命名风格

```dart
testWidgets('it_should_display_fab_button_on_home_screen', (tester) async {
  // Given: 用户在主页
  // When: 主页加载完成
  // Then: FAB 按钮显示在右下角
});
```

**理由**：
- ✅ **可读性强**：测试名称即文档，清晰表达预期行为
- ✅ **符合 Spec Coding**：与规格文档中的 Scenario 一致
- ✅ **易于搜索**：可以通过 `grep "it_should_"` 快速查找所有测试
- ✅ **已有先例**：`card_creation_spec_test.dart` 已使用此风格

**替代方案**：
- ❌ 传统风格（`test_fab_button_visible`）→ 可读性差
- ❌ BDD 风格（`should display FAB button`）→ 不符合 Dart 命名规范

### Decision 3: Mock 策略

**选择**：使用手写 Mock 类（如 `MockCardApi`），不引入 `mockito`

**理由**：
- ✅ **零依赖**：不增加项目复杂度
- ✅ **简单直接**：手写 Mock 更容易理解和调试
- ✅ **已有实现**：`MockCardApi` 已存在并运行良好
- ✅ **快速执行**：无需代码生成步骤

**实现模式**：
```dart
class MockCardApi implements CardApiInterface {
  int createCardCallCount = 0;
  Card? lastCreatedCard;
  bool shouldThrowError = false;

  @override
  Future<Card> createCard(String title, String content) async {
    createCardCallCount++;
    if (shouldThrowError) throw Exception('Mock error');
    lastCreatedCard = Card(id: 'mock-id', title: title, content: content);
    return lastCreatedCard!;
  }
}
```

**替代方案**：
- ❌ 使用 `mockito` → 需要代码生成，增加构建复杂度
- ❌ 使用真实 API → 测试速度慢，依赖外部状态

### Decision 4: 响应式布局测试策略

**选择**：使用 `tester.binding.window.physicalSizeTestValue` 模拟不同屏幕尺寸

```dart
testWidgets('it_should_switch_to_mobile_layout_below_1024px', (tester) async {
  // 设置窗口大小为 800x600（移动端）
  tester.binding.window.physicalSizeTestValue = Size(800, 600);
  tester.binding.window.devicePixelRatioTestValue = 1.0;

  await tester.pumpWidget(MyApp());

  // 验证移动端布局
  expect(find.byType(BottomNavigationBar), findsOneWidget);

  // 清理
  addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
});
```

**理由**：
- ✅ **精确控制**：可以测试任意屏幕尺寸和断点
- ✅ **无需真实设备**：在 CI/CD 中可靠运行
- ✅ **Flutter 官方推荐**：符合 Flutter 测试最佳实践

**替代方案**：
- ❌ 使用 `debugDefaultTargetPlatformOverride` → 只能切换平台，无法控制尺寸
- ❌ 手动测试 → 无法自动化，回归成本高

### Decision 5: 规格文档更新策略

**选择**：在每个规格文档末尾添加 "Test Implementation" 章节

```markdown
## Test Implementation

### Test File
`test/specs/card_creation_spec_test.dart`

### Test Coverage
- ✅ FAB Button Tests (3 tests)
- ✅ Input Field Tests (6 tests)
- ✅ Auto-save Tests (5 tests)
- ✅ Validation Tests (4 tests)
- ✅ Error Handling Tests (5 tests)
- ✅ Navigation Tests (6 tests)
- ✅ Performance Tests (1 test)

### Running Tests
```bash
flutter test test/specs/card_creation_spec_test.dart
```

### Coverage Report
Last updated: 2026-01-18
- Scenarios covered: 30/30 (100%)
- Test cases: 30
- All tests passing: ✅
```

**理由**：
- ✅ **双向追溯**：从规格可以找到测试，从测试可以找到规格
- ✅ **可见性**：开发者可以快速了解测试覆盖情况
- ✅ **活文档**：测试覆盖清单随规格一起维护
- ✅ **CI 友好**：可以自动生成和更新覆盖率报告

**替代方案**：
- ❌ 单独的测试覆盖文档 → 容易过时，维护成本高
- ❌ 仅在代码注释中说明 → 可见性差

### Decision 6: CI/CD 集成策略

**选择**：创建专门的 GitHub Actions workflow（`.github/workflows/flutter_tests.yml`）

```yaml
name: Flutter Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2

      # 运行所有规格测试
      - name: Run Spec Tests
        run: flutter test test/specs/

      # 运行所有 Widget 测试
      - name: Run Widget Tests
        run: flutter test test/widgets/

      # 运行所有 Screen 测试
      - name: Run Screen Tests
        run: flutter test test/screens/

      # 生成覆盖率报告
      - name: Generate Coverage
        run: flutter test --coverage

      # 上传覆盖率到 Codecov
      - name: Upload Coverage
        uses: codecov/codecov-action@v2
        with:
          files: ./coverage/lcov.info
```

**理由**：
- ✅ **自动验证**：每次 PR 自动运行所有测试
- ✅ **快速反馈**：开发者可以立即看到测试结果
- ✅ **覆盖率追踪**：自动生成和上传覆盖率报告
- ✅ **分层运行**：可以单独运行不同层级的测试

**替代方案**：
- ❌ 手动运行测试 → 容易遗漏，不可靠
- ❌ 在现有 workflow 中添加 → 可能影响其他任务

## Risks / Trade-offs

### Risk 1: 测试维护成本
**风险**：新增 150+ 测试用例，维护成本可能很高

**缓解措施**：
- ✅ 使用清晰的命名和结构，降低理解成本
- ✅ 提供测试模板和最佳实践文档
- ✅ 在 PR review 中强制要求更新对应的测试
- ✅ 使用 Mock API 隔离外部依赖，减少测试脆弱性

### Risk 2: Mock API 与真实 API 不一致
**风险**：Mock API 的行为可能与真实 Rust API 不一致，导致测试通过但实际有 bug

**缓解措施**：
- ✅ 定期运行集成测试（使用真实 API）验证 Mock 的正确性
- ✅ 在 Mock API 中添加详细注释，说明其行为与真实 API 的对应关系
- ✅ 当 Rust API 变更时，同步更新 Mock API
- ⚠️ **接受的权衡**：widget 测试主要验证 UI 逻辑，API 逻辑由 Rust 测试覆盖

### Risk 3: 响应式布局测试的局限性
**风险**：模拟屏幕尺寸可能无法完全复现真实设备的行为（如触摸手势、性能）

**缓解措施**：
- ✅ 使用 widget 测试覆盖布局逻辑
- ✅ 保留关键场景的手动测试（如真实设备上的性能测试）
- ✅ 在文档中明确说明哪些场景需要手动验证
- ⚠️ **接受的权衡**：80% 的场景可以自动化，20% 需要手动测试

### Risk 4: 测试执行时间
**风险**：150+ 测试用例可能导致 CI/CD 执行时间过长

**缓解措施**：
- ✅ 使用 `flutter test --concurrency=4` 并行运行测试
- ✅ 在 CI 中分层运行测试（先运行快速的单元测试，再运行慢速的集成测试）
- ✅ 使用 GitHub Actions 的缓存机制加速依赖安装
- ✅ 监控测试执行时间，优化慢速测试
- 🎯 **目标**：所有测试在 5 分钟内完成

### Risk 5: 规格文档与测试不同步
**风险**：规格文档更新后，测试可能没有及时更新，导致不一致

**缓解措施**：
- ✅ 在 PR 模板中添加检查清单："是否更新了对应的测试？"
- ✅ 在规格文档中添加 "Last updated" 时间戳，便于识别过时的测试
- ✅ 定期运行 `dart tool/validate_constraints.dart` 验证规格-测试一致性
- ✅ 在 CI 中添加检查：如果规格文档修改，必须同时修改测试文件

## Migration Plan

### Phase 1: 基础设施准备（1-2 天）
1. ✅ 创建测试目录结构（`test/specs/`, `test/integration/`）
2. ✅ 创建测试模板文件和最佳实践文档
3. ✅ 配置 CI/CD workflow（`.github/workflows/flutter_tests.yml`）
4. ✅ 创建 Mock API 基类和工具函数

### Phase 2: 核心规格测试（3-5 天）
**优先级 1**：Flutter UI 规格（5 个）
- `ui_interaction_spec_test.dart` (SP-FLUT-003)
- `onboarding_spec_test.dart` (SP-FLUT-007)
- `home_screen_spec_test.dart` (SP-FLUT-008)
- 扩展 `card_creation_spec_test.dart` (SP-FLUT-009)
- 扩展 `sync_feedback_spec_test.dart` (SP-FLUT-010)

### Phase 3: 平台自适应测试（2-3 天）
**优先级 2**：平台自适应规格（5 个）
- `platform_detection_spec_test.dart` (SP-ADAPT-001)
- `adaptive_ui_framework_spec_test.dart` (SP-ADAPT-002)
- `keyboard_shortcuts_spec_test.dart` (SP-ADAPT-003)
- `mobile_ui_patterns_spec_test.dart` (SP-ADAPT-004)
- `desktop_ui_patterns_spec_test.dart` (SP-ADAPT-005)

### Phase 4: UI 组件测试（3-4 天）
**优先级 3**：UI 组件规格（9 个）
- `adaptive_ui_system_spec_test.dart` (SP-UI-001)
- `card_editor_spec_test.dart` (SP-UI-002)
- `device_manager_ui_spec_test.dart` (SP-UI-003)
- `fullscreen_editor_spec_test.dart` (SP-UI-004)
- `home_screen_ui_spec_test.dart` (SP-UI-005)
- `mobile_navigation_spec_test.dart` (SP-UI-006)
- `note_card_component_spec_test.dart` (SP-UI-007)
- `sync_status_indicator_spec_test.dart` (SP-UI-008)
- `toast_notification_spec_test.dart` (SP-UI-009)

### Phase 5: 集成测试和文档（1-2 天）
1. ✅ 创建集成测试套件（`user_journey_test.dart`）
2. ✅ 更新所有规格文档，添加 "Test Implementation" 章节
3. ✅ 生成测试覆盖率报告
4. ✅ 编写测试维护指南

### Rollback Strategy
如果测试导致 CI/CD 失败或其他问题：
1. 可以通过 Git revert 回滚测试文件（不影响业务代码）
2. 可以在 CI workflow 中临时禁用特定测试层级
3. 测试是增量添加的，可以逐步回滚到任意阶段

## Open Questions

### Q1: 是否需要为所有 UI 组件规格创建独立的测试文件？
**当前方案**：是，每个规格一个测试文件（19 个文件）

**替代方案**：将相关规格的测试合并到一个文件中（如 `adaptive_ui_spec_test.dart` 包含 SP-ADAPT-001~005）

**决策依据**：
- ✅ 独立文件：更好的追溯性，更容易维护
- ❌ 合并文件：文件过大，难以导航

**结论**：保持一对一映射，便于追溯和维护

### Q2: 是否需要测试动画和过渡效果？
**当前方案**：仅测试动画的存在性，不测试具体的动画曲线和时长

**理由**：
- 动画的视觉效果难以用自动化测试验证
- 动画的具体参数（如时长、曲线）属于实现细节，不属于规格要求
- 可以通过 `tester.pumpAndSettle()` 验证动画完成后的状态

**示例**：
```dart
testWidgets('it_should_animate_fab_appearance', (tester) async {
  await tester.pumpWidget(MyApp());

  // 验证动画存在（不验证具体曲线）
  expect(find.byType(AnimatedOpacity), findsOneWidget);

  // 等待动画完成
  await tester.pumpAndSettle();

  // 验证最终状态
  expect(find.byType(FloatingActionButton), findsOneWidget);
});
```

### Q3: 如何处理依赖真实 API 的测试场景？
**当前方案**：
1. **Widget 测试**：使用 Mock API（快速、可靠）
2. **集成测试**：使用真实 API（慢速、完整验证）
3. **手动测试**：保留关键场景的手动测试（如设备配对、P2P 同步）

**分层策略**：
```
Widget Tests (Mock API)     → 快速反馈，每次 commit 运行
Integration Tests (Real API) → 完整验证，每次 PR 运行
Manual Tests                 → 关键场景，发布前运行
```

## Implementation Notes

### 测试模板
所有测试文件应遵循以下模板：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/...';

/// <规格名称> Specification Tests
///
/// 规格编号: SP-XXX-XXX
/// 这些测试验证 <功能描述> 的所有交互行为
///
/// 测试遵循 Spec Coding 方法论：
/// - 测试即规格，规格即文档
/// - 使用 it_should_xxx() 命名风格
/// - Given-When-Then 结构

void main() {
  group('SP-XXX-XXX: <规格名称>', () {
    // Setup
    late MockApi mockApi;

    setUp(() {
      mockApi = MockApi();
    });

    // Test groups
    group('<Scenario Group 1>', () {
      testWidgets('it_should_xxx', (WidgetTester tester) async {
        // Given: 前置条件

        // When: 执行操作

        // Then: 验证结果
        expect(...);
      });
    });
  });
}
```

### 关键工具函数
创建 `test/helpers/test_helpers.dart`：

```dart
/// 创建带 Provider 的测试 Widget
Widget createTestWidget(Widget child, {List<ChangeNotifierProvider>? providers}) {
  return MaterialApp(
    home: MultiProvider(
      providers: providers ?? [],
      child: child,
    ),
  );
}

/// 模拟屏幕尺寸
void setScreenSize(WidgetTester tester, Size size) {
  tester.binding.window.physicalSizeTestValue = size;
  tester.binding.window.devicePixelRatioTestValue = 1.0;
  addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
}

/// 等待异步操作完成
Future<void> waitForAsync(WidgetTester tester) async {
  await tester.pump(Duration.zero);
  await tester.pumpAndSettle();
}
```

### 预期工作量
- **总测试文件**：17 个新增 + 2 个扩展 = 19 个
- **预计测试用例**：150-200 个
- **预计开发时间**：10-15 天（1-2 人）
- **预计维护成本**：每个规格变更需要同步更新测试（约 1-2 小时/规格）
