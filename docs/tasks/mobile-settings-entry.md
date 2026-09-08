# 任务：移动端设置入口

## 任务目标

移动端布局（`_buildMobile`）当前没有任何 `/settings` 路由入口：设置按钮只存在于桌面侧边栏（`note_list_page.dart:684`，`open-settings`），手机用户无法进入设置页，也就无法使用已完成的"更新渠道选择 + 检查更新 + 下载安装"功能。本任务在移动端 AppBar 添加设置入口并保持既有行为不回退。

## 主仓库与 worktree

主仓库路径: D:/Projects/CardMind
worktree 路径: D:/Projects/CardMind/.worktrees/mobile-settings-entry
worktree 分支: mobile-settings-entry

## 已有基础

- 路由已存在：`main.dart` 已注册 `/settings`（`case '/settings'`），设置页 `SettingsPage` 完整可用（渠道选择、检查更新、下载、安装状态）。
- 桌面入口已存在：`note_list_page.dart` `_buildSidebar` 内 `ValueKey('open-settings')` 的 TextButton.icon。
- 移动端布局：`note_list_page.dart` `_buildMobile`，AppBar actions 现有：回收站（`trash-entry`）、条件显示立即同步（`sync-now-button`）、同步状态指示。底部导航 `main-navigation`：笔记 / 设备 两个 tab。
- 已有参照测试：`test/vertical_slice_widget_test.dart:297` 桌面设置入口点击链路；`test/mobile_ui_test.dart` 移动端布局测试。

## 改动范围

允许修改：
- `lib/pages/note_list_page.dart`（仅移动端 AppBar actions 一处）
- `test/` 对应测试（新增或扩展）

禁止修改：
- 设置页本身（`lib/pages/settings_page.dart`）、更新服务、下载器、安装器——本任务不改更新功能
- 路由注册、桌面侧边栏、底部导航结构
- `.env`、用户未跟踪资料（docs/research/、web-articles/）
- 任何 `pubspec` 依赖

## 验收模式

测试模式: Widget（移动端布局导航链路）
浏览器验收模式: 不适用
选择理由与证据边界: 纯 UI 导航改动，Widget 测试可完整覆盖入口存在性与路由跳转；真实移动端安装验证（设置页可达）由本任务后的应用内更新 E2E 任务覆盖。
环境前置: `PUB_HOSTED_URL=https://pub.flutter-io.cn`；所有测试 `--timeout 3m`，外层硬超时 180s；worktree 内 `git config core.autocrlf false`。

## 设计决策（已定，不留给 executor）

- 入口位置：移动端 AppBar actions，放在回收站按钮**左侧**（设置是低频入口，回收站更高频）。
- 形式：`IconButton` + `Icons.settings_outlined`，tooltip '设置'，key `ValueKey('open-settings-mobile')`（与桌面 `open-settings` 区分，两端可分别定位断言）。
- 行为：点击 `Navigator.of(context).pushNamed('/settings')`，与桌面 `_openSettings` 完全一致（复用同一方法即可）。

## 验收标准（每条 = 一个测试用例）

1. `test/vertical_slice_widget_test.dart`（或新增移动端布局测试文件）— 新用例 `mobile app bar shows settings entry`：在移动端宽度（< CardMindLayout.desktopBreakpoint）下 pump NoteListPage，`find.byKey(const ValueKey('open-settings-mobile'))` 存在且可见；桌面 `open-settings` 按钮**不**同时出现。
2. 同上文件 — 新用例 `mobile settings entry navigates to settings page`：tap `open-settings-mobile` 后 pump，路由进入 `/settings`（通过 `find.byType(SettingsPage)` 或页面标题 '设置' 断言）。
3. 既有回归 — `test/vertical_slice_widget_test.dart` 既有用例（含桌面 `open-settings` 点击链路）全部继续通过。
4. 既有回归 — `flutter test --timeout 3m` 全量 suite 通过（+229 基线，本任务只增不减）。
5. 静态检查 — `dart format` 无变更、`flutter analyze` 零 issue。

## 需决策点

- 若移动端 AppBar 空间不足（回收站+同步+状态+设置溢出），停下报告，不自行改成抽屉/菜单。
- 若发现移动端已有其他设置入口（本设计遗漏），停下报告，不重复添加。

## 任务专属证据目录

所有流水线报告写入：

```text
.workflow/mobile-settings-entry/executor-report.md
.workflow/mobile-settings-entry/review-report.md
.workflow/mobile-settings-entry/final-check.md
```

不得覆盖其他任务的 `.workflow/` 目录。

## 验收进度台账（由 Hermes 维护）

| AC | 状态 | 当前测试/命令 | 最新证据 | 备注 |
|---|---|---|---|---|
| AC1 | 通过 | `flutter test test/vertical_slice_widget_test.dart --plain-name 'mobile app bar shows settings entry'` | `+1 All tests passed` | 移动 key 出现、桌面 key 不出现 |
| AC2 | 通过 | `--plain-name 'mobile settings entry navigates to settings page'` | `+1 All tests passed` | tap 后进入 /settings |
| AC3 | 通过 | `flutter test test/vertical_slice_widget_test.dart --timeout 3m` | `+14 All tests passed` | 桌面入口链路不回退 |
| AC4 | 通过 | `flutter test --timeout 3m`（修复 FRB lock 后） | `00:34 +232: All tests passed!` | executor 环境偏差由 Hermes 修复复验 |
| AC5 | 通过 | `dart format --set-exit-if-changed` + `flutter analyze` | 0 changed / No issues | |

## 执行记录（由 Hermes 维护）

| 时间/轮次 | 事件 | 结果 | 证据 | 后续 |
|---|---|---|---|---|
| 2026-09-08 | 任务单创建并提交 | 完成 | 942f4c3 | 派发流水线 |
| 2026-09-08 | dispatch-with-watchdog 统一派单（Luna） | 正常完成 | preflight OK、registry running→完成 | executor+reviewer+re-check |
| 2026-09-08 | executor 实现 + reviewer 独立复验 | AC1-3/5 PASS，AC4 环境阻塞 | .workflow/mobile-settings-entry/ 三报告 | 环境排查 |
| 2026-09-08 | Hermes 修复 worktree pubspec.lock 被重写（FRB 2.12→2.13 失配） | AC4 复验 `+232` 全绿 | final-check.md 合并后门禁记录 | 终审合并 |

## 设计变更与 continuation 索引（由 Hermes 维护）

- 无。

## 最终结果（由 Hermes 维护）

- 状态：完成
- 四级验证：executor 自检 PASS → 独立 reviewer PASS（本任务首次形成有效独立 reviewer 报告）→ build re-check PASS（环境修复后）→ Hermes 终审 PASS
- 合并提交：8a187bad（--no-ff，含实现 20e5be3c 与证据 42440b04）
- 遗留项：无
- 合并后主仓复验：vertical_slice +14 全绿、flutter analyze 零 issue
