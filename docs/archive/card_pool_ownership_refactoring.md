# 卡片与数据池所有权模型重构方案

**文档类型**: 架构设计决策 (ADR)
**创建日期**: 2026-01-09
**状态**: 📋 提议中 (Proposed)

---

## 1. 背景与问题

### 1.1 项目初心

CardMind 的核心定位是**面向个人用户的分布式笔记应用**：
- 支持个人的多设备同步（手机、平板、电脑）
- P2P 去中心化同步，无需中央服务器
- 离线优先，数据完全自主

**用户画像**：个人用户，在自己的多个设备间同步笔记

### 1.2 当前设计

**数据模型**：
```rust
// Card Loro 文档
Card {
    id: String,
    pool_ids: Vec<String>,  // 一张卡片可以属于多个池
}

// Device Config
DeviceConfig {
    device_id: String,
    joined_pools: Vec<String>,      // 设备可以加入多个池
    resident_pools: Vec<String>,    // 常驻池：新卡片自动绑定
}

// Pool
Pool {
    pool_id: String,
    name: String,
    members: Vec<Device>,
}
```

**产品愿景中对数据池的描述**：
- 隐私保护机制：数据池 + 密码验证，防止局域网内数据泄露（家庭成员各用各的，互不干扰）
- 数据分类同步：支持创建多个数据池，不同类型笔记分开同步（工作、生活、学习）

### 1.3 发现的关键问题

#### 问题 1：移除操作无法传播到其他设备 ⚠️

**场景**：设备 A 将卡片从数据池中移除

```rust
// 设备 A：移除卡片
card.pool_ids.remove("pool-A");  // ["pool-A", "pool-B"] → ["pool-B"]
card_doc.commit();

// 设备 B（只加入了 pool-A）：收到同步请求
if !card.pool_ids.contains("pool-A") {
    // SyncFilter 阻止同步！
    // 因为卡片不再属于 pool-A
    // 设备 B 永远收不到这个"移除"更新 ❌
}
```

**根本原因**：
- 关系存储在 Card 中，移除操作修改的是 Card 文档
- 当卡片不再属于某个池后，SyncFilter 会排除它
- 该池内的设备无法收到"移除"事件

#### 问题 2：过度设计 - 多池不符合"个人笔记"定位

**当前设计假设**：用户需要多个数据池来分类笔记（工作、个人、学习）

**反思产品定位**：
- ❌ CardMind 不是团队协作工具
- ❌ 不是多用户共享平台
- ✅ 是**个人笔记应用**：一个人，多个设备

**数据池的真实用途**：
- **隔离自己和他人**（唯一目的）
  - 家庭场景：防止家人的笔记互串
  - 密码保护：局域网内的安全边界

**结论**：
- 一个人 = 一个笔记空间 = 一个数据池

#### 问题 3：多池模型带来的复杂度

**用户困惑**：
- "我应该创建几个数据池？"
- "这张卡片应该放在哪个池？"
- "我现在在看哪个池的笔记？"

**代码复杂度**：
- 多池关系管理（交集、过滤、移除检查）
- 常驻池机制（自动绑定多个池）
- 池切换逻辑
- 同步过滤逻辑

**性能问题**：
- 查询池内卡片需要遍历所有卡片
- 退出池需要检查每张卡片是否属于其他池

#### 问题 4：设备可加入多池的安全风险

**场景**：设备丢失或转手
```
当前：一个设备加入了 A、B、C 三个池
→ 泄露了三个池的数据
→ 退出前需要检查并退出所有池

优化：一个设备只加入一个池
→ 只泄露一个池的数据
→ 退出 = 清空所有数据（简单明确）
```

---

## 2. 设计目标

### 2.1 核心原则

1. **回归"个人笔记"本质**：一个人 = 一个笔记空间
2. **极简用户体验**："数据池"对用户透明，称为"笔记空间"
3. **清晰的所有权**：一个设备只能加入一个空间
4. **可靠的同步**：移除操作必须能传播到所有设备
5. **安全边界**：数据池只用于隔离不同用户，不用于分类

### 2.2 关键约束

- ✅ 一个用户一个数据池（自动创建，用户无感知）
- ✅ 一个设备只能加入一个数据池
- ✅ 数据分类通过标签，不通过多池
- ✅ Pool 持有 card_ids（解决移除传播问题）
- ✅ 退出池 = 删除所有本地数据

---

## 3. 新设计方案

### 3.1 核心概念转变

| 概念 | 旧模型 | 新模型 |
|------|-------|-------|
| **数据池** | 用户可创建多个，用于分类 | 每用户一个，用于隔离 |
| **用户感知** | "创建数据池"、"选择数据池" | "我的笔记空间"（透明） |
| **设备加入** | 可加入多个池 | 只能加入一个池 |
| **卡片归属** | 可属于多个池 | 属于唯一的池 |

### 3.2 数据模型

#### Loro 层（真理源）

```rust
// Pool Loro 文档（简化）
Pool {
    pool_id: String,              // 自动生成（UUID v7）
    name: String,                 // 默认："我的笔记"
    password_hash: String,        // 用户设置的密码
    members: Vec<Device>,         // 加入的设备列表
    card_ids: Vec<String>,        // ← 池持有卡片列表（新增）
}

// Card Loro 文档（极简）
Card {
    id: String,
    title: String,
    content: String,
    created_at: i64,
    updated_at: i64,
    deleted: bool,
    // pool_ids 字段移除！
}
```

#### SQLite 层（查询缓存）

```sql
-- 保持不变，用于双向查询
CREATE TABLE card_pool_bindings (
    card_id TEXT,
    pool_id TEXT,
    PRIMARY KEY (card_id, pool_id)
);

CREATE INDEX idx_pool_cards ON card_pool_bindings(pool_id);
CREATE INDEX idx_card_pools ON card_pool_bindings(card_id);
```

#### 设备配置（大幅简化）

```rust
// 极简设计
pub struct DeviceConfig {
    pub device_id: String,

    // 注意：单值 Option，不是 Vec
    pub pool_id: Option<String>,  // ← 当前加入的唯一池
}
```

**不再需要的字段**：
- ❌ `joined_pools: Vec<String>` - 只能加入一个
- ❌ `resident_pools: Vec<String>` - 只有一个池，无需常驻池
- ❌ `last_selected_pool` - 只有一个池，无需记住选择

#### 内存模型（Rust API）

```rust
// Card 结构体（极简）
pub struct Card {
    pub id: String,
    pub title: String,
    pub content: String,
    pub created_at: i64,
    pub updated_at: i64,
    pub deleted: bool,
    pub pool_id: Option<String>,  // ← 从 SQLite 反向查询得到
}
```

### 3.3 关系方向

| 层次 | 关系存储 | 说明 |
|------|---------|------|
| **Loro 层** | `Pool.card_ids` | 真理源、分布式同步的依据 |
| **SQLite 层** | `card_pool_bindings` 表 | 通过订阅自动维护 |
| **Rust API** | `Card.pool_id` | 从 SQLite 查询填充 |

**核心理念**：
> 真理源在容器（Pool），缓存在关系表（SQLite）

### 3.4 约束规则

| 规则 | 说明 | 实施方式 |
|------|------|---------|
| **一用户一池** | 每个用户创建一个数据池 | 首次启动自动创建，不暴露"创建池"功能 |
| **一设备一池** | 每个设备只能加入一个池 | `pool_id: Option<String>`，join 时检查 |
| **退出 = 清空** | 退出数据池删除所有数据 | `leave_pool()` 删除本地所有卡片 |
| **池对用户透明** | 用户不感知"数据池"概念 | UI 使用"笔记空间"术语 |

---

## 4. 关键操作

### 4.0 初始化流程决策

**重要**：应用启动时必须区分两种场景：

| 场景 | 设备顺序 | 行为 | API调用 |
|------|---------|------|---------|
| **全新用户** | 第 1 台设备 | 创建新笔记空间 | `initialize_first_time(password)` |
| **已有用户** | 第 N 台设备（N>1） | 加入已有空间 | `join_existing_pool(pool_id, password)` |

#### 决策流程

```
[应用启动]
     ↓
[检查本地配置]
     ├─→ 已加入空间？ → [直接进入主页]
     └─→ 未加入空间？
          ↓
     [启动 mDNS 发现]
          ↓
     ┌────────┴────────┐
     ↓                 ↓
[发现附近设备]      [未发现设备/选择创建]
 "找到 2 台设备"      "创建新空间"
                    ↓
            ┌────────┴────────┐
            ↓                 ↓
     [显示配对界面]      [显示创建界面]
```

#### 实现逻辑

```rust
pub async fn on_app_start() -> Result<InitAction> {
    // 1. 检查本地配置
    let config = DeviceConfig::load_or_create()?;

    if config.is_joined() {
        // 已加入空间，直接进入主页
        return Ok(InitAction::EnterMain);
    }

    // 2. 未加入空间，启动 mDNS 发现
    let discovery = start_mdns_discovery().await?;

    if discovery.peers.is_empty() {
        // 未发现设备，引导创建
        return Ok(InitAction::ShowCreateWizard);
    }

    // 发现设备，显示配对/创建选项
    return Ok(InitAction::ShowChoice {
        peers: discovery.peers,
    });
}

pub enum InitAction {
    /// 直接进入主页
    EnterMain,

    /// 显示创建向导
    ShowCreateWizard,

    /// 显示选择（配对或创建）
    ShowChoice { peers: Vec<DiscoveredPeer> },
}
```

#### UI 交互设计

```
┌─────────────────────────────────────┐
│  欢迎使用 CardMind                   │
├─────────────────────────────────────┤
│  发现已有的笔记空间                  │
│                                     │
│  📱 MacBook Pro                     │
│     "我的笔记"空间                  │
│     [ 配对 ]                       │
│                                     │
│  💻 iPhone 12                       │
│     "我的笔记"空间                  │
│     [ 配对 ]                       │
│                                     │
│  ────────────────────────────       │
│  或                                 │
│                                     │
│  [ 创建新笔记空间 ]                 │
└─────────────────────────────────────┘
```

#### 关键实现细节

1. **mDNS 发现并行进行**：在用户选择前后台持续发现
2. **超时处理**：30秒未发现设备，引导创建
3. **网络权限**：首次启动需要请求局域网访问权限
4. **错误恢复**：配对失败后可以返回创建向导

### 4.1 创建笔记空间（全新用户，第 1 台设备）

**旧流程**：
```
[首次启动] → [创建数据池] → [输入名称] → [设置密码] → [开始使用]
```

**新流程**（创建）：
```
[应用启动] → [检测：未加入空间]
          → [显示创建向导]
          → [设置密码] → [自动创建空间] → [开始使用]
```

**代码实现**：

```rust
pub fn initialize_first_time(password: String) -> Result<()> {
    // 1. 自动创建数据池
    let pool_id = generate_uuid_v7();
    let pool = Pool::new(
        &pool_id,
        "我的笔记",  // 默认名称
        &hash_password(&password)?
    );

    // 添加当前设备为第一个成员
    let device = Device::new(&get_device_id()?, "此设备");
    pool.add_member(device);

    // 2. 保存 Pool Loro
    save_pool(&pool)?;

    // 3. 设备自动加入
    let mut config = DeviceConfig::load_or_create()?;
    config.join_pool(pool_id)?;  // ← 自动检查是否已加入

    // 4. 存储密码到 Keyring
    store_password(&pool_id, &password)?;

    Ok(())
}
```

**UI 界面**：

```
┌─────────────────────────────────────┐
│  欢迎使用 CardMind                   │
├─────────────────────────────────────┤
│  为你的笔记空间设置密码              │
│                                     │
│  密码：[________________]           │
│  确认：[________________]           │
│                                     │
│  此密码用于：                       │
│  • 保护你的笔记隐私                │
│  • 在其他设备上同步                │
│                                     │
│  [ 开始使用 ]                      │
└─────────────────────────────────────┘
```

### 4.2 加入笔记空间（已有用户，第 N 台设备，N>1）

**初始化流程**（加入）：
```
[应用启动] → [检测：未加入空间]
          → [启动 mDNS 发现]
          → [发现附近设备]
          → [选择设备 + 输入密码]
          → [验证并加入] → [开始使用]
```

**代码实现**：

```rust
pub fn join_existing_pool(pool_id: String, password: String) -> Result<()> {
    // 1. 验证密码
    verify_pool_password(&pool_id, &password)?;

    // 2. 检查设备是否已加入其他池
    let mut config = DeviceConfig::load_or_create()?;
    config.join_pool(pool_id.clone())?;  // ← 内部检查

    // 3. 添加设备到 Pool.members
    let mut pool = load_pool(&pool_id)?;
    let device = Device::new(&config.device_id, "新设备");
    pool.add_member(device);
    save_pool(&pool)?;

    // 4. 存储密码
    store_password(&pool_id, &password)?;

    // 5. 同步数据
    sync_all_cards(&pool_id)?;

    Ok(())
}
```

**UI 界面**：

```
┌─────────────────────────────────────┐
│  发现附近的 CardMind 设备            │
├─────────────────────────────────────┤
│  📱 MacBook Pro                     │
│     "我的笔记"空间                  │
│     [ 配对 ]                       │
│                                     │
│  💻 iPhone 12                       │
│     "我的笔记"空间                  │
│     [ 配对 ]                       │
└─────────────────────────────────────┘
         ↓ 点击配对
┌─────────────────────────────────────┐
│  输入笔记空间密码                    │
├─────────────────────────────────────┤
│  密码：[________________]           │
│                                     │
│  [ 取消 ]          [ 确认 ]        │
└─────────────────────────────────────┘
```

### 4.3 创建卡片（极简流程）

**旧流程**：
```
[点击 FAB] → [选择数据池] → [选择常驻池] → [进入编辑器]
```

**新流程**：
```
[点击 FAB] → [进入编辑器] → [创建完成]
```

**代码实现**：

```rust
pub fn create_card(title: String, content: String) -> Result<Card> {
    let store = get_store()?;
    let mut store = store.lock().unwrap();

    // 1. 创建卡片
    let card = store.create_card(title, content)?;

    // 2. 自动加入当前设备的数据池
    let config = get_device_config()?;
    if let Some(pool_id) = config.pool_id {
        add_card_to_pool(&card.id, &pool_id)?;
    }

    Ok(card)
}
```

**优势**：
- ✅ 无需选择数据池（只有一个）
- ✅ 无需配置常驻池（自动加入）
- ✅ 极简流程，直接进入编辑

### 4.4 添加卡片到池

**实现**：

```rust
pub fn add_card_to_pool(card_id: &str, pool_id: &str) -> Result<()> {
    // 修改 Pool Loro（唯一真理源）
    let pool_doc = get_pool_doc(pool_id)?;
    let card_ids = pool_doc.get_list("card_ids");
    card_ids.push(card_id)?;
    pool_doc.commit();  // ← 触发订阅，自动更新 SQLite

    Ok(())
}
```

### 4.5 移除卡片（完美解决传播问题）

**实现**：

```rust
pub fn remove_card_from_pool(card_id: &str, pool_id: &str) -> Result<()> {
    // 修改 Pool Loro
    let pool_doc = get_pool_doc(pool_id)?;
    let card_ids = pool_doc.get_list("card_ids");

    // 从列表中删除
    for i in 0..card_ids.len() {
        if card_ids.get(i)? == card_id {
            card_ids.delete(i, 1)?;  // CRDT List 删除
            break;
        }
    }

    pool_doc.commit();  // ← 同步到所有设备！✅

    Ok(())
}
```

**优势**：
- ✅ Pool 文档的同步不受过滤器影响
- ✅ 所有设备都能收到"移除"事件

### 4.6 退出笔记空间（罕见场景）

**场景**：
- 设备需要加入另一个笔记空间（如转让设备、切换空间等）

**代码实现**：

```rust
pub fn leave_pool() -> Result<()> {
    let config = get_device_config()?;
    let pool_id = config.pool_id
        .ok_or(CardMindError::NotJoinedPool)?;

    // 1. 获取池内所有卡片（O(1)）
    let pool = get_pool(&pool_id)?;

    // 2. 删除所有卡片
    for card_id in pool.card_ids {
        delete_card_physically(&card_id)?;
    }

    // 3. 删除 Pool 文档
    delete_pool_doc(&pool_id)?;

    // 4. 清空配置
    let mut config = get_device_config()?;
    config.pool_id = None;
    config.save()?;

    // 5. 删除密码
    delete_password(&pool_id)?;

    Ok(())
}
```

**UI 界面**：

```
[设置] → [数据管理] → [退出笔记空间]

┌─────────────────────────────────────┐
│  退出笔记空间？                      │
├─────────────────────────────────────┤
│  ⚠️  警告：                         │
│  • 此设备上的 137 张卡片将被删除    │
│  • 其他设备不受影响                │
│  • 退出后可以加入其他笔记空间       │
│                                     │
│  [ 先导出数据 ]  [ 取消 ]  [ 确认 ]│
└─────────────────────────────────────┘
```

### 4.7 DeviceConfig 约束实现

```rust
impl DeviceConfig {
    /// 加入数据池（唯一的池）
    pub fn join_pool(&mut self, pool_id: String) -> Result<()> {
        // 约束：只能加入一个池
        if self.pool_id.is_some() {
            return Err(CardMindError::AlreadyJoinedPool(
                "设备已加入笔记空间，如需切换请先退出当前空间".to_string()
            ));
        }

        self.pool_id = Some(pool_id);
        self.save()?;

        Ok(())
    }

    /// 退出数据池
    pub fn leave_pool(&mut self) -> Result<()> {
        if self.pool_id.is_none() {
            return Err(CardMindError::NotJoinedPool);
        }

        self.pool_id = None;
        self.save()?;

        Ok(())
    }

    /// 获取当前加入的池
    pub fn get_pool_id(&self) -> Option<&str> {
        self.pool_id.as_deref()
    }

    /// 检查是否已加入池
    pub fn is_joined(&self) -> bool {
        self.pool_id.is_some()
    }
}
```

---

## 5. 同步机制

### 6.1 订阅机制

```rust
fn on_pool_updated(pool: &Pool) {
    // 1. 清空该池的旧绑定
    sqlite.execute(
        "DELETE FROM card_pool_bindings WHERE pool_id = ?",
        &pool.pool_id
    )?;

    // 2. 重新写入新绑定
    for card_id in &pool.card_ids {
        sqlite.execute(
            "INSERT INTO card_pool_bindings VALUES (?, ?)",
            (card_id, &pool.pool_id)
        )?;
    }
}
```

### 6.2 P2P 同步流程

```rust
fn sync_with_peer(peer_id: &str) -> Result<()> {
    // 1. 获取当前设备的数据池
    let config = get_device_config()?;
    let pool_id = config.pool_id
        .ok_or(CardMindError::NotJoinedPool)?;

    // 2. 同步 Pool 文档
    let pool = load_pool(&pool_id)?;
    let pool_updates = export_pool_updates(&pool_id)?;
    send_to_peer(peer_id, pool_updates)?;

    // 3. 从 Pool.card_ids 获取卡片列表
    let card_ids = pool.card_ids;

    // 4. 同步这些卡片
    for card_id in card_ids {
        let card_updates = export_card_updates(&card_id)?;
        send_to_peer(peer_id, card_updates)?;
    }

    Ok(())
}
```

**优势**：
- ✅ 同步范围清晰（从 Pool.card_ids 获取）
- ✅ 不需要复杂的 SyncFilter
- ✅ 移除操作可靠传播

---

## 7. 实施计划

### 7.1 代码改动清单

#### 第一阶段：数据模型

**Pool 模型** (`rust/src/models/pool.rs`)
- [ ] 新增 `card_ids: Vec<String>` 字段
- [ ] 添加 `add_card()` / `remove_card()` 方法

**设备发现模型** (`rust/src/models/discovery.rs`) - 新增文件
- [ ] 新增 `DiscoveredPeer` 结构体
- [ ] 新增 `MdnsDiscovery` 服务

**Card 模型** (`rust/src/models/card.rs`)
- [ ] 移除 `pool_ids: Vec<String>` 字段（Loro 层）
- [ ] 保留 `pool_id: Option<String>` 用于 API 层（从 SQLite 填充）

**DeviceConfig 模型** (`rust/src/models/device_config.rs`)
- [ ] **核心改动**：`joined_pools: Vec<String>` → `pool_id: Option<String>`
- [ ] 移除 `resident_pools: Vec<String>` 字段
- [ ] 移除 `last_selected_pool: Option<String>` 字段
- [ ] 修改方法：
  - `join_pool()` - 检查是否已加入其他池
  - `leave_pool()` - 简化逻辑
  - 移除 `set_resident_pool()` 等方法

**PoolStore** (`rust/src/store/pool_store.rs`)
- [ ] 实现 Pool 的 Loro 文档管理
- [ ] 持久化路径：`data/loro/pools/<pool_id>/snapshot.loro`

#### 第二阶段：存储层

**CardStore** (`rust/src/store/card_store.rs`)
- [ ] 修改 `create_card()` - 自动加入当前设备的池
- [ ] 修改 `add_card_to_pool()` - 修改 Pool Loro
- [ ] 修改 `remove_card_from_pool()` - 修改 Pool Loro
- [ ] 新增 `leave_pool()` - 从 Pool.card_ids 获取列表

**订阅机制** (`rust/src/store/subscription.rs`)
- [ ] 新增 `on_pool_updated()` 订阅回调
- [ ] 自动维护 `card_pool_bindings` 表

**SQLite 表结构**
- [ ] 保持 `card_pool_bindings` 表不变
- [ ] 确认 Card 表中没有 `pool_ids` 字段

#### 第三阶段：同步层

**SyncManager** (`rust/src/p2p/sync_manager.rs`)
- [ ] 简化 `handle_sync_request()` - 从 Pool.card_ids 获取
- [ ] 移除复杂的 SyncFilter 逻辑

**SyncFilter** (`rust/src/p2p/sync.rs`)
- [ ] 大幅简化或移除（只有一个池）

#### 第四阶段：API 层

**Pool API** (`rust/src/api/pool.rs`)
- [ ] 移除 `create_pool()` API（自动创建）
- [ ] 新增 `check_initialization_status()` API - 检查是否需要初始化
- [ ] 新增 `initialize_first_time()` API - 创建新空间
- [ ] 新增 `join_existing_pool()` API - 加入已有空间
- [ ] 新增 `leave_pool()` API
- [ ] 新增 `export_pool()` API

**Card API** (`rust/src/api/card.rs`)
- [ ] 修改 `create_card()` - 移除 pool_id 参数（自动加入）
- [ ] 修改 `add_card_to_pool()` / `remove_card_from_pool()`

**DeviceConfig API** (`rust/src/api/device_config.rs`)
- [ ] 移除所有多池相关 API
- [ ] 移除常驻池相关 API
- [ ] 修改 `get_device_config()` 返回结构

**Discovery API** (`rust/src/api/discovery.rs`) - 新增文件
- [ ] 新增 `start_mdns_discovery()` API
- [ ] 新增 `stop_mdns_discovery()` API

#### 第五阶段：Flutter UI

**初始化流程**
- [ ] 实现 `on_app_start()` 决策逻辑（检查配置 + mDNS 发现）
- [ ] 首次启动：显示选择界面（创建 vs 配对）
- [ ] 创建向导：显示"设置密码"页面
- [ ] 配对向导：显示"发现设备"列表

**配对流程**
- [ ] mDNS 发现设备
- [ ] 输入密码配对
- [ ] 自动加入数据池

**卡片创建**
- [ ] 移除"选择数据池"对话框
- [ ] 直接进入编辑器（极简流程）

**设置页面**
- [ ] 移除"数据池管理"
- [ ] 新增"退出笔记空间"（罕见操作，放在高级设置）
- [ ] 移除"常驻池"设置

**UI 术语统一**
- [ ] "数据池" → "笔记空间"
- [ ] "加入数据池" → "配对设备"
- [ ] "创建数据池" → 移除

### 7.2 数据迁移

```rust
fn migrate_to_single_pool() -> Result<()> {
    let config = load_device_config()?;

    // 1. 检查设备当前加入的池
    if config.joined_pools.is_empty() {
        // 未加入任何池 → 首次使用场景
        return Ok(());
    }

    // 2. 如果加入了多个池，选择第一个
    let pool_id = config.joined_pools[0].clone();

    // 3. 警告用户（如果有多个池）
    if config.joined_pools.len() > 1 {
        warn!("检测到设备加入了多个数据池，迁移后仅保留第一个：{}", pool_id);
        // 可选：导出其他池的数据
        for other_pool in &config.joined_pools[1..] {
            export_pool(other_pool)?;
        }
    }

    // 4. 更新配置
    let mut new_config = DeviceConfig {
        device_id: config.device_id.clone(),
        pool_id: Some(pool_id.clone()),
    };
    new_config.save()?;

    // 5. 为 Pool 创建 card_ids
    migrate_pool_card_ids(&pool_id)?;

    Ok(())
}

fn migrate_pool_card_ids(pool_id: &str) -> Result<()> {
    // 从 card_pool_bindings 表获取该池的卡片
    let bindings = sqlite.query(
        "SELECT card_id FROM card_pool_bindings WHERE pool_id = ?",
        [pool_id]
    )?;

    // 创建 Pool Loro 并填充 card_ids
    let pool = load_pool(pool_id)?;
    let pool_doc = get_pool_doc(pool_id)?;
    let card_ids_list = pool_doc.get_list("card_ids");

    for (card_id,) in bindings {
        card_ids_list.push(card_id)?;
    }

    pool_doc.commit();
    persist_pool_doc(pool_id, &pool_doc)?;

    Ok(())
}
```

### 7.3 测试计划

**单元测试**
- [ ] DeviceConfig.join_pool() 只能加入一个池
- [ ] Pool 的 card_ids 操作
- [ ] 订阅回调正确更新 SQLite
- [ ] leave_pool 正确删除所有数据
- [ ] check_initialization_status() 正确返回初始化状态

**集成测试**
- [ ] 初始化决策逻辑（检查配置 + mDNS 发现）
- [ ] 首次启动流程（自动创建池）
- [ ] 新设备配对流程
- [ ] 移除操作的传播测试
- [ ] 退出笔记空间的完整流程

**UI 测试**
- [ ] 首次启动引导
- [ ] 配对设备流程
- [ ] 创建卡片流程（无需选择池）
- [ ] 退出笔记空间确认

---

## 8. 影响评估

### 8.1 优势

**极致简化**
- ✅ 用户无需理解"数据池"概念
- ✅ 零配置，开箱即用
- ✅ 减少 50% 的代码复杂度
- ✅ UI 简洁，学习成本极低

**解决关键 Bug**
- ✅ 移除操作能可靠传播到所有设备
- ✅ 不再出现"移除事件丢失"问题

**提升安全性**
- ✅ 一个设备只加入一个空间，降低泄露风险
- ✅ 退出空间 = 清空所有数据，操作明确

**提升性能**
- ✅ 查询池内卡片：O(1)
- ✅ 同步逻辑简化

**符合产品定位**
- ✅ 回归"个人笔记"本质
- ✅ 一个人 = 一个笔记空间

### 8.2 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| 数据迁移失败 | 用户数据丢失 | 迁移前备份；多池用户导出其他池数据；充分测试 |
| API 大幅变更 | Flutter 层需重构 | 分阶段迁移；保持向后兼容（临时） |
| 性能回退 | 查询变慢 | 优化索引；压测验证 |

### 8.3 不兼容变更

**API 变更**：
```rust
// 旧 API
pub struct DeviceConfig {
    pub joined_pools: Vec<String>,      // 移除
    pub resident_pools: Vec<String>,    // 移除
}

pub fn create_pool(name: String, password: String) -> Pool;  // 移除
pub fn create_card(title: String, content: String, pool_id: Option<String>) -> Card;

// 新 API
pub struct DeviceConfig {
    pub pool_id: Option<String>,        // 单值
}

pub fn initialize_first_time(password: String) -> Result<()>;  // 新增
pub fn join_existing_pool(pool_id: String, password: String) -> Result<()>;  // 新增
pub fn create_card(title: String, content: String) -> Card;
```

**用户功能变更**：
- ❌ 不再支持：创建多个数据池
- ❌ 不再支持：一张卡片属于多个池
- ❌ 不再支持：设备加入多个池
- ❌ 不再支持：常驻池机制

---

## 9. 决策记录

### 9.1 关键决策

**决策 1：单一数据池模型**

- ✅ 选择原因：符合"个人笔记"定位；极致简化用户体验
- ❌ 放弃多数据池：过度设计，不符合使用场景
- 📊 数据支持：产品愿景定位为"个人用户"，不是团队协作

**决策 2：每设备只能加入一个池**

- ✅ 选择原因：简化心智模型；提升安全性
- ❌ 放弃多池加入：用户困惑，安全风险
- 📊 数据支持：一个设备 = 一个主人 = 一个笔记空间

**决策 3：Pool 持有 card_ids（方案 2）**

- ✅ 选择原因：解决移除操作的同步传播问题
- ❌ 放弃 Card.pool_ids：无法可靠传播移除事件

**决策 4："数据池"对用户透明**

- ✅ 选择原因：降低学习成本；符合直觉
- 🔤 术语变更："数据池" → "笔记空间"
- 🎯 目标：用户只需设置密码，开始使用

### 9.2 替代方案

| 方案 | 描述 | 优点 | 缺点 | 结论 |
|------|------|------|------|------|
| 支持设备切换数据池 | 允许设备在多个池间切换 | 灵活性高 | 增加复杂度、概念混淆 | ❌ 放弃（过度设计） |
| 保留多池但简化 | 允许多池但默认单池 | 灵活性 | 仍然复杂 | ❌ 放弃（不够彻底） |

---

## 10. 后续工作

### 10.1 必须完成

- [ ] 实施代码重构（按上述计划）
- [ ] 编写数据迁移脚本（处理多池用户）
- [ ] 更新相关文档：
  - `data_contract.md` - 更新为单池模型
  - `sync_mechanism.md` - 简化同步逻辑
  - `ui_flows.md` - 更新初始化和创建流程
  - `product_vision.md` - 澄清"数据池"用途
- [ ] 完整的测试覆盖
- [ ] UI 术语统一（"数据池" → "笔记空间"）

### 10.2 可选改进

- [ ] 批量导出/导入

---

## 11. 参考资料

### 11.1 相关文档

- [Product Vision](../requirements/product_vision.md) - 产品定位和目标用户
- [Data Contract](data_contract.md) - 数据模型定义
- [Sync Mechanism](sync_mechanism.md) - 同步机制设计
- [System Design](system_design.md) - 系统架构设计

### 11.2 讨论记录

- 2026-01-09: 发现移除操作无法传播的问题
- 2026-01-09: 讨论回归"个人笔记"初心
- 2026-01-09: 确定方案 2（Pool.card_ids）为最佳方案
- 2026-01-09: 决定移除常驻池
- 2026-01-09: **决定采用"单一数据池 + 每设备一池"模型**
- 2026-01-12: **新增 4.0 节初始化流程决策** - 明确第 1 台设备 vs 第 N 台设备的区分逻辑

---

**最后更新**: 2026-01-12
**审核状态**: 待审核
**相关 Issue**: TBD
