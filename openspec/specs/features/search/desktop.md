# Desktop Search Specification | 桌面端搜索规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active | 已完成
**Dependencies** | **依赖**: [home_screen/shared.md](../home_screen/shared.md)

---

## 1. Overview | 概述

### 1.1 Goals | 目标

Define desktop search feature specifications to ensure:

定义桌面端搜索功能规范，确保：

- Inline filtering maintaining context | 内联过滤，保持上下文
- Real-time search results | 实时搜索结果
- Highlighted matching text | 高亮匹配文本
- Keyboard shortcut support | 键盘快捷键支持

### 1.2 Applicable Platforms | 适用平台

- macOS
- Windows
- Linux

---

## 2. Search Field | 搜索字段

### Requirement: Desktop SHALL use inline search | 需求：桌面端应使用内联搜索

Desktop SHALL use inline search.

桌面端应使用内联搜索。

#### Scenario: Search field is in toolbar | 场景：搜索字段在工具栏中

- **GIVEN** user is on home screen
- **前置条件**：用户在主屏幕上
- **WHEN** viewing toolbar
- **操作**：查看工具栏
- **THEN** search field SHALL be visible
- **预期结果**：搜索字段应可见
- **AND** field SHALL be in center-right area
- **并且**：字段应在中右区域
- **AND** field SHALL have 300px width
- **并且**：字段应有 300px 宽度

#### Scenario: Search field has placeholder | 场景：搜索字段有占位符

- **GIVEN** search field is empty
- **前置条件**：搜索字段为空
- **WHEN** viewing field
- **操作**：查看字段
- **THEN** placeholder SHALL say "搜索笔记标题、内容或标签..."
- **预期结果**：占位符应显示"搜索笔记标题、内容或标签..."
- **AND** placeholder SHALL be gray
- **并且**：占位符应为灰色

#### Scenario: Cmd/Ctrl+F focuses search | 场景：Cmd/Ctrl+F 聚焦搜索

- **GIVEN** user is on home screen
- **前置条件**：用户在主屏幕上
- **WHEN** user presses Cmd/Ctrl+F
- **操作**：用户按下 Cmd/Ctrl+F
- **THEN** search field SHALL receive focus
- **预期结果**：搜索字段应获得焦点
- **AND** existing text SHALL be selected
- **并且**：现有文本应被选中

---

## 3. Real-Time Filtering | 实时过滤

### Requirement: Search SHALL filter in real-time | 需求：搜索应实时过滤

Search SHALL filter cards in real-time.

搜索应实时过滤卡片。

#### Scenario: Results update as user types | 场景：用户输入时结果更新

- **GIVEN** user types in search field
- **前置条件**：用户在搜索字段中输入
- **WHEN** user enters text
- **操作**：用户输入文本
- **THEN** card grid SHALL filter immediately
- **预期结果**：卡片网格应立即过滤
- **AND** only matching cards SHALL be visible
- **并且**：只有匹配的卡片应可见
- **AND** filtering SHALL be smooth (no flicker)
- **并且**：过滤应平滑（无闪烁）

#### Scenario: Filtering completes within 200ms | 场景：过滤在 200ms 内完成

- **GIVEN** user types character
- **前置条件**：用户输入字符
- **WHEN** filtering occurs
- **操作**：过滤发生
- **THEN** filtering SHALL complete within 200ms
- **预期结果**：过滤应在 200ms 内完成
- **AND** UI SHALL remain responsive
- **并且**：UI 应保持响应

#### Scenario: Clearing search shows all cards | 场景：清空搜索显示所有卡片

- **GIVEN** search is active
- **前置条件**：搜索已激活
- **WHEN** user clears search field
- **操作**：用户清空搜索字段
- **THEN** all cards SHALL be visible again
- **预期结果**：所有卡片应再次可见
- **AND** transition SHALL be smooth
- **并且**：过渡应平滑

---

## 4. Match Highlighting | 匹配高亮

### Requirement: Search SHALL highlight matches | 需求：搜索应高亮匹配

Search SHALL highlight matching text.

搜索应高亮匹配文本。

#### Scenario: Matching text is highlighted | 场景：匹配文本被高亮

- **GIVEN** search results are shown
- **前置条件**：搜索结果已显示
- **WHEN** viewing cards
- **操作**：查看卡片
- **THEN** matching text SHALL be highlighted
- **预期结果**：匹配文本应被高亮
- **AND** highlight SHALL use primary color
- **并且**：高亮应使用主色
- **AND** highlight SHALL be visible
- **并且**：高亮应可见

#### Scenario: Multiple matches are highlighted | 场景：多个匹配被高亮

- **GIVEN** card has multiple matches
- **前置条件**：卡片有多个匹配
- **WHEN** viewing card
- **操作**：查看卡片
- **THEN** all matches SHALL be highlighted
- **预期结果**：所有匹配应被高亮
- **AND** highlights SHALL be consistent
- **并且**：高亮应一致

---

## 5. Empty Results | 空结果

### Requirement: Search SHALL show empty state | 需求：搜索应显示空状态

Search SHALL show empty state when no results.

搜索应在无结果时显示空状态。

#### Scenario: No results shows message | 场景：无结果显示消息

- **GIVEN** search has no matches
- **前置条件**：搜索无匹配
- **WHEN** viewing grid
- **操作**：查看网格
- **THEN** message SHALL say "未找到相关笔记"
- **预期结果**：消息应显示"未找到相关笔记"
- **AND** icon SHALL be displayed
- **并且**：图标应显示
- **AND** search term SHALL be shown
- **并且**：搜索词应显示

#### Scenario: Empty state suggests clearing | 场景：空状态建议清空

- **GIVEN** no results are shown
- **前置条件**：无结果显示
- **WHEN** viewing message
- **操作**：查看消息
- **THEN** suggestion SHALL say "尝试其他关键词"
- **预期结果**：建议应显示"尝试其他关键词"
- **AND** clear button SHALL be visible
- **并且**：清空按钮应可见

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
