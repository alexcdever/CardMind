# 2026-03-15 Flutter Rust 最终契约收尾设计

## 1. 背景与目标

- 当前 Flutter/Rust 主路径修补与真实性修补已经基本完成，并通过了质量门禁与关键测试。
- 但 review 仍指出最后一组契约不一致问题：
  - 带 `current_user_role` 的 pool API 还没有全部做到 caller-scoped；
  - card query 的默认列表策略仍在 Flutter 保留了一小段产品语义。
- 本设计的目标是做最后一轮契约收尾，使 pool 身份字段与 card query 语义彻底由 Rust 统一定义，并消除前端残留策略开关。

## 2. 已锁定决策

- 所有带 `current_user_role` 的 pool API 都必须 caller-scoped。
- 只要 Rust 返回 `current_user_role`，就必须显式基于当前调用者身份计算。
- 调用者不在池里时，必须返回明确错误，不能伪造 `member`。
- card query 的默认产品语义由 Rust 固定为：列表默认仅返回 `deleted = false`。
- 搜索是在默认未删除列表基础上再加过滤，而不是改变 deleted 过滤规则。
- Flutter 不再携带 `includeDeleted` 这类会影响产品语义的参数。

## 3. 备选方案比较

### 3.1 方案 A（选定）：强一致语义收尾

- 把所有带 `current_user_role` 的 pool API 都改成 caller-scoped。
- 把 card query 的默认列表与搜索语义都收回 Rust。
- 优点：
  - 契约最干净；
  - 同名字段不再出现多套语义；
  - Flutter 不再残留产品规则开关。
- 缺点：
  - 需要同时调整 Rust API、Flutter 调用方与测试。

### 3.2 方案 B：最小补丁收尾

- 只修 `get_joined_pool_view()` lookup miss，`get_pool_detail()` 不再承诺真实角色。
- Flutter 中把 `includeDeleted` 固定写死。
- 优点：
  - 改动最小。
- 缺点：
  - 契约仍然比较零碎；
  - 不能真正回答“谁定义产品语义”。

### 3.3 方案 C：只修后端内部，不动前端接口

- 尽量在 Rust 内部兜底，保持 Flutter 参数形状不变。
- 优点：
  - 表面修改面较小。
- 缺点：
  - Flutter 仍保留不该有的策略开关；
  - 漂移风险仍在。

## 4. 最终契约边界

### 4.1 Pool 身份契约

- `get_joined_pool_view()` 必须 caller-scoped。
- `get_pool_detail()` 如果继续返回 `current_user_role`，也必须 caller-scoped。
- 两类 API 都必须接收明确的当前调用者身份输入。
- 两类 API 在 lookup miss 时都必须返回明确错误，而不是伪造角色。

### 4.2 Card query 契约

- card list 默认语义固定为：仅返回 `deleted = false`。
- card search 语义固定为：在未删除集合上继续按关键字过滤。
- Flutter 只表达“默认列表”或“按关键字搜索”的意图。
- deleted 是否参与集合由 Rust 固定定义，而不是由 Flutter 决定。

### 4.3 禁止事项

- 禁止任何 pool API 继续用 `members.first()` 近似当前用户角色。
- 禁止 lookup miss 时返回假 `member`。
- 禁止 Flutter 继续传 `includeDeleted` 之类的产品语义开关。

## 5. 组件与接口收尾设计

### 5.1 Rust pool API

- 所有返回 `PoolDto` / `PoolDetailDto` 且包含 `current_user_role` 的 API，都需要 caller identity 参数。
- role 计算必须基于显式调用者身份查成员关系。
- 如果调用者不在池中：
  - 返回稳定错误（例如 not member / not found 风格错误）。

### 5.2 Rust card query API

- Rust query API 直接定义两类使用意图：
  - 默认列表
  - 关键字搜索
- 两类查询都以内置的 `deleted = false` 默认产品规则为前提。
- Flutter 无需再暴露或传递 `includeDeleted`。

### 5.3 Flutter 调用方

- `FrbPoolApiClient` 调 pool caller-scoped query 时必须提供当前调用者身份。
- `CardsController` / `FrbCardApiClient` 不再暴露 `includeDeleted` 语义。
- Flutter 只发“我要列表”或“我要搜索关键词”这种意图。

## 6. 数据流与测试收尾设计

### 6.1 Pool caller-scoped 查询链路

- `Flutter -> FrbPoolApiClient -> Rust pool API(带调用者身份) -> DTO/error -> Flutter`
- 调用者存在于池中时返回真实 `current_user_role`。
- 调用者不在池中时返回明确错误。

### 6.2 Card query 真相链路

- `Flutter -> FrbCardApiClient -> Rust card query API -> SQLite -> DTO -> Flutter`
- 默认列表固定 `deleted = false`。
- 搜索在默认未删除集合上继续过滤。
- Flutter 不再在本地补 deleted 过滤规则。

### 6.3 测试收尾

- Rust 契约测试：
  - caller-scoped pool query happy path
  - caller-scoped pool query lookup miss
  - card default list 只返回未删除
  - card search 仍只在未删除集合上工作
- Flutter 编排测试：
  - pool query 必须带调用者身份
  - card query 不再传 `includeDeleted`
- 回退防护测试：
  - 禁止回退为 `members.first()` 角色推断
  - 禁止回退为 lookup miss 伪造 member
  - 禁止 Flutter 重新引入 deleted 语义开关

## 7. 完成判定

- 所有带 `current_user_role` 的 pool API 都只返回 caller-scoped 真相。
- 调用者不在池中时，Rust 返回明确错误，不再伪造角色。
- card 默认列表与搜索语义完全由 Rust 定义，且固定默认 `deleted = false`。
- Flutter 不再保留 `includeDeleted` 这类产品语义参数。
- 相关守卫测试能持续防止契约漂移回流。
