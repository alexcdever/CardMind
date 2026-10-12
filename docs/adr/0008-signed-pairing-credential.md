# ADR 0008 — 签名配对凭证协议：canonical payload、nonce 防重放与失败上限

- **日期**：2026-10-12
- **状态**：已采纳
- **决策者**：@alexc

---

> 来源：原一次性任务单《任务 Q：签名配对凭证、二维码与复制字符串》及续单 Q2/Q3、R、S、T、T2
> （这些任务单是流水线的一次性记录，已按 `docs/standards/ai-collaboration.md` 的约定从
> `docs/` 删除；本文承载其中仍然有效的长期协议决策）。
> 配对在架构里的定位（准入控制）见 [ADR 0006](0006-lan-sync-loro-iroh-mdns.md)；
> 同步网络拓扑与 relay 策略见 `docs/sync-network.md`。

## 背景

配对是「发现 ≠ 可连接」这条决策的落点（ADR 0006 第 7 条）：mDNS 只能说明同网段有设备，
不能说明用户想连的是哪一台，所以首次连接必须有人工确认。
2026-08 之前的做法是「确认方显示 6 位配对码 + 发起方手工输入对方 64 字符节点 ID」，
它有两个硬伤：

1. 普通用户拿不到、也抄不对节点 ID（`lib/pages/devices_page.dart` 里曾有一个手工节点 ID
   输入框，现已从产品删除）；
2. 跨网段时 mDNS 不可用，只给节点 ID 无法寻址（iroh 会退回被墙的 n0 DNS 解析）。

取而代之的方案是把「本机节点 ID + 6 位配对码 + 签发/过期时间 + 一次性 nonce」打成一个由
本机 iroh 身份密钥签名的**配对凭证**：显示方同时给出二维码与可复制字符串，发起方扫码或
粘贴后本地验签、还原出目标与 nonce，再走既有的 iroh 配对与首次同步。

参与方：

- **显示方 / 确认方**：生成凭证、显示二维码与 6 位码、有界等待配对请求、确认落库；
- **发起方**：解析并验证凭证、用凭证内嵌的目标发起连接、接收握手响应并落库。

## 决策

### 1. 用途与传输形态

1. **凭证是一次性的身份 + 寻址 + 授权材料，不承担加密职责**：载荷明文包含 `node_id`、
   6 位配对码、时间与 `nonce`，任何人都能读；签名只保证**完整性**与**来源认证**
   （签名者就是载荷里那台 `node_id` 对应的设备）。
2. **字符串形态固定为 `cm1.` + URL-safe Base64（无 `=` padding）**，内容是
   `canonical_payload || signature`。二维码内容与「复制配对信息」文本**逐字相同**
   （`credential_to_string` / `credential_from_string`，前缀常量见 `CREDENTIAL_PREFIX`）。

### 2. Canonical payload

3. **公共头 71 字节，全部大端序**（`CREDENTIAL_PAYLOAD_LEN`），字节布局固定：

   | 偏移 | 长度 | 字段 | 说明 |
   |------|------|------|------|
   | 0 | 2 | magic | ASCII `CM`（`CREDENTIAL_MAGIC`） |
   | 2 | 1 | version | 载荷版本：`CREDENTIAL_VERSION_V1` = 1，`CREDENTIAL_VERSION_V2` = 2 |
   | 3 | 8 | `issued_at` | Unix 秒（UTC） |
   | 11 | 8 | `expires_at` | Unix 秒（UTC） |
   | 19 | 16 | `nonce` | 密码学随机的一次性会话标识 |
   | 35 | 32 | `node_id` | iroh 身份公钥原始字节 |
   | 67 | 4 | `pairing_code` | 100000..=999999 |

   不使用 JSON 字段顺序或平台默认序列化；`pairing_code` 超出范围直接报错
   （`build_common_header`）。
4. **v1 = 71 字节固定载荷**（只有公共头，不含地址），最终凭证 135 字节
   （`CREDENTIAL_FINAL_LEN` = 71 + 64）。
5. **v2 = 公共头 + 内嵌直连地址**（`build_canonical_payload_v2`）：公共头之后接
   `ip_count`（u16 大端）+ 逐项 `[u16 大端长度][UTF-8 字节]`，签名覆盖**整个** payload
   （含 IP 段）。v2 是**生产生成路径**（`begin_pairing_credential` 调 `encode_credential_v2`，
   地址取本机 `local_addrs()`）；v1 只保留解析能力（`parse_credential` 的 v1 分支 +
   `encode_credential`，供历史测试构造用例），生产不生成 v1。
6. **长度必须精确，不得忽略尾随数据**：报文总长小于 135 字节直接拒绝；v1 要求载荷恰为
   71 字节；v2 读完 `ip_count` 个条目后 `offset != payload.len()` 即报 trailing bytes；
   未知版本号报错。
7. **签名与校验**：签名是设备既有 iroh 身份密钥对 canonical payload 的 64 字节 Ed25519
   签名（`CREDENTIAL_SIGNATURE_LEN`，`SecretKey` 签名）。校验时**先从载荷里的 `node_id`
   字节构造 `PublicKey`，再用它验签**——不引入第二套公钥分发；任何载荷或签名字节被改动
   都会验签失败。
8. **不得另建长期配对密钥**：`SyncService` 构造时克隆一份 endpoint 的持久化 `secret_key`
   供签名（内存态，不落库、不暴露）；不得从磁盘重复读私钥，也不得把设备私钥或 relay 凭据
   写进凭证。

### 3. nonce 与防重放

9. **`nonce` 由显示方在每次生成凭证时用密码学随机源生成**（16 字节，`OsRng`），与 6 位码
   一起写入内存态的 `PairingSession`；在二维码字符串与网络请求里以 hex 字符串出现
   （`nonce_to_hex` / `nonce_from_hex`）。
10. **确认方强制校验 nonce，不存在任何绕过后门**：`confirm_pairing` 把请求里的 `nonce`
    与当前 `PairingSession.nonce` 逐字节比较，**空串、全零、hex 格式错误、不匹配四种情况
    一律拒绝**，并各自计入失败次数（请求侧字段 `PairingRequest.nonce`）。
11. **错误 nonce 与错误配对码同等对待**：都计入 `PAIRING_MAX_FAILED_ATTEMPTS`（5 次），
    达到上限即清空会话、当前凭证彻底失效。
12. **一次性使用**：确认成功后立刻清空 `PairingSession`（`confirm_pairing_inner`），
    同一凭证（或同一 6 位码）第二次握手必然失败。
13. **重新生成即失效**：每次 `begin_pairing_credential` 都生成新的 6 位码与新的 `nonce`，
    并清空 `pending_pairing`；旧凭证因 nonce 不匹配而失效。

### 4. 有效期与失败上限

14. **凭证有效期 10 分钟**（`CREDENTIAL_TTL_SECS`），与 6 位码有效期一致
    （`PAIRING_CODE_TTL_MINUTES`）；`PairingCredentialDisplay.expires_at` 以 RFC3339 UTC
    返回，供 UI 做倒计时。
15. **时间窗口有界**：`issued_at` 最多允许比本机当前 UTC 时间晚 `CREDENTIAL_CLOCK_SKEW_SECS`
    （60 秒，容忍时钟偏差）；`expires_at` 必须严格大于 `issued_at`，且二者之差不得超过
    `CREDENTIAL_TTL_SECS`；`expires_at` 已过则拒绝。
16. **失败尝试上限 5 次**（`PAIRING_MAX_FAILED_ATTEMPTS`）：`validate_pairing_code` 检查
    会话年龄与失败计数，超限即失效。

### 5. 失败与拒绝时的行为

17. **解析失败用稳定的错误分类表达**：Rust 侧 `PairingCredentialError` 携带
    `PairingCredentialErrorKind`（`invalidFormat` / `invalidSignature` / `expired` /
    `usedOrReplaced` / `unreachable` / `internal`）；`credential_error` 按底层错误归类，
    凭证入口的连接失败（`begin_pairing_connect_with_credential`）一律归为 `unreachable`。
18. **Dart 侧按 kind 映射中文文案**，不暴露裸异常、完整节点 ID、nonce 或内部栈：
    `PairingCredentialException`（`lib/bridge/pairing_credential_exception.dart`）给出
    「格式无效 / 签名无效，可能已被篡改 / 已过期 / 已使用或已被替代 / 无法连接到对方设备 /
    配对失败」六类文案。
19. **解析期不判定「已使用」**：解析只看前缀、长度、版本、时间窗与签名，因此被用掉或被
    重新生成取代的凭证在解析阶段仍然「有效」，真正的拒绝发生在确认方（会话已清空 /
    nonce 不匹配），表现为连接失败。`usedOrReplaced` 这一 kind 已定义、已过 FRB、Dart
    文案已备，但当前分类器不产出它（见「未实现与偏差」）。

### 6. 两条配对路径

20. **凭证路径（跨网段主路径）**：`begin_pairing_connect_with_credential` 在 Rust 内部完成
    「解析 → 验签 → 构造 `PairingTarget`」（`pairing_target_for_credential`），目标地址直接
    取 v2 凭证内嵌的 `ips`；`ips` 为空（v1 或本机无 IPv4）时沿用 `build_connect_addr`：
    优先直连地址，否则用**发起端自己的**可选 relay 配置。**凭证路径不得调用 mDNS**，
    也不得再出现节点 ID 手工输入。**解析结果就是握手输入**：`parse_pairing_credential` 返回的
    `ParsedPairingCredential` 含 6 位码、节点 ID（base32 文本，供展示与日志脱敏）、RFC3339
    过期时间、hex `nonce` 与凭证内嵌的 `ips`；`nonce` 只用于 FRB→握手传递，不在 UI 展示、
    不进日志。
21. **6 位码 + mDNS 路径（同网段兼容路径）保留**：发起方只输入 6 位数字时，
    `discover_peers` 找同网段设备，把唯一结果的 `deviceId`、`ip:port` 与 **mDNS TXT 里的
    nonce** 一起填进 `PairingTarget`，再调 `begin_pairing_connect`。无结果 / 多结果都给
    友好提示，不再引导手工输入节点 ID。
22. **mDNS TXT 必须携带 nonce**：`DiscoveryService::start_advertising` 的 TXT 记录含
    `device_id` / `port` / `nonce`，`PeerInfo` 带 `nonce` 字段；旧 TXT 缺 nonce 时解析为空串，
    **由确认方的强制校验拒绝**——空串是「识别出旧广播」，不是绕过（非当前二进制客户端的
    兼容承诺）。
23. **凭证与会话的原子性**：`begin_pairing_credential_with_advertising` 在一次调用内完成
    「生成凭证（新 code + 新 nonce）→ 启动 mDNS 广播」；显示方弹窗关闭/取消/完成时用
    `stop_pairing_advertising` 停广播（幂等）。

### 7. 显示方与发起方的 UI 契约

24. **显示方**（`_PairingAcceptDialog`，`lib/pages/devices_page.dart`）必须同时给出：二维码
    （内容为完整凭证字符串，用 `QrPainter` / `qr_flutter` 绘制）、6 位码、「复制配对信息」
    （复制完整凭证）、有效期倒计时、重新生成按钮；**不显示**完整节点 ID、nonce、签名或
    relay URL；提示语以显示方为准（「扫描此二维码」）。
25. **显示方生命周期固定**：先 await 生成凭证（含广播）→ 显示数据 → 再启动**单个**有界
    accept（`accept_pairing_request_with_timeout`）；重新生成时先让旧轮次作废再开新轮次，
    不得并发两个 accept 循环，confirm 只允许使用当前显示的那一份 code；弹窗关闭后不再
    confirm、不再 setState。
26. **发起方只有一个主输入**（`pair-credential-input`，标签「配对码或配对信息」）：`cm1`
    开头的凭证走凭证入口（记 `pairing.discovery action=bypassed`），纯 6 位数字走 mDNS；
    Android 扫码（`ScannerService` / `mobile_scanner`）的结果回填同一输入框并调用同一提交
    逻辑，不存在第二套解析逻辑；桌面平台（Windows）隐藏扫码按钮，复制/粘贴始终可用。

### 8. 日志与隐私

27. **结构化日志不得出现**私钥、完整凭证、6 位码、nonce、签名或完整节点 ID；节点 ID 一律经
    `debug_log::redact_device_id` 脱敏为前 8 + 后 8 字符（`redact_device_id`）。凭证路径记
    `pairing.discovery action=bypassed mdns_skipped=true`（不记凭证本身）；连接记
    `pairing.connect action=start|success|failed transport=credential|direct|relay_or_dns`。

### 9. 依赖与权限

28. **二维码与扫码都用成熟包，不手写编码器 / 识别器**：显示方用 `qr_flutter` 绘制二维码
    （`QrPainter`）；Android 扫码用 `mobile_scanner`，经 `ScannerService` 条件导入隔离，
    桌面构建不链接该插件。Android 只申请扫码所需的最小 CAMERA 权限
    （`android/app/src/main/AndroidManifest.xml`），并按平台惯例在首次扫码时请求；
    **不引入联网分析、云扫码、遥测或其它第三方服务**，扫码文本只在本地解析。

## 拒绝的方案

### 兼容空 nonce / 全零 nonce 的「旧版本后门」

- **源文给出的理由**（任务 Q2 设计裁决）：第一轮实现允许 `requester.nonce.is_empty()` 或
  全零 nonce 时跳过校验，等于把防重放关掉；设计方裁决为「不得放松生产校验」。
- **本 ADR 的结论**：保留「6 位码 + mDNS」指的是保留**当前流程**，不是兼容旧二进制协议；
  确认方对所有请求强制校验 nonce。不要求新版本与旧客户端跨版本配对。

### 手工输入节点 ID

- **源文给出的理由**（任务 R 产品契约）：手动节点 ID 路径已从产品删除，旧 UI 锚点与测试
  行为迁移为凭证路径。
- 依据是用户侧：64 字符节点 ID 不可读、不可抄；凭证路径与 mDNS 路径已覆盖全部场景。

### 把凭证当成加密容器

- 载荷含节点 ID、配对码与 nonce 且明文可读；本项目不把「隐藏节点 ID」列为安全目标，
  可信边界是同网段 / 自有 relay 与被配对设备本人确认（ADR 0006 的「发现 ≠ 可连接」）。

### 用 relay / 服务器做配对中介

- **（推断）**：把凭证换成服务端 rendezvous 需要新增服务与信任根，且与
  `docs/sync-network.md` 的「默认零配置、仅局域网；跨网段靠用户自部署 relay」冲突。

## 后果

- **正向**：普通用户用二维码或复制字符串即可完成跨网段配对；确认方验签不需要任何外部
  公钥分发（公钥就在载荷里）；nonce 让重放与错配请求在握手层被拒；失败上限使凭证不可
  暴力猜解；凭证里的直连地址让同网段直连不依赖 relay 与 n0 DNS。
- **约束 / 负向**：
  - 凭证一次性、10 分钟有效，过期必须重新生成（用户理解成本）；
  - 载荷明文暴露节点 ID 与配对码，安全强度依赖 iroh 传输加密（QUIC/TLS）与用户确认；
  - v2 内嵌的 `ip:port` 是生成时刻的地址快照，网络变化后需要重新生成凭证或退回 relay 路径；
  - 双方时钟偏差超过 60 秒会直接判定凭证异常。

### 未实现与偏差（2026-10 核对）

- `PairingCredentialErrorKind.usedOrReplaced` **已定义、已过 FRB、Dart 文案已备**
  （`lib/bridge/pairing_credential_exception.dart`），但 `credential_error` 目前不会产出该
  kind：被使用或被取代的凭证在解析期仍判「有效」，实际表现为连接期 `unreachable`，
  用户看到「无法连接到对方设备」而不是「已使用或已被替代」。分类口径与文案不一致，属已知缺口。
- **任务 Q3「accept 超时报错并停广播」的裁决已废弃**：显示方 accept 窗口超时不再显示错误，
  而是静默重新生成新 code + 新 nonce 继续等待（`_runAcceptRounds` / `_acceptFuture`，
  后续任务 U7 的行为）；用户全程无感。本文的决策 25 只固定「单 loop、不当用旧 code confirm、
  关闭后不再 setState」这些仍然成立的部分。
- v1 生成路径（`encode_credential`）只服务历史测试用例，生产不再生成 v1；
  `parse_credential` 保留 v1 解析作为一条兼容路径（当前无 v1 客户端在流通）。

## 非目标

- **不要求与旧二进制客户端跨版本配对**：协议不做版本协商，`cm1.` 前缀不编码版本。
- **不把 public relay 写进凭证或默认发布配置**：relay 仍是可选配置（`load_relay_mode` +
  数据目录 `relay.txt`），凭证里不得硬编码 relay URL。
- **不做服务器侧 rendezvous、不做云配对服务**，也不为此做数据库 schema 迁移。
- **不做双向确认与额外的中间人防护**：个人工具，防误连即可（`docs/sync-network.md` 决策 12）。
- **任务单里的一次性流程要求不算长期决策**：逐条测试清单（如
  `test/pairing_credential_ui_test.dart` 与 `test/pairing_credential_repository_test.dart`
  的用例清单、`rust-backend/tests/pairing_credential_test.rs` 的 13 个用例）、两轮 FRB codegen
  幂等、平台 integration 与标准 443 relay live 验收、三份报告门禁、`cargo fmt` 与行尾噪声
  还原要求，都是流水线的过程纪律，载体是 `docs/standards/*.md`，不写进本 ADR。
- **测试编排细节不是协议**：离线 FRB 测试用凭证内的身份材料 + `local_addrs()` 直连、以
  nonce 一致性构造 `PairingTarget`，属测试手法；产品凭证入口仍禁止 mDNS（决策 20）。
- **空 nonce 兼容后门被明确禁止**（不是「保留待议」）：任何形式的空 / 全零 nonce 放行都
  视为回归。
