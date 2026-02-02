# Settings Panel Specification
# 设置面板规格

**版本**: 1.0.0

**状态**: 活跃

**依赖**: [device_config.md](../../../architecture/storage/device_config.md), [sync/protocol.md](../../../architecture/sync/service.md)

**相关测试**: `test/widgets/settings_panel_test.dart`

---

## 概述


本规格定义了设置面板组件，显示和管理按逻辑部分组织的应用程序设置。

---

## 需求：显示主题设置


系统应提供主题自定义选项。

### 场景：显示当前主题模式

- **前置条件**：设置面板已显示
- **操作**：渲染面板
- **预期结果**：系统应显示当前主题模式（浅色/深色）
- **并且**：显示切换或开关控件

### 场景：切换主题

- **前置条件**：设置面板已显示
- **操作**：用户切换主题开关
- **预期结果**：系统应使用新主题偏好调用 onThemeChanged 回调
- **并且**：立即应用主题更改

---

## 需求：显示同步设置


系统应显示与同步相关的配置选项。

### 场景：显示自动同步偏好

- **前置条件**：设置面板已显示
- **操作**：显示同步设置
- **预期结果**：系统应显示自动同步启用/禁用切换

### 场景：显示同步频率选项

- **前置条件**：自动同步已启用
- **操作**：显示同步设置
- **预期结果**：系统应显示同步频率选项（立即、每 5 分钟等）

---

## 需求：显示应用程序信息


系统应显示应用程序版本和构建信息。

### 场景：显示应用版本

- **前置条件**：设置面板已显示
- **操作**：显示关于部分
- **预期结果**：系统应从包信息中显示应用程序版本号

### 场景：显示应用名称和描述

- **前置条件**：设置面板已显示
- **操作**：显示关于部分
- **预期结果**：系统应显示应用程序名称
- **并且**：显示应用的简要描述

---

## 需求：提供到设备管理的导航


系统应链接到设备管理界面。

### 场景：导航到设备管理器

- **前置条件**：设置面板已显示
- **操作**：用户点击"管理设备"选项
- **预期结果**：系统应导航到设备管理屏幕

---

## 需求：支持数据管理操作


系统应提供管理应用程序数据的选项。

### 场景：清除本地缓存

- **前置条件**：设置面板已显示
- **操作**：用户选择"清除缓存"选项
- **预期结果**：系统应显示确认对话框
- **并且**：确认后清除缓存数据

### 场景：导出数据

- **前置条件**：设置面板已显示
- **操作**：用户选择"导出数据"选项
- **预期结果**：系统应启动数据导出流程
- **并且**：允许用户保存导出的数据文件

---

## 需求：显示法律和隐私信息


系统应提供访问法律文档和隐私政策的途径。

### 场景：显示隐私政策

- **前置条件**：设置面板已显示
- **操作**：用户选择"隐私政策"选项
- **预期结果**：系统应打开隐私政策文档

### 场景：显示服务条款

- **前置条件**：设置面板已显示
- **操作**：用户选择"服务条款"选项
- **预期结果**：系统应打开服务条款文档

---

## 需求：将设置组织到部分


系统应将相关设置分组到逻辑部分。

### 场景：显示部分标题

- **前置条件**：设置面板已显示
- **操作**：渲染面板
- **预期结果**：系统应将设置分组到部分标题下：外观、同步、数据、关于、法律

---

## 设计细节

### Functional Scope
### 功能范围


设置面板提供以下功能区域：

- **通知设置**：同步通知开关
- **外观设置**：深色模式开关
- **数据管理**：导出/导入 Loro 格式数据
- **关于应用**：版本、技术栈、GitHub 链接、贡献者、更新日志

### Platform Differences
### 平台差异


设置面板适应不同平台，具有不同的交互模式：

- **移动端**：全屏页面，通过底部导航栏进入
- **桌面端**：弹出对话框，快捷键 Ctrl/Cmd+,

### Data Operations
### 数据操作


具有特定格式和大小约束的数据管理功能：

- **导出**：Loro 二进制格式（.loro）
- **导入**：合并到现有数据，不覆盖
- **文件大小限制**：100MB

### Interaction Design
### 交互设计


具有特定时间和动画要求的交互模式：

- **开关**：即时生效，200ms 动画
- **主题切换**：300ms 平滑过渡
- **Export/Import**: Confirmation dialog + progress indication
- **导出/导入**：确认对话框 + 进度提示

### Key Decisions
### 关键决策


安全性和用户体验的重要设计决策：

- **Removed "Clear Data" feature** (security considerations)
- **移除"清空数据"功能**（安全性考虑）
- **Loro format only** (for completeness and consistency)
- **仅支持 Loro 格式**（完整性和一致性）
- **Import uses merge mode** (to avoid overwriting existing data)
- **导入采用合并模式**（避免覆盖现有数据）
- **Changelog shows only recent 3 versions**
- **更新日志只显示最近 3 个版本**

---

## 测试覆盖

**测试文件**: `test/unit/settings_panel_test.dart`, `test/widgets/settings_panel_test.dart`

**单元测试** (8):
- Theme switching logic
- 主题切换逻辑
- Data export/import validation
- 数据导出/导入验证
- Settings state management
- 设置状态管理
- File size validation
- 文件大小验证
- Configuration persistence
- 配置持久化
- Error handling for invalid operations
- 无效操作的错误处理
- Platform-specific behavior detection
- 平台特定行为检测
- Notification preference management
- 通知偏好管理
- Change log version filtering
- 更新日志版本过滤

- `it_should_show_current_theme_mode()` - Display theme mode
- `it_should_show_current_theme_mode()` - 显示主题模式
- `it_should_toggle_theme()` - Toggle theme
- `it_should_toggle_theme()` - 切换主题
- `it_should_show_auto_sync_preference()` - Auto-sync preference
- `it_should_show_auto_sync_preference()` - 自动同步偏好
- `it_should_show_sync_frequency_options()` - Sync frequency
- `it_should_show_sync_frequency_options()` - 同步频率
- `it_should_show_app_version()` - App version
- `it_should_show_app_version()` - 应用版本
- `it_should_show_app_name_description()` - App name & description
- `it_should_show_app_name_description()` - 应用名称和描述
- `it_should_navigate_to_device_manager()` - Navigate to devices
- `it_should_navigate_to_device_manager()` - 导航到设备
- `it_should_clear_local_cache()` - Clear cache
- `it_should_clear_local_cache()` - 清除缓存
- `it_should_export_data()` - Export data
- `it_should_export_data()` - 导出数据
- `it_should_show_privacy_policy()` - Privacy policy
- `it_should_show_privacy_policy()` - 隐私政策
- `it_should_show_terms_of_service()` - Terms of service
- `it_should_show_terms_of_service()` - 服务条款
- `it_should_group_settings_by_sections()` - Section grouping
- `it_should_group_settings_by_sections()` - 部分分组

**验收标准**:
- [ ] All widget tests pass
- [ ] 所有 Widget 测试通过
- [ ] Theme switching works correctly
- [ ] 主题切换正常工作
- [ ] Sync settings are functional
- [ ] 同步设置功能正常
- [ ] Data management actions work reliably
- [ ] 数据管理操作可靠工作
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## 相关文档

**相关规格**:
- [device_config.md](../../../architecture/storage/device_config.md) - Device configuration
- [device_config.md](../../../architecture/storage/device_config.md) - 设备配置
- [sync/protocol.md](../../../architecture/sync/service.md) - Sync protocol
- [sync/protocol.md](../../../architecture/sync/service.md) - 同步协议
- [settings_screen.md](../../screens/mobile/settings_screen.md) - Settings screen
- [settings_screen.md](../../screens/mobile/settings_screen.md) - 设置屏幕
- [device_manager_panel.md](device_manager_panel.md) - Device manager
- [device_manager_panel.md](device_manager_panel.md) - 设备管理器

---

**最后更新**: 2026-01-27

**作者**: CardMind Team
