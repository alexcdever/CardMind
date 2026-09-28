# 最终检查：device-name-hostname

- task-id: `device-name-hostname`
- role: main-agent（最终检查）
- worktree: `/Users/alexc/Projects/CardMind/.worktrees/device-name-hostname`
- branch: `pipeline/device-name-hostname`
- 契约提交: `9b2574fbab7292dd598acb04302a4ca7009a0494`
- 审查 verdict: PASS（见 `review-report.md`）

## 身份与范围 — 通过

- HEAD = 契约提交，branch 正确。
- 改动 3 个文件：`rust-backend/src/sync.rs`、`rust-backend/Cargo.toml`、新增 `rust-backend/tests/device_name_test.rs`。
- `lib/`（含 `lib/src/rust/`）**零改动** —— 主代理读 `git status --short` 确认。
- `pubspec.lock` 干净。
- `Cargo.lock` 唯一变化：`cardmind-backend` 的 `dependencies` 列表加一行 `"libc"`；`libc` 包条目版本 `0.2.186`、checksum **零变化**（主代理读 `git diff` 确认）。

## 根因（主代理诊断，已固化在契约）

`default_device_name()` 只读两个环境变量：

```rust
std::env::var("COMPUTERNAME")                          // Windows 专有
    .or_else(|_| std::env::var("HOSTNAME"))            // shell 变量
    .unwrap_or_else(|_| "CardMind Device".to_string())
```

主代理实测 Finder 启动的 GUI 进程环境（`ps eww -p <pid>` 白名单过滤）：

```
USER=alexc
LOGNAME=alexc
HOME=/Users/alexc
SHELL=/bin/zsh
```

**既无 `COMPUTERNAME` 也无 `HOSTNAME`** → 必然落到兜底串。而系统真实主机名 `Alexc-MBA` 从未被读取（`scutil --get ComputerName` / `gethostname(3)` 均可取到）。

## 修复

新增可测纯函数，`default_device_name()` 变为薄入口：

```rust
fn default_device_name() -> String {
    default_device_name_with(std::env::var("COMPUTERNAME").ok(), detect_hostname())
}
```

- `detect_hostname()`：`#[cfg(unix)]` 走 `libc::gethostname`（256 缓冲 + NUL 截断 + UTF-8 校验）；`#[cfg(not(unix))]` 返回 `None`
- `normalize_hostname()`：去域名后缀（`Alexc-MBA.local` → `Alexc-MBA`）；IP 形式原样返回，不截成 `192`；空值/截断后为空 → `None`
- 命名格式：**只取主机名，不加 `user@` 前缀**（契约裁定）

## 主代理独立核验

| 项 | 结果 |
|---|---|
| 身份与 diff | HEAD = 契约提交；`lib/` 零改动；`Cargo.lock` 仅 deps 列表 +1 行 |
| 审查结论 | PASS，A1–A4 全绿 |
| Windows 编译推理 | `#[cfg(not(unix))]` 双分支同名同签名；`sync.rs` 无 `use libc`（全限定路径），cfg 在名字解析前移除分支 |
| A1 IP 边界 | 审查确认 `assert_eq!(... "192.168.1.5")` **且** `assert_ne!(..., Some("192"))` |
| A3 独立性 | 审查在本 shell（无 `HOSTNAME`/`COMPUTERNAME`）跑通 → 若实现退回环境变量版必红，非假通过 |

## 一个未能完成的验证（证据边界）

**Windows 编译未实测**：本机只装了 `aarch64-apple-darwin` 目标，未做 Windows 交叉编译。`#[cfg(not(unix))]` 能阻止 `libc::gethostname` 被解析，这是基于 cfg 语义的静态推理，不是编译证据。审查方已如实标注。

## 关于 `flutter test` 的基线失败

执行方与审查方均报 `+243 ~1 -6`，与主工作树基线逐条相同。这 6 个失败集中在 `test/git_gate_hook_integration_test.dart`，主代理已独立确认为**非确定性、基线先存**（详见主对话中的抖动率实测），与本改动零因果。

## 验收结论

| 验收 | 结果 |
|---|---|
| A1 normalize_hostname 边界 | PASS |
| A2 default_device_name_with 优先级 | PASS |
| A3 真实调用取到主机名 | PASS |
| A4 全量回归 | PASS |
| A5 实机确认设备名 | **由主代理在合并后执行** |

## 合并决定

A1–A4 全部 PASS，审查 PASS，无未解决的正确性缺陷。**批准合并到 main。**

```pipeline-evidence
task-id: device-name-hostname
role: main-agent-final-check
worktree: /Users/alexc/Projects/CardMind/.worktrees/device-name-hostname
branch: pipeline/device-name-hostname
head: 9b2574fbab7292dd598acb04302a4ca7009a0494
acceptance: A1=pass; A2=pass; A3=pass; A4=pass; A5=pending-main-agent
verdict: PASS
```