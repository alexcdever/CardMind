# Reviewer 审核报告 — 任务 H：自动同步调度

- 审核时间：2026-08-15
- worktree：`D:/Projects/CardMind/.worktrees/autosync`（分支 `codex/autosync`，基线 040e1c77）
- 审核对象：任务单"同步网络模块 4（任务 H）：自动同步调度"全部验收标准
- 方法：独立实机执行全部验证命令 + 逐文件代码审查 + 决策点核对（不盲信 executor 报告）

---

## 一、验收标准逐条复验结果

### Rust 集成测试（autosync_test.rs，6 条）

命令：`cargo test --test autosync_test -- --nocapture`（workdir=rust-backend）

真实输出（关键行）：
```
running 6 tests
test test_edit_not_blocked_by_network ... ok
test test_sync_disabled_blocks_push ... ok
test test_edit_triggers_push ... ok
test test_pending_count_tracks_unsynced ... ok
test test_periodic_pull_syncs_notes ... ok
[sync] push to 3128addd... failed (silent): push timeout after 10s
test test_push_failure_silent ... ok

test result: ok. 6 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 10.35s
```
注：编译期有 2 个 `unused_mut` warning（pair_up 参数 mut initiator/confirmer，测试代码 nit 级）。

| # | 用例 | 结果 | 证据 |
|---|------|------|------|
| 1 | test_edit_triggers_push | PASS | A create 后 pending>=1 → push_pending ok → B import 后 get_note 返回新内容 → pending 归零 |
| 2 | test_periodic_pull_syncs_notes | PASS | run_sync_cycle 后 B 可见 A 的笔记，pushed_count>=1 |
| 3 | test_sync_disabled_blocks_push | PASS | set_sync_allowed(false) 后 push 空结果、B 无更新、pending 保留；恢复 true 后推送成功 |
| 4 | test_pending_count_tracks_unsynced | PASS | 初始 0 → 编辑后 1（同笔记多次编辑计 1）→ 推送成功后 0 |
| 5 | test_edit_not_blocked_by_network | PASS | 无对端时编辑耗时 <2s（实际秒级返回）、push_pending 空结果 |
| 6 | test_push_failure_silent | PASS | 对端 drop 后编辑成功 <2s、push 结果失败/空、无错误抛出、pending 保留（10s 超时为既有设计） |

### 回归验收

| # | 命令 | 真实输出 | 结果 |
|---|------|----------|------|
| 9 | cargo test（全量） | 13 组 test result 全部 ok，合计 60 通过 0 失败（6+7+2+2+2+10+6+6+5+1+13=60） | PASS |
| 10 | flutter pub get && flutter test | pub get 成功（Changed 115 dependencies，connectivity_plus 6.1.5 解析）；flutter test `00:16 +56: All tests passed!` | PASS |
| 11 | flutter analyze | `No issues found! (ran in 25.7s)` | PASS |
| 12 | flutter_rust_bridge_codegen generate | `Done!`；跑前/跑后 git status 文件集合完全一致，幂等 | PASS |
| 13 | git status 改动范围 | 见下方范围核对 | PASS（含 2 项说明） |

### Flutter repository 测试（2 条）

命令：`flutter test`（全量，含 test/sync_scheduler_test.dart）

```
00:16 +56: All tests passed!
```
- 验收 7（scheduler responds to connectivity）：PASS — fake monitor emit(false/true) → setSyncAllowedCalls 记录正确（蜂窝暂停、WiFi 恢复）
- 验收 8（repository save triggers background push）：PASS — create/updateMetadata/softDelete/restore/purge 后 noteEditedCalls 依次 1..5

---

## 二、改动范围核对（验收 13）

git status 完整清单（复验时）：
```
 M .workflow/executor-report.md           （报告文件，允许）
 M lib/bridge/bridge_helper.dart          （范围内）
 M lib/bridge/frb_note_repository.dart    （范围内）
 M lib/src/rust/api.dart                  （FRB 生成，允许）
 M lib/src/rust/sync.dart                 （FRB 生成，允许）
 M lib/src/rust/frb_generated*.dart       （FRB 生成，允许）
 M lib/src/rust/discovery.dart            （仅行尾触碰，diff 无内容差异）
 M lib/src/rust/store.dart                （仅行尾触碰，diff 无内容差异）
 M linux/windows/flutter/generated_plugin_registrant.*、generated_plugins.cmake（flutter pub get 自动生成，允许）
 M pubspec.lock / pubspec.yaml            （范围内：connectivity_plus）
 M rust-backend/src/api.rs / sync.rs / frb_generated.rs（范围内 + codegen 产物）
?? lib/bridge/sync_scheduler.dart         （范围内新增）
?? rust-backend/tests/autosync_test.rs    （范围内新增）
?? test/sync_scheduler_test.dart          （范围内新增）
```

**禁止目录零改动**：`git status --short -- lib/pages docs prototype .gitignore` 输出为空。✅

说明 1：`lib/bridge/note_repository.dart` 任务单列入改动范围，但实际**未改动**——接口无新方法，onLocalChange 回调通过 FrbNoteRepository.open 参数注入，不需要改接口。合理，不算漏项。
说明 2：pubspec.lock 中所有依赖 url 从 `pub.flutter-io.cn` 变为 `pub.dev`——**这是 reviewer 复验时运行 `flutter pub get` 未设 PUB_HOSTED_URL 造成的副作用**（本审核会话的 bash 权限规则拦截了 `PUB_HOSTED_URL=... flutter ...` 前缀命令），非 executor 改动。合并时建议以镜像环境重跑 pub get 还原，或接受 url 差异（功能无影响）。

---

## 三、代码审查发现的问题清单

### blocker
无。

### major（1 项）

**M1. `accept_pairing_request` 重构后丢弃推送帧数据（数据丢失路径）**
- 位置：`rust-backend/src/sync.rs:399`（`let _ = self.accept_incoming_routed(incoming).await;`）
- 证据：`accept_pairing_request` 改为 500ms 短窗口轮询后，若收到的是**推送帧**（非配对帧），`accept_incoming_routed` 会完整读取 payload（`read_to_end`）并 `conn.close`，然后返回 `Ok(Some(data))`——但调用处 `let _ =` 直接把数据**丢弃**，且连接已被消费、对端 `push_to_peer` 的 `conn.closed()` 正常返回、发送端 `mark_synced_all` 会清空 pending。
- 触发场景：确认方正在等待配对请求（周期 accept 与配对 accept 争用同一 endpoint 通道），对端推送恰好被配对 accept 抢到 → 推送数据被读走并静默丢弃 → 对端认为推送成功（pending 归零）→ 笔记内容丢失。这与需决策点 3 的"不冲突"结论相矛盾：executor 的方案只解决了"配对帧被周期 accept 抢到"的方向（存入 pending_pairing 供 confirm_pairing 使用），未解决"推送帧被配对 accept 抢到"的方向（数据被吞）。
- 严重度：major（低概率但为真实数据丢失路径，违背决策 4 的同步保证；测试未覆盖"配对等待期间对端推送"并发场景，`test_sync_disabled_blocks_push` 是配对完成后再 push，未触发此路径）。
- 修复方向（仅报告）：`accept_pairing_request` 中收到 `Ok(Some(data))` 时不应丢弃——应缓存/导入，或改为只 accept 配对帧的专用等待（如先检查 pending_pairing、非配对帧继续循环不读空连接）；或周期 accept 与配对 accept 分离等待器。由主代理打回 executor 决策。

### minor（3 项）

**m2. `run_sync_cycle` 的 `pushed_count` 语义**（sync.rs:1250）
- `pushed_count: u32::from(any_ok)` — 文档注释写"成功推送的对端设备数"，实际是布尔转 0/1（任意一台成功即为 1，多台成功仍为 1）。验收标准只断言 `>= 1` 不受影响，但字段语义与注释不符。FRB 已暴露给 Flutter，未来 UI 计数会不准确。

**m3. test 编译警告 unused_mut**（autosync_test.rs:24/26）
- `pair_up` 参数 `mut initiator` / `mut confirmer` 不需要 mut。cargo test 输出 2 条 warning，非失败但建议清理。

**m4. `mark_all_pending` 未覆盖 purge_expired 新建墓碑**（sync.rs:718-751）
- `purge_expired` 直接 `tombstones.insert` 且**未调用 mark_sync_pending**（与 purge_note 不同）。若过期清理发生在无对端推送成功后（pending 已空），被清理的墓碑 id 不会进入待同步集，重启后 `mark_all_pending` 会重新标记全部（有兜底），但同一进程内后续 `push_pending` 可能不带新墓碑。影响：对端可能保留已过期笔记直到下次全量周期（周期本身 push 全量，实际影响有限）。属边界 nit，报告备案。

### nit（2 项）

**n1. `peer_ips` 内存态**：重启清空后周期推送退化为 relay/地址解析路径，与 executor 报告一致，备案。
**n2. `test_push_failure_silent` 单测耗时 10s**：对端离线时 `push_to_paired_devices` 单台超时 10s 为既有设计，全量回归因此 +10s，已确认。

---

## 四、需决策点核对结论

| 需决策点 | executor 处理 | 复核结论 |
|---------|--------------|---------|
| 1. Rust spawn 生命周期冲突 | 选 Flutter 侧触发（Timer.periodic + fire-and-forget），规避 tokio::spawn 'static 问题 | ✅ 正确规避：SyncService 为 FRB opaque 无 Arc，spawn 会冲突；Flutter 侧触发满足"编辑立即返回、推送异步、失败静默"，且测试确定性好 |
| 2. connectivity_plus 兼容 | 6.1.0 安装成功、Windows 无异常，未触发决策点 | ✅ 正确：pub get 实际解析 6.1.5，`List<ConnectivityResult>` API 按 6.x 编写，`_allowedForType` 映射正确（mobile→false，其余→true） |
| 3. accept 通道争用 | 声称统一帧路由"不冲突" | ⚠️ **不完整**：配对帧被周期 accept 抢到→存入 pending_pairing（安全方向✅）；但推送帧被配对 accept 抢到→数据被读走丢弃（M1 数据丢失路径❌）。需决策点 3 未完全规避，应打回补充方案 |

---

## 五、总评

**FAIL（需打回修复 M1 后可合并）**

- 验收标准 1–13 全部实机 PASS（6 条 Rust 新增 + 2 条 Flutter 新增 + 60 全量回归 + 56 Flutter 回归 + analyze 零问题 + codegen 幂等 + 范围合规）。
- executor 自检报告的真实性：**基本属实**——本审核独立执行的所有命令输出与 executor 报告一致（60/56/0 失败/No issues/Done!）。
- 但代码审查发现 1 项 major 数据丢失路径（M1：配对等待期间推送帧被配对 accept 抢到并丢弃），且需决策点 3 的结论与代码现实不完全一致（executor 只论证了安全方向）。按"发现问题就如实报告"纪律，判定 FAIL，要求打回修复 M1 并补充相应并发测试（配对等待期间对端推送的集成测试）后再合并。
- 次要项（m2/m3/m4/n1/n2）不阻塞合并，可随修复一并处理。

---

# 第二轮复验报告（M1 修复核验 + 新发现 M2）

- 审核时间：2026-08-15（第二轮）
- 对象：executor 对第一轮 FAIL 结论的修复（M1/m2/m3/m4/pubspec 还原）
- 方法：逐文件代码审查 + 全量实机重跑（独立执行，不盲信 executor 报告）

## 一、第一轮问题修复核验

### 🔴 M1（accept_pairing_request 丢弃推送帧）— **PASS**

代码核验（rust-backend/src/sync.rs:390-424）：
- `accept_pairing_request` 已改为 `pub async fn accept_pairing_request(&mut self)`（&mut 签名）；
- 收到 `Ok(Some(data))`（推送帧）时立即 `self.import_all(&data)` 导入，失败仅 `eprintln` 容忍，不中断配对等待；
- 收到 `Ok(None)`（配对帧，已路由存入 pending_pairing）继续循环；`Err` 记录日志继续；
- 无死锁风险（import_all 不涉及 endpoint accept；pending_pairing 锁在分支内短期持有）；
- 无循环饥饿（import 是同步操作，完成后继续下一轮 500ms accept）。

连带改动核验：
- `api.rs:44` `accept_pairing_request(svc: &mut SyncService)` 签名同步 ✅
- `pairing_test.rs:172` `test_pairing_persists_both_sides` 的 confirmer 补 `mut`；`test_pairing_triggers_initial_full_sync`（L243）原有 `mut` ✅（两处 accept_pairing_request 调用点均满足 &mut）
- `autosync_test.rs` 新增 `test_pairing_wait_does_not_drop_push`（L310-378）✅
  - 断言有效性核验：测试让 B 先 `begin_pairing_accept` 进入配对等待轮询，再让 A 推送 → 若修复被回退（丢弃），`b.get_note("n1")` 为 None，L371-375 断言必失败——**测试真实覆盖 M1 路径** ✅

实机验证：
```
cargo test --test autosync_test
running 7 tests
test test_edit_not_blocked_by_network ... ok
test test_edit_triggers_push ... ok
test test_pending_count_tracks_unsynced ... ok
test test_sync_disabled_blocks_push ... ok
test test_pairing_wait_does_not_drop_push ... ok
test test_periodic_pull_syncs_notes ... ok
test test_push_failure_silent ... ok
test result: ok. 7 passed; 0 failed; ... finished in 10.32s
```
→ 7/7 通过，**无任何 warning**（m3 同时核验通过）。

### 🟡 m2（pushed_count 语义）— **PASS**
sync.rs:1275：`let pushed_count = results.iter().filter(|r| r.ok).count() as u32;` — 真实成功设备数，与结构体注释一致 ✅

### 🟡 m3（unused_mut warning）— **PASS**
autosync_test.rs 编译无 warning（上面 cargo test 输出无 warning 行）；`pair_up` 的 initiator 已去 mut ✅

### 🟡 m4（purge_expired 未 mark_sync_pending）— **PASS**
sync.rs:767-773：persist 成功后 `for id in &expired { self.mark_sync_pending(id); }`，与 purge_note 一致 ✅

### ⚪ pubspec.lock 还原 — **PASS**
`grep -c "pub.flutter-io.cn" pubspec.lock` = **116**；`grep -c "pub.dev" pubspec.lock` = **0** — url 已全部还原为镜像源，无 pub.dev 残留 ✅（executor 声明属实）

## 二、回归复验（全量实机重跑）

| # | 命令 | 真实输出 | 结果 |
|---|------|----------|------|
| 9 | cargo test 全量 | 13 组全 ok，**61 通过 0 失败**（7+7+2+2+2+10+6+6+5+1+13=61），无 warning | PASS |
| 10 | flutter test（依赖已就绪，未重复 pub get 以免再扰动 lock） | `00:06 +56: All tests passed!` | PASS |
| 11 | flutter analyze | `No issues found! (ran in 20.3s)` | PASS |
| 12 | codegen 幂等 | `Done!`；跑前（status_before_codegen.txt）与跑后（status_after_codegen.txt）文件集合完全一致 | PASS |
| 13 | git status 范围 | 新增 `rust-backend/tests/pairing_test.rs`（M1 适配，允许）；禁止目录 lib/pages、docs、prototype、.gitignore **零改动** | PASS |

## 三、新增问题清单

### 🔴 M2（major，新增）：推送帧首字节与配对帧标记冲突 → 墓碑数为 1（或 257/513…）时推送被误判为配对帧、数据丢失

- **位置**：`rust-backend/src/sync.rs:1093`（accept_incoming_routed 帧路由判定）
- **证据链**（代码实读）：
  1. `PAIRING_FRAME_REQUEST = 0x01`（sync.rs:165）；`accept_incoming_routed` 以 **单字节** `first[0] == 0x01` 判定配对帧，否则按推送帧处理（sync.rs:1091-1107）。
  2. 推送网络发送的是 `export_all()` 的输出（`push_to_peer_once` 直接 `send.write_all(data)`，data = export_all 结果，**不带** CARDMIND envelope——envelope 仅用于持久化文件，sync.rs:1022-1035）。
  3. `export_all()` 首 4 字节 = `self.tombstones.len() as u32` 的 LE 编码（sync.rs:792）。当推送方**有 1 个墓碑**（或 257、513…，即数量 ≡ 1 mod 256）时，payload 首字节 = `0x01` = `PAIRING_FRAME_REQUEST`。
  4. 该推送帧被 accept_incoming_routed **误判为配对帧** → 走 `decode_pairing_request` 分支 → 解析失败返回 `Err`（推送 payload 不是配对请求格式）→ 数据被丢弃。
  5. 连接行为：误判分支中 decode 失败后 `conn` 被 drop → 对端 `push_to_peer_once` 的 `conn.closed()` 返回（或 10s 超时）→ `push_to_paired_devices` 判定 ok → `push_pending` 的 `mark_synced_all` **清空 pending** → 数据丢失且无重试（下次周期/编辑推送仍同样误判，因为墓碑数不变）。
- **触发条件**：推送方删除过 1 篇笔记（tombstones = 1，非常常见）后向对端推送。任何 accept 路径均受影响：周期 `try_accept_push`、配对等待 `accept_pairing_request`、`accept_push`。
- **为何现有测试未覆盖**：M1 新测试中 A 只 create_note（墓碑 0 → 首字节 0x00，安全）；tombstone 相关测试（sync_service_test）走 export/import 直传、不经 accept_incoming_routed 路由。**无任何测试覆盖"推送方有墓碑时的网络推送"**。
- **严重度**：major（确定性触发的数据丢失/同步失败路径，与 M1 同类但触发面更广——不需配对窗口，任何带墓碑推送都触发）。不在任务单验收标准内，但属真实数据丢失，按纪律必须报告。
- **修复方向（仅报告，不代修）**：帧路由不能用单字节区分。建议：推送帧在网络上带固定 magic 前缀（如 LORO_MAGIC "CARDMIND"），accept_incoming_routed 读首 8 字节比对 magic 判定推送帧、首字节 0x01 判定配对帧；或配对请求帧改用不会与推送首字节冲突的标记。需主代理打回 executor 决策并补测试（推送方 1 墓碑的网络推送集成测试）。

## 四、需决策点核对（第二轮更新）

| 需决策点 | 结论 |
|---------|------|
| 1. Rust spawn 生命周期 | ✅ 维持（Flutter 侧触发规避，无变化） |
| 2. connectivity_plus 兼容 | ✅ 维持（6.1.5 解析正常） |
| 3. accept 通道争用 | ⚠️ M1 修复后"配对等待期间抢到推送帧不丢弃"方向已解决，但**帧路由单字节判定存在 M2 冲突**，需决策点 3 仍未完全关闭 |

## 五、总评（第二轮）

**FAIL（需打回修复 M2 后可合并）**

- 第一轮 FAIL 的 5 项（M1/m2/m3/m4/pubspec 还原）**全部修复到位且实机复验通过**：7/7 autosync 测试、61 全量 Rust、56 Flutter、analyze 零问题、codegen 幂等、范围合规、lock 还原。
- 但代码审查发现**新增 major 问题 M2**（推送帧首字节与配对帧标记 0x01 冲突，墓碑数为 1 时推送被误判丢弃、pending 被清空、数据丢失），第一轮与第二轮均未被测试覆盖。按"发现问题如实报告"纪律，判定 FAIL，要求打回修复 M2（帧路由 magic 判定 + 对应集成测试）后再合并。
- 复核说明：M2 为代码路径推演结论（export_all 布局 / push_to_peer_once 发送体 / accept_incoming_routed 判定三处代码实读），未实机复现（复现需新增测试文件，超出审核只读权限）；建议主代理打回后由 executor 补红测试验证。

---

# 第三轮复验报告（M2 修复核验）

- 审核时间：2026-08-15（第三轮）
- 对象：executor 对第二轮 FAIL 结论（M2 帧路由冲突）的修复
- 方法：逐文件代码审查（发送/接收双端 + 测试断言有效性）+ 全量实机重跑（独立执行）

## 一、M2 修复核验 — **PASS**

### 代码审查（发送端双路径全覆盖 + 接收端 magic 判定）

**发送端**：
- `encode_push_wire(payload)` = `LORO_MAGIC(8B "CARDMIND") + payload`（sync.rs:1384-1389）
- `push_to_peer`（L947）`let wire = encode_push_wire(&data);` 发送 wire ✅
- `push_to_peer_once`（L1054）`send.write_all(&encode_push_wire(data))` ✅（临时 Vec 引用传给 write_all 无悬垂——write_all 在 await 前复制进 iroh buffer，编译通过且测试验证）
- **配对自动同步路径**（confirm_pairing 调 push_to_peer）随 push_to_peer 覆盖 ✅
- 持久化 envelope（encode_envelope/decode_envelope，L1371/1397）**未改动**——仅网络线格式加前缀 ✅

**接收端** `accept_incoming_routed`（sync.rs:1096-1131）：
- 读满 8 字节 `let mut marker = [0u8; LORO_MAGIC.len()]; recv.read_exact(&mut marker)` ✅
- `&marker == LORO_MAGIC` → 推送帧：读剩余 payload、close、返回**剥离 magic 后** `Ok(Some(data))`（data = export_all 输出，import_all 原格式直接消费）✅
- `marker[0] == PAIRING_FRAME_REQUEST(0x01)` → 配对帧：`marker(8B) + rest` 构成完整帧（从 0x01 开始），decode_pairing_request 正确解析 ✅
- 其他 → `anyhow::bail!("unknown incoming frame marker")` ✅
- **分支互斥确认**：magic 首字节 0x43 ≠ 0x01，两个判定条件不可能同时命中；配对帧格式未变（仍 0x01 开头）✅

### 新增问题排查（read_exact / 阻塞 / 短包）
- 短包/半包：`read_exact` 读不满 8 字节返回 Err → accept_push/try_accept_push 中 Err 传播；accept_pairing_request 中 Err 容忍继续（既有模式，无新风险）✅
- marker 读取阻塞：read_exact(8) 需对端发送完整 marker，正常发送端总是先发 8 字节 magic 或 0x01 开头配对帧，无阻塞路径 ✅
- 配对帧最小长度远超 8 字节（code 10B + id + name + relay + ips），read_exact(8) 不会截断配对帧 ✅

### 测试有效性核验（test_push_with_tombstone_not_misrouted，autosync_test.rs:312-375）
- 前置断言：`a.tombstones().contains("del-note")` + `exported[0] == 0x01`（墓碑=1 诱因真实存在）✅
- 断言点：① A 推送成功 ② B 可见 keep-note（推送未被误判丢弃）③ del-note 不复活（墓碑传播）④ B.tombstones() 含 del-note ⑤ A.pending_sync_count()==0 ✅
- **回退验证推理**：若回退到旧单字节判定，A 推送帧（wire 无 magic 或 B 端旧判定）首字节 0x01 → B 误判配对帧 → decode_pairing_request 解析失败 → B 端 accept_push().unwrap() panic / 主线程"推送应成功"断言失败——测试必失败 ✅

### 存量 pairing_test 零回归
- pairing_test.rs 6 条测试（L40/97/127/170/241/312）全绿（见全量回归，running 2/6 组 ok，0 failed）✅

## 二、回归复验（全部实机重跑）

| # | 命令 | 真实输出 | 结果 |
|---|------|----------|------|
| 1 | cargo test --test autosync_test | `running 8 tests` ... `test result: ok. 8 passed; 0 failed; ... finished in 10.36s`，无 warning | PASS |
| 2 | cargo test 全量 | 13 组全部 ok，**62 通过 0 失败**（8+7+2+2+2+10+6+6+5+1+13），无 warning | PASS |
| 3 | flutter test | `00:06 +56: All tests passed!` | PASS |
| 4 | flutter analyze | `No issues found! (ran in 20.0s)` | PASS |
| 5 | codegen 幂等 | `Done!`；跑前（status_before3.txt）/跑后（status_after3.txt）文件集合逐行一致 | PASS |
| 6 | git status 范围 | 新增仅 autosync_test/pairing_test 适配；禁止目录 lib/pages、docs、prototype、.gitignore **零改动** | PASS |
| 7 | pubspec.lock | 116 处 `pub.flutter-io.cn` / 0 处 `pub.dev`（未扰动） | PASS |

## 三、新增问题清单

无新增问题。

审慎排查过以下潜在点均确认安全：
- `&encode_push_wire(data)` 临时引用：无悬垂（write_all 内部复制）
- 配对帧判定完整性：marker 8 字节保留给 decode_pairing_request，帧首 0x01 不变
- 持久化兼容：v3 envelope 格式未动，仅网络传输层加前缀
- 跨版本约束：同仓收发同步改动，无跨版本场景

## 四、需决策点 3 结论（第三轮）

**已关闭**。统一帧路由经两轮加固：配对帧/推送帧识别从单字节升级为"8 字节 LORO_MAGIC + 0x01 标记"，推送 payload 首字节（墓碑数 LE）与配对帧标记的 0x01 冲突彻底消除。三条 accept 路径（周期 try_accept_push / 配对等待 accept_pairing_request / accept_push）统一走 accept_incoming_routed，数据丢失窗口全部关闭。

## 五、总评（第三轮）

**PASS（可合并）**

- M2 修复到位且实机验证通过：8/8 autosync（含 M2 墓碑误判回归 + M1 配对等待回归）、62 全量 Rust（含 pairing_test 6 条存量零回归）、56 Flutter、analyze 零问题、codegen 幂等、范围合规、lock 未扰动。
- 三轮回合：M1（配对等待丢推送）→ M2（帧路由 0x01 冲突）→ 均已修复并有红测试兜底；验收标准 1-13 三轮均实机 PASS。
- 建议：合并前按惯例由主代理确认工具副作用文件（linux/windows registrant、lib/src/rust/discovery.dart、store.dart 等行尾触碰）处理方式；确认后即可合并。
