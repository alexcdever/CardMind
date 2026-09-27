# 最终检查：pairing-credential-ip

- task-id: `pairing-credential-ip`
- role: main-agent（最终检查）
- worktree: `/Users/alexc/Projects/CardMind/.worktrees/pairing-credential-ip`
- branch: `pipeline/pairing-credential-ip`
- 契约提交: `8b6ff7013017050fa552ccd222ee0a98cb4793b8`
- 审查 verdict: PASS（见 `review-report.md`）

## 身份与范围 — 通过

- HEAD = `8b6ff7013017050fa552ccd222ee0a98cb4793b8`（= 契约提交），branch 正确。
- 10 个已跟踪文件改动 + `.pipeline/` 证据，全在契约 §4 允许范围。
- **`pubspec.lock` 干净**（上一轮越界改动已还原）。
- 未触碰 `lib/pages/devices_page.dart`、relay 策略、entitlements、版本号、发布工作流。

## 主代理独立复现（不采信子代理结论）

| 项 | 命令 | 结果 |
|---|---|---|
| A1–A4 | `cargo test --test pairing_credential_test` | **20 passed / 0 failed，EXIT=0** |
| A5 Rust | `cargo test`（全量 16 二进制） | **全 ok / 0 failed，EXIT=0** |
| A5 analyze | `flutter analyze` | **No issues found，EXIT=0** |
| A5 Dart | `flutter test`（全量） | **+238 ~1 -4，EXIT=1** |
| 基线对照 | 主工作树 `flutter test`（全量） | **+238 ~1 -4，EXIT=1（同 4 例）** |

## 关键结论：A5 的 4 个失败是基线先存

主代理亲自在**未改动的基线主工作树**（`main`，HEAD 同为 `8b6ff701`，`test/git_gate_hook_integration_test.dart` 干净 0 处改动）跑全量 `flutter test`：

```
00:32 +238 ~1 -4: Some tests failed.
Failing tests:
  test/git_gate_hook_integration_test.dart: 19 / 20 / 21 / 22
BASELINE_FULL_EXIT=1
```

与 worktree 的 `+238 ~1 -4` **逐项一致**（同样的 4 个用例）。而单独跑该文件时，**两边都 4/4 通过**（`+4: All tests passed!`，EXIT=0）。

因此该失败是 `git_gate_hook_integration_test.dart` 在**并发全量运行**下的既有环境问题（具体根因未定位，倾向并发 fork/exec 资源受限），**与本任务改动零因果关系**。按契约 §5 A5「必须与基线一致或更好，不得新增失败」→ **A5 = PASS**。

### 对两份报告矛盾的裁定

- 执行报告称 `+238 ~1 -4`：**全量范围，属实**。
- 审查报告称 `+242 ~1: All tests passed`：**单文件范围，属实**。
- 两者都对，只是命令范围不同。审查方"纠正执行方失实"的说法本身也不准确——执行方没有编造。
- 执行方与审查方对根因的猜测（PATH / 并发）均**未证实**，本报告不采信，只记录现象。

## A4 seam 核实 — 够深

主代理读码确认：

- seam = 新增 `SyncService::pairing_target_for_credential`，是生产入口 `begin_pairing_connect_with_credential` 的**唯一实际调用方**（非死代码）。
- 断言为 `assert_eq!(target.ips, confirmer.local_addrs())`（列表相等 + 顺序），**非宽松断言**；另有端到端直连用例兜底。
- 本环境 `local_addrs()` 非空 → 退回 `vec![]` 立即变红。

## 接线核实 — 完整

主代理读码确认 `rust-backend/src/sync.rs`：

- `begin_pairing_credential` 调用 `encode_credential_v2(..., &self.local_addrs())` —— 生成路径确实内嵌本机 IP。
- 凭证常量 `CREDENTIAL_VERSION_V1=1` / `CREDENTIAL_VERSION_V2=2` 分离；`parse_credential` 按 `[2]` 版本分派。
- 审查方独立 `grep "ips: vec!\[\]" src/` 无输出 → 硬编码空 IP 已彻底移除。

## 验收结论

| 验收 | 结果 | 证据 |
|---|---|---|
| A1 v1 仍可解析 | PASS | 20/20 含 `credential_v1_has_exact_canonical_layout_and_roundtrips` |
| A2 v2 往返+签名含 IP | PASS | 4 个 v2 用例全过，含逐字节篡改拒签 |
| A3 生成含本机地址 | PASS | `generated_credential_contains_local_addrs`，严格相等 |
| A4 连接用内嵌 IP | PASS | seam + 端到端，断言非宽松 |
| A5 回归绿 | PASS | 与基线逐项一致，零新增失败 |
| A6 真机扫码 | **未验证** | 需物理手机；由用户执行 |

## 未验证 / 遗留

1. **A6 未验证**：需真实手机 + 同局域网扫码。代码路径与单元/端到端均已验证，但真实设备链路未跑。不得声称 A6 通过。
2. **`git_gate_hook_integration_test.dart` 全量失败**：基线先存，非本任务引入；根因未定位。建议另开任务。
3. **GitNexus 不可用**：无 `.gitnexus/run.cjs`，未执行 impact analysis。
4. **rustup stable 工具链损坏**：`~/.rustup/toolchains/stable-aarch64-apple-darwin/bin` 缺失，本任务全部 Rust 命令用 Homebrew Rust 1.98.1 完成。这是环境问题，与本改动无关，但会影响后续任务——建议修工具链。

## 合并决定

主代理独立复现全部关键验收，A1–A5 全部 PASS，无未解决的正确性缺陷。**批准合并到 main。**

```pipeline-evidence
task-id: pairing-credential-ip
role: main-agent-final-check
worktree: /Users/alexc/Projects/CardMind/.worktrees/pairing-credential-ip
branch: pipeline/pairing-credential-ip
head: 8b6ff7013017050fa552ccd222ee0a98cb4793b8
acceptance: A1=pass; A2=pass; A3=pass; A4=pass; A5=pass; A6=unverified
verdict: PASS
```