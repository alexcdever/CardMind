# Phase 3 数据流转扩展能力评估与执行设计

**日期**: 2026-03-27  
**状态**: 待审查  
**作者**: OpenCode  
**目标**: 谨慎评估数据池协作扩展能力，确保不压过个人多设备主路径

---

## 1. 背景

### 1.1 已完成阶段

**Phase 1** ✅: 跨设备延续成立 + 最低恢复能力  
**Phase 2** ✅: 信任优先恢复（内容安全信任优先于恢复强度）

### 1.2 当前状态

- **核心架构**: Flutter 前端 + Rust 后端，LoroDoc（写模型）+ SQLite（读模型）
- **已实现**: 个人笔记 CRUD、跨设备同步、异常恢复、查询收敛语义
- **数据池基础**: 池创建、成员管理、笔记引用挂接、P2P 同步框架

### 1.3 Phase 3 目标

根据 `docs/plans/2026-03-23-next-phase-roadmap-design.md`：

> "在不压过个人多设备主路径的前提下，重新判断哪些数据池协作或其他流转扩展能力，真正能够强化'笔记数据持续流转'而不是制造新的理解负担。"

**关键约束**:
- 这是一个"优先级重评估 phase"，不是默认进入大规模实现的功能扩张 phase
- 默认输出是：继续 defer、单独设计，或进入后续规划
- 不是直接形成新的实现大清单

---

## 2. 评估框架

### 2.1 核心评估原则

所有数据池协作增强必须通过"**主路径增强测试**"：

> **该能力是否让用户在多设备间创建/加入/管理/解散数据池的体验更流畅、完整，而不会让数据池从"个人工具"变成"多人协作平台"？**

### 2.2 评估维度

| 维度 | 问题 | 权重 |
|-----|------|------|
| **主路径服务度** | 该能力是否直接增强个人多设备主路径？ | 高 |
| **必要性** | 缺失该能力是否会导致功能不完整或体验断裂？ | 高 |
| **反客为主风险** | 该能力是否会让数据池变成独立主目标？ | 高 |
| **工作量** | 实现成本是否可控？ | 中 |
| **技术债务** | 缺失该能力是否会累积技术债务？ | 中 |

### 2.3 决策矩阵

| 评估结果 | 含义 | 后续动作 |
|---------|------|---------|
| **进入设计** | 通过主路径增强测试，值得单独设计 | 编写独立设计文档 → 实现 |
| **单独评估** | 需要更多信息或场景验证 | 保留为待评估项，暂不进入近期范围 |
| **继续 defer** | 不通过测试，或当前不必要 | 明确延后原因、重开条件、所属后续阶段 |

---

## 3. 候选扩展能力清单与评估

### 3.1 加入申请审批流程

**现状**: 消息类型已定义（JoinRequest/JoinDecision），但处理逻辑不完整

**评估**:
- ✅ **主路径服务度**: 高 - 让用户在设备B加入设备A创建的数据池时体验更流畅
- ✅ **必要性**: 高 - 当前审批流程不完整，用户无法完成完整的加入流程
- ✅ **反客为主风险**: 低 - 只是补全现有功能，不引入新协作模式
- ✅ **工作量**: 中 - 消息协议已存在，只需补全处理逻辑
- ✅ **技术债务**: 高 - 当前实现不完整，成为技术债务

**评估结论**: **进入设计**

**理由**: 这是数据池基础生命周期的必要环节，服务于个人多设备场景下的池加入体验，不会让协作反客为主。

---

### 3.2 池解散功能

**现状**: 未实现，缺失生命周期的必要闭环

**评估**:
- ✅ **主路径服务度**: 高 - 用户需要清理不再使用的数据池
- ✅ **必要性**: 高 - 无法删除无用数据池会导致数据膨胀
- ✅ **反客为主风险**: 低 - 只是生命周期闭环，不涉及新协作模式
- ✅ **工作量**: 中 - 需要添加 dissolved 状态和相关校验
- ✅ **技术债务**: 高 - 生命周期不完整，用户无法清理数据

**评估结论**: **进入设计**

**理由**: 这是数据池生命周期的必要闭环，缺失会导致用户长期体验受损，属于主路径的必要补全。

---

### 3.3 管理员不变量校验

**现状**: 未实现，无"至少保留1个admin"的校验

**评估**:
- ✅ **主路径服务度**: 高 - 防止误操作导致数据池无法管理
- ✅ **必要性**: 高 - 规格明确要求"未解散池 MUST 至少有 1 个 admin"
- ✅ **反客为主风险**: 低 - 只是基础不变量保障
- ✅ **工作量**: 低 - 在 leave_pool 等操作中添加校验即可
- ✅ **技术债务**: 中 - 违反规格要求，需要补齐

**评估结论**: **进入设计**

**理由**: 这是数据池规格的基本要求，保障数据池的可管理性，属于基础能力补全。

---

### 3.4 多成员实时协作

**现状**: 未实现

**评估**:
- ❌ **主路径服务度**: 低 - 这会让数据池从"个人工具"变成"多人协作平台"
- ⚠️ **必要性**: 中 - 个人多设备场景下不需要多人同时编辑
- ❌ **反客为主风险**: 高 - 明确违反"主路径优先"原则
- ❌ **工作量**: 高 - 需要复杂的冲突解决、权限管理、实时同步
- ⚠️ **技术债务**: 低 - 当前未承诺此能力

**评估结论**: **继续 defer**

**延后原因**: 该能力会让数据池协作反客为主，从服务个人多设备主路径的扩展能力变成独立主目标，与当前阶段"个人多设备主路径优先"原则冲突。

**重开条件**: 
1. Phase 1 和 Phase 2 已完全稳定
2. 有明确的用户场景证明个人多设备场景需要多人协作
3. 能够设计出不压过主路径的协作模式

**所属后续阶段**: 阶段外独立议题，需要单独的产品论证

---

### 3.5 其他候选能力（Defer 清单）

| 候选能力 | 评估结论 | 延后原因 | 重开条件 |
|---------|---------|---------|---------|
| 跨池内容流转 | 继续 defer | 超出个人多设备主路径范围 | **定量条件**: 用户调研显示 >30% 用户有跨池整理需求；**定性条件**: 有具体场景证明跨池流转能增强主路径延续体验 |
| 笔记分享（只读/可编辑） | 继续 defer | 引入外部协作，可能反客为主 | **定量条件**: 用户调研显示 >25% 用户需要分享功能；**定性条件**: 能够设计出不引入协作复杂度的轻量分享机制 |
| 版本历史查看 | 继续 defer | 增强功能而非必要基础 | **定量条件**: 用户反馈中版本恢复需求占比 >15%；**定性条件**: 有真实数据丢失场景需要版本恢复 |
| 角色权限细分 | 继续 defer | 过度设计，当前 admin/member 足够 | **定量条件**: 数据池平均成员数 >3 人；**定性条件**: 出现明确的权限管理痛点反馈 |
| 池设置中心 | 继续 defer | 不能比跨设备延续更直接证明价值 | **定量条件**: 用户反馈中设置相关需求占比 >20%；**定性条件**: 现有流程无法满足某类基础设置需求（如数据导出、存储清理） |

---

## 4. 执行策略

### 4.1 执行原则

**主路径增强优先法**（已确认）：
- 只选择那些**直接增强个人多设备主路径延续**的协作能力
- 补全数据池的必要基础能力，让用户能完整使用池功能
- 工作量可控，不会变成大规模重构

### 4.2 设计文档补充说明

本设计文档是阶段3的**评估与整体策略设计**，确定了哪些能力进入设计、执行顺序和验收标准。

每个周期开始前，将编写**详细设计文档**，补充以下内容：
- 详细的行为契约（前置条件、成功结果、失败结果、可恢复路径）
- 具体的接口定义和数据结构
- 详细的错误处理策略
- 与现有代码的集成点

这遵循 `docs/specs/pool.md` 第80行的指引。本设计文档一次性完成全部详细设计，确保评估决策有技术可行性支撑。

### 4.3 详细设计

本章节包含3个功能的完整详细设计，包括接口定义、数据结构、行为契约和错误处理。

---

#### 4.3.1 功能一：加入申请审批流程

##### 4.3.1.1 功能概述

完善数据池加入流程，实现完整的申请-审批机制。用户在设备B加入设备A创建的池时，需要池管理员审批后方可加入。

##### 4.3.1.2 数据结构设计

**JoinRequest 结构（新增）**
```rust
pub struct JoinRequest {
    pub request_id: Uuid,           // 申请唯一标识
    pub pool_id: Uuid,              // 目标池ID
    pub applicant_device_id: String, // 申请人设备标识
    pub applicant_public_key: String, // 申请人公钥（用于后续同步）
    pub request_time: DateTime,     // 申请时间
    pub status: JoinRequestStatus,  // 申请状态
    pub processed_by: Option<Uuid>, // 处理人（admin）
    pub processed_time: Option<DateTime>, // 处理时间
}

pub enum JoinRequestStatus {
    Pending,   // 待处理
    Approved,  // 已通过
    Rejected,  // 已拒绝
    Expired,   // 已过期（超过72小时）
}
```

**Pool 结构扩展**
```rust
pub struct Pool {
    pub pool_id: Uuid,
    pub name: String,
    pub dissolved: bool,
    pub members: Vec<PoolMember>,
    pub card_ids: Vec<Uuid>,
    pub join_requests: Vec<JoinRequest>, // 新增：申请列表
    pub created_at: DateTime,
    pub updated_at: DateTime,
}
```

##### 4.3.1.3 接口定义

**Rust API（FRB暴露）**

```rust
/// 提交加入申请
/// 
/// 前置条件：
/// - 目标池存在且未解散
/// - 申请人不在该池的成员列表中
/// - 申请人没有该池的待处理申请
/// 
/// 成功结果：返回完整的申请信息（包含申请ID），状态为 Pending
/// 失败结果：PoolNotFound / PoolDissolved / AlreadyMember / DuplicateRequest
pub fn submit_join_request(
    pool_id: Uuid,
    applicant_device_id: String,
    applicant_public_key: String,
) -> Result<JoinRequestDto, ApiError>

/// 审批加入申请
/// 
/// 前置条件：
/// - 调用者是池的 admin
/// - 申请存在且状态为 Pending
/// - 目标池未解散
/// 
/// 成功结果：申请状态变为 Approved，申请人成为 member
/// 失败结果：PoolNotFound / NotAdmin / RequestNotFound / InvalidStatus
pub fn approve_join_request(
    pool_id: Uuid,
    request_id: Uuid,
) -> Result<JoinRequestDto, ApiError>

/// 拒绝加入申请
/// 
/// 前置条件：
/// - 调用者是池的 admin
/// - 申请存在且状态为 Pending
/// 
/// 成功结果：申请状态变为 Rejected
/// 失败结果：PoolNotFound / NotAdmin / RequestNotFound / InvalidStatus
pub fn reject_join_request(
    pool_id: Uuid,
    request_id: Uuid,
) -> Result<JoinRequestDto, ApiError>

/// 查询池的加入申请列表
/// 
/// 前置条件：
/// - 调用者是池的 admin 或 member
/// 
/// 成功结果：返回申请列表（admin看到全部，member只看到Approved的）
/// 失败结果：PoolNotFound / NotMember
pub fn list_join_requests(
    pool_id: Uuid,
    status_filter: Option<JoinRequestStatus>,
) -> Result<Vec<JoinRequestDto>, ApiError>

/// 取消自己的加入申请
/// 
/// 前置条件：
/// - 申请存在且状态为 Pending
/// - 调用者是申请人本人
/// 
/// 成功结果：申请被删除
/// 失败结果：RequestNotFound / NotApplicant / InvalidStatus
pub fn cancel_join_request(
    pool_id: Uuid,
    request_id: Uuid,
) -> Result<(), ApiError>
```

##### 4.3.1.4 状态机

```
Pending ──[approve]──→ Approved ──[成为member]──→ 结束
   │
   ├──[reject]──→ Rejected ──[结束]
   │
   ├──[cancel]──→ 删除
   │
   └──[72小时过期]──→ Expired ──[可重新申请]
```

##### 4.3.1.5 错误码定义

| 错误码 | 场景 | 用户提示 |
|-------|------|---------|
| JOIN_REQUEST_NOT_FOUND | 申请ID不存在 | "申请不存在或已处理" |
| DUPLICATE_JOIN_REQUEST | 重复提交申请 | "您已有待处理的申请" |
| JOIN_REQUEST_EXPIRED | 申请已过期 | "申请已过期，请重新申请" |
| INVALID_JOIN_STATUS | 操作与当前状态不符 | "申请状态已变更，请刷新" |
| NOT_APPLICANT | 非本人取消申请 | "只能取消自己的申请" |

##### 4.3.1.6 网络层集成

**消息类型（已存在，需完善处理）**
```rust
pub enum PoolMessage {
    // ... 现有消息
    JoinRequest { request: JoinRequest },
    JoinDecision { request_id: Uuid, approved: bool, processed_by: Uuid },
}
```

**流程**：
1. 设备B提交申请 → 本地存储 + 广播给池内所有成员
2. Admin（设备A）审批 → 本地更新 + 广播决策
3. 所有设备收到决策 → 更新本地状态，Approved时添加member

##### 4.3.1.7 测试要点

- 正常申请-审批流程
- 重复申请被拒绝
- 非admin尝试审批被拒绝
- 过期申请自动清理
- 并发申请处理
- 网络中断后恢复

---

#### 4.3.2 功能二：池解散功能

##### 4.3.2.1 功能概述

实现数据池解散功能，允许管理员解散不再需要的数据池。解散后池进入只读状态，不再接受新成员和编辑。

##### 4.3.2.2 数据结构设计

**Pool 结构（复用 dissolved 字段）**
```rust
pub struct Pool {
    pub pool_id: Uuid,
    pub name: String,
    pub dissolved: bool,              // true = 已解散
    pub dissolved_at: Option<DateTime>, // 新增：解散时间
    pub dissolved_by: Option<Uuid>,     // 新增：解散人
    pub members: Vec<PoolMember>,
    pub card_ids: Vec<Uuid>,
    pub join_requests: Vec<JoinRequest>,
    pub created_at: DateTime,
    pub updated_at: DateTime,
}
```

##### 4.3.2.3 接口定义

```rust
/// 解散数据池
/// 
/// 前置条件：
/// - 调用者是池的 admin
/// - 池未解散
/// - 池内只有自己一个成员（简化：单人可直接解散，多人需其他成员先退出）
/// 
/// 成功结果：池状态变为 dissolved，记录解散信息
/// 失败结果：PoolNotFound / NotAdmin / PoolDissolved / HasOtherMembers
/// 
/// 可恢复路径：
/// - 如果 HasOtherMembers：提示"请先移除其他成员"
/// - 其他错误：显示具体原因
/// 
/// 【未来扩展】当前设计限制为"只有自己一个成员时才能解散"。
/// 未来可考虑支持"强制解散"（admin移除所有成员后解散），
/// 但当前阶段保持简化，避免引入成员移除的复杂性。
pub fn dissolve_pool(pool_id: Uuid) -> Result<PoolDto, ApiError>

/// 查询池是否已解散
pub fn is_pool_dissolved(pool_id: Uuid) -> Result<bool, ApiError>
```

##### 4.3.2.4 解散后行为约束

**已解散池的限制**（规格 5.2.2-5.2.3）：
- ❌ 接受新的加入申请
- ❌ 新增成员
- ❌ 编辑池内笔记（但可读取）
- ❌ 新增笔记到池
- ✅ 读取现有笔记
- ✅ 查看池历史

**实现方式**：
```rust
impl Pool {
    pub fn can_accept_join_request(&self) -> bool {
        !self.dissolved
    }
    
    pub fn can_add_member(&self) -> bool {
        !self.dissolved
    }
    
    pub fn can_edit_notes(&self) -> bool {
        !self.dissolved
    }
}
```

##### 4.3.2.5 错误码定义

| 错误码 | 场景 | 用户提示 |
|-------|------|---------|
| POOL_ALREADY_DISSOLVED | 池已解散 | "该数据池已解散" |
| HAS_OTHER_MEMBERS | 解散时还有其他成员 | "请先移除其他成员后再解散" |
| CANNOT_MODIFY_DISSOLVED_POOL | 尝试修改已解散池 | "数据池已解散，无法执行此操作" |

##### 4.3.2.6 网络层集成

**消息类型**
```rust
pub enum PoolMessage {
    // ... 现有消息
    PoolDissolved { pool_id: Uuid, dissolved_by: Uuid, dissolved_at: DateTime },
}
```

**流程**：
1. Admin 调用 dissolve_pool
2. 本地更新 Pool 状态
3. 广播 PoolDissolved 消息给所有成员
4. 所有成员收到后更新本地状态

##### 4.3.2.7 UI展示

已解散池的展示：
- 池列表中显示"已解散"标签
- 池详情页显示解散时间和解散人
- 禁用所有编辑操作
- 保留读取和导出功能

##### 4.3.2.8 测试要点

- 正常解散流程
- 非admin尝试解散被拒绝
- 已解散池的操作限制
- 解散消息广播
- 解散后数据完整性

---

#### 4.3.3 功能三：管理员不变量校验

##### 4.3.3.1 功能概述

实现"未解散池必须至少有1个admin"的不变量校验，防止因误操作导致池无法管理。

##### 4.3.3.2 不变量规则

**规格 4.3**：
1. 未解散池 MUST 至少有 1 个 admin
2. 任何会导致未解散池 `admin=0` 的操作 MUST 被拒绝

**触发场景**：
- 成员退出池（leave_pool）
- 修改成员角色（如降级admin为member）
- 移除成员（如实现此功能）

##### 4.3.3.3 接口定义

```rust
/// 退出数据池
/// 
/// 前置条件：
/// - 调用者是池的 member
/// - 如果调用者是唯一的 admin，拒绝操作
/// 
/// 成功结果：成员关系被移除
/// 失败结果：PoolNotFound / NotMember / LastAdminCannotLeave
/// 
/// 可恢复路径：
/// - 如果 LastAdminCannotLeave：提示"请先指定新的管理员"
pub fn leave_pool(pool_id: Uuid) -> Result<(), ApiError>

/// 修改成员角色（【未来扩展】当前阶段不实现，仅预留接口定义）
/// 
/// 【说明】当前阶段只实现"退出池时的不变量校验"，不实现主动变更角色功能。
/// 此接口预留用于未来阶段，当需要支持"转让管理员"等场景时实现。
/// 
/// 前置条件（未来实现时）：
/// - 调用者是 admin
/// - 修改后至少还有1个admin
/// 
/// 成功结果：角色变更
/// 失败结果：PoolNotFound / NotAdmin / TargetNotMember / LastAdminCannotDemote
pub fn change_member_role(
    pool_id: Uuid,
    member_id: Uuid,
    new_role: MemberRole,
) -> Result<PoolMemberDto, ApiError>
```

##### 4.3.3.4 校验逻辑

```rust
impl Pool {
    /// 检查是否会导致 admin=0
    pub fn would_leave_zero_admins(&self, leaving_member_id: Uuid) -> bool {
        if self.dissolved {
            return false; // 已解散池不检查
        }
        
        let is_leaving_admin = self.members
            .iter()
            .any(|m| m.member_id == leaving_member_id && m.is_admin);
        
        if !is_leaving_admin {
            return false; // 退出的不是admin，不影响
        }
        
        let admin_count = self.members
            .iter()
            .filter(|m| m.is_admin && m.member_id != leaving_member_id)
            .count();
        
        admin_count == 0
    }
    
    /// 获取当前admin数量
    pub fn admin_count(&self) -> usize {
        self.members.iter().filter(|m| m.is_admin).count()
    }
}
```

##### 4.3.3.5 错误码定义

| 错误码 | 场景 | 用户提示 |
|-------|------|---------|
| LAST_ADMIN_CANNOT_LEAVE | 唯一admin尝试退出 | "您是唯一的管理员，请先指定新的管理员" |
| LAST_ADMIN_CANNOT_DEMOTE | 尝试降级唯一的admin | "不能降级唯一的管理员" |
| INSUFFICIENT_ADMINS | admin数量不足（预留） | "管理员数量不足" |

##### 4.3.3.6 与现有代码的集成

**现有 leave_pool 需要修改**：
```rust
// 在 leave_pool 实现中添加校验
pub fn leave_pool(pool_id: Uuid, member_id: Uuid) -> Result<(), Error> {
    let pool = pool_store.get(pool_id)?;
    
    // 新增：检查不变量
    if pool.would_leave_zero_admins(member_id) {
        return Err(Error::LastAdminCannotLeave);
    }
    
    // 原有逻辑...
}
```

##### 4.3.3.7 测试要点

- 普通member正常退出
- 唯一admin尝试退出被拒绝
- 多admin场景下admin正常退出
- 边界情况：空池（理论上不应发生）

---

#### 4.3.4 功能间依赖关系

```
加入申请审批流程 ─┬──→ 依赖：Pool基础结构（已存在）
                  └──→ 被依赖：池解散（需要知道成员关系）

池解散功能 ───────┬──→ 依赖：Pool结构、成员管理
                  ├──→ 依赖：管理员不变量（确保解散时合规）
                  └──→ 独立功能，但被其他功能依赖

管理员不变量校验 ─┬──→ 依赖：Pool成员结构
                  └──→ 被依赖：加入审批（添加新member时）、池解散
```

**实现顺序建议**：
1. 管理员不变量校验（基础保障）
2. 池解散功能（生命周期闭环）
3. 加入申请审批流程（体验增强）

但实际开发中可以部分并行，只要保证不变量校验尽早实施。

---

### 4.4 执行顺序

阶段3将分为**3个独立的设计-实现周期**：

#### 周期1：加入申请审批流程
1. 编写详细设计文档
2. 编写实现计划
3. 实现审批流程（JoinRequest/JoinDecision 处理逻辑）
4. 验证：池加入流程完整可用

#### 周期2：池解散功能
1. 编写详细设计文档
2. 编写实现计划
3. 实现池解散（dissolved 状态、解散操作、解散后限制）
4. 验证：生命周期闭环完整

#### 周期3：管理员不变量校验
1. 编写详细设计文档
2. 编写实现计划
3. 实现不变量校验（leave_pool、成员变更时校验）
4. 验证：规格要求满足

### 4.5 验收标准

每个周期完成后必须满足：

1. **功能完整性**: 该能力按照规格要求完整实现
2. **主路径未受损**: 个人多设备主路径体验没有退化
3. **协作未反客为主**: 数据池仍然是服务主路径的扩展能力
4. **测试覆盖**: 新增功能有完整的单元测试和集成测试
5. **质量门禁**: `dart run tool/quality.dart all` 通过

### 4.6 中止条件

任一周期执行过程中，如果出现以下情况，应中止并重新评估：

1. 实现过程中发现该能力实际上会**反客为主**
2. 工作量超出预期，**分散**了对主路径的注意力
3. 发现更基础的问题需要先解决
4. 用户反馈表明该能力**非必要**

---

## 5. 风险与缓解

### 5.1 风险：协作能力逐步扩张

**风险**: 虽然单个能力都通过测试，但累积起来可能让数据池变得过于复杂。

**缓解**:
- 严格执行"主路径增强测试"
- 每个周期独立评估，随时可中止
- 保持 defer 清单，明确不进入近期范围的能力

### 5.2 风险：用户期望更强的协作

**风险**: 用户可能期望多成员实时协作等高级功能。

**缓解**:
- 明确产品定位：面向个人多设备，而非团队协作
- 在适当时机沟通产品边界
- 记录用户需求，用于未来阶段评估

### 5.3 风险：技术债务累积

**风险**: 加入审批、池解散等能力缺失确实会造成技术债务。

**缓解**:
- 这正是进入设计的原因 - 补齐必要的基础能力
- 严格控制范围，只做必要的基础闭环

---

## 6. 与下游规格的关系

### 6.1 需要更新的规格

执行过程中可能需要更新以下规格：

- `docs/specs/pool.md`: 补充审批流程、解散、不变量校验的行为约束
- `docs/specs/ui-interaction.md`: 补充相关交互反馈语义
- `docs/specs/architecture.md`: 如有架构边界调整（预计无）

### 6.2 需要遵守的约束

所有实现必须遵守：

- `docs/specs/product.md`: 产品目标、阶段目标、能力边界
- `docs/specs/user-journeys.md`: 用户旅程约束
- `docs/specs/architecture.md`: 架构约束（Rust 后端、LoroDoc 真源、SQLite 读模型）

---

## 7. 结论

### 7.1 阶段3评估结论

**进入设计的扩展能力**（3项）：
1. ✅ 加入申请审批流程
2. ✅ 池解散功能
3. ✅ 管理员不变量校验

**继续延后的扩展能力**（多项）：
- 多成员实时协作
- 跨池内容流转
- 笔记分享
- 版本历史查看
- 角色权限细分
- 池设置中心

### 7.2 下一步动作

1. 审查并批准本设计文档
2. 启动**周期1**：编写加入申请审批流程的详细设计
3. 按顺序执行3个周期
4. 每个周期结束后验证主路径未受损
5. 全部完成后更新阶段状态

### 7.3 成功标准

阶段3成功完成的标准：

1. 数据池基础生命周期完整（创建、加入、管理、解散）
2. 个人多设备主路径体验没有退化
3. 数据池仍然是服务主路径的扩展能力，没有反客为主
4. 所有新增能力都有完整测试覆盖
5. 质量门禁全绿通过

---

## 8. 附录

### 8.1 参考文档

- `docs/specs/product.md`: 产品定位与阶段目标
- `docs/specs/user-journeys.md`: 用户旅程规格
- `docs/specs/pool.md`: 数据池领域规格
- `docs/specs/architecture.md`: 项目架构规格
- `docs/plans/2026-03-23-next-phase-roadmap-design.md`: Roadmap 设计
- `docs/plans/2026-03-23-phase2-trust-first-recovery-design.md`: Phase 2 设计

### 8.2 术语表

- **主路径**: 个人多设备笔记使用中的连续行为链（记录 → 跨设备延续 → 继续记录）
- **反客为主**: 扩展能力变成独立主目标，压过原主路径
- **Defer**: 延后，暂时不进入近期实施范围
- **生命周期闭环**: 功能从创建到销毁的完整流程

### 8.3 变更记录

| 日期 | 版本 | 变更 | 作者 |
|-----|------|------|------|
| 2026-03-27 | v1.0 | 初始版本 | OpenCode |
