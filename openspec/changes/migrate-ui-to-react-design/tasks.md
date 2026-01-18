# Implementation Tasks

## 1. 准备工作

- [x] 1.1 添加 `fluttertoast` 依赖到 `pubspec.yaml`
- [x] 1.2 扩展 `lib/theme/app_theme.dart`，添加新的颜色定义（卡片阴影、毛玻璃效果等）
- [x] 1.3 创建 Toast 通知工具类 `lib/utils/toast_utils.dart`

## 2. 自适应系统扩展

- [x] 2.1 扩展 `lib/adaptive/adaptive_builder.dart`，添加 1024px 断点常量
- [x] 2.2 创建 `lib/adaptive/layouts/three_column_layout.dart`（桌面端三栏布局）
- [x] 2.3 创建 `lib/adaptive/widgets/adaptive_fab.dart`（自适应浮动操作按钮）

## 3. 基础组件实现 - NoteCard

- [x] 3.1 创建 `lib/widgets/note_card.dart`
- [x] 3.2 实现笔记信息显示（标题、内容预览、标签、元数据）
- [x] 3.3 实现桌面端内联编辑模式（编辑/保存/取消按钮）
- [x] 3.4 实现标签管理（添加/删除标签）
- [x] 3.5 实现删除笔记功能（下拉菜单）
- [x] 3.6 添加视觉反馈（悬停效果、点击动画、协作标识）
- [x] 3.7 实现响应式布局（移动端单栏、桌面端网格）
- [x] 3.8 编写 Widget 测试 `test/widgets/note_card_test.dart`

## 4. 基础组件实现 - MobileNav

- [x] 4.1 创建 `lib/widgets/mobile_nav.dart`
- [x] 4.2 实现底部导航栏布局（三个标签：笔记、设备、设置）
- [x] 4.3 实现标签切换功能
- [x] 4.4 实现徽章指示器（显示笔记数量、设备数量）
- [x] 4.5 实现激活标签高亮效果（顶部指示条）
- [x] 4.6 添加图标和文字
- [x] 4.7 编写 Widget 测试 `test/widgets/mobile_nav_test.dart`

## 5. 基础组件实现 - FullscreenEditor

- [x] 5.1 创建 `lib/widgets/fullscreen_editor.dart`
- [x] 5.2 实现全屏编辑器布局（顶部导航栏 + 内容区域）
- [x] 5.3 实现标题和内容输入框
- [x] 5.4 实现标签管理（添加/删除标签）
- [x] 5.5 实现保存和取消按钮
- [x] 5.6 实现自动保存草稿功能（2 秒延迟）
- [x] 5.7 实现键盘优化（自动聚焦、键盘避让）
- [x] 5.8 添加进入/退出动画
- [x] 5.9 编写 Widget 测试 `test/widgets/fullscreen_editor_test.dart`

## 6. 基础组件实现 - DeviceManagerPanel

- [x] 6.1 创建 `lib/widgets/device_manager_panel.dart`
- [x] 6.2 实现当前设备信息显示（名称、类型、状态）
- [x] 6.3 实现设备重命名功能（编辑模式）
- [x] 6.4 实现已配对设备列表显示
- [x] 6.5 实现添加设备对话框（扫码配对 + 局域网发现）
- [x] 6.6 实现移除设备功能
- [x] 6.7 实现设备状态指示（在线/离线图标）
- [x] 6.8 实现设备类型图标（手机/笔记本/平板）
- [x] 6.9 编写 Widget 测试 `test/widgets/device_manager_panel_test.dart`

## 7. 基础组件实现 - SettingsPanel

- [x] 7.1 创建 `lib/widgets/settings_panel.dart`
- [x] 7.2 实现设置面板布局（卡片式设计）
- [x] 7.3 添加主题切换选项（亮色/暗色模式）
- [x] 7.4 添加同步设置选项
- [x] 7.5 添加关于信息
- [x] 7.6 编写 Widget 测试 `test/widgets/settings_panel_test.dart`

## 8. 基础组件实现 - SyncStatusIndicator 增强

- [x] 8.1 打开 `lib/widgets/sync_status_indicator.dart`
- [x] 8.2 增强视觉效果（添加颜色、动画）
- [x] 8.3 实现相对时间显示（刚刚、X 分钟前、X 小时前）
- [x] 8.4 实现同步设备数量显示
- [x] 8.5 实现响应式显示（桌面端显示文字，移动端仅显示图标）
- [x] 8.6 更新 Widget 测试 `test/widgets/sync_status_indicator_test.dart`

## 9. 主屏幕重构 - 桌面端布局

- [x] 9.1 打开 `lib/screens/home_screen.dart`
- [x] 9.2 实现顶部导航栏（应用标题 + 同步状态 + 新建按钮）
- [x] 9.3 实现三栏布局（使用 `ThreeColumnLayout`）
- [x] 9.4 左侧栏：集成 `DeviceManagerPanel` 和 `SettingsPanel`
- [x] 9.5 右侧栏：实现搜索栏 + 笔记网格
- [x] 9.6 实现笔记网格布局（1-2 列，使用 `GridView.builder`）
- [x] 9.7 实现空状态显示
- [x] 9.8 集成 `NoteCard` 组件

## 10. 主屏幕重构 - 移动端布局

- [x] 10.1 在 `lib/screens/home_screen.dart` 中实现移动端布局
- [x] 10.2 实现 `IndexedStack` 管理三个标签页
- [x] 10.3 笔记标签页：搜索栏 + 笔记列表
- [x] 10.4 设备标签页：集成 `DeviceManagerPanel`
- [x] 10.5 设置标签页：集成 `SettingsPanel`
- [x] 10.6 集成 `MobileNav` 底部导航栏
- [x] 10.7 实现浮动操作按钮（FAB）
- [x] 10.8 实现点击卡片打开全屏编辑器

## 11. 主屏幕重构 - 通用功能

- [x] 11.1 实现搜索功能（标题、内容、标签）
- [x] 11.2 实现创建新笔记功能（桌面端和移动端）
- [x] 11.3 集成 Toast 通知（创建、保存、删除、同步）
- [x] 11.4 实现自适应切换逻辑（使用 `AdaptiveBuilder`）
- [x] 11.5 保持现有的 `CardProvider` 集成
- [x] 11.6 保持现有的同步状态 Stream 订阅

## 12. 清理旧代码

- [x] 12.1 删除 `lib/screens/card_editor_screen.dart`（已被全屏编辑器和内联编辑替代）
- [x] 12.2 删除 `lib/screens/sync_screen.dart`（已集成到主屏幕）
- [x] 12.3 删除 `lib/widgets/card_list_item.dart`（已被 `NoteCard` 替代）
- [x] 12.4 更新 `lib/main.dart` 中的路由配置

## 13. 测试

- [x] 13.1 运行所有 Widget 测试 `flutter test`
- [ ] 13.2 手动测试移动端布局（使用模拟器或调整窗口大小）
- [ ] 13.3 手动测试桌面端布局
- [ ] 13.4 测试响应式切换（跨越 1024px 断点）
- [ ] 13.5 测试笔记创建、编辑、删除流程
- [ ] 13.6 测试搜索功能
- [ ] 13.7 测试设备管理功能
- [ ] 13.8 测试同步状态显示
- [ ] 13.9 测试 Toast 通知

## 14. 性能优化

- [x] 14.1 使用 `const` 构造函数优化 Widget 重建
- [x] 14.2 优化笔记列表渲染（确保使用 `ListView.builder` 或 `GridView.builder`）
- [x] 14.3 使用 Flutter DevTools 分析性能
- [x] 14.4 优化不必要的 `setState` 调用
- [x] 14.5 添加图片懒加载（如果有图片）

## 15. 文档和收尾

- [x] 15.1 更新 `README.md` 中的 UI 说明
- [x] 15.2 添加代码注释（特别是复杂的自适应逻辑）
- [x] 15.3 更新 `CHANGELOG.md`
- [x] 15.4 运行 `dart tool/validate_constraints.dart` 验证约束
- [x] 15.5 运行 `dart tool/fix_lint.dart` 修复 lint 问题
- [x] 15.6 确保所有文件使用 Unix 换行符（LF）
