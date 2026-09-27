# 最终检查：log-dir-discoverability

- task-id: `log-dir-discoverability`
- role: main-agent（最终检查）
- worktree: `/Users/alexc/Projects/CardMind/.worktrees/log-dir-discoverability`
- branch: `pipeline/log-dir-discoverability`
- 契约提交: `2d9478c214616dfb89d0e105b01c611635f03f80`
- 审查：round1 FAIL（A4 Linux 路径错）→ 修正 → round2 PASS

## 身份与范围 — 通过

- HEAD = 契约提交，branch 正确。
- 改动 5 个文件，全在契约允许范围：`AGENTS.md`、`lib/bridge/debug_log.dart`、`lib/pages/settings_page.dart`、`test/debug_log_test.dart`、`test/settings_page_test.dart`。
- `pubspec.lock` 干净；`macos/Runner/*.entitlements` 零改动；`pubspec.yaml` 零改动。
- 未触碰 `FileDebugSink` 写入逻辑、日志格式、脱敏规则。

## 主代理独立复现

| 项 | 命令 | 结果 |
|---|---|---|
| A1/A2 | `flutter test test/debug_log_test.dart` | +15 All tests passed，EXIT=0 |
| A3 | `flutter test test/settings_page_test.dart` | +9 All tests passed，EXIT=0 |
| A5 | `flutter analyze` | No issues found，EXIT=0 |

## 关键裁定：A4 从 FAIL 到 PASS

round1 审查给出 FAIL，理由是 `AGENTS.md` 的 Linux 日志路径写成 `~/.local/share/com.cardmind.v2/...`。审查方当时自标「置信度中等」。

**主代理亲自钉死了四层证据链**（不采信任何一方）：

1. `linux/CMakeLists.txt:10` → `set(APPLICATION_ID "com.cardmind.cardmind")`
2. `linux/runner/my_application.cc:143,146` → 该值传给 GTK：`g_set_prgname(APPLICATION_ID)` + `"application-id", APPLICATION_ID`
3. `path_provider_linux-2.2.1/lib/src/path_provider_linux.dart:49-51` → `Directory(path.join(xdg.dataHome.path, await _getId()))`
4. 同文件 `:97-101` → `_getId()` → `getApplicationId()` → FFI 调 `g_application_get_application_id`

结论：Linux 返回 `~/.local/share/com.cardmind.cardmind`。**审查方的 FAIL 成立。**

同时主代理独立核实了另两行**未被误改且正确**：

- Windows：`windows/runner/Runner.rc:92,98` → `CompanyName="com.cardmind"`、`ProductName="cardmind"`；`path_provider_windows:216-218` 拼成 `%APPDATA%\com.cardmind\cardmind` ✓
- macOS：entitlements 启用 sandbox → 容器路径 ✓

修正后 round2 复审逐行核对三行、补全 Linux 证据链至「高置信度」、确认 CRLF 保持，判 **A4 PASS**。

## 一个必须记录的流程事实

执行子代理在修正 A4 时首次调用因网关 520 中断（`provider_error`）。按项目 provider 策略「瞬时上游失败 → 同模型重试」，重试后成功。这不是代码或契约问题。

## 验收结论

| 验收 | 结果 | 证据 |
|---|---|---|
| A1 resolveLogDirectory 单元 | PASS | 注入临时 baseDirectory，断言 `<base>/logs` |
| A2 与 FileDebugSink.open 同源 | PASS | `p.isWithin(resolved, sink.path)` + `p.dirname(sink.path) == resolved.path`；读码确认 `open` 真调用 `resolveLogDirectory`（原内联拼接已删） |
| A3 设置页入口 widget | PASS | 注入假 resolver/opener，断言路径显示 + opener 调用一次 + 失败 SnackBar 含路径；测试不打开访达 |
| A4 AGENTS.md 记录真实路径 | PASS | 三行平台路径逐行核实；Linux 行经四层证据链钉死 |
| A5 回归绿 | PASS | analyze EXIT=0；全量 6 个失败为基线先存，与本改动零因果 |

## 未验证 / 遗留

1. **「设置页点击真的打开访达」未验证**：widget 测试注入假 opener，真实 `Process.run('open', …)` 分支不可达。需合并后用真实应用点一次验证。
2. **`_loadLogDirectory` 解析失败时 UI 永久停留「加载中…」**（`settings_page.dart:96-104` catch 后不设值）。契约未规定失败态，属轻微 UX wart，非阻塞。
3. **`revealLogDirectory` 在生产路径无调用点**：设置页自行组合 resolver+opener（因 UI 需 opener 异常触发 SnackBar，而 reveal 故意吞掉）。合理取舍，契约函数未被生产使用。
4. **`git_gate_hook_integration_test.dart` 全量失败**：基线先存，根因未定位。建议另开任务。
5. **GitNexus 不可用**：无 `.gitnexus/run.cjs`，未执行 impact analysis。
6. **rustup stable 工具链损坏**：本轮纯 Dart，未受影响；但会影响后续 Rust 任务，建议修。

## 合并决定

A1–A5 全部 PASS，round2 复审 PASS，无未解决的正确性缺陷。**批准合并到 main。**

```pipeline-evidence
task-id: log-dir-discoverability
role: main-agent-final-check
worktree: /Users/alexc/Projects/CardMind/.worktrees/log-dir-discoverability
branch: pipeline/log-dir-discoverability
head: 2d9478c214616dfb89d0e105b01c611635f03f80
acceptance: A1=pass; A2=pass; A3=pass; A4=pass; A5=pass
verdict: PASS
```