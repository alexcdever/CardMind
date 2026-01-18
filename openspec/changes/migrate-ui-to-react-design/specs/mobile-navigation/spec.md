# Mobile Navigation Specification

## ADDED Requirements

### Requirement: Bottom navigation bar
系统 SHALL 在移动端显示底部导航栏。

#### Scenario: 显示导航栏
- **WHEN** 应用在移动端平台运行
- **THEN** 屏幕底部显示固定的导航栏，包含三个标签页：笔记、设备、设置

#### Scenario: 隐藏导航栏（桌面端）
- **WHEN** 应用在桌面端平台运行
- **THEN** 底部导航栏不显示

### Requirement: Tab switching
系统 SHALL 支持标签页切换功能。

#### Scenario: 切换到笔记标签页
- **WHEN** 用户点击"笔记"标签
- **THEN** 系统显示笔记列表页面，"笔记"标签高亮显示

#### Scenario: 切换到设备标签页
- **WHEN** 用户点击"设备"标签
- **THEN** 系统显示设备管理页面，"设备"标签高亮显示

#### Scenario: 切换到设置标签页
- **WHEN** 用户点击"设置"标签
- **THEN** 系统显示设置页面，"设置"标签高亮显示

### Requirement: Tab state preservation
系统 SHALL 保持标签页的状态。

#### Scenario: 保持页面状态
- **WHEN** 用户在标签页之间切换
- **THEN** 每个标签页的滚动位置和输入状态保持不变

### Requirement: Badge indicators
系统 SHALL 在标签上显示徽章指示器。

#### Scenario: 显示笔记数量
- **WHEN** 渲染笔记标签
- **THEN** 标签显示当前笔记总数的徽章

#### Scenario: 显示设备数量
- **WHEN** 渲染设备标签
- **THEN** 标签显示已配对设备数量的徽章

#### Scenario: 大数量显示
- **WHEN** 徽章数量超过 99
- **THEN** 徽章显示"99+"

### Requirement: Active tab indicator
系统 SHALL 显示当前激活的标签。

#### Scenario: 高亮激活标签
- **WHEN** 标签被选中
- **THEN** 标签图标和文字使用主题色，顶部显示指示条

#### Scenario: 非激活标签样式
- **WHEN** 标签未被选中
- **THEN** 标签图标和文字使用灰色
