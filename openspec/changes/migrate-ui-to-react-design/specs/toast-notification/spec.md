# Toast Notification Specification

## ADDED Requirements

### Requirement: Display toast notifications
系统 SHALL 显示 Toast 通知以提供操作反馈。

#### Scenario: 显示成功通知
- **WHEN** 用户完成一个成功的操作（如创建笔记、保存更改）
- **THEN** 系统显示绿色的成功 Toast，包含操作描述

#### Scenario: 显示错误通知
- **WHEN** 操作失败（如同步失败、保存失败）
- **THEN** 系统显示红色的错误 Toast，包含错误信息

#### Scenario: 显示信息通知
- **WHEN** 系统需要通知用户一般信息（如收到同步数据）
- **THEN** 系统显示蓝色的信息 Toast

### Requirement: Toast positioning
系统 SHALL 在合适的位置显示 Toast。

#### Scenario: 移动端底部显示
- **WHEN** 在移动端显示 Toast
- **THEN** Toast 显示在屏幕底部，距离底部导航栏 80px

#### Scenario: 桌面端顶部显示
- **WHEN** 在桌面端显示 Toast
- **THEN** Toast 显示在屏幕顶部右侧

### Requirement: Toast auto-dismiss
系统 SHALL 自动关闭 Toast 通知。

#### Scenario: 成功通知自动关闭
- **WHEN** 显示成功 Toast
- **THEN** Toast 在 2 秒后自动消失

#### Scenario: 错误通知延长显示
- **WHEN** 显示错误 Toast
- **THEN** Toast 在 4 秒后自动消失

#### Scenario: 手动关闭
- **WHEN** 用户点击 Toast 的关闭按钮
- **THEN** Toast 立即消失

### Requirement: Toast stacking
系统 SHALL 支持多个 Toast 同时显示。

#### Scenario: 多个通知堆叠
- **WHEN** 系统连续发送多个 Toast
- **THEN** Toast 垂直堆叠显示，最新的在最上方

#### Scenario: 限制最大数量
- **WHEN** Toast 数量超过 3 个
- **THEN** 系统自动移除最旧的 Toast

### Requirement: Toast animation
系统 SHALL 为 Toast 提供动画效果。

#### Scenario: 进入动画
- **WHEN** Toast 显示
- **THEN** Toast 从底部（移动端）或右侧（桌面端）滑入

#### Scenario: 退出动画
- **WHEN** Toast 关闭
- **THEN** Toast 淡出并滑出屏幕
