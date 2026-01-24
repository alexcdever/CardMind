# Flutter Spec-Test 映射表
# Flutter Spec-Test Mapping

**最后更新 Last Updated**: 2026-01-24
**维护者 Maintainer**: CardMind Team

---

## 📖 概述
## Overview

本文档记录 Flutter UI 规格文档与测试文件的映射关系，用于追踪规格实现状态和测试覆盖率。
This document tracks the mapping between Flutter UI specifications and test files, used to monitor implementation status and test coverage.

**映射原则 Mapping Principles**:
- 每个规格文档应该有对应的测试文件
- 测试文件名应该反映规格文档的内容
- 使用 `*_spec_test.dart` 命名规格测试，`*_test.dart` 命名单元测试

---

## 📊 映射统计
## Mapping Statistics

| 类别 Category | 规格数量 Specs | 测试数量 Tests | 覆盖率 Coverage |
|---------------|---------------|---------------|----------------|
| **UI Screens** | 8 | 3 | 38% |
| **UI Components** | 16 | 6 | 38% |
| **UI Adaptive** | 3 | 8 | 267% ⚠️ |
| **Features** | 33 | 11 | 33% |
| **总计 Total** | 60 | 28 | 47% |

⚠️ **注意**: Adaptive 测试数量超过规格数量，说明测试粒度更细或有额外的集成测试。

---

## 🎨 UI Screens 映射
## UI Screens Mapping

### Mobile Screens

| 规格文档 Spec | 测试文件 Test | 状态 Status | 备注 Notes |
|--------------|--------------|-------------|-----------|
| [ui/screens/mobile/home_screen.md](../../openspec/specs/ui/screens/mobile/home_screen.md) | `test/specs/home_screen_spec_test.dart` | ✅ 已映射 | - |
| [ui/screens/mobile/home_screen.md](../../openspec/specs/ui/screens/mobile/home_screen.md) | `test/specs/home_screen_ui_spec_test.dart` | ✅ 已映射 | UI 层测试 |
| [ui/screens/mobile/home_screen.md](../../openspec/specs/ui/screens/mobile/home_screen.md) | `test/screens/home_screen_adaptive_test.dart` | ✅ 已映射 | 自适应测试 |
| [ui/screens/mobile/home_screen.md](../../openspec/specs/ui/screens/mobile/home_screen.md) | `test/integration/home_screen_flow_test.dart` | ✅ 已映射 | 集成测试 |
| [ui/screens/mobile/home_screen.md](../../openspec/specs/ui/screens/mobile/home_screen.md) | `test/integration/home_screen_search_test.dart` | ✅ 已映射 | 搜索功能测试 |
| [ui/screens/mobile/card_editor_screen.md](../../openspec/specs/ui/screens/mobile/card_editor_screen.md) | `test/specs/card_editor_spec_test.dart` | ✅ 已映射 | - |
| [ui/screens/mobile/card_detail_screen.md](../../openspec/specs/ui/screens/mobile/card_detail_screen.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |
| [ui/screens/mobile/settings_screen.md](../../openspec/specs/ui/screens/mobile/settings_screen.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |
| [ui/screens/mobile/sync_screen.md](../../openspec/specs/ui/screens/mobile/sync_screen.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |

### Desktop Screens

| 规格文档 Spec | 测试文件 Test | 状态 Status | 备注 Notes |
|--------------|--------------|-------------|-----------|
| [ui/screens/desktop/home_screen.md](../../openspec/specs/ui/screens/desktop/home_screen.md) | ⚠️ 共享测试 | 🔄 部分覆盖 | 使用 mobile 测试 |
| [ui/screens/desktop/card_editor_screen.md](../../openspec/specs/ui/screens/desktop/card_editor_screen.md) | ⚠️ 共享测试 | 🔄 部分覆盖 | 使用 mobile 测试 |
| [ui/screens/desktop/settings_screen.md](../../openspec/specs/ui/screens/desktop/settings_screen.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |

### Shared Screens

| 规格文档 Spec | 测试文件 Test | 状态 Status | 备注 Notes |
|--------------|--------------|-------------|-----------|
| [ui/screens/shared/onboarding_screen.md](../../openspec/specs/ui/screens/shared/onboarding_screen.md) | `test/specs/onboarding_spec_test.dart` | ✅ 已映射 | - |

---

## 🧩 UI Components 映射
## UI Components Mapping

### Mobile Components

| 规格文档 Spec | 测试文件 Test | 状态 Status | 备注 Notes |
|--------------|--------------|-------------|-----------|
| [ui/components/mobile/mobile_nav.md](../../openspec/specs/ui/components/mobile/mobile_nav.md) | `test/widgets/mobile_nav_test.dart` | ✅ 已映射 | - |
| [ui/components/mobile/mobile_nav.md](../../openspec/specs/ui/components/mobile/mobile_nav.md) | `test/specs/mobile_navigation_spec_test.dart` | ✅ 已映射 | Spec 测试 |
| [ui/components/mobile/card_list_item.md](../../openspec/specs/ui/components/mobile/card_list_item.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |
| [ui/components/mobile/fab.md](../../openspec/specs/ui/components/mobile/fab.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |
| [ui/components/mobile/gestures.md](../../openspec/specs/ui/components/mobile/gestures.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |

### Desktop Components

| 规格文档 Spec | 测试文件 Test | 状态 Status | 备注 Notes |
|--------------|--------------|-------------|-----------|
| [ui/components/desktop/desktop_nav.md](../../openspec/specs/ui/components/desktop/desktop_nav.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |
| [ui/components/desktop/toolbar.md](../../openspec/specs/ui/components/desktop/toolbar.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |
| [ui/components/desktop/context_menu.md](../../openspec/specs/ui/components/desktop/context_menu.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |
| [ui/components/desktop/card_list_item.md](../../openspec/specs/ui/components/desktop/card_list_item.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |

### Shared Components

| 规格文档 Spec | 测试文件 Test | 状态 Status | 备注 Notes |
|--------------|--------------|-------------|-----------|
| [ui/components/shared/note_card.md](../../openspec/specs/ui/components/shared/note_card.md) | `test/widgets/note_card_test.dart` | ✅ 已映射 | - |
| [ui/components/shared/note_card.md](../../openspec/specs/ui/components/shared/note_card.md) | `test/specs/note_card_component_spec_test.dart` | ✅ 已映射 | Spec 测试 |
| [ui/components/shared/fullscreen_editor.md](../../openspec/specs/ui/components/shared/fullscreen_editor.md) | `test/widgets/fullscreen_editor_test.dart` | ✅ 已映射 | - |
| [ui/components/shared/fullscreen_editor.md](../../openspec/specs/ui/components/shared/fullscreen_editor.md) | `test/specs/fullscreen_editor_spec_test.dart` | ✅ 已映射 | Spec 测试 |
| [ui/components/shared/sync_status_indicator.md](../../openspec/specs/ui/components/shared/sync_status_indicator.md) | `test/widgets/sync_status_indicator_test.dart` | ✅ 已映射 | - |
| [ui/components/shared/sync_status_indicator.md](../../openspec/specs/ui/components/shared/sync_status_indicator.md) | `test/specs/sync_status_indicator_component_spec_test.dart` | ✅ 已映射 | Spec 测试 |
| [ui/components/shared/device_manager_panel.md](../../openspec/specs/ui/components/shared/device_manager_panel.md) | `test/widgets/device_manager_panel_test.dart` | ✅ 已映射 | - |
| [ui/components/shared/device_manager_panel.md](../../openspec/specs/ui/components/shared/device_manager_panel.md) | `test/specs/device_manager_ui_spec_test.dart` | ✅ 已映射 | Spec 测试 |
| [ui/components/shared/device_manager_panel.md](../../openspec/specs/ui/components/shared/device_manager_panel.md) | `test/integration/device_manager_test.dart` | ✅ 已映射 | 集成测试 |
| [ui/components/shared/settings_panel.md](../../openspec/specs/ui/components/shared/settings_panel.md) | `test/widgets/settings_panel_test.dart` | ✅ 已映射 | - |
| [ui/components/shared/sync_details_dialog.md](../../openspec/specs/ui/components/shared/sync_details_dialog.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |

---

## 🎯 UI Adaptive 映射
## UI Adaptive Mapping

| 规格文档 Spec | 测试文件 Test | 状态 Status | 备注 Notes |
|--------------|--------------|-------------|-----------|
| [ui/adaptive/layouts.md](../../openspec/specs/ui/adaptive/layouts.md) | `test/adaptive/layouts/adaptive_scaffold_test.dart` | ✅ 已映射 | - |
| [ui/adaptive/layouts.md](../../openspec/specs/ui/adaptive/layouts.md) | `test/adaptive/responsive_layout_test.dart` | ✅ 已映射 | - |
| [ui/adaptive/layouts.md](../../openspec/specs/ui/adaptive/layouts.md) | `test/adaptive/responsive_utils_test.dart` | ✅ 已映射 | - |
| [ui/adaptive/layouts.md](../../openspec/specs/ui/adaptive/layouts.md) | `test/specs/responsive_layout_spec_test.dart` | ✅ 已映射 | Spec 测试 |
| [ui/adaptive/components.md](../../openspec/specs/ui/adaptive/components.md) | `test/adaptive/adaptive_widget_test.dart` | ✅ 已映射 | - |
| [ui/adaptive/components.md](../../openspec/specs/ui/adaptive/components.md) | `test/adaptive/adaptive_typography_test.dart` | ✅ 已映射 | - |
| [ui/adaptive/components.md](../../openspec/specs/ui/adaptive/components.md) | `test/specs/adaptive_ui_framework_spec_test.dart` | ✅ 已映射 | Spec 测试 |
| [ui/adaptive/components.md](../../openspec/specs/ui/adaptive/components.md) | `test/specs/adaptive_ui_system_spec_test.dart` | ✅ 已映射 | Spec 测试 |
| [ui/adaptive/platform_detection.md](../../openspec/specs/ui/adaptive/platform_detection.md) | `test/adaptive/platform_detector_test.dart` | ✅ 已映射 | - |
| [ui/adaptive/platform_detection.md](../../openspec/specs/ui/adaptive/platform_detection.md) | `test/specs/platform_detection_spec_test.dart` | ✅ 已映射 | Spec 测试 |
| ⚠️ 无规格 | `test/adaptive/keyboard_shortcuts_test.dart` | 🔄 额外测试 | 需要补充规格 |
| ⚠️ 无规格 | `test/adaptive/navigation/adaptive_navigation_test.dart` | 🔄 额外测试 | 需要补充规格 |

---

## 🎯 Features 映射
## Features Mapping

### Card Management

| 规格文档 Spec | 测试文件 Test | 状态 Status | 备注 Notes |
|--------------|--------------|-------------|-----------|
| [features/card_management/spec.md](../../openspec/specs/features/card_management/spec.md) | `test/specs/card_creation_spec_test.dart` | ✅ 已映射 | 卡片创建 |
| [features/card_editor/card_editor_screen.md](../../openspec/specs/features/card_editor/card_editor_screen.md) | `test/specs/card_editor_spec_test.dart` | ✅ 已映射 | - |
| [features/card_editor/fullscreen_editor.md](../../openspec/specs/features/card_editor/fullscreen_editor.md) | `test/specs/fullscreen_editor_spec_test.dart` | ✅ 已映射 | - |
| [features/card_editor/note_card.md](../../openspec/specs/features/card_editor/note_card.md) | `test/specs/note_card_component_spec_test.dart` | ✅ 已映射 | - |
| [features/card_editor/mobile.md](../../openspec/specs/features/card_editor/mobile.md) | ⚠️ 共享测试 | 🔄 部分覆盖 | 使用通用测试 |
| [features/card_editor/desktop.md](../../openspec/specs/features/card_editor/desktop.md) | ⚠️ 共享测试 | 🔄 部分覆盖 | 使用通用测试 |
| [features/card_detail/card_detail_screen.md](../../openspec/specs/features/card_detail/card_detail_screen.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |
| [features/card_list/card_list_item.md](../../openspec/specs/features/card_list/card_list_item.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |
| [features/card_list/mobile.md](../../openspec/specs/features/card_list/mobile.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |
| [features/card_list/desktop.md](../../openspec/specs/features/card_list/desktop.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |

### Home Screen

| 规格文档 Spec | 测试文件 Test | 状态 Status | 备注 Notes |
|--------------|--------------|-------------|-----------|
| [features/home_screen/home_screen.md](../../openspec/specs/features/home_screen/home_screen.md) | `test/specs/home_screen_spec_test.dart` | ✅ 已映射 | - |
| [features/home_screen/home_screen.md](../../openspec/specs/features/home_screen/home_screen.md) | `test/specs/home_screen_ui_spec_test.dart` | ✅ 已映射 | UI 层测试 |
| [features/home_screen/home_screen.md](../../openspec/specs/features/home_screen/home_screen.md) | `test/integration/home_screen_flow_test.dart` | ✅ 已映射 | 集成测试 |
| [features/home_screen/shared.md](../../openspec/specs/features/home_screen/shared.md) | ⚠️ 共享测试 | 🔄 部分覆盖 | 使用通用测试 |

### Navigation

| 规格文档 Spec | 测试文件 Test | 状态 Status | 备注 Notes |
|--------------|--------------|-------------|-----------|
| [features/navigation/mobile_nav.md](../../openspec/specs/features/navigation/mobile_nav.md) | `test/specs/mobile_navigation_spec_test.dart` | ✅ 已映射 | - |
| [features/navigation/mobile.md](../../openspec/specs/features/navigation/mobile.md) | ⚠️ 共享测试 | 🔄 部分覆盖 | 使用通用测试 |

### Sync & Feedback

| 规格文档 Spec | 测试文件 Test | 状态 Status | 备注 Notes |
|--------------|--------------|-------------|-----------|
| [features/p2p_sync/spec.md](../../openspec/specs/features/p2p_sync/spec.md) | ❌ 无测试 | ⚠️ 缺失 | 后端测试在 Rust |
| [features/sync/sync_screen.md](../../openspec/specs/features/sync/sync_screen.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |
| [features/sync_feedback/shared.md](../../openspec/specs/features/sync_feedback/shared.md) | `test/specs/sync_feedback_spec_test.dart` | ✅ 已映射 | - |
| [features/sync_feedback/sync_status_indicator.md](../../openspec/specs/features/sync_feedback/sync_status_indicator.md) | `test/specs/sync_status_indicator_component_spec_test.dart` | ✅ 已映射 | - |
| [features/sync_feedback/sync_details_dialog.md](../../openspec/specs/features/sync_feedback/sync_details_dialog.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |

### Settings

| 规格文档 Spec | 测试文件 Test | 状态 Status | 备注 Notes |
|--------------|--------------|-------------|-----------|
| [features/settings/spec.md](../../openspec/specs/features/settings/spec.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |
| [features/settings/settings_screen.md](../../openspec/specs/features/settings/settings_screen.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |
| [features/settings/settings_panel.md](../../openspec/specs/features/settings/settings_panel.md) | `test/widgets/settings_panel_test.dart` | ✅ 已映射 | - |
| [features/settings/device_manager_panel.md](../../openspec/specs/features/settings/device_manager_panel.md) | `test/specs/device_manager_ui_spec_test.dart` | ✅ 已映射 | - |

### Onboarding

| 规格文档 Spec | 测试文件 Test | 状态 Status | 备注 Notes |
|--------------|--------------|-------------|-----------|
| [features/onboarding/shared.md](../../openspec/specs/features/onboarding/shared.md) | `test/specs/onboarding_spec_test.dart` | ✅ 已映射 | - |

### Search & Filter

| 规格文档 Spec | 测试文件 Test | 状态 Status | 备注 Notes |
|--------------|--------------|-------------|-----------|
| [features/search_and_filter/spec.md](../../openspec/specs/features/search_and_filter/spec.md) | `test/integration/home_screen_search_test.dart` | ✅ 已映射 | 集成测试 |
| [features/search/mobile.md](../../openspec/specs/features/search/mobile.md) | ⚠️ 共享测试 | 🔄 部分覆盖 | 使用集成测试 |
| [features/search/desktop.md](../../openspec/specs/features/search/desktop.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |

### Other Features

| 规格文档 Spec | 测试文件 Test | 状态 Status | 备注 Notes |
|--------------|--------------|-------------|-----------|
| [features/pool_management/spec.md](../../openspec/specs/features/pool_management/spec.md) | ❌ 无测试 | ⚠️ 缺失 | 后端测试在 Rust |
| [features/fab/mobile.md](../../openspec/specs/features/fab/mobile.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |
| [features/gestures/mobile.md](../../openspec/specs/features/gestures/mobile.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |
| [features/toolbar/desktop.md](../../openspec/specs/features/toolbar/desktop.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |
| [features/context_menu/desktop.md](../../openspec/specs/features/context_menu/desktop.md) | ❌ 无测试 | ⚠️ 缺失 | 需要创建 |

---

## 🔍 额外测试 (无对应规格)
## Additional Tests (No Corresponding Specs)

| 测试文件 Test | 建议 Suggestion |
|-------------|----------------|
| `test/adaptive/keyboard_shortcuts_test.dart` | 创建 `ui/adaptive/keyboard_shortcuts.md` 规格 |
| `test/adaptive/navigation/adaptive_navigation_test.dart` | 创建 `ui/adaptive/navigation.md` 规格 |
| `test/integration/toast_notification_test.dart` | 创建 `ui/components/shared/toast_notification.md` 规格 |
| `test/specs/toast_notification_spec_test.dart` | 同上 |
| `test/specs/ui_interaction_spec_test.dart` | 创建 `ui/interactions.md` 规格或合并到现有规格 |
| `test/integration/user_journey_test.dart` | 集成测试，无需单独规格 |
| `test/widget_test.dart` | Flutter 默认测试，可删除 |

---

## 📋 缺失测试清单
## Missing Tests Checklist

### 高优先级 (P0)
### High Priority (P0)

- [ ] `test/specs/card_detail_screen_spec_test.dart` - 卡片详情屏幕
- [ ] `test/specs/settings_screen_spec_test.dart` - 设置屏幕
- [ ] `test/specs/sync_screen_spec_test.dart` - 同步屏幕
- [ ] `test/specs/card_list_spec_test.dart` - 卡片列表

### 中优先级 (P1)
### Medium Priority (P1)

- [ ] `test/specs/fab_spec_test.dart` - 浮动按钮
- [ ] `test/specs/gestures_spec_test.dart` - 手势
- [ ] `test/specs/toolbar_spec_test.dart` - 工具栏
- [ ] `test/specs/context_menu_spec_test.dart` - 右键菜单
- [ ] `test/specs/sync_details_dialog_spec_test.dart` - 同步详情对话框

### 低优先级 (P2)
### Low Priority (P2)

- [ ] `test/specs/desktop_nav_spec_test.dart` - 桌面导航
- [ ] `test/specs/desktop_card_list_item_spec_test.dart` - 桌面卡片列表项
- [ ] `test/specs/search_desktop_spec_test.dart` - 桌面搜索

---

## 📋 缺失规格清单
## Missing Specs Checklist

### 需要创建的规格
### Specs to Create

- [ ] `ui/adaptive/keyboard_shortcuts.md` - 键盘快捷键
- [ ] `ui/adaptive/navigation.md` - 自适应导航
- [ ] `ui/components/shared/toast_notification.md` - Toast 通知
- [ ] `ui/interactions.md` - UI 交互规范

---

## 🔄 映射约定
## Mapping Conventions

### 命名约定
### Naming Conventions

1. **Spec 测试**: `test/specs/{feature}_spec_test.dart`
   - 示例: `home_screen_spec_test.dart`
   - 用途: 验证规格定义的行为

2. **Widget 测试**: `test/widgets/{widget}_test.dart`
   - 示例: `note_card_test.dart`
   - 用途: 单元测试组件

3. **集成测试**: `test/integration/{feature}_test.dart`
   - 示例: `home_screen_flow_test.dart`
   - 用途: 端到端流程测试

4. **Adaptive 测试**: `test/adaptive/{feature}_test.dart`
   - 示例: `responsive_layout_test.dart`
   - 用途: 自适应和响应式测试

### 映射规则
### Mapping Rules

1. **一对一映射**: 每个规格文档应该有至少一个对应的测试文件
2. **一对多映射**: 复杂规格可以有多个测试文件 (spec test + widget test + integration test)
3. **多对一映射**: 多个平台规格 (mobile/desktop) 可以共享同一个测试文件 (如果逻辑相同)

---

## 📊 覆盖率目标
## Coverage Goals

| 阶段 Phase | 目标 Goal | 当前 Current | 状态 Status |
|-----------|----------|-------------|-------------|
| **Phase 2** | 50% | 47% | 🔄 进行中 |
| **Phase 3** | 75% | 47% | ⏳ 待开始 |
| **Phase 4** | 90% | 47% | ⏳ 待开始 |

---

## 🔧 维护指南
## Maintenance Guide

### 何时更新此文档
### When to Update This Document

1. 创建新的规格文档时
2. 创建新的测试文件时
3. 删除或重命名规格/测试时
4. 每月定期审查

### 如何更新
### How to Update

1. 在对应的表格中添加/修改行
2. 更新"映射统计"部分的数字
3. 更新"最后更新"日期
4. 提交 PR 并标记为 `docs` 类型

---

## 🆘 常见问题
## FAQ

**Q: 为什么有些规格没有测试？**
A: 可能是规格刚创建，测试还未实现。请查看"缺失测试清单"并创建对应测试。

**Q: 为什么有些测试没有规格？**
A: 可能是测试先于规格创建，或者是集成测试。请查看"额外测试"部分并补充规格。

**Q: 如何判断测试是否覆盖了规格？**
A: 阅读规格文档的"验收标准"部分，检查测试是否验证了所有关键行为。

**Q: Desktop 和 Mobile 规格可以共享测试吗？**
A: 如果逻辑完全相同，可以共享。但如果有平台特定行为，应该创建独立测试。

---

**维护说明**: 本文档应在每次创建/修改规格或测试时更新。
**Maintenance Note**: This document should be updated whenever specs or tests are created/modified.

**最后更新**: 2026-01-24 (Phase 2 - 结构重建)
**Last Updated**: 2026-01-24 (Phase 2 - Structure Rebuild)
