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

## 2. P2P 设备发现 (Phase 2)

### 2.1 发现协议

使用**本地网络广播**协议 (mDNS),设备在同一局域网内自动发现。

```mermaid
sequenceDiagram
    participant NewDevice as 新设备
    participant mDNS as mDNS 服务
    participant ExistingDevice as 现有设备

    NewDevice->>mDNS: 监听广播
    ExistingDevice->>mDNS: 广播数据池信息
    mDNS->>NewDevice: 发现数据池列表
    NewDevice->>NewDevice: 显示可加入的数据池
```

### 2.2 广播内容 (非敏感信息)

**mDNS 广播包含**:
```json
{
  "device_id": "device-001",
  "device_name": "MacBook Pro",
  "pools": [
    {
      "pool_id": "pool-abc",
      "pool_name": "工作笔记"
    }
  ]
}
```

**不包含的敏感信息**:
- ❌ 密码或密码哈希
- ❌ 成员列表
- ❌ 卡片数量或内容
- ❌ 任何业务数据

**隐私保护**: 未授权设备无法通过 mDNS 获取数据池的实质性信息。

### 2.3 连接建立

```mermaid
sequenceDiagram
    participant NewDevice as 新设备
    participant ExistingDevice as 现有设备
    participant PoolDoc as 数据池 LoroDoc
    participant Keyring as 系统 Keyring

    NewDevice->>NewDevice: 用户选择数据池
    NewDevice->>NewDevice: 用户输入密码
    NewDevice->>ExistingDevice: 发送 (pool_id, password)
    ExistingDevice->>PoolDoc: 读取 password_hash
    ExistingDevice->>ExistingDevice: bcrypt 验证密码
    alt 密码正确
        ExistingDevice->>NewDevice: 发送数据池 LoroDoc
        NewDevice->>NewDevice: 导入数据池 LoroDoc
        NewDevice->>PoolDoc: 添加自己到 members 列表
        NewDevice->>Keyring: 存储密码
        ExistingDevice->>NewDevice: 同步该数据池的所有卡片
    else 密码错误
        ExistingDevice->>NewDevice: 返回错误
        NewDevice->>NewDevice: 提示用户密码错误
    end
```

### 2.4 安全保证

1. **密码验证**: 使用 bcrypt 哈希对比,不传输明文
2. **加密传输**: libp2p 提供加密连接 (TLS)
3. **授权访问**: 未授权设备无法访问数据池内容

### 2.5 自动重连机制

**App 启动时**:
1. 遍历 `joined_pools` 列表
2. 从系统 Keyring 读取每个数据池的密码
3. 自动连接到已发现的数据池成员设备
4. 如果密码验证失败 (例如密码已更改),提示用户重新输入

**保证**: 用户无需每次手动输入密码,自动恢复同步。

---

## 3. 数据池同步策略 (Phase 2)

### 3.1 同步范围

**过滤规则**: 仅同步满足以下条件的卡片:

```
card.pool_ids ∩ device.joined_pools ≠ ∅
```

**含义**: 卡片的绑定池与设备的加入池有交集。

**伪代码**:
```rust
fn should_sync_card(card: &Card, device: &Device) -> bool {
    let device_pools: HashSet<_> = device.joined_pools.iter().collect();
    let card_pools: HashSet<_> = card.pool_ids.iter().collect();

    !device_pools.is_disjoint(&card_pools)
}
```

**示例**:
- 卡片绑定: `pool_ids = ["pool-A", "pool-B"]`
- 设备加入: `joined_pools = ["pool-A", "pool-C"]`
- 结果: 同步 (因为 `pool-A` 在交集中)

### 3.2 冲突解决

**CRDT 自动合并**: 使用 Loro CRDT 的自动冲突解决算法

**示例场景**:
- 设备 A 离线修改卡片标题: "标题 A"
- 设备 B 离线修改卡片标题: "标题 B"
- 联网后 CRDT 合并: "标题 A标题 B" 或按时间戳选择最新

**保证**:
- 无需用户干预
- 保证最终一致性
- 数据永不丢失

### 3.3 离线支持

**离线编辑**:
- 离线时正常编辑卡片
- 修改保存在本地 Loro 文档

**联网后同步**:
1. 检测到网络连接
2. 导出本地更新 (`loro.export_updates()`)
3. 发送更新到对等设备
4. 接收对等设备的更新
5. 导入更新 (`loro.import_updates()`)
6. CRDT 自动合并冲突

**多设备离线编辑**:
- 设备 A 和设备 B 同时离线编辑
- 各自修改不同卡片或同一卡片的不同字段
- 联网后自动合并,无需手动处理

### 3.4 增量同步

**设计**: 仅同步变更部分,不传输完整文档

**流程**:
```rust
// 伪代码
fn sync_with_peer(peer: PeerId) -> Result<()> {
    // 1. 获取本地最后同步版本
    let last_sync_version = get_last_sync_version(peer)?;

    // 2. 导出增量更新
    let updates = loro_doc.export_from(last_sync_version)?;

    // 3. 发送到对等设备
    send_to_peer(peer, updates)?;

    // 4. 接收对等设备的更新
    let peer_updates = receive_from_peer(peer)?;

    // 5. 导入更新
    loro_doc.import(&peer_updates)?;

    // 6. commit 触发订阅,自动更新 SQLite
    loro_doc.commit();

    // 7. 更新同步版本
    set_last_sync_version(peer, loro_doc.current_version())?;

    Ok(())
}
```

**优势**:
- 减少网络流量
- 提高同步速度
- 支持断点续传 (记录同步版本)

---

## 4. 数据池网络架构 (Phase 2)

### 4.1 数据池生命周期

```mermaid
stateDiagram-v2
    [*] --> 初始化: App 首次启动
    初始化 --> 发现: mDNS 广播
    发现 --> 加入: 输入密码验证
    加入 --> 同步: 连接成功
    同步 --> 同步: 持续同步
    同步 --> 退出: 用户主动退出
    退出 --> [*]: 删除本地数据
```

### 4.2 数据池角色

**平等权限模型**:
- 所有成员权限相同
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

## 5. 健康检查和状态监控 (Phase 2)

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
  - P2P 同步: `rust/src/sync/` (Phase 2)

---

## 更新日志

| 版本 | 变更 |
|------|------|
| 1.0.0 | 初始版本,从 PRD.md 和 DATABASE.md 提取同步机制设计 |

---

**设计哲学**: 本文档定义同步机制的设计理念和流程,使用流程图和伪代码展示原理,不包含具体实现。同步的核心是"订阅驱动、单向数据流、CRDT 自动冲突解决"。
