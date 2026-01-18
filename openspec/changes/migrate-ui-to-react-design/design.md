## Context

当前 CardMind 的 Flutter UI 实现基于传统的单页面导航模式，主要包含：
- `HomeScreen`: 简单的卡片列表视图
- `CardEditorScreen`: 独立的编辑页面
- `SettingsScreen`: 设置页面
- `SyncScreen`: 同步管理页面

现有的自适应系统（`lib/adaptive/`）已经实现了基础的平台检测和响应式布局，但缺乏针对移动端和桌面端的差异化 UI 设计。

React 参考代码提供了一套完整的现代化 UI 设计，包含：
- 移动端：底部导航 + 全屏编辑器 + FAB
- 桌面端：三栏布局 + 内联编辑 + 固定顶栏
- 8 个自定义组件（NoteCard, MobileNav, DeviceManager, SettingsPanel, SyncStatus, FullscreenEditor, QRCodeMock, ImageWithFallback）
- 基于 shadcn/ui 的组件库（20+ UI 组件）

**约束条件**:
- 必须保持现有的 Rust 后端 API 不变
- 必须遵循 Loro CRDT + SQLite 双层架构
- 必须使用现有的 `CardProvider` 状态管理
- 必须兼容现有的 `flutter_rust_bridge` 集成
- 必须遵循 Project Guardian 约束（无 `unwrap()`, 无 `panic!()`, 使用 `debugPrint()`）

**利益相关者**:
- 用户：期望更好的移动端和桌面端体验
- 开发者：需要可维护的组件化架构
- 产品：需要现代化的视觉设计

## Goals / Non-Goals

**Goals:**
- 实现移动端和桌面端的差异化 UI 布局
- 创建可复用的现代化组件库
- 提升用户交互体验和视觉设计
- 保持代码的可维护性和可测试性
- 完全迁移到新的 UI 设计，替换所有旧的 UI 代码

**Non-Goals:**
- 不修改 Rust 后端 API
- 不改变数据模型和存储逻辑
- 不实现 React 代码中的 localStorage 和 BroadcastChannel（已有 Loro 同步）
- 不实现 QR 码扫描功能（React 代码中是 mock）
- 不添加新的业务功能（仅 UI 重构）

## Decisions

### 1. 组件架构：分层组件系统

**决策**: 采用三层组件架构
- **Screens 层**: 页面级组件，负责布局和状态管理
- **Widgets 层**: 可复用的业务组件（NoteCard, DeviceManagerPanel 等）
- **Adaptive 层**: 平台自适应组件和布局

**理由**:
- 清晰的职责分离，便于维护
- 组件可复用性高
- 符合 Flutter 最佳实践

**替代方案**:
- ❌ 单层扁平结构：难以管理复杂的组件关系
- ❌ 过度抽象的多层结构：增加复杂度，降低可读性

### 2. 自适应策略：响应式断点 + 平台检测

**决策**: 使用 `LayoutBuilder` + `PlatformDetector` 实现自适应
- 移动端断点: `< 1024px`
- 桌面端断点: `>= 1024px`
- 使用 `AdaptiveBuilder` 统一管理自适应逻辑

**理由**:
- 与 React 代码的 `lg:` 断点（1024px）保持一致
- 现有的 `PlatformDetector` 已经实现了平台检测
- `LayoutBuilder` 是 Flutter 标准的响应式方案

**替代方案**:
- ❌ 仅使用平台检测：无法处理桌面端的小窗口场景
- ❌ 使用 `MediaQuery` 全局断点：不够灵活，难以局部调整

### 3. 导航模式：移动端标签页 vs 桌面端单页

**决策**:
- 移动端：使用 `IndexedStack` + 底部导航栏，保持三个标签页的状态
- 桌面端：单页布局，所有内容在一个页面中展示

**理由**:
- 移动端标签页符合用户习惯（类似微信、支付宝）
- 桌面端单页布局充分利用屏幕空间
- `IndexedStack` 可以保持标签页状态，避免重复加载

**替代方案**:
- ❌ 移动端也使用单页：内容过多，滚动体验差
- ❌ 桌面端也使用标签页：浪费屏幕空间

### 4. 编辑模式：移动端全屏 vs 桌面端内联

**决策**:
- 移动端：点击卡片打开全屏编辑器（新的 `FullscreenEditorWidget`）
- 桌面端：卡片内联编辑（在 `NoteCard` 组件内切换编辑状态）

**理由**:
- 移动端全屏编辑提供更好的输入体验
- 桌面端内联编辑减少页面跳转，提高效率
- 与 React 参考代码的交互模式一致

**替代方案**:
- ❌ 统一使用全屏编辑：桌面端体验差
- ❌ 统一使用内联编辑：移动端输入困难

### 5. Toast 通知：使用 `fluttertoast` 包

**决策**: 添加 `fluttertoast` 依赖，实现 Toast 通知

**理由**:
- `fluttertoast` 是成熟的跨平台 Toast 库
- API 简单，易于集成
- 支持自定义样式

**替代方案**:
- ❌ 使用 `SnackBar`：需要 `ScaffoldMessenger`，在某些场景下不方便
- ❌ 自己实现 Toast：重复造轮子，增加维护成本

### 6. 状态管理：继续使用 Provider

**决策**: 保持现有的 `CardProvider`，不引入新的状态管理方案

**理由**:
- 现有的 `Provider` 已经满足需求
- 避免大规模重构
- 团队熟悉 `Provider`

**替代方案**:
- ❌ 迁移到 Riverpod：学习成本高，收益不明显
- ❌ 使用 Bloc：过度设计，增加复杂度

### 7. 组件映射策略

**决策**: 将 React 组件一对一映射到 Flutter Widget

| React 组件 | Flutter Widget | 位置 |
|-----------|---------------|------|
| `App.tsx` | `HomeScreen` | `lib/screens/home_screen.dart` |
| `NoteCard` | `NoteCard` | `lib/widgets/note_card.dart` |
| `MobileNav` | `MobileNav` | `lib/widgets/mobile_nav.dart` |
| `DeviceManager` | `DeviceManagerPanel` | `lib/widgets/device_manager_panel.dart` |
| `SettingsPanel` | `SettingsPanel` | `lib/widgets/settings_panel.dart` |
| `SyncStatus` | `SyncStatusIndicator` (增强) | `lib/widgets/sync_status_indicator.dart` |
| `NoteEditorFullscreen` | `FullscreenEditorWidget` | `lib/widgets/fullscreen_editor.dart` |

**理由**:
- 清晰的映射关系，便于对照实现
- 保持组件的职责一致性
- 便于后续维护和更新

### 8. 样式系统：扩展现有的 Theme

**决策**: 在现有的 `lib/theme/` 基础上扩展，添加新的颜色和样式定义

**理由**:
- 保持主题系统的一致性
- 避免重复定义
- 便于全局样式调整

**替代方案**:
- ❌ 创建新的样式系统：造成样式碎片化
- ❌ 硬编码样式：难以维护和调整

## Risks / Trade-offs

### 风险 1: 大规模 UI 重构可能引入 Bug
**缓解措施**:
- 分阶段实施：先实现组件，再集成到页面
- 每个组件都编写 Widget 测试
- 保留旧代码，通过 feature flag 切换（可选）

### 风险 2: 移动端和桌面端代码分支过多
**缓解措施**:
- 使用 `AdaptiveBuilder` 统一管理自适应逻辑
- 提取公共组件，减少重复代码
- 编写清晰的注释和文档

### 风险 3: 性能问题（复杂布局可能影响性能）
**缓解措施**:
- 使用 `const` 构造函数优化 Widget 重建
- 合理使用 `ListView.builder` 和 `GridView.builder`
- 避免不必要的 `setState` 调用
- 使用 Flutter DevTools 进行性能分析

### 风险 4: 与现有代码的集成问题
**缓解措施**:
- 保持 `CardProvider` 接口不变
- 不修改 Rust 后端 API
- 渐进式迁移，先实现新组件，再替换旧组件

### Trade-off 1: 代码量增加 vs 用户体验提升
- **取舍**: 接受代码量增加（约 2000+ 行新代码）
- **理由**: 用户体验的提升值得这个成本

### Trade-off 2: 移动端和桌面端代码分离 vs 代码复用
- **取舍**: 优先考虑用户体验，接受一定的代码重复
- **理由**: 移动端和桌面端的交互模式差异较大，强行复用会降低代码可读性

### Trade-off 3: 完全重写 vs 渐进式重构
- **取舍**: 采用完全重写的方式
- **理由**: 旧 UI 代码较少，完全重写更清晰，避免技术债务

## Migration Plan

### 阶段 1: 准备工作（1 个任务）
1. 添加依赖：`fluttertoast` 到 `pubspec.yaml`
2. 扩展 Theme 系统：添加新的颜色和样式定义

### 阶段 2: 基础组件实现（7 个任务）
1. 实现 `NoteCard` 组件（支持内联编辑、标签管理）
2. 实现 `MobileNav` 组件（底部导航栏）
3. 实现 `DeviceManagerPanel` 组件
4. 实现 `SettingsPanel` 组件
5. 增强 `SyncStatusIndicator` 组件
6. 实现 `FullscreenEditorWidget` 组件
7. 创建 Toast 通知工具类

### 阶段 3: 布局系统（2 个任务）
1. 创建 `ThreeColumnLayout` 组件（桌面端布局）
2. 扩展 `AdaptiveBuilder` 支持新的布局模式

### 阶段 4: 页面重构（1 个任务）
1. 重构 `HomeScreen`：
   - 移动端：`IndexedStack` + `MobileNav` + FAB
   - 桌面端：`ThreeColumnLayout` + 固定顶栏

### 阶段 5: 测试和优化（3 个任务）
1. 编写 Widget 测试（所有新组件）
2. 集成测试（移动端和桌面端流程）
3. 性能优化和 Bug 修复

### 阶段 6: 清理和文档（2 个任务）
1. 删除旧的 UI 代码（`CardEditorScreen`, `SyncScreen` 等）
2. 更新文档和注释

### Rollback 策略
- 如果发现严重问题，可以通过 Git 回滚到旧版本
- 建议在 feature branch 上开发，测试通过后再合并到 main

## Open Questions

1. **是否需要实现 QR 码扫描功能？**
   - React 代码中是 mock，实际功能未实现
   - 建议：暂不实现，留待后续迭代

2. **是否需要保留旧的 `CardEditorScreen` 和 `SyncScreen`？**
   - 建议：删除，新 UI 已经包含这些功能

3. **是否需要添加动画效果？**
   - React 代码中有一些 CSS 过渡动画
   - 建议：先实现基础功能，动画效果可以后续优化

4. **是否需要支持暗色模式？**
   - React 代码使用了 shadcn/ui 的主题系统，支持暗色模式
   - 建议：Flutter 已有 Theme 系统，可以直接支持，但需要测试

5. **移动端 FAB 的位置是否需要调整？**
   - React 代码中 FAB 位于右下角，距离底部导航栏 80px
   - 建议：保持一致，但需要测试实际效果
