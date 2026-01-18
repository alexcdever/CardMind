## Why

当前 Flutter UI 实现较为基础，缺乏现代化的设计语言和响应式布局。React 参考代码提供了一套完整的移动端和桌面端自适应 UI 设计，包含更好的视觉层次、交互反馈和用户体验。迁移到这套设计可以显著提升应用的专业度和可用性。

## What Changes

- **移动端 UI 重构**
  - 实现底部导航栏（笔记、设备、设置三个标签页）
  - 添加全屏笔记编辑器（移动端专用）
  - 实现浮动操作按钮（FAB）用于快速创建笔记
  - 优化移动端卡片列表布局

- **桌面端 UI 重构**
  - 实现三栏布局：设备管理（左侧）+ 笔记列表（右侧两栏）
  - 添加顶部固定导航栏，包含同步状态和快速操作
  - 实现响应式网格布局（笔记卡片）
  - 优化桌面端交互体验

- **通用组件升级**
  - 重新设计笔记卡片组件（NoteCard）
  - 实现同步状态指示器（SyncStatus）
  - 创建设备管理面板（DeviceManager）
  - 添加设置面板（SettingsPanel）
  - 实现搜索栏组件

- **视觉设计改进**
  - 采用现代化的卡片设计语言
  - 添加毛玻璃效果（backdrop blur）
  - 优化颜色系统和间距
  - 改进图标和排版

- **交互体验优化**
  - 添加 Toast 通知反馈
  - 优化加载状态和空状态展示
  - 改进移动端触摸交互
  - 增强桌面端鼠标悬停效果

## Capabilities

### New Capabilities
- `adaptive-ui-system`: 平台自适应 UI 系统，根据设备类型（移动端/桌面端）自动切换布局和交互模式
- `note-card-component`: 现代化笔记卡片组件，支持内联编辑、标签管理、设备信息显示
- `mobile-navigation`: 移动端底部导航系统，包含标签页切换和状态指示
- `fullscreen-editor`: 移动端全屏笔记编辑器，提供沉浸式编辑体验
- `device-manager-ui`: 设备管理界面，支持设备配对、重命名、状态监控
- `sync-status-indicator`: 同步状态可视化组件，实时显示同步进度和状态
- `toast-notification`: Toast 通知系统，提供用户操作反馈

### Modified Capabilities
- `home-screen`: 主屏幕布局从单一列表改为自适应多栏布局，支持移动端和桌面端不同的展示方式
- `card-editor`: 卡片编辑器从独立页面改为移动端全屏模式 + 桌面端内联编辑模式

## Impact

**受影响的代码**:
- `lib/screens/home_screen.dart` - 需要完全重构以支持自适应布局
- `lib/screens/card_editor_screen.dart` - 需要适配新的编辑模式
- `lib/widgets/card_list_item.dart` - 需要重新设计为现代化卡片组件
- `lib/widgets/sync_status_indicator.dart` - 需要增强视觉效果
- `lib/adaptive/` - 需要扩展自适应系统以支持新的布局模式

**新增文件**:
- `lib/widgets/mobile_nav.dart` - 移动端底部导航
- `lib/widgets/note_card.dart` - 新的笔记卡片组件
- `lib/widgets/device_manager_panel.dart` - 设备管理面板
- `lib/widgets/settings_panel.dart` - 设置面板
- `lib/widgets/fullscreen_editor.dart` - 全屏编辑器
- `lib/widgets/toast_notification.dart` - Toast 通知组件
- `lib/adaptive/layouts/three_column_layout.dart` - 三栏布局

**依赖变更**:
- 可能需要添加 `fluttertoast` 或类似的 Toast 库
- 可能需要添加更多的 Material Design 3 组件

**API 影响**:
- 不影响 Rust 后端 API
- 仅涉及 Flutter UI 层的重构

**数据层影响**:
- 不影响数据模型和存储逻辑
- 保持现有的 Loro CRDT + SQLite 双层架构

**测试影响**:
- 需要更新所有 UI 相关的 widget 测试
- 需要添加新组件的测试用例
- 需要测试移动端和桌面端的自适应行为
