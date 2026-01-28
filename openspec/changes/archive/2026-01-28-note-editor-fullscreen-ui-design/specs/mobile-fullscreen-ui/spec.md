## ADDED Requirements

### Requirement: 全屏布局结构
The system SHALL provide a fullscreen layout that maximizes editing space on mobile devices.

#### Scenario: 全屏渲染
- **WHEN** editor is opened
- **THEN** editor occupies entire screen
- **AND** status bar is hidden or dimmed
- **AND** navigation bar is hidden

#### Scenario: 安全区域适配
- **WHEN** editor is rendered on device with notches
- **THEN** toolbar height includes SafeArea.top
- **AND** content avoids system UI overlaps

### Requirement: 工具栏设计
The system SHALL provide a toolbar with proper height, background, and visual effects.

#### Scenario: 工具栏高度
- **WHEN** toolbar is rendered
- **THEN** height is 56px + SafeArea.top
- **AND** maintains consistent height across devices

#### Scenario: 工具栏背景
- **WHEN** toolbar is displayed
- **THEN** background has 95% opacity
- **AND** background blur effect is applied
- **AND** bottom border is 1px separator line

#### Scenario: 深色模式适配
- **WHEN** system is in dark mode
- **THEN** toolbar background uses dark theme colors
- **AND** text colors are adjusted for contrast

### Requirement: 关闭按钮设计
The system SHALL provide a close button with proper touch target and visual feedback.

#### Scenario: 关闭按钮布局
- **WHEN** toolbar is rendered
- **THEN** close button is positioned on left side
- **AND** has 44x44px touch target
- **AND** displays "×" icon

#### Scenario: 关闭按钮样式
- **WHEN** close button is rendered
- **THEN** it uses ghost button style
- **AND** has no background fill
- **AND** provides visual feedback on press

### Requirement: 保存区域设计
The system SHALL provide a save area with auto-save status and complete button.

#### Scenario: 自动保存状态显示
- **WHEN** toolbar is rendered
- **THEN** "自动保存" text is displayed
- **AND** uses 14px secondary text color
- **AND** positioned on right side before complete button

#### Scenario: 完成按钮设计
- **WHEN** complete button is rendered
- **THEN** displays "完成" text with "✓" icon
- **AND** uses primary button style with theme color background
- **AND** positioned on far right of toolbar

### Requirement: 输入区域设计
The system SHALL provide properly styled input areas for title and content.

#### Scenario: 标题输入框样式
- **WHEN** title input is rendered
- **THEN** placeholder text is "笔记标题"
- **AND** uses 24px bold font weight
- **AND** has 16px horizontal padding
- **AND** has no border or focus ring

#### Scenario: 内容输入框样式
- **WHEN** content input is rendered
- **THEN** placeholder text is "开始写笔记..."
- **AND** uses 16px regular font weight
- **AND** has 16px horizontal padding
- **AND** minimum height is 60vh
- **AND** supports multiline input

### Requirement: 分隔线设计
The system SHALL provide visual separators between different sections.

#### Scenario: 标题内容分隔
- **WHEN** title and content areas are rendered
- **THEN** horizontal separator line is displayed between them
- **AND** line uses subtle color

#### Scenario: 元数据分隔
- **WHEN** metadata section is rendered
- **THEN** horizontal separator line is displayed above it
- **AND** line uses subtle color

### Requirement: 元数据区域设计
The system SHALL provide a metadata section with proper typography and spacing.

#### Scenario: 元数据布局
- **WHEN** metadata section is rendered
- **THEN** it has 16px padding
- **AND** uses 14px font size
- **AND** uses secondary text color

#### Scenario: 元数据格式化
- **WHEN** displaying timestamps
- **THEN** format is "YYYY/M/D HH:MM:SS"
- **AND** uses zh-CN locale for Chinese users

### Requirement: 响应式设计
The system SHALL adapt layout for different screen sizes while maintaining fullscreen experience.

#### Scenario: 小屏幕适配
- **WHEN** rendered on small screens
- **THEN** minimum content height is maintained
- **AND** toolbar remains accessible

#### Scenario: 大屏幕适配
- **WHEN** rendered on large screens
- **THEN** content area uses appropriate maximum width
- **AND** maintains centered layout

### Requirement: 视觉层次
The system SHALL establish clear visual hierarchy for different UI elements.

#### Scenario: 主要操作突出
- **WHEN** complete button is rendered
- **THEN** it has highest visual prominence
- **AND** uses theme color for background

#### Scenario: 次要信息弱化
- **WHEN** metadata is displayed
- **THEN** it has lowest visual prominence
- **AND** uses secondary color and smaller font

### Requirement: 交互反馈
The system SHALL provide appropriate visual feedback for user interactions.

#### Scenario: 按钮按下状态
- **WHEN** user presses buttons
- **THEN** visual feedback is provided
- **AND** feedback is immediate and smooth

#### Scenario: 输入框焦点状态
- **WHEN** input fields receive focus
- **THEN** no focus ring is displayed
- **AND** cursor is clearly visible