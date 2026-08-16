## 任务 Q：签名配对凭证、二维码与复制字符串

将当前“6 位配对码 + 可选手输 64 字符节点 ID”的跨网配对流程，升级为统一的签名配对凭证：显示方同时展示二维码和可复制字符串；发起方扫码或粘贴同一字符串后，自动还原并验证节点 ID、6 位配对码、过期时间和一次性 nonce，再沿用现有 iroh 配对、relay、bounded accept、首次同步和持续接收流程。

普通用户不再查看或手工输入节点 ID。保留旧 6 位码 + mDNS 局域网兼容路径。

## 主仓库与 worktree

- 主仓库：`D:/Projects/CardMind`
- worktree：`D:/Projects/CardMind/.worktrees/signed-pairing-credential`
- 分支：`codex/signed-pairing-credential`
- 基线：主仓库当前 `codex/knowledge-base`
- worktree 必须位于主仓库 `.worktrees/` 内；禁止修改主仓库业务文件。

## 已确认的依赖事实

CardMind 当前使用 iroh 1.0.2。其 `EndpointId` 是 Ed25519 `PublicKey`：

```rust
SecretKey::sign(message: &[u8]) -> Signature
PublicKey::verify(message: &[u8], signature: &Signature) -> Result<(), SignatureError>
```

不得另建长期配对密钥、不得把 `device.key` 私钥或 relay 凭据写入凭证。

## 协议契约

### 1. Canonical binary payload v1

所有整数使用大端序。签名正文必须严格按以下字节序列拼接，不使用 JSON 字段顺序或平台默认序列化：

```text
magic        [2]byte  = ASCII "CM"
version      u8       = 1
issued_at    u64      = Unix seconds UTC
expires_at   u64      = Unix seconds UTC
nonce        [16]byte = 密码学随机，一次性会话标识
node_id      [32]byte = iroh EndpointId/PublicKey 原始字节
pairing_code u32      = 100000..999999
```

签名：

```text
signature = Ed25519.sign(device SecretKey, canonical_payload) // 64 bytes
```

最终凭证字节：

```text
canonical_payload || signature
```

最终字符串：

```text
cm1. + base64url_no_padding(final_bytes)
```

必须使用 URL-safe Base64，无 `=` padding。二维码内容与复制字符串必须逐字相同。

固定长度：payload 71 bytes，签名 64 bytes，最终 135 bytes；解析器必须拒绝多一个或少一个字节的输入，禁止忽略尾随数据。

### 2. 安全语义

- 凭证明文包含节点 ID、6 位码、时间和 nonce；这不是加密，也不宣称隐藏信息。
- 签名保证完整性和来源认证；解析时先从 payload 的 node_id 构造公钥，再验签。
- 默认有效期沿用现有配对会话：10 分钟。
- `issued_at` 最多允许比本机当前 UTC 时间晚 60 秒；超过视为时钟/凭证异常。
- `expires_at` 必须大于 `issued_at`，且 `expires_at - issued_at <= 10 分钟`。
- 过期凭证拒绝。
- nonce 必须与确认方当前 `PairingSession` 一致；错误 nonce 与错误 code 一样计入失败次数。
- 配对成功后 `PairingSession` 立即清空，旧凭证再次使用必须失败。
- 重新生成配对凭证必须生成新 code 与新 nonce，使旧凭证失效。
- 任意 payload/signature 字节被篡改必须拒绝。
- 私钥、完整凭证、6 位码、nonce、完整节点 ID均不得写入结构化日志；节点 ID仍按既有 8+8 脱敏。

### 3. Rust 类型与 API

按现有模块边界实现，命名可做等价微调，但功能与 FRB 数据链必须完整：

```rust
pub struct PairingCredentialDisplay {
    pub code: String,
    pub credential: String,
    pub expires_at: String, // RFC3339 UTC，供 UI 倒计时
}

pub struct ParsedPairingCredential {
    pub code: String,
    pub device_id: String,
    pub expires_at: String,
    pub nonce: String, // 仅用于内部 FRB→握手传递；不得在 UI/日志显示
}
```

新增/调整能力：

```rust
SyncService::begin_pairing_credential() -> Result<PairingCredentialDisplay>
SyncService::parse_pairing_credential(&self, credential: &str) -> Result<ParsedPairingCredential>
```

- `begin_pairing_credential` 创建现有 `PairingSession`，会话增加 `[u8; 16] nonce`，并用 endpoint 的持久化 SecretKey 签名。
- 若当前 `Endpoint` API不直接暴露 SecretKey，可在 `SyncService` 构造时保留 `SecretKey` clone；不得从磁盘重复读取或暴露私钥。
- `begin_pairing_accept_and_advertise` 的旧 6 位码 API保留兼容，但显示二维码的组合 API必须保证“创建 credential + 启动 mDNS广播”原子地进入同一配对会话。
- `PairingRequest` 增加 nonce；凭证路径把解析出的 nonce带入网络请求。
- 旧 6 位码 + mDNS 路径使用当前会话 nonce（由确认方广播结果或旧协议兼容策略获得）。如果现有 mDNS协议无法携带 nonce，扩展 mDNS TXT记录携带 nonce；不得用空 nonce绕过校验。
- 连接 API应提供凭证垂直入口，例如：

```rust
begin_pairing_connect_with_credential(credential: String) -> Result<PairingResult>
```

该 API内部完成 parse/verify/target 构造，`ips=[]` 时沿用当前 `build_connect_addr`，使用发起端自己的可选 `relay.txt`。不得把内部 dogcloud URL硬编码进凭证或发布配置。

### 4. UI/UX

#### 显示方

“我显示配对码”弹窗同时显示：

- 二维码（内容为完整 `cm1...` 凭证）；
- 6 位码，供同局域网旧流程兼容；
- “复制配对信息”按钮，复制完整凭证；
- 有效期倒计时；
- “重新生成”命令，生成新 code + nonce并使旧凭证失效；
- 不显示完整节点 ID、nonce、签名或 relay URL。

二维码使用成熟 Flutter 包（优先 `qr_flutter`）；二维码有稳定正方形尺寸、浅色静区和足够纠错级别，Windows/Android 均能显示。

#### 发起方

“我输入对方的码”改为单一主输入框：

```text
配对码或配对信息
```

支持：

- 粘贴 `cm1...` 凭证：自动验签、解析并经 relay/直连发起配对；
- 输入 6 位数字：保留当前 mDNS 自动发现路径；
- Android 提供扫码按钮，使用成熟扫码包（优先 `mobile_scanner`），扫码结果回填并自动解析；
- 不再显示“对方设备 ID”输入框；
- Windows 无可用扫码能力时隐藏扫码按钮，复制/粘贴必须可用。

错误文案至少区分：

- 格式无效；
- 签名无效/内容被修改；
- 已过期；
- 已使用或已被重新生成替代；
- 目标不可达。

用户文案不得显示裸 `AnyhowException`、完整节点 ID、nonce或内部栈。

### 5. 依赖与权限

- 使用 `flutter pub add` 或精确修改 `pubspec.yaml` 添加成熟二维码显示与移动扫码依赖；不得手写二维码编码器/相机识别器。
- Android 仅增加扫码所需的最小 CAMERA 权限；首次扫码时按平台惯例请求。
- 不添加联网分析、云扫码、遥测或第三方服务。
- 包版本必须与当前 Flutter/Dart兼容；`pubspec.lock` 的对应依赖变化属于范围。

## 改动范围

允许修改：

- `rust-backend/src/sync.rs`
- `rust-backend/src/api.rs`
- `rust-backend/Cargo.toml`、`Cargo.lock`（编码依赖需要时）
- FRB 生成文件 `rust-backend/src/frb_generated.rs`、`lib/src/rust/**`
- `lib/bridge/note_repository.dart`
- `lib/bridge/frb_note_repository.dart`
- `lib/bridge/bridge_helper.dart`
- `lib/pages/devices_page.dart`
- 可新增配对凭证/扫码 UI小组件到 `lib/widgets/` 或现有合理目录
- `pubspec.yaml`、`pubspec.lock`
- Android CAMERA 权限文件
- 本任务测试文件
- `.workflow/*.md`

禁止修改：

- relay 默认策略（仍为无 `relay.txt` 就禁用）
- dogcloud/服务器配置
- 笔记、回收站、同步 envelope 数据模型
- 持续接收器核心调度语义
- `.gitignore`
- `prototype/`
- 其它会话当前未提交的 context/gitnexus 文件

## 验收标准（ATDD，红-绿-蓝）

每条均须先写失败测试并实机确认红，再实现绿，最后蓝阶段重构并全绿。报告记录红与绿真实输出。

### Rust 协议测试：新增 `rust-backend/tests/pairing_credential_test.rs`

1. `credential_v1_has_exact_canonical_layout_and_roundtrips`：固定 SecretKey、固定时间、固定 nonce、固定 code，断言解码后恰为 135 bytes；逐字段字节偏移、大小端、签名区位置准确；生成→解析字段完全一致。
2. `credential_qr_text_is_canonical_base64url_without_padding`：字符串仅 `cm1.` + `[A-Za-z0-9_-]`，无 `=`、空白和换行；重新编码字节完全一致。
3. `credential_signature_is_verified_by_endpoint_id`：从 payload node_id 验证签名成功，证明无需额外公钥。
4. `credential_rejects_tampered_payload_and_signature`：分别翻转 node_id/code/expires/nonce/signature 任一字节，全部拒绝。
5. `credential_rejects_wrong_prefix_version_length_and_trailing_bytes`：错误前缀、未知版本、截断、超长、尾随字节均拒绝。
6. `credential_rejects_expired_future_and_invalid_ttl`：过期、issued_at未来超过60秒、expires<=issued、TTL>10分钟全部拒绝；允许60秒内时钟偏差。
7. `new_credential_replaces_previous_session`：连续生成两次，code与nonce均不同；第一份凭证在确认方失败，第二份可用。
8. `credential_is_single_use`：凭证成功完成一次配对后，同一凭证第二次握手失败。
9. `credential_nonce_mismatch_counts_toward_attempt_limit`：签名正确但对确认方当前会话 nonce不匹配时拒绝并计入既有5次限制。
10. `credential_connect_uses_embedded_node_id_without_mdns`：两个真实 endpoint，发起方只给 credential，不给手写 ID、不做 mDNS，完成配对并双方持久化。
11. `legacy_six_digit_mdns_pairing_remains_supported`：旧 6 位码局域网路径仍可完成配对，且 nonce校验不被绕过。
12. `credential_never_enters_debug_logs`：完整凭证、code、nonce、签名、完整 ID均不出现在结构化日志。

### Flutter repository/FRB 测试：新增 `test/pairing_credential_repository_test.dart`

13. `display credential survives real FRB roundtrip`：真实 RustLib + DLL，生成显示对象，parse返回 code/device_id/expires/nonce；Store/SyncService RustArc均未 disposed。
14. `credential connect bypasses discovery`：凭证入口调用真实/可观察 repository 时不调用 `discoverPeers`，直接使用解析目标。
15. `legacy six digit input still invokes discovery`：纯 6 位数字仍调用 mDNS路径。
16. `invalid expired and tampered credential map to friendly errors`：三类错误映射为稳定、非裸异常的用户错误。

### Flutter widget 测试：扩展设备页测试或新增 `test/pairing_credential_ui_test.dart`

17. `show dialog renders qr code text copy and countdown`：显示二维码、6 位码、复制按钮和倒计时；二维码数据与复制文本逐字相同；不显示完整 node ID/nonce。
18. `regenerate invalidates old display and updates qr and text`：重新生成后二维码、字符串、6 位码均变化。
19. `enter dialog has one primary field and no node id field`：存在“配对码或配对信息”；不存在 `pair-peer-id-input`。
20. `pasted credential connects without discovery`：粘贴 `cm1...` 后直接连接；mDNS未调用。
21. `six digits preserve mdns path and ambiguity messages`：旧路径无结果/多结果文案仍正确。
22. `android scan result uses same parser as paste`：扫码结果只回填统一输入并调用同一 parser，不存在第二套 QR解析逻辑。
23. `scanner permission denied has friendly fallback`：拒绝相机权限时提示可复制/粘贴，不阻断文本入口。
24. `long credential never overflows desktop or mobile dialog`：320x640 与 1280x720 下无 overflow；字符串省略显示但复制完整值。

### 平台与真实链路

25. `flutter_rust_bridge_codegen generate` 连续两次，第二次零新增内容级 diff。
26. `timeout 3m cargo test --test pairing_credential_test -- --nocapture` 全绿；每个网络等待/spawn两侧均有 tokio timeout。
27. Rust 其余测试按文件分组执行，每个测试命令3分钟硬上限，全部0 failed。
28. `flutter test --timeout 3m` 全绿；`flutter analyze` 无问题。
29. `flutter test integration_test/receiver_platform_test.dart -d windows` 与无代理环境 Android 模拟器均通过，Store不 disposed。
30. 真实默认 NAT + dogcloud relay 双端验收：
    - Windows 显示二维码/复制字符串；
    - Android 不使用 mDNS、不输入节点 ID，只粘贴或扫码凭证；
    - `pairing.connect` transport=relay success；
    - Windows confirm success；
    - 首次 `sync.push -> sync.receive -> sync.import` 成功；
    - 双方 `last_seen` 更新，设备页5秒内在线；
    - 无 `DroppableDisposedException`；
    - 未执行不得声称通过。
31. git 范围检查：`.gitignore` 无差异；context/gitnexus、prototype、relay配置无改动；工具产生的纯行尾噪声全部还原。

## 需决策点

遇到以下任一情况立即停下报告，不自行改设计：

1. iroh 1.0.2 的 Endpoint SecretKey 无法在不暴露私钥的前提下用于签名，或 EndpointId无法验签。
2. 为兼容旧 6 位码必须允许空 nonce/绕过 nonce校验。
3. mobile scanner 包与当前 Flutter/Android工具链不兼容，需要换包或提高 minSdk。
4. 真实 NAT relay 路径要求把 dogcloud地址硬编码进凭证或默认发布配置。
5. 需要数据库 schema迁移、服务器 rendezvous服务或修改 relay默认策略。
6. Android/Windows真实平台无法启动；必须如实标注，不得用 widget/mock测试替代。
