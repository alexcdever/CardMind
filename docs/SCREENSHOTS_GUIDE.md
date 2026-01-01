# CardMind 应用商店截图指南

## 截图策略

应用商店截图是用户下载前的第一印象，需要：
- 展示核心功能
- 突出独特卖点
- 清晰美观
- 符合平台规范

## 所需截图列表

### 必备截图（5张）

1. **主界面** - 卡片列表
   - 展示：多张卡片、网格/列表布局
   - 重点：响应式设计、Material Design

2. **编辑器** - 创建/编辑卡片
   - 展示：Markdown 编辑界面
   - 重点：语法高亮、工具栏、预览切换

3. **卡片详情** - Markdown 渲染
   - 展示：完整渲染效果（标题、列表、代码块）
   - 重点：所见即所得、排版优雅

4. **深色模式** - 主题切换
   - 展示：深色主题下的界面
   - 重点：护眼、夜间模式

5. **设置页面** - 应用设置
   - 展示：设置选项、关于页面
   - 重点：简洁易用

### 可选截图（2-3张）

6. **响应式布局** - 平板/大屏
   - 展示：双列/三列网格视图
   - 重点：适配多种屏幕

7. **操作流程** - 创建卡片流程
   - 展示：从创建到保存的完整步骤
   - 重点：操作简单直观

8. **性能展示** - 大量卡片
   - 展示：加载100+张卡片
   - 重点：流畅不卡顿

## 平台规范

### Android (Google Play)

**截图要求**:
- 最少: 2 张
- 最多: 8 张
- 尺寸:
  - 手机: 1080x1920 或 1080x2340 (9:16 或 9:19.5)
  - 7寸平板: 1200x1920 (10:16)
  - 10寸平板: 1600x2560 (10:16)
- 格式: PNG 或 JPG（24位，无透明）
- 大小: 每张 < 8MB

**推荐尺寸** (手机):
- 1080x2340 px (覆盖主流Android手机屏幕比例)

**顺序**: 按功能重要性排列

### Windows Store

**截图要求**:
- 最少: 1 张
- 最多: 10 张
- 尺寸:
  - 推荐: 1920x1080 (16:9)
  - 可选: 2560x1440, 3840x2160
- 格式: PNG, JPG, JPEG
- 大小: 每张 < 2MB

**顺序**: 第一张最重要（缩略图）

## 截图制作步骤

### 1. 准备测试数据

在应用中创建示例卡片：

```markdown
# 示例卡片 1 - 学习笔记
## Rust 所有权
- 每个值都有一个所有者
- 同时只能有一个所有者
- 所有者离开作用域时，值被释放

# 示例卡片 2 - 灵感记录
**项目想法**: 开发一款笔记应用
使用 CRDT 技术实现离线优先设计

# 示例卡片 3 - 代码片段
\```rust
fn main() {
    println!("Hello, CardMind!");
}
\```

# 示例卡片 4 - 待办事项
- [x] 完成 MVP 开发
- [x] 编写测试
- [ ] 发布到应用商店
```

### 2. 设置截图环境

**Android**:
```bash
# 启动模拟器（推荐 Pixel 6）
flutter emulators --launch Pixel_6_API_33

# 或使用真机
adb devices
```

**Windows**:
- 直接运行应用
- 设置窗口大小为标准尺寸（如 1366x768）

### 3. 截取屏幕

**Android截图**:
- 使用 Android Studio Device Manager 截图工具
- 或命令行: `adb shell screencap -p /sdcard/screenshot.png && adb pull /sdcard/screenshot.png`
- 或设备自带截图: 音量下 + 电源键

**Windows截图**:
- Windows Snipping Tool (Win + Shift + S)
- 或第三方工具: ShareX, Greenshot

### 4. 后期处理

**裁剪和调整**:
- 确保尺寸符合平台要求
- 移除系统状态栏（可选）
- 统一所有截图的尺寸

**工具推荐**:
- **Figma** (在线) - 专业设计工具
- **GIMP** (免费) - 图片编辑
- **ImageMagick** (命令行) - 批量处理

```bash
# ImageMagick 批量调整尺寸
magick mogrify -resize 1080x2340^ -gravity center -extent 1080x2340 *.png
```

**添加设备框架**（可选）:
- 使用 [Device Frame Generator](https://developer.android.com/distribute/marketing-tools/device-art-generator)
- 或 [Mockuphone](https://mockuphone.com/)

### 5. 优化文件大小

压缩PNG文件：
```bash
# 使用 TinyPNG CLI
tinypng *.png

# 或在线工具
# https://tinypng.com/
```

## 截图内容建议

### 截图 1: 主界面（卡片列表）
**目标**: 展示核心功能，吸引用户
**内容**:
- 5-8 张卡片
- 混合不同类型内容（笔记、代码、待办）
- 显示创建按钮
- 浅色主题

**文案** (可选叠加):
- "卡片式笔记，井然有序"
- "Organize Your Thoughts"

### 截图 2: 编辑器
**目标**: 展示 Markdown 编辑功能
**内容**:
- 编辑中的卡片
- 部分 Markdown 语法可见
- 工具栏/保存按钮
- 实时预览提示

**文案**:
- "完整 Markdown 支持"
- "Full Markdown Support"

### 截图 3: 卡片详情
**目标**: 展示渲染效果
**内容**:
- 丰富格式的卡片（标题、列表、代码块）
- 完整渲染效果
- 编辑/删除按钮

**文案**:
- "所见即所得"
- "Beautiful Rendering"

### 截图 4: 深色模式
**目标**: 展示主题功能
**内容**:
- 深色主题下的主界面或编辑器
- 突出护眼效果

**文案**:
- "深色模式，护眼舒适"
- "Dark Mode Support"

### 截图 5: 设置页面
**目标**: 展示应用设置
**内容**:
- 设置界面
- 主题切换开关
- 关于信息

**文案**:
- "简洁易用的设置"
- "Simple & Intuitive"

## 截图检查清单

完成截图后，确认：

- [ ] 所有截图尺寸一致且符合平台要求
- [ ] 截图内容清晰，无模糊或失真
- [ ] 展示了核心功能和主要卖点
- [ ] 包含不同使用场景（浅色/深色主题）
- [ ] 移除了测试/调试信息
- [ ] 文字可读（如果包含文案叠加）
- [ ] 文件大小符合要求（已压缩）
- [ ] 文件命名规范（如：01_main_screen.png）
- [ ] 截图顺序合理（最重要的在前）

## 文件组织

建议的目录结构：

```
assets/screenshots/
├── android/
│   ├── phone/
│   │   ├── 01_main_screen.png         (1080x2340)
│   │   ├── 02_editor.png
│   │   ├── 03_detail.png
│   │   ├── 04_dark_mode.png
│   │   └── 05_settings.png
│   └── tablet/
│       └── (可选)
├── windows/
│   ├── 01_main_screen.png             (1920x1080)
│   ├── 02_editor.png
│   ├── 03_detail.png
│   ├── 04_dark_mode.png
│   └── 05_settings.png
└── README.md                          (截图说明)
```

## 替代方案（快速版）

如果时间紧迫，最少准备 2-3 张关键截图：

1. **主界面** - 展示核心功能
2. **编辑器** - 展示 Markdown 支持
3. **深色模式** - 展示主题功能

其他截图可以在后续更新时补充。

## 提示和技巧

1. **真实设备优于模拟器**: 实际设备的截图更真实
2. **使用高质量测试数据**: 避免"测试"、"aaaa"等无意义内容
3. **保持一致性**: 所有截图使用相同的配色和风格
4. **突出差异化**: 展示 CardMind 独特的功能
5. **考虑国际化**: 如果支持多语言，准备不同语言版本的截图

## 当前状态

📋 **待办**:
- [ ] 准备测试数据（示例卡片）
- [ ] 截取 5 张核心截图
- [ ] 调整截图尺寸（Android: 1080x2340, Windows: 1920x1080）
- [ ] 优化文件大小
- [ ] 组织截图文件
- [ ] 上传到应用商店

💡 **临时方案**:
MVP 发布前必须至少准备 2 张截图（主界面 + 编辑器），其他截图可以后续补充。

## 参考资源

- [Google Play Screenshots Guidelines](https://support.google.com/googleplay/android-developer/answer/9866151)
- [Microsoft Store Screenshots Requirements](https://docs.microsoft.com/en-us/windows/apps/publish/screenshots-and-images)
- [App Store Screenshot Specifications](https://help.apple.com/app-store-connect/#/devd274dd925)
- [Device Art Generator](https://developer.android.com/distribute/marketing-tools/device-art-generator)
