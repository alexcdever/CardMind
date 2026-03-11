# 2026-03-09 Flutter Rust 前后端分层设计

## 1. 背景与目标

- 本设计将 CardMind 收敛为一套内嵌式前后端架构：Flutter 充当前端，Rust 充当后端，`flutter_rust_bridge` 充当进程内 RPC 边界。
- 当前目标是落实 `docs/specs/pool.md` 与 `docs/specs/card-note.md` 已定义的可观察行为，并由 Rust 作为唯一业务真源。
- 第一阶段要打通的可观察闭环包括：创建池、加入池、创建卡片笔记、编辑卡片笔记、自动把 `noteId` 挂接到池元数据，以及让同步收敛后的结果最终对成员可见。
- 交付优先级为业务结果优先、同步控制其次，但仍要求具备显式同步 API 和可恢复的同步反馈。

## 2. 已锁定决策

- `Flutter` 只承担前端职责：UI 组合、交互流程、页面状态、API 调用、面向用户的恢复动作。
- `Rust` 只承担后端职责：领域规则、持久化、池与笔记关联、同步流程、稳定错误语义、DTO 产出。
- `FRB` 是薄边界层，不能演变成第二套业务层。
- `LoroDoc` 是卡片笔记与池元数据的唯一真实信源。
- `SQLite` 只作为查询侧读模型，不作为业务真源。
- 所有业务写入必须先经 Rust 落入 `LoroDoc`。
- 面向产品行为的查询必须走 `SQLite`，不能把 `LoroDoc` 作为产品查询主路径。
- `LoroDoc` 变更必须通过订阅机制、投影流程或等价链路更新到 `SQLite`。
- 外部同步结果必须先进入 `LoroDoc`，再驱动 `SQLite` 收敛。
- Flutter 不能继续作为业务写入真源。
- 第一阶段在关键业务动作之后采用显式触发同步，而不是后台优先自动同步。
- 不允许长期兼容层。如果某段短期兼容路径确实不可避免，相关代码必须带明确中文注释，说明它是临时兼容代码、正在兼容哪条旧路径、将由哪条新路径替代、后续必须删除。

## 3. 备选方案比较

### 3.1 方案 A（选定）：Rust 真源 + 面向用例 API

- Flutter 调用面向用例的 Rust API，例如创建池、加入池、创建笔记、编辑笔记、执行同步。
- 优点：
  - 最符合目标中的前后端分工；
  - 领域规则集中在 Rust；
  - 更容易保证规格约束和跨平台一致性；
  - 调用链显式，失败定位更清楚。
- 缺点：
  - 需要补齐更完整的 Rust API 与 DTO 设计；
  - 需要移除或绕开现有 Flutter 侧写路径。

### 3.2 方案 B：Rust 资源 API + Flutter 侧编排

- Rust 暴露更细粒度的 CRUD 风格资源接口，由 Flutter 组合成业务流程。
- 优点：
  - API 复用度高；
  - 页面组合更灵活。
- 缺点：
  - 业务规则容易回流到 Flutter；
  - 与选定的后端归属模型不够一致。

### 3.3 方案 C：与现有 Flutter 写路径渐进共存

- 暂时保留 Flutter 当前写逻辑，再逐步迁移部分流程到 Rust。
- 优点：
  - 短期迁移压力最小。
- 缺点：
  - 会形成双真源；
  - 与当前架构目标直接冲突；
  - 长期维护风险高。

## 4. 架构与职责边界

### 4.1 顶层架构

- `UI -> PageController -> ApiClient -> FRB -> Rust 后端 -> LoroDoc -> Projection -> SQLite -> Flutter 查询状态 -> UI`
- 同步链路与本地链路并行收敛：`Rust Sync <-> LoroDoc -> Projection -> SQLite`

### 4.2 Flutter 职责

- 构建并渲染 UI 组件。
- 处理路由与页面级交互流程。
- 持有 loading、success、empty、degraded、error 等展示状态。
- 通过轻量 Dart 客户端调用后端 API。
- 把稳定错误码转换为用户提示和恢复动作。

### 4.3 Rust 职责

- 落实 pool 与 card-note 规格中的领域规则。
- 掌管所有业务写入和业务不变量。
- 负责 `LoroDoc` 写入、投影驱动、`SQLite` 收敛与同步执行。
- 维护池元数据，包括 `noteId` 挂接规则。
- 返回稳定 DTO 和稳定错误码。

### 4.4 FRB 职责

- 在语言边界上传递请求与响应数据。
- 向 Flutter 暴露生成后的可调用 API。
- 除传输需要外，不承载领域分支、规则复制或长期翻译逻辑。

## 5. 前端命名模型

- 用更直接的前端术语替代抽象名称，例如不再使用 `Feature Facade`。
- 推荐的 Flutter 命名模型：
  - `ApiClient`：Dart 侧 Rust API 封装，例如 `PoolApiClient`、`CardApiClient`、`SyncApiClient`。
  - `PageController`：页面动作编排层，例如 `PoolPageController`、`CardsPageController`。
  - `ViewState`：面向渲染的页面状态，例如 `PoolPageState`、`CardsPageState`。
  - `UI`：页面与组件本身。
- 这样能让 Flutter 侧保持“前端栈”语义，而不是继续像半套后端。

## 6. 后端 API 面设计

### 6.1 Session/App API

- 初始化后端运行时上下文。
- 打开本地数据目录或等价的应用后端会话。
- 初始化同步所需的网络句柄。
- 查询后端是否就绪及当前运行状态。

### 6.1.1 后端内部读写分离约束

- 写模型真源为 `LoroDoc`。
- 读模型为 `SQLite`。
- Rust 对 Flutter 暴露的查询 API 必须以 `SQLite` 结果为准。
- Rust 对 Flutter 暴露的业务写 API 必须先写入 `LoroDoc`，再通过投影驱动 `SQLite` 更新。
- 投影失败与同步失败都不能伪装成业务写失败。

### 6.2 Pool API

- `createPool`
- `joinPool` 或 `requestJoinPool`，具体取决于当前产品语义
- `listPools`
- `getPoolDetail`
- Pool API 必须掌管成员规则、角色语义和池元数据修改。
- 加入池时，必须在同一个后端用例里自动挂接当前用户已有笔记引用。

### 6.3 Card API

- `createCardNote`
- `updateCardNote`
- `listCardNotes`
- `getCardNoteDetail`
- 当在池上下文中创建笔记时，Rust 必须在同一后端流程内把新的 `noteId` 写入池元数据。
- 对已挂接笔记执行更新或删除时，不能创建重复引用。

### 6.4 Sync API

- `connectSyncTarget`
- `runSyncNow`
- `getSyncStatus`
- `disconnectSync`
- 第一阶段由 Flutter 在关键业务成功后显式调用同步。

## 7. 数据流与关键闭环

### 7.1 创建池

- Flutter 通过 `PoolPageController` 和 `PoolApiClient` 触发 `createPool`。
- Rust 创建池、把创建者设为首个 admin，并先把业务事实写入 `LoroDoc`。
- `LoroDoc` 变更驱动投影更新 `SQLite`，查询侧收敛后返回或刷新 `PoolDto`。
- Flutter 刷新池查询结果时，应以 `SQLite` 查询结果为准；如果当前环境已联机，可继续显式触发同步。

### 7.2 加入池

- Flutter 触发 `joinPool`。
- Rust 完成加入流程，并在 `LoroDoc` 中自动挂接 card-note 规格要求的全部已有笔记引用。
- Flutter 不能再额外补一段客户端挂接逻辑。
- 之后由投影更新 `SQLite`，再由 Flutter 显式触发同步，并刷新池和笔记视图。

### 7.3 创建卡片笔记

- Flutter 触发 `createCardNote`。
- Rust 先把笔记写入 `LoroDoc`；如果当前处于池上下文，则在同一后端事务或等价原子流程内完成池元数据引用写入。
- `LoroDoc` 变更通过投影流程更新 `SQLite`。
- Flutter 显式触发同步，再通过 `SQLite` 查询刷新列表和详情视图。

### 7.4 编辑卡片笔记

- Flutter 触发 `updateCardNote`。
- Rust 先把更新后的内容写入 `LoroDoc`，同时保证不新增重复引用。
- 投影链路更新 `SQLite` 查询结果。
- Flutter 显式触发同步，再通过 `SQLite` 刷新当前视图。

### 7.5 业务成功与同步失败的分离表达

- 业务写入成功、投影未收敛、同步失败必须被分开表达。
- Flutter 必须能展示：数据已保存、同步尚未完成、可重试。
- 不能因为同步失败，就把一次成功的业务写入伪装成业务失败。
- 不能因为 `SQLite` 投影暂未完成，就把一次成功的 `LoroDoc` 写入伪装成业务失败。

## 8. DTO 与错误契约

### 8.1 DTO 原则

- Rust 必须返回稳定、面向视图的 DTO，而不是把内部存储或同步模型细节泄露给 Flutter。
- DTO 只暴露当前 UI 与验收范围真正需要的字段。
- 禁止为了未来假设场景而过度扩展，遵循 YAGNI。

### 8.2 核心 DTO

- `PoolDto`：池 id、名称、解散状态、当前用户角色、成员摘要、基础同步摘要。
- `PoolDetailDto`：池基础信息、笔记引用摘要、成员列表、待处理加入状态（如果适用）。
- `CardNoteDto`：笔记 id、标题、内容、时间戳、所属池摘要、删除状态。
- `SyncStatusDto`：当前同步状态、最近一次结果、是否可重试、推荐恢复动作。
- `SyncResultDto`：本次同步成功或退化结果、错误码（如适用）、下一步提示。

### 8.2.1 DTO 来源约束

- 业务写结果以 Rust 对 `LoroDoc` 的写入结果为准。
- 面向产品展示的查询 DTO 以 `SQLite` 查询结果为准。
- Flutter 不直接读取 `LoroDoc` 组装页面 DTO。

### 8.3 错误契约

- Rust 返回统一形态的 `ApiError`。
- Flutter 只基于稳定的 `error.code` 做分支。
- `error.message` 用于用户展示。
- `error.details` 只用于诊断，不能驱动产品逻辑。

### 8.4 错误分类

- `VALIDATION_*`
- `PERMISSION_*`
- `NOT_FOUND_*`
- `CONFLICT_*`
- `SYNC_*`
- `TRANSPORT_*`
- `INTERNAL`

### 8.5 恢复动作映射原则

- Validation 错误引导用户修正输入。
- Permission 错误停止重试并说明拒绝原因。
- Conflict 错误通过刷新或重新查询当前状态恢复。
- Projection 未收敛时提供重试查询、等待重试或触发投影恢复动作。
- Sync 错误提供重试同步或重连动作。
- Transport 错误提供重试或重新初始化后端动作。
- Internal 错误回退为通用重试和诊断路径。

## 9. 迁移策略

### 9.1 迁移目标

- 把 Flutter 侧业务写入真源移出主路径。
- 把前端代码收敛到 `UI + PageController + ViewState + ApiClient`。
- 把重叠的业务逻辑与持久化控制迁入 Rust，并收敛为 `LoroDoc` 写模型 + `SQLite` 读模型。

### 9.2 迁移顺序

- 先建立新的 Rust 用例 API。
- 再把 Rust 查询路径收敛到 `SQLite` 读模型。
- 再把 Flutter 页面改接到新的 `ApiClient` 路径。
- 停止页面主流程调用 Flutter 侧业务写层。
- 待新路径验证稳定后，删除过时的 Flutter 写层、存储层、application 层代码。

### 9.3 遗留代码处理

- `lib/features/pool/data/*`
- `lib/features/cards/data/*`
- `lib/features/shared/storage/*`
- `lib/features/*/application/*`
- 这些区域中凡是直接承担业务写逻辑、持久化真源或同步控制职责的代码，都必须退出主路径，并按阶段删除。
- 如果临时兼容代码确实不可避免，必须带明确中文注释，说明其临时性质和删除意图。

## 10. 测试策略

### 10.1 Rust 领域与应用测试

- 验证创建池、加入池、创建笔记、编辑笔记、自动挂接、幂等性和稳定错误语义。
- 验证业务写入先进入 `LoroDoc`，再驱动 `SQLite` 投影更新。

### 10.2 Rust 同步测试

- 验证显式同步流程、同步状态迁移、同步退化或失败语义，以及业务成功、投影未收敛、同步失败三者的分离表达。

### 10.3 Flutter 前端编排测试

- 验证页面动作流程，例如 `createCard -> runSyncNow -> reloadCards`。
- 验证页面查询结果来自 Rust 暴露的 `SQLite` 查询链路，而不是直接读取 `LoroDoc`。
- 这里不重复断言 Rust 业务规则。

### 10.4 跨语言烟测

- 用真实 FRB 跑少量关键端到端桥接用例。
- 确认请求与响应 DTO，以及错误传播，能穿过真实边界正常工作。

## 11. 第一阶段验收重点

- Given 无池上下文，When 创建池，Then 创建者成为 admin。
- Given 已有若干笔记，When 加入池，Then 池元数据包含这些已有 `noteId` 引用。
- Given 当前处于池上下文，When 创建笔记，Then 池元数据包含新的 `noteId`。
- Given 已挂接笔记，When 编辑笔记，Then 池元数据中不会新增重复 `noteId`。
- Given 一次业务写入成功但查询侧暂未收敛，When 用户稍后重新查询，Then 结果最终通过 `SQLite` 可见。
- Given 成员完成变更并显式同步，When 另一成员在收敛后刷新，Then 结果最终一致。
- Given 业务写入成功但同步失败，When 页面展示结果，Then 用户看到“已保存但未同步”的反馈和恢复动作。

## 12. 第一阶段范围外

- 多池并发同步控制台。
- 完整的后台优先自动同步策略。
- 为假想未来分域预埋的过度通用 API 面。
- Flutter 与 Rust 长期共存为双业务写入真源。
