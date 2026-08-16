## 任务 N

CardMind 测试基础设施与诊断增强：**两端调试日志 + 独立 TAP 测试网段验收配合**。

## 背景

用户要求为 Android 模拟器与 Windows app 增强调试日志，方便诊断配对、relay、mDNS、同步问题。当前模拟器默认 NAT 网络导致 mDNS 不穿透；后续将使用独立 TAP/独立测试网段做平台联调。TAP 驱动和网卡配置由主代理在获得管理员授权后处理，executor 只负责 app 日志和测试钩子，不直接修改 Windows 网络。

## 改动范围

- Flutter 两端共享日志模块（建议 `lib/bridge/debug_log.dart` 或符合现有结构的位置）
- `lib/pages/devices_page.dart`
- `lib/bridge/bridge_helper.dart`、`lib/bridge/frb_note_repository.dart`
- `rust-backend/src/sync.rs`、`rust-backend/src/api.rs`（如需补充 Rust 侧日志）
- 测试文件：配对 UI、relay、同步相关测试
- 禁止修改 Windows 网卡、TAP 驱动、路由和防火墙；禁止写入密钥、配对码、私钥或完整 device key

## 日志要求

### Flutter/Android/Windows 共用字段

每条日志至少包含：

- 时间戳
- 平台（Windows/Android）
- 事件名
- 当前阶段
- 可脱敏的 device ID（只允许前 8 + 后 8 字符，中间省略）
- 错误类型与错误链
- 耗时（配对/连接/同步操作）

### 必须记录的事件

1. 应用启动：RustLib/Bridge/SyncService 初始化成功或失败
2. relay 配置：是否启用、relay 主机和端口（禁止记录 token/凭据）
3. 本机身份：脱敏 device ID
4. 设备发现：mDNS 开始、发现数量、候选 ID 脱敏、发现耗时
5. 显示配对码：开始、广播启动、确认方 accept loop 启动/结束、取消、超时
6. 输入配对码：是否手动提供 device ID、是否跳过 mDNS、目标 ID 脱敏
7. 连接阶段：开始、使用直连或 relay、成功、超时、失败错误链和耗时
8. 配对阶段：请求发送、请求接收、confirm 开始/成功/失败
9. 首次全量同步：push 开始、接收、导入成功/失败、笔记数量（不得记录笔记正文）
10. 后续同步：触发原因、待同步数量、成功/失败和耗时
11. mDNS/relay/socket 清理：成功或异常

### 输出与开关

- 默认输出到平台调试日志：Flutter `debugPrint`/等价 logger，Rust `tracing`
- 增加可测试的 logger 接口或 sink，测试可以断言事件而不依赖控制台文本
- 支持通过 debug 开关提高详细程度；release 默认不输出敏感内容
- 日志写入失败不能影响配对或同步主流程
- 不得把 `SecretKey`、API key、完整 device ID、配对码、笔记正文写入日志

## TDD 与验收标准

1. `debug logger redacts device ids`：完整 ID 只输出脱敏形式；SecretKey、API key、配对码、笔记正文不会出现在日志事件中。
2. `startup emits initialization events`：启动成功和失败各有可断言事件。
3. `relay config emits safe endpoint event`：记录 relay host/port 和 enabled，不记录凭据。
4. `manual pairing emits discovery-bypass event`：手动 device ID 路径明确记录跳过 mDNS。
5. `mdns discovery emits count and duration`：发现成功、空结果、多候选都记录数量和耗时。
6. `pairing accept lifecycle emits all stages`：显示码、accept、request、confirm、成功/失败/取消/超时事件完整。
7. `relay connection emits transport and error chain`：能区分 direct/relay，超时包含耗时和错误链。
8. `initial sync emits counts only`：记录同步方向、笔记数量、耗时，不记录内容。
9. `logger failure does not break flow`：日志 sink 抛异常时配对/同步仍完成。
10. `cargo test` 全绿，外层默认 180 秒硬上限。
11. `flutter test --timeout 3m` 全绿。
12. `flutter analyze` 无 error。
13. 现有真实 relay 测试仍通过；不得用 mock 代替真实 relay 验收。
14. Windows/Android 至少各有一条集成测试或平台日志采集验证，明确报告实际覆盖范围。
15. `git status` 改动只在任务范围内；不得改 `.gitignore`、TAP/网卡配置或写入凭据。

## TAP 联调前置验收（主代理执行，非 executor）

- TAP 驱动安装后，独立测试网段例如 `192.168.250.0/24`
- Windows 默认路由仍指向现有 `192.168.31.1`
- Windows 物理网卡 IP、网关、DNS 不变
- 不创建 Windows 网络桥
- 模拟器通过 `-net-tap` 或 `-wifi-tap` 使用独立接口
- Windows app 绑定/可访问测试网段地址
- mDNS 多播在测试网段可见
- 测试完成可删除 TAP 接口和专用路由，宿主网络恢复原样

## 测试纪律

所有测试默认 3 分钟超时。Rust 网络/阻塞操作和 spawned task 两侧必须 `tokio::time::timeout`；cargo test 外层硬超时 180 秒；Flutter 使用 `--timeout 3m`。超过 3 分钟立即停止并检查原因，禁止无限等待。
