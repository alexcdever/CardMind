input: 当前文档约束检查脚本/测试现状，及重构目标（移除自动门禁，内化标准）
output: 文档治理重构设计，明确删除范围、标准内化策略、验证与迁移方案
pos: 将文档治理从“脚本/测试硬阻断”重构为“标准文档+AI执行+人工评审”，降低维护耦合

# 2026-03-05 文档治理重构设计

## 1. 背景与目标

当前仓库中存在多类“文档约束检查”自动门禁：

- 分形文档检查链路：`tool/fractal_doc_check.dart` + `tool/fractal_doc_checker.dart` + `tool/fractal_doc_bootstrap.dart` 及其测试。
- 计划文档 TDD 关键词守卫：`test/plan_tdd_guard_test.dart`。
- UI 治理文档内容守卫：`test/ui_interaction_governance_docs_test.dart`。

这些门禁能提供约束，但维护成本高、对文案与专题结构耦合强，易在规则演化时导致非业务阻断。

本次重构目标：

1. 移除全部文档约束检查脚本与测试硬门禁。
2. 将“分形文档规则”“完整 TDD 流程规则”内化到 `docs/standards/`，作为 AI 与研发默认遵循标准。
3. 移除 UI 治理专题门禁及其配套文档链路，仅保留必要 UI 规格文档作为事实源。

## 2. 方案选型

### 2.1 候选方案

- 方案 A（推荐）：一次性切换。单轮完成标准定稿、脚本/测试删除、引用清理。
- 方案 B：两阶段切换。先定标准，再删门禁，短期保留双轨。
- 方案 C：最小删除。只删代码，标准最小改动。

### 2.2 选型结论

采用方案 A。

原因：

- 用户策略已明确，不需要过渡期双轨。
- 能快速消除“规则在文档、实现在脚本”不一致风险。
- 可一次性清理引用，避免后续悬挂路径与过时命令。

## 3. 目标架构（治理方式）

重构后治理架构：

- 规则承载层：`docs/standards/documentation.md` 与 `docs/standards/tdd.md`。
- 执行层：AI 默认遵循标准 + 开发者执行。
- 审核层：代码评审对标准符合性进行人工把关。

明确不再保留：

- 文档关键词字符串断言测试。
- 文档检查 CLI 强阻断链路。
- UI 治理专题的附加门禁文档体系（设计/矩阵/release gate）。

## 4. 变更范围

### 4.1 删除项

- 工具脚本：
  - `tool/fractal_doc_check.dart`
  - `tool/fractal_doc_checker.dart`
  - `tool/fractal_doc_bootstrap.dart`
- 测试：
  - `test/fractal_doc_checker_test.dart`
  - `test/plan_tdd_guard_test.dart`
  - `test/ui_interaction_governance_docs_test.dart`
- UI 治理专题文档：
  - `docs/plans/2026-02-27-ui-interaction-governance-design.md`
  - `docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md`
  - `docs/plans/2026-02-27-ui-interaction-release-gate.md`

### 4.2 更新项

- 标准文档：
  - `docs/standards/documentation.md`
  - `docs/standards/tdd.md`
- 索引与引用：
  - `docs/plans/DIR.md`
  - 其他提及旧命令与旧路径的文档内容。

## 5. 数据流与依赖流变化

重构前：

`git diff -> fractal_doc_check CLI -> checker -> tests -> 阻断`

重构后：

`标准文档 -> AI/开发执行 -> Code Review 人工验收`

影响：

- 删除自动阻断，减少脚本维护与文案耦合。
- 把“是否符合标准”的判定前移到执行与评审流程。

## 6. 错误处理与风险控制

### 6.1 主要风险

- 删除后仍存在旧命令引用（如 `dart run tool/fractal_doc_check.dart --base`）。
- 计划索引残留已删除文件。
- 团队担心约束强度下降。

### 6.2 控制策略

- 先更新标准，再删除实现，最后全仓引用清理。
- 以“无悬挂引用”作为验收硬条件。
- 在标准中明确“必须遵循”的角色责任，替代脚本阻断。

### 6.3 回滚策略

- 如后续验证约束不足，仅恢复“低耦合结构化检查”作为可选增强。
- 不回滚到强字符串断言与专题耦合门禁模式。

## 7. 测试与验收策略

本次为治理重构，不引入产品行为改动。验收聚焦仓库一致性：

1. 已删除文件不再被任何文档或脚本引用。
2. 标准文档可独立表达分形文档与完整 TDD 规范。
3. UI 规格仍由 `docs/specs/ui-interaction.md` 承载，不依赖专题门禁文档。
4. 常规质量命令（如 `flutter analyze`、`flutter test`）可继续作为工程质量检查，但不再承担文档门禁职责。

## 8. 实施边界

- 本设计仅定义治理重构方案与落地约束。
- 不在本阶段执行代码实现与文件删除。
- 下一阶段仅进入实施计划编写（`writing-plans`），再按计划实施。
