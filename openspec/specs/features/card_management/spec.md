# Card Management Feature Specification
# 卡片管理功能规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: Active

**Dependencies**: [../../domain/card/rules.md](../../domain/card/rules.md), [../../domain/pool/model.md](../../domain/pool/model.md)
**依赖**: [../../domain/card/rules.md](../../domain/card/rules.md), [../../domain/pool/model.md](../../domain/pool/model.md)

**Related Tests**: `test/features/card_management_test.dart`
**相关测试**: `test/features/card_management_test.dart`

---

## Overview
## 概述

This specification defines the Card Management feature, which enables users to create, view, edit, and delete note cards in the CardMind system. The feature provides a complete user journey from card creation to deletion, with automatic draft saving, tag management, and multi-device collaboration support.

本规格定义了卡片管理功能，使用户能够在 CardMind 系统中创建、查看、编辑和删除笔记卡片。该功能提供从卡片创建到删除的完整用户旅程，支持自动草稿保存、标签管理和多设备协作。

**Key User Journeys**:
**核心用户旅程**:
- Create new note cards with title and content
- 创建包含标题和内容的新笔记卡片
- View complete card details with metadata
- 查看包含元数据的完整卡片详情
- Edit existing cards with automatic draft saving
- 编辑现有卡片并自动保存草稿
- Manage tags (add, remove, prevent duplicates)
- 管理标签（添加、移除、防止重复）
- Delete cards with confirmation
- 删除卡片并确认
- Share card content with other applications
- 与其他应用分享卡片内容

---

## Requirement: Card Creation
## 需求：卡片创建

Users SHALL be able to create new note cards with a title and optional content.

用户应能够创建包含标题和可选内容的新笔记卡片。

### Scenario: Create card with title and content
### 场景：创建包含标题和内容的卡片

- **GIVEN**: The user has joined a pool
- **前置条件**: 用户已加入一个池
- **WHEN**: The user creates a new card with title "Meeting Notes" and content "Discussed project timeline"
- **操作**: 用户创建标题为"Meeting Notes"、内容为"Discussed project timeline"的新卡片
- **THEN**: The system SHALL create a card with UUID v7 identifier
- **预期结果**: 系统应使用 UUID v7 标识符创建卡片
- **AND**: The card SHALL be automatically associated with the current pool
- **并且**: 卡片应自动关联到当前池
- **AND**: The card SHALL be visible to all devices in the pool
- **并且**: 该池中的所有设备应可见该卡片
- **AND**: The creation timestamp SHALL be recorded
- **并且**: 应记录创建时间戳

### Scenario: Create card with title only
### 场景：仅使用标题创建卡片

- **GIVEN**: The user has joined a pool
- **前置条件**: 用户已加入一个池
- **WHEN**: The user creates a new card with title "Quick Note" and empty content
- **操作**: 用户创建标题为"Quick Note"、内容为空的新卡片
- **THEN**: The system SHALL create the card successfully
- **预期结果**: 系统应成功创建卡片
- **AND**: The content field SHALL be empty
- **并且**: 内容字段应为空

### Scenario: Reject card creation without title
### 场景：拒绝创建无标题的卡片

- **GIVEN**: The user attempts to create a card
- **前置条件**: 用户尝试创建卡片
- **WHEN**: The user provides empty title or whitespace-only title
- **操作**: 用户提供空标题或仅包含空格的标题
- **THEN**: The system SHALL reject the creation
- **预期结果**: 系统应拒绝创建
- **AND**: The system SHALL display error message "Title is required"
- **并且**: 系统应显示错误消息"标题为必填项"

### Scenario: Reject card creation when not joined to pool
### 场景：未加入池时拒绝创建卡片

- **GIVEN**: The user has not joined any pool
- **前置条件**: 用户未加入任何池
- **WHEN**: The user attempts to create a new card
- **操作**: 用户尝试创建新卡片
- **THEN**: The system SHALL reject the creation with error "NO_POOL_JOINED"
- **预期结果**: 系统应以错误"NO_POOL_JOINED"拒绝创建
- **AND**: The system SHALL prompt the user to join or create a pool
- **并且**: 系统应提示用户加入或创建池

---

## Requirement: Card Viewing
## 需求：卡片查看

Users SHALL be able to view complete card details including content, metadata, tags, and sync information.

用户应能够查看完整的卡片详情，包括内容、元数据、标签和同步信息。

### Scenario: View card details
### 场景：查看卡片详情

- **GIVEN**: A card exists with title, content, and tags
- **前置条件**: 存在包含标题、内容和标签的卡片
- **WHEN**: The user opens the card detail view
- **操作**: 用户打开卡片详情视图
- **THEN**: The system SHALL display the card title
- **预期结果**: 系统应显示卡片标题
- **AND**: The system SHALL display the card content
- **并且**: 系统应显示卡片内容
- **AND**: The system SHALL display creation timestamp
- **并且**: 系统应显示创建时间戳
- **AND**: The system SHALL display last modified timestamp
- **并且**: 系统应显示最后修改时间戳
- **AND**: The system SHALL display all associated tags
- **并且**: 系统应显示所有关联的标签

### Scenario: View collaboration information
### 场景：查看协作信息

- **GIVEN**: A card was last modified by another device
- **前置条件**: 卡片最后由另一设备修改
- **WHEN**: The user views the card details
- **操作**: 用户查看卡片详情
- **THEN**: The system SHALL display the device name that last modified the card
- **预期结果**: 系统应显示最后修改卡片的设备名称
- **AND**: The system SHALL display the modification timestamp
- **并且**: 系统应显示修改时间戳

### Scenario: View sync status
### 场景：查看同步状态

- **GIVEN**: A card has sync status information
- **前置条件**: 卡片有同步状态信息
- **WHEN**: The user views the card details
- **操作**: 用户查看卡片详情
- **THEN**: The system SHALL display current sync status (synced, syncing, or error)
- **预期结果**: 系统应显示当前同步状态（已同步、同步中或错误）
- **AND**: The system SHALL display last sync timestamp
- **并且**: 系统应显示最后同步时间戳

---

## Requirement: Card Editing
## 需求：卡片编辑

Users SHALL be able to edit existing cards with automatic draft saving to prevent data loss.

用户应能够编辑现有卡片，并自动保存草稿以防止数据丢失。

### Scenario: Edit card title and content
### 场景：编辑卡片标题和内容

- **GIVEN**: A card exists with title "Old Title" and content "Old Content"
- **前置条件**: 存在标题为"Old Title"、内容为"Old Content"的卡片
- **WHEN**: The user edits the title to "New Title" and content to "New Content"
- **操作**: 用户将标题编辑为"New Title"、内容编辑为"New Content"
- **AND**: The user saves the changes
- **并且**: 用户保存更改
- **THEN**: The system SHALL update the card with new title and content
- **预期结果**: 系统应使用新标题和内容更新卡片
- **AND**: The system SHALL update the last modified timestamp
- **并且**: 系统应更新最后修改时间戳
- **AND**: The system SHALL record the current device as the modifier
- **并且**: 系统应记录当前设备为修改者
- **AND**: The changes SHALL sync to all devices in the pool
- **并且**: 更改应同步到池中的所有设备

### Scenario: Automatic draft saving during editing
### 场景：编辑时自动保存草稿

- **GIVEN**: The user is editing a card
- **前置条件**: 用户正在编辑卡片
- **WHEN**: The user stops typing for 500 milliseconds
- **操作**: 用户停止输入500毫秒
- **THEN**: The system SHALL automatically save the current state as a draft
- **预期结果**: 系统应自动将当前状态保存为草稿
- **AND**: The system SHALL display "Draft saved" indicator
- **并且**: 系统应显示"草稿已保存"指示器

### Scenario: Restore draft on editor reopen
### 场景：重新打开编辑器时恢复草稿

- **GIVEN**: The user was editing a card and closed the editor without saving
- **前置条件**: 用户正在编辑卡片并在未保存的情况下关闭了编辑器
- **AND**: A draft was automatically saved
- **并且**: 草稿已自动保存
- **WHEN**: The user reopens the editor for the same card
- **操作**: 用户重新打开同一卡片的编辑器
- **THEN**: The system SHALL restore the draft content
- **预期结果**: 系统应恢复草稿内容
- **AND**: The system SHALL display "Draft restored" message
- **并且**: 系统应显示"草稿已恢复"消息

### Scenario: Discard draft on explicit save
### 场景：显式保存时丢弃草稿

- **GIVEN**: The user has a draft saved
- **前置条件**: 用户有已保存的草稿
- **WHEN**: The user explicitly saves the card
- **操作**: 用户显式保存卡片
- **THEN**: The system SHALL persist the changes to the card
- **预期结果**: 系统应将更改持久化到卡片
- **AND**: The system SHALL delete the draft
- **并且**: 系统应删除草稿

### Scenario: Cancel editing and discard changes
### 场景：取消编辑并丢弃更改

- **GIVEN**: The user is editing a card with unsaved changes
- **前置条件**: 用户正在编辑包含未保存更改的卡片
- **WHEN**: The user clicks "Cancel" or "Discard"
- **操作**: 用户点击"取消"或"丢弃"
- **THEN**: The system SHALL display confirmation dialog "Discard unsaved changes?"
- **预期结果**: 系统应显示确认对话框"丢弃未保存的更改？"
- **AND**: If user confirms, the system SHALL revert to the last saved state
- **并且**: 如果用户确认，系统应恢复到最后保存的状态
- **AND**: The system SHALL delete the draft
- **并且**: 系统应删除草稿

### Scenario: Prevent saving card with empty title
### 场景：防止保存空标题的卡片

- **GIVEN**: The user is editing a card
- **前置条件**: 用户正在编辑卡片
- **WHEN**: The user clears the title field and attempts to save
- **操作**: 用户清空标题字段并尝试保存
- **THEN**: The system SHALL reject the save operation
- **预期结果**: 系统应拒绝保存操作
- **AND**: The system SHALL display error "Title cannot be empty"
- **并且**: 系统应显示错误"标题不能为空"
- **AND**: The system SHALL keep the editor open
- **并且**: 系统应保持编辑器打开

---

## Requirement: Tag Management
## 需求：标签管理

Users SHALL be able to add and remove tags to organize cards, with automatic duplicate prevention.

用户应能够添加和移除标签以组织卡片，并自动防止重复。

### Scenario: Add tag to card
### 场景：向卡片添加标签

- **GIVEN**: A card exists without tags
- **前置条件**: 存在没有标签的卡片
- **WHEN**: The user adds tag "work"
- **操作**: 用户添加标签"work"
- **THEN**: The system SHALL associate the tag with the card
- **预期结果**: 系统应将标签关联到卡片
- **AND**: The tag SHALL be visible in the card view
- **并且**: 标签应在卡片视图中可见
- **AND**: The change SHALL sync to all devices
- **并且**: 更改应同步到所有设备

### Scenario: Add multiple tags to card
### 场景：向卡片添加多个标签

- **GIVEN**: A card exists with tag "work"
- **前置条件**: 存在包含标签"work"的卡片
- **WHEN**: The user adds tags "urgent" and "meeting"
- **操作**: 用户添加标签"urgent"和"meeting"
- **THEN**: The card SHALL have three tags: "work", "urgent", "meeting"
- **预期结果**: 卡片应有三个标签："work"、"urgent"、"meeting"

### Scenario: Prevent duplicate tags
### 场景：防止重复标签

- **GIVEN**: A card has tag "work"
- **前置条件**: 卡片有标签"work"
- **WHEN**: The user attempts to add tag "work" again
- **操作**: 用户尝试再次添加标签"work"
- **THEN**: The system SHALL reject the duplicate tag
- **预期结果**: 系统应拒绝重复标签
- **AND**: The system SHALL display message "Tag already exists"
- **并且**: 系统应显示消息"标签已存在"

### Scenario: Remove tag from card
### 场景：从卡片移除标签

- **GIVEN**: A card has tags "work" and "urgent"
- **前置条件**: 卡片有标签"work"和"urgent"
- **WHEN**: The user removes tag "urgent"
- **操作**: 用户移除标签"urgent"
- **THEN**: The card SHALL only have tag "work"
- **预期结果**: 卡片应只有标签"work"
- **AND**: The change SHALL sync to all devices
- **并且**: 更改应同步到所有设备

### Scenario: Tag case sensitivity
### 场景：标签大小写敏感性

- **GIVEN**: A card has tag "Work"
- **前置条件**: 卡片有标签"Work"
- **WHEN**: The user attempts to add tag "work"
- **操作**: 用户尝试添加标签"work"
- **THEN**: The system SHALL treat "Work" and "work" as different tags
- **预期结果**: 系统应将"Work"和"work"视为不同标签
- **AND**: Both tags SHALL be added to the card
- **并且**: 两个标签都应添加到卡片

---

## Requirement: Card Deletion
## 需求：卡片删除

Users SHALL be able to delete cards with confirmation to prevent accidental deletion.

用户应能够删除卡片并确认，以防止意外删除。

### Scenario: Delete card with confirmation
### 场景：确认后删除卡片

- **GIVEN**: A card exists
- **前置条件**: 存在卡片
- **WHEN**: The user selects "Delete" action
- **操作**: 用户选择"删除"操作
- **THEN**: The system SHALL display confirmation dialog "Delete this card?"
- **预期结果**: 系统应显示确认对话框"删除此卡片？"
- **AND**: If user confirms, the system SHALL soft-delete the card
- **并且**: 如果用户确认，系统应软删除卡片
- **AND**: The card SHALL be marked as deleted but not physically removed
- **并且**: 卡片应标记为已删除但不物理移除
- **AND**: The deletion SHALL sync to all devices
- **并且**: 删除操作应同步到所有设备

### Scenario: Cancel card deletion
### 场景：取消卡片删除

- **GIVEN**: A card exists
- **前置条件**: 存在卡片
- **WHEN**: The user selects "Delete" action
- **操作**: 用户选择"删除"操作
- **AND**: The user clicks "Cancel" in the confirmation dialog
- **并且**: 用户在确认对话框中点击"取消"
- **THEN**: The system SHALL not delete the card
- **预期结果**: 系统应不删除卡片
- **AND**: The card SHALL remain visible and accessible
- **并且**: 卡片应保持可见和可访问

### Scenario: Soft deletion preserves data
### 场景：软删除保留数据

- **GIVEN**: A card is soft-deleted
- **前置条件**: 卡片被软删除
- **WHEN**: An administrator queries deleted cards
- **操作**: 管理员查询已删除的卡片
- **THEN**: The system SHALL return the deleted card with all its data
- **预期结果**: 系统应返回包含所有数据的已删除卡片
- **AND**: The card SHALL have deleted flag set to true
- **并且**: 卡片应将删除标志设置为true

---

## Requirement: Card Sharing
## 需求：卡片分享

Users SHALL be able to share card content with other applications.

用户应能够与其他应用分享卡片内容。

### Scenario: Share card as plain text
### 场景：以纯文本形式分享卡片

- **GIVEN**: A card exists with title and content
- **前置条件**: 存在包含标题和内容的卡片
- **WHEN**: The user selects "Share" action
- **操作**: 用户选择"分享"操作
- **THEN**: The system SHALL format the card as plain text
- **预期结果**: 系统应将卡片格式化为纯文本
- **AND**: The format SHALL be: "Title\n\nContent"
- **并且**: 格式应为："标题\n\n内容"
- **AND**: The system SHALL open the platform share dialog
- **并且**: 系统应打开平台分享对话框

### Scenario: Share card with tags
### 场景：分享包含标签的卡片

- **GIVEN**: A card has title, content, and tags "work", "urgent"
- **前置条件**: 卡片有标题、内容和标签"work"、"urgent"
- **WHEN**: The user shares the card
- **操作**: 用户分享卡片
- **THEN**: The shared text SHALL include tags at the end
- **预期结果**: 分享的文本应在末尾包含标签
- **AND**: The format SHALL be: "Title\n\nContent\n\nTags: work, urgent"
- **并且**: 格式应为："标题\n\n内容\n\n标签：work, urgent"

---

## Requirement: Platform-Specific Editing Modes
## 需求：平台特定的编辑模式

The system SHALL provide platform-optimized editing experiences: inline editing for desktop and fullscreen editing for mobile.

系统应提供平台优化的编辑体验：桌面端的内联编辑和移动端的全屏编辑。

### Scenario: Desktop inline editing
### 场景：桌面端内联编辑

- **GIVEN**: The user is on a desktop platform
- **前置条件**: 用户在桌面平台上
- **WHEN**: The user clicks "Edit" on a card
- **操作**: 用户点击卡片上的"编辑"
- **THEN**: The system SHALL enable inline editing within the card view
- **预期结果**: 系统应在卡片视图内启用内联编辑
- **AND**: The system SHALL keep the surrounding context visible
- **并且**: 系统应保持周围上下文可见
- **AND**: The system SHALL support keyboard shortcuts (Cmd/Ctrl+Enter to save, Escape to cancel)
- **并且**: 系统应支持键盘快捷键（Cmd/Ctrl+Enter保存，Escape取消）

### Scenario: Mobile fullscreen editing
### 场景：移动端全屏编辑

- **GIVEN**: The user is on a mobile platform
- **前置条件**: 用户在移动平台上
- **WHEN**: The user taps a card to edit
- **操作**: 用户点击卡片进行编辑
- **THEN**: The system SHALL open a fullscreen editor
- **预期结果**: 系统应打开全屏编辑器
- **AND**: The system SHALL hide navigation bars for immersive experience
- **并且**: 系统应隐藏导航栏以提供沉浸式体验
- **AND**: The system SHALL automatically show the keyboard
- **并且**: 系统应自动显示键盘
- **AND**: The system SHALL focus on the title field
- **并且**: 系统应聚焦到标题字段

### Scenario: Only one card editable at a time on desktop
### 场景：桌面端一次只能编辑一张卡片

- **GIVEN**: The user is editing card A on desktop
- **前置条件**: 用户在桌面端正在编辑卡片A
- **WHEN**: The user clicks "Edit" on card B
- **操作**: 用户点击卡片B的"编辑"
- **THEN**: The system SHALL automatically save card A
- **预期结果**: 系统应自动保存卡片A
- **AND**: The system SHALL exit edit mode for card A
- **并且**: 系统应退出卡片A的编辑模式
- **AND**: The system SHALL enter edit mode for card B
- **并且**: 系统应进入卡片B的编辑模式

---

## Business Rules
## 业务规则

### Automatic Pool Association
### 自动池关联

All newly created cards SHALL be automatically associated with the device's currently joined pool.

所有新创建的卡片应自动关联到设备当前加入的池。

**Rationale**: Simplifies user experience by eliminating manual pool selection.

**理由**：通过消除手动池选择简化用户体验。

### Draft Persistence
### 草稿持久化

Drafts SHALL be stored locally on the device and SHALL NOT sync to other devices.

草稿应存储在设备本地，不应同步到其他设备。

**Rationale**: Drafts are device-specific work-in-progress and should not interfere with other devices.

**理由**：草稿是设备特定的进行中工作，不应干扰其他设备。

### Soft Deletion
### 软删除

Deleted cards SHALL be marked with a deleted flag rather than physically removed from storage.

已删除的卡片应标记删除标志，而不是从存储中物理移除。

**Rationale**: Enables potential future recovery features and maintains data integrity for sync.

**理由**：支持潜在的未来恢复功能，并维护同步的数据完整性。

### Title Validation
### 标题验证

Card titles SHALL NOT be empty or contain only whitespace. Leading and trailing whitespace SHALL be trimmed.

卡片标题不应为空或仅包含空格。前导和尾随空格应被修剪。

**Rationale**: Ensures all cards have meaningful identifiers for user navigation.

**理由**：确保所有卡片都有有意义的标识符供用户导航。

### Tag Uniqueness
### 标签唯一性

A card SHALL NOT have duplicate tags. Tag comparison SHALL be case-sensitive.

卡片不应有重复标签。标签比较应区分大小写。

**Rationale**: Prevents confusion and maintains clean tag organization.

**理由**：防止混淆并维护清晰的标签组织。

### Auto-Save Timing
### 自动保存时机

The system SHALL trigger auto-save after 500 milliseconds of user inactivity during editing.

系统应在编辑期间用户无活动500毫秒后触发自动保存。

**Rationale**: Balances data safety with performance (avoids excessive save operations during rapid typing).

**理由**：平衡数据安全性和性能（避免快速输入期间过多的保存操作）。

---

## Test Coverage
## 测试覆盖

**Test File**: `test/features/card_management_test.dart`
**测试文件**: `test/features/card_management_test.dart`

**Feature Tests**:
**功能测试**:
- `it_should_create_card_with_title_and_content()` - Create card with full data
- 创建包含完整数据的卡片
- `it_should_create_card_with_title_only()` - Create card with empty content
- 创建仅包含标题的卡片
- `it_should_reject_card_without_title()` - Reject empty title
- 拒绝空标题
- `it_should_reject_creation_when_not_joined()` - Reject when no pool
- 未加入池时拒绝
- `it_should_display_card_details()` - View card details
- 查看卡片详情
- `it_should_display_collaboration_info()` - View collaboration info
- 查看协作信息
- `it_should_edit_card_title_and_content()` - Edit card
- 编辑卡片
- `it_should_auto_save_draft()` - Auto-save draft
- 自动保存草稿
- `it_should_restore_draft_on_reopen()` - Restore draft
- 重新打开时恢复草稿
- `it_should_discard_draft_on_save()` - Discard draft on save
- 保存时丢弃草稿
- `it_should_confirm_discard_changes()` - Confirm discard
- 确认丢弃
- `it_should_prevent_empty_title_save()` - Prevent empty title
- 防止空标题
- `it_should_add_tag_to_card()` - Add tag
- 添加标签
- `it_should_prevent_duplicate_tags()` - Prevent duplicate tags
- 防止重复标签
- `it_should_remove_tag_from_card()` - Remove tag
- 移除标签
- `it_should_delete_card_with_confirmation()` - Delete with confirmation
- 确认后删除
- `it_should_cancel_deletion()` - Cancel deletion
- 取消删除
- `it_should_soft_delete_card()` - Soft delete
- 软删除
- `it_should_share_card_as_text()` - Share card
- 分享卡片
- `it_should_use_inline_editing_on_desktop()` - Desktop inline editing
- 桌面端内联编辑
- `it_should_use_fullscreen_editing_on_mobile()` - Mobile fullscreen editing
- 移动端全屏编辑

**Acceptance Criteria**:
**验收标准**:
- [ ] All feature tests pass
- [ ] 所有功能测试通过
- [ ] Card creation works on all platforms
- [ ] 卡片创建在所有平台上工作
- [ ] Auto-save prevents data loss
- [ ] 自动保存防止数据丢失
- [ ] Tag management is intuitive
- [ ] 标签管理直观
- [ ] Deletion requires confirmation
- [ ] 删除需要确认
- [ ] Platform-specific editing modes work correctly
- [ ] 平台特定的编辑模式正确工作
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Domain Specs**:
**领域规格**:
- [../../domain/card/rules.md](../../domain/card/rules.md) - Card business rules
- 卡片业务规则
- [../../domain/pool/model.md](../../domain/pool/model.md) - Pool domain model
- 池领域模型

**Architecture Specs**:
**架构规格**:
- [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md) - Card storage implementation
- 卡片存储实现
- [../../architecture/sync/service.md](../../architecture/sync/service.md) - P2P sync service
- P2P 同步服务

**UI Specs** (to be created):
**UI规格**（待创建）:
- `../../ui/screens/mobile/card_detail_screen.md` - Card detail screen UI
- 卡片详情屏幕UI
- `../../ui/screens/mobile/card_editor_screen.md` - Card editor screen UI
- 卡片编辑器屏幕UI
- `../../ui/components/shared/note_card.md` - NoteCard component UI
- NoteCard组件UI

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23

**Authors**: CardMind Team
**作者**: CardMind Team
