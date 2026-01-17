## Why

当前 `docs/interaction/feedback_design.md` 中包含了同步状态反馈的描述，但这些描述混合了视觉设计和可执行的交互规格，导致：
1. 同步状态的状态机逻辑没有明确定义
2. 无法通过自动化测试验证状态转换
3. 缺少明确的前置条件、后置条件和测试用例
4. 视觉设计（图标、颜色）和交互行为（状态转换）混在一起

本 change 将同步反馈的交互行为从设计文档中提取出来，创建可执行的交互规格，遵循 Spec Coding 方法论。

## What Changes

- **新增** `openspec/specs/flutter/sync_feedback_spec.md` - 同步反馈交互规格
- **修改** `docs/interaction/feedback_design.md` - 移除交互规格内容，仅保留视觉设计描述，添加到新规格的引用
- **新增** Flutter widget 测试 - 验证同步状态反馈行为
- **更新** `openspec/specs/README.md` - 添加新规格索引

## Capabilities

### New Capabilities
- `sync-feedback-interaction`: 定义同步状态反馈的完整交互规格，包括：
  - 同步状态机（disconnected → syncing → synced → failed）
  - 状态指示器显示逻辑（图标、文字、颜色）
  - 状态转换触发条件
  - 用户交互（点击查看详情、重试）
  - 实时状态更新（通过 Stream）
  - 错误处理和用户反馈

### Modified Capabilities
- `home-screen-interaction` (SP-FLUT-008): 需要添加同步状态指示器的集成点：
  - AppBar 显示同步状态
  - 状态变化时更新 UI
  - 点击状态图标查看详情

## Impact

**受影响的文件**:
- `docs/interaction/feedback_design.md` - 内容重构，分离设计与规格
- `openspec/specs/flutter/` - 新增规格文档
- `openspec/specs/README.md` - 更新索引
- `test/specs/` - 新增测试文件

**受影响的组件**:
- `HomeScreen` widget - AppBar 同步状态指示器
- `SyncStatusIndicator` widget - 同步状态显示组件（待实现）
- `HomeScreenState` - 状态管理（订阅同步状态）

**依赖关系**:
- 依赖 Rust API: `SyncApi.statusStream`, `SyncApi.getSyncStatus()`
- 依赖现有规格: SP-FLUT-008 (主页交互规格)
- 依赖后端规格: SP-SYNC-006 (同步层规格)

**不影响**:
- 视觉设计（图标、颜色等仍在 `docs/design/` 中定义）
- 后端同步逻辑（Rust 代码）
- 其他反馈类型（操作反馈、进度反馈等将在后续 change 中处理）
