# Desktop UI Interaction Specification

## 📋 规格编号: SP-FLUT-012
**版本**: 1.0.0
**状态**: 已完成
**依赖**: 
- SP-FLUT-008 (主页交互规格)
- SP-ADAPT-005 (桌面端 UI 模式规格)
- SP-CARD-004 (CardStore 规格)

---

## 1. 概述

### 1.1 目标
定义 CardMind 桌面端（macOS、Windows、Linux）的完整 UI 交互规范，确保：
- 鼠标和键盘优先的交互设计
- 高效的多任务工作流
- 充分利用大屏幕空间
- 专业的桌面应用体验

### 1.2 适用平台
- macOS
- Windows
- Linux

### 1.3 核心交互模式
- **工具栏按钮**：主要操作入口
- **内联编辑**：就地编辑，保持上下文
- **分栏布局**：多列显示，提高效率
- **键盘快捷键**：快速操作
- **右键菜单**：上下文操作

---

## 2. 卡片创建流程

### Requirement: Desktop SHALL use toolbar button for card creation

桌面端 SHALL 使用工具栏按钮作为创建卡片的主要入口，而不是 FAB。

#### Scenario: New Card button is visible in toolbar
- **GIVEN** user is on the home screen
- **WHEN** viewing the app bar
- **THEN** system SHALL display "新建笔记" button in toolbar
- **AND** button SHALL be on the right side of app bar
- **AND** button SHALL show "+" icon and text label

#### Scenario: Toolbar button has hover effect
- **GIVEN** user hovers over "新建笔记" button
- **WHEN** mouse enters button area
- **THEN** button SHALL show hover effect (background color change)
- **AND** cursor SHALL change to pointer

#### Scenario: Toolbar button shows tooltip
- **GIVEN** user hovers over "新建笔记" button
- **WHEN** mouse stays for 500ms
- **THEN** system SHALL show tooltip "新建笔记 (Cmd/Ctrl+N)"
- **AND** tooltip SHALL appear below button

#### Scenario: No FAB button on desktop
- **GIVEN** user is on desktop platform
- **WHEN** viewing the home screen
- **THEN** system SHALL NOT display floating action button
- **AND** only toolbar button SHALL be visible

---

### Requirement: Desktop card creation SHALL use inline editing

桌面端创建卡片 SHALL 自动进入内联编辑模式，无需导航到新页面。

#### Scenario: Clicking New Card creates card and enters edit mode
- **GIVEN** user clicks "新建笔记" button
- **WHEN** button is clicked
- **THEN** system SHALL create a new card with empty title and content
- **AND** new card SHALL appear at top of grid
- **AND** card SHALL automatically enter inline editing mode
- **AND** title field SHALL receive focus
- **AND** cursor SHALL be at beginning of title field

#### Scenario: New card is visible in grid immediately
- **GIVEN** user creates a new card
- **WHEN** card is created
- **THEN** card SHALL appear at top-left of grid
- **AND** card SHALL be highlighted with elevated shadow
- **AND** surrounding cards SHALL remain visible
- **AND** no navigation SHALL occur

#### Scenario: Card list remains visible during editing
- **GIVEN** user is editing a new card
- **WHEN** in edit mode
- **THEN** other cards in grid SHALL remain visible
- **AND** user SHALL be able to see context
- **AND** left sidebar SHALL remain visible

#### Scenario: Title field is focused automatically
- **GIVEN** new card enters edit mode
- **WHEN** edit mode activates
- **THEN** title field SHALL have focus
- **AND** field SHALL show blinking cursor
- **AND** field SHALL have visible focus indicator (border)

---

### Requirement: Desktop inline editor provides efficient editing

桌面端内联编辑器 SHALL 提供高效的编辑体验，优化键盘操作。

#### Scenario: Title and content fields are stacked vertically
- **GIVEN** card is in edit mode
- **WHEN** viewing the card
- **THEN** title field SHALL be at top
- **AND** content field SHALL be below title
- **AND** both fields SHALL be full-width within card

#### Scenario: Tab key moves between fields
- **GIVEN** cursor is in title field
- **WHEN** user presses Tab key
- **THEN** focus SHALL move to content field
- **AND** cursor SHALL be at beginning of content

#### Scenario: Shift+Tab moves backwards between fields
- **GIVEN** cursor is in content field
- **WHEN** user presses Shift+Tab
- **THEN** focus SHALL move back to title field
- **AND** cursor SHALL be at end of title

#### Scenario: Content field expands to fit text
- **GIVEN** user is typing in content field
- **WHEN** text exceeds visible area
- **THEN** field SHALL expand vertically
- **AND** card height SHALL increase
- **AND** expansion SHALL be smooth

---

### Requirement: Desktop editor supports keyboard shortcuts

桌面端编辑器 SHALL 支持键盘快捷键，提高操作效率。

#### Scenario: Cmd/Ctrl+N creates new card
- **GIVEN** user is on home screen
- **WHEN** user presses Cmd+N (macOS) or Ctrl+N (Windows/Linux)
- **THEN** system SHALL create new card
- **AND** card SHALL enter edit mode
- **AND** title field SHALL receive focus

#### Scenario: Cmd/Ctrl+Enter saves and exits edit mode
- **GIVEN** user is editing a card
- **WHEN** user presses Cmd+Enter (macOS) or Ctrl+Enter (Windows/Linux)
- **THEN** system SHALL save the card
- **AND** system SHALL exit edit mode
- **AND** card SHALL show saved content

#### Scenario: Escape cancels edit mode
- **GIVEN** user is editing a card
- **WHEN** user presses Escape key
- **THEN** system SHALL exit edit mode without saving
- **AND** if card is new and empty, system SHALL delete it
- **AND** if card has content, system SHALL revert changes

#### Scenario: Escape on new empty card deletes it
- **GIVEN** user created new card but entered no content
- **WHEN** user presses Escape
- **THEN** system SHALL delete the empty card
- **AND** card SHALL animate out of grid
- **AND** no confirmation dialog SHALL appear

#### Scenario: Escape on edited card shows confirmation
- **GIVEN** user edited existing card
- **AND** changes are not saved
- **WHEN** user presses Escape
- **THEN** system SHALL show confirmation dialog "放弃更改？"
- **AND** dialog SHALL have "放弃" and "取消" buttons

---

### Requirement: Desktop editor supports auto-save

桌面端编辑器 SHALL 自动保存用户输入，避免数据丢失。

#### Scenario: Auto-save triggers after 500ms of inactivity
- **GIVEN** user is typing in editor
- **WHEN** user stops typing for 500ms
- **THEN** system SHALL call save API
- **AND** system SHALL show subtle "保存中..." indicator

#### Scenario: Auto-save indicator is non-intrusive
- **GIVEN** auto-save is in progress
- **WHEN** indicator is shown
- **THEN** indicator SHALL be small and subtle
- **AND** indicator SHALL appear in card footer
- **AND** indicator SHALL NOT block content

#### Scenario: Auto-save shows success indicator briefly
- **GIVEN** auto-save completes successfully
- **WHEN** save operation finishes
- **THEN** system SHALL show "已保存" indicator for 1 second
- **AND** indicator SHALL fade out smoothly

#### Scenario: Auto-save handles errors gracefully
- **GIVEN** auto-save fails
- **WHEN** save operation returns error
- **THEN** system SHALL show error icon in card footer
- **AND** hovering over icon SHALL show error message
- **AND** clicking icon SHALL retry save

---

### Requirement: Desktop editor provides save and cancel buttons

桌面端编辑器 SHALL 提供明确的保存和取消按钮。

#### Scenario: Save and cancel buttons appear in edit mode
- **GIVEN** card is in edit mode
- **WHEN** viewing the card
- **THEN** system SHALL show checkmark (save) button
- **AND** system SHALL show X (cancel) button
- **AND** buttons SHALL be in top-right corner of card

#### Scenario: Save button is green
- **GIVEN** card is in edit mode
- **WHEN** viewing save button
- **THEN** button SHALL have green color
- **AND** button SHALL show checkmark icon

#### Scenario: Cancel button is red
- **GIVEN** card is in edit mode
- **WHEN** viewing cancel button
- **THEN** button SHALL have red color
- **AND** button SHALL show X icon

#### Scenario: Clicking save button saves and exits
- **GIVEN** user has entered content
- **WHEN** user clicks save button
- **THEN** system SHALL save the card
- **AND** system SHALL exit edit mode
- **AND** card SHALL show saved content

#### Scenario: Clicking cancel button discards changes
- **GIVEN** user has entered content
- **WHEN** user clicks cancel button
- **THEN** system SHALL show confirmation dialog (if changes exist)
- **AND** confirming SHALL discard changes and exit edit mode

---

## 3. 卡片编辑流程

### Requirement: Desktop SHALL use right-click menu for card actions

桌面端 SHALL 使用右键菜单提供卡片操作，符合桌面应用习惯。

#### Scenario: Right-clicking card shows context menu
- **GIVEN** user is viewing card grid
- **WHEN** user right-clicks on a card
- **THEN** system SHALL show context menu
- **AND** menu SHALL appear near mouse cursor
- **AND** menu SHALL include: "编辑", "删除", "复制", "分享"

#### Scenario: Context menu Edit option enters edit mode
- **GIVEN** context menu is shown
- **WHEN** user clicks "编辑" option
- **THEN** card SHALL enter inline edit mode
- **AND** title field SHALL receive focus

#### Scenario: Context menu Delete option removes card
- **GIVEN** context menu is shown
- **WHEN** user clicks "删除" option
- **THEN** system SHALL show confirmation dialog
- **AND** confirming SHALL soft-delete the card

#### Scenario: Clicking outside dismisses context menu
- **GIVEN** context menu is shown
- **WHEN** user clicks outside menu
- **THEN** menu SHALL close
- **AND** no action SHALL be performed

---

### Requirement: Desktop SHALL support hover effects

桌面端 SHALL 使用悬停效果提供视觉反馈和操作提示。

#### Scenario: Hovering card shows action buttons
- **GIVEN** user hovers over a card
- **WHEN** mouse enters card area
- **THEN** system SHALL show action buttons (edit, delete)
- **AND** buttons SHALL fade in smoothly
- **AND** card SHALL show subtle elevation increase

#### Scenario: Hovering edit button shows tooltip
- **GIVEN** action buttons are visible
- **WHEN** user hovers over edit button
- **THEN** system SHALL show tooltip "编辑 (右键菜单)"
- **AND** tooltip SHALL appear after 500ms

#### Scenario: Leaving card hides action buttons
- **GIVEN** action buttons are visible
- **WHEN** mouse leaves card area
- **THEN** buttons SHALL fade out smoothly
- **AND** card SHALL return to normal elevation

---

### Requirement: Desktop editing preserves context

桌面端编辑 SHALL 保持用户的工作上下文，不打断工作流。

#### Scenario: Editing card does not hide other cards
- **GIVEN** user enters edit mode on a card
- **WHEN** editing
- **THEN** other cards SHALL remain visible in grid
- **AND** user SHALL be able to reference other cards
- **AND** grid layout SHALL not change

#### Scenario: Multiple cards cannot be edited simultaneously
- **GIVEN** user is editing card A
- **WHEN** user clicks edit on card B
- **THEN** system SHALL save card A automatically
- **AND** card A SHALL exit edit mode
- **AND** card B SHALL enter edit mode

#### Scenario: Clicking outside card saves and exits
- **GIVEN** user is editing a card
- **WHEN** user clicks outside the card
- **THEN** system SHALL save the card
- **AND** system SHALL exit edit mode
- **AND** no confirmation SHALL be needed

---

## 4. 布局和导航

### Requirement: Desktop SHALL use three-column layout

桌面端 SHALL 使用三栏布局，充分利用宽屏空间。

#### Scenario: Left column shows device management
- **GIVEN** user is on desktop
- **WHEN** viewing home screen
- **THEN** left column SHALL show device manager panel
- **AND** column SHALL be 320px wide
- **AND** column SHALL be scrollable

#### Scenario: Middle column is reserved for future use
- **GIVEN** user is on desktop
- **WHEN** viewing home screen
- **THEN** middle column SHALL be empty (reserved)
- **AND** column SHALL expand to fill available space

#### Scenario: Right column shows card grid
- **GIVEN** user is on desktop
- **WHEN** viewing home screen
- **THEN** right column SHALL show card grid
- **AND** column SHALL use remaining width
- **AND** column SHALL be scrollable

#### Scenario: Columns are resizable
- **GIVEN** user is on desktop
- **WHEN** user drags column divider
- **THEN** columns SHALL resize
- **AND** resize SHALL be smooth
- **AND** minimum widths SHALL be enforced

---

### Requirement: Desktop SHALL use card grid layout

桌面端 SHALL 使用网格布局显示卡片，优化空间利用。

#### Scenario: Cards are displayed in grid
- **GIVEN** user has multiple cards
- **WHEN** viewing home screen
- **THEN** cards SHALL be displayed in grid
- **AND** grid SHALL have multiple columns
- **AND** column count SHALL adapt to window width

#### Scenario: Grid uses max cross-axis extent
- **GIVEN** cards are in grid
- **WHEN** viewing layout
- **THEN** each card SHALL have max width of 400px
- **AND** cards SHALL maintain aspect ratio of 1.2
- **AND** spacing SHALL be 16px

#### Scenario: Grid scrolls vertically
- **GIVEN** user has many cards
- **WHEN** cards exceed viewport height
- **THEN** grid SHALL scroll vertically
- **AND** scrolling SHALL be smooth
- **AND** scroll bar SHALL be visible

---

### Requirement: Desktop SHALL NOT use bottom navigation

桌面端 SHALL NOT 使用底部导航栏，所有功能通过侧边栏和工具栏访问。

#### Scenario: No bottom navigation bar on desktop
- **GIVEN** user is on desktop
- **WHEN** viewing home screen
- **THEN** system SHALL NOT show bottom navigation bar
- **AND** all navigation SHALL be in left sidebar

#### Scenario: Settings are in left sidebar
- **GIVEN** user is on desktop
- **WHEN** viewing home screen
- **THEN** settings panel SHALL be in left sidebar
- **AND** settings SHALL be below device manager

---

## 5. 搜索交互

### Requirement: Desktop search uses inline filtering

桌面端搜索 SHALL 使用内联过滤，保持卡片网格可见。

#### Scenario: Search field is in toolbar
- **GIVEN** user is on home screen
- **WHEN** viewing toolbar
- **THEN** search field SHALL be visible in toolbar
- **AND** field SHALL have search icon
- **AND** field SHALL show placeholder "搜索笔记标题、内容或标签..."

#### Scenario: Search filters cards in real-time
- **GIVEN** user types in search field
- **WHEN** user enters text
- **THEN** card grid SHALL filter in real-time
- **AND** only matching cards SHALL be visible
- **AND** filtering SHALL be smooth (no flicker)

#### Scenario: Search highlights matches
- **GIVEN** search results are shown
- **WHEN** viewing cards
- **THEN** matching text SHALL be highlighted
- **AND** highlight SHALL use primary color

#### Scenario: Clearing search shows all cards
- **GIVEN** search is active
- **WHEN** user clears search field
- **THEN** all cards SHALL be visible again
- **AND** transition SHALL be smooth

#### Scenario: Cmd/Ctrl+F focuses search field
- **GIVEN** user is on home screen
- **WHEN** user presses Cmd+F (macOS) or Ctrl+F (Windows/Linux)
- **THEN** search field SHALL receive focus
- **AND** any existing text SHALL be selected

---

## 6. 键盘快捷键

### Requirement: Desktop SHALL support comprehensive keyboard shortcuts

桌面端 SHALL 支持完整的键盘快捷键，提高专业用户效率。

#### Scenario: Cmd/Ctrl+N creates new card
- **GIVEN** user is on home screen
- **WHEN** user presses Cmd/Ctrl+N
- **THEN** system SHALL create new card and enter edit mode

#### Scenario: Cmd/Ctrl+F focuses search
- **GIVEN** user is on home screen
- **WHEN** user presses Cmd/Ctrl+F
- **THEN** search field SHALL receive focus

#### Scenario: Cmd/Ctrl+Enter saves current card
- **GIVEN** user is editing a card
- **WHEN** user presses Cmd/Ctrl+Enter
- **THEN** system SHALL save and exit edit mode

#### Scenario: Escape cancels current operation
- **GIVEN** user is editing a card
- **WHEN** user presses Escape
- **THEN** system SHALL cancel and exit edit mode

#### Scenario: Cmd/Ctrl+, opens settings
- **GIVEN** user is on home screen
- **WHEN** user presses Cmd+, (macOS) or Ctrl+, (Windows/Linux)
- **THEN** system SHALL scroll to settings panel

#### Scenario: Keyboard shortcuts are shown in tooltips
- **GIVEN** user hovers over a button
- **WHEN** tooltip appears
- **THEN** tooltip SHALL include keyboard shortcut
- **AND** shortcut SHALL use platform-appropriate notation

---

## 7. 拖拽交互

### Requirement: Desktop SHALL support drag and drop

桌面端 SHALL 支持拖拽操作，提供直观的卡片管理。

#### Scenario: Cards can be dragged to reorder
- **GIVEN** user clicks and holds on a card
- **WHEN** user drags the card
- **THEN** card SHALL follow mouse cursor
- **AND** card SHALL show elevated shadow
- **AND** other cards SHALL shift to make space

#### Scenario: Dropping card reorders it
- **GIVEN** user is dragging a card
- **WHEN** user releases mouse button
- **THEN** card SHALL be placed in new position
- **AND** order SHALL be saved
- **AND** animation SHALL be smooth

#### Scenario: Drag shows visual feedback
- **GIVEN** user is dragging a card
- **WHEN** dragging over valid drop zone
- **THEN** drop zone SHALL be highlighted
- **AND** cursor SHALL show move icon

---

## 8. 窗口管理

### Requirement: Desktop SHALL support window resizing

桌面端 SHALL 优雅处理窗口大小调整。

#### Scenario: Layout adapts to window width
- **GIVEN** user resizes window
- **WHEN** window width changes
- **THEN** card grid SHALL adapt column count
- **AND** layout SHALL remain usable
- **AND** no content SHALL be cut off

#### Scenario: Minimum window size is enforced
- **GIVEN** user tries to resize window very small
- **WHEN** window reaches 800x600 pixels
- **THEN** window SHALL not shrink further
- **AND** content SHALL remain readable

#### Scenario: Window size is persisted
- **GIVEN** user resizes window
- **WHEN** user closes and reopens app
- **THEN** window SHALL restore previous size
- **AND** window SHALL restore previous position

---

## 9. 性能要求

### Requirement: Desktop interactions SHALL be responsive

桌面端交互 SHALL 满足性能要求，确保流畅体验。

#### Scenario: Hover effects appear within 50ms
- **GIVEN** user hovers over interactive element
- **WHEN** mouse enters element
- **THEN** hover effect SHALL appear within 50ms
- **AND** effect SHALL be smooth

#### Scenario: Edit mode activates within 100ms
- **GIVEN** user clicks edit button
- **WHEN** button is clicked
- **THEN** edit mode SHALL activate within 100ms
- **AND** focus SHALL be set immediately

#### Scenario: Search filtering completes within 200ms
- **GIVEN** user types in search field
- **WHEN** user enters character
- **THEN** filtering SHALL complete within 200ms
- **AND** UI SHALL remain responsive

#### Scenario: Grid scrolling is smooth
- **GIVEN** user scrolls card grid
- **WHEN** scrolling
- **THEN** scrolling SHALL maintain 60fps
- **AND** no frame drops SHALL occur

---

## 10. 输入验证

### Requirement: Desktop editor validates input before save

桌面端编辑器 SHALL 在保存前验证输入。

#### Scenario: Empty title prevents save
- **GIVEN** user attempts to save with empty title
- **WHEN** user clicks save or presses Cmd/Ctrl+Enter
- **THEN** system SHALL show inline error "标题不能为空"
- **AND** title field SHALL be highlighted with red border
- **AND** title field SHALL receive focus

#### Scenario: Title with only whitespace is invalid
- **GIVEN** user enters only spaces in title
- **WHEN** user attempts to save
- **THEN** system SHALL show error "标题不能为空"
- **AND** system SHALL trim whitespace

#### Scenario: Empty content is allowed
- **GIVEN** user enters title but no content
- **WHEN** user saves
- **THEN** system SHALL save the card successfully

#### Scenario: Title exceeds 200 characters
- **GIVEN** user enters title longer than 200 characters
- **WHEN** user attempts to save
- **THEN** system SHALL show error "标题不能超过 200 字符"
- **AND** title field SHALL be highlighted

---

## 11. 错误处理

### Requirement: Desktop editor handles errors gracefully

桌面端编辑器 SHALL 优雅处理错误，保护用户数据。

#### Scenario: Save error shows inline message
- **GIVEN** save operation fails
- **WHEN** error occurs
- **THEN** system SHALL show error icon in card footer
- **AND** error message SHALL appear on hover
- **AND** editor content SHALL be preserved

#### Scenario: Error icon provides retry action
- **GIVEN** save error occurred
- **WHEN** user clicks error icon
- **THEN** system SHALL attempt to save again
- **AND** system SHALL show loading indicator

#### Scenario: Network error provides helpful message
- **GIVEN** save fails due to network error
- **WHEN** error occurs
- **THEN** error message SHALL say "保存失败，请检查网络连接"
- **AND** retry option SHALL be available

#### Scenario: Editor state is preserved on error
- **GIVEN** save fails
- **WHEN** error occurs
- **THEN** user's input SHALL remain in editor
- **AND** cursor position SHALL be preserved
- **AND** edit mode SHALL remain active

---

## 12. 辅助功能

### Requirement: Desktop UI SHALL support accessibility

桌面端 SHALL 支持辅助功能，确保可访问性。

#### Scenario: All interactive elements are keyboard accessible
- **GIVEN** user navigates with keyboard only
- **WHEN** user presses Tab
- **THEN** focus SHALL move to next interactive element
- **AND** focus indicator SHALL be clearly visible

#### Scenario: Screen reader announces actions
- **GIVEN** user uses screen reader
- **WHEN** user interacts with elements
- **THEN** screen reader SHALL announce element type and state
- **AND** announcements SHALL be clear and concise

#### Scenario: High contrast mode is supported
- **GIVEN** user enables high contrast mode
- **WHEN** viewing UI
- **THEN** all elements SHALL have sufficient contrast
- **AND** UI SHALL remain usable

---

## 13. 测试覆盖

### Unit Tests
- `it_should_display_toolbar_button_on_desktop()`
- `it_should_not_display_fab_on_desktop()`
- `it_should_create_card_and_enter_edit_mode_on_button_click()`
- `it_should_focus_title_field_automatically()`
- `it_should_save_on_ctrl_enter()`
- `it_should_cancel_on_escape()`
- `it_should_delete_empty_card_on_escape()`
- `it_should_show_confirmation_on_escape_with_changes()`
- `it_should_trigger_autosave_after_500ms()`
- `it_should_validate_empty_title()`
- `it_should_validate_title_length()`

### Widget Tests
- `it_should_render_inline_editor_in_card()`
- `it_should_show_save_and_cancel_buttons()`
- `it_should_show_three_column_layout()`
- `it_should_show_card_grid_in_right_column()`
- `it_should_show_device_manager_in_left_column()`
- `it_should_show_hover_effects_on_cards()`
- `it_should_show_context_menu_on_right_click()`
- `it_should_highlight_search_matches()`

### Integration Tests
- `it_should_complete_card_creation_with_keyboard_only()`
- `it_should_save_card_to_rust_api()`
- `it_should_preserve_context_during_editing()`
- `it_should_handle_window_resize_gracefully()`
- `it_should_support_drag_and_drop_reordering()`
- `it_should_filter_cards_in_realtime_on_search()`

---

## 14. 实施检查清单

- [x] 工具栏按钮实现
- [x] 内联编辑模式
- [x] 自动保存机制
- [x] 键盘快捷键（部分）
- [x] 三栏布局
- [x] 卡片网格
- [ ] 右键菜单
- [ ] 悬停效果
- [ ] 拖拽排序
- [ ] 窗口大小持久化
- [ ] 完整的键盘快捷键
- [ ] 辅助功能支持

---

## 15. 与其他规格的关系

### 依赖的规格
- **SP-ADAPT-005** (桌面端 UI 模式规格): 定义桌面端通用 UI 模式
- **SP-FLUT-008** (主页交互规格): 定义主页的通用交互
- **SP-CARD-004** (CardStore 规格): 定义卡片存储 API

### 被依赖的规格
- **SP-UI-002** (卡片编辑器 UI 规格): 实现本规格中的内联编辑器
- **SP-UI-003** (设备管理面板 UI 规格): 实现本规格中的设备管理

### 相关的规格
- **SP-FLUT-011** (移动端 UI 交互规格): 移动端对应规格
- **SP-FLUT-010** (同步反馈交互规格): 同步状态显示
- **SP-ADAPT-003** (键盘快捷键规格): 详细的快捷键定义

---

**最后更新**: 2026-01-19
**作者**: CardMind Team
**状态**: 已完成

---

## Migration from SP-FLUT-009

本规格取代了 SP-FLUT-009 (卡片创建交互规格) 中的桌面端部分。

### 主要变更
- ✅ 明确标注所有场景为"桌面端专用"
- ✅ 添加内联编辑自动激活规格（**核心改进**）
- ✅ 添加键盘快捷键规格
- ✅ 添加右键菜单规格
- ✅ 添加悬停效果规格
- ✅ 添加拖拽交互规格
- ✅ 移除移动端相关场景（移至 SP-FLUT-011）

### 核心改进：自动进入编辑模式

**旧行为（SP-FLUT-009）**：
```
1. 用户点击"新建笔记"
2. 创建空白卡片
3. 卡片出现在网格中
4. 用户需要手动点击"编辑"按钮
5. 才能开始输入内容
```

**新行为（SP-FLUT-012）**：
```
1. 用户点击"新建笔记"
2. 创建空白卡片
3. 卡片出现在网格中
4. ✅ 自动进入内联编辑模式
5. ✅ 标题字段自动聚焦
6. 用户直接开始输入
```

### 迁移指南
如果你正在查看 SP-FLUT-009，请：
- 桌面端场景 → 查看本规格 (SP-FLUT-012)
- 移动端场景 → 查看 SP-FLUT-011
