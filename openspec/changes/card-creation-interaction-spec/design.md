## Context

### 背景
CardMind 当前的文档结构混合了视觉设计和交互规格，导致职责不清。本 change 专注于将卡片创建的交互行为从 `docs/interaction/ui_flows.md` 中提取出来，创建符合 Spec Coding 方法论的可执行规格。

### 当前状态
- **现有文档**: `docs/interaction/ui_flows.md` 包含卡片创建流程的描述
- **现有规格**: `SP-FLUT-008` (主页交互规格) 已定义主页的基本交互
- **现有 API**: Rust 后端已提供 `CardApi.createCard()` 接口
- **现有组件**: `HomeScreen` 已实现，但缺少 FAB 按钮和创建流程

### 约束
- 必须遵循 Spec Coding 方法论（规格 → 测试 → 代码）
- 必须使用 `it_should_xxx()` 测试命名风格
- 必须通过 Flutter widget 测试验证所有交互行为
- 视觉设计（颜色、布局等）保留在 `docs/design/` 中
- 性能约束：30 秒内完成卡片创建流程

### 利益相关者
- **用户**: 需要快速、流畅的卡片创建体验
- **开发者**: 需要清晰的交互规格和可执行测试
- **AI Agent**: 需要明确的规格来指导实现

---

## Goals / Non-Goals

### Goals
1. **创建可执行的交互规格**: 定义卡片创建的所有交互行为，包括前置条件、操作步骤、后置条件
2. **编写 widget 测试**: 验证所有交互行为（FAB 点击、输入、保存、导航等）
3. **分离设计与规格**: 将交互行为从设计文档中分离，建立清晰的文档边界
4. **集成现有规格**: 与 SP-FLUT-008 (主页交互规格) 和 SP-CARD-004 (CardStore 规格) 集成

### Non-Goals
1. **不实现视觉设计**: 颜色、字体、布局等视觉元素仍在 `docs/design/` 中定义
2. **不修改后端 API**: Rust API 已存在，本 change 只关注 Flutter 层
3. **不处理其他 UI 流程**: 卡片编辑、删除、搜索等将在后续 change 中处理
4. **不实现高级功能**: Markdown 编辑器、图片上传等高级功能不在本 change 范围

---

## Decisions

### Decision 1: 使用 Navigator 2.0 还是 1.0？
**选择**: Navigator 1.0 (命名路由)

**理由**:
- 项目当前使用 Navigator 1.0，保持一致性
- 卡片创建流程简单，不需要 Navigator 2.0 的复杂性
- 降低学习曲线和实现复杂度

**替代方案**:
- Navigator 2.0: 更强大，但对于简单流程过度设计

### Decision 2: 自动保存机制
**选择**: 输入后 500ms debounce 自动保存

**理由**:
- 符合现代笔记应用的用户期望（如 Notion、Obsidian）
- 避免用户忘记保存导致数据丢失
- 500ms 是平衡响应性和性能的最佳值

**替代方案**:
- 手动保存按钮: 用户体验差，容易忘记保存
- 实时保存（每次输入）: 性能开销大，可能导致卡顿

### Decision 3: 状态管理方案
**选择**: Provider + ChangeNotifier

**理由**:
- 项目已使用 Provider（见 SP-FLUT-008）
- 简单、轻量，适合中小型应用
- Flutter 官方推荐

**替代方案**:
- Riverpod: 更现代，但需要迁移现有代码
- Bloc: 过度设计，增加复杂度

### Decision 4: 表单验证策略
**选择**: 实时验证 + 保存时最终验证

**理由**:
- 实时验证提供即时反馈（如标题不能为空）
- 保存时最终验证确保数据完整性
- 平衡用户体验和数据安全

**替代方案**:
- 仅保存时验证: 用户体验差，错误反馈延迟
- 仅实时验证: 可能遗漏边界情况

### Decision 5: 错误处理策略
**选择**: SnackBar + 错误状态保留

**理由**:
- SnackBar 是 Material Design 标准的错误提示方式
- 错误状态保留允许用户重试，避免数据丢失
- 符合用户期望

**替代方案**:
- Dialog: 过于侵入，打断用户流程
- Toast: 可能被忽略，不够明显

---

## Risks / Trade-offs

### Risk 1: 自动保存可能导致意外保存
**风险**: 用户可能在输入过程中意外触发保存，保存了不完整的内容

**缓解措施**:
- 使用 500ms debounce，避免频繁保存
- 提供"撤销"功能（后续 change）
- 在 UI 上明确显示"自动保存中..."状态

### Risk 2: 网络/API 失败导致保存失败
**风险**: Rust API 调用失败时，用户输入的内容可能丢失

**缓解措施**:
- 在本地缓存用户输入（使用 SharedPreferences）
- 显示明确的错误提示和重试按钮
- 保留编辑器状态，允许用户继续编辑

### Risk 3: 性能约束（30 秒）可能无法满足
**风险**: 在低端设备或网络不佳时，可能超过 30 秒

**缓解措施**:
- 优化 API 调用（使用 Rust 本地 API，不依赖网络）
- 添加性能监控和日志
- 如果超时，提供明确的错误提示

### Risk 4: 与现有规格的集成点不清晰
**风险**: SP-FLUT-008 (主页交互规格) 可能需要修改，导致冲突

**缓解措施**:
- 在 proposal 中明确标注 Modified Capabilities
- 创建 delta spec 文件（如需要）
- 与主页规格保持松耦合（通过导航和回调）

---

## Migration Plan

### 实施步骤

#### Phase 1: 创建规格文档
1. 创建 `openspec/specs/flutter/card_creation_spec.md`
2. 定义所有交互行为的前置条件、操作步骤、后置条件
3. 编写测试用例（使用 `it_should_xxx()` 命名）

#### Phase 2: 编写测试
1. 创建 `test/specs/card_creation_spec_test.dart`
2. 实现所有测试用例（先失败）
3. 验证测试覆盖率（目标 > 90%）

#### Phase 3: 实现代码
1. 创建 `CardEditorScreen` widget
2. 实现自动保存逻辑（debounce）
3. 集成 Rust API (`CardApi.createCard()`)
4. 实现错误处理和用户反馈

#### Phase 4: 集成主页
1. 在 `HomeScreen` 添加 FAB 按钮
2. 实现导航到 `CardEditorScreen`
3. 实现创建完成后返回并刷新列表
4. 更新 SP-FLUT-008 规格（如需要）

#### Phase 5: 文档更新
1. 更新 `docs/interaction/ui_flows.md`（移除交互规格，添加引用）
2. 更新 `openspec/specs/README.md`（添加新规格索引）
3. 更新 `docs/design/` 中的相关引用

### 回滚策略
- 如果测试失败，不合并代码
- 如果发现性能问题，回退到手动保存模式
- 保留旧的 `ui_flows.md` 版本，以便回滚

### 验证标准
- [ ] 所有测试通过（`flutter test test/specs/card_creation_spec_test.dart`）
- [ ] 性能测试通过（30 秒内完成创建）
- [ ] 代码审查通过（遵循 Project Guardian 约束）
- [ ] 文档更新完成（规格、索引、交叉引用）

---

## Open Questions

### Q1: 是否需要支持 Markdown 实时预览？
**状态**: 待决定

**选项**:
- A: 仅支持 Markdown 输入，不预览（简单）
- B: 支持实时预览（复杂，但用户体验更好）

**建议**: 先实现 A，在后续 change 中添加 B

### Q2: 自动保存失败时，是否需要离线缓存？
**状态**: 待决定

**选项**:
- A: 仅显示错误提示，不缓存（简单）
- B: 使用 SharedPreferences 缓存，下次启动恢复（复杂）

**建议**: 先实现 A，在后续 change 中添加 B

### Q3: 是否需要支持草稿功能？
**状态**: 待决定

**选项**:
- A: 不支持草稿，退出即丢失（简单）
- B: 支持草稿，退出时保存（复杂）

**建议**: 先实现 A，在后续 change 中添加 B

### Q4: 是否需要修改 SP-FLUT-008 规格？
**状态**: 待确认

**影响**: 如果 SP-FLUT-008 需要修改，需要创建 delta spec

**建议**: 先查看 SP-FLUT-008 的当前状态，确定是否需要修改
