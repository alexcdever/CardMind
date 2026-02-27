# CardMind Flutter-Rust 同步网络对接设计（2026-02-28）

## 1. 背景与目标
- 目标：以“生产级对接方案”打通 Flutter 与 Rust 的同步网络主链路，覆盖桌面与移动端统一验收。
- 优先级：同步网络优先（`rust/src/net/*`），功能与稳定性优先于性能极限优化。
- 设计原则：
  - Rust 保持网络能力真源；
  - FRB 为唯一跨语言边界；
  - Flutter UI 不直接依赖 FRB 原始接口；
  - 所有失败必须可见、可理解、可恢复。

## 2. 范围与边界
### 2.1 范围内
- 同步网络垂直切片链路：连接、加入池、推送、拉取、断开、状态查询。
- Flutter 侧同步领域分层：`SyncService`（承担 facade 职责）、状态模型、控制器。
- 错误模型统一：稳定错误码 + 用户文案 + 诊断细节。
- 全平台一致状态语义与交互反馈。

### 2.2 范围外（YAGNI）
- 首批不引入复杂多池并发可视化控制台。
- 首批不引入性能压测门槛型发布门禁（保留可观测指标）。
- 首批不拆分多套平台专用 UI 状态协议。

## 3. 架构设计
- Rust 侧继续通过 `rust/src/api.rs` 暴露对外能力，网络实现收敛在 `rust/src/net/*`。
- FRB 配置维持当前入口（`crate::api`），生成文件位于 `lib/bridge_generated/*`，禁止手改生成物。
- Flutter 侧建立同步域统一门面（命名采用 `SyncService`），职责包括：
  - FRB 调用编排；
  - 参数与超时策略校验；
  - 错误码映射与状态转换；
  - 屏蔽平台差异。
- UI 层仅依赖状态与动作，不直接依赖 FRB。

## 4. 组件与接口
### 4.1 Rust 对外接口组（语义分组）
- `syncInit(config)`
- `syncConnect(target)`
- `syncJoinPool(poolId, invite)`
- `syncPush(localChanges)`
- `syncPull()`
- `syncDisconnect()`
- `syncStatus()`

说明：接口命名可在实现期按现有仓库风格微调，但语义边界保持不变。

### 4.2 Flutter 同步域组件
- `SyncService`：跨语言调用与容错策略入口。
- `SyncController`：UI 动作编排（join/retry/reconnect 等）。
- `SyncState`：统一状态模型，供页面与组件渲染断言。

## 5. 数据流与状态机
### 5.1 主数据流
- `UI Action -> SyncController -> SyncService -> FRB API -> Rust net -> Result/Error -> State Update -> UI Feedback`

### 5.2 状态机定义
- `idle`
- `connecting`
- `connected`
- `syncing`
- `degraded`
- `error`

### 5.3 状态约束
- 同步中的重复触发必须幂等，防止重复提交。
- 长耗时操作具备超时边界。
- 失败后必须提供明确下一步动作（retry/reconnect/rejoin）。

## 6. 错误处理与稳定性
### 6.1 错误分层
- `DomainError`：业务可判定错误（基于稳定错误码）。
- `FfiTransportError`：跨语言桥接与序列化错误。
- `UnexpectedError`：未知兜底错误。

### 6.2 映射规则
- Rust 返回结构：`code/message/details`。
- Flutter 逻辑只依赖 `code` 做分支；`message` 用于用户展示；`details` 用于诊断日志。

### 6.3 恢复策略
- 可重试错误：指数退避 + 抖动，超上限后进入 `degraded` 或 `error`。
- 不可重试错误：直接进入 `error` 并提供明确恢复动作。
- 连接抖动：优先自动重连，期间状态可解释且可见。

### 6.4 可观测性（含线上排障能力）
- Flutter 与 Rust 统一结构化日志字段：`op_id/session_id/pool_id/error_code`。
- 禁止吞错，所有失败必须映射到可见状态。

## 7. 测试设计（功能与稳定性优先）
### 7.1 Rust 测试
- `cargo test` 覆盖同步接口边界、错误码稳定性、超时/重试逻辑。

### 7.2 Flutter 领域测试（无 UI）
- `SyncService`、`SyncController` 的状态迁移与错误映射单测。

### 7.3 Flutter UI 组件与交互测试
- 组件测试：基于状态断言渲染结果（loading/error/degraded/connected）。
- 交互测试：基于 fake `SyncService` 断言 join/retry/reconnect 的状态迁移与反馈。
- 要求：禁用交互必须有说明，失败态必须有可执行恢复动作。

### 7.4 跨语言链路测试
- 少量端到端用例走真实 FRB，验证对接链路可用。

### 7.5 必过门禁
- `flutter analyze`
- `flutter test`
- `cargo test`
- `flutter test test/interaction_guard_test.dart`
- `flutter test test/ui_interaction_governance_docs_test.dart`

## 8. 验收标准（DoD）
- 同步主链路可用：connect/join/push/pull/recover。
- 错误码可稳定映射并驱动恢复动作。
- Flutter UI 组件测试与交互测试稳定通过。
- 交互治理门禁无违规（无空交互、无无说明禁用交互）。
- 桌面与移动平台保持一致状态语义和核心交互反馈。

## 9. 实施顺序建议
1. 固化 Rust 对外同步接口语义与错误码协议。
2. 完成 FRB 映射与 Flutter `SyncService` 门面层。
3. 建立 `SyncController/SyncState` 并接入现有页面。
4. 补齐 Flutter 组件测试、交互测试与 Rust 侧测试。
5. 跑全量门禁并修复至全绿。
