# Flutter UI 组件实现计划

**日期**: 2026-01-26
**作者**: Claude Sonnet 4.5
**状态**: 待审核

---

## 执行摘要

本计划旨在实现 CardMind 项目中已完成设计的 8 个 Flutter UI 组件。这些组件的设计文档和测试规格已经完成，但实现代码与规格存在差距，导致 96 个测试失败。

**目标**: 修复所有失败的测试，确保实现与 OpenSpec 规格完全一致。

**预期成果**:
- 所有 Flutter Widget 测试通过（0 失败）
- 代码符合 OpenSpec 规格要求
- 遵循 Project Guardian 约束
- 通过 `dart tool/validate_constraints.dart` 验证

---

## 背景

### 当前状态

**已完成的设计**（8 个组件）:
1. ✅ sync-status-indicator（桌面端同步状态指示器）
2. ✅ note-card（笔记卡片）
3. ✅ mobile-nav（移动端底部导航栏）
4. ✅ note-editor-fullscreen（移动端全屏笔记编辑器）
5. ✅ device-manager（移动端设备管理页面）
6. ✅ device-manager（桌面端设备管理页面）
7. ✅ settings-panel（设置面板）
8. ✅ sync-details-dialog（同步详情对话框）

**现有代码**:
- `lib/widgets/` 目录下已有 8 个 Widget 文件
- `test/widgets/` 目录下已有对应的测试文件
- 测试结果: 568 通过, 96 失败

**问题**:
- 实现代码与 OpenSpec 规格不完全一致
- 部分测试用例失败
- 需要修复实现以符合规格要求

---

## 实施策略

### 方法论

采用 **Spec Coding** 方法:
1. **规格优先**: 以 OpenSpec 规格为唯一真实来源
2. **测试驱动**: 修复失败的测试，确保实现符合规格
3. **增量修复**: 逐个组件修复，每个组件完成后验证
4. **约束验证**: 每次修改后运行 Project Guardian 验证

### 优先级排序

按照依赖关系和复杂度排序:

**第一批（基础组件）**:
1. sync-status-indicator - 基础状态显示组件
2. note-card - 核心笔记卡片组件

**第二批（导航和编辑）**:
3. mobile-nav - 移动端导航
4. note-editor-fullscreen - 全屏编辑器

**第三批（设备管理）**:
5. device-manager（移动端）
6. device-manager（桌面端）

**第四批（设置和详情）**:
7. settings-panel - 设置面板
8. sync-details-dialog - 同步详情对话框

---

## 详细任务分解

### 阶段 1: 环境准备和分析（1 个任务）

#### 任务 1.1: 分析测试失败原因
**目标**: 理解所有 96 个失败测试的根本原因

**步骤**:
1. 运行 `flutter test --no-pub` 并保存完整输出
2. 分析每个失败测试的错误信息
3. 按组件分类失败原因
4. 识别共性问题（如缺失依赖、API 不匹配等）
5. 创建问题清单和修复优先级

**输出**:
- `docs/plans/2026-01-26-test-failure-analysis.md` - 失败分析报告
- 按组件分类的问题清单

**验收标准**:
- 所有 96 个失败测试都有明确的失败原因
- 问题清单按优先级排序
- 识别出可批量修复的共性问题

---

### 阶段 2: 基础组件修复（2 个任务）

#### 任务 2.1: 修复 sync-status-indicator
**目标**: 使 SyncStatusIndicator 组件通过所有测试

**规格文档**:
- `openspec/specs/features/sync_feedback/desktop.md`
- `openspec/specs/features/sync_feedback/shared.md`

**测试文件**:
- `test/widgets/sync_status_indicator_test.dart`
- `test/specs/sync_status_indicator_component_spec_test.dart`

**步骤**:
1. 阅读规格文档，理解完整需求
2. 运行该组件的测试: `flutter test test/widgets/sync_status_indicator_test.dart`
3. 逐个修复失败的测试用例
4. 确保状态机正确实现（disconnected/syncing/synced/failed）
5. 验证动画效果（syncing 状态的旋转动画）
6. 验证点击行为（显示详情对话框）
7. 验证无障碍支持（Semantics）

**关键实现点**:
- 状态枚举: `SyncState.disconnected/syncing/synced/failed`
- 图标映射: `cloud_off/sync/cloud_done/cloud_off`
- 颜色映射: 灰色/主题色/绿色/橙色
- 旋转动画: 2 秒一圈，仅在 syncing 状态
- 相对时间格式: 刚刚/X秒前/X分钟前/X小时前/X天前

**验收标准**:
- 所有 SyncStatusIndicator 测试通过
- 代码符合 OpenSpec 规格
- 通过 `dart tool/validate_constraints.dart` 验证
- 无 lint 警告

---

#### 任务 2.2: 修复 note-card
**目标**: 使 NoteCard 组件通过所有测试

**规格文档**:
- `openspec/specs/features/card_list/note_card.md`
- `openspec/specs/features/card_editor/note_card.md`

**测试文件**:
- `test/widgets/note_card_test.dart`

**步骤**:
1. 阅读规格文档，理解完整需求
2. 运行该组件的测试: `flutter test test/widgets/note_card_test.dart`
3. 逐个修复失败的测试用例
4. 确保平台差异正确实现（桌面端内联编辑 vs 移动端全屏编辑）
5. 验证标签管理功能
6. 验证协作编辑标识
7. 验证日期格式化

**关键实现点**:
- 平台检测: 使用 `PlatformDetector.isMobile`
- 桌面端: 内联编辑模式，PopupMenu 操作
- 移动端: 点击打开全屏编辑器
- 标签管理: 添加、删除标签
- 协作标识: 显示最后编辑设备
- 日期格式: 刚刚/X分钟前/X小时前/完整日期

**验收标准**:
- 所有 NoteCard 测试通过
- 桌面端和移动端行为正确区分
- 代码符合 OpenSpec 规格
- 通过约束验证
- 无 lint 警告

---

### 阶段 3: 导航和编辑组件修复（2 个任务）

#### 任务 3.1: 修复 mobile-nav
**目标**: 使 MobileNav 组件通过所有测试

**规格文档**:
- `openspec/specs/features/navigation/mobile_nav.md`

**测试文件**:
- `test/widgets/mobile_nav_test.dart`

**步骤**:
1. 阅读规格文档
2. 运行测试: `flutter test test/widgets/mobile_nav_test.dart`
3. 修复失败的测试用例
4. 验证三个标签页（笔记/设备/设置）
5. 验证图标和标签
6. 验证笔记数量徽章
7. 验证标签切换回调

**关键实现点**:
- 三个标签: notes/devices/settings
- 图标: note/devices/settings
- 笔记数量徽章: 显示在 notes 标签上
- 标签切换: 调用 `onTabChange` 回调
- 仅移动端显示

**验收标准**:
- 所有 MobileNav 测试通过
- 标签切换正常工作
- 徽章显示正确
- 代码符合规格
- 通过约束验证

---

#### 任务 3.2: 修复 note-editor-fullscreen
**目标**: 使 FullscreenEditor 组件通过所有测试

**规格文档**:
- `openspec/specs/features/card_list/note_editor_fullscreen.md`
- `openspec/specs/features/card_editor/fullscreen_editor.md`

**测试文件**:
- `test/widgets/fullscreen_editor_test.dart`

**步骤**:
1. 阅读规格文档
2. 运行测试: `flutter test test/widgets/fullscreen_editor_test.dart`
3. 修复失败的测试用例
4. 验证全屏布局
5. 验证标题和内容编辑
6. 验证保存和取消按钮
7. 验证返回导航

**关键实现点**:
- 全屏布局: 占据整个屏幕
- AppBar: 标题 + 保存/取消按钮
- 标题输入: TextField
- 内容输入: TextField（多行）
- 保存: 调用 `onSave` 回调
- 取消: 调用 `onCancel` 回调或返回
- 仅移动端使用

**验收标准**:
- 所有 FullscreenEditor 测试通过
- 编辑功能正常工作
- 保存和取消正确触发
- 代码符合规格
- 通过约束验证

---

### 阶段 4: 设备管理组件修复（2 个任务）

#### 任务 4.1: 修复 device-manager（移动端）
**目标**: 使移动端 DeviceManagerPanel 组件通过所有测试

**规格文档**:
- `docs/plans/2026-01-26-device-manager-mobile-ui-design.md`
- `openspec/specs/features/settings/device_manager_panel.md`

**测试文件**:
- `test/widgets/device_manager_panel_test.dart`（移动端测试）

**步骤**:
1. 阅读设计文档和规格
2. 运行测试并筛选移动端相关测试
3. 修复失败的测试用例
4. 实现设备列表显示
5. 实现当前设备编辑
6. 实现二维码配对（显示/扫描）
7. 实现验证码输入对话框

**关键实现点**:
- 设备列表: 在线优先 + 最后在线时间倒序
- 设备类型图标: phone/laptop/tablet
- 在线状态徽章: 绿色"在线"/灰色"离线"
- 当前设备: 主题色 10% 背景 + "本机"标识
- 二维码配对: 两个标签（显示/扫描）
- 验证码: 6 位数字，独立输入框，自动跳转
- 时间格式: 刚刚/X分钟前/X小时前/X天前/完整日期

**验收标准**:
- 移动端 DeviceManagerPanel 测试通过
- 设备列表正确显示和排序
- 二维码配对流程完整
- 验证码输入正常工作
- 代码符合规格
- 通过约束验证

---

#### 任务 4.2: 修复 device-manager（桌面端）
**目标**: 使桌面端 DeviceManagerPanel 组件通过所有测试

**规格文档**:
- `docs/plans/2026-01-26-device-manager-desktop-ui-design.md`
- `openspec/specs/features/settings/device_manager_panel.md`

**测试文件**:
- `test/widgets/device_manager_panel_test.dart`（桌面端测试）

**步骤**:
1. 阅读设计文档和规格
2. 运行测试并筛选桌面端相关测试
3. 修复失败的测试用例
4. 实现 Card 卡片布局
5. 实现当前设备内联编辑
6. 实现二维码配对（显示/上传）
7. 实现拖拽上传功能

**关键实现点**:
- Card 布局: 最大宽度 800px
- 当前设备: 内联编辑名称
- 二维码配对: 两个标签（显示/上传）
- 上传区域: 400x240px，支持拖拽
- 验证码: 6 个独立输入框（56x64px）
- 桌面端交互: 悬停效果、键盘快捷键
- 使用 libp2p PeerId 作为设备 ID

**验收标准**:
- 桌面端 DeviceManagerPanel 测试通过
- Card 布局正确
- 内联编辑正常工作
- 上传和拖拽功能完整
- 代码符合规格
- 通过约束验证

---

### 阶段 5: 设置和详情组件修复（2 个任务）

#### 任务 5.1: 修复 settings-panel
**目标**: 使 SettingsPanel 组件通过所有测试

**规格文档**:
- `docs/plans/2026-01-26-settings-panel-ui-design.md`
- `openspec/specs/features/settings/settings_panel.md`

**测试文件**:
- `test/widgets/settings_panel_test.dart`

**步骤**:
1. 阅读设计文档和规格
2. 运行测试: `flutter test test/widgets/settings_panel_test.dart`
3. 修复失败的测试用例
4. 实现通知设置
5. 实现外观设置（深色模式）
6. 实现数据管理（导出/导入）
7. 实现关于应用信息

**关键实现点**:
- 通知设置: 同步通知开关
- 外观设置: 深色模式开关，300ms 过渡
- 数据管理: 导出/导入 Loro 格式，100MB 限制
- 关于应用: 版本、技术栈、GitHub、贡献者、更新日志（最近 3 个版本）
- 平台差异: 移动端全屏页面 vs 桌面端对话框
- 开关: 即时生效，200ms 动画

**验收标准**:
- 所有 SettingsPanel 测试通过
- 开关功能正常工作
- 导出/导入流程完整
- 平台差异正确实现
- 代码符合规格
- 通过约束验证

---

#### 任务 5.2: 修复 sync-details-dialog
**目标**: 使 SyncDetailsDialog 组件通过所有测试

**规格文档**:
- `docs/plans/2026-01-26-sync-details-dialog-ui-design.md`
- `openspec/specs/features/sync_feedback/sync_details_dialog.md`

**测试文件**:
- `test/widgets/sync_details_dialog_test.dart`（如果存在）

**步骤**:
1. 阅读设计文档和规格
2. 检查是否有测试文件，如果没有则创建
3. 修复或实现测试用例
4. 实现同步状态显示
5. 实现设备列表显示
6. 实现同步统计信息
7. 实现同步历史记录

**关键实现点**:
- 对话框尺寸: 600px 宽，最大 80vh 高
- 同步状态: 未同步/同步中/已同步/失败
- 设备列表: 显示所有设备及在线状态
- 同步统计: 总卡片数、数据大小、同步间隔
- 同步历史: 最近 20 条记录
- 实时更新: 通过 Stream 订阅
- 状态颜色: 灰色/蓝色+旋转/绿色/红色
- 仅桌面端使用

**验收标准**:
- 所有 SyncDetailsDialog 测试通过
- 实时更新正常工作
- 历史记录正确显示
- 对话框布局正确
- 代码符合规格
- 通过约束验证

---

### 阶段 6: 集成测试和验证（3 个任务）

#### 任务 6.1: 运行完整测试套件
**目标**: 确保所有测试通过

**步骤**:
1. 运行完整测试: `flutter test --no-pub`
2. 验证测试结果: 0 失败
3. 如有失败，分析原因并修复
4. 重复直到所有测试通过

**验收标准**:
- `flutter test` 输出: "All tests passed!"
- 0 个失败测试
- 所有 Widget 测试通过
- 所有 Spec 测试通过

---

#### 任务 6.2: 运行约束验证
**目标**: 确保代码符合 Project Guardian 约束

**步骤**:
1. 运行快速验证: `dart tool/validate_constraints.dart`
2. 运行完整验证: `dart tool/validate_constraints.dart --full`
3. 修复任何约束违规
4. 重复直到验证通过

**验收标准**:
- 快速验证通过
- 完整验证通过
- 无约束违规
- 无 lint 警告

---

#### 任务 6.3: 代码审查和文档更新
**目标**: 确保代码质量和文档同步

**步骤**:
1. 审查所有修改的代码
2. 确保代码注释清晰
3. 更新 `docs/plans/2026-01-26-ui-design-progress.md`
4. 标记所有组件为"已实现"
5. 创建实施总结报告

**输出**:
- `docs/plans/2026-01-26-ui-implementation-summary.md` - 实施总结

**验收标准**:
- 所有代码有适当的注释
- 进度文档已更新
- 实施总结报告完成
- 代码符合团队规范

---

## 风险和缓解措施

### 风险 1: 规格文档不完整或不清晰
**影响**: 中等
**概率**: 低
**缓解措施**:
- 在实施前仔细阅读所有规格文档
- 如发现规格不清晰，先澄清再实施
- 参考设计文档和测试用例理解需求

### 风险 2: 测试用例与规格不一致
**影响**: 中等
**概率**: 中等
**缓解措施**:
- 以 OpenSpec 规格为唯一真实来源
- 如测试与规格冲突，优先修改测试
- 记录所有测试修改的原因

### 风险 3: 平台差异导致实现复杂
**影响**: 高
**概率**: 中等
**缓解措施**:
- 使用 `PlatformDetector` 统一平台检测
- 为桌面端和移动端创建独立的实现分支
- 充分测试两个平台的行为

### 风险 4: 依赖缺失或版本不兼容
**影响**: 高
**概率**: 低
**缓解措施**:
- 在开始前检查所有依赖
- 使用 `pubspec.yaml` 中指定的版本
- 如需新依赖，先评估影响

### 风险 5: 约束验证失败
**影响**: 中等
**概率**: 低
**缓解措施**:
- 每个任务完成后立即运行约束验证
- 熟悉 Project Guardian 约束规则
- 遵循最佳实践和反模式指南

---

## 成功标准

### 必须满足（Must Have）
1. ✅ 所有 Flutter 测试通过（0 失败）
2. ✅ 代码符合 OpenSpec 规格
3. ✅ 通过 Project Guardian 约束验证
4. ✅ 无 lint 警告或错误
5. ✅ 所有 8 个组件功能完整

### 应该满足（Should Have）
1. ✅ 代码注释清晰完整
2. ✅ 平台差异正确实现
3. ✅ 动画和交互流畅
4. ✅ 无障碍支持完整
5. ✅ 文档同步更新

### 可以满足（Could Have）
1. ⭕ 性能优化（如有必要）
2. ⭕ 额外的边界测试
3. ⭕ 代码重构（如有重复）

---

## 依赖和前置条件

### 前置条件
1. ✅ Flutter 3.x 已安装
2. ✅ Dart 3.x 已安装
3. ✅ 所有依赖已安装（`flutter pub get`）
4. ✅ OpenSpec 规格文档已完成
5. ✅ 测试文件已创建

### 外部依赖
1. `provider` - 状态管理
2. `flutter_rust_bridge` - Rust 桥接
3. `flutter_markdown` - Markdown 渲染
4. `rxdart` - Stream 工具
5. `shared_preferences` - 主题持久化
6. `package_info_plus` - 版本信息
7. `fluttertoast` - Toast 通知

---

## 时间线和里程碑

### 里程碑 1: 环境准备完成
- 任务 1.1 完成
- 失败分析报告完成
- 问题清单创建

### 里程碑 2: 基础组件完成
- 任务 2.1 和 2.2 完成
- sync-status-indicator 和 note-card 测试通过

### 里程碑 3: 导航和编辑组件完成
- 任务 3.1 和 3.2 完成
- mobile-nav 和 note-editor-fullscreen 测试通过

### 里程碑 4: 设备管理组件完成
- 任务 4.1 和 4.2 完成
- 移动端和桌面端 device-manager 测试通过

### 里程碑 5: 设置和详情组件完成
- 任务 5.1 和 5.2 完成
- settings-panel 和 sync-details-dialog 测试通过

### 里程碑 6: 项目完成
- 所有测试通过
- 约束验证通过
- 文档更新完成
- 实施总结报告完成

---

## 附录

### A. 相关文档

**OpenSpec 规格**:
- `openspec/specs/features/sync_feedback/desktop.md`
- `openspec/specs/features/sync_feedback/shared.md`
- `openspec/specs/features/sync_feedback/sync_details_dialog.md`
- `openspec/specs/features/card_list/note_card.md`
- `openspec/specs/features/card_editor/note_card.md`
- `openspec/specs/features/navigation/mobile_nav.md`
- `openspec/specs/features/card_list/note_editor_fullscreen.md`
- `openspec/specs/features/card_editor/fullscreen_editor.md`
- `openspec/specs/features/settings/device_manager_panel.md`
- `openspec/specs/features/settings/settings_panel.md`

**设计文档**:
- `docs/plans/2026-01-25-sync-status-ui-design.md`
- `docs/plans/2026-01-25-note-card-ui-design.md`
- `docs/plans/2026-01-25-mobile-nav-ui-design.md`
- `docs/plans/2026-01-25-note-editor-fullscreen-ui-design.md`
- `docs/plans/2026-01-26-device-manager-mobile-ui-design.md`
- `docs/plans/2026-01-26-device-manager-desktop-ui-design.md`
- `docs/plans/2026-01-26-settings-panel-ui-design.md`
- `docs/plans/2026-01-26-sync-details-dialog-ui-design.md`

**进度跟踪**:
- `docs/plans/2026-01-26-ui-design-progress.md`

**约束文档**:
- `project-guardian.toml`
- `.project-guardian/best-practices.md`
- `.project-guardian/anti-patterns.md`

### B. 测试命令

```bash
# 运行所有测试
flutter test --no-pub

# 运行特定组件测试
flutter test test/widgets/sync_status_indicator_test.dart
flutter test test/widgets/note_card_test.dart
flutter test test/widgets/mobile_nav_test.dart
flutter test test/widgets/fullscreen_editor_test.dart
flutter test test/widgets/device_manager_panel_test.dart
flutter test test/widgets/settings_panel_test.dart

# 运行约束验证
dart tool/validate_constraints.dart
dart tool/validate_constraints.dart --full

# 代码格式化
dart format .

# 静态分析
flutter analyze
```

### C. 关键约束提醒

1. **文件格式**: 所有文本文件必须使用 Unix 换行符（LF）
2. **错误处理**: 禁止 `unwrap()` / `expect()` / `panic!()`
3. **日志**: Dart 中禁止 `print()`，使用 `debugPrint()`
4. **API 设计**: 所有 API 返回 `Result<T, Error>`
5. **测试命名**: 使用 `it_should_xxx()` 格式
6. **双层架构**: 写操作 → Loro，读操作 → SQLite

---

**最后更新**: 2026-01-26
**计划版本**: 1.0
**审核状态**: 待审核
