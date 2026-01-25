# Note Card Component Specification | 笔记卡片组件规格

**Version** | **版本**: 2.0.0
**Status** | **状态**: Active
**Dependencies** | **依赖**: [Card Model](../../architecture/data/card.md)
**Related Tests** | **相关测试**: `test/widgets/note_card_test.dart`, `test/specs/note_card_component_spec_test.dart`

---

## Overview | 概述

This specification defines the Note Card component, a reusable widget for displaying individual cards in list and grid views. The component reuses the existing Card data model from the Rust bridge layer and provides platform-specific interactions for both desktop and mobile platforms.

本规格定义了笔记卡片组件，这是一个可复用的 Widget，用于在列表和网格视图中显示单个卡片。该组件复用 Rust 桥接层的现有 Card 数据模型，并为桌面端和移动端提供平台特定的交互。

**Key Features** | **核心特性**:
- Display card content (title, content preview, metadata)
- Platform-specific interactions (desktop: click + right-click, mobile: tap + long-press)
- Context menu operations (edit, delete, share)
- Visual feedback (hover, press states)
- Accessibility support
- Performance optimization

---

## Requirement: Display card content | 需求：显示卡片内容

The system SHALL display card information including title, content preview, and metadata.

系统应显示卡片信息，包括标题、内容预览和元数据。

### Scenario: Display card title | 场景：显示卡片标题

- **WHEN** rendering a note card with a non-empty title
- **操作**：渲染带有非空标题的笔记卡片
- **THEN** the system SHALL display the card title prominently at the top
- **预期结果**：系统应在顶部突出显示卡片标题
- **AND** apply appropriate text styling (font size, weight, color)
- **并且**：应用适当的文本样式（字体大小、粗细、颜色）

### Scenario: Display content preview | 场景：显示内容预览

- **WHEN** rendering a note card with content
- **操作**：渲染带有内容的笔记卡片
- **THEN** the system SHALL display a preview of the card content
- **预期结果**：系统应显示卡片内容的预览
- **AND** truncate long content with ellipsis
- **并且**：使用省略号截断长内容
- **AND** limit preview to a reasonable number of lines
- **并且**：将预览限制为合理的行数

### Scenario: Display update time | 场景：显示更新时间

- **WHEN** rendering a note card
- **操作**：渲染笔记卡片
- **THEN** the system SHALL display the last update timestamp
- **预期结果**：系统应显示最后更新时间戳
- **AND** format time as relative time for recent updates (e.g., "2 hours ago")
- **并且**：对于最近的更新，将时间格式化为相对时间（例如"2小时前"）
- **AND** format time as absolute date for older updates (e.g., "2026-01-20")
- **并且**：对于较旧的更新，将时间格式化为绝对日期（例如"2026-01-20"）

### Scenario: Display tags | 场景：显示标签

- **WHEN** rendering a note card with tags
- **操作**：渲染带有标签的笔记卡片
- **THEN** the system SHALL display all associated tags
- **预期结果**：系统应显示所有关联的标签
- **AND** render each tag as a chip or badge
- **并且**：将每个标签渲染为芯片或徽章
- **AND** apply distinct visual styling to tags
- **并且**：为标签应用独特的视觉样式

---

## Requirement: Handle empty card content | 需求：处理空卡片内容

The system SHALL gracefully handle cards with missing or empty content.

系统应优雅地处理缺失或空内容的卡片。

### Scenario: Handle empty title | 场景：处理空标题

- **WHEN** rendering a note card with an empty title
- **操作**：渲染带有空标题的笔记卡片
- **THEN** the system SHALL display a placeholder text (e.g., "Untitled")
- **预期结果**：系统应显示占位符文本（例如"无标题"）
- **AND** apply distinct styling to indicate placeholder state
- **并且**：应用独特的样式来指示占位符状态

### Scenario: Handle empty content | 场景：处理空内容

- **WHEN** rendering a note card with empty content
- **操作**：渲染带有空内容的笔记卡片
- **THEN** the system SHALL display a placeholder text (e.g., "No content")
- **预期结果**：系统应显示占位符文本（例如"无内容"）
- **AND** maintain consistent card height and layout
- **并且**：保持一致的卡片高度和布局

### Scenario: Handle empty tags | 场景：处理空标签

- **WHEN** rendering a note card with no tags
- **操作**：渲染没有标签的笔记卡片
- **THEN** the system SHALL hide the tags section
- **预期结果**：系统应隐藏标签部分
- **AND** adjust layout to remove empty space
- **并且**：调整布局以删除空白空间

---

## Requirement: Support platform-specific interactions | 需求：支持平台特定的交互

The system SHALL provide different interaction patterns for desktop and mobile platforms.

系统应为桌面端和移动端提供不同的交互模式。

### Scenario: Handle click on desktop | 场景：处理桌面端点击

- **WHEN** user clicks on a note card on desktop
- **操作**：用户在桌面端点击笔记卡片
- **THEN** the system SHALL trigger the onTap callback
- **预期结果**：系统应触发 onTap 回调
- **AND** navigate to card detail or editor view
- **并且**：导航到卡片详情或编辑器视图

### Scenario: Handle right-click on desktop | 场景：处理桌面端右键点击

- **WHEN** user right-clicks on a note card on desktop
- **操作**：用户在桌面端右键点击笔记卡片
- **THEN** the system SHALL display a context menu
- **预期结果**：系统应显示上下文菜单
- **AND** show available operations (edit, delete, share, etc.)
- **并且**：显示可用操作（编辑、删除、分享等）
- **AND** position menu near the cursor
- **并且**：将菜单定位在光标附近

### Scenario: Handle tap on mobile | 场景：处理移动端点击

- **WHEN** user taps on a note card on mobile
- **操作**：用户在移动端点击笔记卡片
- **THEN** the system SHALL trigger the onTap callback
- **预期结果**：系统应触发 onTap 回调
- **AND** provide haptic feedback
- **并且**：提供触觉反馈
- **AND** navigate to card detail or editor view
- **并且**：导航到卡片详情或编辑器视图

### Scenario: Handle long-press on mobile | 场景：处理移动端长按

- **WHEN** user long-presses on a note card on mobile
- **操作**：用户在移动端长按笔记卡片
- **THEN** the system SHALL display a context menu or bottom sheet
- **预期结果**：系统应显示上下文菜单或底部表单
- **AND** provide haptic feedback
- **并且**：提供触觉反馈
- **AND** show available operations (edit, delete, share, etc.)
- **并且**：显示可用操作（编辑、删除、分享等）

---

## Requirement: Support context menu operations | 需求：支持上下文菜单操作

The system SHALL provide context menu operations for card management.

系统应提供用于卡片管理的上下文菜单操作。

### Scenario: Edit card from context menu | 场景：从上下文菜单编辑卡片

- **WHEN** user selects "Edit" from the context menu
- **操作**：用户从上下文菜单选择"编辑"
- **THEN** the system SHALL trigger the onUpdate callback
- **预期结果**：系统应触发 onUpdate 回调
- **AND** navigate to card editor view
- **并且**：导航到卡片编辑器视图

### Scenario: Delete card from context menu | 场景：从上下文菜单删除卡片

- **WHEN** user selects "Delete" from the context menu
- **操作**：用户从上下文菜单选择"删除"
- **THEN** the system SHALL show a confirmation dialog
- **预期结果**：系统应显示确认对话框
- **AND** trigger the onDelete callback upon confirmation
- **并且**：确认后触发 onDelete 回调
- **AND** remove the card from the list
- **并且**：从列表中删除卡片

### Scenario: Share card from context menu | 场景：从上下文菜单分享卡片

- **WHEN** user selects "Share" from the context menu
- **操作**：用户从上下文菜单选择"分享"
- **THEN** the system SHALL open the platform share dialog
- **预期结果**：系统应打开平台分享对话框
- **AND** include card title and content in share data
- **并且**：在分享数据中包含卡片标题和内容

---

## Requirement: Display time information | 需求：显示时间信息

The system SHALL display time information in user-friendly formats.

系统应以用户友好的格式显示时间信息。

### Scenario: Display relative time for recent updates | 场景：为最近更新显示相对时间

- **WHEN** rendering a note card updated within the last 24 hours
- **操作**：渲染在过去24小时内更新的笔记卡片
- **THEN** the system SHALL display relative time (e.g., "2 hours ago", "30 minutes ago")
- **预期结果**：系统应显示相对时间（例如"2小时前"、"30分钟前"）
- **AND** update the display automatically as time passes
- **并且**：随着时间推移自动更新显示

### Scenario: Display absolute time for older updates | 场景：为较旧更新显示绝对时间

- **WHEN** rendering a note card updated more than 24 hours ago
- **操作**：渲染在24小时前更新的笔记卡片
- **THEN** the system SHALL display absolute date (e.g., "Jan 20, 2026")
- **预期结果**：系统应显示绝对日期（例如"2026年1月20日"）
- **AND** include time if updated within the last week
- **并且**：如果在过去一周内更新，则包含时间

### Scenario: Display full timestamp on hover | 场景：悬停时显示完整时间戳

- **WHEN** user hovers over the time display on desktop
- **操作**：用户在桌面端悬停在时间显示上
- **THEN** the system SHALL show a tooltip with full timestamp
- **预期结果**：系统应显示带有完整时间戳的工具提示
- **AND** include date, time, and timezone information
- **并且**：包含日期、时间和时区信息

---

## Requirement: Provide visual feedback | 需求：提供视觉反馈

The system SHALL provide clear visual feedback for user interactions.

系统应为用户交互提供清晰的视觉反馈。

### Scenario: Show hover state on desktop | 场景：在桌面端显示悬停状态

- **WHEN** user hovers over a note card on desktop
- **操作**：用户在桌面端悬停在笔记卡片上
- **THEN** the system SHALL apply hover state styling
- **预期结果**：系统应应用悬停状态样式
- **AND** change background color or add shadow
- **并且**：更改背景颜色或添加阴影
- **AND** show cursor as pointer
- **并且**：将光标显示为指针

### Scenario: Show press state on mobile | 场景：在移动端显示按下状态

- **WHEN** user presses on a note card on mobile
- **操作**：用户在移动端按下笔记卡片
- **THEN** the system SHALL apply press state styling
- **预期结果**：系统应应用按下状态样式
- **AND** provide visual feedback (e.g., scale down, change opacity)
- **并且**：提供视觉反馈（例如缩小、更改不透明度）
- **AND** provide haptic feedback
- **并且**：提供触觉反馈

### Scenario: Show collaboration indicator | 场景：显示协作指示器

- **WHEN** rendering a note card edited by another device
- **操作**：渲染由其他设备编辑的笔记卡片
- **THEN** the system SHALL display a collaboration indicator
- **预期结果**：系统应显示协作指示器
- **AND** show the device name or identifier
- **并且**：显示设备名称或标识符
- **AND** apply distinct visual styling
- **并且**：应用独特的视觉样式

---

## Requirement: Support accessibility | 需求：支持无障碍访问

The system SHALL provide accessibility features for users with disabilities.

系统应为残障用户提供无障碍访问功能。

### Scenario: Provide semantic labels | 场景：提供语义标签

- **WHEN** rendering a note card
- **操作**：渲染笔记卡片
- **THEN** the system SHALL provide semantic labels for screen readers
- **预期结果**：系统应为屏幕阅读器提供语义标签
- **AND** include card title, content preview, and metadata in labels
- **并且**：在标签中包含卡片标题、内容预览和元数据

### Scenario: Support keyboard navigation | 场景：支持键盘导航

- **WHEN** user navigates using keyboard on desktop
- **操作**：用户在桌面端使用键盘导航
- **THEN** the system SHALL support focus management
- **预期结果**：系统应支持焦点管理
- **AND** show focus indicator when card is focused
- **并且**：当卡片获得焦点时显示焦点指示器
- **AND** support Enter key to open card
- **并且**：支持 Enter 键打开卡片
- **AND** support context menu key to show context menu
- **并且**：支持上下文菜单键显示上下文菜单

### Scenario: Support high contrast mode | 场景：支持高对比度模式

- **WHEN** system is in high contrast mode
- **操作**：系统处于高对比度模式
- **THEN** the system SHALL adjust colors for better visibility
- **预期结果**：系统应调整颜色以提高可见性
- **AND** maintain sufficient contrast ratios
- **并且**：保持足够的对比度比率
- **AND** ensure all interactive elements are visible
- **并且**：确保所有交互元素可见

---

## Requirement: Optimize performance | 需求：优化性能

The system SHALL optimize rendering performance for smooth scrolling and interaction.

系统应优化渲染性能以实现流畅的滚动和交互。

### Scenario: Optimize rendering for large lists | 场景：优化大列表的渲染

- **WHEN** rendering note cards in a large list
- **操作**：在大列表中渲染笔记卡片
- **THEN** the system SHALL use efficient rendering techniques
- **预期结果**：系统应使用高效的渲染技术
- **AND** avoid unnecessary rebuilds
- **并且**：避免不必要的重建
- **AND** implement proper key management
- **并且**：实现适当的键管理

### Scenario: Lazy load card content | 场景：延迟加载卡片内容

- **WHEN** rendering note cards in a scrollable list
- **操作**：在可滚动列表中渲染笔记卡片
- **THEN** the system SHALL defer loading of off-screen content
- **预期结果**：系统应延迟加载屏幕外的内容
- **AND** load content as cards enter the viewport
- **并且**：当卡片进入视口时加载内容

### Scenario: Cache rendered content | 场景：缓存渲染内容

- **WHEN** rendering note cards
- **操作**：渲染笔记卡片
- **THEN** the system SHALL cache rendered content when appropriate
- **预期结果**：系统应在适当时缓存渲染内容
- **AND** reuse cached content for unchanged cards
- **并且**：为未更改的卡片重用缓存内容

---

## Requirement: Handle edge cases | 需求：处理边缘情况

The system SHALL gracefully handle edge cases and unusual input.

系统应优雅地处理边缘情况和异常输入。

### Scenario: Handle very long title | 场景：处理非常长的标题

- **WHEN** rendering a note card with a very long title
- **操作**：渲染带有非常长标题的笔记卡片
- **THEN** the system SHALL truncate the title with ellipsis
- **预期结果**：系统应使用省略号截断标题
- **AND** prevent layout overflow
- **并且**：防止布局溢出
- **AND** show full title in tooltip on hover
- **并且**：悬停时在工具提示中显示完整标题

### Scenario: Handle very long content | 场景：处理非常长的内容

- **WHEN** rendering a note card with very long content
- **操作**：渲染带有非常长内容的笔记卡片
- **THEN** the system SHALL limit preview to a fixed number of lines
- **预期结果**：系统应将预览限制为固定行数
- **AND** truncate with ellipsis
- **并且**：使用省略号截断
- **AND** prevent layout overflow
- **并且**：防止布局溢出

### Scenario: Handle many tags | 场景：处理多个标签

- **WHEN** rendering a note card with many tags
- **操作**：渲染带有多个标签的笔记卡片
- **THEN** the system SHALL display tags in a scrollable or wrapped layout
- **预期结果**：系统应在可滚动或换行布局中显示标签
- **AND** limit visible tags if necessary (e.g., show first 5 + "more")
- **并且**：如有必要限制可见标签（例如显示前5个+"更多"）
- **AND** prevent layout overflow
- **并且**：防止布局溢出

---

## Test Coverage | 测试覆盖

**Test File** | **测试文件**: `test/widgets/note_card_test.dart`, `test/specs/note_card_component_spec_test.dart`

### Basic Display Tests | 基础显示测试 (4 tests)

1. `it_should_display_card_title` - Display card title | 显示卡片标题
2. `it_should_display_card_content_preview` - Display content preview | 显示内容预览
3. `it_should_display_tags` - Display tags | 显示标签
4. `it_should_display_metadata` - Display metadata (update time) | 显示元数据（更新时间）

### Interaction Tests | 交互测试 (4 tests)

5. `it_should_respond_to_tap_on_mobile` - Handle tap on mobile | 处理移动端点击
6. `it_should_enter_edit_mode_on_desktop` - Handle click on desktop | 处理桌面端点击
7. `it_should_show_context_menu_on_right_click` - Handle right-click on desktop | 处理桌面端右键点击
8. `it_should_show_context_menu_on_long_press` - Handle long-press on mobile | 处理移动端长按

### Tag Management Tests | 标签管理测试 (2 tests)

9. `it_should_display_all_tags` - Display all tags | 显示所有标签
10. `it_should_handle_empty_tags` - Handle empty tags | 处理空标签

### Update Tests | 更新测试 (2 tests)

11. `it_should_call_onUpdate_when_card_is_modified` - Call onUpdate callback | 调用 onUpdate 回调
12. `it_should_update_display_when_card_changes` - Update display on change | 更改时更新显示

### Delete Tests | 删除测试 (2 tests)

13. `it_should_call_onDelete_when_delete_is_triggered` - Call onDelete callback | 调用 onDelete 回调
14. `it_should_show_confirmation_dialog_before_delete` - Show confirmation dialog | 显示确认对话框

### Visual Feedback Tests | 视觉反馈测试 (3 tests)

15. `it_should_show_hover_effect_on_desktop` - Show hover effect | 显示悬停效果
16. `it_should_show_press_effect_on_mobile` - Show press effect | 显示按下效果
17. `it_should_show_collaboration_indicator` - Show collaboration indicator | 显示协作指示器

### Edge Cases Tests | 边缘情况测试 (3 tests)

18. `it_should_handle_long_title` - Handle very long title | 处理非常长的标题
19. `it_should_handle_empty_title` - Handle empty title | 处理空标题
20. `it_should_handle_empty_content` - Handle empty content | 处理空内容

### Time Display Tests | 时间显示测试 (3 tests)

21. `it_should_display_relative_time_for_recent_updates` - Display relative time | 显示相对时间
22. `it_should_display_absolute_time_for_old_updates` - Display absolute time | 显示绝对时间
23. `it_should_show_full_timestamp_on_hover` - Show full timestamp on hover | 悬停时显示完整时间戳

### Context Menu Tests | 上下文菜单测试 (4 tests)

24. `it_should_show_edit_option_in_context_menu` - Show edit option | 显示编辑选项
25. `it_should_show_delete_option_in_context_menu` - Show delete option | 显示删除选项
26. `it_should_show_share_option_in_context_menu` - Show share option | 显示分享选项
27. `it_should_close_context_menu_on_outside_click` - Close menu on outside click | 外部点击时关闭菜单

### Accessibility Tests | 无障碍访问测试 (5 tests)

28. `it_should_provide_semantic_labels` - Provide semantic labels | 提供语义标签
29. `it_should_support_keyboard_navigation` - Support keyboard navigation | 支持键盘导航
30. `it_should_show_focus_indicator` - Show focus indicator | 显示焦点指示器
31. `it_should_support_enter_key_to_open` - Support Enter key | 支持 Enter 键
32. `it_should_support_high_contrast_mode` - Support high contrast mode | 支持高对比度模式

### Performance Tests | 性能测试 (3 tests)

33. `it_should_render_efficiently_in_large_lists` - Efficient rendering | 高效渲染
34. `it_should_avoid_unnecessary_rebuilds` - Avoid unnecessary rebuilds | 避免不必要的重建
35. `it_should_use_proper_key_management` - Proper key management | 适当的键管理

### Platform-Specific Tests | 平台特定测试 (4 tests)

36. `it_should_detect_desktop_platform` - Detect desktop platform | 检测桌面平台
37. `it_should_detect_mobile_platform` - Detect mobile platform | 检测移动平台
38. `it_should_provide_haptic_feedback_on_mobile` - Provide haptic feedback | 提供触觉反馈
39. `it_should_show_pointer_cursor_on_desktop` - Show pointer cursor | 显示指针光标

### Tag Display Tests | 标签显示测试 (2 tests)

40. `it_should_handle_many_tags` - Handle many tags | 处理多个标签
41. `it_should_truncate_tag_list_if_needed` - Truncate tag list | 截断标签列表

### Empty State Tests | 空状态测试 (2 tests)

42. `it_should_show_placeholder_for_empty_title` - Show placeholder for empty title | 为空标题显示占位符
43. `it_should_show_placeholder_for_empty_content` - Show placeholder for empty content | 为空内容显示占位符

**Total Test Count** | **测试总数**: 43 tests

---

## Acceptance Criteria | 验收标准

### Functional Requirements | 功能需求

- [ ] All 43 widget tests pass | 所有43个 Widget 测试通过
- [ ] Card content displays correctly (title, content, tags, time) | 卡片内容正确显示（标题、内容、标签、时间）
- [ ] Platform-specific interactions work correctly | 平台特定交互正常工作
- [ ] Context menu operations function properly | 上下文菜单操作正常运行
- [ ] Empty states handled gracefully | 空状态优雅处理
- [ ] Edge cases handled without errors | 边缘情况无错误处理

### Visual Requirements | 视觉需求

- [ ] Visual feedback is clear and responsive | 视觉反馈清晰且响应迅速
- [ ] Hover and press states are visually distinct | 悬停和按下状态视觉上明显
- [ ] Collaboration indicators are visible | 协作指示器可见
- [ ] Layout is consistent across different card states | 不同卡片状态下布局一致
- [ ] No layout overflow or visual glitches | 无布局溢出或视觉故障

### Performance Requirements | 性能需求

- [ ] Smooth scrolling in large lists (60 FPS) | 大列表中流畅滚动（60 FPS）
- [ ] No unnecessary rebuilds or re-renders | 无不必要的重建或重新渲染
- [ ] Efficient memory usage | 高效的内存使用
- [ ] Fast initial render time (<100ms per card) | 快速初始渲染时间（每张卡片<100ms）

### Accessibility Requirements | 无障碍访问需求

- [ ] Screen reader support with semantic labels | 带有语义标签的屏幕阅读器支持
- [ ] Keyboard navigation fully functional | 键盘导航完全正常
- [ ] Focus indicators visible and clear | 焦点指示器可见且清晰
- [ ] High contrast mode supported | 支持高对比度模式
- [ ] WCAG 2.1 Level AA compliance | 符合 WCAG 2.1 AA 级标准

### Code Quality Requirements | 代码质量需求

- [ ] Code review approved | 代码审查通过
- [ ] No linting errors or warnings | 无 linting 错误或警告
- [ ] Documentation updated | 文档已更新
- [ ] Test coverage ≥ 90% | 测试覆盖率 ≥ 90%

---

## Related Documents | 相关文档

**Related Specs** | **相关规格**:
- [Card Model](../../architecture/data/card.md) - Card data model | 卡片数据模型
- [Card List Item](./card_list_item.md) - Card list item component | 卡片列表项组件
- [Context Menu](../context_menu/context_menu.md) - Context menu component | 上下文菜单组件
- [Desktop Card List](./desktop.md) - Desktop card list view | 桌面端卡片列表视图
- [Mobile Card List](./mobile.md) - Mobile card list view | 移动端卡片列表视图

**Related Tests** | **相关测试**:
- `test/widgets/note_card_test.dart` - Note card widget tests | 笔记卡片 Widget 测试
- `test/specs/note_card_component_spec_test.dart` - Note card specification tests | 笔记卡片规格测试

**Related Implementation** | **相关实现**:
- `lib/widgets/note_card.dart` - Note card widget implementation | 笔记卡片 Widget 实现
- `lib/bridge/models/card.dart` - Card data model | 卡片数据模型

---

**Last Updated** | **最后更新**: 2026-01-25
**Authors** | **作者**: CardMind Team
