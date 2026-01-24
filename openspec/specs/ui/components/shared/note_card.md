# NoteCard Component Specification
# NoteCard 组件规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: Active

**Dependencies**: [card/model.md](../../../domain/card/model.md)
**依赖**: [card/model.md](../../../domain/card/model.md)

**Related Tests**: `test/widgets/note_card_test.dart`
**相关测试**: `test/widgets/note_card_test.dart`

---

## Overview
## 概述

This specification defines the requirements for the NoteCard component, which displays card content and adapts editing behavior based on the platform (desktop vs mobile).

本规格定义了 NoteCard 组件的需求，该组件显示卡片内容并根据平台（桌面端 vs 移动端）调整编辑行为。

---

## Requirement: Display card content with platform-specific editing
## 需求：显示卡片内容并支持平台特定的编辑

The system SHALL provide a card display component that adapts editing behavior based on the platform.

系统应提供卡片显示组件，根据平台调整编辑行为。

### Scenario: Desktop inline editing
### 场景：桌面端内联编辑

- **GIVEN**: user is on desktop platform
- **前置条件**：用户在桌面平台上
- **WHEN**: user clicks on a card
- **操作**：用户点击卡片
- **THEN**: the card SHALL switch to inline editing mode within the card component
- **预期结果**：卡片应在组件内切换到内联编辑模式

### Scenario: Mobile tap to open fullscreen editor
### 场景：移动端点击打开全屏编辑器

- **GIVEN**: user is on mobile platform
- **前置条件**：用户在移动平台上
- **WHEN**: user taps on a card
- **操作**：用户点击卡片
- **THEN**: the system SHALL trigger the onTap callback to open a fullscreen editor
- **预期结果**：系统应触发 onTap 回调以打开全屏编辑器

### Scenario: Real-time content update
### 场景：实时内容更新

- **GIVEN**: user is editing a card
- **前置条件**：用户正在编辑卡片
- **WHEN**: user modifies card title or content
- **操作**：用户修改卡片标题或内容
- **THEN**: the system SHALL call onUpdate callback with the modified card
- **预期结果**：系统应使用修改后的卡片调用 onUpdate 回调

---

## Requirement: Support tag management
## 需求：支持标签管理

The system SHALL allow users to add and remove tags on cards.

系统应允许用户在卡片上添加和删除标签。

### Scenario: Add tag to card
### 场景：向卡片添加标签

- **GIVEN**: user is viewing or editing a card
- **前置条件**：用户正在查看或编辑卡片
- **WHEN**: user enters a tag name and confirms
- **操作**：用户输入标签名称并确认
- **THEN**: the system SHALL add the tag to the card and call onUpdate callback
- **预期结果**：系统应将标签添加到卡片并调用 onUpdate 回调

### Scenario: Remove tag from card
### 场景：从卡片移除标签

- **GIVEN**: a card has one or more tags
- **前置条件**：卡片有一个或多个标签
- **WHEN**: user clicks the remove button on a tag
- **操作**：用户点击标签上的移除按钮
- **THEN**: the system SHALL remove the tag from the card and call onUpdate callback
- **预期结果**：系统应从卡片移除标签并调用 onUpdate 回调

---

## Requirement: Show collaboration indicators
## 需求：显示协作指示器

The system SHALL display visual indicators when a card is being edited by other devices.

系统应在卡片被其他设备编辑时显示可视化指示器。

### Scenario: Show last modified device
### 场景：显示最后修改设备

- **GIVEN**: a card exists in the pool
- **前置条件**：卡片存在于池中
- **WHEN**: the card was last modified by a device different from the current device
- **操作**：卡片最后被与当前设备不同的设备修改
- **THEN**: the system SHALL display the device name and modification time
- **预期结果**：系统应显示设备名称和修改时间

### Scenario: Highlight current device edits
### 场景：高亮显示当前设备的编辑

- **GIVEN**: a card exists in the pool
- **前置条件**：卡片存在于池中
- **WHEN**: viewing a card last modified by the current device
- **操作**：查看由当前设备最后修改的卡片
- **THEN**: the system SHALL use distinct styling to indicate local ownership
- **预期结果**：系统应使用独特的样式表示本地所有权

---

## Requirement: Support card deletion
## 需求：支持卡片删除

The system SHALL provide a delete action for cards.

系统应提供卡片删除操作。

### Scenario: Delete card
### 场景：删除卡片

- **GIVEN**: user has permission to delete cards
- **前置条件**：用户有权限删除卡片
- **WHEN**: user triggers the delete action
- **操作**：用户触发删除操作
- **THEN**: the system SHALL call onDelete callback with the card ID
- **预期结果**：系统应使用卡片 ID 调用 onDelete 回调

---

## Test Coverage
## 测试覆盖

**Test File**: `test/widgets/note_card_test.dart`
**测试文件**: `test/widgets/note_card_test.dart`

**Widget Tests**:
**Widget 测试**:
- `it_should_switch_to_inline_editing_on_desktop()` - Verify desktop editing behavior
- `it_should_switch_to_inline_editing_on_desktop()` - 验证桌面编辑行为
- `it_should_open_fullscreen_editor_on_mobile()` - Verify mobile editing behavior
- `it_should_open_fullscreen_editor_on_mobile()` - 验证移动端编辑行为
- `it_should_add_tag_to_card()` - Verify tag addition
- `it_should_add_tag_to_card()` - 验证标签添加
- `it_should_remove_tag_from_card()` - Verify tag removal
- `it_should_remove_tag_from_card()` - 验证标签移除
- `it_should_show_collaboration_indicators()` - Verify collaboration features
- `it_should_show_collaboration_indicators()` - 验证协作功能
- `it_should_delete_card()` - Verify deletion
- `it_should_delete_card()` - 验证删除

**Acceptance Criteria**:
**验收标准**:
- [ ] All widget tests pass
- [ ] 所有 Widget 测试通过
- [ ] Platform-specific behavior verified on both desktop and mobile
- [ ] 已在桌面端和移动端验证平台特定行为
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Related Specs**:
**相关规格**:
- [fullscreen_editor.md](fullscreen_editor.md) - Mobile fullscreen editor
- [fullscreen_editor.md](fullscreen_editor.md) - 移动端全屏编辑器
- [card/model.md](../../../domain/card/model.md) - Card domain model
- [card/model.md](../../../domain/card/model.md) - 卡片领域模型

---

**Last Updated**: 2026-01-24
**最后更新**: 2026-01-24

**Authors**: CardMind Team
**作者**: CardMind Team
