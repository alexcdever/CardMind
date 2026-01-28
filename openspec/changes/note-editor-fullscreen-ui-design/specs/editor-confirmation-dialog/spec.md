## ADDED Requirements

### Requirement: 确认对话框触发条件
The system SHALL display confirmation dialog when user attempts to close with unsaved changes.

#### Scenario: 关闭按钮触发
- **WHEN** user clicks close button and hasUnsavedChanges is true
- **THEN** confirmation dialog is displayed
- **AND** editor remains open until user makes decision

#### Scenario: 自动保存期间触发
- **WHEN** user clicks close button during auto-save debounce period
- **THEN** confirmation dialog is displayed
- **AND** system treats as having unsaved changes

#### Scenario: 无更改不触发
- **WHEN** user clicks close button and hasUnsavedChanges is false
- **THEN** editor closes immediately
- **AND** confirmation dialog is not displayed

### Requirement: 确认对话框内容
The system SHALL display appropriate dialog content for unsaved changes scenario.

#### Scenario: 对话框标题和内容
- **WHEN** confirmation dialog is displayed
- **THEN** title is "有未保存的更改"
- **AND** content is "是否保存更改？"

#### Scenario: 对话框按钮选项
- **WHEN** confirmation dialog is displayed
- **THEN** "保存并关闭" button is shown as primary action
- **AND** "放弃更改" button is shown as destructive action
- **AND** "取消" button is shown as secondary action

### Requirement: 保存并关闭操作
The system SHALL handle save and close action from confirmation dialog.

#### Scenario: 有效内容保存
- **WHEN** user clicks "保存并关闭" with valid content
- **THEN** card is saved immediately
- **AND** editor closes after successful save
- **AND** onSave and onClose callbacks are invoked

#### Scenario: 空内容保存
- **WHEN** user clicks "保存并关闭" with empty content
- **THEN** toast message "内容不能为空" is displayed
- **AND** confirmation dialog remains open
- **AND** editor does not close

#### Scenario: 空标题处理
- **WHEN** user clicks "保存并关闭" with empty title but valid content
- **THEN** title is automatically set to "无标题笔记"
- **AND** card is saved successfully
- **AND** editor closes

### Requirement: 放弃更改操作
The system SHALL handle discard changes action from confirmation dialog.

#### Scenario: 放弃更改执行
- **WHEN** user clicks "放弃更改"
- **THEN** editor closes immediately
- **AND** onSave callback is not invoked
- **AND** onClose callback is invoked
- **AND** all unsaved changes are lost

#### Scenario: 放弃更改确认
- **WHEN** user clicks "放弃更改"
- **THEN** no additional confirmation is required
- **AND** action is executed immediately

### Requirement: 取消操作
The system SHALL handle cancel action from confirmation dialog.

#### Scenario: 取消对话框
- **WHEN** user clicks "取消"
- **THEN** confirmation dialog closes
- **AND** user returns to editing
- **AND** unsaved changes are preserved
- **AND** editor remains open

#### Scenario: 取消后状态
- **WHEN** user cancels confirmation dialog
- **THEN** hasUnsavedChanges flag remains true
- **AND** auto-save timer continues if active

### Requirement: 对话框外部交互
The system SHALL handle interactions outside the confirmation dialog.

#### Scenario: 外部点击关闭
- **WHEN** user clicks outside confirmation dialog
- **THEN** dialog closes
- **AND** user returns to editing
- **AND** unsaved changes are preserved

#### Scenario: 系统返回键
- **WHEN** user presses system back button while dialog is open
- **THEN** dialog closes
- **AND** user returns to editing
- **AND** editor does not close

### Requirement: 对话框样式和布局
The system SHALL provide properly styled confirmation dialog.

#### Scenario: 对话框布局
- **WHEN** confirmation dialog is displayed
- **THEN** it is centered on screen
- **AND** has appropriate padding and margins
- **AND** does not exceed screen boundaries

#### Scenario: 按钮样式
- **WHEN** dialog buttons are rendered
- **THEN** "保存并关闭" uses primary button style
- **AND** "放弃更改" uses destructive button style
- **AND** "取消" uses secondary button style

### Requirement: 对话框可访问性
The system SHALL ensure confirmation dialog is accessible.

#### Scenario: 屏幕阅读器支持
- **WHEN** confirmation dialog is displayed
- **THEN** dialog title and content are announced
- **AND** button labels are accessible
- **AND** focus management is proper

#### Scenario: 键盘导航
- **WHEN** user navigates with keyboard
- **THEN** tab order is logical
- **AND** enter key activates primary action
- **AND** escape key cancels dialog

### Requirement: 对话框状态管理
The system SHALL properly manage dialog state and lifecycle.

#### Scenario: 对话框状态跟踪
- **WHEN** confirmation dialog is displayed
- **THEN** dialog state is tracked
- **AND** prevents multiple dialogs from opening

#### Scenario: 对话框销毁
- **WHEN** editor widget is disposed while dialog is open
- **THEN** dialog is properly disposed
- **AND** no memory leaks occur

### Requirement: 对话框错误处理
The system SHALL handle errors during confirmation dialog operations.

#### Scenario: 保存失败处理
- **WHEN** save fails during "保存并关闭" action
- **THEN** error message is displayed
- **AND** confirmation dialog remains open
- **AND** user can retry or cancel

#### Scenario: 对话框渲染错误
- **WHEN** dialog encounters rendering error
- **THEN** fallback behavior is provided
- **AND** user can still close editor

### Requirement: 对话框性能要求
The system SHALL ensure dialog performance meets requirements.

#### Scenario: 对话框显示性能
- **WHEN** confirmation dialog is triggered
- **THEN** dialog appears within performance requirements
- **AND** animation is smooth at 60fps

#### Scenario: 对话框响应性能
- **WHEN** user clicks dialog buttons
- **THEN** response is immediate
- **AND** no noticeable lag