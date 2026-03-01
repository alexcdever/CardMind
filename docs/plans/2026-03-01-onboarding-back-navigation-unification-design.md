# 引导与全局返回策略统一设计（方案 A）

## 1. 背景与问题

- 当前引导页在“创建或加入数据池”路径上缺少清晰可验证的返回策略说明。
- 用户期望是“仅系统返回”，并且要统一移动端与桌面端的返回行为。
- 当前主壳（卡片/数据池/设置）缺少统一的系统返回处理链路，导致体验不一致。

## 2. 目标与非目标

### 2.1 目标

- 引导页进入“创建/加入池”后，系统返回可稳定回到引导页。
- 主壳内统一双段返回：
  - 若当前不在卡片页，系统返回先切回卡片页；
  - 若当前已在卡片列表页，弹出“是否退出应用？”确认框。
- 退出确认框行为：
  - 选择“是”退出应用；
  - 选择“否”仅关闭弹窗，停留当前页。
- 同一策略覆盖移动端与桌面端（仅触发入口不同）。

### 2.2 非目标

- 不改造为每个 Tab 独立 Navigator 栈。
- 不引入新的全局路由守卫服务。
- 不进行引导页视觉改版。

## 3. 方案对比与结论

### 3.1 备选方案

1. 方案 A：页面栈 + 主壳拦截（推荐）
2. 方案 B：每个 Tab 独立导航栈 + 根级协调
3. 方案 C：统一路由守卫服务

### 3.2 结论

- 采用方案 A。
- 原因：最小改动覆盖全部需求、回归风险低、测试边界清晰，符合 YAGNI。

## 4. 架构设计

### 4.1 导航分层

- `OnboardingPage`：负责首次分流（本地使用 / 创建或加入数据池）。
- `AppShellPage`：负责三标签主壳及全局返回策略。
- `PoolPage`、`CardsPage`、`SettingsPage`：保持业务页面职责，不各自实现分叉的全局返回规则。

### 4.2 统一返回状态机

1. `Onboarding -> Pool(notJoined)`：通过 `Navigator.push(...)` 入栈。
2. 在 `PoolPage` 收到系统返回：优先 `pop` 回 `OnboardingPage`。
3. 在 `AppShellPage` 收到系统返回：
   - 若 `section != cards`：执行 `setSection(cards)` 并消费返回；
   - 若 `section == cards`：弹出退出确认框。
4. 在退出确认框中：
   - 选“否”关闭弹窗，不退出；
   - 选“是”触发平台退出动作。

### 4.3 跨端统一语义

- 移动端：返回键 / 返回手势触发 back intent。
- 桌面端：等效返回意图触发同一判定链。
- 规则一致，入口不同。

## 5. 组件职责与变更边界

### 5.1 Onboarding

- 文件：`lib/features/onboarding/onboarding_page.dart`
- 约束：保持“创建或加入数据池”使用 `push` 而非 `pushReplacement`。

### 5.2 App Shell

- 文件：`lib/app/navigation/app_shell_page.dart`
- 责任：统一处理系统返回、切回卡片逻辑与退出确认框展示。

### 5.3 Controller

- 文件：`lib/app/navigation/app_shell_controller.dart`
- 责任：复用现有 `section` 和 `setSection`，不新增持久化状态。

## 6. 数据流与状态管理

- 不新增业务域状态模型。
- 退出确认框为瞬时 UI 状态，不入库、不持久化。
- 返回优先级：子路由可回退 > 主壳切卡片 > 退出确认。

## 7. 异常与边界处理

- 弹窗防重入：弹窗显示期间不重复弹出第二个确认框。
- 弹窗显示时再次 back：优先关闭弹窗，不直接退出。
- 平台退出兜底：若平台无法直接退出，退化为窗口关闭请求，避免未处理异常。
- 所有交互保持非空回调，符合交互守卫约束。

## 8. 测试与验收

### 8.1 用例覆盖

- `test/features/onboarding/onboarding_page_test.dart`
  - 引导进入池页后，系统返回回到引导页。
- 建议新增 `test/app/navigation/app_shell_page_test.dart`
  - 在 `pool/settings` 标签 back：切回 `cards`，不退出。
  - 在 `cards` 标签 back：显示“是否退出应用？”弹窗。
  - 弹窗点“否”：关闭弹窗并停留当前页。
  - 弹窗可见时再次 back：先关闭弹窗。

### 8.2 治理门禁

- 同步更新文档：
  - `docs/plans/2026-02-27-ui-interaction-governance-design.md`
  - `docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md`
  - `docs/plans/2026-02-27-ui-interaction-release-gate.md`
- 执行守卫测试：
  - `flutter test test/interaction_guard_test.dart`
  - `flutter test test/ui_interaction_governance_docs_test.dart`

## 9. 实施原则

- 采用 TDD 小步推进：先补失败测试，再做最小实现，再补边界。
- 保持单一意图提交，避免无关改动混入。
- 优先最小改动满足需求，不做超前架构。
