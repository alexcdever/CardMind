# FRB API 设计文档

## 目标
- 建立 Flutter/Rust 桥接的薄层 FRB API
- 采用句柄式生命周期（`init_*` 返回 `store_id`）
- Dart 传入 `base_path`，Rust 负责校验与路径拼接
- 卡片接口覆盖 CRUD + 列表/排序 + 搜索（SQLite LIKE）
- 数据池接口覆盖创建/读取/加入/退出/审批/广播（接口先定义）
- 无订阅回调，Flutter 端主动拉取
- 错误统一映射为“错误码 + 消息”

## 非目标
- 不实现事件订阅
- 不做跨设备同步细节实现
- 不引入复杂事务或批量 API

## 架构概览
- FRB 仅暴露薄层 API，不引入额外业务逻辑
- Rust 侧提供 `CardStore`、`PoolStore`、`SqliteStore` 三类句柄
- Flutter 调用 `init_*`，传入 `base_path`，返回 `store_id`
- 所有 I/O 操作使用 async，其它保持同步
- Rust struct 直接暴露为 FRB 类型（无 JSON 传递）

## 组件与职责
### CardStore
- 负责卡片写入与读取
- 写入流程：生成 UUID v7 → 写 Loro → 更新 SQLite
- 读取与搜索：仅走 SQLite 缓存
- 支持分页与排序参数（如 `limit/offset/sort_by`）

### PoolStore
- 负责数据池元数据与成员管理
- 提供创建池、读取池、加入/退出/审批/广播接口
- 网络行为未实现时返回 `NOT_IMPLEMENTED`

### SqliteStore
- 作为内部依赖供 CardStore 使用
- 暂不对 UI 直接暴露

## 路径与句柄
- Dart 传入 `base_path`
- Rust 校验 `base_path` 可用性
- Loro 路径拼接：`data/loro/note/<base64(uuid)>`、`data/loro/pool/<base64(uuid)>`
- SQLite 路径拼接：`data/sqlite/cardmind.sqlite`（拟定）

## 错误处理
- 对外统一返回 `ApiError { code, message }`
- 最小错误码集合：
  - `INVALID_ARGUMENT`
  - `NOT_FOUND`
  - `NOT_IMPLEMENTED`
  - `IO_ERROR`
  - `SQLITE_ERROR`
  - `POOL_NOT_FOUND`
  - `INVALID_POOL_HASH`
  - `INVALID_KEY_HASH`
  - `ADMIN_OFFLINE`
  - `REQUEST_TIMEOUT`
  - `REJECTED_BY_ADMIN`
  - `ALREADY_MEMBER`

## 测试策略
- CardStore：创建/更新/删除/按 id 读取/列表/搜索
- PoolStore：创建池、成员增删、加入/退出/审批错误码
- 错误映射：覆盖每类错误码与 message 非空
- FRB 入口：Rust 侧单测验证参数校验与错误码稳定
