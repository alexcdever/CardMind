# Card Editor Specification

## MODIFIED Requirements

### Requirement: Platform-specific editing mode
卡片编辑器 SHALL 根据平台提供不同的编辑模式。

#### Scenario: 移动端全屏编辑
- **WHEN** 用户在移动端编辑笔记
- **THEN** 系统打开全屏编辑器，提供沉浸式编辑体验

#### Scenario: 桌面端内联编辑
- **WHEN** 用户在桌面端编辑笔记
- **THEN** 系统在笔记卡片内切换到编辑模式，无需跳转页面

### Requirement: Edit note fields
编辑器 SHALL 允许用户编辑笔记的所有字段。

#### Scenario: 编辑标题
- **WHEN** 用户在标题输入框中输入文字
- **THEN** 标题实时更新

#### Scenario: 编辑内容
- **WHEN** 用户在内容输入框中输入文字
- **THEN** 内容实时更新

#### Scenario: 管理标签
- **WHEN** 用户添加或删除标签
- **THEN** 标签列表实时更新

### Requirement: Save changes
编辑器 SHALL 保存笔记更改。

#### Scenario: 保存笔记
- **WHEN** 用户点击保存按钮
- **THEN** 系统保存笔记到 Loro CRDT，更新最后编辑时间和设备信息

#### Scenario: 自动保存（移动端）
- **WHEN** 用户在全屏编辑器中输入内容后等待 2 秒
- **THEN** 系统自动保存草稿到本地

### Requirement: Discard changes
编辑器 SHALL 支持放弃更改。

#### Scenario: 取消编辑
- **WHEN** 用户点击取消按钮
- **THEN** 系统恢复笔记到原始状态，退出编辑模式

### Requirement: Update metadata
编辑器 SHALL 更新笔记的元数据。

#### Scenario: 更新编辑时间
- **WHEN** 用户保存笔记
- **THEN** 系统更新笔记的 updatedAt 时间戳

#### Scenario: 记录编辑设备
- **WHEN** 用户保存笔记
- **THEN** 系统记录当前设备名称到 lastEditDevice 字段
