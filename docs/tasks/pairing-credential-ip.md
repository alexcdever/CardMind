# 配对凭证携带直连地址：修复同局域网扫码配对失败

- task-id: `pairing-credential-ip`
- 状态：契约冻结（待派发）
- 基线：`470a3655`
- 证据目录：`.pipeline/pairing-credential-ip/`

## 1. 问题陈述

用户在 macOS 桌面端生成配对二维码，用手机（同局域网）扫描后，手机端显示：

> 无法连接到对方设备，请确认两台设备网络可达后重试

### 已确认的根因（基线实测证据）

本机容器日志 `~/Library/Containers/com.cardmind.v2/Data/Library/Application Support/com.cardmind.v2/logs/cardmind.log` 记录了完整配对过程：

```
21:34:24  pairing.show_code  action=start
21:34:24  pairing.advertise  action=start
21:34:24  pairing.accept     action=start  timeout_ms=600000
21:35:41  pairing.show_code  action=cancelled
21:44:26  pairing.advertise  action=stop   ok=true
```

事件计数：

```
event=pairing.request  →  0 次
event=pairing.confirm  →  0 次
```

**本机开好了 10 分钟接收窗口，但窗口内从未收到任何入站请求。** 本机侧无报错，mDNS 广播正常（`dns-sd -B _cardmind._tcp` 可见实例 `cardmind-8d2d214a`，TXT 含 `port=62023`、`device_id`、`nonce`）。

手机端报错文案 `无法连接到对方设备，请确认两台设备网络可达后重试` 唯一来源是 `lib/bridge/pairing_credential_exception.dart:34` 的 `PairingCredentialErrorKind.unreachable`，**只有凭证路径会产生它** —— 反推手机走的是二维码凭证路径。

### 代码级根因

`rust-backend/src/sync.rs` 的 `begin_pairing_connect_with_credential`：

```rust
let target = PairingTarget {
    device_id: parsed.device_id,
    ips: vec![],           // ← 空
    nonce: parsed.nonce,
};
```

凭证 v1 载荷（71 字节）只编码 `magic|version|issued_at|expires_at|nonce|node_id|pairing_code`，**不含任何 IP**。

随后 `build_connect_addr(node_id, &[])` 在 `ips` 为空时：

1. 查 `relay_mode.relay_map().urls()` —— 本机无 `relay.txt`，`RelayMode::Disabled`，**无 relay URL**
2. 只剩 `EndpointAddr::new(node_id)` 的 n0 DNS TXT 解析

而实测该解析不可达：

```
dns.n0.iroh.link    解析失败
relay.n0.iroh.link  解析失败
iroh.link           5.161.195.246（TCP 443 Connection refused）
```

于是连接必然超时，被归类为 `Unreachable`。

### 与既有项目经验的关系

`.claude/skills/pipeline-project-lessons/SKILL.md:45` 已记录：

> iroh 客户端关键坑：`EndpointAddr::new(node_id)` 空 ips 时走 n0 DNS TXT 解析（被墙）——所有无直连 IP 的连接路径必须 `.with_relay_url(relay_url)` 显式附加 relay。

该经验只覆盖了「6 位码 + relay」路径，**未覆盖「二维码凭证 + 局域网」这条既无 relay 又无 IP 的路径**，于是踩进同一个坑。

## 2. 目标

让同局域网扫码配对可用：**凭证自带显示方的直连地址**，扫码方直接构造 `EndpointAddr::from_parts(node_id, ips)`，不依赖 relay 与 n0 DNS。

## 3. 协议设计（已由主代理定稿，执行方不得改动布局）

### v1（保留，仅解析）

```
[0..2]   "CM"
[2]      version = 1
[3..11]  issued_at   (u64 BE)
[11..19] expires_at  (u64 BE)
[19..35] nonce       (16)
[35..67] node_id     (32)
[67..71] pairing_code(u32 BE)
= 71 字节 canonical payload，后接 64 字节签名
```

### v2（新增，用于生成）

```
[0..71]  同 v1 字节布局，但 [2] = 2
[71..73] ip_count (u16 BE)
[73..]   每项：[u16 BE 长度][utf8 字节]
= 73 + Σ(2 + len) 字节 canonical payload，后接 64 字节签名
```

**签名覆盖范围 = canonical payload 全部字节**（v1 的 71 字节、v2 的 `73 + Σ` 字节）。

### 解析分派

`parse_credential` 读 `[2]` 版本字节分派：

- `1` → 按 v1 布局解析，`ips = []`
- `2` → 先按 71 字节读公共头，再读 `ip_count` 与逐项 IP
- 其他 → 报错

签名验证必须用**对应版本的 payload 切片**，不得固定按 71 字节切分。

## 4. 修改范围

允许修改：

- `rust-backend/src/sync.rs`
- `rust-backend/src/api.rs`（仅当 FRB 导出签名需要同步）
- `rust-backend/tests/pairing_credential_test.rs`
- `rust-backend/tests/` 下新增配对凭证测试文件
- `lib/src/rust/**`（FRB codegen 生成产物，必须通过 `flutter_rust_bridge_codegen generate` 重新生成，不得手改）
- `lib/bridge/frb_note_repository.dart`、`lib/bridge/note_repository.dart`、`lib/bridge/bridge_helper.dart`（仅当 FRB 类型新增字段导致编译错误）
- `test/**` 中因 FRB 类型变更而需要同步的测试夹具

禁止修改：

- `lib/pages/devices_page.dart` 的 UI 流程（除非类型变更导致编译失败）
- relay 配置策略、`macos/Runner/*.entitlements`
- 签名/公证、版本号、发布工作流

## 5. 验收条件

### A1（单元）v1 凭证仍可解析 — 向后兼容

现有 `pairing_credential_test.rs` 中构造 v1 凭证并解析的用例必须继续通过（`parse_credential` 对 version=1 走原路径，`ips` 为空）。

### A2（单元）v2 凭证往返 + IP 参与签名

新增测试覆盖：

- `encode_credential_v2` 生成含 N 个 IP 的凭证，`parse_credential` 取回**完全相同的 IP 列表与顺序**
- 篡改任一 IP 字节 → 验签失败
- 篡改 `ip_count` → 解析失败或验签失败
- `ip_count = 0` 的 v2 凭证可正常解析（边界）
- 超长 IP 字符串（> u16）不得 panic

### A3（单元）生成路径确实填入本机地址

测试：构造 `SyncService`，调用 `begin_pairing_credential()`，解析返回的 `credential` 字符串，断言其中的 `ips` **等于** `svc.local_addrs()` 的结果（或至少非空且格式为 `ip:port`）。

若 `local_addrs()` 在该测试环境下为空（如无网络接口），测试必须显式标注该前提，不得放宽为非空断言。

### A4（单元）连接路径使用凭证内嵌 IP

测试 `begin_pairing_connect_with_credential` 的 `PairingTarget.ips` 来自凭证解析结果而非 `vec![]`。

**实现建议（非强制）**：把 `PairingTarget` 构造与 `build_connect_addr` 之间抽出可注入的观测点，或对 `build_connect_addr` 单独断言「传入非空 ips 时返回 `EndpointAddr` 含 `TransportAddr::Ip`」。执行方须说明所选的 seam，并确认它能捕获「忘了传 ips」这类回归。

### A5（回归）全量测试绿

```bash
cd rust-backend && cargo test
flutter analyze
flutter test
```

必须与基线一致或更好，不得新增失败。

### A6（真实链路，主代理执行）同局域网扫码配对成功

需要真实手机与桌面端在同一局域网：

1. 桌面端生成二维码
2. 手机扫码
3. 断言桌面端容器日志出现 `pairing.request action=received`
4. 断言手机端进入配对确认流程

**此验收依赖用户的物理设备，主代理无法独立完成。** 若无法执行，必须在 `final-check.md` 明确标注为未验证，不得伪造。

## 6. 证据要求

执行方在 `.pipeline/pairing-credential-ip/executor-report.md` 中必须包含：

- task-id、worktree 绝对路径、branch、HEAD
- A1–A5 的完整命令、退出码、关键断言输出（真实输出，不得编造）
- 修改文件清单与 diff 摘要
- 所选测试 seam 的说明与它为何能捕获回归
- FRB codegen 是否执行、生成产物是否被纳入改动
- A6 明确标注由主代理执行

报告末尾加机器可读区块：

```pipeline-evidence
task-id: pairing-credential-ip
role: executor
worktree: <绝对路径>
branch: pipeline/pairing-credential-ip
head: <HEAD sha>
acceptance: A1=<pass|fail>; A2=<pass|fail>; A3=<pass|fail>; A4=<pass|fail>; A5=<pass|fail>
```

## 7. 已知证据边界

- 本仓库不存在 `.gitnexus/run.cjs`，GitNexus MCP impact 工具不可用，无法提供 impact analysis。执行与审查报告必须如实记录，不得声称已执行。
- `cargo test` 中的网络类测试可能需要真实网络接口；若环境不满足，标注为环境前置而非代码回归。
- A6 需要��理手机，可能无法完成。

<!-- pipeline-contract
 task-id: pairing-credential-ip
 contract-version: 1
 baseline: 470a3655
 scope: rust-backend/src/sync.rs,rust-backend/src/api.rs,rust-backend/tests/pairing_credential_test.rs,lib/src/rust,lib/bridge,test
 acceptance: A1-v1-still-parses; A2-v2-roundtrip-and-signature-covers-ips; A3-generated-credential-contains-local-addrs; A4-connect-uses-embedded-ips; A5-full-suite-green; A6-lan-scan-pairs
 execution-worktree: pending-contract-freeze
 evidence-dir: .pipeline/pairing-credential-ip/
-->