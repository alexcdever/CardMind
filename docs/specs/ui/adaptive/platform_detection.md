# Platform Detection Specification
# 平台检测规格

**版本**: 1.0.0

**状态**: 活跃

**依赖**: 无

**相关测试**: `test/adaptive/platform_detection_test.dart`

---

## 概述


本规格定义了平台检测系统，识别当前平台和设备特性以启用自适应 UI 行为。

---

## 需求：检测操作系统平台


系统应准确检测操作系统平台。

### 场景：检测 Android 平台

- **前置条件**：应用程序正在运行
- **操作**：查询平台
- **预期结果**：在 Android 设备上运行时系统应返回"Android"

### 场景：检测 iOS 平台

- **前置条件**：应用程序正在运行
- **操作**：查询平台
- **预期结果**：在 iPhone 或 iPad 上运行时系统应返回"iOS"

### 场景：检测 Windows 平台

- **前置条件**：应用程序正在运行
- **操作**：查询平台
- **预期结果**：在 Windows 桌面上运行时系统应返回"Windows"

### 场景：检测 macOS 平台

- **前置条件**：应用程序正在运行
- **操作**：查询平台
- **预期结果**：在 Mac 计算机上运行时系统应返回"macOS"

### 场景：检测 Linux 平台

- **前置条件**：应用程序正在运行
- **操作**：查询平台
- **预期结果**：在 Linux 桌面上运行时系统应返回"Linux"

---

## 需求：检测设备形态


系统应根据屏幕尺寸和平台确定设备形态。

### 场景：检测移动手机

- **前置条件**：应用程序正在运行
- **操作**：确定设备形态
- **预期结果**：当屏幕宽度 < 600dp 且平台为 Android 或 iOS 时系统应分类为"手机"

### 场景：检测平板电脑

- **前置条件**：应用程序正在运行
- **操作**：确定设备形态
- **预期结果**：当屏幕宽度 >= 600dp 且平台为 Android 或 iOS 时系统应分类为"平板电脑"

### 场景：检测桌面

- **前置条件**：应用程序正在运行
- **操作**：确定设备形态
- **预期结果**：当平台为 Windows、macOS 或 Linux 时系统应分类为"桌面"

---

## 需求：检测输入能力


系统应检测设备上可用的输入方法。

### 场景：检测触摸输入

- **前置条件**：应用程序正在运行
- **操作**：查询输入能力
- **预期结果**：对于移动和平板设备，系统应返回 true 表示支持触摸
- **并且**：对于没有触摸屏的传统桌面平台返回 false

### 场景：检测鼠标/指针输入

- **前置条件**：应用程序正在运行
- **操作**：查询输入能力
- **预期结果**：对于桌面平台，系统应返回 true 表示支持指针
- **并且**：对于不支持鼠标的移动手机返回 false

### 场景：检测键盘输入

- **前置条件**：应用程序正在运行
- **操作**：查询输入能力
- **预期结果**：对于桌面的物理键盘，系统应返回 true
- **并且**：对于仅有虚拟键盘的移动设备返回 false

---

## 需求：检测屏幕特性


系统应提供有关屏幕尺寸和像素密度的信息。

### 场景：获取屏幕宽度（dp）

- **前置条件**：应用程序正在运行
- **操作**：查询屏幕尺寸
- **预期结果**：系统应返回以密度无关像素（dp）为单位的屏幕宽度

### 场景：获取屏幕高度（dp）

- **前置条件**：应用程序正在运行
- **操作**：查询屏幕尺寸
- **预期结果**：系统应返回以密度无关像素（dp）为单位的屏幕高度

### 场景：获取像素密度

- **前置条件**：应用程序正在运行
- **操作**：查询屏幕特性
- **预期结果**：系统应返回设备像素比（例如，1.0、2.0、3.0）

### 场景：检测屏幕方向

- **前置条件**：应用程序正在运行
- **操作**：查询屏幕方向
- **预期结果**：当高度 > 宽度时系统应返回"竖屏"
- **并且**：当宽度 > 高度时返回"横屏"

---

## 需求：提供平台特定的行为标志


系统应为常见的平台特定行为提供布尔标志。

### 场景：检查平台是否为移动端

- **前置条件**：应用程序正在运行
- **操作**：检查平台类别
- **预期结果**：当平台为 Android 或 iOS 且为手机形态时，系统应为 isMobile 返回 true

### 场景：检查平台是否为桌面端

- **前置条件**：应用程序正在运行
- **操作**：检查平台类别
- **预期结果**：当平台为 Windows、macOS 或 Linux 时，系统应为 isDesktop 返回 true

### 场景：检查平台是否支持悬停

- **前置条件**：应用程序正在运行
- **操作**：检查悬停支持
- **预期结果**：对于桌面平台，系统应为 supportsHover 返回 true
- **并且**：对于没有指针的移动平台返回 false

### 场景：检查平台是否支持手势

- **前置条件**：应用程序正在运行
- **操作**：检查手势支持
- **预期结果**：对于支持触摸的设备，系统应为 supportsGestures 返回 true
- **并且**：对于没有触摸屏的桌面返回 false

---

## 需求：响应平台变化


系统应在运行时检测并响应平台特性变化。

### 场景：检测屏幕尺寸变化

- **前置条件**：应用程序正在运行
- **操作**：用户调整窗口大小或旋转设备
- **预期结果**：系统应发出平台变化事件
- **并且**：更新屏幕尺寸值
- **并且**：重新评估形态分类

### 场景：检测方向变化

- **前置条件**：应用程序在移动或平板设备上运行
- **操作**：用户旋转设备
- **预期结果**：系统应发出方向变化事件
- **并且**：更新方向值（竖屏/横屏）

---

## 测试覆盖

**测试文件**: `test/adaptive/platform_detection_test.dart`

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

## 相关文档

**相关规格**:
- [layouts.md](layouts.md) - Adaptive layout system
- [layouts.md](layouts.md) - 自适应布局系统
- [components.md](components.md) - Adaptive components
- [components.md](components.md) - 自适应组件

---

**最后更新**: 2026-01-24

**作者**: CardMind Team
