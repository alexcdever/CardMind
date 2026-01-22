# Home Screen Specification | 主屏幕规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active
**Dependencies** | **依赖**: [card_store.md](../../domain/card_store.md), [sync_protocol.md](../../domain/sync_protocol.md)
**Related Tests** | **相关测试**: `test/screens/home_screen_test.dart`

---

## Overview | 概述

This specification defines the home screen that displays the user's card collection with search, filtering, and management capabilities.

本规格定义了主屏幕，显示用户的卡片集合及搜索、过滤和管理功能。

---

## Requirement: Display card list with filtering and search | 需求：显示带有过滤和搜索的卡片列表

The system SHALL provide a home screen that displays all user cards with search and filter capabilities.

系统应提供显示所有用户卡片的主屏幕，并提供搜索和过滤功能。

### Scenario: Display card list | 场景：显示卡片列表

- **WHEN** home screen loads
- **操作**：主屏幕加载
- **THEN** the system SHALL display all cards in a list or grid layout
- **预期结果**：系统应以列表或网格布局显示所有卡片
- **AND** show card titles, preview text, and metadata
- **并且**：显示卡片标题、预览文本和元数据

### Scenario: Search cards | 场景：搜索卡片

- **WHEN** user enters text in the search bar
- **操作**：用户在搜索栏输入文本
- **THEN** the system SHALL filter cards matching the search query in title or content
- **预期结果**：系统应过滤标题或内容中匹配搜索查询的卡片
- **AND** update the display in real-time
- **并且**：实时更新显示

### Scenario: Filter by tags | 场景：按标签过滤

- **WHEN** user selects tag filters
- **操作**：用户选择标签过滤器
- **THEN** the system SHALL display only cards with the selected tags
- **预期结果**：系统应只显示具有选定标签的卡片

### Scenario: Empty state | 场景：空状态

- **WHEN** user has no cards
- **操作**：用户没有卡片
- **THEN** the system SHALL display an empty state with instructions to create first card
- **预期结果**：系统应显示空状态及创建第一张卡片的说明

---

## Requirement: Provide card creation action | 需求：提供卡片创建操作

The system SHALL allow users to create new cards from the home screen.

系统应允许用户从主屏幕创建新卡片。

### Scenario: Create new card (mobile) | 场景：创建新卡片（移动端）

- **WHEN** user taps the floating action button on mobile
- **操作**：用户点击移动端的浮动操作按钮
- **THEN** the system SHALL open the fullscreen editor for a new card
- **预期结果**：系统应打开新卡片的全屏编辑器

### Scenario: Create new card (desktop) | 场景：创建新卡片（桌面端）

- **WHEN** user clicks the "New Card" button on desktop
- **操作**：用户在桌面端点击"新建卡片"按钮
- **THEN** the system SHALL add a new card inline in the list/grid
- **预期结果**：系统应在列表/网格中内联添加新卡片
- **AND** focus the title field for immediate editing
- **并且**：聚焦标题字段以便立即编辑

---

## Requirement: Navigate to card detail or editor | 需求：导航到卡片详情或编辑器

The system SHALL allow users to open cards for viewing or editing.

系统应允许用户打开卡片进行查看或编辑。

### Scenario: Open card on mobile | 场景：在移动端打开卡片

- **WHEN** user taps a card on mobile
- **操作**：用户在移动端点击卡片
- **THEN** the system SHALL navigate to card detail screen
- **预期结果**：系统应导航到卡片详情屏幕
- **OR** open fullscreen editor depending on configuration
- **或者**：根据配置打开全屏编辑器

### Scenario: Open card on desktop | 场景：在桌面端打开卡片

- **WHEN** user clicks a card on desktop
- **操作**：用户在桌面端点击卡片
- **THEN** the system SHALL show card in the inline editor panel
- **预期结果**：系统应在内联编辑器面板中显示卡片
- **AND** keep the card list visible in the layout
- **并且**：在布局中保持卡片列表可见

---

## Requirement: Display sync status | 需求：显示同步状态

The system SHALL show synchronization status on the home screen.

系统应在主屏幕上显示同步状态。

### Scenario: Show sync indicator | 场景：显示同步指示器

- **WHEN** displaying home screen
- **操作**：显示主屏幕
- **THEN** the system SHALL show current sync status in the app bar or status area
- **预期结果**：系统应在应用栏或状态区域显示当前同步状态
- **AND** display number of connected devices
- **并且**：显示已连接设备的数量

---

## Requirement: Support card selection and bulk actions | 需求：支持卡片选择和批量操作

The system SHALL allow users to select multiple cards for bulk operations.

系统应允许用户选择多张卡片进行批量操作。

### Scenario: Enter selection mode | 场景：进入选择模式

- **WHEN** user long-presses a card on mobile OR shift-clicks on desktop
- **操作**：用户在移动端长按卡片或在桌面端 Shift 点击
- **THEN** the system SHALL enter selection mode
- **预期结果**：系统应进入选择模式
- **AND** show checkboxes on all cards
- **并且**：在所有卡片上显示复选框

### Scenario: Bulk delete cards | 场景：批量删除卡片

- **WHEN** user selects multiple cards and triggers delete action
- **操作**：用户选择多张卡片并触发删除操作
- **THEN** the system SHALL show confirmation dialog
- **预期结果**：系统应显示确认对话框
- **AND** delete all selected cards upon confirmation
- **并且**：确认后删除所有选定的卡片

---

## Test Coverage | 测试覆盖

**Test File** | **测试文件**: `test/screens/home_screen_test.dart`

**Screen Tests** | **屏幕测试**:
- `it_should_display_card_list()` - Display card list | 显示卡片列表
- `it_should_show_card_metadata()` - Show metadata | 显示元数据
- `it_should_search_cards()` - Search functionality | 搜索功能
- `it_should_filter_by_tags()` - Tag filtering | 标签过滤
- `it_should_show_empty_state()` - Empty state | 空状态
- `it_should_create_card_mobile()` - Create card (mobile) | 创建卡片（移动端）
- `it_should_create_card_desktop()` - Create card (desktop) | 创建卡片（桌面端）
- `it_should_open_card_mobile()` - Open card (mobile) | 打开卡片（移动端）
- `it_should_open_card_desktop()` - Open card (desktop) | 打开卡片（桌面端）
- `it_should_show_sync_status()` - Display sync status | 显示同步状态
- `it_should_enter_selection_mode()` - Enter selection mode | 进入选择模式
- `it_should_bulk_delete()` - Bulk delete | 批量删除

**Acceptance Criteria** | **验收标准**:
- [ ] All screen tests pass | 所有屏幕测试通过
- [ ] Search and filtering work correctly | 搜索和过滤正常工作
- [ ] Card creation flows are intuitive | 卡片创建流程直观
- [ ] Platform-specific behaviors work as expected | 平台特定行为符合预期
- [ ] Code review approved | 代码审查通过
- [ ] Documentation updated | 文档已更新

---

## Related Documents | 相关文档

**Related Specs** | **相关规格**:
- [card_store.md](../../domain/card_store.md) - Card storage | 卡片存储
- [card_list_item.md](../card_list/card_list_item.md) - Card list item | 卡片列表项
- [card_detail_screen.md](../card_detail/card_detail_screen.md) - Card detail screen | 卡片详情屏幕
- [fullscreen_editor.md](../card_editor/fullscreen_editor.md) - Fullscreen editor | 全屏编辑器
- [sync_status_indicator.md](../sync_feedback/sync_status_indicator.md) - Sync status | 同步状态

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
