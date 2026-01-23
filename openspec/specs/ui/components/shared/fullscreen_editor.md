# Fullscreen Editor Specification
# 全屏编辑器规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: Active

**Dependencies**: [card/model.md](../../../domain/card/model.md), [note_card.md](note_card.md)
**依赖**: [card/model.md](../../../domain/card/model.md), [note_card.md](note_card.md)

**Related Tests**: `test/widgets/fullscreen_editor_test.dart`
**相关测试**: `test/widgets/fullscreen_editor_test.dart`

---

## Overview
## 概述

This specification defines the fullscreen editor for mobile platforms, providing an immersive editing experience with minimal distractions.

本规格定义了移动平台的全屏编辑器，提供沉浸式编辑体验，减少干扰。

---

## Requirement: Provide immersive fullscreen editing experience
## 需求：提供沉浸式全屏编辑体验

The system SHALL provide a fullscreen editor optimized for mobile platforms with minimal distractions.

系统应提供针对移动平台优化的全屏编辑器，减少干扰。

### Scenario: Open editor with existing card
### 场景：打开现有卡片的编辑器

- **GIVEN**: an existing card is selected for editing
- **前置条件**：选择了现有卡片进行编辑
- **WHEN**: user opens the fullscreen editor
- **操作**：用户打开全屏编辑器
- **THEN**: the system SHALL pre-populate title and content fields with the card's current data
- **预期结果**：系统应使用卡片的当前数据预填充标题和内容字段

### Scenario: Open editor for new card
### 场景：打开新卡片编辑器

- **GIVEN**: user wants to create a new card
- **前置条件**：用户想要创建新卡片
- **WHEN**: user opens the fullscreen editor without a card
- **操作**：用户打开不含卡片的全屏编辑器
- **THEN**: the system SHALL display empty title and content fields ready for input
- **预期结果**：系统应显示空的标题和内容字段，准备接受输入

---

## Requirement: Auto-save draft periodically
## 需求：定期自动保存草稿

The system SHALL automatically save draft content to prevent data loss during editing.

系统应自动保存草稿内容，以防止编辑期间数据丢失。

### Scenario: Auto-save after content change
### 场景：内容更改后自动保存

- **GIVEN**: user is editing a card
- **前置条件**：用户正在编辑卡片
- **WHEN**: user modifies title or content
- **操作**：用户修改标题或内容
- **THEN**: the system SHALL trigger auto-save after 2 seconds of inactivity
- **预期结果**：系统应在 2 秒无活动后触发自动保存

### Scenario: Restore draft on re-open
### 场景：重新打开时恢复草稿

- **GIVEN**: user has an auto-saved draft
- **前置条件**：用户有自动保存的草稿
- **WHEN**: user closes editor without saving and reopens
- **操作**：用户未保存关闭编辑器并重新打开
- **THEN**: the system SHALL restore the last auto-saved draft
- **预期结果**：系统应恢复最后一次自动保存的草稿

---

## Requirement: Manage tags within editor
## 需求：在编辑器内管理标签

The system SHALL provide tag management functionality within the fullscreen editor.

系统应在全屏编辑器内提供标签管理功能。

### Scenario: Add tag during editing
### 场景：编辑时添加标签

- **GIVEN**: user is editing a card
- **前置条件**：用户正在编辑卡片
- **WHEN**: user adds a tag in the editor
- **操作**：用户在编辑器中添加标签
- **THEN**: the tag SHALL be included when saving the card
- **预期结果**：保存卡片时应包含该标签

### Scenario: Remove tag during editing
### 场景：编辑时移除标签

- **GIVEN**: a card has one or more tags
- **前置条件**：卡片有一个或多个标签
- **WHEN**: user removes a tag in the editor
- **操作**：用户在编辑器中移除标签
- **THEN**: the tag SHALL be excluded when saving the card
- **预期结果**：保存卡片时应排除该标签

---

## Requirement: Save and cancel actions
## 需求：保存和取消操作

The system SHALL provide explicit save and cancel actions.

系统应提供明确的保存和取消操作。

### Scenario: Save edited card
### 场景：保存编辑的卡片

- **GIVEN**: user has made changes to a card
- **前置条件**：用户对卡片进行了更改
- **WHEN**: user taps the save button
- **操作**：用户点击保存按钮
- **THEN**: the system SHALL call onSave callback with the updated card data
- **预期结果**：系统应使用更新的卡片数据调用 onSave 回调
- **AND**: close the fullscreen editor
- **并且**：关闭全屏编辑器

### Scenario: Cancel editing
### 场景：取消编辑

- **GIVEN**: user is editing a card
- **前置条件**：用户正在编辑卡片
- **WHEN**: user taps the cancel button
- **操作**：用户点击取消按钮
- **THEN**: the system SHALL call onCancel callback without saving
- **预期结果**：系统应在不保存的情况下调用 onCancel 回调
- **AND**: close the fullscreen editor
- **并且**：关闭全屏编辑器
- **AND**: discard the auto-saved draft
- **并且**：丢弃自动保存的草稿

---

## Requirement: Keyboard optimization
## 需求：键盘优化

The system SHALL optimize keyboard behavior for efficient mobile editing.

系统应优化键盘行为以实现高效的移动编辑。

### Scenario: Auto-focus on title field
### 场景：自动聚焦标题字段

- **GIVEN**: user is creating a new card
- **前置条件**：用户正在创建新卡片
- **WHEN**: editor opens for a new card
- **操作**：为新卡片打开编辑器
- **THEN**: the system SHALL automatically focus the title field and show the keyboard
- **预期结果**：系统应自动聚焦标题字段并显示键盘

### Scenario: Maintain keyboard across field transitions
### 场景：字段转换时保持键盘显示

- **GIVEN**: user is editing a card
- **前置条件**：用户正在编辑卡片
- **WHEN**: user moves from title to content field
- **操作**：用户从标题字段移动到内容字段
- **THEN**: the keyboard SHALL remain visible without dismissing and re-appearing
- **预期结果**：键盘应保持可见，不会消失后重新出现

---

## Test Coverage
## 测试覆盖

**Test File**: `test/widgets/fullscreen_editor_test.dart`
**测试文件**: `test/widgets/fullscreen_editor_test.dart`

**Widget Tests**:
**Widget 测试**:
- `it_should_prepopulate_existing_card_data()` - Pre-populate existing card
- `it_should_prepopulate_existing_card_data()` - 预填充现有卡片
- `it_should_display_empty_fields_for_new_card()` - Display empty fields
- `it_should_display_empty_fields_for_new_card()` - 显示空字段
- `it_should_autosave_after_inactivity()` - Auto-save after 2s inactivity
- `it_should_autosave_after_inactivity()` - 2秒无活动后自动保存
- `it_should_restore_draft_on_reopen()` - Restore draft
- `it_should_restore_draft_on_reopen()` - 恢复草稿
- `it_should_include_added_tags()` - Include added tags
- `it_should_include_added_tags()` - 包含添加的标签
- `it_should_exclude_removed_tags()` - Exclude removed tags
- `it_should_exclude_removed_tags()` - 排除移除的标签
- `it_should_save_and_close_on_save()` - Save and close
- `it_should_save_and_close_on_save()` - 保存并关闭
- `it_should_cancel_and_discard_draft()` - Cancel and discard
- `it_should_cancel_and_discard_draft()` - 取消并丢弃
- `it_should_autofocus_title_for_new_card()` - Auto-focus title
- `it_should_autofocus_title_for_new_card()` - 自动聚焦标题
- `it_should_maintain_keyboard_on_field_transition()` - Maintain keyboard
- `it_should_maintain_keyboard_on_field_transition()` - 保持键盘

**Acceptance Criteria**:
**验收标准**:
- [ ] All widget tests pass
- [ ] 所有 Widget 测试通过
- [ ] Auto-save works reliably
- [ ] 自动保存可靠工作
- [ ] Keyboard behavior is smooth
- [ ] 键盘行为流畅
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Related Specs**:
**相关规格**:
- [note_card.md](note_card.md) - NoteCard component
- [note_card.md](note_card.md) - NoteCard 组件
- [card/model.md](../../../domain/card/model.md) - Card domain model
- [card/model.md](../../../domain/card/model.md) - 卡片领域模型

---

**Last Updated**: 2026-01-24
**最后更新**: 2026-01-24

**Authors**: CardMind Team
**作者**: CardMind Team
