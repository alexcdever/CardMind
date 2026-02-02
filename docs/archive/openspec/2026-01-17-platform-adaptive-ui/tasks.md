## 1. 基础设施搭建

- [x] 1.1 创建 `lib/adaptive/` 目录结构
- [x] 1.2 实现 `PlatformDetector` 类（platform_detector.dart）
- [x] 1.3 实现 `PlatformType` 枚举（mobile/desktop）
- [x] 1.4 为 `PlatformDetector` 编写单元测试
- [x] 1.5 实现 `AdaptiveWidget` 抽象基类（adaptive_widget.dart）
- [x] 1.6 实现 `AdaptiveBuilder` 组件（adaptive_builder.dart）
- [x] 1.7 为 `AdaptiveWidget` 和 `AdaptiveBuilder` 编写单元测试
- [x] 1.8 创建 `lib/adaptive/widgets/` 目录

## 2. 自适应导航系统

- [x] 2.1 创建 `lib/adaptive/navigation/` 目录
- [x] 2.2 实现 `AdaptiveNavigation` 组件（adaptive_navigation.dart）
- [x] 2.3 实现移动端导航（mobile_navigation.dart）使用 BottomNavigationBar
- [x] 2.4 实现桌面端导航（desktop_navigation.dart）使用 NavigationRail
- [x] 2.5 为导航组件编写 Widget 测试
- [x] 2.6 验证导航状态在移动端和桌面端正确同步

## 3. 自适应布局系统

- [x] 3.1 创建 `lib/adaptive/layouts/` 目录
- [x] 3.2 实现 `AdaptiveScaffold` 组件（adaptive_scaffold.dart）
- [x] 3.3 实现移动端布局（mobile_layout.dart）- 单列布局
- [x] 3.4 实现桌面端布局（desktop_layout.dart）- 分栏布局
- [x] 3.5 为布局组件编写 Widget 测试
- [x] 3.6 实现自适应间距工具（adaptive_spacing.dart）
- [x] 3.7 实现自适应内边距工具（adaptive_padding.dart）

## 4. 主页改造

- [x] 4.1 重构 `home_screen.dart` 使用 `AdaptiveScaffold`
- [x] 4.2 实现移动端主页布局（单列列表 + FAB）
- [x] 4.3 实现桌面端主页布局（分栏：列表 + 详情）
- [x] 4.4 移动端：保留 FloatingActionButton
- [x] 4.5 桌面端：在工具栏添加"新建卡片"按钮
- [x] 4.6 为主页编写 Widget 测试（移动端和桌面端）
- [x] 4.7 验证主页在两个平台上正常工作

## 5. 卡片编辑器改造

- [x] 5.1 重构 `card_editor_screen.dart` 使用自适应布局
- [x] 5.2 实现移动端编辑器（全屏模式）
- [x] 5.3 实现桌面端编辑器（右侧面板模式）
- [x] 5.4 移动端：添加返回按钮和保存按钮到 AppBar
- [x] 5.5 桌面端：编辑器在右侧面板显示，列表保持可见
- [x] 5.6 为编辑器编写 Widget 测试（移动端和桌面端）
- [x] 5.7 验证编辑器在两个平台上正常工作

## 6. 设置页面改造

- [x] 6.1 重构 `settings_screen.dart` 使用自适应布局
- [x] 6.2 实现移动端设置布局（单列列表）
- [x] 6.3 实现桌面端设置布局（可选：两列布局）
- [x] 6.4 为设置页面编写 Widget 测试
- [x] 6.5 验证设置页面在两个平台上正常工作

## 7. 键盘快捷键系统

- [x] 7.1 创建 `lib/adaptive/keyboard_shortcuts.dart`
- [x] 7.2 定义 Intent 类（CreateCardIntent, SaveCardIntent, CloseEditorIntent 等）
- [x] 7.3 实现 `KeyboardShortcuts` 组件使用 Flutter Shortcuts API
- [x] 7.4 实现快捷键：Ctrl/Cmd+N（新建卡片）
- [x] 7.5 实现快捷键：Ctrl/Cmd+S（保存卡片）
- [x] 7.6 实现快捷键：Esc（关闭编辑器）
- [x] 7.7 实现快捷键：Ctrl/Cmd+F（搜索）
- [x] 7.8 实现快捷键：Ctrl/Cmd+,（设置）
- [x] 7.9 实现快捷键：Delete（删除卡片）
- [x] 7.10 实现快捷键：Ctrl/Cmd+A（全选）
- [x] 7.11 实现快捷键：Ctrl/Cmd+Z（撤销）
- [x] 7.12 实现快捷键：Ctrl/Cmd+Shift+Z（重做）
- [x] 7.13 确保快捷键仅在桌面端启用
- [x] 7.14 确保快捷键不干扰文本输入
- [x] 7.15 为键盘快捷键编写测试
- [x] 7.16 在桌面端验证所有快捷键正常工作

## 8. 移动端触摸优化

- [x] 8.1 实现 `TouchTarget` 组件（touch_target.dart）
- [x] 8.2 确保所有可点击元素最小尺寸为 44x44 逻辑像素
- [x] 8.3 重构 `card_list_item.dart` 使用 `TouchTarget`
- [x] 8.4 重构按钮组件使用 `TouchTarget`
- [x] 8.5 实现下拉刷新功能（pull to refresh）
- [x] 8.6 实现滑动删除功能（swipe to delete）
- [x] 8.7 实现长按显示上下文菜单
- [x] 8.8 为触摸交互编写测试
- [x] 8.9 在移动端验证所有触摸交互正常工作

## 9. 桌面端鼠标优化

- [x] 9.1 为所有交互元素添加悬停效果
- [x] 9.2 实现右键菜单系统
- [x] 9.3 为卡片列表项添加右键菜单（编辑、删除、复制等）
- [x] 9.4 实现拖拽排序功能（drag to reorder）
- [x] 9.5 实现拖拽删除功能（drag to delete）
- [x] 9.6 为所有按钮添加工具提示（tooltips）
- [x] 9.7 在工具提示中显示键盘快捷键
- [x] 9.8 为鼠标交互编写测试
- [x] 9.9 在桌面端验证所有鼠标交互正常工作

## 10. 自适应组件库

- [x] 10.1 实现 `AdaptiveButton` 组件（adaptive_button.dart）
- [x] 10.2 实现 `AdaptiveListItem` 组件（adaptive_list_item.dart）
- [x] 10.3 实现 `AdaptiveDialog` 组件（adaptive_dialog.dart）
- [x] 10.4 实现 `AdaptiveTextField` 组件（adaptive_text_field.dart）
- [x] 10.5 为自适应组件编写 Widget 测试
- [x] 10.6 创建组件示例和文档

## 11. 响应式布局

- [x] 11.1 实现窗口大小检测
- [x] 11.2 桌面端：支持窗口调整大小
- [x] 11.3 桌面端：设置最小窗口尺寸（800x600）
- [x] 11.4 桌面端：窗口宽度小于 1024px 时折叠分栏布局
- [x] 11.5 移动端：处理屏幕旋转
- [x] 11.6 移动端：处理键盘弹出和收起
- [x] 11.7 为响应式布局编写测试

## 12. 排版优化

- [x] 12.1 定义移动端字体大小（body: 16px, heading: 20px+）
- [x] 12.2 定义桌面端字体大小（body: 14-16px, heading: 18px+）
- [x] 12.3 实现自适应排版系统
- [x] 12.4 更新所有文本组件使用自适应字体大小
- [x] 12.5 验证排版在两个平台上的可读性

## 13. 测试

- [x] 13.1 编写平台检测的单元测试
- [x] 13.2 编写自适应框架的单元测试
- [x] 13.3 编写导航系统的 Widget 测试
- [x] 13.4 编写主页的 Widget 测试（移动端和桌面端）
- [x] 13.5 编写编辑器的 Widget 测试（移动端和桌面端）
- [x] 13.6 编写键盘快捷键的测试
- [x] 13.7 编写触摸交互的测试
- [x] 13.8 编写鼠标交互的测试
- [x] 13.9 在 Android 上运行集成测试
- [x] 13.10 在 iOS 上运行集成测试
- [x] 13.11 在 macOS 上运行集成测试
- [x] 13.12 在 Windows 上运行集成测试
- [x] 13.13 在 Linux 上运行集成测试
- [x] 13.14 修复所有测试失败

## 14. 性能优化

- [x] 14.1 验证平台检测的性能开销（应为零）
- [x] 14.2 优化自适应组件的构建性能
- [x] 14.3 确保 Tree Shaking 移除未使用的平台代码
- [x] 14.4 在 Release 模式下测试性能
- [x] 14.5 修复任何性能问题

## 15. 文档和示例

- [x] 15.1 编写平台自适应系统的使用文档
- [x] 15.2 创建自适应组件的代码示例
- [x] 15.3 编写迁移指南（如何将现有组件迁移到自适应架构）
- [x] 15.4 更新 CLAUDE.md 添加平台自适应相关说明
- [x] 15.5 创建键盘快捷键参考文档
- [x] 15.6 更新用户手册

## 16. 代码质量

- [x] 16.1 运行 `dart analyze` 修复所有警告
- [x] 16.2 运行 `dart format` 格式化所有代码
- [x] 16.3 运行 `dart tool/fix_lint.dart` 修复 lint 问题
- [x] 16.4 运行 `dart tool/validate_constraints.dart` 验证约束
- [x] 16.5 确保所有文件使用 Unix 换行符（LF）
- [x] 16.6 代码审查和重构

## 17. 最终验证

- [x] 17.1 在所有平台上进行完整的手动测试
- [x] 17.2 验证移动端触摸交互体验
- [x] 17.3 验证桌面端键鼠交互体验
- [x] 17.4 验证导航在所有平台上正常工作
- [x] 17.5 验证编辑器在所有平台上正常工作
- [x] 17.6 验证所有键盘快捷键在桌面端正常工作
- [x] 17.7 验证所有测试通过
- [x] 17.8 验证性能符合预期
- [x] 17.9 验证文档完整准确
- [x] 17.10 准备提交 PR
