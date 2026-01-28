## ADDED Requirements

### Requirement: 空内容验证
The system SHALL validate that content is not empty before allowing save operations.

#### Scenario: 完全空内容检测
- **WHEN** content field contains only empty string
- **THEN** content is considered invalid
- **AND** save operation is prevented
- **AND** toast message "内容不能为空" is displayed

#### Scenario: 空白字符内容检测
- **WHEN** content field contains only whitespace characters
- **THEN** content is considered invalid
- **AND** save operation is prevented
- **AND** toast message "内容不能为空" is displayed

#### Scenario: 换行符内容检测
- **WHEN** content field contains only newline characters
- **THEN** content is considered invalid
- **AND** save operation is prevented
- **AND** toast message "内容不能为空" is displayed

### Requirement: 有效内容验证
The system SHALL accept content that contains non-whitespace characters.

#### Scenario: 单字内容验证
- **WHEN** content field contains a single character
- **THEN** content is considered valid
- **AND** save operation is allowed

#### Scenario: 文本内容验证
- **WHEN** content field contains text with mixed whitespace
- **THEN** content is considered valid if non-whitespace characters exist
- **AND** save operation is allowed

### Requirement: 标题空值处理
The system SHALL handle empty titles gracefully.

#### Scenario: 空标题自动填充
- **WHEN** title is empty or whitespace-only and content is valid
- **THEN** system automatically sets title to "无标题笔记"
- **AND** save operation proceeds normally

#### Scenario: 空标题验证
- **WHEN** title is being validated
- **THEN** empty title is not considered an error
- **AND** validation only applies to content field

### Requirement: 新建模式验证规则
The system SHALL apply different validation rules for new mode.

#### Scenario: 新建模式空内容关闭
- **WHEN** user attempts to close new mode with empty content
- **THEN** editor closes without confirmation dialog
- **AND** no validation error is displayed
- **AND** no card is created

#### Scenario: 新建模式空内容完成
- **WHEN** user clicks complete button in new mode with empty content
- **THEN** validation error is displayed
- **AND** toast message "内容不能为空" is shown
- **AND** editor remains open

### Requirement: 编辑模式验证规则
The system SHALL apply strict validation for edit mode.

#### Scenario: 编辑模式空内容关闭
- **WHEN** user attempts to close edit mode after clearing all content
- **THEN** confirmation dialog is displayed
- **AND** user can choose to save or discard

#### Scenario: 编辑模式空内容保存
- **WHEN** user attempts to save edit mode with empty content
- **THEN** validation error is displayed
- **AND** toast message "内容不能为空" is shown
- **AND** save operation is prevented

### Requirement: 验证时机
The system SHALL perform content validation at appropriate times.

#### Scenario: 完成按钮验证
- **WHEN** user clicks complete button
- **THEN** content validation is performed immediately
- **AND** save proceeds only if content is valid

#### Scenario: 自动保存验证
- **WHEN** auto-save is triggered
- **THEN** content validation is performed
- **AND** save is skipped if content is invalid

#### Scenario: 对话框保存验证
- **WHEN** user chooses "保存并关闭" from confirmation dialog
- **THEN** content validation is performed
- **AND** save proceeds only if content is valid

### Requirement: 验证错误反馈
The system SHALL provide clear feedback for validation failures.

#### Scenario: 错误消息显示
- **WHEN** content validation fails
- **THEN** toast message "内容不能为空" is displayed
- **AND** message appears at bottom of screen
- **AND** message disappears after 2 seconds

#### Scenario: 验证失败后状态
- **WHEN** validation fails
- **THEN** editor remains open
- **AND** user can continue editing
- **AND** unsaved changes are preserved

### Requirement: 内容长度验证
The system SHALL handle very long content appropriately.

#### Scenario: 超长内容接受
- **WHEN** content exceeds typical length limits
- **THEN** content is accepted as valid
- **AND** save operation is allowed
- **AND** content area supports scrolling

#### Scenario: 超长标题处理
- **WHEN** title exceeds typical length limits
- **THEN** title is accepted as valid
- **AND** title field supports text wrapping
- **AND** no length limit is enforced

### Requirement: 验证性能要求
The system SHALL perform validation efficiently without impacting user experience.

#### Scenario: 验证响应时间
- **WHEN** validation is performed
- **THEN** validation completes within performance requirements
- **AND** does not block UI thread

#### Scenario: 频繁验证优化
- **WHEN** user makes rapid changes
- **THEN** validation is optimized to prevent redundant checks
- **AND** UI remains responsive

### Requirement: 验证边界条件
The system SHALL handle edge cases in content validation.

#### Scenario: 特殊字符内容
- **WHEN** content contains special characters or emojis
- **THEN** content is considered valid if non-whitespace characters exist
- **AND** save operation is allowed

#### Scenario: 混合内容验证
- **WHEN** content contains mix of text, whitespace, and special characters
- **THEN** content is valid if any non-whitespace characters exist
- **AND** save operation is allowed

### Requirement: 验证状态管理
The system SHALL maintain validation state properly.

#### Scenario: 验证状态跟踪
- **WHEN** validation results change
- **THEN** validation state is updated appropriately
- **AND** UI reflects current validation status

#### Scenario: 验证状态重置
- **WHEN** user makes valid changes after validation failure
- **THEN** validation error state is cleared
- **AND** normal save behavior is restored