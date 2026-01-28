# note-editor-fullscreen Specification

## Purpose
TBD - created by archiving change note-editor-fullscreen-ui-design. Update Purpose after archive.
## Requirements
### Requirement: 全屏编辑器初始化
The system SHALL initialize a fullscreen editor when opening a card for editing or creation.

#### Scenario: 新建模式初始化
- **WHEN** user opens editor with card=null
- **THEN** editor displays with empty title and content fields
- **AND** no metadata section is shown
- **AND** auto-save is enabled

#### Scenario: 编辑模式初始化
- **WHEN** user opens editor with existing card
- **THEN** editor displays with card.title populated in title field
- **AND** card.content populated in content field
- **AND** metadata section shows creation time, update time, and last edit device
- **AND** auto-save is enabled

### Requirement: 标题输入功能
The system SHALL allow users to input and edit card titles in a dedicated input field.

#### Scenario: 输入标题
- **WHEN** user types in title input field
- **THEN** title field content updates in real-time
- **AND** auto-save timer is triggered

#### Scenario: 空标题自动填充
- **WHEN** user saves card with empty or whitespace-only title
- **THEN** system automatically sets title to "无标题笔记"
- **AND** card is saved successfully

#### Scenario: 标题输入框样式
- **WHEN** title input field is rendered
- **THEN** it displays placeholder text "笔记标题"
- **AND** uses 24px bold font
- **AND** has no border or focus ring
- **AND** occupies single line with auto-wrap

### Requirement: 内容输入功能
The system SHALL provide a large text area for card content editing with minimum height requirements.

#### Scenario: 内容输入
- **WHEN** user types in content input field
- **THEN** content field updates in real-time
- **AND** auto-save timer is triggered
- **AND** field supports multiline input

#### Scenario: 内容输入框样式
- **WHEN** content input field is rendered
- **THEN** it displays placeholder text "开始写笔记..."
- **AND** uses 16px regular font
- **AND** has minimum height of 60vh
- **AND** supports scrolling for long content
- **AND** has no border or focus ring

#### Scenario: 内容验证
- **WHEN** user attempts to save card with empty or whitespace-only content
- **THEN** system shows toast message "内容不能为空"
- **AND** card is not saved
- **AND** user remains in editor

### Requirement: 自动保存机制
The system SHALL automatically save card content after user stops typing with a debounce mechanism.

#### Scenario: 自动保存触发
- **WHEN** user makes changes to title or content and stops typing for 1 second
- **THEN** system automatically saves the card
- **AND** updates the original values for change detection
- **AND** clears unsaved changes flag

#### Scenario: 自动保存防抖
- **WHEN** user makes multiple rapid changes within 1 second
- **THEN** system only triggers auto-save once after 1 second of inactivity
- **AND** previous auto-save timer is cancelled

#### Scenario: 空内容不保存
- **WHEN** auto-save is triggered and content is empty or whitespace-only
- **THEN** system does not save the card
- **AND** clears auto-save timer

### Requirement: 工具栏交互
The system SHALL provide a toolbar with close button, auto-save status, and complete button.

#### Scenario: 关闭按钮点击
- **WHEN** user clicks close button and there are no unsaved changes
- **THEN** editor closes immediately
- **AND** onClose callback is invoked

#### Scenario: 关闭按钮有未保存更改
- **WHEN** user clicks close button and there are unsaved changes
- **THEN** confirmation dialog is displayed
- **AND** user can choose to save, discard, or cancel

#### Scenario: 完成按钮点击
- **WHEN** user clicks complete button with valid content
- **THEN** auto-save timer is cancelled
- **AND** card is saved immediately
- **AND** editor closes
- **AND** onSave and onClose callbacks are invoked

#### Scenario: 完成按钮空内容
- **WHEN** user clicks complete button with empty or whitespace-only content
- **THEN** toast message "内容不能为空" is displayed
- **AND** editor remains open
- **AND** auto-save timer is cancelled

### Requirement: 确认对话框
The system SHALL display a confirmation dialog when user attempts to close editor with unsaved changes.

#### Scenario: 保存并关闭
- **WHEN** user clicks "保存并关闭" in confirmation dialog
- **THEN** system saves the card if content is valid
- **AND** editor closes if save successful
- **AND** shows toast if content is invalid and keeps dialog open

#### Scenario: 放弃更改
- **WHEN** user clicks "放弃更改" in confirmation dialog
- **THEN** editor closes without saving
- **AND** onClose callback is invoked
- **AND** onSave callback is not invoked

#### Scenario: 取消操作
- **WHEN** user clicks "取消" in confirmation dialog
- **THEN** dialog closes
- **AND** user returns to editing
- **AND** unsaved changes are preserved

#### Scenario: 对话框外部点击
- **WHEN** user clicks outside confirmation dialog
- **THEN** dialog closes
- **AND** user returns to editing

### Requirement: 元数据显示
The system SHALL display card metadata in edit mode including creation time, update time, and last edit device.

#### Scenario: 编辑模式元数据
- **WHEN** editor is opened in edit mode
- **THEN** metadata section is displayed below content area
- **AND** shows "创建时间: {formatted creation time}"
- **AND** shows "更新时间: {formatted update time}"
- **AND** shows "最后编辑设备: {device name}" if available
- **AND** uses 14px secondary text color

#### Scenario: 新建模式元数据
- **WHEN** editor is opened in new mode
- **THEN** metadata section is not displayed

#### Scenario: 元数据缺失字段
- **WHEN** card has null lastEditDevice
- **THEN** "最后编辑设备" line is not displayed

### Requirement: 动画和过渡
The system SHALL provide smooth animations for opening and closing the fullscreen editor.

#### Scenario: 打开动画
- **WHEN** editor opens
- **THEN** it slides in from bottom with 300ms duration
- **AND** animation runs at 60fps

#### Scenario: 关闭动画
- **WHEN** editor closes without confirmation
- **THEN** it slides out to bottom with 300ms duration
- **AND** animation runs at 60fps

### Requirement: 状态管理
The system SHALL manage editor state including current values, original values, and unsaved changes detection.

#### Scenario: 更改检测
- **WHEN** title or content differs from original values
- **THEN** hasUnsavedChanges flag is set to true
- **AND** confirmation dialog will appear on close

#### Scenario: 原始值更新
- **WHEN** card is successfully saved
- **THEN** original values are updated to current values
- **AND** hasUnsavedChanges flag is set to false

### Requirement: 性能要求
The system SHALL maintain responsive performance during editing operations.

#### Scenario: 输入响应
- **WHEN** user types in input fields
- **THEN** input response time is less than 16ms
- **AND** UI remains responsive

#### Scenario: 内存管理
- **WHEN** editor is opened and closed
- **THEN** memory usage growth is less than 10MB
- **AND** no memory leaks occur

#### Scenario: 自动保存频率
- **WHEN** user continuously types
- **THEN** auto-save triggers at most once per second
- **AND** does not block UI thread

### Requirement: 边界条件处理
The system SHALL handle edge cases and error conditions gracefully.

#### Scenario: 超长内容
- **WHEN** user inputs very long title or content
- **THEN** system accepts input without truncation
- **AND** title wraps to multiple lines if needed
- **AND** content area scrolls

#### Scenario: 快速连续操作
- **WHEN** user rapidly clicks complete button multiple times
- **THEN** save operation executes only once
- **AND** subsequent clicks are ignored

#### Scenario: 自动保存期间关闭
- **WHEN** user clicks close during auto-save debounce period
- **THEN** system treats as having unsaved changes
- **AND** shows confirmation dialog

### Requirement: 生命周期管理
The system SHALL properly manage component lifecycle and resource cleanup.

#### Scenario: 组件销毁
- **WHEN** editor widget is disposed
- **THEN** auto-save timer is cancelled
- **AND** text controllers are disposed
- **AND** no memory leaks occur

#### Scenario: 页面返回键
- **WHEN** user presses device back button
- **THEN** close button logic is triggered
- **AND** confirmation dialog appears if there are unsaved changes

