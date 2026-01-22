# Desktop Card Grid Specification
# 桌面端卡片网格规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active | 已完成
**Dependencies** | **依赖**: [card_store.md](../../domain/card_store.md), [adaptive_ui_components.md](../../ui_system/adaptive_ui_components.md)

---

## 1. Overview | 概述

### 1.1 Goals | 目标

Define desktop card grid layout specifications to ensure:

定义桌面端卡片网格布局规范，确保：

- Multi-column grid layout, fully utilizing wide screens | 多列网格布局，充分利用宽屏
- Responsive column count adjustment | 响应式列数调整
- Smooth grid scrolling | 流畅的网格滚动
- Card drag-and-drop sorting | 卡片拖拽排序

### 1.2 Applicable Platforms | 适用平台

- macOS
- Windows
- Linux

---

## 2. Grid Layout | 网格布局

### Requirement: Desktop SHALL use grid layout
### 需求：桌面端应使用网格布局

Desktop SHALL use grid layout to display cards.

桌面端应使用网格布局显示卡片。

#### Scenario: Cards are displayed in grid
#### 场景：卡片在网格中显示

- **GIVEN** user has multiple cards
- **前置条件**：用户有多张卡片
- **WHEN** viewing home screen
- **操作**：查看主屏幕
- **THEN** cards SHALL be displayed in grid
- **预期结果**：卡片应在网格中显示
- **AND** grid SHALL have multiple columns
- **并且**：网格应有多列
- **AND** column count SHALL adapt to width
- **并且**：列数应适应宽度

#### Scenario: Grid uses max cross-axis extent
#### 场景：网格使用最大交叉轴范围

- **GIVEN** cards are in grid
- **前置条件**：卡片在网格中
- **WHEN** viewing layout
- **操作**：查看布局
- **THEN** each card SHALL have max width of 400px
- **预期结果**：每张卡片应有最大宽度 400px
- **AND** cards SHALL maintain aspect ratio of 1.2
- **并且**：卡片应保持 1.2 的纵横比
- **AND** spacing SHALL be 16px
- **并且**：间距应为 16px

#### Scenario: Grid scrolls vertically
#### 场景：网格垂直滚动

- **GIVEN** user has many cards
- **前置条件**：用户有很多卡片
- **WHEN** cards exceed viewport height
- **操作**：卡片超过视口高度
- **THEN** grid SHALL scroll vertically
- **预期结果**：网格应垂直滚动
- **AND** scrolling SHALL be smooth (60fps)
- **并且**：滚动应流畅（60fps）
- **AND** scroll bar SHALL be visible
- **并且**：滚动条应可见

---

## 3. Responsive Column Count | 响应式列数

### Requirement: Grid SHALL adapt column count
### 需求：网格应调整列数

Grid SHALL adapt column count based on window width.

网格应根据窗口宽度调整列数。

#### Scenario: Wide window shows 3+ columns
#### 场景：宽窗口显示 3+ 列

- **GIVEN** window width is 1600px+
- **前置条件**：窗口宽度为 1600px+
- **WHEN** viewing grid
- **操作**：查看网格
- **THEN** grid SHALL show 3 or more columns
- **预期结果**：网格应显示 3 列或更多
- **AND** cards SHALL fill available space
- **并且**：卡片应填充可用空间

#### Scenario: Medium window shows 2 columns
#### 场景：中等窗口显示 2 列

- **GIVEN** window width is 1200-1600px
- **前置条件**：窗口宽度为 1200-1600px
- **WHEN** viewing grid
- **操作**：查看网格
- **THEN** grid SHALL show 2 columns
- **预期结果**：网格应显示 2 列
- **AND** cards SHALL be properly sized
- **并且**：卡片应适当调整大小

#### Scenario: Narrow window shows 1 column
#### 场景：窄窗口显示 1 列

- **GIVEN** window width is 800-1200px
- **前置条件**：窗口宽度为 800-1200px
- **WHEN** viewing grid
- **操作**：查看网格
- **THEN** grid SHALL show 1 column
- **预期结果**：网格应显示 1 列
- **AND** cards SHALL be full-width
- **并且**：卡片应全宽

---

## 4. Card Display | 卡片显示

### Requirement: Desktop cards SHALL show full content
### 需求：桌面端卡片应显示完整内容

Desktop cards SHALL show full content preview.

桌面端卡片应显示完整内容预览。

#### Scenario: Card shows title
#### 场景：卡片显示标题

- **GIVEN** card is displayed in grid
- **前置条件**：卡片在网格中显示
- **WHEN** viewing card
- **操作**：查看卡片
- **THEN** card SHALL show title in bold
- **预期结果**：卡片应以粗体显示标题
- **AND** title SHALL be truncated if too long
- **并且**：标题过长应截断
- **AND** title SHALL use 20px font size
- **并且**：标题应使用 20px 字号

#### Scenario: Card shows content preview
#### 场景：卡片显示内容预览

- **GIVEN** card is displayed in grid
- **前置条件**：卡片在网格中显示
- **WHEN** viewing card
- **操作**：查看卡片
- **THEN** card SHALL show first 5 lines of content
- **预期结果**：卡片应显示内容的前 5 行
- **AND** content SHALL be truncated with "..."
- **并且**：内容应以"..."截断
- **AND** content SHALL use 16px font size
- **并且**：内容应使用 16px 字号

#### Scenario: Card shows metadata
#### 场景：卡片显示元数据

- **GIVEN** card is displayed in grid
- **前置条件**：卡片在网格中显示
- **WHEN** viewing card
- **操作**：查看卡片
- **THEN** card SHALL show last updated time
- **预期结果**：卡片应显示最后更新时间
- **AND** time SHALL use relative format ("2小时前")
- **并且**：时间应使用相对格式（"2小时前"）
- **AND** metadata SHALL use 14px font size
- **并且**：元数据应使用 14px 字号

---

## 5. Hover Effects | 悬停效果

### Requirement: Desktop cards SHALL show hover effects
### 需求：桌面端卡片应显示悬停效果

Desktop cards SHALL show hover effects.

桌面端卡片应显示悬停效果。

#### Scenario: Hovering card shows elevation
#### 场景：悬停卡片显示提升

- **GIVEN** user hovers over card
- **前置条件**：用户悬停在卡片上
- **WHEN** mouse enters card area
- **操作**：鼠标进入卡片区域
- **THEN** card SHALL show elevated shadow
- **预期结果**：卡片应显示提升的阴影
- **AND** elevation SHALL increase smoothly
- **并且**：提升应平滑增加
- **AND** transition SHALL be 200ms
- **并且**：过渡应为 200ms

#### Scenario: Hovering shows action buttons
#### 场景：悬停显示操作按钮

- **GIVEN** user hovers over card
- **前置条件**：用户悬停在卡片上
- **WHEN** mouse enters card area
- **操作**：鼠标进入卡片区域
- **THEN** edit and delete buttons SHALL appear
- **预期结果**：编辑和删除按钮应出现
- **AND** buttons SHALL fade in smoothly
- **并且**：按钮应平滑淡入
- **AND** buttons SHALL be in top-right corner
- **并且**：按钮应在右上角

#### Scenario: Leaving card hides effects
#### 场景：离开卡片隐藏效果

- **GIVEN** hover effects are shown
- **前置条件**：悬停效果已显示
- **WHEN** mouse leaves card area
- **操作**：鼠标离开卡片区域
- **THEN** elevation SHALL return to normal
- **预期结果**：提升应恢复正常
- **AND** action buttons SHALL fade out
- **并且**：操作按钮应淡出
- **AND** transition SHALL be smooth
- **并且**：过渡应平滑

---

## 6. Performance Requirements | 性能要求

### Requirement: Desktop grid SHALL be performant
### 需求：桌面端网格应满足性能要求

Desktop grid SHALL meet performance requirements.

桌面端网格应满足性能要求。

#### Scenario: Grid scrolling maintains 60fps
#### 场景：网格滚动保持 60fps

- **GIVEN** user scrolls grid
- **前置条件**：用户滚动网格
- **WHEN** scrolling
- **操作**：滚动中
- **THEN** frame rate SHALL be 60fps
- **预期结果**：帧率应为 60fps
- **AND** no frame drops SHALL occur
- **并且**：不应有掉帧

#### Scenario: Cards load within 350ms
#### 场景：卡片在 350ms 内加载

- **GIVEN** user opens home screen
- **前置条件**：用户打开主屏幕
- **WHEN** loading cards
- **操作**：加载卡片
- **THEN** cards SHALL appear within 350ms
- **预期结果**：卡片应在 350ms 内出现
- **AND** loading indicator SHALL be shown
- **并且**：应显示加载指示器

#### Scenario: Hover effects appear within 50ms
#### 场景：悬停效果在 50ms 内出现

- **GIVEN** user hovers over card
- **前置条件**：用户悬停在卡片上
- **WHEN** mouse enters
- **操作**：鼠标进入
- **THEN** effects SHALL appear within 50ms
- **预期结果**：效果应在 50ms 内出现
- **AND** transition SHALL be smooth
- **并且**：过渡应平滑

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
