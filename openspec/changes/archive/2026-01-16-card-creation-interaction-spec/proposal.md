## Why

当前 `docs/interaction/ui_flows.md` 中包含了卡片创建的交互流程描述，但这些描述混合了视觉设计和可执行的交互规格，导致：
1. 无法通过自动化测试验证交互行为
2. 设计文档和交互规格职责不清晰
3. 缺少明确的前置条件、后置条件和测试用例

本 change 将卡片创建的交互行为从设计文档中提取出来，创建可执行的交互规格，遵循 Spec Coding 方法论。

## What Changes

- **新增** `openspec/specs/flutter/card_creation_spec.md` - 卡片创建交互规格
- **修改** `docs/interaction/ui_flows.md` - 移除交互规格内容，仅保留用户流程描述，添加到新规格的引用
- **新增** Flutter widget 测试 - 验证卡片创建交互行为
- **更新** `openspec/specs/README.md` - 添加新规格索引

## Capabilities

### New Capabilities
- `card-creation-interaction`: 定义卡片创建的完整交互规格，包括：
  - 点击 FAB 按钮触发创建流程
  - 卡片编辑器的输入交互（标题、内容）
  - 自动保存机制（输入后 500ms 自动保存）
  - 保存成功后的导航和列表更新
  - 错误处理和用户反馈
  - 性能约束（30 秒内完成创建）

### Modified Capabilities
- `home-screen-interaction` (SP-FLUT-008): 需要添加与卡片创建流程的集成点：
  - FAB 按钮的点击事件处理
  - 创建完成后返回主页并刷新列表
  - 创建失败时的错误提示

## Impact

**受影响的文件**:
- `docs/interaction/ui_flows.md` - 内容重构，分离设计与规格
- `openspec/specs/flutter/` - 新增规格文档
- `openspec/specs/README.md` - 更新索引
- `test/specs/` - 新增测试文件

**受影响的组件**:
- `HomeScreen` widget - FAB 按钮交互
- `CardEditorScreen` widget - 卡片编辑器（待实现）
- `HomeScreenState` - 状态管理

**依赖关系**:
- 依赖 Rust API: `CardApi.createCard()`
- 依赖现有规格: SP-FLUT-008 (主页交互规格)
- 依赖后端规格: SP-CARD-004 (CardStore 规格)

**不影响**:
- 视觉设计（颜色、字体、布局等仍在 `docs/design/` 中定义）
- 后端 Rust 代码（API 已存在）
- 其他 UI 流程（编辑、删除、搜索等将在后续 change 中处理）
