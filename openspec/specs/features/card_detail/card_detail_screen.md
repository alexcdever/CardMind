# Card Detail Screen Specification | 卡片详情屏幕规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active
**Dependencies** | **依赖**: [card_store.md](../../domain/card_store.md)
**Related Tests** | **相关测试**: `test/screens/card_detail_screen_test.dart`

---

## Overview | 概述

This specification defines the card detail screen that shows the complete card content with all metadata and editing capabilities.

本规格定义了卡片详情屏幕，显示完整的卡片内容及所有元数据和编辑功能。

---

## Requirement: Display full card content | 需求：显示完整的卡片内容

The system SHALL show the complete card content with all metadata and editing capabilities.

系统应显示完整的卡片内容及所有元数据和编辑功能。

### Scenario: Display card title and content | 场景：显示卡片标题和内容

- **WHEN** card detail screen loads
- **操作**：卡片详情屏幕加载
- **THEN** the system SHALL display the full card title
- **预期结果**：系统应显示完整的卡片标题
- **AND** show the complete card content with proper formatting
- **并且**：显示格式正确的完整卡片内容

### Scenario: Show card metadata | 场景：显示卡片元数据

- **WHEN** displaying card details
- **操作**：显示卡片详情
- **THEN** the system SHALL show creation timestamp
- **预期结果**：系统应显示创建时间戳
- **AND** display last modified timestamp
- **并且**：显示最后修改时间戳
- **AND** show last modified device name
- **并且**：显示最后修改的设备名称

---

## Requirement: Support inline editing | 需求：支持内联编辑

The system SHALL allow users to edit the card directly on the detail screen.

系统应允许用户直接在详情屏幕上编辑卡片。

### Scenario: Enter edit mode | 场景：进入编辑模式

- **WHEN** user taps the edit button
- **操作**：用户点击编辑按钮
- **THEN** the system SHALL make title and content fields editable
- **预期结果**：系统应使标题和内容字段可编辑
- **AND** show save and cancel buttons
- **并且**：显示保存和取消按钮

### Scenario: Save changes | 场景：保存更改

- **WHEN** user saves edits
- **操作**：用户保存编辑
- **THEN** the system SHALL update the card in the backend
- **预期结果**：系统应在后端更新卡片
- **AND** exit edit mode
- **并且**：退出编辑模式
- **AND** show confirmation feedback
- **并且**：显示确认反馈

---

## Requirement: Display and manage tags | 需求：显示和管理标签

The system SHALL show card tags and allow tag management.

系统应显示卡片标签并允许标签管理。

### Scenario: Display tags | 场景：显示标签

- **WHEN** card has tags
- **操作**：卡片有标签
- **THEN** the system SHALL display all tags as chips
- **预期结果**：系统应将所有标签显示为芯片

### Scenario: Add tag | 场景：添加标签

- **WHEN** user adds a tag
- **操作**：用户添加标签
- **THEN** the system SHALL add the tag to the card
- **预期结果**：系统应将标签添加到卡片
- **AND** update the display immediately
- **并且**：立即更新显示

### Scenario: Remove tag | 场景：移除标签

- **WHEN** user taps the remove icon on a tag
- **操作**：用户点击标签上的移除图标
- **THEN** the system SHALL remove the tag from the card
- **预期结果**：系统应从卡片中移除标签

---

## Requirement: Provide card actions | 需求：提供卡片操作

The system SHALL offer actions for managing the card.

系统应提供管理卡片的操作。

### Scenario: Delete card | 场景：删除卡片

- **WHEN** user selects delete action
- **操作**：用户选择删除操作
- **THEN** the system SHALL show confirmation dialog
- **预期结果**：系统应显示确认对话框
- **AND** delete the card and navigate back upon confirmation
- **并且**：确认后删除卡片并返回

### Scenario: Share card | 场景：分享卡片

- **WHEN** user selects share action
- **操作**：用户选择分享操作
- **THEN** the system SHALL open the share dialog with card content
- **预期结果**：系统应打开包含卡片内容的分享对话框

---

## Requirement: Show sync information | 需求：显示同步信息

The system SHALL display synchronization information for the card.

系统应显示卡片的同步信息。

### Scenario: Show sync status | 场景：显示同步状态

- **WHEN** displaying card details
- **操作**：显示卡片详情
- **THEN** the system SHALL show whether the card is synced across devices
- **预期结果**：系统应显示卡片是否已在设备间同步
- **AND** display last sync timestamp
- **并且**：显示上次同步时间戳

---

## Test Coverage | 测试覆盖

**Test File** | **测试文件**: `test/screens/card_detail_screen_test.dart`

**Screen Tests** | **屏幕测试**:
- `it_should_display_full_title()` - Display title | 显示标题
- `it_should_show_complete_content()` - Show content | 显示内容
- `it_should_show_metadata()` - Show metadata | 显示元数据
- `it_should_enter_edit_mode()` - Enter edit mode | 进入编辑模式
- `it_should_save_changes()` - Save changes | 保存更改
- `it_should_display_tags()` - Display tags | 显示标签
- `it_should_add_tag()` - Add tag | 添加标签
- `it_should_remove_tag()` - Remove tag | 移除标签
- `it_should_delete_card_with_confirmation()` - Delete with confirmation | 确认删除
- `it_should_share_card()` - Share card | 分享卡片
- `it_should_show_sync_status()` - Show sync status | 显示同步状态

**Acceptance Criteria** | **验收标准**:
- [ ] All screen tests pass | 所有屏幕测试通过
- [ ] Inline editing works smoothly | 内联编辑流畅工作
- [ ] Tag management is intuitive | 标签管理直观
- [ ] Card actions work correctly | 卡片操作正确工作
- [ ] Code review approved | 代码审查通过
- [ ] Documentation updated | 文档已更新

---

## Related Documents | 相关文档

**Related Specs** | **相关规格**:
- [card_store.md](../../domain/card_store.md) - Card storage | 卡片存储
- [card_editor_screen.md](../card_editor/card_editor_screen.md) - Card editor | 卡片编辑器
- [note_card.md](../card_editor/note_card.md) - NoteCard component | NoteCard 组件

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
