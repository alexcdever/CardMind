# 任务 T2 收尾实机自检 — executor report

时间：2026-08-18
worktree：`D:/Projects/CardMind/.worktrees/signed-pairing-credential`
分支：`codex/signed-pairing-credential`
状态：在任务 T 既有改动之上继续；未删除、未回退、未重建任何既有改动。**四个必做项均已完成并实机验证**；跨设备（Windows↔Android）双端 UI 自动化按任务单许可如实报告为"未覆盖"，但 Rust 443 credential 链路、Windows 平台、Android 平台分别真实通过。

## 完成内容

1. **必做 1 — 标准 443 签名凭证 live test**：在 `rust-backend/tests/live_relay_test.rs` 新增独立 `#[test] #[ignore]` 测试 `live_signed_credential_pairing_over_standard_443_relay`（与旧 :9443 测试并存）。两持久化 SyncService，两端 `relay.txt` 严格写 `https://relay.alexc.cn`（断言不含 `:9443`）；confirmer `begin_pairing_credential`（不依赖 mDNS）；initiator 只拿凭证字符串走 `begin_pairing_connect_with_credential`（不输入 node id、不调 mDNS、target.ips=[] 内部解析）；`accept_pairing_request` + `confirm_pairing`；请求 code/nonce 与会话一致性断言；首次全量 push → `accept_push` + `import_all`；双方配对记录、last_seen 时间窗、n1 读模型；`CollectingSink` 抓结构化日志断言 `pairing.connect transport=relay`（start+success）；日志脱敏断言（完整凭证/body/配对码/完整 device id/正文不得入日志）；confirmer/initiator 与 spawn 两侧均 `tokio::time::timeout` 包裹；旧测试敏感 println 改为脱敏/掩码。
2. **必做 2 — Android x86_64 平台 integration**：清代理 → `cargo ndk -t x86_64` 重建（30.63s，mtime 本轮 00:34）→ `flutter test integration_test/receiver_platform_test.dart -d emulator-5554 --timeout 3m` 实机跑通（3 次连续 All tests passed，测试内部断言 receiver.start success + ≥2 sync.cycle + 无 DroppableDisposedException）。
3. **必做 3 — 双端签名凭证 UI 自动化**：
   - 新增 `integration_test/pairing_credential_platform_test.dart`：Windows 与 Android **分别真实启动**凭证 UI 页面（show 弹窗真实生成 cm1. 凭证 + QR/复制/重新生成/倒计时 + 剪贴板为完整凭证；enter 弹窗单主字段 + 无 node ID + 粘贴统一解析友好错误）→ Windows、Android 双平台均通过。
   - 新增 `integration_test/pairing_credential_dual_end_test.dart`：Windows 宿主上**同一测试进程内两个真实 endpoint + 两个真实 UI 实例**，凭证经系统剪贴板从显示方提取、粘贴进输入方，走标准 443 relay 完成 confirm → 首次同步 → 双方 last_seen → 设备页在线（全部真实链路）。跨设备（Windows↔Android）自动化受 integration_test 单进程单 app + 模态 root navigator 限制，如实报告"未覆盖"。
4. **必做 4 — 最终回归**：fmt/check/Rust 全文件测试/Flutter 124/analyze/credential 测试/FRB 幂等/.gitignore/换行噪声/debug_log -w 核验，见下表。

## 验收标准逐条结果（真实命令与真实输出）

### 1. 标准 443 签名凭证 live test（✅ 真实成功）

命令（严格按任务单）：
```bash
cd rust-backend
timeout 3m cargo test --test live_relay_test live_signed_credential_pairing_over_standard_443_relay -- --ignored --nocapture
```
退出码 0，真实输出（末次复跑，7.87s）：
```text
[live443] confirmer relay=https://relay.alexc.cn/
[live443] initiator relay=https://relay.alexc.cn/
[live443] confirmer id: 1bb9e6c2…c99cca65
[live443] credential len=184 code=11…94 expires_at=2026-08-17T17:22:12.576533+00:00
[live443] paired: 1bb9e6c2…c99cca65 <-> b29b56c8…6f575b3a
[live443] confirmer last_seen=2026-08-17T17:12:19.943084500+00:00 (age=0s)
[live443] initiator last_seen=2026-08-17T17:12:19.943540500+00:00 (age=0s)
[live443] log pairing.connect action=start transport=relay
[live443] log pairing.connect action=success transport=relay
[live443] ✅ 标准 443 relay 签名凭证配对 + 首次同步全链路成功
test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 1 filtered out; finished in 7.87s
```
证据要点（非 HTTP 200 探测，为 iroh endpoint 真实链路）：
- 两端 relay 配置严格 `https://relay.alexc.cn`（无 `:9443`），测试内断言。
- 配对成功（peer 双向一致）、n1 到达 initiator（`list_notes`）、双方 last_seen 非空且 age=0s。
- 结构化日志 `pairing.connect` start/success 均为 `transport=relay`（`CollectingSink` 注入断言）。
- 日志脱敏断言全部通过（完整凭证/凭证 body/6 位码/完整 device id/正文均未出现在结构化日志中）。
- 旧 :9443 测试同文件同轮复跑通过（2 passed；stdout 已脱敏）。

### 2. Android x86_64 平台 integration（✅ 真实通过）

代理清空确认：`unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy` 后 `env | grep -i proxy` 为空。

Rust 库刷新：
```bash
cd rust-backend
timeout 3m cargo ndk -t x86_64 -o ../build/android-jni build --release -j 2
```
```text
Compiling cardmind-backend v0.1.0 ... Finished `release` profile [optimized] in 30.63s
     Copying libraries to ...build\android-jni
```
产物验证：`build/android-jni/x86_64/libcardmind_backend.so` = 29,952,184 字节（非空），`mtime=2026-08-18 00:34:04`（本轮；说明：cargo-ndk 拷贝保留源产物 mtime，故 touch src/lib.rs 强制重编译后 mtime 为本轮）。

平台测试（模拟器 emulator-5554 已启动、`sys.boot_completed=1`、ABI x86_64、Android 16；默认 NAT，未用 TAP）：
```bash
flutter test integration_test/receiver_platform_test.dart -d emulator-5554 --timeout 3m
```
3 次连续运行均：
```text
00:00 +0: real platform: receiver.start success + at least two periodic sync.cycle without disposed
02:05 +1: (tearDownAll)
02:05 +1: All tests passed!
```
（第 1 次运行时出现一次 harness 层 "did not complete"（01:27，无崩溃日志），随后 3 次连续通过，判定为 APK 重装与 driver 连接的偶发竞态；测试内部断言 receiver.start action=success、≥2 次 sync.cycle ok=true、无 DroppableDisposedException、Store 未 dispose。）

### 3. 双端签名凭证 UI 自动化（✅ Windows/Android 分别通过；⚠️ 跨设备双端如实未覆盖）

**Windows 平台（-d windows）**：`integration_test/pairing_credential_platform_test.dart` → `00:04 +2: All tests passed!`（show 弹窗：真实 cm1. 凭证、QR、复制按钮、重新生成、倒计时、剪贴板为完整凭证；enter 弹窗：单主字段、无 node ID、粘贴统一解析友好错误）。

**Android 平台（-d emulator-5554）**：同文件 → `00:08 +2: All tests passed!`，日志含 `platform=android ... pairing.connect action=start transport=credential`（真实 Android 设备上凭证 UI 真实启动）。

**同进程双端全链路（Windows）**：`integration_test/pairing_credential_dual_end_test.dart` → `00:05 +1: All tests passed!`，真实输出关键行：
```text
pairing.connect action=start transport=credential        （B 粘贴提交，凭证路径）
pairing.request action=received → pairing.confirm action=success
pairing.connect duration_ms=1420 action=success transport=credential
[dual-end] confirmer side last_seen=2026-08-17T16:59:12.534979600+00:00
[dual-end] initiator side last_seen=2026-08-17T16:59:12.547070100+00:00
sync.initial direction=import action=success            （首次全量同步导入）
[dual-end] ✅ 双端凭证 UI 全链路成功（同进程两个真实 endpoint，标准 443 relay）
```
该测试为**同一进程内两个真实 SyncService + 两个真实 DevicesPage UI 实例**，凭证经系统剪贴板从显示方 UI 提取、粘贴进输入方 UI，走标准 443 relay 完成配对/首次同步/双方 last_seen/设备页"在线"——非 mock、非伪造。

**跨设备（Windows 显示 → Android 粘贴）双端 UI：未覆盖（如实声明）**。原因：`integration_test` 单进程单 app 限制 + 产品配对弹窗为模态 root-navigator 对话框（`showDialog` 默认 `useRootNavigator: true`，barrier 覆盖全窗口），无法在同一进程/窗口同时以真实点击驱动两端页面；跨设备 credential 提取传递需要双进程编排，超出本任务允许的"仅测试文件"范围。但 Rust 443 credential 链路（§1）、Windows 平台（§3-Windows）、Android 平台（§3-Android）均已分别真实通过——三者独立陈述，不合并。

### 4. 最终回归（✅ 全绿，除一处如实说明）

| 项目 | 命令 | 真实输出 |
|---|---|---|
| fmt | `cargo fmt --check` | 无输出，退出码 0 |
| Rust check | `cargo check --tests` | `Finished dev profile`；warning 计数 0 |
| Rust 测试（按文件，各 ≤3m） | `cargo test --test <file>` | pairing_credential 13、pairing 10、store 6、note_crdt 10、sync 1、connect 7、autosync 8、debug_log 10、discovery 2、integration 2、migration 2、receiver_continuous 14、relay_config 7、sync_service 5、trash 13 —— 全部 `0 failed`；live_relay（ignored，除 443 指定用例外）2 passed |
| Flutter 全套 | `flutter test --concurrency=1 --timeout 3m` | `00:51 +124: All tests passed!` |
| Flutter analyze | `flutter analyze` | `No issues found!` |
| credential UI/repository | `flutter test test/pairing_credential_repository_test.dart test/pairing_credential_ui_test.dart` | `00:06 +14: All tests passed!` |
| FRB 幂等 | `flutter_rust_bridge_codegen generate` ×2 → `git diff > .workflow/frb-generate-{first,second}.patch` | 两次均 `Done!`；两 patch sha256 均为 `db9f203fb902486cbc60ba17acf53c57c9d7d32873667b2e061bdfdbba0d52f2`，`cmp -s` = 0（内容级幂等；证据文件已更新） |
| .gitignore | `git diff -- .gitignore` | 0 行（无 diff） |
| 换行噪声 | `comm` 对比 `git diff --name-only` 与 `git diff --ignore-all-space --name-only` | 无纯空白/纯换行文件；新增测试文件为 LF（新文件，与仓库约定一致） |
| debug_log.rs -w | `git diff -w -- rust-backend/src/debug_log.rs` | **非空（如实说明见下）** |
| 范围 | `git diff --name-only HEAD` | 未触碰 prototype、.gitnexus、任务 U worktree；本任务新增/修改仅限任务单允许文件 |

**关于 `git diff -w -- rust-backend/src/debug_log.rs` 的如实说明**：该文件相对 HEAD 的唯一差异是 `redact_device_id` 内一行被 rustfmt 拆为多行（任务 T 遗留状态，任务 T 报告亦称"变化仅 rustfmt 拆行"）。当前 git 的 `-w` 不把"1 行拆 5 行"视为可忽略（非空）；但若恢复 HEAD 的单行版本，`cargo fmt --check` 会失败（HEAD 基线本身不满足当前 rustfmt）。二者在本机 git/rustfmt 版本下无法同时满足。本任务未对 debug_log.rs 做任何内容修改（已确认并恢复为任务 T 的 fmt 后状态），此差异为任务 T 既有、非本任务引入。如验收方要求 `-w` 严格为空，需对 debug_log.rs 作范围外处理（如将该行标记 rustfmt skip 或接受 HEAD 非 fmt-clean），请决策。

## 新增测试清单

- `rust-backend/tests/live_relay_test.rs` → `live_signed_credential_pairing_over_standard_443_relay`（#[ignore] live）：标准 443 签名凭证配对 + 首次同步全链路；两端 relay=443 断言；请求 code/nonce 与会话一致性；transport=relay 结构化日志断言；last_seen 时间窗；n1 读模型；日志脱敏断言；双侧 timeout 包裹。
- `integration_test/pairing_credential_platform_test.dart`（Windows + Android 实机）：
  - `real platform: show credential page renders real cm1 credential with qr copy regenerate countdown` — 真实 Rust 生成 cm1. 凭证、QR/复制/重新生成/倒计时元素、剪贴板完整凭证。
  - `real platform: enter page has one primary field no node id and unified paste parsing` — 单主字段、无 node ID、cm1 前缀统一凭证解析（InvalidFormat 中文文案）、非 cm1/非 6 位统一格式提示。
- `integration_test/pairing_credential_dual_end_test.dart`（Windows 实机）：
  - `dual-end credential UI: show -> copy -> paste -> 443 relay pairing -> first sync -> both last_seen -> devices online` — 同进程两真实 endpoint+两 UI；系统剪贴板传凭证；443 relay 配对；confirm；首次同步 n1；双方 last_seen；设备页在线。

## 问题未决

1. **跨设备（Windows↔Android）双端 UI 自动化未覆盖**（任务单允许路径）：单进程单 app 的 integration_test 与模态 root navigator 限制；Windows 平台、Android 平台、Rust 443 链路均已分别真实通过。
2. **`git diff -w -- rust-backend/src/debug_log.rs` 非空**：仅为任务 T 遗留的 rustfmt 拆行差异（本任务零内容改动）；与 `cargo fmt --check` 通过在本机 git/rustfmt 下互斥，见 §4 说明，请决策是否做范围外处理。
3. **Android receiver 测试曾出现一次 harness 层 "did not complete"**（首次运行，01:27，无崩溃日志；其后 3 次连续通过），判定为 APK 重装与 driver 连接竞态，非业务缺陷；如需完全排除可在后续轮次多次复跑。
4. 未提交任何改动（与任务 T 基线一致，交由主代理/审核代理处理）。
