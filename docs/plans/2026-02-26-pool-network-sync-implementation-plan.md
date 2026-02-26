# 数据池组网与同步 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 基于 iroh 完成数据池组网与同步（池元数据 + 卡片数据），全成员互联、前景常驻同步、管理员白名单准入。

**Architecture:** Rust 侧新增 iroh 连接层与同步协调器，负责加入/审批消息与 Loro 快照/增量同步；FRB 暴露薄层 API 给 Flutter。同步以 Loro 文档为真相源，先快照后增量，断线重连补漏。

**Tech Stack:** Rust, iroh, tokio, Loro, SQLite, flutter_rust_bridge, serde, postcard

---

### Task 1: 移除 pool_key 并更新持久化与测试

**Files:**
- Modify: `rust/src/models/pool.rs`
- Modify: `rust/src/store/pool_store.rs`
- Modify: `rust/src/store/sqlite_store.rs`
- Modify: `rust/tests/sqlite_store_pool_test.rs`
- Modify: `rust/tests/pool_store_persist_test.rs`
- Modify: `rust/src/models/DIR.md`
- Modify: `rust/src/store/DIR.md`

**Step 1: 更新测试以移除 pool_key 字段**

```rust
let pool = Pool {
    pool_id: new_uuid_v7(),
    members: vec![PoolMember {
        endpoint_id: "ep".to_string(),
        nickname: "nick".to_string(),
        os: "mac".to_string(),
        is_admin: true,
    }],
    card_ids: vec![],
};
```

**Step 2: 运行测试，确认失败（缺少 pool_key 相关实现）**

Run: `cargo test --test sqlite_store_pool_test --test pool_store_persist_test`
Expected: FAIL（`pool_key` 字段仍存在 / 结构不匹配）

**Step 3: 修改模型与存储，删除 pool_key**

- `Pool` 结构移除 `pool_key`
- `PoolStore::create_pool` 删除 `pool_key` 参数与校验
- SQLite `pools` 表移除 `pool_key` 字段，读写逻辑同步调整
- 更新文件头 `input/output/pos` 与 `DIR.md`

```rust
pub struct Pool {
    pub pool_id: Uuid,
    pub members: Vec<PoolMember>,
    pub card_ids: Vec<Uuid>,
}
```

**Step 4: 运行测试，确认通过**

Run: `cargo test --test sqlite_store_pool_test --test pool_store_persist_test`
Expected: PASS

**Step 5: 提交**

```bash
git add rust/src/models/pool.rs rust/src/store/pool_store.rs rust/src/store/sqlite_store.rs \
  rust/tests/sqlite_store_pool_test.rs rust/tests/pool_store_persist_test.rs \
  rust/src/models/DIR.md rust/src/store/DIR.md
git commit -m "feat(pool): drop pool_key from schema"
```

---

### Task 2: 新增成员权限错误码

**Files:**
- Modify: `rust/src/models/api_error.rs`
- Modify: `rust/src/models/error.rs`
- Modify: `rust/src/api.rs`
- Modify: `rust/tests/api_error_test.rs`
- Modify: `rust/src/models/DIR.md`

**Step 1: 编写失败测试，校验新增错误码**

```rust
#[test]
fn it_should_format_not_member_error_code() {
    assert_eq!(ApiErrorCode::NotMember.as_str(), "NOT_MEMBER");
}
```

**Step 2: 运行测试，确认失败（NotMember 未定义）**

Run: `cargo test --test api_error_test`
Expected: FAIL（`NotMember` 不存在）

**Step 3: 实现错误码与映射**

```rust
pub enum ApiErrorCode {
    // ...
    NotMember,
}

match self {
    // ...
    ApiErrorCode::NotMember => "NOT_MEMBER",
}
```

```rust
pub enum CardMindError {
    // ...
    NotMember(String),
}
```

```rust
CardMindError::NotMember(msg) => ApiError::new(ApiErrorCode::NotMember, &msg),
```

**Step 4: 运行测试，确认通过**

Run: `cargo test --test api_error_test`
Expected: PASS

**Step 5: 提交**

```bash
git add rust/src/models/api_error.rs rust/src/models/error.rs rust/src/api.rs \
  rust/tests/api_error_test.rs rust/src/models/DIR.md
git commit -m "feat(pool): add not-member error code"
```

---

### Task 3: 新增同步消息模型与编解码

**Files:**
- Create: `rust/src/net/DIR.md`
- Create: `rust/src/net/mod.rs`
- Create: `rust/src/net/messages.rs`
- Create: `rust/src/net/codec.rs`
- Modify: `rust/src/lib.rs`
- Modify: `rust/src/DIR.md`
- Test: `rust/tests/pool_net_codec_test.rs`

**Step 1: 编写失败测试，验证消息序列化/反序列化**

```rust
let msg = PoolMessage::Hello { pool_id, endpoint_id, nickname, os };
let bytes = encode_message(&msg)?;
let decoded = decode_message(&bytes)?;
assert_eq!(decoded, msg);
```

**Step 2: 运行测试，确认失败（模块不存在）**

Run: `cargo test --test pool_net_codec_test`
Expected: FAIL（模块/函数未定义）

**Step 3: 实现消息结构与编解码（postcard + length prefix）**

```rust
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum PoolMessage {
    Hello { pool_id: Uuid, endpoint_id: String, nickname: String, os: String },
    JoinRequest { pool_id: Uuid, applicant: PoolMember },
    JoinForward { pool_id: Uuid, applicant: PoolMember },
    JoinDecision { pool_id: Uuid, approved: bool, reason: Option<String> },
    PoolSnapshot { pool_id: Uuid, bytes: Vec<u8> },
    PoolUpdates { pool_id: Uuid, bytes: Vec<u8> },
    CardSnapshot { card_id: Uuid, bytes: Vec<u8> },
    CardUpdates { card_id: Uuid, bytes: Vec<u8> },
}
```

```rust
pub fn encode_message(msg: &PoolMessage) -> Result<Vec<u8>, CardMindError> { /* postcard */ }
pub fn decode_message(bytes: &[u8]) -> Result<PoolMessage, CardMindError> { /* postcard */ }
```

**Step 4: 运行测试，确认通过**

Run: `cargo test --test pool_net_codec_test`
Expected: PASS

**Step 5: 提交**

```bash
git add rust/src/net/DIR.md rust/src/net/mod.rs rust/src/net/messages.rs \
  rust/src/net/codec.rs rust/src/lib.rs rust/src/DIR.md \
  rust/tests/pool_net_codec_test.rs
git commit -m "feat(pool): add pool network message codec"
```

---

### Task 4: 引入 iroh 与端点管理器

**Files:**
- Modify: `rust/Cargo.toml`
- Create: `rust/src/net/endpoint.rs`
- Modify: `rust/src/net/mod.rs`
- Modify: `rust/src/net/DIR.md`
- Test: `rust/tests/pool_net_endpoint_test.rs`

**Step 1: 编写失败测试，验证端点可启动与互连**

```rust
#[tokio::test]
async fn it_should_connect_two_endpoints() {
    let (a, b) = build_test_endpoints().await?;
    let _conn = a.connect(b.endpoint_id()).await?;
    Ok(())
}
```

**Step 2: 运行测试，确认失败（iroh 依赖未引入）**

Run: `cargo test --test pool_net_endpoint_test`
Expected: FAIL（缺少 iroh / tokio 依赖）

**Step 3: 添加依赖并实现端点管理器**

- `Cargo.toml` 添加 `iroh`、`tokio`、`postcard`
- 端点构建使用自定义 ALPN，并配置 discovery（本地 mDNS + DNS 地址解析）

```toml
[dependencies]
iroh = { version = "0.96.1", features = ["discovery-local-network", "dns"] }
tokio = { version = "1", features = ["rt-multi-thread", "macros"] }
postcard = { version = "1", features = ["alloc"] }
```

```rust
pub const POOL_ALPN: &[u8] = b"cardmind/pool/1";

pub async fn build_endpoint() -> Result<Endpoint, CardMindError> {
    let mdns = MdnsDiscovery::new().await?;
    let endpoint = Endpoint::builder()
        .alpns(vec![POOL_ALPN.to_vec()])
        .discovery(Box::new(mdns))
        .address_lookup(Box::new(DnsAddressLookup::new()))
        .bind()
        .await?;
    Ok(endpoint)
}
```

**Step 4: 运行测试，确认通过**

Run: `cargo test --test pool_net_endpoint_test`
Expected: PASS

**Step 5: 提交**

```bash
git add rust/Cargo.toml rust/src/net/endpoint.rs rust/src/net/mod.rs \
  rust/src/net/DIR.md rust/tests/pool_net_endpoint_test.rs
git commit -m "feat(pool): add iroh endpoint manager"
```

---

### Task 5: 会话管理与握手校验

**Files:**
- Create: `rust/src/net/session.rs`
- Modify: `rust/src/net/mod.rs`
- Modify: `rust/src/net/DIR.md`
- Test: `rust/tests/pool_net_session_test.rs`

**Step 1: 编写失败测试，校验非成员连接被拒绝**

```rust
#[tokio::test]
async fn it_should_reject_non_member() {
    let session = PoolSession::new(pool_id, members);
    let result = session.validate_peer("unknown");
    assert!(matches!(result, Err(CardMindError::NotMember(_))));
}
```

**Step 2: 运行测试，确认失败**

Run: `cargo test --test pool_net_session_test`
Expected: FAIL

**Step 3: 实现会话管理与握手流程**

```rust
pub struct PoolSession {
    pool_id: Uuid,
    members: HashSet<String>,
}

pub fn validate_peer(&self, endpoint_id: &str) -> Result<(), CardMindError> {
    if self.members.contains(endpoint_id) { Ok(()) } else { Err(CardMindError::NotMember("not member".into())) }
}
```

**Step 4: 运行测试，确认通过**

Run: `cargo test --test pool_net_session_test`
Expected: PASS

**Step 5: 提交**

```bash
git add rust/src/net/session.rs rust/src/net/mod.rs rust/src/net/DIR.md \
  rust/tests/pool_net_session_test.rs
git commit -m "feat(pool): add session membership check"
```

---

### Task 6: Loro 快照/增量同步协调器

**Files:**
- Modify: `rust/src/store/loro_store.rs`
- Create: `rust/src/net/sync.rs`
- Modify: `rust/src/net/mod.rs`
- Modify: `rust/src/net/DIR.md`
- Test: `rust/tests/pool_sync_test.rs`

**Step 1: 编写失败测试，验证快照 + 增量导入**

```rust
let a = LoroDoc::new();
a.get_text("t").insert(0, "hi")?;
a.commit();
let snap = export_snapshot(&a)?;
let b = LoroDoc::from_snapshot(&snap)?;

b.get_text("t").insert(2, "!")?;
b.commit();
let updates = export_updates(&b, &a.oplog_vv())?;
let status = import_updates(&a, &updates)?;
assert!(status.pending.is_empty());
```

**Step 2: 运行测试，确认失败**

Run: `cargo test --test pool_sync_test`
Expected: FAIL

**Step 3: 实现导出/导入与同步协调器**

```rust
pub fn export_snapshot(doc: &LoroDoc) -> Result<Vec<u8>, CardMindError> {
    doc.export(ExportMode::Snapshot).map_err(|e| CardMindError::Loro(e.to_string()))
}

pub fn export_updates(doc: &LoroDoc, from: &VersionVector) -> Result<Vec<u8>, CardMindError> {
    doc.export(ExportMode::updates(from)).map_err(|e| CardMindError::Loro(e.to_string()))
}

pub fn import_updates(doc: &LoroDoc, bytes: &[u8]) -> Result<ImportStatus, CardMindError> {
    doc.import(bytes).map_err(|e| CardMindError::Loro(e.to_string()))
}
```

**Step 4: 运行测试，确认通过**

Run: `cargo test --test pool_sync_test`
Expected: PASS

**Step 5: 提交**

```bash
git add rust/src/store/loro_store.rs rust/src/net/sync.rs rust/src/net/mod.rs \
  rust/src/net/DIR.md rust/tests/pool_sync_test.rs
git commit -m "feat(pool): add Loro snapshot/update sync helpers"
```

---

### Task 7: 组网与同步主流程（会话 + 同步整合）

**Files:**
- Create: `rust/src/net/pool_network.rs`
- Modify: `rust/src/net/mod.rs`
- Modify: `rust/src/net/DIR.md`
- Test: `rust/tests/pool_network_flow_test.rs`

**Step 1: 编写失败测试，模拟两节点首次同步**

```rust
#[tokio::test]
async fn it_should_sync_pool_and_cards() {
    let (a, b) = build_test_endpoints().await?;
    let net_a = PoolNetwork::new(a, pool_store_a, card_store_a);
    let net_b = PoolNetwork::new(b, pool_store_b, card_store_b);
    net_a.start().await?;
    net_b.start().await?;
    net_a.connect_and_sync(net_b.endpoint_id()).await?;
    assert!(net_b.has_card(card_id)?);
    Ok(())
}
```

**Step 2: 运行测试，确认失败**

Run: `cargo test --test pool_network_flow_test`
Expected: FAIL

**Step 3: 实现同步流程编排**

- 连接后先发送 `Hello`，校验 `members` 白名单
- 新成员：发送池元数据快照 + 缺失卡片快照
- 常驻：监听本地 Loro 变更，广播增量；重连后补漏

```rust
pub async fn connect_and_sync(&self, peer: EndpointId) -> Result<(), CardMindError> {
    let conn = self.endpoint.connect(peer, POOL_ALPN).await?;
    self.send_hello(&conn).await?;
    self.sync_pool_snapshot_if_needed(&conn).await?;
    self.sync_cards_snapshot_if_needed(&conn).await?;
    self.spawn_incremental_sync(conn).await?;
    Ok(())
}
```

**Step 4: 运行测试，确认通过**

Run: `cargo test --test pool_network_flow_test`
Expected: PASS

**Step 5: 提交**

```bash
git add rust/src/net/pool_network.rs rust/src/net/mod.rs rust/src/net/DIR.md \
  rust/tests/pool_network_flow_test.rs
git commit -m "feat(pool): add pool network sync flow"
```

---

### Task 8: FRB API 暴露与 Dart 绑定更新

**Files:**
- Modify: `rust/src/api.rs`
- Modify: `rust/src/lib.rs`
- Modify: `lib/bridge_generated/frb_generated.dart`
- Modify: `lib/bridge_generated/api.dart`
- Modify: `flutter_rust_bridge.yaml`
- Test: `rust/tests/api_handle_test.rs`

**Step 1: 编写失败测试，验证 PoolNetwork 句柄初始化/关闭**

```rust
#[test]
fn it_should_init_and_close_pool_network() -> Result<(), Box<dyn std::error::Error>> {
    let id = init_pool_network("/tmp/cardmind".to_string())?;
    close_pool_network(id)?;
    Ok(())
}
```

**Step 2: 运行测试，确认失败**

Run: `cargo test --test api_handle_test`
Expected: FAIL

**Step 3: 实现 FRB API 与 Dart 绑定**

```rust
pub fn init_pool_network(base_path: String) -> Result<u64, ApiError> { /* create + store handle */ }
pub fn close_pool_network(id: u64) -> Result<(), ApiError> { /* drop handle */ }
```

- 运行 `flutter_rust_bridge_codegen generate` 更新 Dart 绑定

**Step 4: 运行测试，确认通过**

Run: `cargo test --test api_handle_test`
Expected: PASS

**Step 5: 提交**

```bash
git add rust/src/api.rs rust/src/lib.rs lib/bridge_generated/frb_generated.dart \
  lib/bridge_generated/api.dart rust/tests/api_handle_test.rs
flutter_rust_bridge_codegen generate
git commit -m "feat(pool): expose pool network api"
```

---

### Task 9: 文档与清单同步

**Files:**
- Modify: `docs/plans/DIR.md`
- Modify: `docs/plans/2026-02-18-cardmind-rebuild-design.md`

**Step 1: 更新文档描述**
- 移除 `pool_key` 表述
- 补充 iroh 组网与同步实现状态

**Step 2: 运行检查**

Run: `rg -n "pool_key" docs/plans`
Expected: 仅剩历史文档中不可变更内容

**Step 3: 提交**

```bash
git add docs/plans/DIR.md docs/plans/2026-02-18-cardmind-rebuild-design.md
git commit -m "docs: align pool sync design"
```
