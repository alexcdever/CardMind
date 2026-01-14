# 同步机制设计 (Sync Mechanism)

本文档定义 CardMind 的同步机制设计,包括订阅驱动更新、P2P 设备发现和数据池同步策略。

**实现细节请查看源码**: 运行 `cargo doc --open` 查看自动生成的 Rust 同步模块文档。

---

## 1. 订阅驱动更新机制

### 1.1 设计原理

源数据层 (Loro CRDT) 变更时,通过**观察者模式**通知缓存层 (SQLite) 更新,保证数据一致性。

```mermaid
sequenceDiagram
    participant User as 用户操作
    participant Loro as Loro CRDT
    participant Sub as 订阅回调
    participant SQLite as SQLite 缓存

    User->>Loro: 修改数据 (insert/update/delete)
    User->>Loro: commit()
    Loro->>Sub: 触发订阅事件
    Sub->>Sub: 解析变更事件
    Sub->>SQLite: 执行 SQL (INSERT/UPDATE/DELETE)
    SQLite-->>Sub: 确认
    Loro->>Loro: 持久化到文件
```

### 1.2 流程说明

1. **写入源数据层**: 用户操作触发数据修改 (创建、更新、删除卡片)
2. **提交变更**: 调用 `commit()` 接口,标记变更完成
3. **触发订阅回调**: 源数据层通知所有订阅者
4. **更新缓存层**: 订阅者接收变更事件,更新 SQLite 缓存
5. **通知 UI 刷新**: 缓存层触发 UI 重新查询 (Flutter 层实现)

### 1.3 订阅保证

**原子性**: 订阅回调在同一事务内执行

```rust
// 伪代码
fn subscription_callback(event: LoroEvent) -> Result<()> {
    let tx = sqlite.transaction()?; // 开始事务

    match event {
        LoroEvent::Create => tx.execute("INSERT INTO cards ...")?,
        LoroEvent::Update => tx.execute("UPDATE cards ...")?,
        LoroEvent::Delete => tx.execute("UPDATE cards SET is_deleted = 1 ...")?,
    }

    tx.commit()?; // 提交事务
    Ok(())
}
```

**一致性**: 缓存更新失败不影响源数据层

```rust
// 伪代码
if let Err(e) = sync_to_sqlite(event) {
    // 记录错误,但不回滚 Loro 的 commit
    error!("Failed to sync to SQLite: {}", e);
    // SQLite 可以稍后重建,Loro 数据永不丢失
}
```

**顺序性**: 订阅顺序与提交顺序一致

- Loro 保证事件按提交顺序触发
- SQLite 更新严格按事件顺序执行

### 1.4 订阅事件类型

| Loro 事件 | SQLite 操作 | 说明 |
|-----------|------------|------|
| `Create` | `INSERT INTO cards ...` | 新建卡片 |
| `Update` | `UPDATE cards SET ...` | 修改字段 |
| `Delete` | `UPDATE cards SET is_deleted = 1 ...` | 软删除 |

**注意**: 删除操作使用软删除 (设置标记),而非物理删除 (DELETE FROM)。

### 1.5 故障恢复

**SQLite 损坏场景**:
1. 检测到 SQLite 数据损坏 (如校验和错误)
2. 删除旧的 `cache.db` 文件
3. 重新创建空数据库
4. 从 Loro 全量同步所有卡片 (遍历 Loro 文档)
5. 重建索引

**数据一致性保证**: Loro 是真理源,SQLite 可随时重建。

---

## 2. 初始化与设备发现 (单池模型)

### 2.1 初始化决策

**目标**: 区分第一台设备(创建笔记空间)与后续设备(加入已存在空间)。

**流程概览**:
```rust
// 伪代码
let config = DeviceConfig::load_or_create()?;
if config.pool_id.is_some() {
    return InitAction::EnterMain; // 已加入,直接进入并启动同步
}

let discovery = start_mdns_discovery().await?;
if discovery.peers.is_empty() {
    return InitAction::ShowCreateWizard; // 未发现同伴,引导创建
}

InitAction::ShowChoice { peers: discovery.peers } // 选择配对或创建
```

### 2.2 发现协议

使用**本地网络广播**协议 (mDNS),设备在同一局域网内自动发现唯一的笔记空间。

```mermaid
sequenceDiagram
    participant NewDevice as 新设备
    participant mDNS as mDNS 服务
    participant ExistingDevice as 现有设备

    NewDevice->>mDNS: 监听广播
    ExistingDevice->>mDNS: 广播 pool_id
    mDNS->>NewDevice: 发现可用 pool_id
    NewDevice->>NewDevice: 显示可加入的笔记空间
```

### 2.3 广播内容 (非敏感信息)

**mDNS 广播包含**:
```json
{
  "device_id": "device-001",
  "device_name": "MacBook-018c8",  // 默认昵称 (设备型号-UUID前5位)
  "pool_id": "pool-abc"            // 仅暴露唯一数据池 ID (未加入时可省略)
}
```

**说明**:
- `device_name` 使用即时生成的默认昵称,避免暴露数据池内昵称
- 单设备仅暴露单个 `pool_id`; 未初始化时可不带该字段
- 防止泄露用户在特定数据池中的身份信息

**隐私保护策略**:
- ✅ **仅暴露 `pool_id`** (UUID): 未授权设备无法推断数据池用途
- ❌ **不暴露 `pool_name`**: 防止泄露敏感业务信息 (如 "公司机密项目")
- ✅ **密码验证后获取**: 新设备需输入正确密码后才能获取数据池名称和详细信息

### 2.4 连接建立

```mermaid
sequenceDiagram
    participant NewDevice as 新设备
    participant ExistingDevice as 现有设备
    participant PoolDoc as 数据池 LoroDoc
    participant Keyring as 系统 Keyring

    NewDevice->>NewDevice: 用户选择设备并输入密码
    NewDevice->>ExistingDevice: 发送 (pool_id, password, timestamp) 🔒 TLS 加密
    ExistingDevice->>ExistingDevice: 验证时间戳（5分钟内有效）
    ExistingDevice->>PoolDoc: 读取 password_hash
    ExistingDevice->>ExistingDevice: bcrypt 验证密码
    ExistingDevice->>ExistingDevice: 立即清零密码内存 (zeroize)
    alt 密码正确
        ExistingDevice->>NewDevice: 发送数据池 LoroDoc
        NewDevice->>NewDevice: 导入数据池 LoroDoc
        NewDevice->>PoolDoc: 添加自己到 members 列表
        NewDevice->>Keyring: 存储密码（OS 级加密）
        ExistingDevice->>NewDevice: 同步该池的所有卡片
    else 密码错误或时间戳过期
        ExistingDevice->>NewDevice: 返回错误
        NewDevice->>NewDevice: 提示用户密码错误
    end
```

### 2.4.1 安全加固措施

**传输层安全**:
- **强制 TLS 加密**: libp2p 配置强制使用 TLS，拒绝明文连接
- **加密算法**: AES-256-GCM（libp2p 默认）
- **证书验证**: 使用 libp2p 自签名证书（本地网络信任模型）

**内存安全**:
- **敏感数据清零**: 使用 `zeroize` crate 清除密码内存
- **验证后立即清理**: bcrypt 验证完成后立即清零密码
- **避免日志泄露**: 密码不出现在任何日志中

**请求时效性**（防简单重放攻击）:
- **时间戳验证**: 加入请求包含 Unix 毫秒时间戳
- **有效期**: 请求在 5 分钟内有效
- **时钟偏差**: 容忍 ±30 秒偏差（可配置）

**密码强度要求**:
- **最少长度**: 8 位字符
- **建议复杂度**: 包含字母、数字（可选，不强制）
- **创建时验证**: 数据池创建时检查密码强度

**实现伪代码**:
```rust
// 1. 强制 TLS 配置
let transport = libp2p::tcp::Transport::default()
    .upgrade(libp2p::core::upgrade::Version::V1)
    .authenticate(libp2p::noise::Config::new(&keypair)?)
    .multiplex(libp2p::yamux::Config::default());

// 2. 密码内存清理
use zeroize::Zeroizing;

fn verify_password(password: Zeroizing<String>, hash: &str) -> Result<bool> {
    let result = bcrypt::verify(&password, hash)?;
    // password 离开作用域时自动清零内存
    Ok(result)
}

// 3. 时间戳验证
struct JoinRequest {
    pool_id: String,
    password: Zeroizing<String>,
    timestamp: u64,  // Unix 毫秒时间戳
}

fn validate_request(req: &JoinRequest) -> Result<()> {
    let now = current_timestamp_ms();
    let diff = now.abs_diff(req.timestamp);

    if diff > 300_000 {  // 5 分钟
        return Err("请求已过期");
    }
    Ok(())
}

// 4. 密码强度验证
fn validate_password_strength(password: &str) -> Result<()> {
    if password.len() < 8 {
        return Err("密码至少 8 位");
    }
    Ok(())
}
```

### 2.5 安全保证总结

**多层防护体系**:

1. **传输层**: libp2p TLS 加密（AES-256-GCM）
2. **验证层**: bcrypt 慢哈希（防暴力破解）
3. **内存层**: zeroize 清零敏感数据
4. **存储层**: 系统 Keyring OS 级加密
5. **时效层**: 时间戳验证（防简单重放）

**安全等级**: 适用于家庭/个人局域网场景，提供足够的安全保护。

**未来升级路径**: 如需更高安全性（如广域网），可升级到 SPAKE2 协议（v2.1.0+）。

### 2.6 自动重连机制

**App 启动时**:
1. 读取本地配置文件 (`config.json`)，获取单个 `pool_id`
2. 如果存在 `pool_id`，加载对应 Pool CRDT 详情
3. 从系统 Keyring 读取该池的密码
4. 自动连接到已发现的池成员设备（通过 mDNS）
5. 如果密码验证失败,提示用户重新输入

**保证**: 用户无需每次手动输入密码,自动恢复同步。

**实现伪代码**:
```rust
fn auto_reconnect_on_startup(config: &Config) -> Result<()> {
    let Some(pool_id) = &config.pool_id else {
        return Ok(()); // 未加入,交由初始化流程处理
    };

    let _pool = load_pool_crdt(pool_id)?; // 预热,获取池详情
    let password = keyring::get_password(&format!("cardmind.pool.{}.password", pool_id))?;

    connect_to_pool(pool_id, &password)?;
    Ok(())
}
```

---

## 3. 数据池同步策略 (单池模型)

### 3.1 同步范围

**规则**:
- 每个设备只存在一个 `pool_id`; 未加入则直接返回 `NotJoinedPool`
- 同步顺序: 先同步 Pool 文档,再根据 `Pool.card_ids` 同步对应卡片
- 不再使用 `card.pool_ids ∩ device.joined_pools` 交集过滤

**伪代码**:
```rust
fn sync_with_peer(peer: PeerId) -> Result<()> {
    let pool_id = device_config.pool_id.ok_or(CardMindError::NotJoinedPool)?;

    // 1) 同步 Pool 文档 (包含 members + card_ids)
    sync_pool_doc(peer, &pool_id)?;

    // 2) 使用 Pool.card_ids 作为唯一同步列表
    let card_ids = load_pool_card_ids(&pool_id)?;
    for card_id in card_ids {
        sync_card_doc(peer, &card_id)?;
    }
    Ok(())
}
```

**移除传播**:
- 移除卡片 = 从 `Pool.card_ids` 删除并 commit
- 由于 Pool 文档不受 SyncFilter 限制,所有设备都能收到移除事件

### 3.2 冲突解决

**CRDT 自动合并**: Pool.card_ids 与 Card 文档均由 Loro CRDT 管理,自动处理并发修改。

**示例场景**:
- 设备 A 离线删除卡片,设备 B 离线编辑卡片
- 联网后 Pool 文档删除事件与 Card 文档更新同时合并
- 订阅回调依据最终的 Pool.card_ids 决定是否保留卡片绑定

**保证**:
- 无需用户干预
- 保证最终一致性
- 移除操作可靠传播

### 3.3 离线支持

**离线编辑**:
- 离线时正常编辑卡片或维护 Pool.card_ids
- 修改保存在本地 Loro 文档

**联网后同步**:
1. 检测到网络连接
2. 导出 Pool 与 Card 的本地更新 (`export_updates`)
3. 与对等设备交换更新
4. 导入更新 (`import_updates`)
5. commit 触发订阅,自动更新 SQLite

### 3.4 增量同步

**设计**: Pool 与 Card 文档均按增量同步,记录各自的版本。

**流程**:
```rust
fn sync_with_peer(peer: PeerId) -> Result<()> {
    let pool_id = device_config.pool_id.ok_or(CardMindError::NotJoinedPool)?;

    // Pool 增量同步
    sync_doc_increments(peer, &pool_id, DocKind::Pool)?;

    // 卡片增量同步
    for card_id in load_pool_card_ids(&pool_id)? {
        sync_doc_increments(peer, &card_id, DocKind::Card)?;
    }
    Ok(())
}
```

**优势**:
- 同步范围由 Pool.card_ids 精确限定,无需额外过滤逻辑
- 减少网络流量,并保持移除事件可靠传播

---

## 4. 数据池网络架构 (单池模型)

### 4.1 数据池生命周期

```mermaid
stateDiagram-v2
    [*] --> 初始化: App 首次启动
    初始化 --> 已加入: 读取 DeviceConfig.pool_id
    已加入 --> 同步: 自动重连
    初始化 --> 发现: mDNS 广播
    发现 --> 加入: 输入密码验证
    加入 --> 同步: 连接成功
    同步 --> 同步: 持续同步
    同步 --> 退出: 用户主动退出
    退出 --> [*]: 删除本地数据
```

**说明**:
- 若本地已有 `pool_id`,跳过发现直接进入同步
- 未加入时才执行发现/创建分支,符合单池约束

### 4.2 数据池角色

**平等权限模型**:
- 所有成员权限相同
- 一个用户 = 一个数据池,设备只能加入一个池
- 所有成员都可以修改数据池信息 (昵称、成员列表)
- 不支持"踢出成员"功能,仅支持"主动退出"

**未来扩展**:
- 引入角色系统 (管理员/普通成员)
- 管理员可踢出成员
- 细粒度权限控制

### 4.3 密码管理

**密码修改流程**:
1. 任意成员修改数据池密码 (修改 `password_hash` 字段)
2. 修改通过 CRDT 同步到所有在线设备
3. 离线设备重连时,使用旧密码验证失败
4. 提示用户重新输入新密码
5. 验证通过后更新系统 Keyring

**安全保证**:
- 密码修改立即生效
- 旧密码无法访问数据池
- 新密码存储在系统 Keyring (加密)

---

## 5. 健康检查和状态监控

### 5.1 在线状态检测

**心跳机制**:
- App 定期发送心跳包 (每 30 秒)
- 如果 60 秒内未收到心跳,标记设备离线
- UI 显示设备在线/离线状态

**libp2p 集成**:
- 使用 libp2p 的 Ping 协议
- 自动检测网络连接状态
- 断线自动重连

### 5.2 同步状态监控

**同步状态**:
- `Idle`: 空闲,无同步任务
- `Syncing`: 正在同步
- `Completed`: 同步完成
- `Failed`: 同步失败 (显示错误原因)

**UI 反馈**:
- 同步中: 显示旋转图标
- 同步完成: 显示勾选图标 (2 秒后消失)
- 同步失败: 显示警告图标,点击重试

### 5.3 冲突检测

**自动冲突解决**: CRDT 算法自动处理,无需用户干预

**日志记录**:
- 记录冲突发生的时间、设备、卡片 ID
- 供调试和审计使用
- 不影响用户体验

---

## 6. 性能优化策略

### 6.1 订阅优化

**批量更新**:
- 多个修改在同一 `commit()` 中批量提交
- 减少订阅回调次数
- 提高 SQLite 更新效率

**延迟更新**:
- UI 编辑时不立即 commit
- 用户停止编辑后 (如 500ms 无输入) 再 commit
- 避免频繁触发订阅

### 6.2 同步优化

**增量传输**:
- 仅传输变更部分,不传输完整文档
- 记录同步版本,支持断点续传

**压缩传输**:
- 使用 gzip 或 zstd 压缩数据
- 减少网络流量

**并行同步**:
- 同时与多个对等设备同步
- 提高同步速度

### 6.3 存储优化

**Loro 文件合并**:
- 当 `update.loro` 超过 1MB 时,合并到 `snapshot.loro`
- 控制文件大小,提高加载速度

**SQLite 缓存清理**:
- 定期清理软删除的卡片 (可选)
- 执行 `VACUUM` 释放空间

---

## 7. 相关文档

**架构层文档**:
- [SYSTEM_DESIGN.md](SYSTEM_DESIGN.md) - 系统设计原则
- [DATA_CONTRACT.md](DATA_CONTRACT.md) - 数据契约定义
- [LAYER_SEPARATION.md](LAYER_SEPARATION.md) - 分层策略
- [TECH_CONSTRAINTS.md](TECH_CONSTRAINTS.md) - 技术选型理由

**实现细节**:
- 运行 `cargo doc --open` 查看 Rust 同步模块文档
- 源码位置:
  - 订阅机制: `rust/src/store/subscription.rs`
  - P2P 同步: `rust/src/sync/`

---

## 更新日志

| 版本 | 变更 |
|------|------|
| 1.3.0 | 适配单池模型：新增初始化决策流程、Pool.card_ids 驱动同步范围、单池广播与自动重连逻辑 |
| 1.2.0 | 增强隐私保护：mDNS 广播仅暴露 `pool_id`，不暴露 `pool_name`；密码验证后才能获取数据池详细信息 |
| 1.1.0 | 更新设备昵称机制：mDNS 广播使用默认昵称；自动重连时从 CRDT 读取数据池详细信息 |
| 1.0.0 | 初始版本,从 PRD.md 和 DATABASE.md 提取同步机制设计 |

---

**设计哲学**: 本文档定义同步机制的设计理念和流程,使用流程图和伪代码展示原理,不包含具体实现。同步的核心是"订阅驱动、单向数据流、CRDT 自动冲突解决"。
