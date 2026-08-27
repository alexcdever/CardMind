# Task U8-R4: 续作——消除手动凭证失败重复日志并刷新证据链

## 设计方裁决

U8 第三轮产物已在 `D:/Projects/CardMind/.worktrees/scanner-feedback`，禁止删除或重建 worktree。

Hermes 终审实测：

- `pairing_credential_ui_test.dart`：18 项通过；
- `pairing_log_events_test.dart`：10 项通过；
- `pairing_accept_ui_test.dart`：8 项通过；
- `pairing_mdns_widget_test.dart`：7 项通过；
- `flutter analyze`：No issues；`git diff --check` 通过。

但终审发现验收冲突：任务单 B7 明确“手动凭证不得重复输出两个 failed 事件”，当前 `test/pairing_log_events_test.dart` 的恶意异常用例却断言 `hasLength(2)`；生产代码中 `_connectCredential` 已记录 credential failed，`_enterPeerCode` 外层 generic catch 又记录一条无 source/transport 的 failed，造成重复。

设计方裁决：**每次手动 cm1 凭证连接失败只允许一条 `pairing.connect failed`，由 `_connectCredential(source: manual)` 负责；外层输入弹窗 catch 只负责 UI 错误状态，不得重复记录 credential 失败。六位码路径仍保留其原有连接日志语义。**

## 主仓库与 worktree

- 主仓库：`D:/Projects/CardMind`
- 既有 worktree：`D:/Projects/CardMind/.worktrees/scanner-feedback`
- 既有分支：`codex/scanner-feedback`
- 禁止 `git worktree remove`、禁止新建 worktree、禁止丢失 U8 已实现的扫描进度/结果 UI 与真实 Navigator 测试。

## 改动范围

仅允许：

- `lib/pages/devices_page.dart`：消除手动 cm1 的重复 failed 日志；不得改扫码 UI/协议/网络逻辑。
- `test/pairing_log_events_test.dart`：将恶意异常用例改为断言 failed 事件恰好 1 条，并确认 `source=manual transport=credential`。
- `.workflow/executor-report.md`
- `.workflow/review-report.md`
- `.workflow/final-check.md`

禁止改其他文件。

## 验收标准

1. 先红：把恶意异常用例改为 `failed events hasLength(1)`，运行 `flutter test test/pairing_log_events_test.dart --timeout 3m`，必须在旧实现上失败并记录摘要。
2. 绿：修复后同命令 10 项全过；唯一 failed 事件 fields 为：
   - `action=failed`
   - `transport=credential`
   - `source=manual`
   - `errorChain` 不含 `cm1.SECRET`、`123456`、`TOPSECRET`。
3. 运行 U8 全验收：
   - `flutter test test/pairing_credential_ui_test.dart --timeout 3m`
   - `flutter test test/pairing_log_events_test.dart --timeout 3m`
   - `flutter test test/pairing_accept_ui_test.dart --timeout 3m`
   - `flutter test test/pairing_mdns_widget_test.dart --timeout 3m`
   - 每条命令外层不超过 3 分钟。
4. `flutter analyze` 无 issue；`git diff --check` 通过。
5. `git status --short` 只含 U8/U8-R4 允许文件和 `.workflow/`。
6. 证据链必须刷新：
   - `.workflow/executor-report.md` 标题/正文明确 `Task U8-R4`，含红绿输出；
   - `.workflow/review-report.md` 必须明确 `Task U8-R4`，不得保留 U5 旧报告；
   - `.workflow/final-check.md` 必须明确 `Task U8-R4`，不得保留旧任务内容。

## 需决策点

若消除重复日志需要修改 repository/FRB/Rust/协议，立即停止报告；不得扩大范围。

## 交付

agents 不提交、不合并、不推送。