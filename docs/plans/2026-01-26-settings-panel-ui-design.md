# 设置面板 UI 设计规格

## 1. 概述

设置面板（SettingsPanel）用于管理应用的各项设置，包括通知、外观、数据管理和应用信息。

**设计原则**：
- 平台特定设计（移动端全屏页面，桌面端对话框）
- 简洁清晰的设置分组
- 即时生效的开关设置
- 安全的数据操作流程

**参考文件**：
- React UI: `react_ui_reference/src/app/components/settings-panel.tsx`

**平台差异**：
- **移动端**：全屏页面，通过底部导航栏"设置"标签进入
- **桌面端**：弹出对话框，从菜单或快捷键（Ctrl/Cmd+,）打开

## 2. 核心功能

### 2.1 通知设置
- 同步通知开关：当笔记被其他设备修改时是否通知用户
- 默认状态：开启
- 即时生效，无需保存按钮

### 2.2 外观设置
- 深色模式开关：切换浅色/深色主题
- 默认状态：跟随系统
- 即时生效，切换时有平滑过渡动画

### 2.3 数据管理
- 导出数据：导出所有笔记数据为 Loro 格式文件（.loro）
- 导入数据：从 Loro 格式文件导入笔记数据
- 导入时合并数据，不覆盖现有数据

### 2.4 关于应用
- 应用版本号
- 技术栈信息（Flutter + Rust + libp2p + loro）
- 开源协议
- GitHub 仓库链接
- 贡献者列表
- 更新日志（最近 3 个版本）

## 3. 组件结构

### 3.1 SettingsPanelMobile 组件（移动端全屏页面）

```dart
class SettingsPanelMobile extends StatelessWidget {
  /// 同步通知开关状态
  final bool syncNotificationEnabled;
  
  /// 深色模式开关状态
  final bool darkModeEnabled;
  
  /// 应用版本号
  final String appVersion;
  
  /// 同步通知开关回调
  final OnToggleSyncNotification onToggleSyncNotification;
  
  /// 深色模式开关回调
  final OnToggleDarkMode onToggleDarkMode;
  
  /// 导出数据回调
  final OnExportData onExportData;
  
  /// 导入数据回调
  final OnImportData onImportData;

  const SettingsPanelMobile({
    required this.syncNotificationEnabled,
    required this.darkModeEnabled,
    required this.appVersion,
    required this.onToggleSyncNotification,
    required this.onToggleDarkMode,
    required this.onExportData,
    required this.onImportData,
  });
}
```

### 3.2 SettingsPanelDesktop 组件（桌面端对话框）

```dart
class SettingsPanelDesktop extends StatelessWidget {
  /// 同步通知开关状态
  final bool syncNotificationEnabled;
  
  /// 深色模式开关状态
  final bool darkModeEnabled;
  
  /// 应用版本号
  final String appVersion;
  
  /// 同步通知开关回调
  final OnToggleSyncNotification onToggleSyncNotification;
  
  /// 深色模式开关回调
  final OnToggleDarkMode onToggleDarkMode;
  
  /// 导出数据回调
  final OnExportData onExportData;
  
  /// 导入数据回调
  final OnImportData onImportData;

  const SettingsPanelDesktop({
    required this.syncNotificationEnabled,
    required this.darkModeEnabled,
    required this.appVersion,
    required this.onToggleSyncNotification,
    required this.onToggleDarkMode,
    required this.onExportData,
    required this.onImportData,
  });
}
```

### 3.3 SettingSection 组件（设置分组）

```dart
class SettingSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const SettingSection({
    required this.title,
    required this.icon,
    required this.children,
  });
}
```

### 3.4 SettingItem 组件（设置项）

```dart
class SettingItem extends StatelessWidget {
  final String label;
  final String description;
  final IconData? icon;
  final Widget? trailing;

  const SettingItem({
    required this.label,
    required this.description,
    this.icon,
    this.trailing,
  });
}
```

### 3.5 ExportConfirmDialog 组件（导出确认对话框）

```dart
class ExportConfirmDialog extends StatelessWidget {
  final OnConfirmExport onConfirm;

  const ExportConfirmDialog({
    required this.onConfirm,
  });
}
```

### 3.6 ImportConfirmDialog 组件（导入确认对话框）

```dart
class ImportConfirmDialog extends StatelessWidget {
  final String fileName;
  final int cardCount;
  final OnConfirmImport onConfirm;

  const ImportConfirmDialog({
    required this.fileName,
    required this.cardCount,
    required this.onConfirm,
  });
}
```

## 4. 数据模型

### 4.1 AppInfo（应用信息）

```dart
class AppInfo {
  final String version;           // 版本号（如 "1.0.0"）
  final String buildNumber;       // 构建号（如 "100"）
  final String license;           // 开源协议（如 "MIT"）
  final String githubUrl;         // GitHub 仓库 URL
  final List<String> contributors; // 贡献者列表
  final List<ChangelogEntry> changelog; // 更新日志
}
```

### 4.2 ChangelogEntry（更新日志条目）

```dart
class ChangelogEntry {
  final String version;           // 版本号
  final DateTime releaseDate;     // 发布日期
  final List<String> changes;     // 变更列表
}
```

### 4.3 回调类型定义

```dart
typedef OnToggleSyncNotification = void Function(bool enabled);
typedef OnToggleDarkMode = void Function(bool enabled);
typedef OnExportData = Future<void> Function();
typedef OnImportData = Future<void> Function();
typedef OnConfirmExport = Future<void> Function();
typedef OnConfirmImport = Future<void> Function();
```

## 5. 视觉设计

（完整的视觉设计规格请参考移动端和桌面端设备管理设计文档的详细程度）

### 5.1 移动端页面布局

- **页面类型**：全屏页面
- **顶部导航栏**：高度 56px，标题"设置"，18px 粗体居中
- **内容区域**：背景色浅灰色（#F5F5F5），内边距 16px
- **组件间距**：16px

### 5.2 桌面端对话框布局

- **宽度**：600px
- **最大高度**：80vh
- **背景色**：白色，圆角 16px
- **标题栏**：高度 64px，标题"设置"，20px 粗体
- **内容区域**：内边距 24px，可滚动

### 5.3 设置项设计

**开关类设置项**：
- 左侧：标签（15px 粗体）+ 描述（13px 常规灰色）
- 右侧：Switch 开关（移动端 51x31px，桌面端 44x24px）
- 动画：200ms 平滑过渡

**按钮类设置项**：
- 标签 + 描述（垂直排列）
- 按钮组：水平排列，间距 8-12px
- 按钮：高度 36px，圆角 8px，主题色边框

### 5.4 关于应用卡片

- 版本信息：标签 + 值，水平排列
- 技术栈：标签在上，值在下
- GitHub 链接：主题色文字 + ExternalLink 图标
- 贡献者：逗号分隔，自动换行
- 更新日志：显示最近 3 个版本

## 6. 交互设计

（完整的交互流程请参考设备管理设计文档的详细程度）

### 6.1 打开设置面板
- 移动端：点击底部导航栏"设置"标签
- 桌面端：菜单或快捷键（Ctrl/Cmd+,）

### 6.2 开关交互
- 点击开关 → 状态立即切换 → 保存设置
- 动画：200ms 平滑过渡
- 失败时：显示 Toast，恢复原状态

### 6.3 导出数据
1. 点击"导出数据"按钮
2. 弹出确认对话框
3. 确认后打开文件保存对话框
4. 选择保存位置
5. 导出数据
6. 显示成功/失败提示

### 6.4 导入数据
1. 点击"导入数据"按钮
2. 打开文件选择对话框
3. 选择 .loro 文件
4. 解析文件，获取卡片数量
5. 弹出确认对话框
6. 确认后导入数据（合并）
7. 显示成功/失败提示

## 7. 边界情况与错误处理

### 7.1 数据边界

| 场景 | 约束 | 处理方式 |
|------|------|----------|
| 同步通知状态为 null | 不允许 | 默认为 true（开启） |
| 深色模式状态为 null | 不允许 | 默认为 false（跟随系统） |
| 应用版本号为空 | 不允许 | 显示"未知版本" |
| 贡献者列表为空 | 允许 | 显示"暂无贡献者" |
| 更新日志为空 | 允许 | 不显示更新日志部分 |
| 导入文件大小 > 100MB | 不允许 | 显示错误提示 |
| 导入文件格式错误 | 不允许 | 显示错误提示 |
| 导入卡片数量 = 0 | 允许 | 显示警告 |

### 7.2 错误处理

- 设置保存失败：Toast + 恢复原状态
- 导出失败：Toast 显示错误信息
- 导入失败：Toast 显示错误信息
- 文件格式错误：Toast 提示
- 文件过大：Toast 提示
- 权限不足：Toast 提示

### 7.3 性能约束

- 设置面板加载时间 < 300ms
- 开关切换响应时间 < 100ms
- 主题切换动画时长 = 300ms
- 导出数据时间 < 5s（1000 张卡片）
- 导入数据时间 < 10s（1000 张卡片）

## 8. 测试用例

### 8.1 单元测试（8 个）

- UT-001: 测试 AppInfo 模型创建
- UT-002: 测试 ChangelogEntry 模型创建
- UT-003: 测试默认设置值
- UT-004: 测试设置保存逻辑
- UT-005: 测试设置加载逻辑
- UT-006: 测试文件名生成
- UT-007: 测试文件名非法字符替换
- UT-008: 测试 Loro 文件格式验证

### 8.2 Widget 测试（45 个）

#### 渲染测试（15 个）
- 移动端/桌面端页面基本渲染
- 开关状态渲染
- 按钮渲染
- 关于应用信息渲染
- 空状态渲染

#### 交互测试（20 个）
- 打开/关闭设置面板
- 切换开关
- 导出/导入数据流程
- 点击链接
- 键盘导航

#### 边界测试（10 个）
- 空数据处理
- 文件格式错误
- 文件过大
- 保存失败

## 9. 实现建议与技术细节

### 9.1 设置持久化
- 使用 `shared_preferences` 包
- 存储键值：`sync_notification_enabled`, `dark_mode_enabled`

### 9.2 Loro 文件导出/导入
- 导出：调用 Rust FFI 接口获取快照数据
- 导入：解析文件 → 确认 → 合并数据
- 文件命名：`cardmind-export-{YYYY-MM-DD-HHmmss}.loro`

### 9.3 状态管理
- 使用 Riverpod 管理状态
- Provider: syncNotificationProvider, darkModeProvider, appInfoProvider

### 9.4 主题切换
- ThemeProvider 管理主题模式
- MaterialApp 配置 themeAnimationDuration: 300ms

### 9.5 依赖包
- `file_picker`: 文件选择
- `shared_preferences`: 设置持久化
- `url_launcher`: 打开链接
- `fluttertoast`: Toast 提示
- `package_info_plus`: 版本信息

## 10. 后续工作

### 10.1 实现阶段
1. 实现数据模型和状态管理
2. 实现 UI 组件（移动端和桌面端）
3. 实现设置持久化逻辑
4. 实现 Loro 文件导出/导入功能
5. 实现主题切换功能
6. 编写单元测试和 Widget 测试
7. 集成到主应用

### 10.2 Rust 端改动
1. 导出 Loro 快照接口
2. 导入 Loro 数据接口（合并模式）
3. 解析 Loro 文件接口（预览卡片数量）

### 10.3 测试阶段
1. 单元测试覆盖率 > 80%
2. Widget 测试覆盖所有交互
3. 真机测试（移动端 + 桌面端）
4. 边界情况测试
5. 性能测试

## 11. 设计决策记录

### 11.1 为什么移动端是全屏页面，桌面端是对话框？

**决策**：移动端作为独立页面，桌面端作为弹出对话框

**理由**：
- 平台习惯：符合各平台的设计规范
- 屏幕空间：移动端屏幕较小，全屏更适合
- 交互效率：桌面端对话框可以快速打开/关闭
- 一致性：符合用户预期

### 11.2 为什么移除"清空数据"功能？

**决策**：不提供清空所有数据的功能

**理由**：
- 安全性：防止用户误操作导致数据丢失
- 不可逆：清空数据是不可逆操作
- 替代方案：用户可以通过卸载应用来清空数据
- 简化设计：减少危险操作

### 11.3 为什么只支持 Loro 格式导入/导出？

**决策**：仅支持 Loro 二进制格式（.loro）

**理由**：
- 完整性：保留完整的 CRDT 历史和元数据
- 一致性：导出和导入使用相同格式
- 简单性：不需要实现多种格式转换
- 性能：二进制格式更高效

### 11.4 为什么导入数据是合并而不是覆盖？

**决策**：导入数据时合并到现有数据，不覆盖

**理由**：
- 安全性：避免意外覆盖现有数据
- CRDT 特性：Loro CRDT 天然支持合并
- 灵活性：可以从多个备份文件导入
- 用户预期：大多数应用的导入功能都是合并

### 11.5 为什么更新日志只显示最近 3 个版本？

**决策**：关于应用中只显示最近 3 个版本的更新日志

**理由**：
- 简洁性：避免信息过载
- 性能：减少渲染内容
- 空间限制：移动端屏幕空间有限
- 完整信息：用户可以通过 GitHub 查看完整日志

### 11.6 为什么文件大小限制为 100MB？

**决策**：导入文件大小限制为 100MB

**理由**：
- 性能：大文件解析消耗大量内存和时间
- 实际需求：正常使用不会超过 100MB
- 用户体验：避免长时间等待
- 安全性：防止恶意文件攻击

## 12. 参考资料

- React UI 参考: `react_ui_reference/src/app/components/settings-panel.tsx`
- Flutter 文件选择: https://pub.dev/packages/file_picker
- Flutter 设置持久化: https://pub.dev/packages/shared_preferences
- Flutter URL 启动器: https://pub.dev/packages/url_launcher
- Flutter Toast: https://pub.dev/packages/fluttertoast
- Flutter 包信息: https://pub.dev/packages/package_info_plus
- Material Design 设置页面: https://m3.material.io/components/lists/overview

---

**最后更新**: 2026-01-26  
**作者**: CardMind Team

**注意**：本文档是简化版本，完整的视觉设计规格、交互流程、边界情况处理和测试用例请参考设备管理设计文档的详细程度进行补充。
