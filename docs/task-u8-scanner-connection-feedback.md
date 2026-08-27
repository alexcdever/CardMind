# Task U8: 扫码配对连接进度、结果反馈与诊断日志

## 用户实机缺陷

Android 真机扫描 Windows 显示的 CardMind 二维码后：扫码页立即退出，之后没有正在连接、成功或失败提示；Windows 端也没有配对请求或错误提示。

已核实：

- `AndroidScannerService._onDetect` 识别文本后立即 `Navigator.pop(ScanOutcome(text: text))`，这是正常的“扫码页完成”行为；
- `DevicesPage._scanPeerCredential` 随后直接、静默 `await beginPairingConnectWithCredential`，没有连接进度 UI；
- 扫码分支没有 `pairing.scan` / `pairing.connect` 结构化日志，而手动输入 `cm1...` 分支有完整 start/success/failed 日志；
- Windows 现场日志只有 `pairing.accept action=start`，没有收到任何发起方连接，最终用户关闭二维码弹窗后记录 cancelled；
- 现有 `scanner cm1 result connects directly without discovery` 测试使用同步 `_SupportedScanner`，没有真实 Navigator push/pop 生命周期，也没有长连接等待，因此无法复现用户路径。

## 主仓库与 worktree

- 主仓库：`D:/Projects/CardMind`
- worktree：`D:/Projects/CardMind/.worktrees/scanner-feedback`
- 分支：`codex/scanner-feedback`
- worktree 必须位于主仓库 `.worktrees/` 内。
- 主仓库存在用户未跟踪文件 `.env`、`docs/research/`、`web-articles/`，禁止修改、删除、提交。

## 产品与交互裁决

1. 扫码页识别到合法文本后可以关闭，但返回设备页后必须立刻出现**模态连接状态对话框**，不得只依赖 SnackBar。
2. 对话框初态显示“正在连接…”和进度指示；连接进行中不得因点空白关闭，必须有明确“取消/关闭”语义。若底层调用不可取消，关闭仅隐藏 UI，迟到结果不得再操作已销毁 context；优先保持对话框直到结果返回。
3. 成功时同一对话框切换为“配对成功”结果，显示对方设备名，用户点击“完成”关闭；关闭后刷新设备列表。
4. 失败时同一对话框切换为明确失败结果，显示 `PairingCredentialException.message`；未知异常显示“配对失败：无法连接到对方设备，请稍后重试”。提供“关闭”和“手动输入”命令；“手动输入”关闭结果对话框后进入现有手动输入弹窗。
5. 非 `cm1` 扫码内容、权限错误和用户取消保持原有语义，但错误不得仅一闪而过；至少用明确结果对话框展示。用户主动取消扫码可以静默返回。
6. 扫码凭证和手动输入 `cm1...` 必须共用一个私有连接函数，统一：
   - `pairing.discovery action=bypassed mdns_skipped=true`
   - `pairing.connect action=start transport=credential source=scan|manual`
   - `pairing.connect action=success|failed transport=credential source=... duration_ms`
   - 失败日志包含脱敏后的错误类型与 errorChain；禁止记录完整凭证、配对码、私钥、完整设备 ID。
7. 本任务不改 Rust 协议、relay 策略、mDNS 或配对凭证格式。先修复可观测性和用户反馈；网络根因由修复后的模拟器实测日志裁决。

## 改动范围

允许：

- `lib/pages/devices_page.dart`
- `lib/scanner/scanner_android_io.dart`（仅生命周期/防重复检测确有必要时）
- `test/pairing_credential_ui_test.dart`
- `test/pairing_log_events_test.dart`
- 可新增一个专门的扫码路由 widget 测试文件
- `.workflow/*.md`

禁止：

- `rust-backend/**`
- FRB 生成文件
- relay/mDNS/凭证协议
- 发布 workflow、依赖版本、锁文件
- 主仓库用户未跟踪文件

## 验收标准（每条对应测试用例）

所有单条测试命令外层不超过 3 分钟；先红后绿再蓝，executor 报告必须贴红阶段失败摘要。

### A. 真实 Navigator 扫码生命周期回归（必须先红）

在 widget 测试中新增 `_RouteScanner`：`scanCredential(context)` 必须真实 `Navigator.push` 一个测试扫码页，测试通过点击“模拟识别”按钮从该路由 `pop(ScanOutcome(text: 'cm1.scanned'))`，禁止直接 Future 返回。

1. `scanner route pop immediately shows persistent connecting dialog`
   - 打开添加设备 → 扫描入口 → 模拟识别；
   - 扫码页消失后，在仓库连接 Future 尚未完成时，存在 key `pair-scan-connecting-dialog`、文案“正在连接…”和进度指示；
   - 不存在静默空白期；
   - repository 已收到且只收到一次凭证调用。
2. `scanner delayed failure remains visible with actionable result`
   - repository Future 延迟后抛 `PairingCredentialException.unreachable`；
   - 同一流程显示 key `pair-scan-result-dialog` 和中文错误；
   - 结果不会因 `pumpAndSettle` 或短时间经过自动消失；
   - “手动输入”进入现有输入弹窗。
3. `scanner delayed success remains visible until user completes`
   - repository Future 延迟成功；
   - 显示配对成功和对方设备名；
   - 点击 key `pair-scan-done` 后关闭并刷新设备列表。
4. `scanner cancellation stays silent and never connects`
   - 扫码路由返回 cancelled；
   - 无连接/结果对话框，无 repository 调用。
5. `invalid scanned contents show persistent result dialog`
   - 非 cm1 文本显示明确错误结果对话框，不调用 repository。

### B. 共用连接函数和日志契约

6. `scan credential emits bypass start and failed lifecycle logs`
   - 扫码来源失败时依次存在 discovery bypass、connect start、connect failed；
   - fields 包含 `transport=credential source=scan`；
   - failed 有 duration/error，日志不含完整凭证。
7. `manual credential uses same lifecycle with source manual`
   - 现有手动输入凭证路径仍通过；
   - fields 为 `source=manual`；
   - 不重复输出两个 failed 事件。
8. `scan success emits one success lifecycle and refreshes`
   - start/success 各一次，source=scan；设备列表刷新。

### C. 回归与静态检查

9. 运行：
   - `flutter test test/pairing_credential_ui_test.dart --timeout 3m`
   - `flutter test test/pairing_log_events_test.dart --timeout 3m`
   - 新增扫码路由测试文件（若有）`--timeout 3m`
   - `flutter test test/pairing_accept_ui_test.dart --timeout 3m`
   - `flutter test test/pairing_mdns_widget_test.dart --timeout 3m`
10. `flutter analyze` 无 issue。
11. `git diff --check` 通过；`git status --short` 仅改动允许范围和 `.workflow/`。

## 需决策点

遇到以下情况停止报告，不自行改变协议：

- 真实 Navigator 测试无法稳定复现扫码路由 pop 生命周期；
- 连接 Future 无法安全承载模态状态，需要改变 repository/FRB 签名；
- 需要修改 Rust、relay、mDNS 或凭证格式；
- 现有测试要求 SnackBar 与本任务结果对话框冲突，且无法迁移为新产品契约；
- 测试或构建单命令超过 3 分钟：立即停止并报告卡在哪里。

## 报告要求

- `.workflow/executor-report.md`：红-绿-蓝证据、逐条验收结果、实际命令与输出摘要、新增测试清单、改动文件；
- `.workflow/review-report.md`：独立复跑、范围/日志脱敏检查、PASS/FAIL；
- `.workflow/final-check.md`：build 最终逐条核对；
- agents 不提交、不合并、不推送。