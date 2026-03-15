# 2026-03-15 Flutter Rust 真实性修补设计

## 1. 背景与目标

- 当前 Flutter/Rust 主路径修补已经通过质量门禁与关键桥接测试，但 code review 仍发现 4 个重要问题。
- 这些问题集中在“用户看到的行为和后端真实语义是否一致”，包括：
  - joined pool 当前用户角色不真实；
  - card query 仍残留 Dart 侧产品语义过滤；
  - 编辑已有卡片保存时可能走 create 语义；
  - sync 恢复按钮仍是假动作，只改本地状态。
- 本设计的目标是继续修补这 4 个问题，使用户可见行为与 Rust 后端返回真相完全一致。

## 2. 已锁定决策

- 验收主线为“用户看到的行为真实优先”。
- joined pool 当前用户角色必须以后端当前调用者身份为准。
- Flutter 只展示 Rust 返回的当前用户角色，不允许前端自行推断。
- UI 中仍保留一个“保存”动作，但内部必须严格分流：
  - 无现有 `cardId` -> create
  - 有现有 `cardId` -> update
- `retry sync` 与 `reconnect` 必须都接真实后端动作。
- card query 的产品级搜索/过滤语义最终必须收回 Rust query API。

## 3. 备选方案比较

### 3.1 方案 A（选定）：用户可见行为优先的一次性收口

- 一次性修完身份真实性、保存动作分流、sync 恢复动作真实性、query 后端化。
- 优点：
  - 最符合当前验收目标；
  - 修完后用户可见行为可信度最高；
  - 不再需要继续带着已知假动作进入下一轮。
- 缺点：
  - 需要同时动 Flutter、Rust 和测试。

### 3.2 方案 B：先修用户可见错误，再修 query 纯度

- 先修 joined pool 身份、保存分流、sync 恢复按钮，query 后端化下一轮处理。
- 优点：
  - 最危险的问题先消除。
- 缺点：
  - 会短期保留“查询语义部分仍在 Flutter”的架构不纯状态。

### 3.3 方案 C：先补后端 query 与身份，再回头修 UI 动作

- 先做 Rust query/identity contract，再修页面与控制器。
- 优点：
  - 后端边界更工整。
- 缺点：
  - 用户可见错误修得更慢，不符合当前优先级。

## 4. 目标修补边界

- joined pool 页面中的当前用户角色必须是真实后端返回，不允许近似计算。
- 卡片编辑保存对用户仍是一个动作，但不能再出现“编辑变创建”的情况。
- sync 恢复动作必须是可观察的真实后端动作，而不是 UI 自我安慰式状态切换。
- card query 的产品语义必须以后端 query API 为准，Flutter 不再承担搜索/过滤真相。
- 修补后的生产路径中，旧的错误实现应被替换或移除，而不是继续共存。

### 4.1 禁止事项

- 禁止用成员列表第一个成员近似当前用户身份。
- 禁止用 create 流程承接已有卡片的保存。
- 禁止恢复动作按钮只改本地 `SyncStatus`。
- 禁止 Flutter 在查询结果上继续承担产品级过滤/搜索真相。

## 5. 组件与接口修补设计

### 5.1 Rust 当前用户视角查询

- Rust 需要提供带当前调用者身份语义的 joined pool query。
- 该查询必须基于明确的当前身份输入（例如 endpoint identity），而不是从池成员顺序推断。
- 返回 DTO 至少要包含：
  - 当前用户角色；
  - 当前用户是否 owner/admin/member；
  - 当前用户对应的 joined pool 视图。

### 5.2 Rust card query API

- Rust 需要提供真正面向产品行为的 card search/query API。
- 查询 API 需要接管：
  - 关键字搜索；
  - 删除态过滤；
  - 后续如有必要的池过滤；
  - 排序语义。
- Flutter 只展示 Rust 返回结果，不再在 Dart 侧追加产品语义过滤。

### 5.3 Flutter save / sync 动作编排

- `CardsController` 或等价编排层必须把一个“保存”动作内部拆成 create/update 两条语义路径。
- `PoolController` / `SyncService` 需要让 `retrySync` 与 `reconnect` 真实调用 `FrbSyncApiClient`。
- Flutter 仍保留统一交互入口，但交互背后的执行必须是真动作。

### 5.4 回退防护测试

- 守卫测试需要防止：
  - 前端重新推断当前用户身份；
  - 保存已有卡片重新走 create；
  - sync 恢复动作重新退化成本地假动作；
  - card query 重新回退为 Dart 侧产品语义过滤。

## 6. 数据流与状态语义修补

### 6.1 joined pool 当前用户角色

- `PoolPage -> PoolController -> FrbPoolApiClient.getJoinedPoolView -> Rust current-user-scoped query`
- Rust 基于当前调用者身份返回 joined pool 视图与当前用户角色。
- Flutter 不再从 `listPools()` 的结果或成员顺序中猜角色。

### 6.2 card save 内部分流

- `Editor save -> CardsController.save(...)`
- 若无现有 `cardId`：
  - 调 create API
- 若有现有 `cardId`：
  - 调 update API
- 用户看到的交互仍然只是“保存”，但后端动作语义必须正确。

### 6.3 sync 恢复动作

- `retry sync -> FrbSyncApiClient -> Rust sync retry action`
- `reconnect -> FrbSyncApiClient -> Rust reconnect action`
- Flutter 只根据 Rust 返回结果刷新状态，不预先假装恢复成功。

### 6.4 card query 后端化

- `CardsPage search/filter -> CardsController -> FrbCardApiClient.query -> Rust query API -> SQLite -> DTO -> Flutter`
- Flutter 不再在本地对 DTO 集合做产品级过滤来决定最终列表。

## 7. 测试与收尾策略

### 7.1 真实用户行为测试

- joined pool 当前用户身份测试：验证当前用户角色来自 Rust 当前调用者身份。
- 编辑已有卡片保存测试：验证保存后更新原卡，而不是创建新卡。
- sync 恢复动作测试：验证按钮点击后真实调用后端并根据结果刷新状态。

### 7.2 Rust 后端契约测试

- current-user-scoped pool query 测试。
- card query/search API 测试。
- sync status / recovery API 测试。

### 7.3 Flutter 编排与桥接测试

- save 动作 create/update 分流测试。
- query 刷新只依赖 Rust query API 测试。
- retry/reconnect 经 FRB 调 Rust 的测试。

### 7.4 回退防护测试

- 禁止前端回退为身份推断者。
- 禁止保存已有卡片继续走 create。
- 禁止 sync 恢复按钮只改本地状态。
- 禁止 card query 重新在 Dart 侧实现产品语义过滤。

## 8. 完成判定

- joined pool 当前用户角色与 Rust 当前调用者身份一致。
- 编辑已有卡片的保存操作更新原卡，不再新增新卡。
- retry sync 与 reconnect 都是可观察的真实后端动作。
- card query 产品语义完全以后端 query API 为准。
- 相关守卫测试能持续防止错误实现回流到生产路径。
