# 设备名回退到固定串：macOS 上取不到真实主机名

- task-id: `device-name-hostname`
- 状态：契约冻结（待派发）
- 基线：`bf619421`
- 证据目录：`.pipeline/device-name-hostname/`

## 1. 问题陈述

配对成功后，设备列表里两台设备的名称都显示为 `CardMind Device`，而不是各自的真实主机名（本机应为 `Alexc-MBA`）。

### 根因（基线实测证据）

`rust-backend/src/sync.rs` 的 `default_device_name()`：

```rust
fn default_device_name() -> String {
    std::env::var("COMPUTERNAME")                          // Windows 专有
        .or_else(|_| std::env::var("HOSTNAME"))            // shell 变量
        .unwrap_or_else(|_| "CardMind Device".to_string())  // 全部失败 → 用户看到的值
}
```

在 macOS 上，由 Finder 启动的 GUI 进程环境变量实测为（`ps eww -p <pid>` 白名单过滤）：

```
USER=alexc
LOGNAME=alexc
HOME=/Users/alexc
SHELL=/bin/zsh
```

**没有 `COMPUTERNAME`，也没有 `HOSTNAME`。** `HOSTNAME` 是 shell 会话变量，GUI 应用不继承。因此两个分支都失败，永远落到 `CardMind Device`。

系统实际主机名（未被读取）：

```
scutil --get ComputerName : Alexc-MBA
scutil --get LocalHostName: Alexc-MBA
gethostname(3)            : Alexc-MBA.local
```

代码注释声明「默认设备名（主机名；无环境变量时回退固定名）」，但实现从未真正取过主机名——**实现与注释不符**。

## 2. 目标

让 `default_device_name()` 在各平台真正取到主机名，取不到时才回退固定串：

| 平台 | 来源 | 期望结果 |
|---|---|---|
| Windows | `COMPUTERNAME`（保持现状） | `DESKTOP-XXXX` |
| macOS / Linux | `gethostname(3)`，去掉 `.local` 等域名后缀 | `Alexc-MBA` |
| 全部失败 | 兜底 | `CardMind Device` |

**命名格式裁定**：只取主机名，**不加** `user@` 前缀。理由：现有实现意图即为主机名；`alexc-mba` 这个例子本身就是主机名；用户另有 `setDeviceName` 可自定义。

## 3. 修改范围

允许修改：

- `rust-backend/src/sync.rs`
- `rust-backend/Cargo.toml`（新增 `libc` 直接依赖）
- `rust-backend/tests/` 下新增或修改设备名测试

禁止修改：

- `lib/` 下任何文件（FRB 类型未变，UI 无需改动）
- 配对协议、`setDeviceName` 公开 API 签名
- 版本号、发布工作流、entitlements

## 4. 实现方向（非强制，执行方须说明所选方案）

**依赖**：`libc = "0.2"` —— `Cargo.lock` 中已有 `libc 0.2.186`（iroh/tokio 的传递依赖），**不得**升级或引入新版本。加为直接依赖后 `Cargo.lock` 的 `libc` 条目不应变化。

**关键约束——必须可测**：把「取主机名」抽成可注入的纯函数，避免测试依赖运行环境：

```rust
/// 各平台主机名探测；返回 None 表示取不到。
fn detect_hostname() -> Option<String>;

/// 去掉域名后缀并过滤空值：`Alexc-MBA.local` → `Alexc-MBA`。
fn normalize_hostname(raw: &str) -> Option<String>;

/// 组装默认设备名（可测：不直接读环境）。
fn default_device_name_with(
    windows_computer_name: Option<String>,
    hostname: Option<String>,
) -> String;
```

`default_device_name()` 保留为无参入口，内部调用上述函数（生产路径读真实环境）。

**后缀处理**：`gethostname(3)` 在 macOS 返回 `Alexc-MBA.local`，需按第一个 `.` 截断。注意：
- 仅当截断后非空才采用
- 纯 IP 形式（如 `192.168.1.5`）不应被截成 `192`——**必须处理这个边界**，或明确说明为何不可能出现
- 大小写：`gethostname` 返回 `Alexc-MBA`（保持系统原样），不做大小写转换

**`libc` 用法**：`libc::gethostname(buf.as_mut_ptr(), buf.len())`，`buf` 用 `[0u8; 256]`（`HOST_NAME_MAX`）。返回 0 表示成功。注意 Unix 与 Windows 的 `libc::gethostname` 签名差异——Windows 分支不走这条路径，但**编译**必须通过（若 `libc` 在 Windows 上无此函数，需 `#[cfg(unix)]` 条件编译）。

## 5. 验收条件

### A1（单元）normalize_hostname 边界

`rust-backend/tests/` 新增用例覆盖：

- `"Alexc-MBA.local"` → `Some("Alexc-MBA")`
- `"Alexc-MBA"` → `Some("Alexc-MBA")`（无后缀不变）
- `""` → `None`（空值拒绝）
- `".local"` → `None`（截断后为空，不得返回空串）
- `"a.b.c"` → `Some("a")`（按第一个点截断）
- IP 形式 `"192.168.1.5"` → **要么**返回原串，**要么**返回 `None`，**不得**返回 `"192"`。执行方须说明选择并给断言。

### A2（单元）default_device_name_with 优先级

- Windows 名存在 → 用它，忽略 hostname
- Windows 名缺失、hostname 存在 → 用 hostname
- 两者都缺失 → `"CardMind Device"`

### A3（单元）真实调用取到主机名

在测试环境调用 `SyncService::new()`，断言 `device_name()` **不等于** `"CardMind Device"`。

若该环境主机名确实取不到（无网络接口等），必须显式标注前提，不得放宽为「等于任意非空串」这类宽松断言。执行方须先确认本机能取到（`hostname` 命令非空），再写这条断言。

### A4（回归）全量测试绿

```bash
cd rust-backend && cargo test
flutter analyze
flutter test
```

与基线一致或更好。注意：`flutter test` 全量存在**基线先存**的失败（`git_gate_hook_integration_test.dart` 等，单独跑可通过），须如实记录、不得归因本改动。

### A5（真实链路，主代理执行）实机确认设备名

主代理重新构建并安装 macOS 应用，重新配对，确认设备列表显示 `Alexc-MBA` 而非 `CardMind Device`。

## 6. 环境前提（重要）

**rustup 的 `stable-aarch64-apple-darwin` 工具链已损坏**（`lib/` 存在但 `bin/` 缺失）。主代理已将其默认工具链切到 `system`（Homebrew Rust 1.98.1）：

```bash
rustup default system
cargo --version   # cargo 1.98.1 (797e8a9bc 2026-08-05) (Homebrew)
rustc --version   # rustc 1.98.1 (48a229cea 2026-09-01) (Homebrew)
```

**不要**再用 `export PATH="/opt/homebrew/Cellar/rust/1.98.1/bin:$PATH"` 这类绕过方式；直接用默认 `cargo` 即可。若发现 `cargo` 不可用，记录下来，不要静默改回。

Flutter 需 `PUB_HOSTED_URL=https://pub.flutter-io.cn`。

## 7. 证据要求

执行方在 `.pipeline/device-name-hostname/executor-report.md` 写明：

- task-id、worktree 绝对路径、branch、HEAD
- A1–A4 的完整命令、退出码、关键断言输出（真实输出，不得编造）
- 修改文件清单与 diff 摘要
- **`Cargo.lock` 是否被改动**（`libc` 加为直接依赖不应改变 lock 内容）
- IP 形式 hostname 的边界处理选择与理由
- A5 标注由主代理执行，未伪造

报告末尾加机器可读区块：

```pipeline-evidence
task-id: device-name-hostname
role: executor
worktree: <绝对路径>
branch: pipeline/device-name-hostname
head: <HEAD sha>
acceptance: A1=<pass|fail>; A2=<pass|fail>; A3=<pass|fail>; A4=<pass|fail>
```

## 8. 已知证据边界

- 本仓库不存在 `.gitnexus/run.cjs`，GitNexus MCP impact 工具不可用。
- `flutter test` 全量有基线先存失败，须与基线逐项比对后判定 A4。

<!-- pipeline-contract
 task-id: device-name-hostname
 contract-version: 1
 baseline: bf619421
 scope: rust-backend/src/sync.rs,rust-backend/Cargo.toml,rust-backend/tests
 acceptance: A1-normalize-hostname-boundaries; A2-default-name-priority; A3-real-hostname-non-fallback; A4-full-suite-green
 execution-worktree: pending-contract-freeze
 evidence-dir: .pipeline/device-name-hostname/
-->