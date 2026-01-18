# Sync Status Indicator Specification

## ADDED Requirements

### Requirement: Display sync status
系统 SHALL 实时显示同步状态。

#### Scenario: 显示已同步状态
- **WHEN** 系统处于已同步状态
- **THEN** 指示器显示绿色的同步图标和"已同步"文字

#### Scenario: 显示同步中状态
- **WHEN** 系统正在同步数据
- **THEN** 指示器显示旋转的同步图标和"同步中"文字

#### Scenario: 显示断开连接状态
- **WHEN** 系统未连接到任何设备
- **THEN** 指示器显示灰色的断开图标和"未连接"文字

#### Scenario: 显示同步失败状态
- **WHEN** 同步过程中发生错误
- **THEN** 指示器显示红色的错误图标和"同步失败"文字

### Requirement: Display last sync time
系统 SHALL 显示最后同步时间。

#### Scenario: 显示相对时间
- **WHEN** 最后同步时间在 1 分钟内
- **THEN** 指示器显示"刚刚同步"

#### Scenario: 显示分钟前
- **WHEN** 最后同步时间在 1 小时内
- **THEN** 指示器显示"X 分钟前"

#### Scenario: 显示小时前
- **WHEN** 最后同步时间在 24 小时内
- **THEN** 指示器显示"X 小时前"

#### Scenario: 显示具体时间
- **WHEN** 最后同步时间超过 24 小时
- **THEN** 指示器显示具体的日期和时间

### Requirement: Display syncing peers
系统 SHALL 显示正在同步的设备数量。

#### Scenario: 显示同步设备数
- **WHEN** 系统正在与多个设备同步
- **THEN** 指示器显示"正在与 X 个设备同步"

### Requirement: Visual feedback
系统 SHALL 提供视觉反馈以增强用户体验。

#### Scenario: 同步动画
- **WHEN** 系统正在同步
- **THEN** 同步图标显示旋转动画

#### Scenario: 状态颜色
- **WHEN** 显示不同的同步状态
- **THEN** 指示器使用对应的颜色（绿色=已同步，蓝色=同步中，灰色=未连接，红色=失败）

### Requirement: Responsive display
系统 SHALL 适应不同的显示位置。

#### Scenario: 桌面端顶部显示
- **WHEN** 在桌面端显示同步状态
- **THEN** 指示器显示在顶部导航栏右侧

#### Scenario: 移动端简化显示
- **WHEN** 在移动端显示同步状态
- **THEN** 指示器仅显示图标，不显示文字（节省空间）
