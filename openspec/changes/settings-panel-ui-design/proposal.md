## Why

CardMind 需要一个完整的设置面板来管理应用的核心配置，包括通知、外观、数据管理和应用信息。当前缺少统一的设置界面，用户无法方便地配置应用行为和查看应用详情。

## What Changes

- 创建平台特定的设置界面（移动端全屏页面，桌面端对话框）
- 实现同步通知开关，支持即时生效
- 添加深色模式切换，提供平滑主题过渡
- 实现数据导入导出功能，支持 Loro 格式文件
- 显示应用信息页面，包含版本、技术栈、贡献者和更新日志
- 提供安全的确认对话框和数据操作流程

## Capabilities

### New Capabilities
- `settings-panel`: 应用设置面板，包含通知管理、主题切换、数据导入导出和应用信息展示

### Modified Capabilities
- 无现有功能需求变更，这是纯新增功能

## Impact

- **UI Components**: 新增 SettingsPanelMobile、SettingsPanelDesktop、SettingSection、SettingItem 等组件
- **Data Models**: 添加 AppInfo、ChangelogEntry 等数据模型
- **File Operations**: 实现 Loro 格式文件的导入导出功能
- **State Management**: 需要设置状态持久化和主题管理
- **Platform Specific**: 区分移动端和桌面端的交互模式
- **Integration**: 需要 Rust 端的 Loro 文件操作接口
- **Testing**: 需要完整的单元测试和 Widget 测试覆盖（53 个测试用例）
- **Dependencies**: 依赖现有的设置持久化、文件操作和主题系统