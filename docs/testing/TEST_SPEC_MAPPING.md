# 测试-规格映射指南

本文档说明 CardMind 项目中测试文件与规格文档的映射关系，确保每个功能规格都有对应的测试覆盖。

## 目录

- [映射原则](#映射原则)
- [规格-测试映射表](#规格-测试映射表)
- [如何添加新测试](#如何添加新测试)
- [验证映射完整性](#验证映射完整性)
- [常见问题](#常见问题)

---

## 映射原则

### 1. 一对一映射

每个规格文档应该有对应的测试文件：

```
openspec/specs/[feature]/spec.md  →  test/specs/[feature]_spec_test.dart
```

### 2. 命名规范

**规格文件命名**:
```
openspec/specs/
├── adaptive-ui-framework/spec.md      (SP-UI-001)
├── desktop-ui-patterns/spec.md        (SP-UI-002)
└── mobile-ui-patterns/spec.md         (SP-UI-003)
```

**测试文件命名**:
```
test/specs/
├── adaptive_ui_framework_spec_test.dart
├── desktop_ui_patterns_spec_test.dart
└── mobile_ui_patterns_spec_test.dart
```

### 3. 规格编号标注

每个测试文件必须在文档注释中标注对应的规格编号：

```dart
/// [Feature Name] Specification Tests
///
/// 规格编号: SP-XXX-XXX
/// 规格文档: openspec/specs/[feature]/spec.md
///
/// 这些测试验证 [功能描述] 的所有交互行为
```

---

## 规格-测试映射表

### Flutter UI 规格

| 规格编号 | 规格文档 | 测试文件 | 状态 |
|---------|---------|---------|------|
| SP-UI-001 | `adaptive-ui-framework/spec.md` | `adaptive_ui_framework_spec_test.dart` | ✅ |
| SP-UI-002 | `desktop-ui-patterns/spec.md` | `desktop_ui_patterns_spec_test.dart` | ✅ |
| SP-UI-003 | `mobile-ui-patterns/spec.md` | `mobile_ui_patterns_spec_test.dart` | ✅ |
| SP-UI-004 | `fullscreen-editor/spec.md` | `fullscreen_editor_spec_test.dart` | ✅ |
| SP-UI-005 | `home-screen/spec.md` | `home_screen_ui_spec_test.dart` | ✅ |
| SP-UI-006 | `note-card-component/spec.md` | `note_card_component_spec_test.dart` | ✅ |
| SP-UI-007 | `device-manager-ui/spec.md` | `device_manager_ui_spec_test.dart` | ✅ |
| SP-UI-008 | `sync-status-indicator/spec.md` | `sync_status_indicator_component_spec_test.dart` | ✅ |

### 响应式布局规格

| 规格编号 | 规格文档 | 测试文件 | 状态 |
|---------|---------|---------|------|
| SP-LAYOUT-001 | `responsive-layout/spec.md` | `responsive_layout_spec_test.dart` | ✅ |
| SP-LAYOUT-002 | `adaptive-ui-system/spec.md` | `adaptive_ui_system_spec_test.dart` | ✅ |

### 平台自适应规格

| 规格编号 | 规格文档 | 测试文件 | 状态 |
|---------|---------|---------|------|
| SP-PLATFORM-001 | `platform-detection/spec.md` | `platform_detection_spec_test.dart` | ✅ |
| SP-PLATFORM-002 | `keyboard-shortcuts/spec.md` | `keyboard_shortcuts_spec_test.dart` | ✅ |

### Flutter 交互规格

| 规格编号 | 规格文档 | 测试文件 | 状态 |
|---------|---------|---------|------|
| SP-FLUT-003 | `flutter/ui_interaction_spec.md` | `ui_interaction_spec_test.dart` | ✅ |
| SP-FLUT-007 | `flutter/onboarding_spec.md` | `onboarding_spec_test.dart` | ✅ |
| SP-FLUT-008 | `flutter/home_screen_spec.md` | `home_screen_spec_test.dart` | ✅ |
| SP-FLUT-009 | `flutter/card_creation_spec.md` | `card_creation_spec_test.dart` | ✅ |
| SP-FLUT-010 | `flutter/sync_feedback_spec.md` | `sync_feedback_spec_test.dart` | ✅ |

### 其他规格

| 规格编号 | 规格文档 | 测试文件 | 状态 |
|---------|---------|---------|------|
| SP-NAV-001 | `mobile-navigation/spec.md` | `mobile_navigation_spec_test.dart` | ✅ |
| SP-TOAST-001 | `toast-notification/spec.md` | `toast_notification_spec_test.dart` | ✅ |
| SP-EDITOR-001 | `card-editor/spec.md` | `card_editor_spec_test.dart` | ✅ |

### 总计

- **总规格数**: 19
- **已覆盖**: 19
- **覆盖率**: 100%

---

## 如何添加新测试

### 步骤 1: 创建规格文档

```bash
# 在 openspec/specs/ 下创建新规格
mkdir -p openspec/specs/new-feature
touch openspec/specs/new-feature/spec.md
```

规格文档模板：
```markdown
# [Feature Name] Specification

**规格编号**: SP-XXX-XXX  
**状态**: Draft | Review | Approved  
**创建日期**: YYYY-MM-DD  
**最后更新**: YYYY-MM-DD

## 概述

[功能描述]

## 场景 (Scenarios)

### Scenario 1: [场景名称]

**Given**: [前置条件]  
**When**: [操作]  
**Then**: [预期结果]

## 验收标准

- [ ] 标准 1
- [ ] 标准 2

## Test Implementation

测试文件: `test/specs/new_feature_spec_test.dart`

- [x] Scenario 1 测试
- [x] Scenario 2 测试
```

### 步骤 2: 创建测试文件

```bash
# 创建对应的测试文件
touch test/specs/new_feature_spec_test.dart
```

测试文件模板：
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [Feature Name] Specification Tests
///
/// 规格编号: SP-XXX-XXX
/// 规格文档: openspec/specs/new-feature/spec.md
///
/// 这些测试验证 [功能描述] 的所有交互行为
///
/// 测试遵循 Spec Coding 方法论：
/// - 测试即规格，规格即文档
/// - 使用 it_should_xxx() 命名风格
/// - Given-When-Then 结构

void main() {
  group('SP-XXX-XXX: [Feature Name]', () {
    // 测试用例
  });
}
```

### 步骤 3: 更新映射表

在本文档的映射表中添加新条目：

```markdown
| SP-XXX-XXX | `new-feature/spec.md` | `new_feature_spec_test.dart` | ✅ |
```

### 步骤 4: 更新规格索引

在 `openspec/specs/README.md` 中添加新规格：

```markdown
## Flutter UI 规格

- [SP-XXX-XXX: Feature Name](new-feature/spec.md) - 功能描述
```

---

## 验证映射完整性

### 手动验证

```bash
# 列出所有规格文件
find openspec/specs -name "spec.md" | sort

# 列出所有测试文件
find test/specs -name "*_spec_test.dart" | sort

# 比对数量
```

### 自动验证脚本

创建 `tool/validate_test_spec_mapping.dart`:

```dart
import 'dart:io';

void main() {
  print('Validating test-spec mapping...\n');
  
  // 查找所有规格文件
  final specDir = Directory('openspec/specs');
  final specFiles = specDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('spec.md'))
      .toList();
  
  print('Found ${specFiles.length} spec files');
  
  // 查找所有测试文件
  final testDir = Directory('test/specs');
  final testFiles = testDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('_spec_test.dart'))
      .toList();
  
  print('Found ${testFiles.length} spec test files');
  
  // 验证映射
  var missingTests = 0;
  for (var specFile in specFiles) {
    final specName = specFile.path.split('/').reversed.skip(1).first;
    final expectedTestName = '${specName}_spec_test.dart';
    
    final hasTest = testFiles.any((f) => f.path.contains(expectedTestName));
    
    if (!hasTest) {
      print('❌ Missing test for: $specName');
      missingTests++;
    }
  }
  
  if (missingTests == 0) {
    print('\n✅ All specs have corresponding tests!');
    exit(0);
  } else {
    print('\n❌ Found $missingTests specs without tests');
    exit(1);
  }
}
```

运行验证：
```bash
dart tool/validate_test_spec_mapping.dart
```

### CI/CD 集成

在 `.github/workflows/flutter_tests.yml` 中已经集成了验证：

```yaml
spec-validation:
  name: Validate Test-Spec Mapping
  runs-on: ubuntu-latest
  steps:
    - name: Validate test-spec mapping
      run: dart tool/validate_test_spec_mapping.dart
```

---

## 测试覆盖率要求

### 规格覆盖率

每个规格文档中的所有 Scenario 都必须有对应的测试：

```dart
group('SP-XXX-XXX: Feature Name', () {
  group('Scenario 1: User Action', () {
    testWidgets('it_should_do_something', ...);
    testWidgets('it_should_handle_error', ...);
  });
  
  group('Scenario 2: Edge Case', () {
    testWidgets('it_should_handle_edge_case', ...);
  });
});
```

### 代码覆盖率

- **目标**: >80%
- **检查**: `flutter test --coverage`
- **报告**: 上传到 Codecov

---

## 维护指南

### 规格变更时

1. **更新规格文档**
   ```bash
   # 编辑规格文档
   vim openspec/specs/feature/spec.md
   ```

2. **更新对应测试**
   ```bash
   # 编辑测试文件
   vim test/specs/feature_spec_test.dart
   ```

3. **运行测试验证**
   ```bash
   flutter test test/specs/feature_spec_test.dart
   ```

4. **提交时包含两者**
   ```bash
   git add openspec/specs/feature/spec.md
   git add test/specs/feature_spec_test.dart
   git commit -m "feat: update feature spec and tests"
   ```

### PR 检查

GitHub Actions 会自动检查：
- 如果 PR 修改了规格文件
- 是否同时修改了对应的测试文件
- 如果没有，CI 会失败并提示

---

## 常见问题

### Q1: 一个规格对应多个测试文件？

**A**: 可以。复杂的规格可以拆分为多个测试文件：

```
openspec/specs/complex-feature/spec.md
  ↓
test/specs/complex_feature_spec_test.dart       (主测试)
test/widgets/complex_feature_widget_test.dart   (Widget 测试)
test/screens/complex_feature_screen_test.dart   (Screen 测试)
```

在规格文档中标注所有相关测试文件。

### Q2: 多个规格共享一个测试文件？

**A**: 不推荐。每个规格应该有独立的测试文件，便于维护和追踪。

如果确实需要共享，在测试文件中明确标注：

```dart
/// Shared Tests for Multiple Specs
///
/// 规格编号: SP-XXX-001, SP-XXX-002
/// 规格文档: 
/// - openspec/specs/feature-1/spec.md
/// - openspec/specs/feature-2/spec.md
```

### Q3: 如何处理已废弃的规格？

**A**: 
1. 在规格文档中标记为 `Deprecated`
2. 保留测试文件但添加注释说明
3. 在映射表中标记状态为 `⚠️ Deprecated`

```dart
/// [Feature Name] Specification Tests
///
/// ⚠️ DEPRECATED: This spec is deprecated as of YYYY-MM-DD
/// Reason: [说明原因]
/// Replacement: SP-XXX-XXX
```

### Q4: 测试文件找不到对应规格？

**A**: 检查以下情况：
1. 规格文档是否在 `openspec/specs/` 目录下
2. 文件名是否为 `spec.md`
3. 是否在规格索引 `openspec/specs/README.md` 中注册

### Q5: 如何验证测试覆盖了规格的所有场景？

**A**: 
1. 在规格文档中列出所有 Scenario
2. 在测试文件中为每个 Scenario 创建对应的 group
3. 在规格文档的 "Test Implementation" 章节中勾选已实现的测试

---

## 相关文档

- [测试指南](TESTING_GUIDE.md) - 完整的测试编写指南
- [测试模板](TEST_TEMPLATE.md) - 测试代码模板
- [最佳实践](BEST_PRACTICES.md) - 测试最佳实践
- [Spec Coding 指南](../../openspec/specs/SPEC_CODING_GUIDE.md) - Spec Coding 方法论

---

**最后更新**: 2026-01-19
