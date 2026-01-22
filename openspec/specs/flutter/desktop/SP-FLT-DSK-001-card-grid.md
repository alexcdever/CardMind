# Desktop Card Grid Specification

## 📋 规格编号: SP-FLT-DSK-001
**版本**: 1.0.0
**状态**: 已完成
**依赖**: 
- SP-FLT-DSK-* (桌面端 UI 交互规格)
- SP-ADAPT-005 (桌面端 UI 模式规格)
- SP-CARD-004 (CardStore 规格)

---

## 1. 概述

### 1.1 目标
定义桌面端卡片网格布局规范，确保：
- 多列网格布局，充分利用宽屏
- 响应式列数调整
- 流畅的网格滚动
- 卡片拖拽排序

### 1.2 适用平台
- macOS
- Windows
- Linux

---

## 2. 网格布局

### Requirement: Desktop SHALL use grid layout

桌面端 SHALL 使用网格布局显示卡片。

#### Scenario: Cards are displayed in grid
- **GIVEN** user has multiple cards
- **WHEN** viewing home screen
- **THEN** cards SHALL be displayed in grid
- **AND** grid SHALL have multiple columns
- **AND** column count SHALL adapt to width

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
- **AND** scrolling SHALL be smooth (60fps)
- **AND** scroll bar SHALL be visible

---

## 3. 响应式列数

### Requirement: Grid SHALL adapt column count

网格 SHALL 根据窗口宽度调整列数。

#### Scenario: Wide window shows 3+ columns
- **GIVEN** window width is 1600px+
- **WHEN** viewing grid
- **THEN** grid SHALL show 3 or more columns
- **AND** cards SHALL fill available space

#### Scenario: Medium window shows 2 columns
- **GIVEN** window width is 1200-1600px
- **WHEN** viewing grid
- **THEN** grid SHALL show 2 columns
- **AND** cards SHALL be properly sized

#### Scenario: Narrow window shows 1 column
- **GIVEN** window width is 800-1200px
- **WHEN** viewing grid
- **THEN** grid SHALL show 1 column
- **AND** cards SHALL be full-width

---

## 4. 卡片显示

### Requirement: Desktop cards SHALL show full content

桌面端卡片 SHALL 显示完整内容预览。

#### Scenario: Card shows title
- **GIVEN** card is displayed in grid
- **WHEN** viewing card
- **THEN** card SHALL show title in bold
- **AND** title SHALL be truncated if too long
- **AND** title SHALL use 20px font size

#### Scenario: Card shows content preview
- **GIVEN** card is displayed in grid
- **WHEN** viewing card
- **THEN** card SHALL show first 5 lines of content
- **AND** content SHALL be truncated with "..."
- **AND** content SHALL use 16px font size

#### Scenario: Card shows metadata
- **GIVEN** card is displayed in grid
- **WHEN** viewing card
- **THEN** card SHALL show last updated time
- **AND** time SHALL use relative format ("2小时前")
- **AND** metadata SHALL use 14px font size

---

## 5. 悬停效果

### Requirement: Desktop cards SHALL show hover effects

桌面端卡片 SHALL 显示悬停效果。

#### Scenario: Hovering card shows elevation
- **GIVEN** user hovers over card
- **WHEN** mouse enters card area
- **THEN** card SHALL show elevated shadow
- **AND** elevation SHALL increase smoothly
- **AND** transition SHALL be 200ms

#### Scenario: Hovering shows action buttons
- **GIVEN** user hovers over card
- **WHEN** mouse enters card area
- **THEN** edit and delete buttons SHALL appear
- **AND** buttons SHALL fade in smoothly
- **AND** buttons SHALL be in top-right corner

#### Scenario: Leaving card hides effects
- **GIVEN** hover effects are shown
- **WHEN** mouse leaves card area
- **THEN** elevation SHALL return to normal
- **AND** action buttons SHALL fade out
- **AND** transition SHALL be smooth

---

## 6. 性能要求

### Requirement: Desktop grid SHALL be performant

桌面端网格 SHALL 满足性能要求。

#### Scenario: Grid scrolling maintains 60fps
- **GIVEN** user scrolls grid
- **WHEN** scrolling
- **THEN** frame rate SHALL be 60fps
- **AND** no frame drops SHALL occur

#### Scenario: Cards load within 350ms
- **GIVEN** user opens home screen
- **WHEN** loading cards
- **THEN** cards SHALL appear within 350ms
- **AND** loading indicator SHALL be shown

#### Scenario: Hover effects appear within 50ms
- **GIVEN** user hovers over card
- **WHEN** mouse enters
- **THEN** effects SHALL appear within 50ms
- **AND** transition SHALL be smooth

---

**最后更新**: 2026-01-19
**作者**: CardMind Team
