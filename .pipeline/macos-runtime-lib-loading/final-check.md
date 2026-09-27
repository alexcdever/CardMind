# 最终检查：macos-runtime-lib-loading

- task-id: `macos-runtime-lib-loading`
- role: main-agent（最终检查）
- 实现 worktree: `/Users/alexc/Projects/CardMind/.worktrees/macos-runtime-lib-loading`
- branch: `pipeline/macos-runtime-lib-loading`
- 契约提交: `ad6fc22ab31564e2e58e335982d834cac1e090ce`
- 审查 verdict: PASS（见 `review-report.md`）

## A1 — PASS（执行方 + 审查方独立重跑）

`flutter test test/rust_library_loader_test.dart` → 退出码 0，`+7: All tests passed!`
7 用例覆盖三平台候选路径 + 三个「不存在」返回 null + 未知平台不探测。

## A2 — PASS（执行方 + 审查方独立重跑）

- `flutter analyze` → 退出码 0，`No issues found!`
- `flutter test` → 退出码 0，`+242 ~1: All tests passed!`（1 跳过为 Windows-only）

环境前置：全量测试中若干用例直接调 `RustLib.init()`，需要 worktree 内
`rust-backend/target/release/libcardmind_backend.dylib`（被 gitignore，非提交内容）。
执行方从主工作树复制该文件；审查方独立核实其存在且未自行复制。

## A3 — PASS（主代理亲测，重新构建产物）

构建（worktree 内）：

```bash
flutter build macos --release --build-name 0.1.0 --build-number 1
# BUILD_EXIT=0 → build/macos/Build/Products/Release/cardmind.app (77.9MB)
```

产物核对：

```
Contents/Frameworks/libcardmind_backend.dylib   26199400 bytes  EXISTS
Contents/MacOS/cardmind                          990416 bytes  EXISTS
```

安装：旧包移至 `/tmp/cardmind-app-backup-old`（未删除），新产物 `cp -a` 到 `/Applications/cardmind.app`。

**决定性验证**（cwd = `/tmp`，非项目根，直接执行二进制并捕获 stdout）：

```
flutter: [cardmind:log] 2026-09-27T21:20:31.828107Z platform=macos event=startup.rustlib stage=startup action=start
flutter: [cardmind:log] 2026-09-27T21:20:31.830859Z platform=macos event=startup.rustlib stage=startup action=success
flutter: [cardmind:log] 2026-09-27T21:20:31.854952Z platform=macos event=startup.sync_service stage=startup action=success
flutter: [cardmind:log] 2026-09-27T21:20:31.855054Z platform=macos event=startup.bridge stage=startup action=success
flutter: [cardmind:log] 2026-09-27T21:20:31.855482Z platform=macos event=receiver.start stage=receiver action=success
```

对比修复前同条件下为 `startup.rustlib ... action=failed`（`Failed to load dynamic library
'cardmind_backend.framework/cardmind_backend'`）。**A3 PASS。**

## A4 — PASS（主代理亲测，Finder 语义启动）

```bash
cd /tmp && open -a /Applications/cardmind.app   # exit=0
```

- 进程存活：PID 56039，持续运行 >2 分钟
- LaunchServices 应用列表包含 `cardmind`
- AX 树：`AXWindow "cardmind"` @0,0 972×768，含 `AXGroup`（焦点视图）、三个标题栏按钮、
  `AXStaticText = "cardmind"`
- **未出现** `启动失败，请重试` 文案
- **未出现** `重试` 按钮
- 统一日志中本次启动无 `dlopen` / `dyld` / `Failed to load` 记录
- 持久日志中失败记录最大时间戳为 `20:55:33`，早于本次启动（`21:20` 之后）

**A4 PASS。**

## 已知残留与证据边界

1. **文件日志 sink 未增长（未解释，非验收项）**：`open -a` 启动后，持久日志文件
   `~/Library/Application Support/com.cardmind.v2/logs/cardmind.log` 行数未增加，而 stdout
   有完整启动序列。`initializeFileLogging` 是 fire-and-forget，失败静默降级为 debugPrint——
   可能是 sink 附着失败。此项与本次修复无关（修复前后同样存在），但**未定位根因**，
   作为已知残留记录，不阻塞验收。

2. **Windows / Linux 无实机证据**：仅有纯单元验证（`test/rust_library_loader_test.dart`）。
   两平台候选路径未在真实产物上核对。macOS 有真实 `.app` 核对。

3. **seam 太浅（审查方发现）**：`lib/main.dart` 的 `initializeCardMindBackend` 本身无测试覆盖。
   若有人把 `rustLib.init` 的 `externalLibrary` 参数去掉，7 个单测仍全绿而 bug 复现。
   建议后续补一个能观测 `RustLib.init` 实参的测试。

4. **GitNexus 不可用**：本仓库无 `.gitnexus/run.cjs`，未执行 impact analysis。

5. **旧包备份**：`/tmp/cardmind-app-backup-old` 保留，未删除。

## 验收结论

| 验收 | 结果 | 证据 |
|---|---|---|
| A1 loader 纯函数按平台 | PASS | 执行方 + 审查方独立重跑，7/7 |
| A2 既有套件全绿 | PASS | analyze 0；test +242 ~1 |
| A3 打包应用脱离项目根启动 | PASS | cwd=/tmp 下 rustlib action=success |
| A4 Finder 语义启动无失败页 | PASS | 窗口渲染正常，无失败文案/重试按钮 |

```pipeline-evidence
task-id: macos-runtime-lib-loading
role: main-agent-final-check
worktree: /Users/alexc/Projects/CardMind/.worktrees/macos-runtime-lib-loading
branch: pipeline/macos-runtime-lib-loading
head: ad6fc22ab31564e2e58e335982d834cac1e090ce
acceptance: A1=pass; A2=pass; A3=pass; A4=pass
verdict: PASS
```