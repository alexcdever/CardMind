# executor-report: device-name-hostname

- task-id: `device-name-hostname`
- role: executor
- worktree: `/Users/alexc/Projects/CardMind/.worktrees/device-name-hostname`
- branch: `pipeline/device-name-hostname`
- HEAD: `9b2574fbab7292dd598acb04302a4ca7009a0494`

## 0. 环境

```
cargo 1.98.1 (797e8a9bc 2026-08-05) (Homebrew)
rustc 1.98.1 (48a229cea 2026-09-01) (Homebrew)
hostname 命令输出: Alexc-MBA.local
```

未使用任何 PATH 绕过方式。

**证据边界**：本仓库无 `.gitnexus/run.cjs`，GitNexus impact/`detect_changes` 工具不可用，
未执行、未声称执行。

## 1. 修改文件清单

| 文件 | 变更 |
|---|---|
| `rust-backend/Cargo.toml` | 新增 `libc = "0.2"` 直接依赖（+2 行） |
| `rust-backend/src/sync.rs` | 新增 `detect_hostname` / `normalize_hostname` / `default_device_name_with`；`default_device_name()` 改为薄入口（+53/-6 行） |
| `rust-backend/tests/device_name_test.rs` | 新增，8 个用例（A1/A2/A3） |
| `rust-backend/Cargo.lock` | **有变更**（见 §4） |

`lib/` 下未改任何文件；配对协议、`setDeviceName` 签名、版本号、发布工作流、
entitlements 均未触碰。未做 git commit。

### diff 摘要（`rust-backend/src/sync.rs`）

```rust
fn default_device_name() -> String {
    default_device_name_with(std::env::var("COMPUTERNAME").ok(), detect_hostname())
}
```

`HOSTNAME` 环境变量分支**已删除**（GUI 进程不继承，是本次缺陷根因）。

## 2. 验收结果

### A1（单元）normalize_hostname 边界 — PASS

```
$ cd rust-backend && cargo test --test device_name_test
EXIT_CODE=0
running 8 tests
test normalize_hostname_strips_suffix_after_first_dot ... ok
test normalize_hostname_rejects_empty_or_empty_after_truncation ... ok
test normalize_hostname_keeps_ip_literal_intact ... ok
test default_device_name_prefers_windows_computer_name ... ok
test default_device_name_uses_hostname_when_windows_name_missing ... ok
test default_device_name_falls_back_to_fixed_string ... ok
test detect_hostname_works_in_this_environment ... ok
test sync_service_device_name_is_not_fallback ... ok

test result: ok. 8 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.06s
```

覆盖用例与断言（真实代码）：

- `normalize_hostname("Alexc-MBA.local")` == `Some("Alexc-MBA")`
- `normalize_hostname("Alexc-MBA")` == `Some("Alexc-MBA")`
- `normalize_hostname("a.b.c")` == `Some("a")`
- `normalize_hostname("")` == `None`
- `normalize_hostname(".local")` == `None`
- `normalize_hostname("   ")` == `None`
- `normalize_hostname("192.168.1.5")` == `Some("192.168.1.5")`，且 `assert_ne!(..., Some("192"))`

### A2（单元）default_device_name_with 优先级 — PASS

（同上一次运行，3 个用例全绿）

- `default_device_name_with(Some("DESKTOP-ABCD"), Some("Alexc-MBA"))` == `"DESKTOP-ABCD"`
- `default_device_name_with(None, Some("Alexc-MBA.local"))` == `"Alexc-MBA"`
- `default_device_name_with(None, None)` == `"CardMind Device"`
- 边界：`Some("")` / `Some(".")` / `Some("   ")` 均视为取不到 → `"CardMind Device"`

### A3（单元）真实调用取到主机名 — PASS

```rust
#[cfg(unix)]
#[test]
fn sync_service_device_name_is_not_fallback() {
    ...
    assert!(detect_hostname().is_some(), "前提：本机能取到主机名（hostname 命令非空）");
    let service = SyncService::new().await.unwrap();
    let name = service.device_name();
    assert_ne!(name, FALLBACK, ...);
    assert!(!name.is_empty(), ...);
}
```

本机 `hostname` 输出 `Alexc-MBA.local`（非空），前提成立。断言是严格的
「不等于兜底串」，未放宽为「任意非空串」。

### A4（回归）全量测试绿 — PASS（与基线一致）

```
$ cd rust-backend && cargo test
EXIT_CODE=0
```

逐二进制（全部 `0 failed`，共 125 passed / 2 ignored）：

| 二进制 | 结果 |
|---|---|
| autosync_test | 8 passed |
| connect_test | 7 passed |
| debug_log_test | 10 passed |
| **device_name_test** | **8 passed** |
| discovery_test | 2 passed |
| integration_test | 2 passed |
| live_relay_test | 0 passed, 2 ignored |
| migration_test | 2 passed |
| note_crdt_test | 10 passed |
| pairing_credential_test | 20 passed |
| pairing_test | 10 passed |
| receiver_continuous_test | 14 passed |
| relay_config_test | 7 passed |
| store_test | 6 passed |
| sync_service_test | 5 passed |
| sync_test | 1 passed |
| trash_test | 13 passed |
| doc-tests | 0 passed |

```
$ flutter analyze
No issues found! (ran in 6.9s)
```

```
$ flutter test        # 主工作树基线: +243 ~1 -6
$ flutter test        # 本 worktree:   +243 ~1 -6   （完全一致）
```

两边的 6 个失败**全部**是同一文件同一批用例：

```
test/git_gate_hook_integration_test.dart:
  19 安装/复制 hook 后真实 git commit 能通过 Dart 入口被调用
  20 真实 git push 证明 pre-push 读取 stdin 并通过 Dart 入口
  21 SKIP_LOCAL_CHECK=1 两个 Hook 都可跳过
  22 Dart gate 非零时 commit/push 确实被 Git 阻止
  (+2 more)
```

**基线比对结论**：本改动未引入任何新失败，失败集合与基线逐一对应。这些失败
归因于 Git hook 集成测试的环境前提，与本改动（Rust 设备名探测）无因果关系。

注：任务书称「单独跑 `git_gate_hook_integration_test.dart` 是能通过的」——
本 worktree 实测单独跑该文件仍是 4 failed（`+0 -4`），与全量时一致。这不影响
A4 判定（基线同样如此），但该表述与实际不符，如实记录。

### 环境前置（非改动，已标注）

worktree 是裸的（无 `rust-backend/target/`），而 FRB 2.12.0 默认加载器按
`Directory.current` 解析 `rust-backend/target/release/`，导致 5 个依赖 dylib 的
测试在 `setUpAll` 报 `Failed to load dynamic library`。从主工作树复制
（`rust-backend/target/` 被 gitignore，复制后 `git status` 无新增条目）：

```
cp /Users/alexc/Projects/CardMind/rust-backend/target/release/libcardmind_backend.dylib \
   .worktrees/device-name-hostname/rust-backend/target/release/
```

复制后 `flutter test` 从 `+211 -11` 变为 `+243 -6`，与基线完全对齐。这是环境
前置，不是代码变更。

### A5（实机确认设备名）— 由主代理执行

未执行、未伪造。需主代理重新构建并安装 macOS 应用、重新配对，确认设备列表显示
`Alexc-MBA` 而非 `CardMind Device`。

## 3. IP 形式 hostname 的边界处理选择与理由

**选择：返回原串**（`normalize_hostname("192.168.1.5") == Some("192.168.1.5")`）。

理由：

1. 该函数的职责是「去掉域名后缀」。点分十进制没有可去掉的域名后缀，原样返回
   最能保真。
2. 返回 `None` 会把「名称为 IP」与「取不到名称」两种语义混为一谈，使
   `default_device_name_with` 无法区分「拿到了但形态特殊」与「没拿到」。
3. 无论选哪种，都不得返回按第一个 `.` 截断的 `"192"` —— 这是无意义且会误导用户的值。

`gethostname(3)` 在 macOS/Linux 实际不返回 IP 字面量（返回 `Alexc-MBA.local`
这类 DNS 名），此分支是边界防御。测试同时断言 `assert_ne!(..., Some("192"))`，
把「不得截断」这条硬约束固化下来。

大小写保持系统原样，不做转换（`gethostname` 返回 `Alexc-MBA`）。

## 4. Cargo.lock 是否被改动

**被改动**，且是加为直接依赖所必需的最小改动。完整 diff：

```diff
diff --git a/rust-backend/Cargo.lock b/rust-backend/Cargo.lock
@@ -517,6 +517,7 @@ dependencies = [
  "chrono",
  "flutter_rust_bridge",
  "iroh",
+ "libc",
  "loro",
  "mdns-sd",
```

即仅在 `cardmind-backend` 的 `dependencies` 列表里加入 `"libc"`。

`libc` **包条目本身完全未变**（版本与 checksum 均保持原值，未升级）：

```
name = "libc"
version = "0.2.186"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "68ab91017fe16c622486840e4c83c9a37afeff978bd239b5293d61ece587de66"
```

契约说「加为直接依赖后 `Cargo.lock` 的 `libc` 条目不应变化」—— 严格满足：
`libc` 条目零变化，唯一变化是反向依赖列表新增一行。无其他依赖新增/升级/删除。

## 5. 实现说明

```rust
#[cfg(unix)]
pub fn detect_hostname() -> Option<String> {
    let mut buf = [0u8; 256];                       // HOST_NAME_MAX
    let rc = unsafe { libc::gethostname(buf.as_mut_ptr() as *mut libc::c_char, buf.len()) };
    if rc != 0 { return None; }
    let end = buf.iter().position(|&b| b == 0).unwrap_or(buf.len());
    let raw = std::str::from_utf8(&buf[..end]).ok()?;
    let trimmed = raw.trim();
    (!trimmed.is_empty()).then(|| trimmed.to_string())
}

#[cfg(not(unix))]
pub fn detect_hostname() -> Option<String> { None }
```

- `#[cfg(unix)]` 条件编译：Windows 走 `COMPUTERNAME`，不调用 `libc::gethostname`
  （两平台签名不同）；`#[cfg(not(unix))]` 分支保证非 Unix 也能编译通过。
- 缓冲 `[0u8; 256]`，按首个 NUL 截断（`gethostname` 不保证 NUL 结尾），
  再做 UTF-8 校验，任一步失败返回 `None`。
- 命名格式只取主机名，**不加** `user@` 前缀。
- `pub` 可见性：三个函数设为 `pub` 以便集成测试从 `cardmind_backend::sync` 导入
  （与既有 `PairingSession` 等测试钩子同模式）。

## 6. 未完成 / 待跟进

- **A5 实机确认未执行**，按契约由主代理完成。
- worktree 的 `rust-backend/target/release/libcardmind_backend.dylib` 是我为跑
  `flutter test` 复制进来的环境前置（gitignored，不进提交）。若后续清理 worktree
  可安全删除。
- 未做 git commit（按任务要求）。

```pipeline-evidence
task-id: device-name-hostname
role: executor
worktree: /Users/alexc/Projects/CardMind/.worktrees/device-name-hostname
branch: pipeline/device-name-hostname
head: 9b2574fbab7292dd598acb04302a4ca7009a0494
acceptance: A1=pass; A2=pass; A3=pass; A4=pass
```