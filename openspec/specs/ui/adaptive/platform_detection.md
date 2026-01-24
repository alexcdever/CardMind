# Platform Detection Specification
# 平台检测规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: Active

**Dependencies**: None
**依赖**: 无

**Related Tests**: `test/adaptive/platform_detection_test.dart`
**相关测试**: `test/adaptive/platform_detection_test.dart`

---

## Overview
## 概述

This specification defines the platform detection system that identifies the current platform and device characteristics to enable adaptive UI behavior.

本规格定义了平台检测系统，识别当前平台和设备特性以启用自适应 UI 行为。

---

## Requirement: Detect operating system platform
## 需求：检测操作系统平台

The system SHALL accurately detect the operating system platform.

系统应准确检测操作系统平台。

### Scenario: Detect Android platform
### 场景：检测 Android 平台

- **GIVEN**: the application is running
- **前置条件**：应用程序正在运行
- **WHEN**: querying the platform
- **操作**：查询平台
- **THEN**: the system SHALL return "Android" when running on Android devices
- **预期结果**：在 Android 设备上运行时系统应返回"Android"

### Scenario: Detect iOS platform
### 场景：检测 iOS 平台

- **GIVEN**: the application is running
- **前置条件**：应用程序正在运行
- **WHEN**: querying the platform
- **操作**：查询平台
- **THEN**: the system SHALL return "iOS" when running on iPhone or iPad
- **预期结果**：在 iPhone 或 iPad 上运行时系统应返回"iOS"

### Scenario: Detect Windows platform
### 场景：检测 Windows 平台

- **GIVEN**: the application is running
- **前置条件**：应用程序正在运行
- **WHEN**: querying the platform
- **操作**：查询平台
- **THEN**: the system SHALL return "Windows" when running on Windows desktop
- **预期结果**：在 Windows 桌面上运行时系统应返回"Windows"

### Scenario: Detect macOS platform
### 场景：检测 macOS 平台

- **GIVEN**: the application is running
- **前置条件**：应用程序正在运行
- **WHEN**: querying the platform
- **操作**：查询平台
- **THEN**: the system SHALL return "macOS" when running on Mac computers
- **预期结果**：在 Mac 计算机上运行时系统应返回"macOS"

### Scenario: Detect Linux platform
### 场景：检测 Linux 平台

- **GIVEN**: the application is running
- **前置条件**：应用程序正在运行
- **WHEN**: querying the platform
- **操作**：查询平台
- **THEN**: the system SHALL return "Linux" when running on Linux desktop
- **预期结果**：在 Linux 桌面上运行时系统应返回"Linux"

---

## Requirement: Detect device form factor
## 需求：检测设备形态

The system SHALL determine the device form factor based on screen size and platform.

系统应根据屏幕尺寸和平台确定设备形态。

### Scenario: Detect mobile phone
### 场景：检测移动手机

- **GIVEN**: the application is running
- **前置条件**：应用程序正在运行
- **WHEN**: determining device form factor
- **操作**：确定设备形态
- **THEN**: the system SHALL classify as "phone" when screen width < 600dp and platform is Android or iOS
- **预期结果**：当屏幕宽度 < 600dp 且平台为 Android 或 iOS 时系统应分类为"手机"

### Scenario: Detect tablet
### 场景：检测平板电脑

- **GIVEN**: the application is running
- **前置条件**：应用程序正在运行
- **WHEN**: determining device form factor
- **操作**：确定设备形态
- **THEN**: the system SHALL classify as "tablet" when screen width >= 600dp and platform is Android or iOS
- **预期结果**：当屏幕宽度 >= 600dp 且平台为 Android 或 iOS 时系统应分类为"平板电脑"

### Scenario: Detect desktop
### 场景：检测桌面

- **GIVEN**: the application is running
- **前置条件**：应用程序正在运行
- **WHEN**: determining device form factor
- **操作**：确定设备形态
- **THEN**: the system SHALL classify as "desktop" when platform is Windows, macOS, or Linux
- **预期结果**：当平台为 Windows、macOS 或 Linux 时系统应分类为"桌面"

---

## Requirement: Detect input capabilities
## 需求：检测输入能力

The system SHALL detect available input methods on the device.

系统应检测设备上可用的输入方法。

### Scenario: Detect touch input
### 场景：检测触摸输入

- **GIVEN**: the application is running
- **前置条件**：应用程序正在运行
- **WHEN**: querying input capabilities
- **操作**：查询输入能力
- **THEN**: the system SHALL return true for touch support on mobile and tablet devices
- **预期结果**：对于移动和平板设备，系统应返回 true 表示支持触摸
- **AND**: return false for traditional desktop platforms without touchscreen
- **并且**：对于没有触摸屏的传统桌面平台返回 false

### Scenario: Detect mouse/pointer input
### 场景：检测鼠标/指针输入

- **GIVEN**: the application is running
- **前置条件**：应用程序正在运行
- **WHEN**: querying input capabilities
- **操作**：查询输入能力
- **THEN**: the system SHALL return true for pointer support on desktop platforms
- **预期结果**：对于桌面平台，系统应返回 true 表示支持指针
- **AND**: return false for mobile phones without mouse support
- **并且**：对于不支持鼠标的移动手机返回 false

### Scenario: Detect keyboard input
### 场景：检测键盘输入

- **GIVEN**: the application is running
- **前置条件**：应用程序正在运行
- **WHEN**: querying input capabilities
- **操作**：查询输入能力
- **THEN**: the system SHALL return true for physical keyboard on desktop
- **预期结果**：对于桌面的物理键盘，系统应返回 true
- **AND**: return false for mobile devices with only virtual keyboard
- **并且**：对于仅有虚拟键盘的移动设备返回 false

---

## Requirement: Detect screen characteristics
## 需求：检测屏幕特性

The system SHALL provide information about screen size and pixel density.

系统应提供有关屏幕尺寸和像素密度的信息。

### Scenario: Get screen width in dp
### 场景：获取屏幕宽度（dp）

- **GIVEN**: the application is running
- **前置条件**：应用程序正在运行
- **WHEN**: querying screen dimensions
- **操作**：查询屏幕尺寸
- **THEN**: the system SHALL return screen width in density-independent pixels (dp)
- **预期结果**：系统应返回以密度无关像素（dp）为单位的屏幕宽度

### Scenario: Get screen height in dp
### 场景：获取屏幕高度（dp）

- **GIVEN**: the application is running
- **前置条件**：应用程序正在运行
- **WHEN**: querying screen dimensions
- **操作**：查询屏幕尺寸
- **THEN**: the system SHALL return screen height in density-independent pixels (dp)
- **预期结果**：系统应返回以密度无关像素（dp）为单位的屏幕高度

### Scenario: Get pixel density
### 场景：获取像素密度

- **GIVEN**: the application is running
- **前置条件**：应用程序正在运行
- **WHEN**: querying screen characteristics
- **操作**：查询屏幕特性
- **THEN**: the system SHALL return device pixel ratio (e.g., 1.0, 2.0, 3.0)
- **预期结果**：系统应返回设备像素比（例如，1.0、2.0、3.0）

### Scenario: Detect screen orientation
### 场景：检测屏幕方向

- **GIVEN**: the application is running
- **前置条件**：应用程序正在运行
- **WHEN**: querying screen orientation
- **操作**：查询屏幕方向
- **THEN**: the system SHALL return "portrait" when height > width
- **预期结果**：当高度 > 宽度时系统应返回"竖屏"
- **AND**: return "landscape" when width > height
- **并且**：当宽度 > 高度时返回"横屏"

---

## Requirement: Provide platform-specific behavior flags
## 需求：提供平台特定的行为标志

The system SHALL provide boolean flags for common platform-specific behaviors.

系统应为常见的平台特定行为提供布尔标志。

### Scenario: Check if platform is mobile
### 场景：检查平台是否为移动端

- **GIVEN**: the application is running
- **前置条件**：应用程序正在运行
- **WHEN**: checking platform category
- **操作**：检查平台类别
- **THEN**: the system SHALL return true for isMobile when platform is Android or iOS with phone form factor
- **预期结果**：当平台为 Android 或 iOS 且为手机形态时，系统应为 isMobile 返回 true

### Scenario: Check if platform is desktop
### 场景：检查平台是否为桌面端

- **GIVEN**: the application is running
- **前置条件**：应用程序正在运行
- **WHEN**: checking platform category
- **操作**：检查平台类别
- **THEN**: the system SHALL return true for isDesktop when platform is Windows, macOS, or Linux
- **预期结果**：当平台为 Windows、macOS 或 Linux 时，系统应为 isDesktop 返回 true

### Scenario: Check if platform supports hover
### 场景：检查平台是否支持悬停

- **GIVEN**: the application is running
- **前置条件**：应用程序正在运行
- **WHEN**: checking hover support
- **操作**：检查悬停支持
- **THEN**: the system SHALL return true for supportsHover on desktop platforms
- **预期结果**：对于桌面平台，系统应为 supportsHover 返回 true
- **AND**: return false on mobile platforms without pointer
- **并且**：对于没有指针的移动平台返回 false

### Scenario: Check if platform supports gestures
### 场景：检查平台是否支持手势

- **GIVEN**: the application is running
- **前置条件**：应用程序正在运行
- **WHEN**: checking gesture support
- **操作**：检查手势支持
- **THEN**: the system SHALL return true for supportsGestures on touch-enabled devices
- **预期结果**：对于支持触摸的设备，系统应为 supportsGestures 返回 true
- **AND**: return false on desktop without touchscreen
- **并且**：对于没有触摸屏的桌面返回 false

---

## Requirement: React to platform changes
## 需求：响应平台变化

The system SHALL detect and respond to platform characteristic changes at runtime.

系统应在运行时检测并响应平台特性变化。

### Scenario: Detect screen size change
### 场景：检测屏幕尺寸变化

- **GIVEN**: the application is running
- **前置条件**：应用程序正在运行
- **WHEN**: user resizes the window or rotates the device
- **操作**：用户调整窗口大小或旋转设备
- **THEN**: the system SHALL emit a platform change event
- **预期结果**：系统应发出平台变化事件
- **AND**: update screen dimension values
- **并且**：更新屏幕尺寸值
- **AND**: re-evaluate form factor classification
- **并且**：重新评估形态分类

### Scenario: Detect orientation change
### 场景：检测方向变化

- **GIVEN**: the application is running on a mobile or tablet device
- **前置条件**：应用程序在移动或平板设备上运行
- **WHEN**: user rotates the device
- **操作**：用户旋转设备
- **THEN**: the system SHALL emit an orientation change event
- **预期结果**：系统应发出方向变化事件
- **AND**: update orientation value (portrait/landscape)
- **并且**：更新方向值（竖屏/横屏）

---

## Test Coverage
## 测试覆盖

**Test File**: `test/adaptive/platform_detection_test.dart`
**测试文件**: `test/adaptive/platform_detection_test.dart`

**Unit Tests**:
**单元测试**:
- `it_should_detect_android_platform()` - Android detection
- `it_should_detect_android_platform()` - Android 检测
- `it_should_detect_ios_platform()` - iOS detection
- `it_should_detect_ios_platform()` - iOS 检测
- `it_should_detect_windows_platform()` - Windows detection
- `it_should_detect_windows_platform()` - Windows 检测
- `it_should_detect_macos_platform()` - macOS detection
- `it_should_detect_macos_platform()` - macOS 检测
- `it_should_detect_linux_platform()` - Linux detection
- `it_should_detect_linux_platform()` - Linux 检测
- `it_should_classify_phone_form_factor()` - Phone classification
- `it_should_classify_phone_form_factor()` - 手机分类
- `it_should_classify_tablet_form_factor()` - Tablet classification
- `it_should_classify_tablet_form_factor()` - 平板分类
- `it_should_classify_desktop_form_factor()` - Desktop classification
- `it_should_classify_desktop_form_factor()` - 桌面分类
- `it_should_detect_touch_input()` - Touch detection
- `it_should_detect_touch_input()` - 触摸检测
- `it_should_detect_pointer_input()` - Pointer detection
- `it_should_detect_pointer_input()` - 指针检测
- `it_should_detect_keyboard_input()` - Keyboard detection
- `it_should_detect_keyboard_input()` - 键盘检测
- `it_should_return_screen_width_in_dp()` - Screen width
- `it_should_return_screen_width_in_dp()` - 屏幕宽度
- `it_should_return_screen_height_in_dp()` - Screen height
- `it_should_return_screen_height_in_dp()` - 屏幕高度
- `it_should_return_pixel_density()` - Pixel density
- `it_should_return_pixel_density()` - 像素密度
- `it_should_detect_portrait_orientation()` - Portrait orientation
- `it_should_detect_portrait_orientation()` - 竖屏方向
- `it_should_detect_landscape_orientation()` - Landscape orientation
- `it_should_detect_landscape_orientation()` - 横屏方向
- `it_should_emit_event_on_screen_size_change()` - Size change event
- `it_should_emit_event_on_screen_size_change()` - 尺寸变化事件
- `it_should_emit_event_on_orientation_change()` - Orientation change event
- `it_should_emit_event_on_orientation_change()` - 方向变化事件

**Acceptance Criteria**:
**验收标准**:
- [ ] All unit tests pass
- [ ] 所有单元测试通过
- [ ] Platform detection is accurate across all supported platforms
- [ ] 平台检测在所有支持的平台上准确
- [ ] Form factor classification is correct
- [ ] 形态分类正确
- [ ] Input capability detection works reliably
- [ ] 输入能力检测可靠工作
- [ ] Platform change events are emitted correctly
- [ ] 平台变化事件正确发出
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Related Specs**:
**相关规格**:
- [layouts.md](layouts.md) - Adaptive layout system
- [layouts.md](layouts.md) - 自适应布局系统
- [components.md](components.md) - Adaptive components
- [components.md](components.md) - 自适应组件

---

**Last Updated**: 2026-01-24
**最后更新**: 2026-01-24

**Authors**: CardMind Team
**作者**: CardMind Team
