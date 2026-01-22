# Desktop Layout Specification
# 桌面端布局规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active | 已完成
**Dependencies** | **依赖**:
- SP-FLT-DSK-* (Desktop UI interaction specs | 桌面端 UI 交互规格)
- SP-ADAPT-005 (Desktop UI pattern specs | 桌面端 UI 模式规格)

---

## 1. Overview | 概述

### 1.1 Goals | 目标

Define desktop layout specifications to ensure:

定义桌面端整体布局规范，确保：

- Three-column layout, fully utilizing wide screens | 三栏布局，充分利用宽屏
- Resizable column widths | 可调整的列宽
- Responsive window sizing | 响应式窗口大小
- Clear visual hierarchy | 清晰的视觉层次

### 1.2 Applicable Platforms | 适用平台

- macOS
- Windows
- Linux

---

## 2. Three-Column Layout | 三栏布局

### Requirement: Desktop SHALL use three-column layout
### 需求：桌面端应使用三栏布局

Desktop SHALL use three-column layout.

桌面端应使用三栏布局。

#### Scenario: Left column shows device manager
#### 场景：左栏显示设备管理器

- **GIVEN** user is on desktop
- **前置条件**：用户在桌面端
- **WHEN** viewing home screen
- **操作**：查看主屏幕
- **THEN** left column SHALL show device manager
- **预期结果**：左栏应显示设备管理器
- **AND** column SHALL be 320px wide
- **并且**：栏宽应为 320px
- **AND** column SHALL be scrollable
- **并且**：栏应可滚动

#### Scenario: Middle column is reserved
#### 场景：中栏预留

- **GIVEN** user is on desktop
- **前置条件**：用户在桌面端
- **WHEN** viewing home screen
- **操作**：查看主屏幕
- **THEN** middle column SHALL be empty (reserved)
- **预期结果**：中栏应为空（预留）
- **AND** column SHALL expand to fill space
- **并且**：栏应扩展填充空间

#### Scenario: Right column shows card grid
#### 场景：右栏显示卡片网格

- **GIVEN** user is on desktop
- **前置条件**：用户在桌面端
- **WHEN** viewing home screen
- **操作**：查看主屏幕
- **THEN** right column SHALL show card grid
- **预期结果**：右栏应显示卡片网格
- **AND** column SHALL use remaining width
- **并且**：栏应使用剩余宽度
- **AND** column SHALL be scrollable
- **并且**：栏应可滚动

---

## 3. Column Width Adjustment | 列宽调整

### Requirement: Columns SHALL be resizable
### 需求：列应可调整宽度

Columns SHALL be resizable.

列应可调整宽度。

#### Scenario: Columns have dividers
#### 场景：列之间有分隔符

- **GIVEN** user is on desktop
- **前置条件**：用户在桌面端
- **WHEN** viewing layout
- **操作**：查看布局
- **THEN** dividers SHALL be between columns
- **预期结果**：分隔符应在列之间
- **AND** dividers SHALL be 1px wide
- **并且**：分隔符应为 1px 宽
- **AND** dividers SHALL be gray
- **并且**：分隔符应为灰色

#### Scenario: Dragging divider resizes columns
#### 场景：拖动分隔符调整列宽

- **GIVEN** user drags column divider
- **前置条件**：用户拖动列分隔符
- **WHEN** dragging
- **操作**：拖动中
- **THEN** columns SHALL resize
- **预期结果**：列应调整大小
- **AND** resize SHALL be smooth
- **并且**：调整应平滑
- **AND** cursor SHALL show resize icon
- **并且**：光标应显示调整大小图标

#### Scenario: Minimum widths are enforced
#### 场景：强制执行最小宽度

- **GIVEN** user tries to resize very small
- **前置条件**：用户尝试调整得非常小
- **WHEN** dragging divider
- **操作**：拖动分隔符
- **THEN** left column SHALL have min 280px
- **预期结果**：左栏应有最小宽度 280px
- **AND** right column SHALL have min 600px
- **并且**：右栏应有最小宽度 600px
- **AND** divider SHALL not move beyond limits
- **并且**：分隔符不应超出限制移动

---

## 4. Window Size | 窗口大小

### Requirement: Layout SHALL adapt to window size
### 需求：布局应适应窗口大小

Layout SHALL adapt to window size.

布局应适应窗口大小。

#### Scenario: Layout adapts to width
#### 场景：布局适应宽度

- **GIVEN** user resizes window
- **前置条件**：用户调整窗口大小
- **WHEN** window width changes
- **操作**：窗口宽度改变
- **THEN** card grid SHALL adapt column count
- **预期结果**：卡片网格应调整列数
- **AND** layout SHALL remain usable
- **并且**：布局应保持可用
- **AND** no content SHALL be cut off
- **并且**：不应有内容被截断

#### Scenario: Minimum window size is enforced
#### 场景：强制执行最小窗口大小

- **GIVEN** user tries to resize very small
- **前置条件**：用户尝试调整得非常小
- **WHEN** window reaches 800x600 pixels
- **操作**：窗口达到 800x600 像素
- **THEN** window SHALL not shrink further
- **预期结果**：窗口不应进一步缩小
- **AND** content SHALL remain readable
- **并且**：内容应保持可读

#### Scenario: Window size is persisted
#### 场景：窗口大小被持久化

- **GIVEN** user resizes window
- **前置条件**：用户调整窗口大小
- **WHEN** user closes and reopens app
- **操作**：用户关闭并重新打开应用
- **THEN** window SHALL restore previous size
- **预期结果**：窗口应恢复之前的大小
- **AND** window SHALL restore previous position
- **并且**：窗口应恢复之前的位置

---

## 5. Device Management Panel | 设备管理面板

### Requirement: Left column SHALL show device manager
### 需求：左栏应显示设备管理器

Left column SHALL show device manager panel.

左栏应显示设备管理面板。

#### Scenario: Current device is shown
#### 场景：显示当前设备

- **GIVEN** user is on desktop
- **前置条件**：用户在桌面端
- **WHEN** viewing left column
- **操作**：查看左栏
- **THEN** current device SHALL be shown at top
- **预期结果**：当前设备应显示在顶部
- **AND** device name SHALL be displayed
- **并且**：设备名称应显示
- **AND** device type SHALL be shown
- **并且**：设备类型应显示

#### Scenario: Paired devices are listed
#### 场景：列出配对设备

- **GIVEN** user has paired devices
- **前置条件**：用户有配对设备
- **WHEN** viewing left column
- **操作**：查看左栏
- **THEN** paired devices SHALL be listed below
- **预期结果**：配对设备应在下方列出
- **AND** each device SHALL show name and status
- **并且**：每个设备应显示名称和状态
- **AND** list SHALL be scrollable
- **并且**：列表应可滚动

#### Scenario: Settings are below devices
#### 场景：设置在设备下方

- **GIVEN** user is on desktop
- **前置条件**：用户在桌面端
- **WHEN** viewing left column
- **操作**：查看左栏
- **THEN** settings panel SHALL be below devices
- **预期结果**：设置面板应在设备下方
- **AND** theme toggle SHALL be visible
- **并且**：主题切换应可见
- **AND** settings SHALL be clearly separated
- **并且**：设置应明确分隔

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
