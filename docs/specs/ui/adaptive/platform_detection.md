# 平台检测规格

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

bool isMacOS() {
  return Platform.isMacOS;
}
```

### 场景：检测 Linux 平台

- **前置条件**: 应用程序正在运行
- **操作**: 查询平台
- **预期结果**: 在 Linux 桌面上运行时系统应返回"Linux"

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

bool supportsHoverFlag(BuildContext context) {
  return getPlatformFlags(context).supportsHover;
}
```

### 场景：检查平台是否支持手势

- **前置条件**: 应用程序正在运行
- **操作**: 检查手势支持
- **预期结果**: 对于支持触摸的设备，系统应为 supportsGestures 返回 true
- **并且**: 对于没有触摸屏的桌面返回 false

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

