# 独立审查报告：pairing-credential-ip

- task-id: `pairing-credential-ip`
- role: reviewer（独立复验，未参与实现；全程只读）
- worktree: `/Users/alexc/Projects/CardMind/.worktrees/pairing-credential-ip`
- branch: `pipeline/pairing-credential-ip`
- HEAD: `8b6ff7013017050fa552ccd222ee0a98cb4793b8`
- 证据目录: `.pipeline/pairing-credential-ip/`

## 1. 身份与范围核对 ✅

```
git rev-parse --show-toplevel → /Users/alexc/Projects/CardMind/.worktrees/pairing-credential-ip
git branch --show-current      → pipeline/pairing-credential-ip
git rev-parse HEAD             → 8b6ff7013017050fa552ccd222ee0a98cb4793b8
```

- **HEAD 等于契约提交** ✅（与 `git log` 首行一致）。
- `git status --short` 仅 10 个已跟踪文件 + `.pipeline/pairing-credential-ip/`（证据目录），全部落在契约 §4 允许范围：
  - `rust-backend/src/sync.rs`
  - `rust-backend/src/frb_generated.rs`（codegen）
  - `rust-backend/tests/pairing_credential_test.rs`
  - `lib/src/rust/sync.dart`、`lib/src/rust/frb_generated.dart`（codegen）
  - `test/pairing_{accept_ui,credential_ui,log_events,mdns_widget}_test.dart`、`test/sync_ui_widget_test.dart`（FRB 夹具 +1 行 `ips`）
- **`pubspec.lock` 干净** ✅：`git status --short pubspec.lock` 无输出。执行报告的「已还原」主张成立。
- **无越界残留** ✅：`git status --short lib/pages/devices_page.dart macos/Runner pubspec.yaml .github` 无输出。relay 策略 / entitlements / 版本号 / 发布工作流均未触碰。
- 执行报告声明的 HEAD 与文件清单与实测逐项一致（新鲜度 ✅）。

## 2. 协议正确性审查（读码，非仅跑测试）

### a) v2 布局与契约 §3 逐字节核对 ✅

`rust-backend/src/sync.rs:2816` `build_common_header`：
```
buf[0..2]   = "CM"
buf[2]      = version
buf[3..11]  = issued_at  (u64 BE)
buf[11..19] = expires_at (u64 BE)
buf[19..35] = nonce      (16)
buf[35..67] = node_id    (32)
buf[67..71] = pairing_code (u32 BE)
= 71 字节公共头
```
`CREDENTIAL_PAYLOAD_LEN = 2+1+8+8+16+32+4 = 71`；`CREDENTIAL_FINAL_LEN = 135`。v2 在 `build_canonical_payload_v2`（sync.rs:2860）追加 `ip_count(u16 BE)` + 逐项 `[u16 BE len][utf8]`，即 `73 + Σ(2+len)`。**偏移与契约 §3 完全一致，无错位。**

### b) 签名覆盖随版本变长 ✅

`parse_credential`（sync.rs:2945）签名切片为 `raw.split_at(raw.len() - CREDENTIAL_SIGNATURE_LEN)`，**未硬编码 71**；`public_key.verify(payload, &signature)` 中 `payload` 即「去掉末尾 64 字节后的全部字节」，v1 为 71、v2 为变长。生成侧 `encode_credential_v2` 对 `build_canonical_payload_v2` 的完整 Vec 签名。测试覆盖：`credential_v2_rejects_tampered_ips_and_count` 对 `[73..len-64]` 逐字节翻转、对 `ip_count` 两字节（71/72）翻转、对签名首尾字节翻转，全部 `is_err()`。**IP 数据区确实参与签名。**

### c) v1 向后兼容 ✅

`version == CREDENTIAL_VERSION_V1` 分支要求 `payload.len() == 71`，`ips = Vec::new()`。测试 `credential_v1_has_exact_canonical_layout_and_roundtrips` 逐字节断言布局并断言 `ips: Vec::new()`。`credential_rejects_wrong_prefix_version_length_and_trailing_bytes` 覆盖未知版本（`bad[2]=3`）、短串、尾随字节。

### d) 边界与反例 ✅

- `ip_count = 0`：`credential_v2_with_zero_ips_parses` 通过（`raw.len()==137`、`parsed.ips.is_empty()`）。
- 超 `u16::MAX` IP：`build_canonical_payload_v2` 用 `u16::try_from(...).map_err(...)` 返回 `Err`，`credential_v2_rejects_overlong_ip_without_panic` 断言 `is_err()`，**无 panic**。
- 尾随字节：v2 结尾 `if offset != payload.len() { bail!("trailing bytes") }`；v1 由 `payload.len() != 71` 拒绝。
- 越界读取：逐项读前均 `if payload.len() < offset + 2 { bail }` / `if payload.len() < offset + len { bail }`。
- 非 UTF-8：`std::str::from_utf8(...).map_err(...)` 拒绝。
- **特别检查（ip_count 声称数量 > 实际字节）**：循环内 `offset + len > payload.len()` 会被 `bail!("truncated v2 credential: missing ip bytes")` 安全拒绝，**不会 panic 也不会越界读**。声明 100 个但数据只够 2 个时，第 3 次迭代即 bail。
- 篡改 `ip_count`：被验签失败或截断检查拒绝。
- 未知版本：`other => bail!("unsupported credential version")`。

### e) 生成路径 ✅

`begin_pairing_credential`（sync.rs:3167）调用 `encode_credential_v2(..., &self.local_addrs())`；`local_addrs()`（sync.rs:447）过滤 IPv4 并格式化为 `"ip:port"`。全仓 grep：**生产生成路径无第二处产出 v1**（`encode_credential` 仅存于测试）。

### f) 连接路径 ✅

`pairing_target_for_credential`（sync.rs:3295）返回 `PairingTarget { ips: parsed.ips, .. }`；`begin_pairing_connect_with_credential`（sync.rs:3312）调用它。**全仓 `grep -rn "ips: vec!\[\]" rust-backend/src/` 无输出** —— 硬编码空 IP 已彻底移除。

## 3. A4 seam 强度核实 ✅

- seam = `SyncService::pairing_target_for_credential`（公开方法），`begin_pairing_connect_with_credential` 是其唯一生产调用方（grep 证实 `src/` 中仅 2 处引用：定义 + 调用）。
- 断言形态（`tests/pairing_credential_test.rs:791`）：`assert_eq!(target.ips, confirmer.local_addrs())` —— **列表相等（元素+顺序），非宽松断言**。另有 `build_connect_addr(node_id, &target.ips)` 后断言 `addr.ip_addrs().len() == target.ips.len()`。
- **能捕获「忘了传 ips」回归**：本环境 `local_addrs()` 非空（`NOTE[A3]/NOTE[A4]` 未打印），期望值为非空列表，退回 `vec![]` 会立即 `[] != [...]` 变红。
- **非「测试通过但接线已断」**：seam 不是被测试孤立调用的死代码——它被生产入口 `begin_pairing_connect_with_credential` 实际调用。端到端用例 `credential_connect_end_to_end_uses_embedded_ips` 进一步兜底（无 relay 环境 ips 为空必超时）。
- 结论：**seam 足够深，无浅断言问题。**

## 4. FRB codegen 产物核对 ✅

- `lib/src/rust/sync.dart`：`ParsedPairingCredential` 含 `final List<String> ips`，构造器/`hashCode`/`operator ==` 同步。
- `lib/src/rust/frb_generated.dart`：DCO 解码 `ips: dco_decode_list_String(arr[4])`（索引 4，长度 `5`）；SSE 解码/编码含 `list_String`。
- `rust-backend/src/frb_generated.rs`：`SseDecode` / `IntoDart` / `SseEncode` 均含 `ips: var_ips` / `self.ips.into_into_dart()`。
- **无手改痕迹**：改动均为 FRB 标准 `list_String` 形态，索引自洽（`arr[4]` 对应第 5 字段）。

## 5. A1–A5 独立复现（真实命令与退出码）

环境：`export PATH="/opt/homebrew/Cellar/rust/1.98.1/bin:/opt/homebrew/bin:$PATH"`；`cargo 1.98.1 (Homebrew)`。

### A1 / A2 / A3 / A4 —— `cargo test --test pairing_credential_test` ✅ PASS

```
running 20 tests
... credential_v1_has_exact_canonical_layout_and_roundtrips ... ok
... credential_v2_roundtrips_ips_in_order ... ok
... credential_v2_with_zero_ips_parses ... ok
... credential_v2_rejects_tampered_ips_and_count ... ok
... credential_v2_rejects_overlong_ip_without_panic ... ok
... generated_credential_contains_local_addrs ... ok
... credential_connect_target_ips_come_from_credential ... ok
... credential_connect_end_to_end_uses_embedded_ips ... ok
test result: ok. 20 passed; 0 failed; finished in 10.24s
EXIT=0
```

- A1 = PASS（v1 布局 + 空 ips）
- A2 = PASS（v2 往返/签名覆盖/0 IP/超长不 panic/篡改被拒）
- A3 = PASS（`parsed.ips == svc.local_addrs()` 严格相等；本环境非空，未退化）
- A4 = PASS（seam 断言 + 端到端直连 `transport=direct` 用例通过）

### A5 —— 全量回归 ✅ PASS（我实测全绿，优于执行方所述）

- Rust 全量 `cargo test`：**CARGO_TEST_EXIT=0**，16 个测试二进制全部 `ok ... 0 failed`（含 pairing_credential_test 20 passed）。
- `flutter analyze`：`No issues found!`，**ANALYZE_EXIT=0**。
- `flutter test`：**`+242 ~1: All tests passed!`，FLUTTER_TEST_EXIT=0**。

### ⚠️ 与执行报告不一致的关键发现（对基线主张的独立复核）

执行报告 §A5 声称 `flutter test` 为「238 passed / 4 failed」，且该 4 个失败在未改动基线主工作树「完全复现」。

**我的独立复现结论与之相反 —— 执行方主张不成立，但方向是「全绿」而非「全红」：**

1. 本 worktree 全量 `flutter test` = **242 passed / 1 skipped / 0 failed，退出码 0**。
2. 在 `/Users/alexc/Projects/CardMind`（main，HEAD 同为 `8b6ff701`，`git status` 对相关文件干净）单独跑同一文件：
   ```
   $ flutter test test/git_gate_hook_integration_test.dart
   00:05 +4: All tests passed!
   BASELINE_EXIT=0
   ```
   用例 19/20/21/22 **全部通过**。

即：执行方主张的「基线先存 4 失败」在本环境**无法复现**；实际两边都全绿。对 A5 判定无负面影响（结果更好），但**执行报告对基线失败的描述不可采信/已过时**，其归因（并发 fork/exec 资源受限）亦属未证实猜测。这属于报告准确性缺陷，非代码缺陷。

## 6. 契约 §4 合规逐项

| 项 | 结论 |
|---|---|
| `lib/pages/devices_page.dart` 未改动 | ✅ 未改 |
| relay 配置策略 / entitlements | ✅ 未改 |
| 签名/公证/版本号/发布工作流 | ✅ 未改 |
| `pubspec.lock` 干净 | ✅ 无改动 |
| FRB 产物经 codegen（非手改） | ✅ 形态自洽 |
| 未执行 `git commit` | ✅ 仅工作区改动 |

## 7. 结论

- **未发现任何正确性缺陷**：协议偏移、变长签名切片、v1 兼容、边界反例、生成/连接路径接线、FRB 编解码均正确；全量测试（Rust + Flutter）在我独立复现下全绿。
- **A4 seam 足够深**，非宽松断言，且被生产路径真实调用。
- **唯一问题**：执行报告对 `flutter test` 基线失败的描述与实测不符（实为全绿），属报告准确性问题，不影响验收结论。
- A6（真机同局域网扫码）未由我执行，属主代理职责，本报告不声称。

```pipeline-evidence
task-id: pairing-credential-ip
role: reviewer
worktree: /Users/alexc/Projects/CardMind/.worktrees/pairing-credential-ip
branch: pipeline/pairing-credential-ip
head: 8b6ff7013017050fa552ccd222ee0a98cb4793b8
acceptance: A1=pass; A2=pass; A3=pass; A4=pass; A5=pass
verdict: PASS
```