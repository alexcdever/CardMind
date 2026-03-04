input: UI 交互变更发布前质量门禁要求
output: 发布阻断条件与必跑校验命令
pos: UI 交互发布门禁文档（修改需同步验收矩阵）
# UI 交互发布门禁（2026-02-27）

计划映射：`docs/plans/2026-03-05-ui-interaction-full-s1-s5-implementation-plan.md`

## 1. 双轨硬门禁
- 研发轨未达标：不可合并。
- 体验轨未达标：不可发布。

## 2. 必跑校验命令
- `flutter analyze`
- `flutter test`
- `flutter test test/ui_interaction_governance_docs_test.dart`
- `flutter test test/interaction_guard_test.dart`
- `dart run tool/fractal_doc_check.dart --base <commit>`

## 3. 拒绝条件
- 存在空交互实现（如 `onPressed: () {}`、`onTap: () {}`）。
- 存在无说明禁用交互（如 `onPressed: null`）。
- 交互变更未同步更新规范与验收矩阵。
- 主壳双段返回策略缺失（非卡片先回卡片，卡片页需“是否退出应用”确认）。
- 同步错误态缺少 `retry` 或 `reconnect` 恢复动作。
- `degraded` 状态阻断本地操作路径。
- 池 owner 缺少“编辑池信息”或“解散池”可执行交互。

## 4. S1-S5 任务映射
| 场景 | 对应任务 | 门禁状态 |
| --- | --- | --- |
| S1 | Task 2-3 | 未签核 |
| S2 | Task 4-6 | 未签核 |
| S3 | Task 7-9 | 未签核 |
| S4 | Task 10-11 | 未签核 |
| S5 | Task 12-13 | 未签核 |
