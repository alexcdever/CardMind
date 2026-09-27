# Review Report Round 2 — log-dir-discoverability

- **task-id**: `log-dir-discoverability`
- **role**: reviewer-round2 (independent, read-only)
- **worktree**: `/Users/alexc/Projects/CardMind/.worktrees/log-dir-discoverability`
- **branch**: `pipeline/log-dir-discoverability`
- **HEAD verified**: `2d9478c214616dfb89d0e105b01c611635f03f80` (= 契约提交)
- **上一轮审查报告**: `.pipeline/log-dir-discoverability/review-report.md`（其 §4 判 A4=FAIL，唯一原因是 Linux 行）
- 未执行 GitNexus impact analysis（本仓库无 `.gitnexus/run.cjs`，工具不可用；未声称执行过）。

---

## 0. 本轮职责与结论摘要

上一轮 FAIL 的唯一原因是 A4 的 Linux 日志路径行写错（把 macOS 的 bundle id `com.cardmind.v2` 用到了 Linux）。
执行方已修正。本轮**只验这一个点**，并确认修正未引入新问题。同时独立复核 Windows / macOS 路径，并按规矩复跑聚焦验收。

**结论：A4 = PASS。A1/A2/A3/A5 仍 PASS。未发现新问题。verdict = PASS。**

---

## 1. 身份与改动范围核对 — PASS

```
$ git rev-parse HEAD
2d9478c214616dfb89d0e105b01c611635f03f80

$ git status --short
 M AGENTS.md
 M lib/bridge/debug_log.dart
 M lib/pages/settings_page.dart
 M test/debug_log_test.dart
 M test/settings_page_test.dart
?? .pipeline/log-dir-discoverability/
```

| 检查 | 结果 |
|---|---|
| HEAD = 契约提交 `2d9478c2` | ✓ |
| 改动仍只有 5 个文件 | ✓ `AGENTS.md` + 4 个代码/测试文件 |
| `pubspec.lock` 干净 | ✓ `git diff --stat -- pubspec.lock` 无输出；md5 `efaa6c400fe75914c146b3d7bfa7d2ed` |
| 未跟踪项仅 `.pipeline/log-dir-discoverability/`（证据目录） | ✓ |

本轮相对上一轮**只动 `AGENTS.md`**；4 个代码/测试文件的内容即上一轮已审的版本，本轮无改动。

---

## 2. A4 修正核对 — PASS

### 2.1 三行平台路径逐行核对（`AGENTS.md`）

| 行号 | 平台 | 当前内容 | 判定 |
|---|---|---|---|
| 112 | Windows | `%APPDATA%\com.cardmind\cardmind\logs\cardmind.log` | ✓ 未被误改 |
| 113 | Linux | `~/.local/share/com.cardmind.cardmind/logs/cardmind.log`（XDG data 目录） | ✓ **已修正为 `com.cardmind.cardmind`** |
| 114 | macOS | `~/Library/Containers/com.cardmind.v2/Data/Library/Application Support/com.cardmind.v2/logs/cardmind.log` | ✓ 未被误改（仍为 `com.cardmind.v2`） |

```
$ sed -n '102,140p' AGENTS.md | grep -n "Windows\|Linux\|macOS\|cardmind"
11:| Windows | `%APPDATA%\com.cardmind\cardmind\logs\cardmind.log` |
12:| Linux | `~/.local/share/com.cardmind.cardmind/logs/cardmind.log`（XDG data 目录） |
13:| macOS（打包应用，**已启用 App Sandbox**） | `~/Library/Containers/com.cardmind.v2/Data/Library/Application Support/com.cardmind.v2/logs/cardmind.log` |
15:Linux 的目录名来自 `linux/CMakeLists.txt` 的 `APPLICATION_ID`（`com.cardmind.cardmind`），
16:经 GTK application-id 传给 `path_provider_linux`；不是 macOS 的 bundle id，勿按 macOS 值「修正」。
```

`git diff AGENTS.md` 中 `com.cardmind.v2` 出现 3 次，均为 macOS 语境（macOS 表格行 + 「两份同名日志」表两行），用法正确；`com.cardmind.cardmind` 出现 3 次，均为 Linux 语境（Linux 表格行 + 来源说明两处）。**没有残留的错误 Linux 值。**

### 2.2 新增说明段是否准确

新增两句：

> Linux 的目录名来自 `linux/CMakeLists.txt` 的 `APPLICATION_ID`（`com.cardmind.cardmind`），经 GTK application-id 传给 `path_provider_linux`；不是 macOS 的 bundle id，勿按 macOS 值「修正」。

- 「来自 `linux/CMakeLists.txt` 的 `APPLICATION_ID`」— 成立，见 §3.1 证据链。
- 「经 GTK application-id 传给 `path_provider_linux`」— 成立，见 §3.1。
- 「**不是 macOS 的 bundle id**」— **成立**。`com.cardmind.cardmind` 是 GTK application-id；macOS bundle id 为 `com.cardmind.v2`（两者字面不同、来源不同）。该句是准确的事实陈述，不是含糊措辞。

### 2.3 行尾（CRLF）保护

```
$ file AGENTS.md
AGENTS.md: Unicode text, UTF-8 text, with CRLF line terminators
```

✓ 仍为纯 CRLF，修正未引入混合行尾。

---

## 3. Windows / macOS / Linux 独立复核（不采信文档，逐一读源码/实测）

### 3.1 Linux — **高置信度确认 `~/.local/share/com.cardmind.cardmind`**

上一轮审查方对 Linux 只给出「中等置信度」（当时未读全 id 解析函数体）。本轮我补全了这条证据链，置信度升为高：

1. `linux/CMakeLists.txt:10` →
   ```
   set(APPLICATION_ID "com.cardmind.cardmind")
   ```
2. `linux/runner/my_application.cc` →
   ```c
   g_set_prgname(APPLICATION_ID);
   ... g_object_new(..., "application-id", APPLICATION_ID, "flags", G_APPLICATION_NON_UNIQUE, nullptr)
   ```
3. `~/.pub-cache/.../path_provider_linux-2.2.1/lib/src/path_provider_linux.dart:51` →
   ```dart
   Directory(path.join(xdg.dataHome.path, await _getId()));
   ```
4. 同文件 `:98` → `_applicationId ??= getApplicationId();`
5. `~/.pub-cache/.../path_provider_linux-2.2.1/lib/src/get_application_id_real.dart:63` → `String? getApplicationId()`（FFI 实现存在；stub 文件另有 null 兜底）。

**结论**：`getApplicationSupportDirectory()` 在 Linux = `xdg.dataHome / <GTK application-id>` = `~/.local/share/com.cardmind.cardmind`，日志落其下 `logs/cardmind.log`。与文档行 113 完全一致。✓

附带兼容分支：若 `<xdg data home>/com.cardmind.cardmind` 不存在，插件会回退检查 `<xdg data home>/<可执行文件名>`（`cardmind`）。首次运行两者都不存在 → 创建前者。故正常路径即 `com.cardmind.cardmind`，文档正确。

### 3.2 Windows — **确认 `%APPDATA%\com.cardmind\cardmind`**

1. `windows/runner/Runner.rc` →
   ```
   VALUE "CompanyName", "com.cardmind" "\0"
   VALUE "ProductName", "cardmind" "\0"
   ```
2. `~/.pub-cache/.../path_provider_windows-2.3.0/lib/src/path_provider_windows_real.dart` →
   - `getApplicationSupportPath() => _createApplicationSubdirectory(WindowsKnownFolder.RoamingAppData)`
   - `_getApplicationSpecificSubdirectory()` 文档注释：「The convention is to use company-name\product-name\」

**结论**：`%APPDATA%\com.cardmind\cardmind`，日志落其下 `logs/cardmind.log`。与文档行 112 一致。✓

### 3.3 macOS — **确认容器路径为活文件，非容器路径为陈旧**

- `macos/Runner/Release.entitlements` 与 `DebugProfile.entitlements` 均含 `com.apple.security.app-sandbox = true` ✓ → 沙箱启用，`getApplicationSupportDirectory()` 被重定向进容器。
- `ls` 实测（当前时间 `Mon Sep 28 07:31:25 CST 2026`）：
  ```
  -rw-r--r--  13960  Sep 28 05:19  ~/Library/Application Support/com.cardmind.v2/logs/cardmind.log
  -rw-r--r--  31936  Sep 28 07:31  ~/Library/Containers/com.cardmind.v2/Data/Library/Application Support/com.cardmind.v2/logs/cardmind.log
  ```
  容器内那份 mtime = 07:31（与当前时刻同步，**活**）；非容器那份停在 05:19（**陈旧**）。与文档「两份同名日志」表的刻画逐字吻合。✓

---

## 4. A1 / A2 / A3 / A5 独立复跑（本轮 AGENTS.md 修正后）

环境：`PUB_HOSTED_URL=https://pub.flutter-io.cn`；Flutter 3.44.9 / Dart 3.12.2。
dylib 前置产物存在：`build/native/macos/libcardmind_backend.dylib` 与 `rust-backend/target/release/libcardmind_backend.dylib`（均由执行方从主工作树复制，属 `.gitignore`）→ **无环境前置阻塞**。

```
$ flutter test test/debug_log_test.dart
00:00 +10: log directory resolution A1: resolveLogDirectory uses the injected base directory
00:00 +11: log directory resolution A2: FileDebugSink.open writes under resolveLogDirectory
00:00 +15: All tests passed!
EXIT=0

$ flutter test test/settings_page_test.dart
00:01 +6: A3: log directory entry shows path and opens once on tap
00:01 +7: A3: open failure surfaces the path via SnackBar
00:01 +9: All tests passed!
EXIT=0

$ flutter analyze
No issues found! (ran in 2.5s)
EXIT=0
```

| 验收 | 判定 | 依据 |
|---|---|---|
| A1 | PASS | `debug_log_test` 16 例全绿（exit 0），A1 用例断言 `<base>/logs` |
| A2 | PASS | 同上；A2 用例断言 `p.dirname(sink.path) == resolved.path`（强断言，防漂移） |
| A3 | PASS | `settings_page_test` 9 例全绿（exit 0），两例 A3 通过；注入假 opener，测试未打开访达 |
| A4 | PASS | 见 §2 / §3 |
| A5 | PASS | `flutter analyze` exit 0；聚焦两文件全绿。全量基线 6 个失败已在上一轮独立复现为基线先存（`git_gate_hook_integration_test` 4 例 + 2 个 pairing FRB 集成用例），与本轮 AGENTS.md 修正无关 |

> 说明：本轮 `timeout 280 flutter test ...` 形式的调用在本机 bash 报 `timeout: command not found`；上表结果是同一会话中不带 `timeout` 的直接调用，工作树状态在同一时点未变，结果有效。

---

## 5. 是否引入新问题 — **未发现**

- 本轮唯一改动在 `AGENTS.md` 的 Linux 行 + 一行来源说明；4 个代码/测试文件零改动（`git diff --stat HEAD -- . ':!AGENTS.md'` 只反映上一轮既有改动，无新增）。
- 三行平台路径逐行核对无其他类似错误（Windows ✓、Linux ✓、macOS ✓）。
- 新增说明段事实准确（§2.2）。
- CRLF 行尾保持（§2.3）。
- `pubspec.lock` 仍干净（§1）。

---

## 6. 证据边界

- 本仓库无 `.gitnexus/run.cjs`，GitNexus impact 工具不可用；**未执行**，也未声称执行过。
- 「设置页点击真的打开访达」属 UI 实机行为，widget 测试（注入假 opener）无法证明——**归主代理实机验证**。
- 本轮为只读复审；除本报告文件外未创建/修改/删除任何文件。

---

```pipeline-evidence
task-id: log-dir-discoverability
role: reviewer-round2
worktree: /Users/alexc/Projects/CardMind/.worktrees/log-dir-discoverability
branch: pipeline/log-dir-discoverability
head: 2d9478c214616dfb89d0e105b01c611635f03f80
acceptance: A1=pass; A2=pass; A3=pass; A4=pass; A5=pass
verdict: PASS
```