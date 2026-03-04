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

## 5. S1 完成证据
- 关键测试：`app cold start shows shell bottom nav on mobile`
- 关键测试：`back on non-cards tab switches to cards first`
- 关键测试：`back on cards shows exit confirmation dialog`
- 关键测试：`cancel on dialog stays in cards root`
- 关键命令：`flutter test test/app/app_shell_navigation_test.dart`

## 6. S2 完成证据
- 关键测试：`create-edit-save appears in cards list through read model`
- 关键测试：`save-and-leave closes editor and keeps context recoverable`
- 关键测试：`cancel on leave dialog keeps editing context visible`
- 关键测试：`save failure keeps editor open with retry hint`
- 关键测试：`search is case-insensitive across title and body for active notes`
- 关键命令：`flutter test test/features/cards/cards_page_test.dart`
- 关键命令：`flutter test test/features/editor/editor_page_test.dart`
- 关键命令：`flutter test test/features/cards/data/sqlite_cards_read_repository_test.dart`

## 7. S3 完成证据
- 关键测试：`join error state shows mapped primary action label`
- 关键测试：`POOL_NOT_FOUND shows stable primary and follow-up actions`
- 关键测试：`maps REQUEST_TIMEOUT to what happened and next step message`
- 关键测试：`retry action in partial cleanup keeps recovery visible`
- 关键命令：`flutter test test/features/pool/pool_page_test.dart`
- 关键命令：`flutter test test/features/pool/pool_sync_interaction_test.dart`
- 关键命令：`flutter test test/features/pool/join_error_mapper_test.dart`

## 8. S4 完成证据
- 关键测试：`from settings, tab switches to cards in one action`
- 关键测试：`from settings, tab switches to pool in one action`
- 关键测试：`settings pool entry can one-step open joined pool root`
- 关键测试：`mobile shell shows one-step tab targets from settings section`
- 关键命令：`flutter test test/features/settings/settings_page_test.dart`
- 关键命令：`flutter test test/app/adaptive_shell_test.dart`

## 9. S5 完成证据
- 关键测试：`degraded banner offers retry or reconnect and stays non-modal`
- 关键测试：`degraded sync remains non-blocking for local save flow`
- 关键测试：`sync error should show retry and reconnect actions`
- 关键测试：`error banner view action routes to pool error page`
- 关键命令：`flutter test test/features/sync/sync_banner_test.dart`
- 关键命令：`flutter test test/features/cards/cards_sync_navigation_test.dart`
- 关键命令：`flutter test test/features/sync/sync_controller_test.dart`

## 10. 最终签核清单（S1-S5）
| 场景 | 签核项 | 状态 |
| --- | --- | --- |
| S1 | 首屏默认卡片与双段返回 | 待签核 |
| S2 | 卡片 CRUD、离开保护与检索语义 | 待签核 |
| S3 | 池流程失败恢复与稳定错误码覆盖 | 待签核 |
| S4 | 设置页一跳到卡片/池 | 待签核 |
| S5 | 同步降级非阻断与恢复动作 | 待签核 |

### 最终回归命令
- `flutter test test/ui_interaction_governance_docs_test.dart`
- `flutter test test/interaction_guard_test.dart`
- `flutter test test/app/app_shell_navigation_test.dart`
- `flutter test test/features/cards/cards_page_test.dart`
- `flutter test test/features/editor/editor_page_test.dart`
- `flutter test test/features/pool/pool_page_test.dart`
- `flutter test test/features/settings/settings_page_test.dart`
- `flutter test test/features/sync/sync_banner_test.dart`
