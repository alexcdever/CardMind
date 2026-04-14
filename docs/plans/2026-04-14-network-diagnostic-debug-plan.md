# 最小网络互通调试方案

## 背景

当前真实双实例联机验证已经从“无法启动或无法触发 join”收敛为“连接建立阶段超时”。

已确认现象：

- `macOS owner -> iOS simulator joiner` 失败时返回 `join_error:INTERNAL:connect failed: internal error: timed out`
- `iOS simulator owner -> macOS joiner` 失败时同样返回 `join_error:INTERNAL:connect failed: internal error: timed out`
- 双端都能完成应用启动、自动解锁、网络初始化与 auto join 触发

这说明当前主要问题不再是 Flutter 页面流程、应用锁 gating 或 runtime 初始化，而是缺少对“基础网络互通性”和“连接尝试阶段”的直接观测。

同时，现有通过 `debug_status.log` / `debug_invite.txt` 写文件的调试路径存在明显问题：

- macOS app 对仓库路径写入受沙盒影响，不稳定
- 多个容器实例容易留下历史文件，排查时容易误读
- 调试信息依赖文件导出，操作笨重，不利于快速迭代

## 目标

本次只做**开发期最小调试能力**，用于回答以下问题：

1. owner 侧生成的 invite 是否已被正确暴露
2. joiner 是否正确解析出 invite 中的目标 endpoint 与地址列表
3. 真实 join 过程中到底尝试了哪些目标地址
4. 每次连接尝试耗时多久，最终失败点是否稳定收敛为 timeout

## 非目标

- 不改变正式 join / sync 业务行为
- 不新增独立“诊断连接”分支
- 不引入正式用户可见页面
- 不在本轮解决 `iroh` 超时本身
- 不把调试参数、日志格式上升为正式产品契约

## 方案

采用**沿现有真实 join 路径补结构化调试输出**的最小方案，不新增独立诊断连接接口。

### owner 侧

在 debug 参数显式开启时，创建池成功后直接把 invite 输出到 Flutter debug 日志。

建议参数：

- `CARDMIND_DEBUG_PRINT_INVITE=true`

建议日志：

- `pool_debug.invite:<invite>`

目标：

- 在 `flutter run` 场景下，优先直接从调试输出拿到 invite，而不是继续依赖文件导出

### joiner 侧

在 debug 参数显式开启时，不额外发起一轮“诊断连接”，而是在**真实 join 路径内部**补结构化调试输出。

建议参数：

- `CARDMIND_DEBUG_JOIN_TRACE=true`

调试输出覆盖以下阶段：

1. invite 解析结果
2. 目标 endpoint id
3. 目标地址列表
4. 每个地址的连接尝试开始
5. 每个地址的连接尝试结束
6. 每次尝试耗时
7. 最终整体结果

建议日志格式：

- `pool_debug.join.invite_parsed:<pool_id>:<target_endpoint>`
- `pool_debug.join.target_addrs:<addr1,addr2,...>`
- `pool_debug.join.attempt_start:<addr>`
- `pool_debug.join.attempt_end:<addr>:<result>:<duration_ms>:<message>`
- `pool_debug.join.final:<result>:<message>`

其中 `result` 以最小够用为原则，至少应能区分 `timeout` 与非 `timeout`；其余分类按实现过程中现有连接路径可直接提供的信息最小化确定，不在本计划中上升为正式接口约束。

## 实现边界

### Rust

- 在现有 invite join 路径内部补调试日志采集点
- 不新增独立“网络诊断连接” API
- 仅在 debug 开关开启时组装并向上返回调试日志内容

### FRB

- 优先复用现有日志链路或现有可传递信息，不预设必须新增独立调试返回结构
- 只有在 Flutter 侧无法拿到最小调试输出时，才补满足当前调试目标的最小桥接

### Flutter

- 只在 debug 参数显式开启时打印 invite 和 join trace
- 输出优先走 debug console
- 现有文件导出逻辑不再作为本轮主依赖，本轮不扩展其职责

## 风险与取舍

### 风险 1：调试输出改变连接时序

应对：

- 不发起额外诊断连接
- 只在现有真实 join 路径内记录阶段信息
- 避免重复连接尝试

### 风险 2：调试日志过多影响阅读

应对：

- 仅在显式 debug 参数开启时输出
- 使用统一前缀 `pool_debug.` 便于筛选

### 风险 3：敏感信息输出过多

应对：

- 本轮仅用于本地开发期调试
- 默认不开启
- 如后续需要对外共享日志，再补脱敏策略

## 验收标准

以下条件全部满足，视为本轮调试方案完成：

1. 用 `flutter run` 启动 owner 且开启 `CARDMIND_DEBUG_PRINT_INVITE=true` 时，日志中出现一条 `pool_debug.invite:` 记录
2. 用 `flutter run` 启动 joiner 且开启 `CARDMIND_DEBUG_JOIN_TRACE=true` 时，日志中至少出现：
   - `pool_debug.join.invite_parsed:`
   - `pool_debug.join.target_addrs:`
   - 至少一条 `pool_debug.join.attempt_start:`
   - 至少一条 `pool_debug.join.attempt_end:`
   - 一条 `pool_debug.join.final:`
3. 在当前失败场景下，`pool_debug.join.final:` 能直接反映最终错误是否为 timeout
4. 现有正式 join 成功/失败语义不变
5. 实现不得新增独立“诊断连接”分支，调试输出必须来自真实 join 路径内的观测点
6. 至少补一条与调试输出开关对应的自动化验证；验证层级以能证明“真实 join 路径开启调试输出后可观测到目标日志锚点”为准

## 后续使用建议

如果这组最小调试输出仍不足以判断“两个实例基础网络是否互通”，下一步再评估：

- 是否补一个独立的基础连通性检查
- 是否增加隐藏调试页承载结构化结果
- 是否把 Rust 侧连接阶段进一步细化到更接近 `iroh` 内部边界
