# CardMind 应用图标指南

## 图标设计理念

CardMind 的图标应该体现以下特点：
- **简洁**: 简单明了的设计
- **识别性**: 一眼就能认出是卡片/笔记应用
- **现代**: 符合 Material Design 规范
- **专业**: 传递可信赖的感觉

## 图标元素建议

### 核心元素
- **卡片形状**: 代表卡片式笔记
- **笔/书写**: 代表笔记功能
- **堆叠效果**: 表示多张卡片组织

### 颜色方案

**主色调建议**:
- 蓝色系（专业、可信）: `#2196F3`, `#1976D2`
- 紫色系（创意、灵感）: `#9C27B0`, `#7B1FA2`
- 绿色系（清新、组织）: `#4CAF50`, `#388E3C`

**辅助色**:
- 白色/浅灰: 卡片背景
- 深灰: 文字或边框

## 所需图标尺寸

### Android

**启动图标（Launcher Icons）**:
- `mipmap-mdpi/ic_launcher.png`: 48x48 px
- `mipmap-hdpi/ic_launcher.png`: 72x72 px
- `mipmap-xhdpi/ic_launcher.png`: 96x96 px
- `mipmap-xxhdpi/ic_launcher.png`: 144x144 px
- `mipmap-xxxhdpi/ic_launcher.png`: 192x192 px

**圆形图标（Adaptive Icons）**:
- 前景层: 108x108 dp (中心 72x72 dp 安全区域)
- 背景层: 108x108 dp

**Play Store**:
- 高分辨率图标: 512x512 px (PNG, 32位, 带透明通道)
- 特色图形: 1024x500 px (可选)

### Windows

**应用图标**:
- Square44x44Logo: 44x44 px (推荐尺寸)
- Square150x150Logo: 150x150 px
- Square310x310Logo: 310x310 px (可选)
- Wide310x150Logo: 310x150 px (可选)

**文件资产**:
- 将所有图标放在 `windows/runner/resources/`
- 更新 `windows/runner/Runner.rc` 文件引用

### iOS (未来)

**App Icon**:
- 20x20, 29x29, 40x40, 60x60, 76x76, 83.5x83.5, 1024x1024

## 图标制作工具推荐

### 在线工具
1. **Figma** (免费) - 专业设计工具
2. **Canva** (免费/付费) - 简单易用
3. **Icon Kitchen** (免费) - Android 图标生成器
4. **App Icon Generator** (免费) - 多平台图标生成

### 桌面软件
1. **Adobe Illustrator** - 矢量图标设计
2. **Inkscape** (免费) - 开源矢量编辑器
3. **GIMP** (免费) - 位图编辑器

### Flutter 工具
```bash
# 使用 flutter_launcher_icons 自动生成
# 1. 添加依赖到 pubspec.yaml (dev_dependencies)
flutter_launcher_icons: ^0.13.0

# 2. 配置图标
flutter_icons:
  android: true
  ios: false  # 暂不支持
  image_path: "assets/icon/app_icon.png"  # 1024x1024 PNG
  adaptive_icon_background: "#2196F3"
  adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"

# 3. 运行生成命令
flutter pub run flutter_launcher_icons
```

## 设计示例（概念）

### 方案 1: 卡片堆叠
```
+-------------------+
|   +-----------+   |
|   |           |   |  ← 前面的卡片（白色）
|   |     📝    |   |  ← 笔/标记图标
|   |           |   |
|   +-----------+   |
| +-----------+     |  ← 后面的卡片（浅灰）
+-------------------+
背景: 蓝色渐变
```

### 方案 2: 单张卡片
```
+-------------------+
|                   |
|   +-----+         |
|   | --- |         |  ← 简化的文字行
|   | --- |         |
|   | --  |         |
|   +-----+         |
|                   |
+-------------------+
背景: 纯色
前景: 白色卡片图标
```

### 方案 3: 字母 C
```
+-------------------+
|                   |
|      CCCCC        |
|     C             |  ← 字母 C（CardMind）
|     C             |
|      CCCCC        |
|                   |
+-------------------+
使用圆角和渐变
```

## 实现步骤

### 1. 创建主图标（1024x1024）

创建一个高分辨率的主图标文件 `app_icon.png`：
- 尺寸: 1024x1024 px
- 格式: PNG，32位色深
- 背景: 透明或纯色
- 内容: 居中，留出安全边距（10%）

### 2. 创建自适应图标（Android）

**前景图层** `app_icon_foreground.png`:
- 尺寸: 1024x1024 px（对应 108 dp）
- 安全区域: 中心 768x768 px（对应 72 dp）
- 背景: 透明
- 内容: 图标主体

**背景图层**: 使用纯色或渐变
- 在 pubspec.yaml 中配置颜色

### 3. 生成所有尺寸

使用 `flutter_launcher_icons` 自动生成所有需要的尺寸：

```yaml
# pubspec.yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.0

flutter_icons:
  android: true
  ios: false
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#2196F3"
  adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"
```

运行:
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

### 4. Windows 图标

手动创建 `.ico` 文件或使用在线工具转换：

1. 准备多个尺寸的 PNG: 16, 32, 48, 256
2. 使用在线工具转换为 `.ico`: https://www.icoconverter.com/
3. 保存为 `windows/runner/resources/app_icon.ico`

## 图标检查清单

创建图标后，确保：

- [ ] 在不同背景色（白/黑/彩色）上都清晰可见
- [ ] 缩小到最小尺寸（44x44）仍然可识别
- [ ] 圆角版本（Android adaptive）显示正常
- [ ] 符合平台设计规范（Material Design / Fluent Design）
- [ ] 没有版权问题（使用自己设计或免费资源）
- [ ] PNG 文件已优化（TinyPNG 等工具压缩）

## 当前状态

📋 **待办**:
- [ ] 设计应用图标主视觉
- [ ] 创建 1024x1024 主图标
- [ ] 创建 Android adaptive icon 前景层
- [ ] 配置 flutter_launcher_icons
- [ ] 生成所有平台所需尺寸
- [ ] 创建 Windows .ico 文件
- [ ] 测试图标在实际设备上的显示效果

💡 **临时方案**:
在正式图标设计完成前，可以使用 Flutter 默认图标或简单的文字图标（字母 C）作为占位符。

## 参考资源

- [Material Design Icons Guidelines](https://material.io/design/iconography/product-icons.html)
- [Android Adaptive Icons](https://developer.android.com/guide/practices/ui_guidelines/icon_design_adaptive)
- [Windows App Icon Guidelines](https://docs.microsoft.com/en-us/windows/apps/design/style/app-icons-and-logos)
- [Flutter Icons Documentation](https://docs.flutter.dev/deployment/android#launcher-icons)
- [flutter_launcher_icons Package](https://pub.dev/packages/flutter_launcher_icons)

---

**注意**: 图标设计需要图形设计技能。如果团队中没有设计师，建议：
1. 使用简单的几何形状设计
2. 聘请 Fiverr/Upwork 等平台的设计师
3. 使用 Logo Maker 等在线工具生成
4. 从 Flaticon 等网站获取免费图标资源（注意许可证）
