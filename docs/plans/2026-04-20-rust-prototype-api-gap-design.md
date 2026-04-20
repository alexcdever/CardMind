# Rust 原型缺口 API 补齐设计

**日期**: 2026-04-20  
**状态**: 已确认设计，待撰写实施计划  
**作者**: Codex  
**目标**: 仅通过补齐 Rust API，覆盖当前 Pencil 原型中成员页与网络态势页的最小后端缺口，不扩展到 Flutter、FRB 或未来成员管理能力

---

## 1. 背景

当前项目已经通过 Pencil 产出了一套覆盖 mobile / desktop 的原型稿，主流程聚焦在以下页面：

- Note List
- Note Editor
- Data Pool Setup
- Data Pool Members / Network Nodes

对照当前 Rust API 门面可见：

- 笔记 CRUD、详情、搜索已经具备稳定接口
- 数据池创建、加入、离开、解散、详情、申请审批链路已经具备稳定接口
- 基于 iroh 的网络初始化、连接、邀请、加入、同步状态、push / pull 已经具备稳定接口

因此，当前真正阻止原型“完整跑起来”的，不是笔记主流程，也不是建池 / 入池主链路，而是成员页与网络态势页缺少面向 UI 的运行态视图接口。

同时，用户已明确收敛本次范围：

1. 只设计和实现 Rust API
2. 只补最小缺口，不顺带设计未来成员管理 API
3. 外围功能只保留“历史”入口，但明确标记为待定，短期不实现

这意味着，本设计不追求把系统做成完整平台管理后台，而是只补齐当前原型真正缺失的后端视图层。

## 2. 设计目标

本次设计只解决以下问题：

1. 成员页如何获得每个成员的运行态信息
2. 池级 summary 卡如何获得聚合统计信息
3. Invite Others 如何从“只能生成邀请码”提升到“最小可管理邀请视图”

本次设计完成后，应满足：

- Data Pool Members / Network Nodes 页面不再只能渲染静态假数据
- Flutter 前端可直接消费 Rust 返回的展示型 DTO，而不需要自行推断成员状态
- 新 API 不污染现有 `PoolDetailDto` / `PoolMemberDto` 的职责

## 3. 非目标

本次设计明确不包含以下内容：

1. Flutter 页面实现
2. FRB 绑定接线与 Dart 调用层改造
3. 历史功能的实际后端实现
4. 成员移除
5. 成员角色调整
6. 更复杂的多人协作管理能力
7. 高精度网络测速、复杂健康诊断或完整运维指标体系

这些能力要么超出当前原型真正缺口，要么属于中期扩展议题，不应进入本轮最小补齐设计。

## 4. 设计原则

### 4.1 运行态与元数据分离

当前 `PoolDetailDto` 主要承担池元数据职责：

- pool id / name
- 成员列表
- note ids
- join requests

成员页和网络页需要的则是高波动运行态：

- connected / syncing / offline
- last active
- sync progress
- active nodes / sync speed / network health

这两类数据刷新频率、缓存策略、失败语义都不同，因此不应继续把运行态塞进 `PoolDetailDto`。本次设计新增独立的“展示型视图 DTO”。

### 4.2 UI 状态不等于网络真相

iroh 可以提供连接活性信号，例如：

- 某连接是否 still alive
- 某连接是否已经关闭
- 关闭原因

但原型页面需要的是应用层状态：

- connected
- syncing
- offline

因此本次设计必须在 Rust 应用层增加一层状态归一化，而不是把底层网络状态原样暴露给前端。

### 4.3 先满足原型展示，再追求高精度统计

对于 `sync_speed`、`pool_traffic_today`、`network_health` 这类指标，本轮不强行定义严格数学口径。

短期目标是：

- 先提供足够稳定的展示型字段
- 让前端能渲染原型对应的 summary 卡
- 避免过早锁死未来更正式的统计模型

因此本轮 summary DTO 允许先返回文案型字段，而不是一开始就全部做成精确结构化数值。

## 5. API 能力补齐范围

本次设计只新增三类能力：

### 5.1 成员运行态视图

为成员列表提供：

- 当前成员是谁
- 当前设备是谁
- 当前连接状态
- 最近活跃时间
- 可选同步进度

### 5.2 池级统计视图

为 summary 卡提供：

- active nodes
- connected members
- offline members
- sync speed
- network health
- pool traffic today

### 5.3 邀请管理视图

为 Invite Others 提供最小可管理能力：

- 查看活跃邀请
- 撤销邀请

这里只做“最小管理”，不引入成员审批后台式复杂逻辑。

## 6. DTO 设计

### 6.1 PoolMemberRuntimeDto

用于成员列表项。

建议字段：

- `endpoint_id: String`
- `nickname: String`
- `device_name: String`
- `os: String`
- `role: String`
- `is_current_device: bool`
- `status: String`
- `last_active_at: Option<i64>`
- `sync_progress: Option<u8>`

字段说明：

- `device_name` 短期允许先复用 `nickname`
- `status` 当前固定为 `connected | syncing | offline`
- `sync_progress` 允许为空，避免为精确进度过度设计

### 6.2 PoolMembersRuntimeViewDto

用于成员页整体返回。

建议字段：

- `pool_id: String`
- `pool_name: String`
- `current_endpoint_id: String`
- `members: Vec<PoolMemberRuntimeDto>`

### 6.3 PoolRuntimeSummaryDto

用于顶部 summary 卡。

建议字段：

- `pool_id: String`
- `active_nodes: usize`
- `connected_members: usize`
- `offline_members: usize`
- `sync_speed_text: String`
- `network_health_text: String`
- `pool_traffic_today_text: String`

设计说明：

- 短期使用 `*_text`，避免在统计口径尚未稳定时提前绑定结构化语义
- 后续若需要更精细图表或历史分析，再单独扩展数值字段

### 6.4 PoolInviteDto

用于邀请列表项。

建议字段：

- `invite_id: String`
- `pool_id: String`
- `code: String`
- `created_at: i64`
- `expires_at: Option<i64>`
- `revoked: bool`

### 6.5 PoolInvitesViewDto

用于邀请管理视图。

建议字段：

- `pool_id: String`
- `active_invites: Vec<PoolInviteDto>`

## 7. API 函数设计

本次建议新增以下 API：

### 7.1 获取成员运行态视图

```rust
pub fn get_pool_members_runtime_view(
    pool_id: String,
    endpoint_id: String,
) -> Result<PoolMembersRuntimeViewDto, ApiError>
```

用途：

- 驱动成员页的成员列表
- 为成员项渲染状态标签、当前设备标识、最近活跃时间提供数据

### 7.2 获取池级统计视图

```rust
pub fn get_pool_runtime_summary(
    pool_id: String,
    endpoint_id: String,
) -> Result<PoolRuntimeSummaryDto, ApiError>
```

用途：

- 驱动成员页 / 网络页顶部 summary 卡
- 支撑 `active nodes`、`network health`、`sync speed` 等展示

### 7.3 列出活跃邀请

```rust
pub fn list_active_invites(
    pool_id: String,
    endpoint_id: String,
) -> Result<PoolInvitesViewDto, ApiError>
```

用途：

- 让 Invite Others 从“只能生成一次性字符串”提升到“可查看当前有效邀请”

### 7.4 撤销邀请

```rust
pub fn revoke_invite(
    invite_id: String,
    endpoint_id: String,
) -> Result<PoolInvitesViewDto, ApiError>
```

用途：

- 对原型中的邀请管理行为给出最小闭环

## 8. 状态语义设计

### 8.1 成员状态

建议在 Rust 内部定义状态枚举，再映射成 DTO 字符串：

- `Connected`
- `Syncing`
- `Offline`

### 8.2 归一化规则

短期规则如下：

- `connected`
  - 当前存在活跃连接，且连接仍可视为 alive
- `syncing`
  - 当前处于 join / connect / push / pull 等同步过程
- `offline`
  - 当前不存在活跃连接，且超过最近活跃阈值

### 8.3 语义注意事项

必须明确：

- `offline` 在 UI 上表达的是“当前未连接 / 当前不可达”
- 它不应被解释成“对端进程确定死亡”

这条约束必须保留在 Rust 层注释和后续页面规格中，避免产品层过度断言底层网络状态。

## 9. 数据来源与实现边界

### 9.1 成员运行态来源

成员运行态需要同时来自：

- `PoolStore` 中的成员元数据
- `PoolNetwork` 中的连接与同步会话状态
- 应用层记录的最近活跃时间

本次不引入完整 presence 子系统，只做最小聚合。

### 9.2 池级统计来源

短期 summary 可基于以下来源保守聚合：

- 当前池成员数
- 当前 alive 连接数
- 当前同步状态
- 最近一次同步结果

这里允许近似，不要求本轮就建立精确网络观测模型。

### 9.3 邀请视图来源

当前 `create_pool_invite` 只负责生成邀请码字符串。  
本轮若要支持 `list_active_invites / revoke_invite`，需要为 invite 增加最小持久化存储。

推荐做法：

- 先由 `PoolStore` 管理 invite 元数据
- 不额外拆复杂邀请服务层

## 10. 文件落点

建议修改：

- `rust/src/api/mod.rs`
  - 新增 DTO 与 FFI API 门面函数
- `rust/src/net/pool_network.rs`
  - 增加最小连接运行态采集能力
- `rust/src/store/pool_store.rs`
  - 增加 invite 视图与撤销支持

建议新增：

- `rust/src/models/pool_runtime.rs`
  - 放置成员运行态与池级统计相关内部模型

不建议在本轮新增更多层次的 service 或 manager，以避免最小补齐任务被架构化膨胀。

## 11. 风险与取舍

### 11.1 风险：状态误判

如果直接把连接断开映射成 `offline`，可能在网络切换、idle timeout、短暂 NAT 波动时误导用户。

应对方式：

- 使用“最近活跃时间 + 当前连接状态”综合判断
- 在 UI 语义中把 `offline` 理解为“当前未连接”

### 11.2 风险：统计口径不稳定

如果现在就把 `sync_speed`、`network_health` 设计成精确数值指标，后续大概率需要返工。

应对方式：

- 先使用展示型文案字段
- 等未来确实需要图表和数值分析时再升级

### 11.3 风险：DTO 污染现有池详情接口

如果继续向 `PoolDetailDto` 塞运行态字段，会导致静态元数据和高频运行态混杂。

应对方式：

- 保持独立运行态视图 API
- 不改现有详情接口职责

## 12. 验证要求

本次实现完成后，至少需要验证：

1. 新 DTO 的序列化与错误边界
2. 在无活跃连接、存在活跃连接、正在同步三种情况下，成员状态归一化是否符合设计
3. 邀请创建、列出、撤销链路是否闭环
4. 不影响现有笔记、池详情、同步主链 API 的行为

## 13. 结论

本次 Rust API 补齐应当保持克制：

- 只补成员运行态、池级统计、邀请管理三类最小视图能力
- 不顺手扩大到未来成员管理或复杂网络诊断
- 不修改现有池元数据 DTO 的职责边界

这样可以在最小范围内，让当前 Pencil 原型的成员页 / 网络页拥有真实后端数据来源，并为下一步 Flutter 接入保留清晰边界。
