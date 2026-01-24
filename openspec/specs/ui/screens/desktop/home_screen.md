# Home Screen Specification
# 主屏幕规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: Active

**Platform**: Desktop
**平台**: 桌面端

**Dependencies**: [card/model.md](../../../domain/card/model.md), [sync/protocol.md](../../../architecture/sync/service.md)
**依赖**: [card/model.md](../../../domain/card/model.md), [sync/protocol.md](../../../architecture/sync/service.md)

**Related Tests**: `test/screens/home_screen_desktop_test.dart`
**相关测试**: `test/screens/home_screen_desktop_test.dart`

---

## Overview
## 概述

This specification defines the desktop home screen that displays the user's card collection with search, filtering, and management capabilities optimized for desktop devices with multi-column layout.

本规格定义了桌面端主屏幕，显示用户的卡片集合及针对桌面设备优化的搜索、过滤和管理功能，采用多列布局。

---

## Requirement: Display card list with filtering and search
## 需求：显示带有过滤和搜索的卡片列表

The system SHALL provide a home screen that displays all user cards with search and filter capabilities.

系统应提供显示所有用户卡片的主屏幕，并提供搜索和过滤功能。

### Scenario: Display card list
### 场景：显示卡片列表

- **GIVEN**: user opens the app
- **前置条件**：用户打开应用
- **WHEN**: home screen loads
- **操作**：主屏幕加载
- **THEN**: the system SHALL display all cards in a multi-column grid or list layout
- **预期结果**：系统应以多列网格或列表布局显示所有卡片
- **AND**: show card titles, preview text, and metadata
- **并且**：显示卡片标题、预览文本和元数据

### Scenario: Search cards
### 场景：搜索卡片

- **GIVEN**: card list is displayed
- **前置条件**：卡片列表已显示
- **WHEN**: user enters text in the search bar
- **操作**：用户在搜索栏输入文本
- **THEN**: the system SHALL filter cards matching the search query in title or content
- **预期结果**：系统应过滤标题或内容中匹配搜索查询的卡片
- **AND**: update the display in real-time
- **并且**：实时更新显示

### Scenario: Filter by tags
### 场景：按标签过滤

- **GIVEN**: card list is displayed
- **前置条件**：卡片列表已显示
- **WHEN**: user selects tag filters
- **操作**：用户选择标签过滤器
- **THEN**: the system SHALL display only cards with the selected tags
- **预期结果**：系统应只显示具有选定标签的卡片

### Scenario: Empty state
### 场景：空状态

- **GIVEN**: user has no cards
- **前置条件**：用户没有卡片
- **WHEN**: home screen loads
- **操作**：主屏幕加载
- **THEN**: the system SHALL display an empty state with instructions to create first card
- **预期结果**：系统应显示空状态及创建第一张卡片的说明

---

## Requirement: Provide card creation action
## 需求：提供卡片创建操作

The system SHALL allow users to create new cards from the home screen.

系统应允许用户从主屏幕创建新卡片。

### Scenario: Create new card inline
### 场景：内联创建新卡片

- **GIVEN**: home screen is displayed
- **前置条件**：主屏幕已显示
- **WHEN**: user clicks the "New Card" button
- **操作**：用户点击"新建卡片"按钮
- **THEN**: the system SHALL add a new card inline in the list/grid
- **预期结果**：系统应在列表/网格中内联添加新卡片
- **AND**: focus the title field for immediate editing
- **并且**：聚焦标题字段以便立即编辑

---

## Requirement: Navigate to card detail or editor
## 需求：导航到卡片详情或编辑器

The system SHALL allow users to open cards for viewing or editing.

系统应允许用户打开卡片进行查看或编辑。

### Scenario: Open card in side panel
### 场景：在侧面板中打开卡片

- **GIVEN**: card list is displayed
- **前置条件**：卡片列表已显示
- **WHEN**: user clicks a card
- **操作**：用户点击卡片
- **THEN**: the system SHALL show card in the inline editor panel
- **预期结果**：系统应在内联编辑器面板中显示卡片
- **AND**: keep the card list visible in the layout
- **并且**：在布局中保持卡片列表可见

### Scenario: Quick actions via context menu
### 场景：通过上下文菜单快速操作

- **GIVEN**: card list is displayed
- **前置条件**：卡片列表已显示
- **WHEN**: user right-clicks a card
- **操作**：用户右键点击卡片
- **THEN**: the system SHALL show context menu with actions (edit, delete, share)
- **预期结果**：系统应显示包含操作的上下文菜单（编辑、删除、分享）

---

## Requirement: Display sync status
## 需求：显示同步状态

The system SHALL show synchronization status on the home screen.

系统应在主屏幕上显示同步状态。

### Scenario: Show sync indicator
### 场景：显示同步指示器

- **GIVEN**: home screen is displayed
- **前置条件**：主屏幕已显示
- **WHEN**: displaying home screen
- **操作**：显示主屏幕
- **THEN**: the system SHALL show current sync status in the toolbar or status area
- **预期结果**：系统应在工具栏或状态区域显示当前同步状态
- **AND**: display number of connected devices
- **并且**：显示已连接设备的数量

---

## Requirement: Support card selection and bulk actions
## 需求：支持卡片选择和批量操作

The system SHALL allow users to select multiple cards for bulk operations.

系统应允许用户选择多张卡片进行批量操作。

### Scenario: Enter selection mode
### 场景：进入选择模式

- **GIVEN**: card list is displayed
- **前置条件**：卡片列表已显示
- **WHEN**: user shift-clicks or ctrl-clicks cards
- **操作**：用户 Shift 点击或 Ctrl 点击卡片
- **THEN**: the system SHALL enter selection mode
- **预期结果**：系统应进入选择模式
- **AND**: show checkboxes on all cards
- **并且**：在所有卡片上显示复选框

### Scenario: Bulk delete cards
### 场景：批量删除卡片

- **GIVEN**: selection mode is active
- **前置条件**：选择模式已激活
- **WHEN**: user selects multiple cards and triggers delete action
- **操作**：用户选择多张卡片并触发删除操作
- **THEN**: the system SHALL show confirmation dialog
- **预期结果**：系统应显示确认对话框
- **AND**: delete all selected cards upon confirmation
- **并且**：确认后删除所有选定的卡片

---

## Desktop-Specific Patterns
## 桌面端特定模式

### Multi-Column Layout
### 多列布局

The system SHALL use a multi-column layout (two-column or three-column) based on window size.

系统应根据窗口大小使用多列布局（两列或三列）。

### Inline Editing
### 内联编辑

The system SHALL support inline editing of cards directly in the list without full-screen navigation.

系统应支持直接在列表中内联编辑卡片，无需全屏导航。

### Context Menus
### 上下文菜单

The system SHALL provide right-click context menus for quick access to card actions.

系统应提供右键上下文菜单以快速访问卡片操作。

### Keyboard Shortcuts
### 键盘快捷键

The system SHALL support keyboard shortcuts for common actions (Ctrl+N for new card, Delete for delete, etc.).

系统应支持常见操作的键盘快捷键（Ctrl+N 新建卡片、Delete 删除等）。

---

## Test Coverage
## 测试覆盖

**Test File**: `test/screens/home_screen_desktop_test.dart`
**测试文件**: `test/screens/home_screen_desktop_test.dart`

**Screen Tests**:
**屏幕测试**:
- `it_should_display_card_list()` - Display card list
- `it_should_display_card_list()` - 显示卡片列表
- `it_should_show_card_metadata()` - Show metadata
- `it_should_show_card_metadata()` - 显示元数据
- `it_should_search_cards()` - Search functionality
- `it_should_search_cards()` - 搜索功能
- `it_should_filter_by_tags()` - Tag filtering
- `it_should_filter_by_tags()` - 标签过滤
- `it_should_show_empty_state()` - Empty state
- `it_should_show_empty_state()` - 空状态
- `it_should_create_card_inline()` - Create inline
- `it_should_create_card_inline()` - 内联创建
- `it_should_open_card_in_side_panel()` - Open in panel
- `it_should_open_card_in_side_panel()` - 在面板中打开
- `it_should_show_context_menu()` - Context menu
- `it_should_show_context_menu()` - 上下文菜单
- `it_should_show_sync_status()` - Display sync status
- `it_should_show_sync_status()` - 显示同步状态
- `it_should_enter_selection_mode()` - Enter selection mode
- `it_should_enter_selection_mode()` - 进入选择模式
- `it_should_bulk_delete()` - Bulk delete
- `it_should_bulk_delete()` - 批量删除
- `it_should_support_keyboard_shortcuts()` - Keyboard shortcuts
- `it_should_support_keyboard_shortcuts()` - 键盘快捷键

**Acceptance Criteria**:
**验收标准**:
- [ ] All screen tests pass
- [ ] 所有屏幕测试通过
- [ ] Search and filtering work correctly
- [ ] 搜索和过滤正常工作
- [ ] Multi-column layout adapts to window size
- [ ] 多列布局适应窗口大小
- [ ] Inline editing is smooth
- [ ] 内联编辑流畅
- [ ] Context menus and keyboard shortcuts work
- [ ] 上下文菜单和键盘快捷键工作正常
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Related Specs**:
**相关规格**:
- [card/model.md](../../../domain/card/model.md) - Card domain model
- [card/model.md](../../../domain/card/model.md) - 卡片领域模型
- [card_list_item.md](../../components/desktop/card_list_item.md) - Card list item
- [card_list_item.md](../../components/desktop/card_list_item.md) - 卡片列表项
- [toolbar.md](../../components/desktop/toolbar.md) - Desktop toolbar
- [toolbar.md](../../components/desktop/toolbar.md) - 桌面端工具栏
- [context_menu.md](../../components/desktop/context_menu.md) - Context menu
- [context_menu.md](../../components/desktop/context_menu.md) - 上下文菜单
- [sync_status_indicator.md](../../components/shared/sync_status_indicator.md) - Sync status
- [sync_status_indicator.md](../../components/shared/sync_status_indicator.md) - 同步状态

---

**Last Updated**: 2026-01-24
**最后更新**: 2026-01-24

**Authors**: CardMind Team
**作者**: CardMind Team
