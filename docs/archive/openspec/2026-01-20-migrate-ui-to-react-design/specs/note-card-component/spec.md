# Note Card Component Specification

## ADDED Requirements

### Requirement: Display note information
组件 SHALL 显示笔记的标题、内容、标签和元数据。

#### Scenario: 显示完整笔记信息
- **WHEN** 渲染笔记卡片
- **THEN** 卡片显示标题、内容预览（最多 4 行）、所有标签、最后编辑设备和更新时间

#### Scenario: 显示无标题笔记
- **WHEN** 笔记标题为空
- **THEN** 卡片显示"无标题笔记"作为占位符

#### Scenario: 显示空笔记内容
- **WHEN** 笔记内容为空
- **THEN** 卡片显示"空笔记"作为占位符

### Requirement: Inline editing mode
组件 SHALL 支持内联编辑模式（仅桌面端）。

#### Scenario: 进入编辑模式
- **WHEN** 用户点击卡片的编辑按钮
- **THEN** 卡片切换到编辑模式，显示可编辑的标题和内容输入框

#### Scenario: 保存编辑
- **WHEN** 用户在编辑模式下点击保存按钮
- **THEN** 系统保存笔记更新，卡片退出编辑模式，显示更新后的内容

#### Scenario: 取消编辑
- **WHEN** 用户在编辑模式下点击取消按钮
- **THEN** 卡片恢复到原始内容，退出编辑模式

### Requirement: Tag management
组件 SHALL 支持标签的添加和删除。

#### Scenario: 添加标签
- **WHEN** 用户在编辑模式下输入新标签并按回车
- **THEN** 系统添加标签到笔记，标签显示在卡片上

#### Scenario: 删除标签
- **WHEN** 用户点击标签上的删除图标
- **THEN** 系统从笔记中删除该标签

#### Scenario: 防止重复标签
- **WHEN** 用户尝试添加已存在的标签
- **THEN** 系统忽略该操作，不添加重复标签

### Requirement: Delete note
组件 SHALL 支持删除笔记功能。

#### Scenario: 删除笔记
- **WHEN** 用户点击删除按钮
- **THEN** 系统删除该笔记，卡片从列表中移除

### Requirement: Visual feedback
组件 SHALL 提供视觉反馈以增强用户体验。

#### Scenario: 悬停效果（桌面端）
- **WHEN** 用户鼠标悬停在卡片上
- **THEN** 卡片显示阴影效果，操作按钮变为可见

#### Scenario: 点击反馈（移动端）
- **WHEN** 用户点击卡片
- **THEN** 卡片显示缩放动画（scale 0.98）

#### Scenario: 显示协作标识
- **WHEN** 笔记最后由其他设备编辑
- **THEN** 卡片显示协作图标和设备名称

### Requirement: Responsive layout
组件 SHALL 适应不同的屏幕尺寸。

#### Scenario: 移动端单栏布局
- **WHEN** 在移动端显示笔记卡片
- **THEN** 卡片占据全宽，垂直排列

#### Scenario: 桌面端网格布局
- **WHEN** 在桌面端显示笔记卡片
- **THEN** 卡片以网格形式排列（1-2 列，根据屏幕宽度）
