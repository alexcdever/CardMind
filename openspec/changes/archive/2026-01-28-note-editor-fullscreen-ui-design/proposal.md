## Why

移动端用户需要一个沉浸式的全屏编辑体验来创建和编辑笔记。当前的设计缺乏专注的编辑环境，用户在移动设备上编辑笔记时容易受到界面干扰，且缺乏自动保存机制保障数据安全。现在实现此功能是为了提升移动端用户体验，与 CardMind 的移动优先策略保持一致。

## What Changes

- **新增**: 实现移动端全屏笔记编辑器组件 `NoteEditorFullscreen`
- **新增**: 自动保存机制（1秒防抖）
- **新增**: 沉浸式全屏编辑体验
- **新增**: 确认对话框防止数据丢失
- **新增**: 新建模式和编辑模式的双模式支持
- **移除**: 在编辑器中显示标签功能（简化体验）
- **修改**: 标题为空时自动填充"无标题笔记"
- **新增**: 内容为空时的验证和提示机制

## Capabilities

### New Capabilities
- `note-editor-fullscreen`: 全屏笔记编辑器的核心功能，包括标题和内容编辑、自动保存、新建/编辑模式切换
- `mobile-fullscreen-ui`: 移动端全屏界面设计系统，包括工具栏、输入区域、元数据显示
- `auto-save-mechanism`: 自动保存机制，包括防抖逻辑、内容验证、状态管理
- `editor-confirmation-dialog`: 编辑器确认对话框系统，包括未保存更改提示、选项处理
- `editor-content-validation`: 内容验证系统，包括空内容检测、边界条件处理

### Modified Capabilities
- 无现有规格需要修改，此为全新功能

## Impact

- **Affected Code**: Flutter UI 层（新增组件）、状态管理（编辑器状态）、数据层（Card 模型集成）
- **APIs**: 新增 OnClose 和 OnSave 回调类型定义
- **Dependencies**: React UI 参考实现、现有 Card 数据模型、OpenSpec 现有设计系统
- **Systems**: 移动端导航系统、数据持久化系统、用户交互系统