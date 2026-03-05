input: 现有 UI 规格文档与补强需求（A11y/性能预算/i18n）
output: UI 规格补强设计与执行边界
pos: UI 交互规格补强设计文档（修改需同步 DIR.md）
# UI 交互规格补强设计（2026-03-04）

- 日期：2026-03-04
- 状态：approved
- 目标文件：`docs/specs/ui-interaction.md`

## 1. 背景

当前 `ui-interaction` 规格已覆盖交互强约束、视觉中约束、状态机与黑盒验收，但在长期治理视角仍需补强可执行细节：

1. A11y 条款分散，缺少独立章节与最小验收闭环。
2. 性能反馈仅有原则性表述，缺少宽松但可验证预算。
3. i18n/文案伸缩缺少边界，后续多语言扩展存在布局风险。

## 2. 目标

1. 补齐 A11y 强约束（键盘、焦点、语义、手势替代）。
2. 增加“可用性优先”的宽松性能预算，避免高压性能门槛。
3. 定义 i18n 与文案伸缩布局约束，降低后续国际化返工。
4. 在验收章节补充 A11y/性能/i18n 的黑盒用例。

## 3. 非目标

1. 不引入具体组件库 API 或平台控件实现细节。
2. 不将性能预算升级为严格 SLA 或工程压测指标。
3. 不在本次引入新的业务流程（仅补强现有 S1-S5 的规格质量）。

## 4. 关键决策

1. A11y 采用 MUST/SHOULD 混合：关键可达性 MUST，体验优化 SHOULD。
2. 性能采用“宽松基线”而非“极致指标”：优先保证有反馈、可恢复。
3. i18n 以布局弹性约束为主，不锁死语言包与文案系统实现。
4. 所有新增条款必须可映射到 Given/When/Then 验收。

## 5. 文档变更结构

在 `docs/specs/ui-interaction.md` 中新增：

1. `5.10 无障碍（A11y）约束`
2. `5.11 国际化与文案伸缩约束`
3. `6.7 性能预算与反馈时延（宽松基线）`
4. `7.5 A11y / 性能 / i18n 最小验收补充`

## 6. 验证策略

1. 运行 `flutter test docs/standards/ui-interaction-governance.md`，确保治理文档守卫仍通过。
2. 运行 `flutter analyze`，确保仓库无新增静态检查问题。

## 7. 交付与影响

1. 新增设计文档：`docs/plans/2026-03-04-ui-interaction-spec-hardening-design.md`。
2. 新增实施计划：`docs/plans/2026-03-04-ui-interaction-spec-hardening-implementation-plan.md`。
3. 更新 `docs/plans/DIR.md` 索引。
