# 数据池系统未来态规格（产品+技术一体）

- status: draft
- applies_to: Flutter UI + Rust/FRB 同步链路 + Loro 写模型 + SQLite 读模型

## 1. 背景与目标

CardMind 需要一个可协作的数据池能力，支持用户创建池、邀请/扫码加入、审批成员、编辑池信息、退出或解散池，并在网络波动下保持可恢复和可解释的状态反馈。

本规格定义数据池功能的未来目标态，统一产品行为、技术契约、验收标准与发布门禁，减少跨端与跨层（UI/应用层/存储层/同步层）实现偏差。

## 2. 范围与非目标

### 2.1 范围（In Scope）

1. 池生命周期：创建、编辑、加入申请、审批/拒绝、退出、解散。
2. 角色与权限：owner/member 两级角色与权限边界。
3. 写模型与读模型：Loro 作为写真源，SQLite 作为查询读侧。
4. 投影一致性：写侧事件到读侧可追踪投影。
5. 同步状态反馈：连接中、已连接、错误、重试、重连。
6. 可测试验收：覆盖成功路径和失败路径。

### 2.2 非目标（Out of Scope）

1. 复杂组织体系（多管理员、多级审批链）。
2. 细粒度 ACL（字段级/记录级权限策略引擎）。
3. 跨池事务一致性（多个 pool 的分布式事务）。
4. 商业化计费与配额策略。

## 3. 角色、术语与核心对象

### 3.1 角色

- Owner：池拥有者，可编辑池信息、审批请求、解散池。
- Member：普通成员，可查看成员与池信息，可退出池。

### 3.2 核心术语

- Pool：协作容器，包含成员与入池请求。
- Join Request：待 owner 审批的入池申请。
- Write Model：以 Loro 持久化的权威状态（source of truth）。
- Read Model：为查询和展示优化的 SQLite 投影。
- Projection：写侧变更同步到读侧的处理过程。

### 3.3 数据对象（目标态）

- PoolEntity：`poolId`、`name`、`dissolved`、`updatedAtMicros`。
- PoolMember：`poolId`、`memberId`、`displayName`、`role`、`joinedAtMicros`。
- PoolRequest：`requestId`、`poolId`、`requesterId`、`displayName`、`requestedAtMicros`、`status`。

注：当前代码中 `PoolRequest` 尚未显式包含 `status` 字段；目标态建议加入以支持更清晰的审计与重放。

## 4. 用户流程与产品行为

### 4.1 创建池

1. 用户在未加入状态点击创建。
2. 系统创建 Pool 与 Owner 成员记录。
3. UI 切换到已加入态，显示 owner 身份与成员列表。

### 4.2 加入池（扫码/邀请码）

1. 用户提交加入凭据。
2. 系统校验凭据并生成 Join Request。
3. owner 审批前，申请方看到等待状态。
4. 审批通过后，申请方成为 member；拒绝后展示可操作失败原因。

### 4.3 审批与拒绝

1. owner 在待审批列表执行通过/拒绝。
2. 通过：移除请求并写入成员记录。
3. 拒绝：请求状态置拒绝或从待处理列表移除（由策略决定，见 6.4）。

### 4.4 退出与解散

1. member 可退出池，退出后移除成员关系。
2. owner 可解散池，解散后池标记 `dissolved=true`。
3. 退出或解散失败时，系统进入可恢复状态并提供重试动作。

## 5. 状态机与转移约束

### 5.1 页面状态（UI）

- `NotJoined`
- `Joined`
- `Error(code)`
- `ExitPartialCleanup`

### 5.2 合法转移

1. `NotJoined -> Joined`：创建成功或加入成功。
2. `NotJoined -> Error`：加入失败、网络异常或凭据无效。
3. `Joined -> ExitPartialCleanup`：退出流程部分清理失败。
4. `ExitPartialCleanup -> NotJoined`：重试清理成功。
5. `Error -> NotJoined`：用户执行主动作（重试加入或返回初始页）。

### 5.3 状态不变量

1. `Joined` 状态下必须存在当前池上下文（至少 `poolId` 与 `poolName`）。
2. `dissolved=true` 的池不可再新增成员。
3. 同一个 `requestId` 在同一池内唯一。
4. owner 不可被普通退出逻辑移除后留下无 owner 池。

## 6. 技术契约（应用层与仓储层）

### 6.1 命令服务（PoolCommandService）

目标态命令集合：

1. `createPool(poolId, name, ownerId, ownerName)`
2. `editPoolInfo(poolId, name)`
3. `requestJoin(poolId, requestId, requesterId, displayName)`
4. `approve(poolId, requestId)`
5. `reject(poolId, requestId)`
6. `leavePool(poolId, memberId)`
7. `dissolvePool(poolId)`

每条命令要求：

- 幂等：重复提交不应造成破坏性副作用。
- 可追踪：失败时返回可映射的错误码。
- 最终可投影：写侧成功后必须可投影到读侧。

### 6.2 写仓接口（PoolWriteRepository）

目标态保留现有上/下线能力，并补充：

1. 批量读取能力（减少多次 round-trip）。
2. 乐观并发控制字段（例如版本号或逻辑时钟）。
3. 审计事件读取接口（便于问题追踪）。

### 6.3 读仓接口（PoolReadRepository）

目标态在 `listPools` 基础上补充：

1. `getPoolById(poolId)`
2. `listMembers(poolId)`
3. `listPendingRequests(poolId)`

### 6.4 拒绝策略（明确化）

规格定义拒绝为软删除策略：

1. 默认 UI 列表仅展示 `pending`。
2. 被拒请求记录为 `rejected`（可审计，不默认展示）。
3. 读侧可按需打开历史视图。

## 7. 同步与一致性语义

### 7.1 同步状态

- `connecting`
- `connected`
- `error(code)`

### 7.2 行为要求

1. 写入优先落地本地写模型，再进行网络传播。
2. 弱网场景下允许暂时读写不一致，但必须最终一致。
3. `error` 状态必须提供 `retry` 与 `reconnect` 至少一种可操作路径。
4. 同步错误提示必须可映射到用户可理解文案与下一步动作。

## 8. 错误模型与映射

### 8.1 标准错误码（建议）

- `ADMIN_OFFLINE`
- `REQUEST_TIMEOUT`
- `POOL_NOT_FOUND`
- `PERMISSION_DENIED`
- `POOL_DISSOLVED`
- `NETWORK_UNAVAILABLE`

### 8.2 映射原则

1. 每个错误码至少提供：用户文案、主动作、可选次动作。
2. 错误码稳定，文案可迭代。
3. UI 不直接依赖底层异常字符串。

## 9. 验收标准（产品+工程）

### 9.1 功能验收

1. 创建池后立刻可见 owner 身份与池名。
2. 加入成功时进入 `Joined`，失败时进入 `Error` 并可恢复。
3. owner 审批通过后，成员进入成员列表且请求不再出现在 pending。
4. 拒绝失败时，UI 明确反馈并允许重复操作。
5. 退出部分失败时进入 `ExitPartialCleanup`，重试成功后回到 `NotJoined`。
6. 解散池后不可继续接受新成员。

### 9.2 工程验收

1. 命令服务具备成功/失败路径单测。
2. 写仓与读仓契约具备集成测试。
3. 投影处理器具备至少一次 end-to-end 验证。
4. 错误码映射表具备完备性测试（新增错误码必须补映射）。

## 10. 测试与发布门禁映射

发布前至少执行：

1. `flutter test`
2. `cargo test`
3. `flutter analyze`
4. `flutter test test/ui_interaction_governance_docs_test.dart`
5. `flutter test test/interaction_guard_test.dart`

若本规格导致 UI 交互行为变更，必须同步更新并通过：

- `docs/plans/2026-02-27-ui-interaction-governance-design.md`
- `docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md`
- `docs/plans/2026-02-27-ui-interaction-release-gate.md`

## 11. 可观测性与运维要求

1. 关键命令记录结构化日志：命令名、poolId、actorId、结果、错误码。
2. 投影失败可重放，不因单条脏数据导致全量阻塞。
3. 支持按 poolId 排查最近 N 次写入与投影行为。

## 12. 安全与数据约束

1. 禁止将敏感凭据写入可公开日志。
2. 池 ID、成员 ID、请求 ID 需满足全局唯一或命名域唯一策略。
3. 输入字段（池名、显示名）需长度与字符校验，避免异常存储负载。

## 13. 迁移与兼容策略

1. 从当前实现迁移到目标态时，优先保证旧数据可读。
2. 新增字段（如 request status）采用向后兼容默认值。
3. 迁移期间允许双读（新旧结构），最终切换为新结构单读。

## 14. 当前实现差异清单（Gap）

基于当前代码，存在以下与目标态差异：

1. UI 仍以模拟扫码码值驱动，未接入真实扫码与鉴权链路。
2. 页面状态与领域状态有耦合，`poolId` 在 UI 状态中尚不完整显式化。
3. `PoolRequest` 缺少显式 `status` 字段与审计视图。
4. 读侧查询能力较少，主要聚焦 `listPools`。
5. 同步状态有基础连接语义，但缺少端到端错误分类闭环。

## 15. 实施建议（从规格到落地）

1. 先固化领域对象与命令返回错误码契约。
2. 再补齐读侧查询与投影一致性校验。
3. 最后接入真实加入凭据链路与跨端同步细节。
4. 每一步均保持测试先行与治理门禁同步更新。

---

本文件为示例规格草案，建议在进入实施前补充：

- 业务 owner/技术 owner
- 目标上线版本与里程碑
- 关键风险与回滚策略
