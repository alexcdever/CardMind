# ADR-0001: 卡片与数据池所有权模型重构

**Status**: Proposed
**Date**: 2026-01-09
**Deciders**: @alexc

## Context

### 问题背景

CardMind 的核心定位是**面向个人用户的分布式笔记应用**：
- 支持个人的多设备同步（手机、平板、电脑）
- P2P 去中心化同步，无需中央服务器
- 离线优先，数据完全自主

**用户画像**：个人用户，在自己的多个设备间同步笔记

### 当前设计

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
- 隐私保护机制：数据池 + 密码验证，防止局域网内数据泄露
- 数据分类同步：支持创建多个数据池，不同类型笔记分开同步

### 发现的关键问题

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

## Decision

采用**单一数据池模型**，核心变更如下：

### 核心概念转变

| 概念 | 旧模型 | 新模型 |
|------|-------|-------|
| **数据池** | 用户可创建多个，用于分类 | 每用户一个，用于隔离 |
| **用户感知** | "创建数据池"、"选择数据池" | "我的笔记空间"（透明） |
| **设备加入** | 可加入多个池 | 只能加入一个池 |
| **卡片归属** | 可属于多个池 | 属于唯一的池 |

### 数据模型变更

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

### 关键约束

| 规则 | 说明 |
|------|------|
| **一用户一池** | 每个用户创建一个数据池，用户无感知 |
| **一设备一池** | 每个设备只能加入一个数据池 |
| **退出 = 清空** | 退出数据池删除所有数据 |
| **池对用户透明** | UI 使用"笔记空间"术语 |

### 初始化流程

**重要**：应用启动时必须区分两种场景：

| 场景 | 设备顺序 | 行为 | API调用 |
|------|---------|------|---------|
| **全新用户** | 第 1 台设备 | 创建新笔记空间 | `initialize_first_time(password)` |
| **已有用户** | 第 N 台设备（N>1） | 加入已有空间 | `join_existing_pool(pool_id, password)` |

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

## Consequences

### 优势

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

### 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| 数据迁移失败 | 用户数据丢失 | 迁移前备份；多池用户导出其他池数据；充分测试 |
| API 大幅变更 | Flutter 层需重构 | 分阶段迁移；保持向后兼容（临时） |
| 性能回退 | 查询变慢 | 优化索引；压测验证 |

### 不兼容变更

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

## Alternatives Considered

| 方案 | 描述 | 优点 | 缺点 | 结论 |
|------|------|------|------|------|
| **当前方案：单一数据池** | 每用户一个池，设备只能加入一个 | 极致简化，符合定位 | 功能限制 | ✅ 采用 |
| 支持设备切换数据池 | 允许设备在多个池间切换 | 灵活性高 | 增加复杂度、概念混淆 | ❌ 放弃（过度设计） |
| 保留多池但简化 | 允许多池但默认单池 | 灵活性 | 仍然复杂 | ❌ 放弃（不够彻底） |
| Card 持有 pool_ids（保持） | 维持当前模型 | 无需迁移 | 移除操作无法传播 | ❌ 放弃（关键Bug） |

## Implementation Notes

### 代码改动清单

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
- [ ] 修改方法：`join_pool()` 检查是否已加入其他池；`leave_pool()` 简化逻辑

#### 第二阶段：API 层

**Pool API** (`rust/src/api/pool.rs`)
- [ ] 移除 `create_pool()` API（自动创建）
- [ ] 新增 `check_initialization_status()` API - 检查是否需要初始化
- [ ] 新增 `initialize_first_time()` API - 创建新空间
- [ ] 新增 `join_existing_pool()` API - 加入已有空间
- [ ] 新增 `leave_pool()` API

**Card API** (`rust/src/api/card.rs`)
- [ ] 修改 `create_card()` - 移除 pool_id 参数（自动加入）
- [ ] 修改 `add_card_to_pool()` / `remove_card_from_pool()`

**Discovery API** (`rust/src/api/discovery.rs`) - 新增文件
- [ ] 新增 `start_mdns_discovery()` API
- [ ] 新增 `stop_mdns_discovery()` API

#### 第三阶段：Flutter UI

**初始化流程**
- [ ] 实现 `on_app_start()` 决策逻辑（检查配置 + mDNS 发现）
- [ ] 首次启动：显示选择界面（创建 vs 配对）
- [ ] 创建向导：显示"设置密码"页面
- [ ] 配对向导：显示"发现设备"列表

**卡片创建**
- [ ] 移除"选择数据池"对话框
- [ ] 直接进入编辑器（极简流程）

**设置页面**
- [ ] 移除"数据池管理"
- [ ] 新增"退出笔记空间"（罕见操作，放在高级设置）

**UI 术语统一**
- [ ] "数据池" → "笔记空间"
- [ ] "加入数据池" → "配对设备"
- [ ] "创建数据池" → 移除

### 数据迁移

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
```

## Related Decisions

无

## References

- [Product Vision](../requirements/product_vision.md) - 产品定位和目标用户
- [Data Contract](../architecture/data_contract.md) - 数据模型定义
- [Sync Mechanism](../architecture/sync_mechanism.md) - 同步机制设计
- [System Design](../architecture/system_design.md) - 系统架构设计
- [原始重构文档](../card_pool_ownership_refactoring.md) - 完整的技术细节
