# 执行报告（收尾轮）：pairing-credential-ip

- task-id: `pairing-credential-ip`
- worktree: `/Users/alexc/Projects/CardMind/.worktrees/pairing-credential-ip`
- branch: `pipeline/pairing-credential-ip`
- HEAD（契约提交）: `8b6ff7013017050fa552ccd222ee0a98cb4793b8`
- 证据目录: `.pipeline/pairing-credential-ip/`
- 本轮角色: 收尾执行子代理（复现验收 + 还原越界改动 + 重写报告）

> 本文件覆盖上一轮（上下文耗尽、未留报告）的产物。上一轮已把实现落盘，本轮**未重做实现**，仅做还原、独立复现与取证。

## 0. 越界改动还原（pubspec.lock）

上一轮遗留 `pubspec.lock` 被改动 121 行（含真实依赖版本变化，如某依赖 `9.2.1` → `9.3.0`），超出契约 §4 修改范围。本轮已还原：

```bash
$ cd /Users/alexc/Projects/CardMind/.worktrees/pairing-credential-ip
$ git checkout -- pubspec.lock
$ git status --short pubspec.lock
$ echo "(end)"
--- status after restore ---
(end)
```

**结论：`pubspec.lock` 已干净还原，`git status --short pubspec.lock` 无输出。** 本轮全程未执行 `flutter pub get`（会改写该文件）；`flutter analyze` / `flutter test` 未改写它，收尾时再次确认仍无输出。

还原后的工作区改动（仅剩契约允许范围内 + 本报告目录）：

```
 M lib/src/rust/frb_generated.dart
 M lib/src/rust/sync.dart
 M rust-backend/src/frb_generated.rs
 M rust-backend/src/sync.rs
 M rust-backend/tests/pairing_credential_test.rs
 M test/pairing_accept_ui_test.dart
 M test/pairing_credential_ui_test.dart
 M test/pairing_log_events_test.dart
 M test/pairing_mdns_widget_test.dart
 M test/sync_ui_widget_test.dart
?? .pipeline/pairing-credential-ip/
```

`git diff --stat HEAD`：10 files changed, 487 insertions(+), 38 deletions(-)。

## 1. 环境前提

- **rustup stable 工具链损坏**：`~/.rustup/toolchains/stable-aarch64-apple-darwin/` 只有 `lib/` 没有 `bin/`，默认 `cargo`（rustup shim）报
  `error: the 'cargo' binary, normally provided by the 'cargo' component, is not applicable to the 'stable-aarch64-apple-darwin' toolchain`。
- 全部 Rust 命令改用 **Homebrew Rust 1.98.1**：
  `export PATH="/opt/homebrew/Cellar/rust/1.98.1/bin:/opt/homebrew/bin:$PATH"`。
  本轮实测：`cargo 1.98.1 (797e8a9bc 2026-08-05) (Homebrew)`。
- Flutter 命令统一带 `export PUB_HOSTED_URL=https://pub.flutter-io.cn`。
- 运行态动态库 `build/native/macos/libcardmind_backend.dylib` 存在且**新于**全部 Rust 源文件：
  ```
  1790549555  build/native/macos/libcardmind_backend.dylib
  1790548959  rust-backend/src/sync.rs
  1790549085  rust-backend/src/frb_generated.rs
  1790548721  rust-backend/src/lib.rs
  ```
  mtime 严格大于三个源文件 → 已含 `ips` 字段的当前代码，**无需重建**。该路径被 `.gitignore:35`（`/build/`）忽略，不入版本控制。
- 仓库**不存在** `.gitnexus/run.cjs`，GitNexus MCP impact 工具**不可用**。本报告不声称执行过 impact analysis。

## 2. A1–A5 验收：完整命令、退出码、关键输出

### A1（v1 凭证仍可解析 — 向后兼容）✅ PASS

与 A2/A3/A4 同批执行：

```bash
$ export PATH="/opt/homebrew/Cellar/rust/1.98.1/bin:/opt/homebrew/bin:$PATH"
$ cd /Users/alexc/Projects/CardMind/.worktrees/pairing-credential-ip/rust-backend
$ cargo test --test pairing_credential_test
```

```
running 20 tests
test credential_qr_text_is_canonical_base64url_without_padding ... ok
test credential_rejects_expired_future_and_invalid_ttl ... ok
test credential_rejects_wrong_prefix_version_length_and_trailing_bytes ... ok
test credential_signature_is_verified_by_endpoint_id ... ok
test credential_rejects_tampered_payload_and_signature ... ok
test credential_v1_has_exact_canonical_layout_and_roundtrips ... ok
test credential_v2_rejects_overlong_ip_without_panic ... ok
test credential_v2_rejects_tampered_ips_and_count ... ok
test credential_v2_roundtrips_ips_in_order ... ok
test credential_v2_with_zero_ips_parses ... ok
test credential_never_enters_debug_logs ... ok
test generated_credential_contains_local_addrs ... ok
test credential_nonce_mismatch_counts_toward_attempt_limit ... ok
test credential_is_single_use ... ok
test empty_and_zero_nonce_are_rejected ... ok
test credential_connect_target_ips_come_from_credential ... ok
test credential_connect_uses_embedded_node_id_without_mdns ... ok
test new_credential_replaces_previous_session ... ok
test legacy_six_digit_mdns_pairing_requires_and_accepts_advertised_nonce ... ok
test credential_connect_end_to_end_uses_embedded_ips ... ok

test result: ok. 20 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 10.21s

EXIT_CODE=0
```

A1 关键断言（`credential_v1_has_exact_canonical_layout_and_roundtrips`）：v1 载荷逐字节布局（`[0..2]=="CM"`、`[2]==1`、各字段大端、`raw[71..].len()==64`、`CREDENTIAL_FINAL_LEN==135`），`parse_credential` 得
`ParsedCredentialFields { node_id_bytes, pairing_code: CODE, expires_at: EXPIRES, nonce, ips: Vec::new() }`。
同批 `credential_rejects_wrong_prefix_version_length_and_trailing_bytes` 断言未知版本（`bad[2]=3`）与尾随字节均被拒。

### A2（v2 往返 + IP 参与签名）✅ PASS

同上命令中的 4 个 v2 用例全部 `ok`：

- `credential_v2_roundtrips_ips_in_order`：3 个 IP，断言 `raw.len() == 73 + Σ(2+len) + 64`、`raw[2]==2`、`raw[0..2]==b"CM"`、`raw[71..73]==ip_count.to_be_bytes()`、`parsed.ips == ips`（**顺序一致**）、base64url 往返逐字节相等。
- `credential_v2_with_zero_ips_parses`：`ip_count=0` → `raw.len()==73+64`、`raw[71..73]==0u16.to_be_bytes()`、`parsed.ips.is_empty()`。
- `credential_v2_rejects_tampered_ips_and_count`：对 IP 数据区 `[73..len-64]` **逐字节**翻转、`ip_count` 两字节（71/72）翻转、签名字节（`len-64` / `len-1`）翻转 → 全部被拒。
- `credential_v2_rejects_overlong_ip_without_panic`：`"a".repeat(u16::MAX as usize + 1)` → `encode_credential_v2` 返回 `Err`，无 panic。

### A3（生成路径确实填入本机地址）✅ PASS

`test generated_credential_contains_local_addrs ... ok`

断言为**严格相等**：

```rust
let local = svc.local_addrs();
assert_eq!(
    parsed.ips, local,
    "凭证内嵌 IP 必须等于 svc.local_addrs()"
);
```

并额外断言每项含 `:` 且可 `parse::<SocketAddr>()`。

**关键：本环境 `local_addrs()` 非空**，故走的是严格分支而非环境退化分支。取证：

```bash
$ cargo test --test pairing_credential_test -- --nocapture 2>&1 | grep -E "NOTE\[A3\]|NOTE\[A4\]"
NO NOTE LINES -> local_addrs() was NON-EMPTY in A3/A4
```

（`NOTE[A3]` 仅在 `local.is_empty()` 分支打印，未出现 → 断言未退化。）A3 日志显示 `event=pairing.show_code ... action=success`。

### A4（连接路径使用凭证内嵌 IP）✅ PASS

两个用例 `ok`：

- `credential_connect_target_ips_come_from_credential`（seam 层，纯解析 + 目标构造，无真实连接）
- `credential_connect_end_to_end_uses_embedded_ips`（端到端真实链路）

端到端用例 `--nocapture` 的真实日志证据（非 mock）：

```
event=pairing.show_code  stage=pairing.show_code  action=success
event=pairing.accept     stage=pairing.accept     action=start  timeout_ms=86400000
event=pairing.connect    stage=pairing.connect    action=start    transport=direct
event=pairing.request    stage=pairing.request    duration_ms=18  action=received peer_name=New Phone
event=pairing.connect    stage=pairing.connect    duration_ms=18  action=success transport=direct peer_name=Trusted PC
event=sync.push          stage=sync.initial       action=start    direction=push note_count=0
event=sync.receive       stage=sync.initial       duration_ms=7   direction=receive action=success bytes=4
event=pairing.confirm    stage=pairing.confirm    duration_ms=8   action=success peer_name=New Phone
```

`transport=direct` + 18ms 内 `action=received`：凭证内嵌 IP 直连成立（若 `ips` 为空，无 relay 环境下只剩 n0 DNS 路径，必然超时）。

### A5（回归：全量绿）✅ PASS（与基线一致，无新增失败）

**Rust 全量** — 退出码 0：

```bash
$ cd rust-backend && cargo test
```

```
test result: ok. 7 passed; 0 failed   (discovery/relay 相关二进制)
test result: ok. 6 passed; 0 failed   (store_test)
test result: ok. 5 passed; 0 failed   (sync_service_test)
test result: ok. 1 passed; 0 failed   (sync_test::end_to_end_sync)
test result: ok. 13 passed; 0 failed  (trash_test)
... 含 pairing_credential_test: 20 passed; 0 failed
Doc-tests cardmind_backend: ok. 0 passed; 0 failed
CARGO_TEST_EXIT=0
```

**Flutter analyze** — 退出码 0：

```bash
$ flutter analyze
Analyzing pairing-credential-ip...
No issues found! (ran in 9.8s)
ANALYZE_EXIT=0
```

**Flutter test** — 退出码 1，**238 passed / 1 skipped / 4 failed**，4 个失败全部来自 `test/git_gate_hook_integration_test.dart`（用例 19/20/21/22）：

```
00:31 +238 ~1 -4: Some tests failed.
Failing tests:
  test/git_gate_hook_integration_test.dart: 19 安装/复制 hook 后真实 git commit 能通过 Dart 入口被调用
  test/git_gate_hook_integration_test.dart: 20 真实 git push 证明 pre-push 读取 stdin 并通过 Dart 入口
  test/git_gate_hook_integration_test.dart: 21 SKIP_LOCAL_CHECK=1 两个 Hook 都可跳过
  test/git_gate_hook_integration_test.dart: 22 Dart gate 非零时 commit/push 确实被 Git 阻止

  ProcessException: No such file or directory
    Command: git commit -m t1
  dart:io                                          Process.run
  test/git_gate_hook_integration_test.dart 122:20  main.gitRun
```

**已独立复现为基线先存失败（非本任务回归）**：在同一 commit 的**未改动基线主工作树** `/Users/alexc/Projects/CardMind`（`main`，HEAD 同为 `8b6ff701`，该测试文件 `git status` 干净）上运行同一文件，得到**完全相同的 4 个失败、相同堆栈**：

```
$ cd /Users/alexc/Projects/CardMind && flutter test test/git_gate_hook_integration_test.dart
00:01 +0 -4: Some tests failed.
Failing tests: test/git_gate_hook_integration_test.dart: 19 / 20 / 21 / 22
  ProcessException: No such file or directory
```

基线**全量** `flutter test` 同样为 `+238 ~1 -4`，与本 worktree 数值逐项一致。本改动未触碰 `test/git_gate_hook_integration_test.dart`、`.githooks/**`、`tool/git_gate.dart` 或任何 git hook 逻辑。

按契约 §5 A5「必须与基线一致或更好，不得新增失败」：**与基线逐项一致 → A5 判 PASS**。

#### 根因说明（如实，含对上一轮结论的纠正）

上一轮报告称失败原因是「`flutter test` 环境的 PATH 未包含可执行 git」。**本轮实测不支持该结论**，特此纠正：

- 在**同一 harness** 内用最小探针（`Process.run('git', ...)`，含/不含 `environment` 覆盖、含/不含 `workingDirectory`、含 `Directory.systemTemp.createTemp` 临时 repo + `git init/config/add/commit`）全部成功：
  ```
  PROBE no-env exit=0 out=git version 2.54.0 (Apple Git-157)
  PROBE with-env exit=0 out=git version 2.54.0 (Apple Git-157)
  B-wd+env     exit=0 err=
  C-noenv-wd+env exit=0
  A-wd-no-env  exit=0
  ```
  `Platform.environment['PATH']` 已含 `/usr/bin`、`/opt/homebrew/bin` 等，git 可达。
- 另有一处细节与「PATH 缺失」矛盾：该测试先执行 `gitRun(repo, ['add', ...])`（同一 `Process.run('git', ...)` 代码路径，`environment: null`）**未失败**，失败只出现在随后带 `environment:` 覆盖的 `git commit`。
- 因此**根因未被本轮确定**。可确证的是：该失败在未改动基线上以完全相同形态复现，属环境/预先存在，与本契约改动无因果关系。倾向性猜测（未证实）：`flutter test` 全量并发下进程创建（fork/exec）资源受限导致 `ProcessException`。

## 3. 修改文件清单与 diff 摘要

| 文件 | 改动摘要 |
|---|---|
| `rust-backend/src/sync.rs` | 协议常量拆为 `CREDENTIAL_VERSION_V1=1` / `CREDENTIAL_VERSION_V2=2`；`ParsedCredentialFields` 增 `ips: Vec<String>`；`build_canonical_payload` 拆出 `build_common_header(version, ...)`；新增 `build_canonical_payload_v2` / `encode_credential_v2`（含 `u16::try_from` 长度校验，超长返回 `Err`）；`parse_credential` 改按 `[2]` 版本分派、签名切片改 `raw.split_at(raw.len() - 64)`（不再固定 71）、v2 逐项读取并做 UTF-8/越界/尾随字节校验；`credential_to_string` 收 `&[u8]`、`credential_from_string` 返回 `Vec<u8>`；`ParsedPairingCredential` 增 `ips`；`begin_pairing_credential` 改用 `encode_credential_v2(..., &self.local_addrs())`；**新增 `SyncService::pairing_target_for_credential`**；`begin_pairing_connect_with_credential` 改为复用该方法（原 `ips: vec![]` 删除） |
| `rust-backend/tests/pairing_credential_test.rs` | v1 期望更新（`ips: Vec::new()`、未知版本改 `bad[2]=3`、`credential_from_string` 返回 `Vec<u8>`）；新增 A2（4 例）/A3（1 例）/A4（2 例） |
| `lib/src/rust/sync.dart` | codegen 产物：`ParsedPairingCredential` 增 `final List<String> ips`，更新构造器、`hashCode`、`operator ==` |
| `lib/src/rust/frb_generated.dart` | codegen 产物：DCO 解码长度 `4` → `5`，增 `ips: dco_decode_list_String(arr[4])`；SSE 解码/编码增 `list_String` |
| `rust-backend/src/frb_generated.rs` | codegen 产物：`ParsedPairingCredential` 的 SseDecode / IntoDart / SseEncode 增 `ips` |
| `test/pairing_accept_ui_test.dart`、`pairing_credential_ui_test.dart`、`pairing_log_events_test.dart`、`pairing_mdns_widget_test.dart`、`sync_ui_widget_test.dart` | 各 +1 行：`ParsedPairingCredential(...)` 夹具补 `ips: const []` |
| `pubspec.lock` | **已还原**（上一轮越界改动，本轮 `git checkout --`） |
| `build/native/macos/libcardmind_backend.dylib` | 环境前置产物，被 `.gitignore` 忽略，不入版本控制 |

未改动（契约禁止项）：`lib/pages/devices_page.dart`、relay 策略、`macos/Runner/*.entitlements`、签名/公证、版本号、发布工作流。**未执行 `git commit`。**

## 4. A4 所选 seam 及为何能红

**seam = `SyncService::pairing_target_for_credential(&self, credential: &str) -> Result<PairingTarget, PairingCredentialError>`**

把原先内联在 `begin_pairing_connect_with_credential` 里的「parse → 构造 `PairingTarget`」抽成公开方法，`begin_pairing_connect_with_credential` 成为其唯一调用方。这样无需发起真实网络连接即可观测连接目标。

**断言强度核实（逐行读过，不是宽松断言）**——`test/pairing_credential_test.rs:782` `credential_connect_target_ips_come_from_credential`：

```rust
let display = confirmer.begin_pairing_credential().unwrap();
let confirmer_local = confirmer.local_addrs();

let target = initiator
    .pairing_target_for_credential(&display.credential)
    .unwrap();
assert_eq!(
    target.ips, confirmer_local,
    "PairingTarget.ips 必须来自凭证内嵌 IP（回归：曾被硬编码为 vec![]）"
);
assert_eq!(target.device_id, confirmer.device_id());

// build_connect_addr：非空 ips → EndpointAddr 含等量 IP 传输地址
let addr = initiator.build_connect_addr(node_id, &target.ips).unwrap();
if !target.ips.is_empty() {
    let ip_addrs: Vec<_> = addr.ip_addrs().copied().collect();
    assert_eq!(ip_addrs.len(), target.ips.len(),
               "非空 ips 必须映射为等量 TransportAddr::Ip");
}
```

**不是** `ips.is_empty() == false` 之类宽松断言，而是 `target.ips == confirmer.local_addrs()` 的**列表相等**（元素 + 顺序）。

**为何能红**：原缺陷是 `ips: vec![]`。本环境 `local_addrs()` **非空**（已由 `NOTE[A3]/NOTE[A4]` 未打印证实），因此期望值为非空列表，任何把 `ips` 退回 `vec![]` 或漏传的改动都会让 `assert_eq!` 立即失败（`[]` ≠ `["192.168.31.x:port", ...]`）。第二段断言进一步覆盖「ips 传了但没进 EndpointAddr」的失效模式。端到端用例 `credential_connect_end_to_end_uses_embedded_ips` 为兜底：无 relay 环境下 `ips` 为空只剩被墙的 n0 DNS 路径，必然超时 → 变红。

**该 seam 为新增公开方法，未放宽任何既有断言；未为使测试通过而修改断言。**

## 5. FRB codegen

**已执行**（上一轮）：`flutter_rust_bridge_codegen generate`，版本 **2.12.0**（与 `.github/workflows/manual-build-artifacts.yml` 的 `FRB_CODEGEN_VERSION` 一致）。
生成产物已纳入改动：`lib/src/rust/sync.dart`、`lib/src/rust/frb_generated.dart`（另含 `.io.dart` / `.web.dart`）与 Rust 侧 `rust-backend/src/frb_generated.rs`。

本轮核对：生成产物与手写类型一致（`lib/src/rust/sync.dart` 的 `ips` 字段、`frb_generated.dart` 的 `arr.length != 5` 与 `dco_decode_list_String(arr[4])`、`frb_generated.rs` 的 `Vec<String>` 编解码），无手改痕迹。本轮**未重跑** codegen（无手写类型变更），未手改任何生成产物。

## 6. A6（真实手机扫码配对）

**未执行 —— 由主代理执行。** 本执行子代理无物理手机、无同局域网真机条件，**未伪造任何 A6 证据**，本报告不声称 A6 通过。

## 7. 证据边界

- GitNexus MCP impact 工具不可用（仓库无 `.gitnexus/run.cjs`），**未执行** impact analysis，不声称已执行。
- `flutter test` 的 4 个失败为**基线先存**：在未改动的主工作树同一 commit 上逐项复现（同文件 4 例、同堆栈、全量 `+238 ~1 -4` 同数值）。本轮**未能确定其根因**，并**纠正**上一轮「PATH 不含 git」的说法——最小探针证明该 harness 内 `Process.run('git', ...)` 可用。
- A3/A4 的「无 IPv4 接口」退化分支已在本环境**未被触发**（`local_addrs()` 非空），故 A3/A4 断言保持严格相等形态。
- 本轮未执行 `flutter pub get`；`pubspec.lock` 还原后至收尾保持干净。

```pipeline-evidence
task-id: pairing-credential-ip
role: executor
worktree: /Users/alexc/Projects/CardMind/.worktrees/pairing-credential-ip
branch: pipeline/pairing-credential-ip
head: 8b6ff7013017050fa552ccd222ee0a98cb4793b8
acceptance: A1=pass; A2=pass; A3=pass; A4=pass; A5=pass
```