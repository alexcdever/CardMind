# Desktop Layout Specification

## 📋 规格编号: SP-FLT-DSK-006
**版本**: 1.0.0
**状态**: 已完成
**依赖**: 
- SP-FLT-DSK-* (桌面端 UI 交互规格)
- SP-ADAPT-005 (桌面端 UI 模式规格)

---

## 1. 概述

### 1.1 目标
定义桌面端整体布局规范，确保：
- 三栏布局，充分利用宽屏
- 可调整的列宽
- 响应式窗口大小
- 清晰的视觉层次

### 1.2 适用平台
- macOS
- Windows
- Linux

---

## 2. 三栏布局

### Requirement: Desktop SHALL use three-column layout

桌面端 SHALL 使用三栏布局。

#### Scenario: Left column shows device manager
- **GIVEN** user is on desktop
- **WHEN** viewing home screen
- **THEN** left column SHALL show device manager
- **AND** column SHALL be 320px wide
- **AND** column SHALL be scrollable

#### Scenario: Middle column is reserved
- **GIVEN** user is on desktop
- **WHEN** viewing home screen
- **THEN** middle column SHALL be empty (reserved)
- **AND** column SHALL expand to fill space

#### Scenario: Right column shows card grid
- **GIVEN** user is on desktop
- **WHEN** viewing home screen
- **THEN** right column SHALL show card grid
- **AND** column SHALL use remaining width
- **AND** column SHALL be scrollable

---

## 3. 列宽调整

### Requirement: Columns SHALL be resizable

列 SHALL 可调整宽度。

#### Scenario: Columns have dividers
- **GIVEN** user is on desktop
- **WHEN** viewing layout
- **THEN** dividers SHALL be between columns
- **AND** dividers SHALL be 1px wide
- **AND** dividers SHALL be gray

#### Scenario: Dragging divider resizes columns
- **GIVEN** user drags column divider
- **WHEN** dragging
- **THEN** columns SHALL resize
- **AND** resize SHALL be smooth
- **AND** cursor SHALL show resize icon

#### Scenario: Minimum widths are enforced
- **GIVEN** user tries to resize very small
- **WHEN** dragging divider
- **THEN** left column SHALL have min 280px
- **AND** right column SHALL have min 600px
- **AND** divider SHALL not move beyond limits

---

## 4. 窗口大小

### Requirement: Layout SHALL adapt to window size

布局 SHALL 适应窗口大小。

#### Scenario: Layout adapts to width
- **GIVEN** user resizes window
- **WHEN** window width changes
- **THEN** card grid SHALL adapt column count
- **AND** layout SHALL remain usable
- **AND** no content SHALL be cut off

#### Scenario: Minimum window size is enforced
- **GIVEN** user tries to resize very small
- **WHEN** window reaches 800x600 pixels
- **THEN** window SHALL not shrink further
- **AND** content SHALL remain readable

#### Scenario: Window size is persisted
- **GIVEN** user resizes window
- **WHEN** user closes and reopens app
- **THEN** window SHALL restore previous size
- **AND** window SHALL restore previous position

---

## 5. 设备管理面板

### Requirement: Left column SHALL show device manager

左栏 SHALL 显示设备管理面板。

#### Scenario: Current device is shown
- **GIVEN** user is on desktop
- **WHEN** viewing left column
- **THEN** current device SHALL be shown at top
- **AND** device name SHALL be displayed
- **AND** device type SHALL be shown

#### Scenario: Paired devices are listed
- **GIVEN** user has paired devices
- **WHEN** viewing left column
- **THEN** paired devices SHALL be listed below
- **AND** each device SHALL show name and status
- **AND** list SHALL be scrollable

#### Scenario: Settings are below devices
- **GIVEN** user is on desktop
- **WHEN** viewing left column
- **THEN** settings panel SHALL be below devices
- **AND** theme toggle SHALL be visible
- **AND** settings SHALL be clearly separated

---

**最后更新**: 2026-01-19
**作者**: CardMind Team
