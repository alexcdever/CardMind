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

### 场景：检查平台是否为桌面端

- **前置条件**: 应用程序正在运行
- **操作**: 检查平台类别
- **预期结果**: 当平台为 Windows、macOS 或 Linux 时，系统应为 isDesktop 返回 true

bool supportsHoverFlag(BuildContext context) {
  return getPlatformFlags(context).supportsHover;
}

### 场景：检测方向变化

- **前置条件**: 应用程序在移动或平板设备上运行
- **操作**: 用户旋转设备
- **预期结果**: 系统应发出方向变化事件
- **并且**: 更新方向值（竖屏/横屏）

