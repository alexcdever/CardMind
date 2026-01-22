# Card Editor Screen Specification
# 卡片编辑器屏幕规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active
**Dependencies** | **依赖**: [card_store.md](../../domain/card_store.md)
**Related Tests** | **相关测试**: `test/screens/card_editor_screen_test.dart`

---

## Overview | 概述

This specification defines the card editor screen, providing a full-screen card editing experience optimized for focused content creation.

本规格定义了卡片编辑器屏幕，提供针对专注内容创作优化的全屏卡片编辑体验。

---

## Requirement: Provide dedicated card editing interface
## 需求：提供专用的卡片编辑界面

The system SHALL offer a full-screen card editing experience optimized for focused content creation.

系统应提供针对专注内容创作优化的全屏卡片编辑体验。

### Scenario: Load existing card for editing
### 场景：加载现有卡片进行编辑

- **WHEN** editor screen opens with an existing card
- **操作**：编辑器屏幕打开现有卡片
- **THEN** the system SHALL pre-populate title and content fields
- **预期结果**：系统应预填充标题和内容字段
- **AND** load existing tags
- **并且**：加载现有标签

### Scenario: Create new card
### 场景：创建新卡片

- **WHEN** editor screen opens for new card creation
- **操作**：编辑器屏幕打开以创建新卡片
- **THEN** the system SHALL display empty title and content fields
- **预期结果**：系统应显示空的标题和内容字段
- **AND** auto-focus the title field
- **并且**：自动聚焦标题字段

---

## Requirement: Auto-save draft content
## 需求：自动保存草稿内容

The system SHALL automatically save draft content to prevent data loss.

系统应自动保存草稿内容以防止数据丢失。

### Scenario: Auto-save on content change
### 场景：内容更改时自动保存

- **WHEN** user modifies title or content
- **操作**：用户修改标题或内容
- **THEN** the system SHALL trigger auto-save after 2 seconds of inactivity
- **预期结果**：系统应在 2 秒无活动后触发自动保存

### Scenario: Restore draft on return
### 场景：返回时恢复草稿

- **WHEN** user returns to an unsaved draft
- **操作**：用户返回到未保存的草稿
- **THEN** the system SHALL restore the draft content
- **预期结果**：系统应恢复草稿内容

---

## Requirement: Rich text editing support
## 需求：富文本编辑支持

The system SHALL support basic rich text formatting.

系统应支持基本的富文本格式化。

### Scenario: Apply text formatting
### 场景：应用文本格式

- **WHEN** user applies formatting (bold, italic, etc.)
- **操作**：用户应用格式（粗体、斜体等）
- **THEN** the system SHALL apply the formatting to selected text
- **预期结果**：系统应将格式应用于选定的文本
- **AND** maintain formatting in saved content
- **并且**：在保存的内容中保持格式

---

## Requirement: Provide save and discard actions
## 需求：提供保存和丢弃操作

The system SHALL offer explicit save and discard options.

系统应提供明确的保存和丢弃选项。

### Scenario: Save card
### 场景：保存卡片

- **WHEN** user taps save button
- **操作**：用户点击保存按钮
- **THEN** the system SHALL persist the card to backend
- **预期结果**：系统应将卡片持久化到后端
- **AND** navigate back to previous screen
- **并且**：导航回上一个屏幕
- **AND** show success confirmation
- **并且**：显示成功确认

### Scenario: Discard changes
### 场景：丢弃更改

- **WHEN** user taps cancel/back button with unsaved changes
- **操作**：用户在有未保存更改时点击取消/返回按钮
- **THEN** the system SHALL show confirmation dialog
- **预期结果**：系统应显示确认对话框
- **AND** discard changes if confirmed
- **并且**：如果确认则丢弃更改
- **AND** keep editing if cancelled
- **并且**：如果取消则继续编辑

---

## Requirement: Tag management in editor
## 需求：编辑器中的标签管理

The system SHALL provide tag management within the editor.

系统应在编辑器内提供标签管理。

### Scenario: Add tag while editing
### 场景：编辑时添加标签

- **WHEN** user adds a tag
- **操作**：用户添加标签
- **THEN** the tag SHALL be included in the card when saved
- **预期结果**：保存卡片时应包含该标签

### Scenario: Remove tag while editing
### 场景：编辑时移除标签

- **WHEN** user removes a tag
- **操作**：用户移除标签
- **THEN** the tag SHALL be excluded from the card when saved
- **预期结果**：保存卡片时应排除该标签

---

## Requirement: Show character count (optional)
## 需求：显示字符计数（可选）

The system SHALL optionally display character or word count.

系统应可选地显示字符或单词计数。

### Scenario: Display content statistics
### 场景：显示内容统计

- **WHEN** user is editing content
- **操作**：用户正在编辑内容
- **THEN** the system MAY show character count or word count in the status area
- **预期结果**：系统可以在状态区域显示字符计数或单词计数

---

## Test Coverage | 测试覆盖

**Test File** | **测试文件**: `test/screens/card_editor_screen_test.dart`

**Widget Tests** | **Widget 测试**:
- `it_should_prepopulate_existing_card()` - Pre-populate existing card | 预填充现有卡片
- `it_should_load_existing_tags()` - Load existing tags | 加载现有标签
- `it_should_display_empty_fields_for_new_card()` - Empty fields for new card | 新卡片空字段
- `it_should_autofocus_title_field()` - Auto-focus title | 自动聚焦标题
- `it_should_autosave_after_inactivity()` - Auto-save after 2s | 2秒后自动保存
- `it_should_restore_draft()` - Restore draft | 恢复草稿
- `it_should_apply_text_formatting()` - Apply formatting | 应用格式
- `it_should_maintain_formatting_in_saved_content()` - Maintain formatting | 保持格式
- `it_should_save_and_navigate_back()` - Save and navigate | 保存并导航
- `it_should_show_confirmation_on_discard()` - Confirmation dialog | 确认对话框
- `it_should_add_tags()` - Add tags | 添加标签
- `it_should_remove_tags()` - Remove tags | 移除标签
- `it_should_display_character_count()` - Display count (optional) | 显示计数（可选）

**Acceptance Criteria** | **验收标准**:
- [ ] All widget tests pass | 所有 Widget 测试通过
- [ ] Auto-save works reliably | 自动保存可靠工作
- [ ] Rich text formatting works correctly | 富文本格式正确工作
- [ ] Confirmation dialog prevents data loss | 确认对话框防止数据丢失
- [ ] Code review approved | 代码审查通过
- [ ] Documentation updated | 文档已更新

---

## Related Documents | 相关文档

**Related Specs** | **相关规格**:
- [fullscreen_editor.md](fullscreen_editor.md) - Fullscreen editor | 全屏编辑器
- [note_card.md](note_card.md) - NoteCard component | NoteCard 组件
- [card_store.md](../../domain/card_store.md) - Card storage | 卡片存储

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
