# Remove Settings Primary Entry Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 移除设置页作为一级导航入口，让当前主导航只保留 `卡片` 与 `数据池`，并同步对齐交互规格与导航测试契约。

**Architecture:** 本计划只做导航语义收缩，不补设置能力。先更新交互规格，把“设置不再是公开一级入口”写成正式约束；再在 Flutter 导航枚举、主页脚手架和相关页面/测试中移除 `settings` 作为公开分区的存在；最后清理设置页测试契约并完成回归验证。

**Tech Stack:** Flutter/Dart、Markdown 规格文档、Flutter widget tests、git

---

## File Structure

- Modify: `docs/specs/ui-interaction.md`
  - 收紧一级导航定义与设置分区约束，移除“设置必须为三域之一”的旧表述。
- Modify: `lib/app/navigation/app_section.dart`
  - 将公开导航分区从 `cards/pool/settings` 收缩为 `cards/pool`。
- Modify: `lib/app/navigation/app_homepage_page.dart`
  - 收拢主页分区分发逻辑，移除公开 `settings` 分区渲染分支。
- Modify: `lib/app/layout/adaptive_homepage_scaffold.dart`
  - 移除设置导航项与相关键盘切换逻辑，保持卡片/数据池双分区导航成立。
- Modify: `lib/features/shared/testing/semantic_ids.dart`
  - 移除 `navSettings` 等不再属于公开主导航契约的语义 ID；仅在必要时保留 `settingsPage` 作为内部页面锚点。
- Modify: `test/widget/pages/settings_page_test.dart`
  - 退役或重写旧设置页占位契约，避免页面测试承担主页导航职责。
- Modify: `test/widget/pages/adaptive_homepage_test.dart`
  - 对齐移动端/桌面端导航可见项与切换契约。
- Modify: `test/widget/pages/app_homepage_test.dart`
  - 对齐主页默认落点与分区切换测试，确保设置移除后主路径仍成立。
- Modify: `test/widget/components/semantic_ids_test.dart`
  - 对齐公开导航语义锚点集合，移除对 `navSettings` 暴露的要求。
- Modify: `test/integration/features/automation_flow_test.dart`
  - 移除“从设置切换”的自动化主路径，并以 cards/pool 两分区主路径替代。
- Optional Modify: `lib/features/settings/settings_page.dart`
  - 仅在编译或内部引用收口需要时做最小化调整；若页面保留为未公开内部页面则不改。
- Verify: `docs/plans/DIR.md`
  - 验证本实施计划文件索引已存在，不重复登记。

---

## Chunk 1: Update The Interaction Truth Source

### Task 1: Align `docs/specs/ui-interaction.md`

**Files:**
- Modify: `docs/specs/ui-interaction.md`
- Reference: `docs/plans/2026-03-20-remove-settings-primary-entry-design.md`
- Reference: `docs/specs/product.md`
- Reference: `docs/specs/user-journeys.md`

- [ ] **Step 1: Write the failing spec alignment checklist**

Define this checklist in your working notes before editing:

```text
1. 是否还把主导航定义为 卡片/池/设置 三分区
2. 是否还要求设置页作为当前版本公开一级分区存在
3. 是否明确 FORBIDDEN 保留任何公开可达的一级设置入口
4. 是否明确主导航当前只保留 卡片/数据池
```

- [ ] **Step 2: Verify current mismatch**

Run: `rg "卡片.*/.*池.*/.*设置|设置页 MUST|设置 Tab|三域" docs/specs/ui-interaction.md`
Expected: 至少命中 2 处旧语义，证明规格尚未对齐

- [ ] **Step 3: Update the minimal required spec sections**

Modify only the sections necessary to reflect the new truth:
- 移动端主导航语义从三分区改为两分区：`卡片` / `数据池`
- 不再把设置页作为当前阶段公开一级分区
- 明确当前阶段 FORBIDDEN 保留任何公开可达的一级设置入口
- 保持默认落点仍为 `卡片`

Do not redesign unrelated layout rules.

- [ ] **Step 4: Verify spec alignment**

Run: `rg "卡片.*数据池|FORBIDDEN.*一级设置入口|默认落点.*卡片|设置页 MUST 为当前版本的空白占位页" docs/specs/ui-interaction.md`
Expected: 前三项命中新语义，最后一项不再命中

- [ ] **Step 5: Run formatting verification**

Run: `git diff --check`
Expected: no whitespace or patch formatting issues

- [ ] **Step 6: Commit task 1**

```bash
git add docs/specs/ui-interaction.md
git commit -m "docs: remove settings from primary navigation spec"
```

---

## Chunk 2: Remove The Public Settings Navigation Path

### Task 2: Update navigation enum and scaffold

**Files:**
- Modify: `lib/app/navigation/app_section.dart`
- Modify: `lib/app/navigation/app_homepage_page.dart`
- Modify: `lib/app/layout/adaptive_homepage_scaffold.dart`
- Modify: `lib/features/shared/testing/semantic_ids.dart`
- Optional Modify: `lib/features/settings/settings_page.dart`

- [ ] **Step 1: Write a failing navigation contract test target list**

Record these expected public-navigation outcomes:

```text
1. AppSection 不再暴露 settings 作为公开分区
2. AppHomepagePage 不再公开分发 SettingsPage 作为主页主分区
3. AdaptiveHomepageScaffold 不再渲染设置导航项
4. SemanticIds 不再暴露 navSettings 作为公开导航锚点
5. 键盘切换只在 cards/pool 两分区间循环
6. 默认 section 语义仍以 cards 为主路径
```

- [ ] **Step 2: Verify current code still exposes settings**

Run: `rg "settings|设置" lib/app/navigation/app_section.dart lib/app/navigation/app_homepage_page.dart lib/app/layout/adaptive_homepage_scaffold.dart lib/features/shared/testing/semantic_ids.dart`
Expected: 命中当前 settings 分区、设置导航项、主页分发分支与公开导航语义 ID 定义

- [ ] **Step 3: Implement the minimal navigation change**

Apply these constraints:
- `AppSection` 只保留 `cards`、`pool`
- `AppHomepagePage` 不再把 `settings` 作为主页公开主分区进行分发
- `AdaptiveHomepageScaffold` destinations 只保留卡片/数据池
- `SemanticIds` 不再把 `navSettings` 作为公开导航锚点保留
- 数字键与方向键切换逻辑适配两分区
- 不引入新的次级设置入口

Only touch `lib/features/settings/settings_page.dart` if compilation requires it.

- [ ] **Step 4: Run focused verification**

Run: `flutter test test/widget/pages/adaptive_homepage_test.dart test/widget/pages/app_homepage_test.dart test/widget/pages/settings_page_test.dart test/widget/components/semantic_ids_test.dart test/integration/features/automation_flow_test.dart`
Expected: 先失败（旧契约未对齐）或在后续测试更新前出现与 settings 移除相关的预期失败

- [ ] **Step 5: Commit task 2 only after tests are aligned in Task 3**

Do not commit this task independently if the focused tests are still failing solely because test expectations have not yet been updated.

---

## Chunk 3: Replace The Old Settings Contract Tests

### Task 3: Rewrite widget/navigation tests around the new public contract

**Files:**
- Modify: `test/widget/pages/settings_page_test.dart`
- Modify: `test/widget/pages/adaptive_homepage_test.dart`
- Modify: `test/widget/pages/app_homepage_test.dart`
- Modify: `test/widget/components/semantic_ids_test.dart`
- Modify: `test/integration/features/automation_flow_test.dart`

- [ ] **Step 1: Replace the old settings-page contract**

In `test/widget/pages/settings_page_test.dart`, rewrite the file in place so it no longer asserts:
- 设置页保持空白
- 从设置页可一步切到卡片/池

Replace it with a minimal, executable outcome:
1. 若 `SettingsPage` 仍作为内部页面保留，则只保留其最小页面契约测试
2. 不再让该文件承担公开导航主路径断言

Constraint:
- 本计划统一采用“保留文件、重写测试职责”的单一路径，不删除 `test/widget/pages/settings_page_test.dart`

- [ ] **Step 2: Update homepage/adaptive navigation expectations**

In the other two test files, align expectations so that:
- 移动端底部导航仅显示两项
- 桌面端导航仅显示两项
- 默认落点仍为卡片
- cards/pool 切换仍为一步可达

Also align these additional test contracts:
- `test/widget/components/semantic_ids_test.dart` 不再要求 `navSettings` 暴露
- `test/integration/features/automation_flow_test.dart` 不再以 `settings` 作为公开切换起点

- [ ] **Step 3: Run focused widget tests**

Run: `flutter test test/widget/pages/settings_page_test.dart test/widget/pages/adaptive_homepage_test.dart test/widget/pages/app_homepage_test.dart test/widget/components/semantic_ids_test.dart test/integration/features/automation_flow_test.dart`
Expected: PASS

- [ ] **Step 4: Run broader navigation regression tests**

Run: `flutter test test/widget/pages test/widget/components test/integration/features/automation_flow_test.dart`
Expected: PASS

- [ ] **Step 5: Run formatting verification**

Run: `git diff --check`
Expected: no whitespace or patch formatting issues

- [ ] **Step 6: Commit tasks 2 and 3 together**

```bash
git add lib/app/navigation/app_section.dart lib/app/navigation/app_homepage_page.dart lib/app/layout/adaptive_homepage_scaffold.dart lib/features/shared/testing/semantic_ids.dart test/widget/pages/settings_page_test.dart test/widget/pages/adaptive_homepage_test.dart test/widget/pages/app_homepage_test.dart test/widget/components/semantic_ids_test.dart test/integration/features/automation_flow_test.dart
git commit -m "refactor: remove settings primary navigation entry"
```

If `lib/features/settings/settings_page.dart` was unchanged, do not stage it.

---

## Chunk 4: Register The Plan And Verify Final State

### Task 4: Verify plan index and run final checks

**Files:**
- Verify: `docs/plans/DIR.md`

- [ ] **Step 1: Verify this implementation plan is already indexed in `docs/plans/DIR.md`**

Run: `rg "2026-03-20-remove-settings-primary-entry-implementation-plan.md" docs/plans/DIR.md`
Expected: 已命中该计划条目；若未命中，停止执行并先补齐索引

- [ ] **Step 2: Run final quality verification for docs-only changes**

Run: `git diff --check`
Expected: no whitespace or patch formatting issues

- [ ] **Step 3: Run final Flutter verification for this change set**

Run: `flutter test test/widget/pages/settings_page_test.dart test/widget/pages/adaptive_homepage_test.dart test/widget/pages/app_homepage_test.dart test/widget/components/semantic_ids_test.dart test/integration/features/automation_flow_test.dart`
Expected: 全部通过

- [ ] **Step 4: Run broader Flutter safety net**

Run: `flutter test`
Expected: PASS

- [ ] **Step 5: Commit task 4 only if this chunk required a tracked file change**

If this chunk introduced no new file changes, do not create an empty commit.
If a file was changed, use:

```bash
git add <changed-files>
git commit -m "docs: finalize settings navigation removal handoff"
```

---

## Final Verification

- [ ] Run: `rg "settings|navSettings" lib/app/navigation/app_section.dart lib/app/navigation/app_homepage_page.dart lib/app/layout/adaptive_homepage_scaffold.dart lib/features/shared/testing/semantic_ids.dart test/widget/pages/settings_page_test.dart`
Expected: 不再出现 settings 或 `navSettings` 作为公开导航分区/公开导航锚点的定义；`settings_page_test.dart` 中仅保留内部页面最小契约相关引用

- [ ] Run: `flutter test`
Expected: PASS

- [ ] Run: `git status --short`
Expected: working tree clean after all planned commits

---

## Notes For The Implementer

- 本次只移除误导性的一级设置入口，不允许顺手补设置中心。
- 本次范围是移除公开一级设置入口，不自动扩展到“永久禁止任何未来公开设置入口”的产品结论。
- 如果发现某处实现把 `settings` 分区深度嵌入更多公开导航逻辑，应只做最小删除或重定向，不要扩张成整套导航重构。
- 如果某个测试失败暴露了“设置分区仍被当作公开主路径”的隐藏契约，应优先把契约收紧到卡片/数据池两分区语义。
