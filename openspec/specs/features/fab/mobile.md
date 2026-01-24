# Mobile FAB Specification | 移动端浮动操作按钮规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active | 已完成
**Dependencies** | **依赖**: [adaptive_ui_components.md](../../ui_system/adaptive_ui_components.md)

---

## 1. Overview | 概述

### 1.1 Goals | 目标

Define mobile floating action button (FAB) specifications to ensure:

定义移动端浮动操作按钮（FAB）规范，确保：

- Easily reachable position | 易于触达的位置
- Clear visual feedback | 清晰的视觉反馈
- Aligned with Material Design specifications | 符合 Material Design 规范

### 1.2 Applicable Platforms | 适用平台

- Android
- iOS
- iPadOS (treated as mobile | 作为移动端处理)

---

## 2. FAB Position and Style | FAB 位置和样式

### Requirement: Mobile SHALL use FAB for primary action | 需求：移动端应使用 FAB 作为主要操作入口

Mobile SHALL use FAB for primary action.

移动端应使用 FAB 作为主要操作入口。

#### Scenario: FAB is at bottom-right | 场景：FAB 在右下角

- **GIVEN** user is on home screen
- **前置条件**：用户在主屏幕上
- **WHEN** viewing screen
- **操作**：查看屏幕
- **THEN** FAB SHALL be at bottom-right corner
- **预期结果**：FAB 应在右下角
- **AND** FAB SHALL be 56x56 logical pixels
- **并且**：FAB 应为 56x56 逻辑像素
- **AND** FAB SHALL use primary color
- **并且**：FAB 应使用主色

#### Scenario: FAB shows plus icon | 场景：FAB 显示加号图标

- **GIVEN** FAB is displayed
- **前置条件**：FAB 已显示
- **WHEN** viewing FAB
- **操作**：查看 FAB
- **THEN** FAB SHALL show "+" icon
- **预期结果**：FAB 应显示"+"图标
- **AND** icon SHALL be white
- **并且**：图标应为白色
- **AND** icon SHALL be 24x24 logical pixels
- **并且**：图标应为 24x24 逻辑像素

#### Scenario: FAB has elevation | 场景：FAB 有高度

- **GIVEN** FAB is displayed
- **前置条件**：FAB 已显示
- **WHEN** viewing FAB
- **操作**：查看 FAB
- **THEN** FAB SHALL have 6dp elevation
- **预期结果**：FAB 应有 6dp 高度
- **AND** shadow SHALL be visible
- **并且**：阴影应可见

---

## 3. FAB Interaction | FAB 交互

### Requirement: FAB SHALL respond to touch | 需求：FAB 应响应触摸交互

FAB SHALL respond to touch interaction.

FAB 应响应触摸交互。

#### Scenario: Tapping FAB opens editor
#### 场景：点击 FAB 打开编辑器

- **GIVEN** user taps FAB
- **前置条件**：用户点击 FAB
- **WHEN** FAB is tapped
- **操作**：FAB 被点击
- **THEN** fullscreen editor SHALL open
- **预期结果**：全屏编辑器应打开
- **AND** new card SHALL be created
- **并且**：新卡片应被创建
- **AND** title field SHALL have focus
- **并且**：标题字段应获得焦点

#### Scenario: FAB shows ripple effect
#### 场景：FAB 显示波纹效果

- **GIVEN** user taps FAB
- **前置条件**：用户点击 FAB
- **WHEN** touch occurs
- **操作**：触摸发生
- **THEN** ripple effect SHALL appear
- **预期结果**：波纹效果应出现
- **AND** ripple SHALL be white
- **并且**：波纹应为白色

#### Scenario: FAB is accessible within 1 second
#### 场景：FAB 在 1 秒内可访问

- **GIVEN** home screen loads
- **前置条件**：主屏幕加载
- **WHEN** 1 second passes
- **操作**：1 秒过去
- **THEN** FAB SHALL be interactive
- **预期结果**：FAB 应可交互
- **AND** tapping SHALL work
- **并且**：点击应有效

---

## 4. FAB Accessibility | FAB 可访问性

### Requirement: FAB SHALL be accessible
### 需求：FAB 应满足可访问性要求

FAB SHALL meet accessibility requirements.

FAB 应满足可访问性要求。

#### Scenario: FAB has minimum touch target
#### 场景：FAB 有最小触摸目标

- **GIVEN** FAB is displayed
- **前置条件**：FAB 已显示
- **WHEN** measuring touch target
- **操作**：测量触摸目标
- **THEN** touch target SHALL be at least 48x48 logical pixels
- **预期结果**：触摸目标应至少为 48x48 逻辑像素
- **AND** target SHALL extend beyond visual bounds
- **并且**：目标应超出视觉边界

#### Scenario: FAB has semantic label
#### 场景：FAB 有语义标签

- **GIVEN** screen reader is enabled
- **前置条件**：屏幕阅读器已启用
- **WHEN** FAB is focused
- **操作**：FAB 获得焦点
- **THEN** label SHALL announce "创建新笔记"
- **预期结果**：标签应朗读"创建新笔记"
- **AND** announcement SHALL be clear
- **并且**：朗读应清晰

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
