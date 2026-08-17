# 任务 T2 审核报告 — 标准 443 签名凭证 + Android 平台 + 双端 UI + 最终回归

审核人：reviewer 子代理（独立实机复验，只报告不修改）
时间：2026-08-18
worktree：`D:/Projects/CardMind/.worktrees/signed-pairing-credential`
分支：`codex/signed-pairing-credential`

## 总体结论

- 必做 1（标准 443 凭证 live test）：**PASS**
- 必做 2（Android x86_64 integration）：**PASS**
- 必做 3（双端 UI 自动化）：Windows **PASS**、Android **PASS**、跨设备双端 = **未覆盖**（如实声明）
- 必做 4（最终回归）：**PASS**（除 debug_log.rs `-w` 门禁非空需决策，见问题清单）

executor 自检报告（.workflow/executor-report.md）全部关键结论经独立实机复验真实可复现，无虚假声称。本报告所有命令均为 reviewer 本机实跑，输出为真实终端输出。

---

## 必做 1：标准 443 签名凭证 live test — PASS

### 复验命令（照抄任务单）
```bash
cd rust-backend
cargo test --test live_relay_test live_signed_credential_pairing_over_standard_443_relay -- --ignored --nocapture
cargo test --test live_relay_test -- --ignored --nocapture   # 同文件全部
```

### 真实输出（单独跑 443 测试，3.54s，退出码 0）
```text
[live443] confirmer relay=https://relay.alexc.cn/
[live443] initiator relay=https://relay.alexc.cn/
[live443] confirmer id: 2abd8e89…32a225d2
[live443] credential len=184 code=82…42 expires_at=2026-08-17T17:25:20.730603200+00:00
[live443] paired: 2abd8e89…32a225d2 <-> 63e7339f…ff16f996
[live443] confirmer last_seen=2026-08-17T17:15:24.007397500+00:00 (age=0s)
[live443] initiator last_seen=2026-08-17T17:15:24.041603200+00:00 (age=0s)
[live443] log pairing.connect action=start transport=relay
[live443] log pairing.connect action=success transport=relay
[live443] ✅ 标准 443 relay 签名凭证配对 + 首次同步全链路成功
test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 1 filtered out; finished in 3.54s
```

### 逐项核对（源码 L179-484 + 实跑双证据）
| 验收要求 | 证据 | 结论 |
|---|---|---|
| relay 严格 https://relay.alexc.cn 不含 :9443 | 源码 L18 RELAY_URL_443=https://relay.alexc.cn；L200-201 两端 relay.txt 写标准 URL；L223-246 断言 urls.len()==1、starts_with、不含 :9443；实跑输出 relay=https://relay.alexc.cn/ | PASS |
| 两真实持久化 SyncService | L207-220 new_persistent_with_log_sink（真实磁盘目录） | PASS |
| confirmer 生成签名 credential 不依赖 mDNS | L252 begin_pairing_credential()（无广播调用） | PASS |
| initiator 只拿 credential 不输 node ID 不调 mDNS | L320 begin_pairing_connect_with_credential(&store, &credential)（凭证内嵌 endpoint） | PASS |
| request code/nonce 与会话一致 | L286-298 request.code == confirmer_code、request.nonce == nonce_to_hex(&session.nonce) | PASS |
| 首次全量 push → accept → import | L324-330 accept_push + import_all；实跑 sync.push/sync.receive/sync.import 日志 | PASS |
| 双方配对记录 | L367-378 list_paired_devices 双向查找 + name 断言 | PASS |
| 双方 last_seen 非空合理时间窗 | L380-396 age 0-600s 断言；实跑 age=0s | PASS |
| n1 在 initiator 可读 | L398-405 list_notes any id==n1 | PASS |
| 结构化日志 transport=relay | L407-444 CollectingSink 断言 pairing.connect start/success transport=relay；实跑两条均 relay | PASS |
| 产品日志无完整凭证/code/私钥/device id/正文 | L446-475 六项脱敏断言；实跑日志 ids 均掩码 | PASS |
| 人工 stdout 不打印完整 id/配对码 | 旧测试 L66-79 与 443 测试 L257-266 均 masked；实跑 code=82…42、23…54、id 掩码 | PASS |
| 双侧 timeout | spawn 内部 120s/90s + join 侧 150s/120s（L281-353） | PASS |

同文件旧 :9443 测试复跑：**2 passed; 0 failed**（3.90s），旧测试 stdout 已脱敏（pairing code: 23…54、confirmer id: dcfa68d8…ae17ac53）✅

---

## 必做 2：Android x86_64 平台 integration — PASS

### 复验命令与真实输出
```bash
cd rust-backend
cargo ndk -t x86_64 -o ../build/android-jni build --release -j 2
```
```text
Building x86_64 (x86_64-linux-android)
Compiling cardmind-backend v0.1.0 ... Finished `release` profile [optimized] in 29.09s
Copying libraries to ...build/android-jni
```
产物：`build/android-jni/x86_64/libcardmind_backend.so` = 29,952,184 字节（非空），mtime `8月 18 01:16`（本轮构建后）。

```bash
cd ..
flutter test integration_test/receiver_platform_test.dart -d emulator-5554 --timeout 3m
```
```text
00:00 +0: real platform: receiver.start success + at least two periodic sync.cycle without disposed
02:04 +1: (tearDownAll)
02:04 +1: All tests passed!
```
模拟器：emulator-5554 / Android 16 / ABI x86_64（flutter devices 确认在线）。

断言源码核对（receiver_platform_test.dart）：真实 RustLib.init() + createPersistentSyncService + createNoteStore（真实 DLL 非 mock）；L69-72 receiver.start action=success；L85-95 ≥2 sync.cycle ok=true 且 error 链不含 DroppableDisposedException；L96-97 store.isDisposed=false。全部实测通过。

---

## 必做 3：双端签名凭证 UI 自动化

### Windows 平台（-d windows）— PASS
命令：`flutter test integration_test/pairing_credential_platform_test.dart -d windows --timeout 3m`
真实输出：`00:04 +2: All tests passed!`；日志含 `pairing.show_code action=start`、`pairing.connect action=start transport=credential`、`discovery action=bypassed mdns_skipped=true`。

### Android 平台（-d emulator-5554）— PASS（实跑，非仅源码审查）
命令：`flutter test integration_test/pairing_credential_platform_test.dart -d emulator-5554 --timeout 3m`
真实输出：`00:07 +2: All tests passed!`；日志含 `platform=android ... pairing.connect action=start transport=credential`（真实 Android 设备上真实启动凭证 UI）。

### 同进程双端全链路（Windows）— PASS
命令：`flutter test integration_test/pairing_credential_dual_end_test.dart -d windows --timeout 3m`
真实输出：`00:04 +1: All tests passed!`，真实日志关键行：
```text
pairing.connect action=start transport=credential
pairing.request action=received → pairing.confirm action=success
pairing.connect duration_ms=1253 action=success transport=credential
[dual-end] confirmer side last_seen=2026-08-17T17:20:24.530744200+00:00
[dual-end] initiator side last_seen=2026-08-17T17:20:24.592200600+00:00
sync.initial direction=import action=success
[dual-end] ✅ 双端凭证 UI 全链路成功（同进程两个真实 endpoint，标准 443 relay）
```
源码核对（pairing_credential_dual_end_test.dart）：两个真实 FrbNoteRepository（test_harness.dart 真实 RustLib.init() + FrbNoteRepository.open，非 mock）；两个真实 DevicesPage UI；凭证经系统剪贴板从 A 提取、粘贴进 B；L139-163 双方设备表持久化断言；L166-171 双方 last_seen 非空；L178-187 首次同步 n1；L190-221 双方设备页「在线」+ 对端名称。B 的「添加设备」在 A 模态遮挡期间经 onPressed 直调生产处理器（非 mock），其后全部真实点击/输入。
### UI 旅程约束核对（源码）
- 显示页：pair-qr-image（二维码）、pair-code-display（6 位码）、pair-copy-button（复制完整 cm1. 凭证，>100 字符）、pair-regenerate-button、pair-code-countdown ✅
- 输入页：pair-credential-input 唯一 TextField（findsOneWidget）、无 pair-node-id-input ✅
- 粘贴/扫描统一解析：cm1 前缀走凭证解析入口，InvalidFormat → 「配对信息格式无效」中文友好文案；非 cm1/非 6 位 → 统一格式提示 ✅

### 跨设备（Windows↔Android）双端 UI — **未覆盖（如实声明）**
结论：**未覆盖**。原因（源码 + 平台约束）：integration_test 单进程单 app 限制 + 产品配对弹窗为模态 root navigator 对话框（showDialog 默认 barrier 覆盖全窗口），无法在同一进程同时以真实点击驱动两端页面；跨设备凭证传递需双进程编排，超出任务单允许范围。Windows 平台、Android 平台、Rust 443 链路分别独立陈述（各自真实通过），不合并。

---

## 必做 4：最终回归 — PASS（除 debug_log -w 门禁，见问题清单）

| 项目 | 复验命令 | 真实输出 | 结论 |
|---|---|---|---|
| fmt | `cargo fmt --check` | 无输出，退出码 0 | PASS |
| Rust check | `cargo check --tests` | Finished dev profile；0 warning | PASS |
| Rust 按文件 | `cargo test --test <file>` | pairing_credential 13、pairing 10、store 6、note_crdt 10、sync 1、connect 7、autosync 8、debug_log 10、discovery 2、integration 2、migration 2、receiver_continuous 14、relay_config 7、sync_service 5、trash 13 —— 全部 0 failed；live_relay（ignored）2 passed | PASS（数量与 executor 声称完全一致） |
| Flutter 全套 | `flutter test --concurrency=1 --timeout 3m` | `00:51 +124: All tests passed!` | PASS |
| analyze | `flutter analyze` | `No issues found!` (16.5s) | PASS |
| credential 专项 | `flutter test test/pairing_credential_repository_test.dart test/pairing_credential_ui_test.dart` | `00:06 +14: All tests passed!` | PASS |
| FRB codegen 幂等 | 亲自跑 `flutter_rust_bridge_codegen generate` 两次，每次 `git diff > patch` | 两次 patch blob hash 一致：939d0fceb682b211815dce0fd25bf61ff2b82c04 == 939d0fceb682b211815dce0fd25bf61ff2b82c04（git hash-object 内容级比较）；executor 留下的两个 patch 亦一致：ae02535092d77954ca5afb689b5e490f8910904a == 同 | PASS |
| .gitignore | `git diff -- .gitignore` | 空输出 | PASS |
| 换行噪声 | `git diff --name-only` vs `git diff --ignore-all-space --name-only` | 两个文件集合完全一致 → 无纯换行/纯空白变化文件 | PASS |
| debug_log.rs -w | `git diff -w -- rust-backend/src/debug_log.rs` | **非空**（见问题清单 1） | 需决策 |
| 范围 | `git diff --name-only HEAD` | 仅任务单允许文件；未触碰 prototype/、.gitnexus/；AndroidManifest 仅加 CAMERA 权限（QR 扫描）；lib/scanner/ 为任务范围内新文件 | PASS |

FRB codegen 幂等补充：executor 声称的 sha256（db9f203f…）与我实测的 git blob hash（939d0fce…）数值不同，但两者均为「两次生成输出内容完全一致」的等价证明（同一文件内容用任何哈希算法都相同）；我用 git hash-object 独立验证 executor 留下的两个 patch blob hash 相同（ae025350 == ae025350）。无矛盾。

---

## 问题清单

1. **`git diff -w -- rust-backend/src/debug_log.rs` 非空（需决策，非本任务引入）**
   - 位置：`rust-backend/src/debug_log.rs` L173-180 `redact_device_id` 内 `let suffix` 一行
   - 证据：diff 显示 `let suffix: String = chars.rev().take(8)...` 单行被 rustfmt 拆为 5 行（7 insertions / 1 deletion），token 序列完全相同，无内容实质变化；`cargo fmt --check` 当前通过（工作区版本 fmt-clean）；HEAD 版本（单行 >120 字符）在无 rustfmt.toml（默认 max_width=100）下必然被当前 rustfmt 拆行
   - 互斥判断：**成立**。git `-w` 只忽略行内空白，不把「1 行拆 5 行」视为可忽略；当前 rustfmt 又必然拆该行。因此「`git diff -w -- debug_log.rs` 为空」与「`cargo fmt --check` 通过」在本机 git/rustfmt 版本下**不可同时满足**。executor 说明属实（任务 T 遗留，本任务零内容改动）。若要该门禁通过需范围外处理（rustfmt::skip 标注或接受 HEAD 非 fmt-clean），请任务方决策。
2. **跨设备（Windows↔Android）双端 UI 自动化未覆盖**（任务单允许如实报告）：Windows/Android 平台与 Rust 443 链路各自独立真实通过，见必做 3 结论。

## 范围核查（越界检查）

- `git diff --name-only HEAD`：36 个修改文件 + 9 个新增路径，全部落在任务单允许范围（Rust 核心 / FRB 生成 / UI 页面 / 测试 / 依赖清单 / 平台插件注册 / AndroidManifest CAMERA 权限）。
- 未触碰 prototype/、.gitnexus/。任务 U worktree 为独立目录，本 worktree diff 不含其路径。
- 复验过程未修改任何业务/测试/报告文件：git status 前后一致；codegen 幂等未产生新 diff；审查 patch 写入系统 Temp 目录。

## 结论

四个必做项：**1 PASS / 2 PASS / 3 PASS(Windows+Android)+未覆盖(跨设备) / 4 PASS(一处需决策)**。executor 报告全部关键声称经独立实机复验真实可复现。唯一需任务方决策项为 debug_log.rs `-w` 门禁互斥问题（任务 T 遗留、非本任务引入）。无 FAIL 项，无需打回。
