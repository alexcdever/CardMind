# Mobile UI Interaction Specification

## 📋 规格编号: SP-FLUT-011
**版本**: 1.0.0
**状态**: 已完成
**依赖**: 
- SP-FLUT-008 (主页交互规格)
- SP-ADAPT-004 (移动端 UI 模式规格)
- SP-CARD-004 (CardStore 规格)

---

## 1. 概述

### 1.1 目标
定义 CardMind 移动端（Android、iOS）的完整 UI 交互规范，确保：
- 触摸优先的交互设计
- 全屏沉浸式编辑体验
- 手势操作流畅自然
- 单手操作友好

### 1.2 适用平台
- Android
- iOS
- iPadOS（作为移动端处理）

### 1.3 核心交互模式
- **FAB 按钮**：快速创建入口
- **全屏编辑器**：沉浸式编辑体验
- **底部导航**：主要功能切换
- **手势操作**：滑动、长按等

---

## 2. 卡片创建流程

### Requirement: User can initiate card creation from FAB button

移动端 SHALL 使用浮动操作按钮（FAB）作为创建卡片的主要入口。

#### Scenario: FAB button is visible on home screen
- **GIVEN** user is on the home screen
- **WHEN** screen loads
- **THEN** system displays a FAB button at the bottom-right corner
- **AND** FAB uses primary color from theme
- **AND** FAB shows "+" icon

#### Scenario: FAB is accessible within thumb reach
- **GIVEN** user holds phone in one hand
- **WHEN** user is on home screen
- **THEN** FAB SHALL be positioned within comfortable thumb reach
- **AND** FAB SHALL have minimum 48x48 logical pixels touch target

#### Scenario: Tapping FAB opens fullscreen editor
- **GIVEN** user is on home screen
- **WHEN** user taps the FAB button
- **THEN** system creates a new card with empty title and content
- **AND** system opens fullscreen editor with slide-up animation
- **AND** title field receives focus automatically
- **AND** keyboard appears automatically

#### Scenario: FAB is accessible within 1 second
- **GIVEN** home screen is loading
- **WHEN** 1 second has passed
- **THEN** FAB button SHALL be interactive

---

### Requirement: Fullscreen editor provides immersive editing experience

移动端 SHALL 使用全屏编辑器，隐藏所有导航元素，提供沉浸式编辑体验。

#### Scenario: Editor occupies full screen
- **GIVEN** user opens card editor
- **WHEN** editor screen loads
- **THEN** editor SHALL occupy the entire screen
- **AND** bottom navigation bar SHALL be hidden
- **AND** status bar MAY be hidden (platform-dependent)

#### Scenario: Editor shows minimal UI chrome
- **GIVEN** user is in editor
- **WHEN** editing content
- **THEN** only app bar with "完成" button SHALL be visible
- **AND** no other UI elements SHALL distract from content

#### Scenario: Title field is focused on editor open
- **GIVEN** user opens editor for new card
- **WHEN** editor screen appears
- **THEN** title field SHALL have focus
- **AND** keyboard SHALL appear automatically
- **AND** cursor SHALL be at the beginning of title field

#### Scenario: Content field is below title field
- **GIVEN** user is in editor
- **WHEN** viewing the layout
- **THEN** content field SHALL be below title field
- **AND** both fields SHALL be full-width
- **AND** content field SHALL expand to fill available space

---

### Requirement: Mobile editor supports auto-save

移动端编辑器 SHALL 自动保存用户输入，避免数据丢失。

#### Scenario: Auto-save triggers after 500ms of inactivity
- **GIVEN** user is typing in editor
- **WHEN** user stops typing for 500ms
- **THEN** system SHALL call save API
- **AND** system SHALL show "自动保存中..." indicator

#### Scenario: Auto-save debounces rapid typing
- **GIVEN** user is typing continuously
- **WHEN** user types without 500ms pause
- **THEN** system SHALL NOT call save API
- **AND** system SHALL wait until 500ms after last keystroke

#### Scenario: Auto-save shows success indicator
- **GIVEN** auto-save completes successfully
- **WHEN** save operation finishes
- **THEN** system SHALL display "已保存" indicator for 2 seconds
- **AND** indicator SHALL fade out automatically

#### Scenario: Auto-save handles errors gracefully
- **GIVEN** auto-save fails
- **WHEN** save operation returns error
- **THEN** system SHALL display error message
- **AND** system SHALL keep editor open with content preserved
- **AND** system SHALL provide "重试" button

---

### Requirement: User can complete card creation manually

移动端 SHALL 提供"完成"按钮，允许用户手动保存并退出编辑器。

#### Scenario: Complete button is visible in app bar
- **GIVEN** user is in editor
- **WHEN** viewing the screen
- **THEN** "完成" button SHALL be visible in app bar
- **AND** button SHALL be on the right side

#### Scenario: Tapping complete saves and exits
- **GIVEN** user has entered title and content
- **WHEN** user taps "完成" button
- **THEN** system SHALL save the card
- **AND** system SHALL close fullscreen editor with slide-down animation
- **AND** system SHALL return to home screen
- **AND** new card SHALL appear at top of list

#### Scenario: Complete button is disabled when title is empty
- **GIVEN** title field is empty
- **WHEN** user views the complete button
- **THEN** button SHALL be disabled (grayed out)
- **AND** tapping button SHALL have no effect

#### Scenario: Complete button is enabled when title is not empty
- **GIVEN** title field has text
- **WHEN** user views the complete button
- **THEN** button SHALL be enabled
- **AND** tapping button SHALL save and exit

---

### Requirement: User can cancel card creation

移动端 SHALL 允许用户取消卡片创建并放弃更改。

#### Scenario: Back button is available in app bar
- **GIVEN** user is in editor
- **WHEN** viewing the screen
- **THEN** back button SHALL be visible in app bar
- **AND** button SHALL be on the left side

#### Scenario: Tapping back with unsaved changes shows confirmation
- **GIVEN** user has entered content
- **AND** content is not saved
- **WHEN** user taps back button
- **THEN** system SHALL display confirmation dialog "放弃更改？"
- **AND** dialog SHALL have "放弃" and "取消" buttons

#### Scenario: Confirming discard returns to home screen
- **GIVEN** discard confirmation dialog is shown
- **WHEN** user taps "放弃" button
- **THEN** system SHALL close editor without saving
- **AND** system SHALL return to home screen
- **AND** unsaved card SHALL NOT appear in list

#### Scenario: Canceling discard keeps editor open
- **GIVEN** discard confirmation dialog is shown
- **WHEN** user taps "取消" button
- **THEN** system SHALL close dialog
- **AND** system SHALL keep editor open with content preserved

#### Scenario: Back with no changes returns immediately
- **GIVEN** user has not entered any content
- **WHEN** user taps back button
- **THEN** system SHALL return to home screen immediately
- **AND** system SHALL NOT show confirmation dialog

#### Scenario: Android back gesture works
- **GIVEN** user is in editor on Android
- **WHEN** user performs back gesture (swipe from left edge)
- **THEN** system SHALL behave same as tapping back button

---

## 3. 卡片编辑流程

### Requirement: User can open card for editing by tapping

移动端 SHALL 允许用户通过点击卡片打开全屏编辑器。

#### Scenario: Tapping card opens fullscreen editor
- **GIVEN** user is on home screen
- **WHEN** user taps a card
- **THEN** system SHALL open fullscreen editor
- **AND** editor SHALL load with card's title and content
- **AND** cursor SHALL be at end of content field

#### Scenario: Editor loads within 300ms
- **GIVEN** user taps a card
- **WHEN** editor opens
- **THEN** editor SHALL be fully interactive within 300ms
- **AND** animation SHALL be smooth (60fps)

#### Scenario: Editing existing card preserves ID
- **GIVEN** user opens existing card for editing
- **WHEN** user saves changes
- **THEN** system SHALL update the same card
- **AND** system SHALL NOT create a new card

---

### Requirement: Mobile editor supports Markdown preview

移动端编辑器 SHALL 支持 Markdown 预览切换。

#### Scenario: Preview toggle button is available
- **GIVEN** user is in editor
- **WHEN** viewing the app bar
- **THEN** system SHALL display a preview toggle button
- **AND** button SHALL show eye icon

#### Scenario: Tapping preview shows rendered Markdown
- **GIVEN** user has entered Markdown content
- **WHEN** user taps preview button
- **THEN** system SHALL render Markdown to HTML
- **AND** system SHALL display rendered content
- **AND** system SHALL hide edit fields

#### Scenario: Tapping edit returns to edit mode
- **GIVEN** user is in preview mode
- **WHEN** user taps edit button
- **THEN** system SHALL return to edit mode
- **AND** system SHALL show edit fields
- **AND** cursor position SHALL be preserved

---

## 4. 底部导航

### Requirement: Mobile SHALL use bottom navigation bar

移动端 SHALL 使用底部导航栏进行主要功能切换。

#### Scenario: Bottom navigation has 3 tabs
- **GIVEN** user is on home screen
- **WHEN** viewing the screen
- **THEN** bottom navigation SHALL have 3 tabs
- **AND** tabs SHALL be: "笔记", "设备", "设置"

#### Scenario: Active tab is highlighted
- **GIVEN** user is on a tab
- **WHEN** viewing bottom navigation
- **THEN** active tab SHALL be highlighted with primary color
- **AND** inactive tabs SHALL use gray color

#### Scenario: Tapping tab switches content
- **GIVEN** user is on "笔记" tab
- **WHEN** user taps "设备" tab
- **THEN** system SHALL switch to device management view
- **AND** bottom navigation SHALL update active indicator
- **AND** transition SHALL be smooth

#### Scenario: Tab shows badge for notifications
- **GIVEN** there are unsynced cards
- **WHEN** viewing bottom navigation
- **THEN** "笔记" tab MAY show a badge with count
- **AND** badge SHALL be visible but not obtrusive

---

## 5. 手势交互

### Requirement: Mobile SHALL support swipe gestures

移动端 SHALL 支持滑动手势进行快速操作。

#### Scenario: Swipe left on card shows delete action
- **GIVEN** user is viewing card list
- **WHEN** user swipes left on a card
- **THEN** system SHALL reveal delete button
- **AND** card SHALL slide left to show button
- **AND** animation SHALL be smooth

#### Scenario: Swipe right on card dismisses delete action
- **GIVEN** delete button is revealed
- **WHEN** user swipes right on the card
- **THEN** system SHALL hide delete button
- **AND** card SHALL slide back to original position

#### Scenario: Tapping delete button removes card
- **GIVEN** delete button is revealed
- **WHEN** user taps delete button
- **THEN** system SHALL soft-delete the card
- **AND** card SHALL animate out of list
- **AND** system SHALL show "已删除" snackbar with undo option

---

### Requirement: Mobile SHALL support long-press gestures

移动端 SHALL 支持长按手势打开上下文菜单。

#### Scenario: Long-press on card shows context menu
- **GIVEN** user is viewing card list
- **WHEN** user long-presses on a card
- **THEN** system SHALL show context menu
- **AND** menu SHALL include: "编辑", "删除", "分享"
- **AND** menu SHALL appear near the touch point

#### Scenario: Context menu actions work correctly
- **GIVEN** context menu is shown
- **WHEN** user taps "编辑"
- **THEN** system SHALL open fullscreen editor

#### Scenario: Tapping outside dismisses context menu
- **GIVEN** context menu is shown
- **WHEN** user taps outside the menu
- **THEN** system SHALL dismiss the menu
- **AND** no action SHALL be performed

---

## 6. 搜索交互

### Requirement: Mobile search uses overlay mode

移动端搜索 SHALL 使用覆盖模式，提供专注的搜索体验。

#### Scenario: Tapping search icon opens search overlay
- **GIVEN** user is on home screen
- **WHEN** user taps search icon in app bar
- **THEN** system SHALL open search overlay
- **AND** search field SHALL have focus
- **AND** keyboard SHALL appear

#### Scenario: Search overlay covers main content
- **GIVEN** search overlay is open
- **WHEN** viewing the screen
- **THEN** search overlay SHALL cover the card list
- **AND** search results SHALL replace card list
- **AND** back button SHALL close search

#### Scenario: Search shows results as user types
- **GIVEN** user is in search overlay
- **WHEN** user types in search field
- **THEN** system SHALL filter cards in real-time
- **AND** results SHALL update with each keystroke
- **AND** no results SHALL show "未找到相关笔记"

#### Scenario: Tapping search result opens card
- **GIVEN** search results are displayed
- **WHEN** user taps a result
- **THEN** system SHALL close search overlay
- **AND** system SHALL open the card in fullscreen editor

---

## 7. 性能要求

### Requirement: Mobile interactions SHALL be responsive

移动端交互 SHALL 满足严格的性能要求，确保流畅体验。

#### Scenario: Screen transitions complete within 300ms
- **GIVEN** user triggers a navigation
- **WHEN** transition animation plays
- **THEN** animation SHALL complete within 300ms
- **AND** animation SHALL maintain 60fps

#### Scenario: Touch feedback is immediate
- **GIVEN** user taps a button
- **WHEN** touch event occurs
- **THEN** visual feedback SHALL appear within 100ms
- **AND** feedback SHALL be visible (ripple effect)

#### Scenario: List scrolling is smooth
- **GIVEN** user scrolls card list
- **WHEN** scrolling
- **THEN** scrolling SHALL maintain 60fps
- **AND** no frame drops SHALL occur

#### Scenario: Keyboard appears within 200ms
- **GIVEN** user opens editor
- **WHEN** editor loads
- **THEN** keyboard SHALL appear within 200ms
- **AND** layout SHALL adjust smoothly

---

## 8. 输入验证

### Requirement: Mobile editor validates input before save

移动端编辑器 SHALL 在保存前验证输入。

#### Scenario: Empty title prevents save
- **GIVEN** user attempts to save with empty title
- **WHEN** user taps "完成" button
- **THEN** system SHALL display error "标题不能为空"
- **AND** system SHALL keep editor open
- **AND** title field SHALL receive focus

#### Scenario: Title with only whitespace is invalid
- **GIVEN** user enters only spaces in title
- **WHEN** user attempts to save
- **THEN** system SHALL display error "标题不能为空"
- **AND** system SHALL trim whitespace

#### Scenario: Empty content is allowed
- **GIVEN** user enters title but no content
- **WHEN** user saves
- **THEN** system SHALL save the card successfully
- **AND** card SHALL appear in list with title only

#### Scenario: Title exceeds 200 characters
- **GIVEN** user enters title longer than 200 characters
- **WHEN** user attempts to save
- **THEN** system SHALL display error "标题不能超过 200 字符"
- **AND** system SHALL keep editor open

---

## 9. 错误处理

### Requirement: Mobile editor handles errors gracefully

移动端编辑器 SHALL 优雅处理错误，保护用户数据。

#### Scenario: Save error shows snackbar
- **GIVEN** save operation fails
- **WHEN** error occurs
- **THEN** system SHALL display snackbar with error message
- **AND** snackbar SHALL include "重试" button
- **AND** editor content SHALL be preserved

#### Scenario: Retry button attempts save again
- **GIVEN** save error snackbar is shown
- **WHEN** user taps "重试" button
- **THEN** system SHALL attempt to save again
- **AND** system SHALL show loading indicator

#### Scenario: Network error provides helpful message
- **GIVEN** save fails due to network error
- **WHEN** error occurs
- **THEN** system SHALL display "保存失败，请检查网络连接"
- **AND** system SHALL keep editor open

#### Scenario: Editor state is preserved on error
- **GIVEN** save fails
- **WHEN** error occurs
- **THEN** user's input (title and content) SHALL remain in editor
- **AND** cursor position SHALL be preserved
- **AND** keyboard state SHALL be preserved

---

## 10. 卡片列表交互

### Requirement: Mobile card list uses vertical scrolling

移动端卡片列表 SHALL 使用垂直滚动，优化单手操作。

#### Scenario: Cards are displayed in vertical list
- **GIVEN** user has multiple cards
- **WHEN** viewing home screen
- **THEN** cards SHALL be displayed in vertical list
- **AND** each card SHALL be full-width
- **AND** cards SHALL have 8px vertical spacing

#### Scenario: List supports infinite scroll
- **GIVEN** user has many cards
- **WHEN** user scrolls to bottom
- **THEN** system SHALL load more cards
- **AND** loading SHALL be seamless

#### Scenario: Pull to refresh updates card list
- **GIVEN** user is at top of card list
- **WHEN** user pulls down
- **THEN** system SHALL show refresh indicator
- **AND** system SHALL reload cards from API
- **AND** system SHALL update list with new data

---

## 11. 设备管理交互

### Requirement: Mobile device management uses dedicated tab

移动端设备管理 SHALL 使用独立标签页，避免干扰主要工作流。

#### Scenario: Device tab is accessible from bottom navigation
- **GIVEN** user is on home screen
- **WHEN** user taps "设备" tab
- **THEN** system SHALL switch to device management view
- **AND** view SHALL show current device and paired devices

#### Scenario: Device list is scrollable
- **GIVEN** user has many paired devices
- **WHEN** viewing device tab
- **THEN** device list SHALL be scrollable
- **AND** scrolling SHALL be smooth

#### Scenario: Tapping device shows details
- **GIVEN** user is on device tab
- **WHEN** user taps a device
- **THEN** system SHALL show device details
- **AND** details SHALL include: name, type, last seen, sync status

---

## 12. 设置交互

### Requirement: Mobile settings use dedicated tab

移动端设置 SHALL 使用独立标签页，提供清晰的设置界面。

#### Scenario: Settings tab is accessible from bottom navigation
- **GIVEN** user is on home screen
- **WHEN** user taps "设置" tab
- **THEN** system SHALL switch to settings view
- **AND** view SHALL show all available settings

#### Scenario: Settings use list layout
- **GIVEN** user is on settings tab
- **WHEN** viewing settings
- **THEN** settings SHALL be displayed in list format
- **AND** each setting SHALL have clear label and current value

#### Scenario: Theme toggle is available
- **GIVEN** user is on settings tab
- **WHEN** viewing settings
- **THEN** system SHALL show theme toggle (亮色/暗色)
- **AND** toggle SHALL reflect current theme

---

## 13. 测试覆盖

### Unit Tests
- `it_should_display_fab_button_on_home_screen()`
- `it_should_navigate_to_fullscreen_editor_when_fab_tapped()`
- `it_should_focus_title_field_on_editor_open()`
- `it_should_trigger_autosave_after_500ms_inactivity()`
- `it_should_debounce_autosave_during_rapid_typing()`
- `it_should_validate_empty_title()`
- `it_should_validate_title_length()`
- `it_should_allow_empty_content()`
- `it_should_disable_complete_button_when_title_empty()`
- `it_should_enable_complete_button_when_title_not_empty()`
- `it_should_show_discard_confirmation_on_back_with_changes()`
- `it_should_return_immediately_on_back_without_changes()`

### Widget Tests
- `it_should_render_fullscreen_editor()`
- `it_should_show_title_and_content_fields()`
- `it_should_show_complete_button_in_appbar()`
- `it_should_show_back_button_in_appbar()`
- `it_should_show_saving_indicator_during_save()`
- `it_should_show_success_indicator_after_save()`
- `it_should_show_error_snackbar_on_save_failure()`
- `it_should_show_bottom_navigation_with_3_tabs()`
- `it_should_highlight_active_tab()`
- `it_should_switch_content_on_tab_change()`

### Integration Tests
- `it_should_complete_card_creation_flow_within_30_seconds()`
- `it_should_save_card_to_rust_api()`
- `it_should_update_home_screen_after_creation()`
- `it_should_preserve_editor_state_on_error()`
- `it_should_retry_save_after_failure()`
- `it_should_handle_swipe_gestures_correctly()`
- `it_should_handle_long_press_gestures_correctly()`

---

## 14. 实施检查清单

- [x] FAB 按钮实现
- [x] 全屏编辑器实现
- [x] 自动保存机制
- [x] 输入验证
- [x] 错误处理
- [x] 底部导航栏
- [ ] 手势交互（滑动删除、长按菜单）
- [ ] Markdown 预览切换
- [ ] 搜索覆盖模式
- [x] 性能优化

---

## 15. 与其他规格的关系

### 依赖的规格
- **SP-ADAPT-004** (移动端 UI 模式规格): 定义移动端通用 UI 模式
- **SP-FLUT-008** (主页交互规格): 定义主页的通用交互
- **SP-CARD-004** (CardStore 规格): 定义卡片存储 API

### 被依赖的规格
- **SP-UI-004** (全屏编辑器 UI 规格): 实现本规格中的全屏编辑器
- **SP-UI-006** (移动端导航 UI 规格): 实现本规格中的底部导航

### 相关的规格
- **SP-FLUT-012** (桌面端 UI 交互规格): 桌面端对应规格
- **SP-FLUT-010** (同步反馈交互规格): 同步状态显示

---

**最后更新**: 2026-01-19
**作者**: CardMind Team
**状态**: 已完成

---

## Migration from SP-FLUT-009

本规格取代了 SP-FLUT-009 (卡片创建交互规格) 中的移动端部分。

### 主要变更
- ✅ 明确标注所有场景为"移动端专用"
- ✅ 添加底部导航交互规格
- ✅ 添加手势交互规格
- ✅ 添加搜索覆盖模式规格
- ✅ 移除桌面端相关场景（移至 SP-FLUT-012）

### 迁移指南
如果你正在查看 SP-FLUT-009，请：
- 移动端场景 → 查看本规格 (SP-FLUT-011)
- 桌面端场景 → 查看 SP-FLUT-012
