# Card List Item Specification
# 卡片列表项规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active
**Dependencies** | **依赖**: [card_store.md](../../domain/card_store.md)
**Related Tests** | **相关测试**: `test/widgets/card_list_item_test.dart`

---

## Overview | 概述

This specification defines the card list item component for displaying card summaries in list or grid layouts.

本规格定义了卡片列表项组件，用于在列表或网格布局中显示卡片摘要。

---

## Requirement: Display card summary in list view
## 需求：在列表视图中显示卡片摘要

The system SHALL provide a compact card list item component for displaying card summaries in list or grid layouts.

系统应提供紧凑的卡片列表项组件，用于在列表或网格布局中显示卡片摘要。

### Scenario: Show card title and preview
### 场景：显示卡片标题和预览

- **WHEN** rendering a card list item
- **操作**：渲染卡片列表项
- **THEN** the system SHALL display the card title prominently
- **预期结果**：系统应突出显示卡片标题
- **AND** show a preview of the card content (first N characters)
- **并且**：显示卡片内容预览（前 N 个字符）

### Scenario: Show card metadata
### 场景：显示卡片元数据

- **WHEN** rendering a card list item
- **操作**：渲染卡片列表项
- **THEN** the system SHALL display last modified timestamp
- **预期结果**：系统应显示最后修改时间戳
- **AND** show associated tags
- **并且**：显示关联的标签

---

## Requirement: Support tap interaction
## 需求：支持点击交互

The system SHALL handle tap interactions to open cards for viewing or editing.

系统应处理点击交互以打开卡片进行查看或编辑。

### Scenario: Tap to open card
### 场景：点击打开卡片

- **WHEN** user taps on a card list item
- **操作**：用户点击卡片列表项
- **THEN** the system SHALL call onTap callback with the card data
- **预期结果**：系统应使用卡片数据调用 onTap 回调
- **AND** trigger navigation to card detail or editor view
- **并且**：触发导航到卡片详情或编辑器视图

---

## Requirement: Show visual feedback for selection
## 需求：显示选择的视觉反馈

The system SHALL provide visual feedback when a card is selected or focused.

系统应在卡片被选中或聚焦时提供视觉反馈。

### Scenario: Highlight selected card
### 场景：高亮选中的卡片

- **WHEN** a card list item is selected
- **操作**：选中卡片列表项
- **THEN** the system SHALL apply distinct styling to indicate selection state
- **预期结果**：系统应应用独特的样式来指示选择状态

### Scenario: Show hover state on desktop
### 场景：在桌面端显示悬停状态

- **WHEN** user hovers over a card list item on desktop
- **操作**：用户在桌面端悬停在卡片列表项上
- **THEN** the system SHALL show hover state styling
- **预期结果**：系统应显示悬停状态样式

---

## Requirement: Display sync status indicator
## 需求：显示同步状态指示器

The system SHALL show synchronization status for each card.

系统应为每张卡片显示同步状态。

### Scenario: Show synced indicator
### 场景：显示已同步指示器

- **WHEN** a card is fully synchronized across devices
- **操作**：卡片已在设备间完全同步
- **THEN** the card list item SHALL display a synced status indicator
- **预期结果**：卡片列表项应显示已同步状态指示器

### Scenario: Show pending sync indicator
### 场景：显示待同步指示器

- **WHEN** a card has local changes not yet synchronized
- **操作**：卡片有尚未同步的本地更改
- **THEN** the card list item SHALL display a pending sync indicator
- **预期结果**：卡片列表项应显示待同步指示器

---

## Test Coverage | 测试覆盖

**Test File** | **测试文件**: `test/widgets/card_list_item_test.dart`

**Widget Tests** | **Widget 测试**:
- `it_should_display_title_prominently()` - Display title | 显示标题
- `it_should_show_content_preview()` - Show preview | 显示预览
- `it_should_display_last_modified()` - Show timestamp | 显示时间戳
- `it_should_show_tags()` - Display tags | 显示标签
- `it_should_trigger_ontap_callback()` - Tap callback | 点击回调
- `it_should_highlight_selection()` - Highlight selected | 高亮选中
- `it_should_show_hover_state()` - Hover state | 悬停状态
- `it_should_show_synced_indicator()` - Synced indicator | 已同步指示器
- `it_should_show_pending_indicator()` - Pending indicator | 待同步指示器

**Acceptance Criteria** | **验收标准**:
- [ ] All widget tests pass | 所有 Widget 测试通过
- [ ] Visual feedback is clear and responsive | 视觉反馈清晰且响应迅速
- [ ] Sync indicators are accurate | 同步指示器准确
- [ ] Code review approved | 代码审查通过
- [ ] Documentation updated | 文档已更新

---

## Related Documents | 相关文档

**Related Specs** | **相关规格**:
- [card_store.md](../../domain/card_store.md) - Card storage | 卡片存储
- [sync_status_indicator.md](../sync_feedback/sync_status_indicator.md) - Sync status | 同步状态

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
