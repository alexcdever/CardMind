# 平台检测规格

**状态**: 活跃
**依赖**: 无
**相关测试**: `test/feature/adaptive/platform_detector_feature_test.dart`

---

## 概述

本规格定义平台检测系统，识别当前平台与设备特性以启用自适应 UI 行为。

**技术栈**:
- Flutter 3.x - UI 框架
- dart:io - 平台检测
- MediaQuery - 屏幕信息
- ChangeNotifier - 状态管理

**核心功能**:
- 操作系统检测
- 设备形态分类
- 输入能力检测
- 屏幕特性查询
- 平台变化响应

**平台分类**:
- 移动端: Android, iOS (< 600dp)
- 平板电脑: Android, iOS (>= 600dp)
- 桌面端: Windows, macOS, Linux

**输入能力**:
- 触摸: 移动端和平板电脑
- 指针: 桌面端
- 物理键盘: 桌面端

---

## 需求：检测操作系统平台

系统应准确检测操作系统平台。

### 场景：检测 Android 平台

- **前置条件**: 应用程序正在运行
- **操作**: 查询平台
- **预期结果**: 在 Android 设备上运行时系统应返回"Android"

**实现逻辑**:

```dart
import 'dart:io';

enum PlatformType {
  android,
  ios,
  windows,
  macos,
  linux,
  web,
  unknown,
}

PlatformType detectPlatform() {
  if (Platform.isAndroid) {
    return PlatformType.android;
  } else if (Platform.isIOS) {
    return PlatformType.ios;
  } else if (Platform.isWindows) {
    return PlatformType.windows;
  } else if (Platform.isMacOS) {
    return PlatformType.macos;
  } else if (Platform.isLinux) {
    return PlatformType.linux;
  } else {
    return PlatformType.unknown;
  }
}

String getPlatformName() {
  final platform = detectPlatform();
  return platform.toString().split('.').last;
}
```

### 场景：检测 iOS 平台

- **前置条件**: 应用程序正在运行
- **操作**: 查询平台
- **预期结果**: 在 iPhone 或 iPad 上运行时系统应返回"iOS"

**实现逻辑**:

```dart
bool isIOS() {
  return Platform.isIOS;
}

bool isIPad(BuildContext context) {
  // iPad 通常有更大的屏幕
  final size = MediaQuery.of(context).size;
  return Platform.isIOS && size.shortestSide >= 600;
}

bool isIPhone(BuildContext context) {
  final size = MediaQuery.of(context).size;
  return Platform.isIOS && size.shortestSide < 600;
}
```

### 场景：检测 Windows 平台

- **前置条件**: 应用程序正在运行
- **操作**: 查询平台
- **预期结果**: 在 Windows 桌面上运行时系统应返回"Windows"

**实现逻辑**:

```dart
bool isWindows() {
  return Platform.isWindows;
}
```

### 场景：检测 macOS 平台

- **前置条件**: 应用程序正在运行
- **操作**: 查询平台
- **预期结果**: 在 Mac 计算机上运行时系统应返回"macOS"

**实现逻辑**:

```dart
bool isMacOS() {
  return Platform.isMacOS;
}
```

### 场景：检测 Linux 平台

- **前置条件**: 应用程序正在运行
- **操作**: 查询平台
- **预期结果**: 在 Linux 桌面上运行时系统应返回"Linux"

**实现逻辑**:

```dart
bool isLinux() {
  return Platform.isLinux;
}
```

---

## 需求：检测设备形态

系统应根据屏幕尺寸和平台确定设备形态。

### 场景：检测移动手机

- **前置条件**: 应用程序正在运行
- **操作**: 确定设备形态
- **预期结果**: 当屏幕宽度 < 600dp 且平台为 Android 或 iOS 时系统应分类为"手机"

**实现逻辑**:

```dart
enum FormFactor {
  phone,
  tablet,
  desktop,
}

FormFactor detectFormFactor(BuildContext context) {
  final platform = detectPlatform();
  final width = MediaQuery.of(context).size.width;
  
  // 桌面平台
  if (platform == PlatformType.windows ||
      platform == PlatformType.macos ||
      platform == PlatformType.linux) {
    return FormFactor.desktop;
  }
  
  // 移动平台根据屏幕尺寸分类
  if (platform == PlatformType.android || platform == PlatformType.ios) {
    if (width < 600) {
      return FormFactor.phone;
    } else {
      return FormFactor.tablet;
    }
  }
  
  return FormFactor.desktop;
}

bool isPhone(BuildContext context) {
  return detectFormFactor(context) == FormFactor.phone;
}
```

### 场景：检测平板电脑

- **前置条件**: 应用程序正在运行
- **操作**: 确定设备形态
- **预期结果**: 当屏幕宽度 >= 600dp 且平台为 Android 或 iOS 时系统应分类为"平板电脑"

**实现逻辑**:

```dart
bool isTablet(BuildContext context) {
  return detectFormFactor(context) == FormFactor.tablet;
}
```

### 场景：检测桌面

- **前置条件**: 应用程序正在运行
- **操作**: 确定设备形态
- **预期结果**: 当平台为 Windows、macOS 或 Linux 时系统应分类为"桌面"

**实现逻辑**:

```dart
bool isDesktop(BuildContext context) {
  return detectFormFactor(context) == FormFactor.desktop;
}

bool isDesktopPlatform() {
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}
```

---

## 需求：检测输入能力

系统应检测设备上可用的输入方法。

### 场景：检测触摸输入

- **前置条件**: 应用程序正在运行
- **操作**: 查询输入能力
- **预期结果**: 对于移动和平板设备，系统应返回 true 表示支持触摸
- **并且**: 对于没有触摸屏的传统桌面平台返回 false

**实现逻辑**:

```dart
class InputCapabilities {
  final bool supportsTouch;
  final bool supportsPointer;
  final bool supportsKeyboard;
  
  InputCapabilities({
    required this.supportsTouch,
    required this.supportsPointer,
    required this.supportsKeyboard,
  });
}

InputCapabilities detectInputCapabilities(BuildContext context) {
  final platform = detectPlatform();
  final formFactor = detectFormFactor(context);
  
  bool supportsTouch = false;
  bool supportsPointer = false;
  bool supportsKeyboard = false;
  
  // 移动和平板支持触摸
  if (formFactor == FormFactor.phone || formFactor == FormFactor.tablet) {
    supportsTouch = true;
    supportsKeyboard = false; // 仅虚拟键盘
  }
  
  // 桌面支持指针和键盘
  if (formFactor == FormFactor.desktop) {
    supportsPointer = true;
    supportsKeyboard = true;
    supportsTouch = false; // 传统桌面无触摸屏
  }
  
  return InputCapabilities(
    supportsTouch: supportsTouch,
    supportsPointer: supportsPointer,
    supportsKeyboard: supportsKeyboard,
  );
}

bool supportsTouch(BuildContext context) {
  return detectInputCapabilities(context).supportsTouch;
}
```

### 场景：检测鼠标/指针输入

- **前置条件**: 应用程序正在运行
- **操作**: 查询输入能力
- **预期结果**: 对于桌面平台，系统应返回 true 表示支持指针
- **并且**: 对于不支持鼠标的移动手机返回 false

**实现逻辑**:

```dart
bool supportsPointer(BuildContext context) {
  return detectInputCapabilities(context).supportsPointer;
}

bool supportsHover(BuildContext context) {
  // 悬停需要指针输入
  return supportsPointer(context);
}
```

### 场景：检测键盘输入

- **前置条件**: 应用程序正在运行
- **操作**: 查询输入能力
- **预期结果**: 对于桌面的物理键盘，系统应返回 true
- **并且**: 对于仅有虚拟键盘的移动设备返回 false

**实现逻辑**:

```dart
bool supportsPhysicalKeyboard(BuildContext context) {
  return detectInputCapabilities(context).supportsKeyboard;
}

bool hasVirtualKeyboard(BuildContext context) {
  // 移动设备有虚拟键盘
  final formFactor = detectFormFactor(context);
  return formFactor == FormFactor.phone || formFactor == FormFactor.tablet;
}
```

---

## 需求：检测屏幕特性

系统应提供有关屏幕尺寸和像素密度的信息。

### 场景：获取屏幕宽度（dp）

- **前置条件**: 应用程序正在运行
- **操作**: 查询屏幕尺寸
- **预期结果**: 系统应返回以密度无关像素（dp）为单位的屏幕宽度

**实现逻辑**:

```dart
class ScreenInfo {
  final double widthDp;
  final double heightDp;
  final double pixelDensity;
  final Orientation orientation;
  
  ScreenInfo({
    required this.widthDp,
    required this.heightDp,
    required this.pixelDensity,
    required this.orientation,
  });
}

ScreenInfo getScreenInfo(BuildContext context) {
  final size = MediaQuery.of(context).size;
  final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
  
  return ScreenInfo(
    widthDp: size.width,
    heightDp: size.height,
    pixelDensity: devicePixelRatio,
    orientation: size.width > size.height 
        ? Orientation.landscape 
        : Orientation.portrait,
  );
}

double getScreenWidth(BuildContext context) {
  return MediaQuery.of(context).size.width;
}
```

### 场景：获取屏幕高度（dp）

- **前置条件**: 应用程序正在运行
- **操作**: 查询屏幕尺寸
- **预期结果**: 系统应返回以密度无关像素（dp）为单位的屏幕高度

**实现逻辑**:

```dart
double getScreenHeight(BuildContext context) {
  return MediaQuery.of(context).size.height;
}
```

### 场景：获取像素密度

- **前置条件**: 应用程序正在运行
- **操作**: 查询屏幕特性
- **预期结果**: 系统应返回设备像素比（例如,1.0、2.0、3.0）

**实现逻辑**:

```dart
double getPixelDensity(BuildContext context) {
  return MediaQuery.of(context).devicePixelRatio;
}

bool isHighDensityScreen(BuildContext context) {
  return getPixelDensity(context) >= 2.0;
}
```

### 场景：检测屏幕方向

- **前置条件**: 应用程序正在运行
- **操作**: 查询屏幕方向
- **预期结果**: 当高度 > 宽度时系统应返回"竖屏"
- **并且**: 当宽度 > 高度时返回"横屏"

**实现逻辑**:

```dart
Orientation getOrientation(BuildContext context) {
  final size = MediaQuery.of(context).size;
  return size.width > size.height 
      ? Orientation.landscape 
      : Orientation.portrait;
}

bool isPortrait(BuildContext context) {
  return getOrientation(context) == Orientation.portrait;
}

bool isLandscape(BuildContext context) {
  return getOrientation(context) == Orientation.landscape;
}
```

---

## 需求：提供平台特定的行为标志

系统应为常见的平台特定行为提供布尔标志。

### 场景：检查平台是否为移动端

- **前置条件**: 应用程序正在运行
- **操作**: 检查平台类别
- **预期结果**: 当平台为 Android 或 iOS 且为手机形态时，系统应为 isMobile 返回 true

**实现逻辑**:

```dart
class PlatformFlags {
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final bool supportsHover;
  final bool supportsGestures;
  
  PlatformFlags({
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
    required this.supportsHover,
    required this.supportsGestures,
  });
}

PlatformFlags getPlatformFlags(BuildContext context) {
  final formFactor = detectFormFactor(context);
  final capabilities = detectInputCapabilities(context);
  
  return PlatformFlags(
    isMobile: formFactor == FormFactor.phone,
    isTablet: formFactor == FormFactor.tablet,
    isDesktop: formFactor == FormFactor.desktop,
    supportsHover: capabilities.supportsPointer,
    supportsGestures: capabilities.supportsTouch,
  );
}

bool isMobile(BuildContext context) {
  return getPlatformFlags(context).isMobile;
}
```

### 场景：检查平台是否为桌面端

- **前置条件**: 应用程序正在运行
- **操作**: 检查平台类别
- **预期结果**: 当平台为 Windows、macOS 或 Linux 时，系统应为 isDesktop 返回 true

**实现逻辑**:

```dart
bool isDesktopFlag(BuildContext context) {
  return getPlatformFlags(context).isDesktop;
}
```

### 场景：检查平台是否支持悬停

- **前置条件**: 应用程序正在运行
- **操作**: 检查悬停支持
- **预期结果**: 对于桌面平台，系统应为 supportsHover 返回 true
- **并且**: 对于没有指针的移动平台返回 false

**实现逻辑**:

```dart
bool supportsHoverFlag(BuildContext context) {
  return getPlatformFlags(context).supportsHover;
}
```

### 场景：检查平台是否支持手势

- **前置条件**: 应用程序正在运行
- **操作**: 检查手势支持
- **预期结果**: 对于支持触摸的设备，系统应为 supportsGestures 返回 true
- **并且**: 对于没有触摸屏的桌面返回 false

**实现逻辑**:

```dart
bool supportsGestures(BuildContext context) {
  return getPlatformFlags(context).supportsGestures;
}
```

---

## 需求：响应平台变化

系统应在运行时检测并响应平台特性变化。

### 场景：检测屏幕尺寸变化

- **前置条件**: 应用程序正在运行
- **操作**: 用户调整窗口大小或旋转设备
- **预期结果**: 系统应发出平台变化事件
- **并且**: 更新屏幕尺寸值
- **并且**: 重新评估形态分类

**实现逻辑**:

```dart
import 'dart:async';

class PlatformChangeNotifier extends ChangeNotifier {
  ScreenInfo? _lastScreenInfo;
  FormFactor? _lastFormFactor;
  
  void checkForChanges(BuildContext context) {
    final currentScreenInfo = getScreenInfo(context);
    final currentFormFactor = detectFormFactor(context);
    
    bool hasChanged = false;
    
    // 检查屏幕尺寸变化
    if (_lastScreenInfo == null ||
        _lastScreenInfo!.widthDp != currentScreenInfo.widthDp ||
        _lastScreenInfo!.heightDp != currentScreenInfo.heightDp) {
      hasChanged = true;
      _lastScreenInfo = currentScreenInfo;
    }
    
    // 检查形态变化
    if (_lastFormFactor == null ||
        _lastFormFactor != currentFormFactor) {
      hasChanged = true;
      _lastFormFactor = currentFormFactor;
    }
    
    if (hasChanged) {
      notifyListeners();
    }
  }
}

class PlatformAwareWidget extends StatefulWidget {
  final Widget Function(BuildContext, PlatformFlags) builder;
  
  @override
  _PlatformAwareWidgetState createState() => _PlatformAwareWidgetState();
}

class _PlatformAwareWidgetState extends State<PlatformAwareWidget> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final flags = getPlatformFlags(context);
        return widget.builder(context, flags);
      },
    );
  }
}
```

### 场景：检测方向变化

- **前置条件**: 应用程序在移动或平板设备上运行
- **操作**: 用户旋转设备
- **预期结果**: 系统应发出方向变化事件
- **并且**: 更新方向值（竖屏/横屏）

**实现逻辑**:

```dart
class OrientationChangeNotifier extends ChangeNotifier {
  Orientation? _lastOrientation;
  
  void checkForOrientationChange(BuildContext context) {
    final currentOrientation = getOrientation(context);
    
    if (_lastOrientation == null ||
        _lastOrientation != currentOrientation) {
      _lastOrientation = currentOrientation;
      notifyListeners();
    }
  }
}

class OrientationAwareWidget extends StatelessWidget {
  final Widget Function(BuildContext, Orientation) builder;
  
  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        return builder(context, orientation);
      },
    );
  }
}
```

---

## 测试覆盖

**测试文件**: `test/feature/adaptive/platform_detector_feature_test.dart`

**单元测试**:
- `it_should_detect_android_platform()` - Android 检测
- `it_should_detect_ios_platform()` - iOS 检测
- `it_should_detect_windows_platform()` - Windows 检测
- `it_should_detect_macos_platform()` - macOS 检测
- `it_should_detect_linux_platform()` - Linux 检测
- `it_should_classify_phone_form_factor()` - 手机分类
- `it_should_classify_tablet_form_factor()` - 平板分类
- `it_should_classify_desktop_form_factor()` - 桌面分类
- `it_should_detect_touch_input()` - 触摸检测
- `it_should_detect_pointer_input()` - 指针检测
- `it_should_detect_keyboard_input()` - 键盘检测
- `it_should_return_screen_width_in_dp()` - 屏幕宽度
- `it_should_return_screen_height_in_dp()` - 屏幕高度
- `it_should_return_pixel_density()` - 像素密度
- `it_should_detect_portrait_orientation()` - 竖屏方向
- `it_should_detect_landscape_orientation()` - 横屏方向
- `it_should_emit_event_on_screen_size_change()` - 尺寸变化事件
- `it_should_emit_event_on_orientation_change()` - 方向变化事件

**验收标准**:
- [x] 所有单元测试通过
- [x] 平台检测在所有支持的平台上准确
- [x] 形态分类正确
- [x] 输入能力检测可靠工作
- [x] 平台变化事件正确发出
- [x] 代码审查通过
