# 2026-03-13 Flutter Rust 主路径修补设计

## 1. 背景与目标

- 当前实现已经补齐了大量 Flutter/Rust 集成能力，但 review 发现生产页面主路径仍未完全切到 Rust 后端。
- 当前残留问题主要包括：生产页面仍默认使用 local/legacy client、部分 FRB client 仍有 `UnimplementedError`、Rust 返回的投影/同步状态仍带占位语义、架构守卫测试无法阻止生产接线回退。
- 本设计的目标是一次性修补这些缺口，使生产路径只通过 `FRB -> Rust` 完成读写与状态查询，并彻底移除生产兼容层。

## 2. 已锁定决策

- 生产代码不保留兼容层。
- `LegacyCardApiClient`、`LocalPoolApiClient` 等对象不得出现在生产页面默认组合层。
- Flutter 只能通过 FRB 调 Rust 后端，不直接碰 `LoroDoc`，也不直接碰 `SQLite`。
- `LoroDoc` 与 `SQLite` 都属于 Rust 后端内部实现细节。
- 查询路径必须是：`Flutter -> FRB -> Rust Query API -> SQLite -> DTO -> Flutter`。
- 写路径必须是：`Flutter -> FRB -> Rust -> LoroDoc -> Projection -> SQLite`。
- `join pool` 第一优先沿用当前 `joinByCode` 语义，只把底层执行改成真实后端处理。
- 本次修补范围一次性覆盖：create pool、join pool、create/edit/delete/restore card、query、explicit sync。

## 3. 备选方案比较

### 3.1 方案 A（选定）：一次性主路径切换 + 缺口补齐

- 把生产页面默认组合层全部切到 FRB client。
- 同时补齐缺失 API、真实状态语义和架构守卫测试。
- 优点：
  - 最符合“完全切换、不留生产兼容层”的目标；
  - 一次性消除 review 中最关键的架构不一致；
  - 修补完成后能清晰证明真实主路径已切到 Rust。
- 缺点：
  - 变更范围较大，需要同时动 Flutter、FRB、Rust 与测试。

### 3.2 方案 B：先切生产接线，再补功能缺口

- 先把页面组合切到 FRB client，再逐步补剩余能力。
- 优点：
  - 架构姿态更快变正确。
- 缺点：
  - 中间阶段会存在生产主路径已切换但功能不完整的风险；
  - 不符合本次“一次性收尾”的目标。

### 3.3 方案 C：先补后端真实性，再最后切前端

- 先补 Rust API 与状态语义，最后再切生产页面。
- 优点：
  - 后端稳定性先提高。
- 缺点：
  - 生产页面会继续停留在旧路径；
  - 容易让兼容层继续存活。

## 4. 目标架构与切换边界

### 4.1 目标主路径

- `CardsPage -> CardsController -> FrbCardApiClient -> FRB -> Rust API -> LoroDoc -> Projection -> SQLite -> Rust Query API -> DTO -> Flutter`
- `PoolPage -> PoolController -> FrbPoolApiClient -> FRB -> Rust API -> LoroDoc -> Projection -> SQLite -> Rust Query API -> DTO -> Flutter`
- `Sync UI -> FrbSyncApiClient -> FRB -> Rust Sync API -> SyncStatusDto/SyncResultDto -> Flutter`

### 4.2 禁止事项

- 生产页面默认实例化 `LegacyCardApiClient` 为 FORBIDDEN。
- 生产页面默认实例化 `LocalPoolApiClient` 为 FORBIDDEN。
- Flutter 直接读 `SQLite` 为 FORBIDDEN。
- Flutter 直接写本地 `LoroDoc` 或本地写仓为 FORBIDDEN。

### 4.3 允许保留的位置

- local/legacy client 仅允许出现在测试、fixture 或明确的开发辅助环境中。
- 若这些对象仍保留在仓库中，不得被生产组合层引用。

## 5. 组件与接口修补设计

### 5.1 Flutter 生产组合层

- `CardsPage` 默认组合必须使用 `FrbCardApiClient`。
- `PoolPage` 默认组合必须使用 `FrbPoolApiClient`。
- 同步相关页面默认组合必须使用 `FrbSyncApiClient`。
- 页面控制器继续承担交互编排，但不得再拥有本地业务写真相。

### 5.2 Flutter ApiClient 层

- `FrbCardApiClient` 必须补齐：
  - create
  - update
  - delete
  - restore
  - list/detail/query
- `FrbPoolApiClient` 必须补齐：
  - createPool
  - joinByCode
  - getPoolDetail
  - listPools 或等价查询
- `FrbSyncApiClient` 必须补齐：
  - connect
  - runSyncNow 或等价主同步动作
  - status
  - disconnect
- 所有 `UnimplementedError` 都必须从生产可达路径中消失。

### 5.3 Rust API 与 DTO 层

- Rust API 需要提供完整且真实的后端语义，而不是仅存在 API 形状。
- `joinByCode` 必须变成真实后端动作，而不是 Flutter 本地模拟。
- delete/restore card 必须拥有真实 Rust 后端实现。
- 查询 DTO 必须足够支撑页面刷新，但不泄露后端内部实现细节。
- `SyncStatusDto` 与 `SyncResultDto` 必须来源于真实后端状态，而不是占位常量。

### 5.4 架构守卫测试

- 守卫测试不能只检查旧 repository/service 名称是否还存在。
- 守卫测试必须覆盖：
  - 生产页面组合层不得实例化 local/legacy client；
  - 生产依赖图不得回退到 Flutter 本地写主路径；
  - 生产可达的 FRB client 不得残留 `UnimplementedError`。

## 6. 数据流与状态语义修补

### 6.1 create pool

- `PoolPage -> PoolController -> FrbPoolApiClient.createPool -> Rust create_pool`
- Rust 先把业务事实写入 `LoroDoc`。
- `LoroDoc` 变化触发投影更新 `SQLite`。
- Flutter 再通过 FRB 调 Rust 查询 API 拉取最新池 DTO。
- 创建者成为 admin 必须由 Rust 保证。

### 6.2 join pool by code

- `PoolPage -> PoolController -> FrbPoolApiClient.joinByCode -> Rust join_by_code`
- Rust 完成真实加入语义，并自动挂接已有 `noteId`。
- 写入先进 `LoroDoc`，再投影到 `SQLite`。
- Flutter 再通过 Rust 查询 API 刷新池详情。

### 6.3 create / edit / delete / restore card

- `CardsPage -> CardsController -> FrbCardApiClient -> Rust`
- Rust 负责：
  - 写卡片事实到 `LoroDoc`；
  - 在池上下文中维护 `noteId` 引用规则；
  - 避免 edit/delete/restore 产生重复引用。
- Flutter 成功后只通过 Rust 查询 API 重新拉取结果。

### 6.4 explicit sync

- `UI -> FrbSyncApiClient -> Rust Sync API`
- Rust 返回真实同步状态 DTO。
- Flutter 根据稳定状态语义展示恢复动作。

### 6.5 稳定状态维度

- 至少需要区分三组状态：
  - `write state`：如 `write_saved`、`write_failed`
  - `projection state`：如 `projection_ready`、`projection_pending`、`projection_failed`
  - `sync state`：如 `idle`、`connected`、`sync_failed`、`degraded`
- Flutter 只消费这些稳定状态，不自行推测真假。

## 7. 测试与迁移收尾策略

### 7.1 生产组合层守卫测试

- 验证生产页面默认只使用 `FrbCardApiClient`、`FrbPoolApiClient`、`FrbSyncApiClient`。
- 明确禁止 local/legacy client 出现在生产默认组合层。

### 7.2 FRB 主路径集成测试

- 覆盖：
  - create pool
  - joinByCode
  - create/edit/delete/restore card
  - query
  - explicit sync
- 证明真实页面所依赖的后端 API 已完整可用。

### 7.3 Rust 状态语义测试

- 验证 `write_saved`、`projection_pending`、`sync_failed` 等状态来自真实后端，而不是占位字符串。

### 7.4 回退防护测试

- 若未来有人把生产路径接回 local/legacy client，测试必须直接变红。

### 7.5 删除与清理策略

- 生产组合层里的 local/legacy client 直接移除。
- 仅在测试或测试专用 fixture 中保留必要 fake/local client。
- 对已经不再有存在意义的兼容代码，直接删除，不保留“以后再说”的生产残留。

## 8. 完成判定

- 生产页面主路径只通过 FRB 调 Rust。
- Flutter 不直接读写 `LoroDoc` / `SQLite`。
- 所有核心用户动作都经由 Rust 后端成功走通。
- Rust 返回的写入/投影/同步状态具有真实语义。
- 架构守卫测试与 FRB 集成测试能持续防止回退。
