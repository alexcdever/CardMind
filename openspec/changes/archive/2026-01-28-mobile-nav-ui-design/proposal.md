## Why

移动端应用需要底部导航栏来提供清晰、直观的导航体验。当前缺少符合移动端设计规范的导航组件，影响用户在笔记、设备和设置页面间的切换效率。

## What Changes

- 新增 MobileNav 底部导航栏组件，支持 3 个主要标签页（Notes、Devices、Settings）
- 实现标签切换动画和视觉反馈
- 添加徽章通知功能，显示笔记和设备的数量
- 支持浅色/深色主题适配
- 遵循移动端平台特定设计规范（非响应式）

## Capabilities

### New Capabilities
- `mobile-nav-ui`: 移动端底部导航栏 UI 组件，包含标签切换、徽章通知、动画反馈等完整功能

### Modified Capabilities
- 无现有功能需求变更，此为全新 UI 组件

## Impact

- **Flutter UI 层**: 新增 `lib/widgets/mobile_nav/` 目录及相关组件
- **状态管理**: 需要集成导航状态管理（Provider/Riverpod）
- **主题系统**: 需要适配浅色/深色主题
- **测试覆盖**: 需要添加 5 个单元测试和 41 个 Widget 测试
- **依赖关系**: 无新增外部依赖，使用 Flutter 内置组件