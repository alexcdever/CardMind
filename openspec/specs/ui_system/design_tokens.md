# ADR-0004: UI Design System
# ADR-0004: UI 设计系统

**Status** | **状态**: Accepted | 已接受
**Date** | **日期**: 2026-01-08
**Deciders** | **决策者**: CardMind Team

---

## Overview | 概述

This document records UI design system decisions including colors, typography, spacing, and layout.

本文档记录了 UI 设计系统的决策，包括颜色、字体、间距和布局。

---

## 1. Color System | 颜色系统

### Primary Color: Teal | 主色：青色

**Decision** | **决策**: Use **Teal (#00BFA5)** as the primary color.

使用**青色 (#00BFA5)** 作为主色。

| Competitor 竞品 | Primary Color 主色 |
|-----------------|-------------------|
| Notion | Purple 紫色 |
| Obsidian | Purple/Blue 紫色/蓝色 |
| **CardMind** | **Teal 青色** |

### Requirement: Color Application | 需求：颜色应用

The system SHALL use consistent color semantics.

系统应使用一致的颜色语义。

#### Scenario: Success state | 场景：成功状态

- **GIVEN** an operation completes successfully
- **前置条件**：操作成功完成
- **WHEN** displaying feedback
- **操作**：显示反馈
- **THEN** the system SHALL use green color
- **预期结果**：系统应使用绿色

#### Scenario: Error state | 场景：错误状态

- **GIVEN** an error occurs
- **前置条件**：发生错误
- **WHEN** displaying error feedback
- **操作**：显示错误反馈
- **THEN** the system SHALL use red color
- **预期结果**：系统应使用红色

---

## 2. Typography | 字体排版

### Font Family | 字体系列

**Decision** | **决策**: Use platform-native system fonts.

使用平台原生系统字体。

| Platform 平台 | Font 字体 |
|---------------|----------|
| iOS | SF Pro |
| Android | Roboto |
| Windows | Segoe UI |
| macOS | SF Pro |
| Linux | Cantarell |

### Requirement: Typography Scale | 需求：字体等级

The system SHALL use consistent typography hierarchy.

系统应使用一致的字体层次结构。

| Style 样式 | Size 大小 | Weight 字重 |
|-----------|----------|------------|
| Display 展示 | 32sp | Bold 粗体 |
| Headline 标题 | 24sp | SemiBold 半粗 |
| Title 子标题 | 20sp | Medium 中等 |
| Body 正文 | 16sp | Regular 常规 |
| Caption 说明 | 12sp | Regular 常规 |

---

## 3. Spacing System | 间距系统

### Grid Baseline | 网格基线

**Decision** | **决策**: Use 8px baseline grid for consistent spacing.

使用 8px 基线网格以保持一致的间距。

### Requirement: Spacing Application | 需求：间距应用

The system SHALL use 8px increments for all spacing.

系统应对所有间距使用 8px 的倍数。

#### Scenario: Component padding | 场景：组件内边距

- **GIVEN** a card component
- **前置条件**：有一个卡片组件
- **WHEN** applying internal padding
- **操作**：应用内部内边距
- **THEN** the padding SHALL be multiples of 8px (8, 16, 24, etc.)
- **预期结果**：内边距应为 8px 的倍数（8、16、24 等）

#### Scenario: Component spacing | 场景：组件间距

- **GIVEN** multiple components in a layout
- **前置条件**：布局中有多个组件
- **WHEN** spacing between components
- **操作**：设置组件间距
- **THEN** the gap SHALL be multiples of 8px
- **预期结果**：间隙应为 8px 的倍数

---

## 4. Layout System | 布局系统

### Responsive Design | 响应式设计

**Decision** | **决策**: Support phone, tablet, and desktop form factors.

支持手机、平板和桌面端形态。

### Requirement: Responsive Layout | 需求：响应式布局

The system SHALL adapt layout based on screen size.

系统应根据屏幕尺寸调整布局。

#### Scenario: Phone layout | 场景：手机布局

- **GIVEN** a device with width < 600dp
- **前置条件**：设备宽度 < 600dp
- **WHEN** rendering the main content
- **操作**：渲染主内容
- **THEN** use single-column layout
- **预期结果**：使用单列布局

#### Scenario: Tablet layout | 场景：平板布局

- **GIVEN** a device with width >= 600dp
- **前置条件**：设备宽度 >= 600dp
- **WHEN** rendering the main content
- **操作**：渲染主内容
- **THEN** use two-column layout
- **预期结果**：使用双列布局

---

**Related Documents** | **相关文档**: [UI Design System](../../docs/interaction/ui_design_system.md)

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
