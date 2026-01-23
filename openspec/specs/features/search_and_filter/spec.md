# Search and Filter Feature Specification
# 搜索和过滤功能规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: Active

**Dependencies**: [../../architecture/storage/sqlite_cache.md](../../architecture/storage/sqlite_cache.md), [../../domain/card/model.md](../../domain/card/model.md), [../card_management/spec.md](../card_management/spec.md)
**依赖**: [../../architecture/storage/sqlite_cache.md](../../architecture/storage/sqlite_cache.md), [../../domain/card/model.md](../../domain/card/model.md), [../card_management/spec.md](../card_management/spec.md)

**Related Tests**: `test/features/search_and_filter_test.dart`
**相关测试**: `test/features/search_and_filter_test.dart`

---

## Overview
## 概述

This specification defines the Search and Filter feature, which enables users to quickly find and organize cards through full-text search, tag filtering, and sorting capabilities. The feature provides real-time search results with highlighted matches and supports multiple filtering criteria to help users navigate large collections of cards efficiently.

本规格定义了搜索和过滤功能，使用户能够通过全文搜索、标签过滤和排序功能快速查找和组织卡片。该功能提供实时搜索结果和高亮匹配，支持多种过滤条件，帮助用户高效浏览大量卡片集合。

**Key User Journeys**:
**核心用户旅程**:
- Search cards by keywords in title and content
- 通过标题和内容中的关键词搜索卡片
- Filter cards by tags
- 按标签过滤卡片
- Sort cards by different criteria (time, title)
- 按不同标准排序卡片（时间、标题）
- Combine search and filter for precise results
- 组合搜索和过滤以获得精确结果
- View highlighted search matches
- 查看高亮的搜索匹配

---

## Requirement: Full-Text Search
## 需求：全文搜索

Users SHALL be able to search cards using keywords that match against card titles and content.

用户应能够使用关键词搜索卡片，匹配卡片标题和内容。

### Scenario: Search cards by keyword in title
### 场景：按标题中的关键词搜索卡片

- **GIVEN**: Multiple cards exist with different titles
- **前置条件**: 存在多张具有不同标题的卡片
- **WHEN**: The user enters "meeting" in the search field
- **操作**: 用户在搜索字段中输入"meeting"
- **THEN**: The system SHALL return all cards with "meeting" in the title
- **预期结果**: 系统应返回标题中包含"meeting"的所有卡片
- **AND**: The search SHALL be case-insensitive
- **并且**: 搜索应不区分大小写
- **AND**: Results SHALL appear within 200 milliseconds
- **并且**: 结果应在200毫秒内出现

### Scenario: Search cards by keyword in content
### 场景：按内容中的关键词搜索卡片

- **GIVEN**: Multiple cards exist with different content
- **前置条件**: 存在多张具有不同内容的卡片
- **WHEN**: The user enters "project timeline" in the search field
- **操作**: 用户在搜索字段中输入"project timeline"
- **THEN**: The system SHALL return all cards containing "project timeline" in content
- **预期结果**: 系统应返回内容中包含"project timeline"的所有卡片
- **AND**: The search SHALL match partial words
- **并且**: 搜索应匹配部分单词
- **AND**: Results SHALL be ranked by relevance
- **并且**: 结果应按相关性排序

### Scenario: Search with multiple keywords
### 场景：使用多个关键词搜索

- **GIVEN**: Cards exist with various content
- **前置条件**: 存在具有各种内容的卡片
- **WHEN**: The user enters "rust programming tutorial"
- **操作**: 用户输入"rust programming tutorial"
- **THEN**: The system SHALL return cards containing any of the keywords
- **预期结果**: 系统应返回包含任何关键词的卡片
- **AND**: Cards matching more keywords SHALL rank higher
- **并且**: 匹配更多关键词的卡片应排名更高
- **AND**: The system SHALL use FTS5 full-text search
- **并且**: 系统应使用FTS5全文搜索

### Scenario: Real-time search updates
### 场景：实时搜索更新

- **GIVEN**: The user is typing in the search field
- **前置条件**: 用户正在搜索字段中输入
- **WHEN**: The user types each character
- **操作**: 用户输入每个字符
- **THEN**: The system SHALL update results in real-time
- **预期结果**: 系统应实时更新结果
- **AND**: The system SHALL debounce input by 200 milliseconds
- **并且**: 系统应对输入进行200毫秒的防抖
- **AND**: The UI SHALL remain responsive during search
- **并且**: UI应在搜索期间保持响应

### Scenario: Clear search returns all cards
### 场景：清空搜索返回所有卡片

- **GIVEN**: A search is active with filtered results
- **前置条件**: 搜索已激活并显示过滤结果
- **WHEN**: The user clears the search field
- **操作**: 用户清空搜索字段
- **THEN**: The system SHALL display all cards again
- **预期结果**: 系统应再次显示所有卡片
- **AND**: The transition SHALL be smooth without flicker
- **并且**: 过渡应平滑无闪烁

### Scenario: No search results shows empty state
### 场景：无搜索结果显示空状态

- **GIVEN**: The user enters a search query
- **前置条件**: 用户输入搜索查询
- **WHEN**: No cards match the search criteria
- **操作**: 没有卡片匹配搜索条件
- **THEN**: The system SHALL display "未找到相关笔记" message
- **预期结果**: 系统应显示"未找到相关笔记"消息
- **AND**: The system SHALL show the search term
- **并且**: 系统应显示搜索词
- **AND**: The system SHALL suggest trying different keywords
- **并且**: 系统应建议尝试不同的关键词

---

## Requirement: Search Match Highlighting
## 需求：搜索匹配高亮

The system SHALL highlight matching text in search results to help users identify relevant content.

系统应在搜索结果中高亮匹配文本，帮助用户识别相关内容。

### Scenario: Highlight matches in card title
### 场景：高亮卡片标题中的匹配

- **GIVEN**: Search results are displayed
- **前置条件**: 搜索结果已显示
- **WHEN**: A card title contains the search keyword
- **操作**: 卡片标题包含搜索关键词
- **THEN**: The system SHALL highlight the matching text in the title
- **预期结果**: 系统应高亮标题中的匹配文本
- **AND**: The highlight SHALL use the primary theme color
- **并且**: 高亮应使用主题主色
- **AND**: The highlight SHALL be clearly visible
- **并且**: 高亮应清晰可见

### Scenario: Highlight matches in card content
### 场景：高亮卡片内容中的匹配

- **GIVEN**: Search results are displayed
- **前置条件**: 搜索结果已显示
- **WHEN**: A card content contains the search keyword
- **操作**: 卡片内容包含搜索关键词
- **THEN**: The system SHALL highlight the matching text in the content preview
- **预期结果**: 系统应高亮内容预览中的匹配文本
- **AND**: Multiple matches SHALL all be highlighted
- **并且**: 多个匹配应全部高亮
- **AND**: The highlight style SHALL be consistent across all matches
- **并且**: 高亮样式应在所有匹配中保持一致

### Scenario: Highlight multiple keywords
### 场景：高亮多个关键词

- **GIVEN**: User searches with multiple keywords
- **前置条件**: 用户使用多个关键词搜索
- **WHEN**: A card contains multiple search keywords
- **操作**: 卡片包含多个搜索关键词
- **THEN**: The system SHALL highlight all matching keywords
- **预期结果**: 系统应高亮所有匹配的关键词
- **AND**: Each keyword SHALL be highlighted independently
- **并且**: 每个关键词应独立高亮

---

## Requirement: Tag Filtering
## 需求：标签过滤

Users SHALL be able to filter cards by selecting one or more tags.

用户应能够通过选择一个或多个标签来过滤卡片。

### Scenario: Display available tags
### 场景：显示可用标签

- **GIVEN**: Cards exist with various tags
- **前置条件**: 存在具有各种标签的卡片
- **WHEN**: The user opens the tag filter
- **操作**: 用户打开标签过滤器
- **THEN**: The system SHALL display all unique tags from all cards
- **预期结果**: 系统应显示所有卡片的所有唯一标签
- **AND**: Tags SHALL be sorted alphabetically
- **并且**: 标签应按字母顺序排序
- **AND**: Each tag SHALL show the count of cards with that tag
- **并且**: 每个标签应显示具有该标签的卡片数量

### Scenario: Filter cards by single tag
### 场景：按单个标签过滤卡片

- **GIVEN**: Multiple cards exist with different tags
- **前置条件**: 存在具有不同标签的多张卡片
- **WHEN**: The user selects tag "work"
- **操作**: 用户选择标签"work"
- **THEN**: The system SHALL display only cards with tag "work"
- **预期结果**: 系统应只显示具有标签"work"的卡片
- **AND**: The tag filter SHALL remain visible and active
- **并且**: 标签过滤器应保持可见和激活状态
- **AND**: The selected tag SHALL be visually highlighted
- **并且**: 选中的标签应视觉高亮

### Scenario: Filter cards by multiple tags (OR logic)
### 场景：按多个标签过滤卡片（OR逻辑）

- **GIVEN**: Cards exist with various tags
- **前置条件**: 存在具有各种标签的卡片
- **WHEN**: The user selects tags "work" and "urgent"
- **操作**: 用户选择标签"work"和"urgent"
- **THEN**: The system SHALL display cards that have either "work" OR "urgent" tag
- **预期结果**: 系统应显示具有"work"或"urgent"标签的卡片
- **AND**: Cards with both tags SHALL also be included
- **并且**: 同时具有两个标签的卡片也应包含
- **AND**: The filter SHALL use OR logic by default
- **并且**: 过滤器应默认使用OR逻辑

### Scenario: Clear tag filter
### 场景：清除标签过滤

- **GIVEN**: Tag filter is active
- **前置条件**: 标签过滤器已激活
- **WHEN**: The user clicks "Clear filters" or deselects all tags
- **操作**: 用户点击"清除过滤器"或取消选择所有标签
- **THEN**: The system SHALL display all cards again
- **预期结果**: 系统应再次显示所有卡片
- **AND**: The tag filter SHALL return to default state
- **并且**: 标签过滤器应返回默认状态

### Scenario: No cards match tag filter
### 场景：没有卡片匹配标签过滤

- **GIVEN**: The user selects a tag
- **前置条件**: 用户选择一个标签
- **WHEN**: No cards have the selected tag
- **操作**: 没有卡片具有选中的标签
- **THEN**: The system SHALL display "未找到相关笔记" message
- **预期结果**: 系统应显示"未找到相关笔记"消息
- **AND**: The system SHALL suggest clearing the filter
- **并且**: 系统应建议清除过滤器

---

## Requirement: Combined Search and Filter
## 需求：组合搜索和过滤

Users SHALL be able to combine search keywords with tag filters for precise results.

用户应能够组合搜索关键词和标签过滤器以获得精确结果。

### Scenario: Search within filtered tags
### 场景：在过滤的标签内搜索

- **GIVEN**: The user has selected tag "work"
- **前置条件**: 用户已选择标签"work"
- **WHEN**: The user enters "meeting" in the search field
- **操作**: 用户在搜索字段中输入"meeting"
- **THEN**: The system SHALL display cards that have tag "work" AND contain "meeting"
- **预期结果**: 系统应显示具有标签"work"且包含"meeting"的卡片
- **AND**: Both filters SHALL be applied simultaneously
- **并且**: 两个过滤器应同时应用
- **AND**: Results SHALL update in real-time
- **并且**: 结果应实时更新

### Scenario: Add tag filter to existing search
### 场景：向现有搜索添加标签过滤

- **GIVEN**: The user has entered search keyword "project"
- **前置条件**: 用户已输入搜索关键词"project"
- **WHEN**: The user selects tag "urgent"
- **操作**: 用户选择标签"urgent"
- **THEN**: The system SHALL narrow results to cards containing "project" with tag "urgent"
- **预期结果**: 系统应将结果缩小到包含"project"且具有标签"urgent"的卡片
- **AND**: The search field SHALL remain active
- **并且**: 搜索字段应保持激活状态
- **AND**: Both filters SHALL be clearly visible
- **并且**: 两个过滤器应清晰可见

### Scenario: Clear all filters
### 场景：清除所有过滤器

- **GIVEN**: Both search and tag filters are active
- **前置条件**: 搜索和标签过滤器都已激活
- **WHEN**: The user clicks "Clear all filters"
- **操作**: 用户点击"清除所有过滤器"
- **THEN**: The system SHALL clear both search and tag filters
- **预期结果**: 系统应清除搜索和标签过滤器
- **AND**: The system SHALL display all cards
- **并且**: 系统应显示所有卡片
- **AND**: All filter UI elements SHALL return to default state
- **并且**: 所有过滤器UI元素应返回默认状态

---

## Requirement: Card Sorting
## 需求：卡片排序

Users SHALL be able to sort cards by different criteria to organize their view.

用户应能够按不同标准排序卡片以组织视图。

### Scenario: Sort cards by last updated time (default)
### 场景：按最后更新时间排序（默认）

- **GIVEN**: Multiple cards exist
- **前置条件**: 存在多张卡片
- **WHEN**: The user views the card list without selecting a sort option
- **操作**: 用户查看卡片列表而不选择排序选项
- **THEN**: The system SHALL sort cards by updated_at timestamp in descending order
- **预期结果**: 系统应按updated_at时间戳降序排序卡片
- **AND**: Most recently updated cards SHALL appear first
- **并且**: 最近更新的卡片应首先出现
- **AND**: This SHALL be the default sort order
- **并且**: 这应是默认排序顺序

### Scenario: Sort cards by creation time
### 场景：按创建时间排序

- **GIVEN**: Multiple cards exist
- **前置条件**: 存在多张卡片
- **WHEN**: The user selects "Sort by creation time"
- **操作**: 用户选择"按创建时间排序"
- **THEN**: The system SHALL sort cards by created_at timestamp in descending order
- **预期结果**: 系统应按created_at时间戳降序排序卡片
- **AND**: Most recently created cards SHALL appear first
- **并且**: 最近创建的卡片应首先出现
- **AND**: The sort preference SHALL be saved for the session
- **并且**: 排序偏好应为会话保存

### Scenario: Sort cards by title alphabetically
### 场景：按标题字母顺序排序

- **GIVEN**: Multiple cards exist
- **前置条件**: 存在多张卡片
- **WHEN**: The user selects "Sort by title A-Z"
- **操作**: 用户选择"按标题A-Z排序"
- **THEN**: The system SHALL sort cards alphabetically by title
- **预期结果**: 系统应按标题字母顺序排序卡片
- **AND**: The sort SHALL be case-insensitive
- **并且**: 排序应不区分大小写
- **AND**: Cards starting with numbers SHALL appear before letters
- **并且**: 以数字开头的卡片应出现在字母之前

### Scenario: Reverse sort order
### 场景：反转排序顺序

- **GIVEN**: Cards are sorted in ascending order
- **前置条件**: 卡片按升序排序
- **WHEN**: The user clicks the sort direction toggle
- **操作**: 用户点击排序方向切换
- **THEN**: The system SHALL reverse the sort order to descending
- **预期结果**: 系统应将排序顺序反转为降序
- **AND**: The sort criteria SHALL remain the same
- **并且**: 排序标准应保持不变
- **AND**: The toggle icon SHALL update to reflect the new direction
- **并且**: 切换图标应更新以反映新方向

### Scenario: Sorting persists with filters
### 场景：排序在过滤时保持

- **GIVEN**: The user has selected a sort order
- **前置条件**: 用户已选择排序顺序
- **WHEN**: The user applies search or tag filters
- **操作**: 用户应用搜索或标签过滤器
- **THEN**: The filtered results SHALL maintain the selected sort order
- **预期结果**: 过滤结果应保持选定的排序顺序
- **AND**: The sort option SHALL remain visible and active
- **并且**: 排序选项应保持可见和激活状态

---

## Requirement: Search Performance
## 需求：搜索性能

The system SHALL provide fast search and filter operations to maintain a responsive user experience.

系统应提供快速的搜索和过滤操作以保持响应式用户体验。

### Scenario: Search completes within 200ms
### 场景：搜索在200毫秒内完成

- **GIVEN**: The user enters a search query
- **前置条件**: 用户输入搜索查询
- **WHEN**: The search is executed
- **操作**: 执行搜索
- **THEN**: The system SHALL return results within 200 milliseconds
- **预期结果**: 系统应在200毫秒内返回结果
- **AND**: The UI SHALL remain responsive during search
- **并且**: UI应在搜索期间保持响应
- **AND**: The system SHALL use SQLite FTS5 for full-text search
- **并且**: 系统应使用SQLite FTS5进行全文搜索

### Scenario: Filter updates within 100ms
### 场景：过滤在100毫秒内更新

- **GIVEN**: The user selects a tag filter
- **前置条件**: 用户选择标签过滤器
- **WHEN**: The filter is applied
- **操作**: 应用过滤器
- **THEN**: The system SHALL update the card list within 100 milliseconds
- **预期结果**: 系统应在100毫秒内更新卡片列表
- **AND**: The transition SHALL be smooth without flicker
- **并且**: 过渡应平滑无闪烁

### Scenario: Search handles large card collections
### 场景：搜索处理大量卡片集合

- **GIVEN**: The user has 1000+ cards
- **前置条件**: 用户有1000+张卡片
- **WHEN**: The user performs a search
- **操作**: 用户执行搜索
- **THEN**: The system SHALL complete the search within 200 milliseconds
- **预期结果**: 系统应在200毫秒内完成搜索
- **AND**: The system SHALL use indexed queries for performance
- **并且**: 系统应使用索引查询以提高性能
- **AND**: Memory usage SHALL remain reasonable
- **并且**: 内存使用应保持合理

---

## Business Rules
## 业务规则

### Search Scope
### 搜索范围

Search SHALL only include cards in the current pool and SHALL exclude soft-deleted cards.

搜索应只包含当前池中的卡片，并应排除软删除的卡片。

**Rationale**: Users should only see cards relevant to their current context and should not see deleted cards in search results.

**理由**：用户应只看到与当前上下文相关的卡片，不应在搜索结果中看到已删除的卡片。

### Case-Insensitive Search
### 不区分大小写搜索

All search operations SHALL be case-insensitive to improve user experience.

所有搜索操作应不区分大小写以改善用户体验。

**Rationale**: Users should not need to remember exact capitalization when searching for content.

**理由**：用户在搜索内容时不应需要记住确切的大小写。

### Search Debouncing
### 搜索防抖

The system SHALL debounce search input by 200 milliseconds to reduce unnecessary queries.

系统应对搜索输入进行200毫秒的防抖以减少不必要的查询。

**Rationale**: Prevents excessive database queries while user is typing, improving performance and reducing resource usage.

**理由**：防止用户输入时过多的数据库查询，提高性能并减少资源使用。

### Tag Filter Logic
### 标签过滤逻辑

Multiple tag filters SHALL use OR logic by default (show cards with any selected tag).

多个标签过滤器应默认使用OR逻辑（显示具有任何选中标签的卡片）。

**Rationale**: OR logic is more intuitive for most users and provides broader results. AND logic would be too restrictive for typical use cases.

**理由**：OR逻辑对大多数用户更直观，提供更广泛的结果。AND逻辑对典型用例来说过于限制。

### Default Sort Order
### 默认排序顺序

Cards SHALL be sorted by last updated time (descending) by default.

卡片应默认按最后更新时间（降序）排序。

**Rationale**: Most recently modified cards are typically most relevant to users, matching common note-taking workflows.

**理由**：最近修改的卡片通常与用户最相关，符合常见的笔记工作流程。

### Sort Persistence
### 排序持久化

Sort preferences SHALL persist for the current session but SHALL NOT be saved across app restarts.

排序偏好应在当前会话中持久化，但不应在应用重启后保存。

**Rationale**: Session-level persistence provides consistency during use without imposing permanent preferences that may not suit all contexts.

**理由**：会话级持久化在使用期间提供一致性，而不强加可能不适合所有上下文的永久偏好。

---

## Test Coverage
## 测试覆盖

**Test File**: `test/features/search_and_filter_test.dart`
**测试文件**: `test/features/search_and_filter_test.dart`

**Feature Tests**:
**功能测试**:
- `it_should_search_cards_by_title()` - Search by title keyword
- 按标题关键词搜索
- `it_should_search_cards_by_content()` - Search by content keyword
- 按内容关键词搜索
- `it_should_search_with_multiple_keywords()` - Multi-keyword search
- 多关键词搜索
- `it_should_update_search_in_realtime()` - Real-time search updates
- 实时搜索更新
- `it_should_clear_search_and_show_all_cards()` - Clear search
- 清空搜索
- `it_should_show_empty_state_for_no_results()` - Empty search results
- 无搜索结果的空状态
- `it_should_highlight_matches_in_title()` - Highlight title matches
- 高亮标题匹配
- `it_should_highlight_matches_in_content()` - Highlight content matches
- 高亮内容匹配
- `it_should_filter_cards_by_single_tag()` - Single tag filter
- 单标签过滤
- `it_should_filter_cards_by_multiple_tags()` - Multiple tag filter (OR)
- 多标签过滤（OR）
- `it_should_clear_tag_filter()` - Clear tag filter
- 清除标签过滤
- `it_should_combine_search_and_tag_filter()` - Combined search and filter
- 组合搜索和过滤
- `it_should_clear_all_filters()` - Clear all filters
- 清除所有过滤器
- `it_should_sort_by_updated_time()` - Sort by update time
- 按更新时间排序
- `it_should_sort_by_created_time()` - Sort by creation time
- 按创建时间排序
- `it_should_sort_by_title_alphabetically()` - Sort by title
- 按标题排序
- `it_should_reverse_sort_order()` - Reverse sort
- 反转排序
- `it_should_maintain_sort_with_filters()` - Sort persists with filters
- 过滤时保持排序
- `it_should_complete_search_within_200ms()` - Search performance
- 搜索性能
- `it_should_handle_large_card_collections()` - Large collection performance
- 大集合性能

**Acceptance Criteria**:
**验收标准**:
- [ ] All feature tests pass
- [ ] 所有功能测试通过
- [ ] Search works on all platforms
- [ ] 搜索在所有平台上工作
- [ ] Full-text search uses FTS5
- [ ] 全文搜索使用FTS5
- [ ] Search completes within 200ms
- [ ] 搜索在200毫秒内完成
- [ ] Tag filtering is intuitive
- [ ] 标签过滤直观
- [ ] Combined filters work correctly
- [ ] 组合过滤器正确工作
- [ ] Sorting options work as expected
- [ ] 排序选项按预期工作
- [ ] Match highlighting is visible
- [ ] 匹配高亮可见
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Architecture Specs**:
**架构规格**:
- [../../architecture/storage/sqlite_cache.md](../../architecture/storage/sqlite_cache.md) - SQLite FTS5 implementation
- SQLite FTS5实现
- [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md) - Card storage and queries
- 卡片存储和查询

**Domain Specs**:
**领域规格**:
- [../../domain/card/model.md](../../domain/card/model.md) - Card model with tags
- 带标签的卡片模型
- [../../domain/card/rules.md](../../domain/card/rules.md) - Card business rules
- 卡片业务规则

**Feature Specs**:
**功能规格**:
- [../card_management/spec.md](../card_management/spec.md) - Card management feature
- 卡片管理功能
- [../search/desktop.md](../search/desktop.md) - Desktop search UI
- 桌面端搜索UI
- [../search/mobile.md](../search/mobile.md) - Mobile search UI
- 移动端搜索UI

**UI Specs** (to be created):
**UI规格**（待创建）:
- `../../ui/components/shared/search_bar.md` - Search bar component
- 搜索栏组件
- `../../ui/components/shared/tag_filter.md` - Tag filter component
- 标签过滤器组件
- `../../ui/components/shared/sort_selector.md` - Sort selector component
- 排序选择器组件

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23

**Authors**: CardMind Team
**作者**: CardMind Team
