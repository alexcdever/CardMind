# Review Report — log-dir-discoverability

- **task-id**: `log-dir-discoverability`
- **role**: reviewer (independent, read-only)
- **worktree**: `/Users/alexc/Projects/CardMind/.worktrees/log-dir-discoverability`
- **branch**: `pipeline/log-dir-discoverability`
- **HEAD verified**: `2d9478c214616dfb89d0e105b01c611635f03f80` (= contract commit)
- **baseline reference worktree**: `/Users/alexc/Projects/CardMind` (branch `main`, HEAD `2d9478c2`, pairing + git_gate test files clean)
- 未执行 impact analysis（本仓库无 `.gitnexus/run.cjs`，工具不可用）。

---

## 1. 身份与范围核对 — PASS

| 检查 | 结果 |
|---|---|
| `git rev-parse --show-toplevel` | worktree 路径正确 |
| `git branch --show-current` | `pipeline/log-dir-discoverability` |
| `git rev-parse HEAD` | `2d9478c214616dfb89d0e105b01c611635f03f80` = 契约提交 ✓ |
| `git status --short` | 仅 5 个 tracked 文件 `M` + 未跟踪 `.pipeline/log-dir-discoverability/` |
| `git diff --name-only HEAD` | `AGENTS.md`, `lib/bridge/debug_log.dart`, `lib/pages/settings_page.dart`, `test/debug_log_test.dart`, `test/settings_page_test.dart` — 全部落在契约 §3 允许清单内 |
| `macos/Runner/Release.entitlements` + `DebugProfile.entitlements` | `git diff HEAD` 输出为空 → **零改动** ✓ |
| `pubspec.lock` | `git status --short pubspec.lock` 无输出；`git diff HEAD -- pubspec.lock` 无输出 → **干净** ✓（我跑了 `flutter analyze`，它触发了隐式 pub get，锁文件仍无变化） |
| `docs/` | 零改动（契约允许但不要求） |
| 越界检查 | 未触碰 `FileDebugSink` 写入逻辑/日志格式/脱敏规则/依赖版本。`debug_log.dart` 的改动仅是目录推导改为调用 `resolveLogDirectory`（契约要求的方向），文件写入、截断、串行队列逻辑逐字未变。 |

---

## 2. A1–A5 独立复现

环境：`PUB_HOSTED_URL=https://pub.flutter-io.cn`；Flutter 3.44.9 / Dart 3.12.2。dylib 前置产物存在（`build/native/macos/libcardmind_backend.dylib` 与 `rust-backend/target/release/libcardmind_backend.dylib`，均由执行方从主工作树复制，属 `.gitignore`）。

### A1 — PASS
`flutter test test/debug_log_test.dart` → `DL_EXIT=0`，`+15: All tests passed!`
关键输出：`00:00 +10: log directory resolution A1: resolveLogDirectory uses the injected base directory`
断言 `resolved.path == p.join(tempBase.path, 'logs')` 且 `startsWith(tempBase.path)`；全程只传 `baseDirectory:`，未触碰 `getApplicationSupportDirectory()`。

### A2 — PASS（且经代码核实「同源」为真，见 §3a）
`00:00 +11: log directory resolution A2: FileDebugSink.open writes under resolveLogDirectory`
断言含 `p.isWithin(resolved.path, sink.path)` **与** `p.dirname(sink.path) == resolved.path`。

### A3 — PASS
`flutter test test/settings_page_test.dart` → `SP_EXIT=0`，`+9: All tests passed!`
`00:01 +6: A3: log directory entry shows path and opens once on tap`
`00:01 +7: A3: open failure surfaces the path via SnackBar`
注入 seam 覆盖真实调用路径（见 §3e），测试未打开访达。

### A4 — FAIL（Linux 路径行有误；macOS / Windows 行经实测正确）
详见 §4。

### A5 — PASS（「6 个基线失败」主张经独立复现确认成立，详见 §5）
`flutter analyze` → `ANALYZE_EXIT=0`，`No issues found! (ran in 2.6s)`
全量 `flutter test` → `FULL_EXIT=1`，`+243 ~1 -6`。

---

## 3. 代码正确性审查

### a) A2 的「同源」是否真的成立 — **成立（读码确认，非看测试）**
`lib/bridge/debug_log.dart:210`：`final logsDir = await resolveLogDirectory(baseDirectory: baseDirectory);`
`FileDebugSink.open` 是**真正调用** `resolveLogDirectory`，原先内联的 `Directory('${base.path}${Platform.pathSeparator}logs')` 已被删除。两处在物理上是同一段代码，不存在两份推导。契约 A2 的设计意图达成。

### b) 路径拼接口径（`Platform.pathSeparator` vs `p.join`） — **无实际缺陷**
`resolveLogDirectory`（debug_log.dart:110）：`Directory('${base.path}${Platform.pathSeparator}logs')`。
- Windows：`Platform.pathSeparator == '\\'`，`base.path` 形如 `C:\Users\x\AppData\Roaming\com.cardmind\cardmind` → 拼接得 `...\cardmind\logs`，**正确**。
- macOS/Linux：分隔符 `/` → 正确。
- 边界：仅当 `base.path` 以分隔符结尾（如 `C:\`）时会产出 `C:\\logs`——Windows 容忍双反斜杠，且 `getApplicationSupportDirectory()` 从不对 app support 目录返回尾分隔符。**低风险**。
`p.join` 更符合惯例，但这是仓库既有写法（改动前 `FileDebugSink.open` 用的就是同一表达式），不是本次引入的问题。**判定：无跨平台隐患，记一条 style 观察即可。**

### c) 静默退化边界 — **发现一个轻微 UX 缺陷（非契约违反）**
- `settings_page.dart:96-104` `_loadLogDirectory()`：resolver 抛错时 `catch` 后 **不设** `_logDirectory`，副标题永久停留在 `'加载中…'`。即：解析失败 → UI 无限显示「加载中…」。执行方报告已如实记录（「解析失败静默：副标题保持加载中…」）。契约只要求「副标题显示解析出的路径（或「加载中…」）」，未规定解析失败态，故**不算契约违反**，但属轻微 UX wart。
- **空串路径**：设置页**不使用** `revealLogDirectory`，而是直接 `widget.logDirectoryResolver ?? resolveLogDirectory`（:100）——`resolveLogDirectory` 返回 `Directory`，永不返回空串。故 `_logDirectory` 只可能是 `null` 或非空路径，**空串在本路径不可达**，UI 不会出现空白条目。`_openLogDirectory()`（:108-109）另有 `path == null || path.isEmpty` 守卫。**空串 UI 行为正常。**
- 附带观察：`revealLogDirectory` 在生产代码中**无调用点**（仅测试引用），设置页自行组合 resolver+opener。原因合理——`revealLogDirectory` 故意吞掉 opener 异常，而 UI 需要该异常来触发 SnackBar。属可接受的设计取舍，但意味着 reveal 的吞异常行为在生产路径未被使用。

### d) opener 平台分派 — **正确**
- Windows：`explorer` + `checkExitCode = false`（注释：explorer 成功也可能返回 1）——处理正确。代价是 Windows 下真实失败不会触发 SnackBar，属已知取舍。
- macOS：`open`；Linux：`xdg-open`。
- `xdg-open` 不存在时：`Process.run` 抛 `ProcessException` → 由 `_openLogDirectory`（:113-119）catch → SnackBar 显示路径。**被正确捕获。**

### e) 测试 seam 深度 — **足够**
- **A1**：断言 `resolved.path == p.join(base,'logs')`。若有人把 `resolveLogDirectory` 改成返回 `<base>`（少 `logs`），`resolved.path` 将等于 `tempBase.path` ≠ `p.join(tempBase.path,'logs')` → **A1 会红**。✓
- **A2**：反例推演——若 `FileDebugSink.open` 改用 `<base>/log`（单数），`resolved.path = <base>/logs`，`sink.path = <base>/log/cardmind.log`，则 `p.dirname(sink.path) == <base>/log ≠ <base>/logs` → **A2 会红**。`dirname` 等式是关键强断言。✓
- **A3**：`SettingsPage` 构造时显式传入假 `logDirectoryResolver` 与假 `logDirectoryOpener`；`_loadLogDirectory`/`_openLogDirectory` 里的 `widget.X ?? realImpl` 恒解析到注入实现，真实 `Process.run('open', ...)` 分支**不可达**。✓ 测试不打开访达。
- `revealLogDirectory` 三例覆盖成功 / opener 抛错 / resolver 抛错，覆盖主要失效模式；resolver-抛错例还断言 `opener` **不被调用**（`fail(...)`）。✓
- 缺口（不影响判定）：A3 未覆盖「resolver 抛错 → UI 显示」这一组合（即 §3c 的「加载中…」永生），故该 UX wart 无测试守卫。

### f) 新增未处理异常路径 — **无**
`resolveLogDirectory` 不包 try/catch（由调用方处理）：`FileDebugSink.open` 的 try/catch（:209-220）覆盖其调用并返回 `null`；`_loadLogDirectory` 有 try/catch；`_openLogDirectory` 有 try/catch。无新增未处理异常路径。✓

---

## 4. 文档准确性（A4）

`AGENTS.md` 新增「## 日志目录（排查必读）」，共 36 行。

| 项 | 判定 | 证据 |
|---|---|---|
| macOS 容器路径 | **正确** | `ls` 实测：`~/Library/Containers/com.cardmind.v2/Data/Library/Application Support/com.cardmind.v2/logs/cardmind.log` 存在，mtime `Sep 28 07:23:10 2026`（活） |
| macOS「两份同名日志」坑 | **正确** | 非容器 `~/Library/Application Support/com.cardmind.v2/logs/cardmind.log` 存在，mtime `Sep 28 05:19:30 2026`（陈旧）。文档对「容器内=活、非容器=陈旧」的刻画与时间戳完全吻合；bundle id `com.cardmind.v2` 经 `macos/Runner/Configs/AppInfo.xcconfig:11` 确认 |
| Windows 路径 `%APPDATA%\com.cardmind\cardmind\logs\cardmind.log` | **正确** | `path_provider_windows` 的 `getApplicationSupportPath()` = `_createApplicationSubdirectory(RoamingAppData)`；`windows/runner/Runner.rc`：`CompanyName = "com.cardmind"`、`ProductName = "cardmind"` → 子目录正是 `com.cardmind\cardmind` |
| `lsof -p <pid> \| grep cardmind.log` | **可用** | 实测在本机 `lsof -p $$` 语法有效；无匹配时 `grep_exit=1`（正常） |
| 「不要改 entitlements」说明 | **已包含** | 文档末段明写「macOS 上不要修改 entitlements 来『修正』路径——沙箱是安全决策」 |
| **Linux 路径 `~/.local/share/com.cardmind.v2/logs/cardmind.log`** | **有误（FAIL 项）** | `linux/CMakeLists.txt:10` 为 `set(APPLICATION_ID "com.cardmind.cardmind")`；`path_provider_linux` 的 app-support 目录取自 Linux **application id**，而非 macOS bundle id。故 Linux 真实路径应为 `~/.local/share/com.cardmind.cardmind/...`，文档写的 `com.cardmind.v2` **与项目自身 Linux APPLICATION_ID 不符**。 |

补充：我未能完整读到 `path_provider_linux` 的 id 解析函数体（grep 未返回该段），故 Linux 结论为**中等置信度**——但 `APPLICATION_ID = com.cardmind.cardmind` 与文档 `com.cardmind.v2` 的冲突是明确的、项目内的硬证据。Linux 非当前出货平台（AGENTS.md：Windows 为主，Linux 保留），影响面小。

**A4 判定：FAIL**（仅 Linux 行；macOS 这一核心项与 Windows 行均实测正确）。

---

## 5. 「6 个基线失败」主张的独立核实 — **主张成立**

这是本次审查的重点。我未采信执行方结论，独立跑了主工作树。

**主工作树（`/Users/alexc/Projects/CardMind`，branch `main`，HEAD `2d9478c2`，pairing/git_gate 测试文件 `git status` 干净）：**

```
=== MAIN BASELINE FULL ===
00:28 +236 ~1 -6: Some tests failed.
Failing tests:
  .../test/git_gate_hook_integration_test.dart: 19 安装/复制 hook 后真实 git commit 能通过 Dart 入口被调用
  .../test/git_gate_hook_integration_test.dart: 20 真实 git push 证明 pre-push 读取 stdin 并通过 Dart 入口
  .../test/git_gate_hook_integration_test.dart: 21 SKIP_LOCAL_CHECK=1 两个 Hook 都可跳过
  .../test/git_gate_hook_integration_test.dart: 22 Dart gate 非零时 commit/push 确实被 Git 阻止
  ... and 2 more
```

**worktree：**

```
===== WORKTREE FULL =====
00:31 +243 ~1 -6: Some tests failed.
Failing tests: 同上 4 个 git_gate + "... and 2 more"
```

`flutter test` 的失败清单只打印前 4 条，故我对两个 pairing 用例做了**单文件独立复现**，在主工作树与 worktree 两侧各跑一次：

| 测试 | 主工作树（未改动） | worktree |
|---|---|---|
| `pairing_credential_repository_test.dart` → `display credential survives real FRB roundtrip` | **FAIL** (`+3 -1`) | **FAIL** (`+3 -1`) |
| `pairing_repository_test.dart` → `repository pair flow pairs two devices and syncs notes` | **FAIL** (`+1 -1`) | **FAIL** (`+1 -1`) |

**结论：** 6 个失败 = 4 个 `git_gate_hook_integration_test`（19/20/21/22）+ 2 个 pairing 集成用例，**两侧逐条相同**，两个 pairing 失败在未改动的主工作树上独立复现。执行方「6 个全部基线先存、失败集合逐条相同」的主张**成立**，不构成本改动的回归。

关于主代理上一轮观察到的 `+238 ~1 -4`：我本次在干净主工作树实测为 `+236 ~1 -6`，且两个 pairing 用例单跑均失败。该 -4 观察未复现——很可能是当时主工作树缺 dylib 前置、或运行中途差异导致的**部分用例未执行**（fail-fast/跳过）而非「不存在」。以本次实测为准：**基线先存 6 个**。

绝对通过计数在执行方基线（`+240`）与我本次主工作树（`+236`）之间有差异，但 worktree 侧 `+243` 与执行方一致，且**判据是失败集合而非通过数**。通过数波动来自全量并发/调度，不影响结论。

---

## 6. 契约合规 — PASS

逐项对照契约 §3 禁止项：`macos/Runner/*.entitlements` 零改动 ✓；`FileDebugSink` 写入逻辑未改 ✓；日志格式/脱敏规则未改 ✓；无依赖变更（`pubspec.lock` 干净）✓。改动全部落在允许清单内。

---

## 7. 结论与建议

**核心交付（macOS 日志可发现性）经独立验证是正确且有效的：** A2「同源」在代码层为真，A1/A2/A3 测试有足够 seam 深度（反例推演均能变红），macOS/Windows 文档路径实测正确，`lsof` 排查命令可用，entitlements 未动，回归无新增失败。

**唯一未达标项是 A4 的 Linux 路径行**（`com.cardmind.v2` 应为 `com.cardmind.cardmind`，依据 `linux/CMakeLists.txt:10`）。这是一处一行文档修正，不影响 macOS 主目标。

次要非阻塞观察：
1. `_loadLogDirectory` resolver 失败时 UI 永久停留「加载中…」（轻微 UX wart，无测试守卫）。
2. `revealLogDirectory` 在生产代码无调用点，设置页自行组合 resolver+opener（合理取舍，但契约函数未被生产路径使用）。
3. 路径拼接用 `Platform.pathSeparator` 而非 `p.join`——无实际缺陷，仅 style。

**「设置页点击真的打开访达」属 UI 实机行为，widget 测试（注入假 opener）无法证明——归主代理实机验证。**

```pipeline-evidence
task-id: log-dir-discoverability
role: reviewer
worktree: /Users/alexc/Projects/CardMind/.worktrees/log-dir-discoverability
branch: pipeline/log-dir-discoverability
head: 2d9478c214616dfb89d0e105b01c611635f03f80
acceptance: A1=pass; A2=pass; A3=pass; A4=fail; A5=pass
verdict: FAIL
```