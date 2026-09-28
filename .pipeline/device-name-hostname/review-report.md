# review-report: device-name-hostname

- task-id: `device-name-hostname`
- role: reviewer (独立复验，未参与实现)
- worktree: `/Users/alexc/Projects/CardMind/.worktrees/device-name-hostname`
- branch: `pipeline/device-name-hostname`
- HEAD: `9b2574fbab7292dd598acb04302a4ca7009a0494`（= 契约提交，已验证）
- 审查时间: 2026-09-28

只读复验。除本报告外未创建/修改/删除任何文件；未改产品代码、测试、契约、依赖。

---

## 0. 环境

```
cargo 1.98.1 (797e8a9bc 2026-08-05) (Homebrew)
hostname 命令: Alexc-MBA.local
uname: Darwin Alexc-MBA.local 27.0.0 ... RELEASE_ARM64_T8112 arm64
rustup target list --installed → 仅 aarch64-apple-darwin
```

关键补充：本 shell 环境 **无 `HOSTNAME` / `COMPUTERNAME` 环境变量**
（`env | grep -iE '^(HOSTNAME|COMPUTERNAME)='` 输出为空）。这一点直接影响 A3 判据，见 §3e。

---

## 1. 身份与范围核对 — PASS

```
$ git rev-parse --show-toplevel   → /Users/alexc/Projects/CardMind/.worktrees/device-name-hostname
$ git branch --show-current       → pipeline/device-name-hostname
$ git rev-parse HEAD              → 9b2574fbab7292dd598acb04302a4ca7009a0494  （YES-HEAD-MATCHES）
$ git diff HEAD --name-status     → M rust-backend/Cargo.lock
                                    M rust-backend/Cargo.toml
                                    M rust-backend/src/sync.rs
$ git status --porcelain -uall    → 上述 3 个 M + ?? .pipeline/device-name-hostname/ + ?? rust-backend/tests/device_name_test.rs
```

| 核对项 | 结果 |
|---|---|
| HEAD == 契约提交 | ✅ 相等 |
| 改动限于 §3 允许范围 | ✅ 仅 `sync.rs` / `Cargo.toml` / `tests/` |
| `lib/` 下有改动 | ✅ **无**（`git status --short -- lib/` 为空，含 `lib/src/rust/`） |
| `pubspec.lock` 干净 | ✅ 干净（`git status --short -- pubspec.lock` 为空） |
| `Cargo.lock` 变化 | ✅ 仅 1 行：`cardmind-backend` 的 deps 列表加 `"libc"` |
| `libc` 包条目零变化 | ✅ 版本 `0.2.186`、checksum `68ab91017fe16c622486840e4c83c9a37afeff978bd239b5293d61ece587de66` 均未变 |
| 无新增/升级/删除其它依赖 | ✅ `cargo tree` 中 `libc v0.2.186` 单版本，无重复 |

`Cargo.lock` 完整 diff（唯一 hunk）：

```diff
@@ -517,6 +517,7 @@ dependencies = [
  "chrono",
  "flutter_rust_bridge",
  "iroh",
+ "libc",
  "loro",
  "mdns-sd",
```

---

## 2. A1–A4 独立复现

### A1（normalize_hostname 边界）— PASS

命令：`cd rust-backend && cargo test --test device_name_test` → **EXIT=0**

```
running 8 tests
test normalize_hostname_keeps_ip_literal_intact ... ok
test normalize_hostname_rejects_empty_or_empty_after_truncation ... ok
test normalize_hostname_strips_suffix_after_first_dot ... ok
test default_device_name_prefers_windows_computer_name ... ok
test default_device_name_uses_hostname_when_windows_name_missing ... ok
test default_device_name_falls_back_to_fixed_string ... ok
test detect_hostname_works_in_this_environment ... ok
test sync_service_device_name_is_not_fallback ... ok
test result: ok. 8 passed; 0 failed
```

逐条核对契约 A1 六个用例（读 `tests/device_name_test.rs` 真实断言）：

| 契约用例 | 断言 | 覆盖 |
|---|---|---|
| `"Alexc-MBA.local"` → `Some("Alexc-MBA")` | `assert_eq!` | ✅ |
| `"Alexc-MBA"` → 不变 | `assert_eq!` | ✅ |
| `""` → `None` | `assert_eq!` | ✅ |
| `".local"` → `None` | `assert_eq!` | ✅ |
| `"a.b.c"` → `Some("a")` | `assert_eq!` | ✅ |
| IP `"192.168.1.5"` 不得为 `"192"` | `assert_eq!(…, Some("192.168.1.5"))` **且** `assert_ne!(…, Some("192"))` | ✅ |

**IP 边界确实断言了「不是 192」**（`device_name_test.rs:41-45`，`assert_ne!` 带失败消息）。

### A2（default_device_name_with 优先级）— PASS

同一 8 用例运行覆盖三条优先级，并含空/`.`/空白边界：

- `(Some("DESKTOP-ABCD"), Some("Alexc-MBA"))` == `"DESKTOP-ABCD"` ✅
- `(None, Some("Alexc-MBA.local"))` == `"Alexc-MBA"` ✅
- `(None, None)` == `"CardMind Device"` ✅
- `(Some(""), None)` / `(Some("."), None)` / `(None, Some(""))` == `FALLBACK` ✅

### A3（真实调用取到主机名）— PASS（**前提成立且已标注**）

读实现（`device_name_test.rs:96-113`）：

```rust
#[cfg(unix)]
#[test]
fn sync_service_device_name_is_not_fallback() {
    assert!(detect_hostname().is_some(), "前提：本机能取到主机名（hostname 命令非空）");
    let service = SyncService::new().await.unwrap();
    let name = service.device_name();
    assert_ne!(name, FALLBACK, "device_name() 不应落到兜底串，实际为 {name:?}");
    assert!(!name.is_empty(), "device_name() 不应为空串");
}
```

- 前提显式断言（非静默放宽）✅
- 断言是严格「不等于兜底串」，未放宽为「任意非空串」✅
- **独立性关键**：本 shell 无 `HOSTNAME`/`COMPUTERNAME`（§0）。若 `default_device_name()` 仍是原环境变量版，
  `SyncService::new()` 必然落到 `CardMind Device` → `assert_ne!` 必红。
  因此本测试**真正走到了 `gethostname` 路径**，不是环境变量造成的假通过。✅
- 另有一条独立前提测试 `detect_hostname_works_in_this_environment`（直接 `expect` 非空）。✅

### A4（全量回归）— PASS

```
$ cd rust-backend && cargo test            → EXIT=0
  逐二进制全部 0 failed；合计 125 passed / 2 ignored（live_relay 2 ignored）
  含 device_name_test 8 passed

$ flutter analyze                          → No issues found! (ran in 3.4s)   EXIT=0
```

`flutter test` 全量双跑基线比对（独立执行，非转述）：

| 侧 | 结果 | 退出码 |
|---|---|---|
| worktree（HEAD=契约提交+改动） | `+243 ~1 -6` | 1 |
| main（基线） | `+243 ~1 -6` | 1 |

两边失败集合**逐条相同**，全部是同一文件的 6 个用例：

```
test/git_gate_hook_integration_test.dart:
  19 安装/复制 hook 后真实 git commit 能通过 Dart 入口被调用
  20 真实 git push 证明 pre-push 读取 stdin 并通过 Dart 入口
  21 SKIP_LOCAL_CHECK=1 两个 Hook 都可跳过
  22 Dart gate 非零时 commit/push 确实被 Git 阻止
  (+2 more)
```

**抖动观测**：本次两跑均稳定为 `+243 ~1 -6`，未复现任务书所述 `+4`/`+0 -4` 抖动；两边失败集合完全一致，
不改判。判定以「两边全量失败集合逐条相同」为准 → **A4 PASS**，本改动未引入新失败。

---

## 3. 代码正确性审查（读实现，非仅跑测试）

`rust-backend/src/sync.rs:2638-2695`（`detect_hostname` / `normalize_hostname` / `default_device_name_with` / `default_device_name`）。

### a) `gethostname` 用法 — 正确，无 NUL 边界已安全处理

```rust
#[cfg(unix)]
pub fn detect_hostname() -> Option<String> {
    let mut buf = [0u8; 256];
    // SAFETY: buf 是长度 256 的有效可写缓冲区；gethostname 至多写入该长度且
    // 不保证 NUL 结尾，故按首个 NUL 或缓冲长度截断后再做 UTF-8 校验。
    let rc = unsafe { libc::gethostname(buf.as_mut_ptr() as *mut libc::c_char, buf.len()) };
    if rc != 0 { return None; }
    let end = buf.iter().position(|&b| b == 0).unwrap_or(buf.len());
    let raw = std::str::from_utf8(&buf[..end]).ok()?;
    let trimmed = raw.trim();
    (!trimmed.is_empty()).then(|| trimmed.to_string())
}
```

- 返回 0 判定成功；非 0 → `None`。✅
- 缓冲 `[0u8; 256]`（`HOST_NAME_MAX`，POSIX 常为 255）。✅
- 按首个 NUL 截断；无 NUL 时取全长。✅
- UTF-8 校验失败 → `None`；trim 后空 → `None`。✅
- `unsafe` 安全注释**准确**：缓冲区长度/可写性、不保证 NUL、截断策略均描述正确。✅

**无 NUL 结尾边界判断**：若主机名恰好填满 256 字节，`position` 返回 `None` → `end = 256` → 取全 256 字节。
判断：**可接受，且实际不可能发生**——`HOST_NAME_MAX` 为 255（macOS/Linux），缓冲比上限大 1 字节，
内核不会写满 256；即使写满也无 UB，只是得到一个恰好 256 字节的名称（仍做 UTF-8 校验，失败即 `None`）。
此边界被正确处理（有界、无 UB、无 panic）。✅

### b) `#[cfg]` 条件编译 — **确实阻止了 Windows 上的编译引用**

- `#[cfg(unix)]` 分支含 `libc::gethostname` 调用；`#[cfg(not(unix))]` 分支返回 `None`。两者同名同签名，
  每个目标只有一个存在，无重复定义。✅
- `sync.rs` 顶部 **无 `use libc` 导入**（已核对全部 `use` 行，`sync.rs:1-20`）——`libc` 全程以全限定路径
  `libc::gethostname` 引用，因此无需条件化任何导入。✅
- Windows 编译时 `#[cfg(unix)]` 整个函数体在**名字解析前**被移除，`libc::gethostname` 不会被解析/引用。
  这是 Rust `cfg` 的保证行为，而非仅阻止运行。✅
- `Cargo.toml` 中 `libc = "0.2"` 未做 target 限定；`libc` crate 本身在各平台均可编译，且调用点已被 cfg 排除，
  Windows 不会因此构建失败。✅

**证据边界（如实声明）**：本机 `rustup target list --installed` 仅 `aarch64-apple-darwin`，
**未能实际对 Windows 目标交叉编译验证**。上述结论基于 `cfg` 语义的静态推理，非编译实测。

### c) `normalize_hostname` 边界 — 见 A1 表，6 条全部有真实断言，IP 有 `assert_ne!("192")`。✅

实现（`sync.rs:2666-2676`）先 trim→空判 `None`，再 `parse::<IpAddr>()` 命中则原样返回，否则按第一个 `.` 截断、截断后空则 `None`。逻辑与断言一致。✅

### d) 优先级逻辑 — 正确，无误截断

```rust
windows_computer_name.as_deref().and_then(normalize_hostname)
    .or_else(|| hostname.as_deref().and_then(normalize_hostname))
    .unwrap_or_else(|| "CardMind Device".to_string())
```

- `DESKTOP-X` 经 `normalize_hostname`：无点 → 原样返回，无意外截断。✅
- `(None, Some("mac.local"))` → `"mac"`；`(None, None)` → `"CardMind Device"`。✅
- 注：Windows 名也过 `normalize_hostname`，对含点的 Windows 名（少见）会截断——契约未禁止，且比原实现更健壮，非缺陷。

### e) 测试能否捕获回归 — 能

- 改回原环境变量版 → A3 必红（本 shell 无 `HOSTNAME`/`COMPUTERNAME`，见 §0/§2-A3）。✅
- `detect_hostname` 返回 `None` → `device_name()` 落兜底 → A3 `assert_ne!` 必红。✅
- A3 **依赖运行环境**（需本机能取到主机名），但**已显式标注前提**（`assert!` + 注释），未放宽断言。✅

### f) 新异常路径 — 无新增未处理路径

新增唯一 `unsafe` 为 `gethostname` 调用；`rc != 0`、UTF-8 失败、空串三条失败路径均返回 `None`，无 panic/unwrap 用户数据。✅

---

## 4. 契约合规（§3 禁止项逐项）

| 禁止项 | 结果 |
|---|---|
| `lib/` 任何文件 | ✅ 未改（含 `lib/src/rust/`） |
| 配对协议 | ✅ 未改 |
| `setDeviceName` 公开 API 签名 | ✅ 未改（`device_name()`/`set_device_name()` 原样） |
| 版本号 / 发布工作流 / entitlements | ✅ 未改（diff 仅 3 个文件） |

---

## 5. 结论与额外必答

| 问题 | 回答 |
|---|---|
| `#[cfg]` 是否真阻止 Windows 上 `libc::gethostname` 编译引用 | **是**（cfg 在名字解析前移除分支；无 `use libc` 需条件化）。**但未做 Windows 交叉编译实测**（无该 target）。 |
| `gethostname` 无 NUL 结尾边界是否正确处理 | **是**。有界、无 UB、无 panic；且 256 缓冲 > HOST_NAME_MAX，实际不会写满。 |
| A1 IP 用例是否真断言「不是 192」 | **是**（`assert_eq!(→Some("192.168.1.5"))` + `assert_ne!(→Some("192"))`）。 |
| A3 是否依赖运行环境、是否有前提标注 | **依赖**，但**已显式标注前提**（`assert!(detect_hostname().is_some(), "前提…")`），未放宽断言。 |
| 是否发现正确性缺陷 | **无**。 |

**Verdict: PASS** — A1/A2/A3/A4 全部独立复现通过；未发现正确性缺陷；范围合规。

残留不确定性（不影响判定）：
1. Windows 编译为静态推理，未交叉编译实测。
2. `git_gate_hook_integration_test.dart` 本次双跑均为 `-6`，未复现任务书所述抖动；判定以两边失败集合一致为准。

```pipeline-evidence
task-id: device-name-hostname
role: reviewer
worktree: /Users/alexc/Projects/CardMind/.worktrees/device-name-hostname
branch: pipeline/device-name-hostname
head: 9b2574fbab7292dd598acb04302a4ca7009a0494
acceptance: A1=pass; A2=pass; A3=pass; A4=pass
verdict: PASS
```