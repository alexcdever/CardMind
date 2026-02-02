## Context

CardMind 是一个基于 Flutter + Rust 的离线优先卡片笔记应用。当前应用缺乏标准化的卡片 UI 组件来展示笔记内容。项目采用双层架构（Loro CRDT + SQLite）和 OpenSpec 规范驱动开发。

设计文档位于 `/docs/plans/2026-01-25-note-card-ui-design.md`，包含了完整的 UI 设计规格，包括桌面端和移动端的差异化展示、交互行为、时间显示规则等详细要求。

## Goals / Non-Goals

**Goals:**
- 创建一个统一的 NoteCard Flutter Widget 组件，支持桌面端和移动端的差异化展示
- 实现高效的文本渲染和交互，支持大量卡片的流畅滚动（≥60 FPS）
- 提供完整的交互功能（点击编辑、右键/长按菜单、键盘导航等）
- 确保可访问性和国际化支持
- 建立可扩展的组件架构，为未来功能扩展奠定基础

**Non-Goals:**
- 修改现有的 Card 数据模型（仅添加 UI 辅助方法）
- 实现复杂的卡片动画效果（留给后续增强）
- 修改应用的整体架构或数据层
- 实现卡片的拖拽排序功能（未来扩展）

## Decisions

### 1. 组件架构：单一主组件 + 平台特定实现

**决策**: 使用 `NoteCard` 作为主组件，内部通过 `Platform.isDesktop` 判断平台，分别调用 `NoteCardDesktop` 和 `NoteCardMobile` 实现。

**理由**: 
- 保持 API 简洁，调用方只需使用一个组件
- 避免平台判断逻辑分散在应用的各个位置
- 便于维护和测试，平台特定代码隔离清晰

**替代方案考虑**: 
- 两个独立组件 `NoteCardDesktop`/`NoteCardMobile` - 需要调用方手动选择，增加复杂性
- 单一组件内大量 if-else - 代码可读性差，测试困难

### 2. 状态管理：无状态组件 + 外部状态

**决策**: NoteCard 组件设计为无状态 Widget，所有状态由父组件管理。

**理由**:
- 提高组件的可测试性和复用性
- 简化组件的渲染逻辑，专注于展示
- 便于集成到不同的状态管理方案（Provider、Riverpod 等）

**替代方案考虑**: 
- 组件内部管理状态 - 增加复杂性，难以与全局状态同步

### 3. 性能优化：虚拟滚动 + 懒加载

**决策**: 使用 `ListView.builder` 实现虚拟滚动，配合分页加载机制。

**理由**:
- 仅渲染可见区域的卡片，支持大量数据的流畅滚动
- Flutter 内置支持，成熟稳定
- 内存占用可控

**替代方案考虑**: 
- `flutter_staggered_grid_view` - 增加依赖，对于简单列表布局过于复杂
- 自定义实现 - 开发成本高，容易出错

### 4. 文本处理：自定义截断工具

**决策**: 创建专门的 `TextTruncator` 工具类，处理单行和多行文本截断。

**理由**:
- Flutter 的 `Text` 组件在多行截断方面功能有限
- 需要精确控制行数（桌面端4行、移动端3行）
- 便于单元测试和边界条件处理

**替代方案考虑**: 
- 直接使用 Flutter 的 `maxLines` 属性 - 无法精确控制省略号显示
- 使用第三方包 - 增加依赖，可能不符合具体需求

### 5. 时间格式化：自定义工具类

**决策**: 创建 `TimeFormatter` 工具类，实现相对时间和绝对时间的智能切换。

**理由**:
- 需要符合中文用户习惯的相对时间显示（"刚刚"、"X分钟前"等）
- 需要定时更新相对时间显示
- 便于单元测试和国际化扩展

**替代方案考虑**: 
- 使用 `intl` 包 - 功能过于复杂，包体积较大
- 直接在组件内处理 - 逻辑分散，难以测试

## Risks / Trade-offs

### 性能风险：大量卡片渲染
**风险**: 当卡片数量超过 1000 时可能出现性能问题
**缓解措施**: 
- 使用 `RepaintBoundary` 隔离重绘区域
- 实现图片懒加载和缩略图缓存
- 添加性能监控和基准测试

### 兼容性风险：不同平台的 UI 差异
**风险**: 桌面端和移动端的交互差异可能导致用户体验不一致
**缓解措施**: 
- 详细的平台差异文档和测试用例
- 共享核心逻辑，仅分离 UI 特定代码
- 充分的跨平台测试

### 维护风险：组件复杂度增加
**风险**: NoteCard 组件可能变得过于复杂，难以维护
**缓解措施**: 
- 严格遵循单一职责原则，将功能拆分为小的工具类
- 完整的单元测试和 Widget 测试覆盖
- 定期重构和代码审查

### 国际化风险：文本硬编码
**风险**: 用户界面文本可能硬编码，影响国际化
**缓解措施**: 
- 所有用户可见文本使用 Flutter 的国际化机制
- 创建专门的 l10n 资源文件
- 测试不同语言环境下的显示效果

## Migration Plan

### 阶段 1：核心组件开发
1. 创建基础 NoteCard 组件结构
2. 实现桌面端和移动端的基础布局
3. 添加基本的文本显示功能

### 阶段 2：交互功能实现
1. 实现点击打开编辑器的功能
2. 添加上下文菜单系统
3. 实现键盘导航和无障碍支持

### 阶段 3：性能优化和测试
1. 实现虚拟滚动和懒加载
2. 添加性能监控和优化
3. 完善测试覆盖率

### 阶段 4：集成和部署
1. 集成到主应用的卡片列表页面
2. 进行端到端测试
3. 部署到测试环境进行用户验证

### 回滚策略
- 每个 Pull Request 保持独立，可单独回滚
- 使用 feature flag 控制新功能的启用
- 保留旧版卡片组件作为备份（如果存在）

## Visual Layout Specifications

### Desktop Platform Layout

```
┌─────────────────────────────────────┐
│ 标题文本（单行，超出显示省略号）      │
│ ─────────────────────────────────── │
│ 内容预览第1行                        │
│ 内容预览第2行                        │
│ 内容预览第3行                        │
│ 内容预览第4行（超出显示省略号）      │
│ ─────────────────────────────────── │
│ 更新时间                             │
└─────────────────────────────────────┘
```

**Display Rules:**
- **Title**: Single line with ellipsis (...) for overflow
- **Content Preview**: Maximum 4 lines with ellipsis for overflow
- **Time Display**: Bottom-right corner showing relative or absolute time
- **Card Size**: Fixed width, height auto-adjusts to content

### Mobile Platform Layout

```
┌─────────────────────────────────────┐
│ 标题文本（单行，超出显示省略号）      │
│ ─────────────────────────────────── │
│ 内容预览第1行                        │
│ 内容预览第2行                        │
│ 内容预览第3行（超出显示省略号）      │
│ ─────────────────────────────────── │
│ 更新时间                             │
└─────────────────────────────────────┘
```

**Display Rules:**
- **Title**: Single line with ellipsis for overflow
- **Content Preview**: Maximum 3 lines (1 line less than desktop)
- **Time Display**: Bottom-right corner showing relative or absolute time
- **Card Size**: Full-width layout, adapts to screen width

### Platform Differences Comparison

| Feature | Desktop | Mobile |
|---------|---------|--------|
| Content Preview Lines | 4 lines | 3 lines |
| Primary Interaction | Single click | Single click |
| Context Menu Trigger | Right-click | Long press (500ms) |
| Editor Type | Modal dialog | Full-screen editor |
| Hover Effects | Supported | Not supported |
| Haptic Feedback | Not supported | Supported |
| Keyboard Navigation | Supported | Not supported |
| Swipe Gestures | Not supported | Supported (optional) |

## Interaction Effects and Context Menu

### Desktop Interaction Effects

**Hover Effects:**
- Subtle shadow and border highlight on mouse hover
- Cursor changes to pointer
- Smooth transition effects

**Click Behavior:**
- Single click opens modal dialog editor
- Dialog centered with semi-transparent overlay
- ESC key support for closing
- No special behavior for double-click or middle-click

### Mobile Interaction Effects

**Touch Behavior:**
- Single click opens full-screen editor
- Long press (500ms) triggers context menu
- Haptic feedback on long press (if device supports)
- Support for back gesture to close editor

### Context Menu Specifications

#### Desktop Menu Items

1. **Edit (编辑)**
   - Icon: ✏️ Edit icon
   - Shortcut: Enter
   - Action: Open edit dialog

2. **Delete (删除)**
   - Icon: 🗑️ Delete icon
   - Shortcut: Delete
   - Action: Show confirmation dialog, delete card on confirmation

3. **View Details (查看详情)**
   - Icon: ℹ️ Info icon
   - Shortcut: Ctrl+I
   - Action: Open details panel with full metadata

4. **Copy Content (复制内容)**
   - Icon: 📋 Copy icon
   - Shortcut: Ctrl+C
   - Action: Copy card content to clipboard

#### Mobile Menu Items

1. **Edit (编辑)**
   - Icon: ✏️ Edit icon
   - Action: Open full-screen editor

2. **Delete (删除)**
   - Icon: 🗑️ Delete icon
   - Action: Show confirmation dialog, delete card on confirmation

3. **Share (分享)**
   - Icon: 📤 Share icon
   - Action: Open system share panel

4. **Copy Content (复制内容)**
   - Icon: 📋 Copy icon
   - Action: Copy card content to clipboard

### Menu Trigger Methods

#### Desktop
- **Right-click**: Anywhere on the card
- **Keyboard trigger**: Menu key or Shift+F10 when card is focused
- **Position**: Near mouse cursor, auto-adjusts to stay on screen

#### Mobile
- **Long press**: 500ms duration on the card
- **Haptic feedback**: Provided on trigger (if supported)
- **Position**: Bottom sheet menu

## Time Display Rules and Edge Cases

### Relative Time Display (within 24 hours)

| Time Difference | Display Text | Example |
|------------------|--------------|---------|
| 0-10 seconds | "刚刚" (Just now) | 刚刚 |
| 11-59 seconds | "X秒前" (X seconds ago) | 30秒前 |
| 1-59 minutes | "X分钟前" (X minutes ago) | 15分钟前 |
| 1-23 hours | "X小时前" (X hours ago) | 3小时前 |

### Absolute Time Display (over 24 hours)

| Time Range | Display Format | Example |
|------------|----------------|---------|
| Current year | MM-DD HH:mm | 01-20 14:30 |
| Previous years | YYYY-MM-DD HH:mm | 2025-12-25 09:15 |

### Edge Case Handling

**Empty Card Placeholders:**
- Empty title: Display "无标题" (No Title) in gray text
- Empty content: Display "点击添加内容..." (Click to add content...) in gray placeholder text
- Empty time: Display "未知时间" (Unknown time) (should not occur, data anomaly)

**Timezone Handling:**
- All timestamps stored in UTC
- Display converted to user's local timezone
- Maintain consistency across timezone synchronization

**Special Cases:**
- Future time: Display "刚刚" (Just now) if `updatedAt` is in future (clock skew)
- Too early time: Display "未知时间" (Unknown time) if `updatedAt` is before 1970-01-01
- Invalid time: Display "未知时间" (Unknown time) if timestamp is unparseable

### Auto-update Strategy

- **Relative time**: Update every 60 seconds
- **Absolute time**: No auto-update needed
- **Performance optimization**: Use timer to batch update visible card time displays

## Performance Benchmarks and Data Models

### Performance Requirements

**Rendering Performance:**
- 1000-card list scrolling frame rate: ≥ 60 FPS
- Memory usage for 1000 cards: ≤ 100 MB
- First-screen loading time (20 cards): ≤ 500ms
- Click-to-open editor response time: ≤ 100ms

### Optimization Strategies

**Virtual Scrolling:**
- Use `ListView.builder` for visible area rendering only
- Support dynamic height calculation
- Implement smooth scrolling

**Lazy Loading:**
- Paginated card data loading (20-50 cards per page)
- Auto-load next page when scrolling to bottom
- Show loading indicator

**Caching Strategy:**
- Cache rendered card layout information
- Cache time formatting results (reuse within 60 seconds)
- Use `RepaintBoundary` to isolate redraw areas

### Data Model Definitions

#### Rust Side Model (rust/src/models/card.rs)

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Card {
    pub id: String,
    pub title: String,
    pub content: String,
    pub tags: Vec<String>,
    pub created_at: i64,
    pub updated_at: i64,
    pub last_edit_device: String,
}
```

#### Dart Side Model (lib/models/card.dart)

```dart
class Card {
  final String id;
  final String title;
  final String content;
  final List<String> tags;
  final int createdAt;
  final int updatedAt;
  final String lastEditDevice;

  Card({
    required this.id,
    required this.title,
    required this.content,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    required this.lastEditDevice,
  });

  factory Card.fromJson(Map<String, dynamic> json) {
    return Card(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      tags: List<String>.from(json['tags'] as List),
      createdAt: json['created_at'] as int,
      updatedAt: json['updated_at'] as int,
      lastEditDevice: json['last_edit_device'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'tags': tags,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'last_edit_device': lastEditDevice,
    };
  }
}
```

### Display Field Mapping

| Field | Data Source | Display Position | Formatting Rules |
|-------|-------------|------------------|-----------------|
| Title | `title` | Card top | Single line truncation |
| Content Preview | `content` | Card middle | Multi-line truncation (desktop 4 lines / mobile 3 lines) |
| Update Time | `updated_at` | Card bottom | Relative/absolute time format |

**Fields Not Displayed:**
- `tags`: Not shown on cards, only for filtering and search
- `last_edit_device`: Not shown on cards, only for sync conflict resolution
- `created_at`: Creation time not shown, only display update time

## File Structure and Organization

### Implementation File Structure

```
lib/
├── widgets/
│   ├── note_card.dart              # Main card component
│   ├── note_card_desktop.dart      # Desktop-specific implementation
│   ├── note_card_mobile.dart       # Mobile-specific implementation
│   └── note_card_context_menu.dart # Context menu component
├── utils/
│   ├── time_formatter.dart         # Time formatting utility
│   └── text_truncator.dart         # Text truncation utility
├── models/
│   └── card.dart                   # Card data model (Dart side)
└── screens/
    ├── card_edit_dialog.dart       # Desktop edit dialog
    └── card_edit_screen.dart       # Mobile full-screen editor

test/
├── unit/
│   ├── time_formatter_test.dart    # Time formatting unit tests
│   ├── text_truncator_test.dart    # Text truncation unit tests
│   └── card_model_test.dart        # Data model unit tests
└── widget/
    ├── note_card_test.dart         # Card component widget tests
    ├── note_card_interaction_test.dart  # Interaction behavior tests
    ├── note_card_context_menu_test.dart # Context menu tests
    └── note_card_time_display_test.dart # Time display tests
```

## Internationalization and Accessibility

### Internationalization Resources

**Text Resources (lib/l10n/app_zh.arb):**

```json
{
  "noteCard_noTitle": "无标题",
  "noteCard_emptyContent": "点击添加内容...",
  "noteCard_unknownTime": "未知时间",
  "noteCard_justNow": "刚刚",
  "noteCard_secondsAgo": "{seconds}秒前",
  "noteCard_minutesAgo": "{minutes}分钟前",
  "noteCard_hoursAgo": "{hours}小时前",
  "noteCard_edit": "编辑",
  "noteCard_delete": "删除",
  "noteCard_viewDetails": "查看详情",
  "noteCard_copyContent": "复制内容",
  "noteCard_share": "分享",
  "noteCard_deleteConfirm": "确定要删除这张卡片吗？",
  "noteCard_deleteSuccess": "卡片已删除",
  "noteCard_copySuccess": "内容已复制到剪贴板"
}
```

### Accessibility Requirements

**Semantic Labels:**
- Add `Semantics` labels to cards
- Provide semantic descriptions for title and content
- Provide readable semantic text for time information

**Keyboard Navigation:**
- Support Tab key to focus cards
- Support Enter key to open editor
- Support arrow keys to switch between cards
- Support ESC key to close dialog

**Screen Reader Support:**
- Card content correctly read by screen readers
- Buttons and menu items provide clear voice prompts
- Status changes (like deletion success) provide voice feedback

**Contrast and Fonts:**
- Text and background contrast ratio ≥ 4.5:1 (WCAG AA standard)
- Support system font scaling
- Support dark mode

## Open Questions

1. **动画效果**: 是否需要添加卡片悬停、点击等微交互动画？
   - 当前设计文档中未明确要求，可能与性能需求冲突
   - 需要与产品团队确认优先级

2. **主题系统**: 如何与深色模式等主题系统集成？
   - 需要了解应用当前的主题系统实现
   - 确保卡片组件适配所有主题变体

3. **数据同步**: 卡片编辑后的数据如何与 P2P 同步系统集成？
   - 需要了解同步系统的 API 设计
   - 确保编辑操作的冲突解决策略

4. **测试数据**: 如何生成足够多样的测试数据来验证边界条件？
   - 需要考虑各种字符长度、特殊字符、空数据等情况
   - 可能需要开发专门的测试数据生成工具