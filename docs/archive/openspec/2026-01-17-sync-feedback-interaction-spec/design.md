## Context

### 背景
CardMind 的同步状态反馈当前缺少明确的交互规格。`docs/interaction/feedback_design.md` 混合了视觉设计（图标、颜色）和交互行为（状态转换），导致职责不清。本 change 专注于将同步反馈的交互行为提取出来，创建符合 Spec Coding 方法论的可执行规格。

### 当前状态
- **现有文档**: `docs/interaction/feedback_design.md` 包含同步状态的简单描述
- **现有规格**: `SP-FLUT-008` (主页交互规格) 已定义主页基本交互，但同步状态指示器未详细定义
- **现有 API**: Rust 后端已提供 `SyncApi.statusStream` 和 `SyncApi.getSyncStatus()`
- **现有组件**: `HomeScreen` 已实现，但缺少同步状态指示器

### 约束
- 必须遵循 Spec Coding 方法论（规格 → 测试 → 代码）
- 必须使用 `it_should_xxx()` 测试命名风格
- 必须通过 Flutter widget 测试验证所有状态转换
- 视觉设计（图标、颜色等）保留在 `docs/design/` 中
- 状态更新必须实时（通过 Stream）

### 利益相关者
- **用户**: 需要清晰、实时的同步状态反馈
- **开发者**: 需要明确的状态机定义和可执行测试
- **AI Agent**: 需要明确的规格来指导实现

---

## Goals / Non-Goals

### Goals
1. **定义同步状态机**: 明确所有状态（disconnected, syncing, synced, failed）及其转换条件
2. **创建可执行的交互规格**: 定义每个状态的显示逻辑、用户交互、状态转换
3. **编写 widget 测试**: 验证所有状态转换和 UI 更新
4. **分离设计与规格**: 将交互行为从设计文档中分离
5. **集成现有规格**: 与 SP-FLUT-008 (主页交互规格) 和 SP-SYNC-006 (同步层规格) 集成

### Non-Goals
1. **不实现视觉设计**: 图标、颜色等视觉元素仍在 `docs/design/` 中定义
2. **不修改后端同步逻辑**: Rust 同步层已存在，本 change 只关注 Flutter 层
3. **不处理其他反馈类型**: 操作反馈、进度反馈等将在后续 change 中处理
4. **不实现同步详情页**: 点击查看详情的页面不在本 change 范围

---

## Decisions

### Decision 1: 状态机设计
**选择**: 4 状态状态机（disconnected → syncing → synced / failed）

**理由**:
- 覆盖所有同步场景
- 状态转换清晰、可预测
- 符合用户心智模型

**状态定义**:
```
disconnected: 未连接到任何对等设备
syncing: 正在同步数据
synced: 同步完成，数据一致
failed: 同步失败（网络错误、冲突等）
```

**替代方案**:
- 3 状态（合并 syncing 和 synced）: 用户无法区分是否正在同步
- 5+ 状态（细分失败原因）: 过度复杂，用户不关心细节

### Decision 2: 状态更新机制
**选择**: Stream-based 实时更新

**理由**:
- Rust API 已提供 `SyncApi.statusStream`
- 实时更新，用户体验好
- Flutter StreamBuilder 原生支持

**替代方案**:
- 轮询（polling）: 延迟高，资源浪费
- 手动刷新: 用户体验差

### Decision 3: 错误处理策略
**选择**: 显示错误状态 + 点击查看详情

**理由**:
- 不打断用户流程（不使用 Dialog）
- 提供足够信息（点击查看详情）
- 符合 Material Design 指南

**替代方案**:
- Dialog: 过于侵入，打断用户
- 忽略错误: 用户不知道同步失败

### Decision 4: 状态指示器位置
**选择**: AppBar 右侧

**理由**:
- 始终可见，不占用主要内容区
- 符合常见应用设计模式（如 Dropbox、Google Drive）
- 与 SP-FLUT-008 一致

**替代方案**:
- 底部 SnackBar: 不持久，容易被忽略
- 独立状态栏: 占用空间，视觉干扰

### Decision 5: 动画策略
**选择**: 同步中显示旋转动画，其他状态静态图标

**理由**:
- 旋转动画清晰表达"正在进行"
- 静态图标减少视觉干扰
- 性能友好

**替代方案**:
- 所有状态都有动画: 过度干扰，消耗资源
- 无动画: 用户无法区分同步中和已同步

---

## Risks / Trade-offs

### Risk 1: Stream 订阅可能导致内存泄漏
**风险**: 如果 StreamBuilder 未正确 dispose，可能导致内存泄漏

**缓解措施**:
- 使用 StreamBuilder（自动管理订阅）
- 在 widget dispose 时确保取消订阅
- 添加内存泄漏检测测试

### Risk 2: 状态更新频率过高可能影响性能
**风险**: 如果同步状态频繁变化，可能导致 UI 频繁重建

**缓解措施**:
- 在 Rust 层做 debounce（避免频繁发送状态）
- 使用 `distinct()` 过滤重复状态
- 添加性能监控

### Risk 3: 网络不稳定时状态可能频繁切换
**风险**: disconnected ↔ syncing 频繁切换，用户体验差

**缓解措施**:
- 添加状态稳定时间（如 2 秒内不切换）
- 显示"连接不稳定"中间状态
- 提供手动重试选项

### Risk 4: 与 SP-FLUT-008 的集成点不清晰
**风险**: 主页规格可能需要修改，导致冲突

**缓解措施**:
- 在 proposal 中明确标注 Modified Capabilities
- 创建 delta spec 文件（如需要）
- 与主页规格保持松耦合

---

## Migration Plan

### 实施步骤

#### Phase 1: 创建规格文档
1. 创建 `openspec/specs/flutter/sync_feedback_spec.md`
2. 定义状态机和所有状态转换
3. 编写测试用例（使用 `it_should_xxx()` 命名）

#### Phase 2: 编写测试
1. 创建 `test/specs/sync_feedback_spec_test.dart`
2. 实现状态机测试（状态转换）
3. 实现 UI 测试（图标、文字、颜色）
4. 实现 Stream 测试（实时更新）

#### Phase 3: 实现代码
1. 创建 `SyncStatusIndicator` widget
2. 实现状态机逻辑
3. 集成 `SyncApi.statusStream`
4. 实现 UI 渲染（图标、文字、动画）

#### Phase 4: 集成主页
1. 在 `HomeScreen` AppBar 添加 `SyncStatusIndicator`
2. 实现点击查看详情（导航到详情页，后续 change）
3. 更新 SP-FLUT-008 规格（如需要）

#### Phase 5: 文档更新
1. 更新 `docs/interaction/feedback_design.md`（移除交互规格，添加引用）
2. 更新 `openspec/specs/README.md`（添加新规格索引）
3. 更新 `docs/design/` 中的相关引用

### 回滚策略
- 如果测试失败，不合并代码
- 如果发现性能问题，回退到静态状态显示
- 保留旧的 `feedback_design.md` 版本，以便回滚

### 验证标准
- [ ] 所有测试通过（`flutter test test/specs/sync_feedback_spec_test.dart`）
- [ ] 状态转换正确（通过集成测试验证）
- [ ] 代码审查通过（遵循 Project Guardian 约束）
- [ ] 文档更新完成（规格、索引、交叉引用）

---

## Open Questions

### Q1: 是否需要支持手动触发同步？
**状态**: 待决定

**选项**:
- A: 仅自动同步，不支持手动触发（简单）
- B: 支持下拉刷新或按钮触发同步（复杂）

**建议**: 先实现 A，在后续 change 中添加 B

### Q2: 同步失败时是否需要显示详细错误信息？
**状态**: 待决定

**选项**:
- A: 仅显示"同步失败"，点击查看详情（简单）
- B: 直接在指示器显示错误原因（复杂，可能过长）

**建议**: 先实现 A

### Q3: 是否需要支持同步历史记录？
**状态**: 待决定

**选项**:
- A: 不支持历史记录（简单）
- B: 支持查看最近 N 次同步记录（复杂）

**建议**: 先实现 A，在后续 change 中添加 B

### Q4: 是否需要修改 SP-FLUT-008 规格？
**状态**: 待确认

**影响**: 如果 SP-FLUT-008 需要修改，需要创建 delta spec

**建议**: 先查看 SP-FLUT-008 的当前状态，确定是否需要修改
