# Mobile Gestures Specification | 移动端手势规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active | 已完成
**Dependencies** | **依赖**: [adaptive_ui_components.md](../../ui_system/adaptive_ui_components.md)

---

## 1. Overview | 概述

### 1.1 Goals | 目标

Define mobile gesture interaction specifications to ensure:

定义移动端手势交互规范，确保：

- Smooth swipe gestures | 流畅的滑动手势
- Intuitive long-press operations | 直观的长按操作
- Platform-aligned gesture behavior | 符合平台习惯的手势行为

### 1.2 Applicable Platforms | 适用平台

- Android
- iOS
- iPadOS (treated as mobile | 作为移动端处理)

---

## 2. Swipe Gestures | 滑动手势

### Requirement: Mobile SHALL support swipe gestures | 需求：移动端应支持滑动手势

Mobile SHALL support swipe gestures for quick actions.

移动端应支持滑动手势进行快速操作。

#### Scenario: Swipe left reveals delete | 场景：左滑显示删除

- **GIVEN** user views card list
- **前置条件**：用户查看卡片列表
- **WHEN** user swipes left on card
- **操作**：用户在卡片上左滑
- **THEN** delete button SHALL be revealed
- **预期结果**：删除按钮应显示
- **AND** card SHALL slide left smoothly
- **并且**：卡片应平滑左滑
- **AND** button SHALL be red
- **并且**：按钮应为红色

#### Scenario: Swipe right dismisses action | 场景：右滑关闭操作

- **GIVEN** delete button is revealed
- **前置条件**：删除按钮已显示
- **WHEN** user swipes right
- **操作**：用户右滑
- **THEN** button SHALL be hidden
- **预期结果**：按钮应隐藏
- **AND** card SHALL slide back
- **并且**：卡片应滑回

#### Scenario: Tapping delete removes card | 场景：点击删除移除卡片

- **GIVEN** delete button is revealed
- **前置条件**：删除按钮已显示
- **WHEN** user taps delete
- **操作**：用户点击删除
- **THEN** card SHALL be soft-deleted
- **预期结果**：卡片应软删除
- **AND** card SHALL animate out
- **并且**：卡片应动画退出
- **AND** snackbar SHALL show "已删除"
- **并且**：提示条应显示"已删除"

---

## 3. Long-Press Gesture | 长按手势

### Requirement: Mobile SHALL support long-press | 需求：移动端应支持长按

Mobile SHALL support long-press gesture to open context menu.

移动端应支持长按手势打开上下文菜单。

#### Scenario: Long-press shows context menu | 场景：长按显示上下文菜单

- **GIVEN** user views card list
- **前置条件**：用户查看卡片列表
- **WHEN** user long-presses card
- **操作**：用户长按卡片
- **THEN** context menu SHALL appear
- **预期结果**：上下文菜单应出现
- **AND** menu SHALL include: "编辑", "删除", "分享"
- **并且**：菜单应包含："编辑"、"删除"、"分享"

#### Scenario: Context menu positioned near touch | 场景：上下文菜单靠近触摸点

- **GIVEN** context menu is shown
- **前置条件**：上下文菜单已显示
- **WHEN** viewing menu
- **操作**：查看菜单
- **THEN** menu SHALL appear near touch point
- **预期结果**：菜单应出现在触摸点附近
- **AND** menu SHALL not extend off screen
- **并且**：菜单不应超出屏幕

#### Scenario: Tapping outside dismisses menu | 场景：点击外部关闭菜单

- **GIVEN** context menu is shown
- **前置条件**：上下文菜单已显示
- **WHEN** user taps outside
- **操作**：用户点击外部
- **THEN** menu SHALL close
- **预期结果**：菜单应关闭
- **AND** no action SHALL occur
- **并且**：不应发生任何操作

---

## 4. Pull-to-Refresh | 下拉刷新

### Requirement: Mobile SHALL support pull-to-refresh | 需求：移动端应支持下拉刷新

Mobile SHALL support pull-to-refresh gesture.

移动端应支持下拉刷新手势。

#### Scenario: Pull down shows indicator | 场景：下拉显示指示器

- **GIVEN** user is at top of list
- **前置条件**：用户在列表顶部
- **WHEN** user pulls down
- **操作**：用户下拉
- **THEN** refresh indicator SHALL appear
- **预期结果**：刷新指示器应出现
- **AND** indicator SHALL follow pull distance
- **并且**：指示器应跟随下拉距离

#### Scenario: Release triggers refresh | 场景：释放触发刷新

- **GIVEN** user pulled past threshold
- **前置条件**：用户下拉超过阈值
- **WHEN** user releases
- **操作**：用户释放
- **THEN** system SHALL reload cards
- **预期结果**：系统应重新加载卡片
- **AND** indicator SHALL show loading
- **并且**：指示器应显示加载中

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
