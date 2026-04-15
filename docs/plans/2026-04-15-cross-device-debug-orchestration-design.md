# 跨端真实调试编排工具设计

## 背景

当前仓库已经具备真实双实例联机验证所需的最小调试能力：

- owner 可通过 `pool_debug.invite:` 在 `flutter run` 日志中直接暴露 invite
- joiner 可通过 `pool_debug.join.*` 与 `debug_status.log` 暴露真实 join 路径状态
- `macOS owner -> macOS joiner`
- `macOS owner -> iOS simulator joiner`

这两条真实链路都已验证可跑通。

但当前调试流程仍然高度手工：

1. 手工启动 owner
2. 从控制台复制 invite
3. 手工启动 joiner 并拼接 `dart-define`
4. 视目标平台再手工读取控制台或 app 容器中的状态文件

这导致每次真实复验都要重复拼命令、重复查容器、重复判断日志来源，收益已经低于额外的工具化成本。

## 目标

新增一个**本地开发专用**的跨端真实调试编排入口，至少支持以下两种组合：

- `macOS owner -> macOS joiner`
- `macOS owner -> iOS simulator joiner`

该入口应能：

1. 启动 owner
2. 自动抓取 invite
3. 启动 joiner
4. 自动收集关键日志与最终结果
5. 在终端给出一次性调试结论

## 非目标

- 不改变正式 join / sync 业务行为
- 不新增 Rust 或 Flutter 产品级调试接口
- 不扩展到 Android、iOS 真机或任意平台矩阵
- 不替代 `tool/build.dart`
- 不做长期驻留的设备管理平台
- 不把当前调试流程上升为正式产品能力

## 方案对比

### 方案 A：新增独立 Dart 调试入口

形式：

`dart run tool/debug_pool.dart --owner macos --joiner ios-sim`

优点：

- 职责边界最清晰，专门承接“真实调试编排”
- 不污染现有 `tool/build.dart`
- 后续扩到更多调试组合时演进空间更稳定

缺点：

- 需要新增一条工具入口和对应测试

### 方案 B：在 `tool/build.dart` 中新增调试子命令

优点：

- 入口集中，命令记忆成本最低

缺点：

- `build.dart` 当前职责是构建与运行单实例 app
- 若继续吸收多实例编排、日志抓取、容器读取，会继续膨胀

### 方案 C：仅补一层薄脚本包装

优点：

- 实现最快

缺点：

- 若不把参数校验、日志采集、容器读取一起收进去，最终仍是半自动
- 后续维护会再次散落成脚本片段

### 结论

采用**方案 A：新增独立 Dart 调试入口**。

原因：

- 当前问题的核心不是构建，而是“多实例真实调试编排”
- 这类职责与 `tool/build.dart` 的边界不同
- 单独入口更符合当前问题域，也能避免后续继续把构建脚本做成大杂烩

## 命令形态

首版命令固定为：

`dart run tool/debug_pool.dart --owner macos --joiner macos|ios-sim`

首版参数仅保留最小必需集：

- `--owner macos`
- `--joiner macos|ios-sim`
- `--pin <pin>`，默认 `1234`
- `--ios-device <udid>`，仅当 `--joiner ios-sim` 时可选；未传时自动选择当前 booted iPhone simulator
- `--keep-running`，默认关闭；关闭时在拿到最终结论后结束启动的调试进程
- `--verbose`，默认关闭；关闭时仅输出关键节点

## 执行流程

### 1. 参数校验

- 校验 `owner/joiner` 组合是否合法
- 若 `joiner=ios-sim`，则校验可用 simulator 是否存在

### 2. 启动 owner

`owner=macos` 时不直接走 `flutter run -d macos`，而是走：

- `dart run tool/build.dart run --dart-define=...`

固定注入：

- `CARDMIND_DEBUG_START_IN_POOL=true`
- `CARDMIND_DEBUG_AUTO_CREATE_POOL=true`
- `CARDMIND_DEBUG_PIN=<pin>`
- `CARDMIND_DEBUG_EXPORT_INVITE_PATH=<tool-managed-path>`
- `CARDMIND_DEBUG_STATUS_EXPORT_PATH=<tool-managed-path>`

### 3. 抓取 invite

优先从工具主动注入的 invite 导出文件中读取 invite。

原因：

- `macOS` 在 worktree 场景下直接走 `flutter run -d macos` 会再次命中文件沙盒与运行态 dylib 路径问题
- `tool/build.dart run` 已是当前仓库验证通过的稳定路径

若在超时时间内拿不到 invite，命令直接失败，并输出 owner 最近日志片段与导出文件状态。

### 4. 启动 joiner

`joiner=macos` 时同样走：

- `dart run tool/build.dart run --dart-define=...`

并主动注入：

- `CARDMIND_DEBUG_START_IN_POOL=true`
- `CARDMIND_DEBUG_PIN=<pin>`
- `CARDMIND_DEBUG_JOIN_CODE=<invite>`
- `CARDMIND_DEBUG_JOIN_TRACE=true`
- `CARDMIND_DEBUG_STATUS_EXPORT_PATH=<tool-managed-path>`

`joiner=ios-sim` 时继续走：

- `flutter run -d <udid> --dart-define=...`

### 5. 收集 join 结果

joiner 侧收集策略分平台：

- `joiner=macos`：优先读取工具主动注入的 `debug_status.log`
- `joiner=ios-sim`：读取 app 容器内 `debug_status.log`
- `pool_debug.join.*` 仍作为辅助观测点，而不再是唯一真相源

优先判定最终状态：

- `joined:<poolId>`
- `join_error:<code>:<message>`

### 6. 输出结论

终端输出至少包含：

- owner 目标
- joiner 目标
- invite 是否抓取成功
- 是否观察到 `pool_debug.join.*`
- 最终 join 结果

### 7. 清理策略

- 默认结束 owner/joiner 启动的调试进程
- 若启用 `--keep-running`，则保留现有会话供人工继续观察

## 模块拆分

为避免把全部逻辑塞进一个长文件，首版拆为四个最小模块：

### `tool/debug_pool.dart`

- CLI 入口
- 参数解析
- 调用编排器
- 打印最终结果

### `tool/src/debug_pool/debug_pool_runner.dart`

- owner/joiner 编排主流程
- invite 抓取
- 结果汇总

### `tool/src/debug_pool/flutter_run_session.dart`

- 封装 `flutter run` 子进程
- 读取 stdout/stderr
- 等待目标日志锚点
- 结束会话

### `tool/src/debug_pool/macos_build_run_session.dart`

- 封装 `dart run tool/build.dart run`
- 管理 macOS owner/joiner 的文件导出路径
- 在 `build.dart run` 日志与导出文件之间提供统一会话接口

### `tool/src/debug_pool/simctl_support.dart`

- 只处理 iOS simulator 能力
- 获取 booted device
- 获取 app container
- 读取 `debug_status.log`

## 错误处理

首版至少覆盖以下错误：

- owner 未能在超时内导出 invite
- joiner 未能在超时内启动到可观测状态
- iOS simulator 不存在或未 boot
- 无法读取 app container
- `debug_status.log` 缺失或没有最终结果
- `flutter run` 进程异常退出

错误输出原则：

- 直接指出失败阶段
- 附最近的关键日志片段
- 不隐藏原始错误信息

## 验证策略

### 自动化验证

以脚本逻辑自动化测试为主，不强制把真实设备调试纳入门禁。

建议覆盖：

- 参数校验
- owner invite 抓取
- joiner trace 抓取
- `joined:` / `join_error:` 结果汇总
- `joiner=ios-sim` 时的 simctl 查询逻辑

### 手工真实验证

至少执行一条：

- `dart run tool/debug_pool.dart --owner macos --joiner ios-sim`

验收目标：

- 不需要人工复制 invite
- 能在终端直接看到最终 join 结论

## 风险与取舍

### 风险 1：macOS 运行路径与 `flutter run -d macos` 不一致

应对：

- `macOS` 统一复用已经验证通过的 `tool/build.dart run`
- `macOS` invite 与最终状态统一从工具主动注入的文件读取
- `pool_debug.join.*` 仅作为辅助观测点

### 风险 2：iOS simulator 容器读取受平台环境影响

应对：

- 将 simulator 相关逻辑隔离到单独模块
- 失败时直接暴露原始 `simctl` 错误，避免吞错

### 风险 3：工具继续膨胀

应对：

- 首版只支持 `owner=macos`
- 首版只支持 `joiner=macos|ios-sim`
- 不开放通用自定义 `dart-define` 注入口

## 验收标准

以下条件全部满足，视为首版工具完成：

1. 存在独立入口 `dart run tool/debug_pool.dart`
2. 支持 `--owner macos --joiner macos|ios-sim`
3. 能自动抓取 owner invite，而不需要人工复制
4. 能自动给 joiner 注入 invite 并等待结果
5. 能在终端输出最终 `joined:` 或 `join_error:` 结论
6. 至少有一组脚本逻辑自动化测试
7. 至少完成一次 `macOS owner -> iOS simulator joiner` 的真实手工复验
