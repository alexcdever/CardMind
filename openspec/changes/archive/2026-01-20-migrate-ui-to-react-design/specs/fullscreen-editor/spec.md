# Fullscreen Editor Specification

## ADDED Requirements

### Requirement: Fullscreen editing interface
系统 SHALL 在移动端提供全屏笔记编辑界面。

#### Scenario: 打开全屏编辑器
- **WHEN** 用户在移动端点击笔记卡片
- **THEN** 系统打开全屏编辑器，显示笔记的标题和内容输入框

#### Scenario: 关闭全屏编辑器
- **WHEN** 用户点击返回按钮或保存按钮
- **THEN** 系统关闭全屏编辑器，返回笔记列表

#### Scenario: 桌面端不显示
- **WHEN** 应用在桌面端运行
- **THEN** 全屏编辑器不显示，使用内联编辑模式

### Requirement: Edit note content
系统 SHALL 允许用户编辑笔记的标题和内容。

#### Scenario: 编辑标题
- **WHEN** 用户在标题输入框中输入文字
- **THEN** 标题实时更新

#### Scenario: 编辑内容
- **WHEN** 用户在内容输入框中输入文字
- **THEN** 内容实时更新

#### Scenario: 多行内容支持
- **WHEN** 用户输入多行文本
- **THEN** 内容输入框自动扩展以显示所有内容

### Requirement: Save changes
系统 SHALL 自动保存笔记更改。

#### Scenario: 保存笔记
- **WHEN** 用户点击保存按钮
- **THEN** 系统保存笔记更改，更新最后编辑时间和设备信息，关闭编辑器

#### Scenario: 自动保存草稿
- **WHEN** 用户输入内容后等待 2 秒
- **THEN** 系统自动保存草稿到本地存储

### Requirement: Tag management in editor
系统 SHALL 在编辑器中支持标签管理。

#### Scenario: 添加标签
- **WHEN** 用户在标签输入框中输入标签并按回车
- **THEN** 系统添加标签到笔记

#### Scenario: 删除标签
- **WHEN** 用户点击标签的删除按钮
- **THEN** 系统从笔记中删除该标签

### Requirement: Keyboard optimization
系统 SHALL 优化移动端键盘体验。

#### Scenario: 自动聚焦
- **WHEN** 打开全屏编辑器
- **THEN** 标题输入框自动获得焦点，弹出键盘

#### Scenario: 键盘避让
- **WHEN** 键盘弹出
- **THEN** 编辑器内容自动上移，避免被键盘遮挡

### Requirement: Discard changes
系统 SHALL 支持放弃更改功能。

#### Scenario: 放弃更改
- **WHEN** 用户点击取消按钮
- **THEN** 系统恢复笔记到原始状态，关闭编辑器
