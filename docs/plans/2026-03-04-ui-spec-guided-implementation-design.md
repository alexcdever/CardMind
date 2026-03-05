input: 用户要求评估 UI 规格是否完备并按规格实施
output: 规格驱动 UI 实施设计（分阶段 + 受控补规格）
pos: 设计草案，指导后续实施计划拆解
# UI 规格驱动实施设计（2026-03-04）

- 日期：2026-03-04
- 状态：approved
- 关联规格：`docs/specs/ui-interaction.md`

## 1. 目标

在不偏离 `ui-interaction` 规格的前提下，按阶段推进 UI 落地，确保：

1. 关键流程 S1-S5 可观察行为满足 MUST/FORBIDDEN。
2. 规格缺口仅在“实现无法判定”时最小补充。
3. 每轮实施都具备可验证、可回归、可门禁放行证据。

## 2. 范围与策略

采用 **B + C 组合策略**：

1. **B（受控补规格）**：实施中遇到规格缺口时，最小增量补充 `docs/specs/ui-interaction.md`。
2. **C（分阶段推进）**：
   - P1：S1 + S2（引导/返回 + 卡片主流程）
   - P2：S3（池生命周期与错误恢复）
   - P3：S4 + S5（设置可达 + 同步异常）

## 3. 架构分工

1. **壳层导航**（`AdaptiveShell` / `AppShell`）
   - 承担跨端导航结构与 section 切换。
   - 承担 S1 双段返回与 S4 一步可达约束。
2. **页面层**（onboarding/cards/editor/pool/settings）
   - 仅表达可观察行为与入口，不承载跨页业务判定。
3. **控制器/状态层**（EditorController、PoolController 等）
   - 统一管理提交中、成功、失败、降级等状态。
   - 向 UI 暴露可渲染状态，不向 UI 泄漏实现细节。

## 4. 错误处理与恢复设计

1. 关键动作失败反馈必须包含：`发生了什么 + 下一步动作`。
2. 池相关错误码映射沿用规格 6.6，禁止“统一失败文案”吞语义。
3. 同步异常遵循 S5：可见、可处理、且不阻断本地卡片读写。

## 5. 测试与门禁设计

1. 每条关键 MUST 至少有 1 条行为断言（Widget/集成测试）。
2. 每类 FORBIDDEN 至少有 1 条守卫断言（防回归）。
3. 每阶段结束必须通过：
   - `flutter test test/interaction_guard_test.dart`
   - `flutter test test/interaction_guard_test.dart`
   - `flutter analyze`
4. 阶段总验收以 `docs/specs/ui-interaction.md` 第 7 章 Given/When/Then 为基准。

## 6. 规格变更规则（Spec-First）

1. 仅当实现无法从现有规格判定时，允许补充规格。
2. 补充范围仅限当前实施所需最小条款，禁止无关扩写。
3. 任何规格目录语义变更需同步 `docs/specs/DIR.md` 与 `docs/DIR.md`。

## 7. 交付物

1. 设计文档：`docs/plans/2026-03-04-ui-spec-guided-implementation-design.md`
2. 实施计划：`docs/plans/2026-03-04-ui-spec-guided-implementation-plan.md`
