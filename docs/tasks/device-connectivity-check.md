# 设备连接可用性检查

<!-- Task ID: device-connectivity-check -->

```pipeline-contract
{
  "schema": 4,
  "task_id": "device-connectivity-check",
  "task_type": "vertical-feature",
  "project_type": "desktop",
  "risk": "high",
  "goal": {"path": "goal.md"},
  "allowed_paths": [
    "goal.md",
    "docs/goal.md",
    "docs/tasks/device-connectivity-check.md",
    ".pipeline/device-connectivity-check/**",
    "lib/pages/devices_page.dart",
    "lib/bridge/note_repository.dart",
    "lib/bridge/frb_note_repository.dart",
    "lib/bridge/bridge_helper.dart",
    "lib/src/rust/**",
    "rust-backend/src/api.rs",
    "rust-backend/src/sync.rs",
    "rust-backend/src/store.rs",
    "rust-backend/src/frb_generated.rs",
    "rust-backend/tests/connect_test.rs",
    "rust-backend/tests/store_test.rs",
    "test/sync_ui_widget_test.dart",
    "test/frb_note_repository_test.dart"
  ],
  "forbidden_paths": [".env", "**/target/**", "build/**", ".workflow/**"],
  "non_goals": [
    "不实现持续在线监控",
    "不实现批量测试",
    "不持久化主动检查结果、检查时间或检查延迟",
    "不因测试连接触发笔记同步或发送笔记内容"
  ],
  "operations": [
    {
      "id": "connectivity-core-and-persistence",
      "kind": "implement",
      "scope": "Rust health-check protocol, FRB API, last_seen/last_sync_at persistence and sync semantics",
      "resources": ["rust-backend/src/api.rs", "rust-backend/src/sync.rs", "rust-backend/src/store.rs", "lib/src/rust"],
      "resource_mode": "batch",
      "acceptance_tests": ["acceptance-test-1", "acceptance-test-2", "acceptance-test-3"]
    },
    {
      "id": "device-page-interaction",
      "kind": "implement",
      "scope": "Device list test-connection interaction, transient states and accessibility",
      "resources": ["lib/pages/devices_page.dart", "lib/bridge/note_repository.dart", "lib/bridge/frb_note_repository.dart", "test/sync_ui_widget_test.dart"],
      "resource_mode": "batch",
      "acceptance_tests": ["acceptance-test-4", "acceptance-test-5"]
    }
  ],
  "chain": {
    "entry": ["lib/pages/devices_page.dart: DevicesPage"],
    "interaction": ["lib/pages/devices_page.dart: _buildDeviceItem", "test/sync_ui_widget_test.dart: main"],
    "application": ["lib/bridge/note_repository.dart: NoteRepository", "lib/bridge/frb_note_repository.dart: FrbNoteRepository"],
    "domain": ["rust-backend/src/sync.rs: SyncService", "rust-backend/src/api.rs: check_device_connectivity"],
    "persistence": ["rust-backend/src/store.rs: NoteStore", "rust-backend/src/store.rs: PairedDeviceRow"],
    "readback": ["lib/pages/devices_page.dart: _load", "lib/bridge/frb_note_repository.dart: listPairedDevices"],
    "recovery": ["lib/pages/devices_page.dart: _buildDeviceItem", "rust-backend/src/sync.rs: check_device_connectivity"]
  },
  "acceptance_tests": [
    {
      "id": "acceptance-test-1",
      "evidence_level": 4,
      "test_ref": "rust-backend/tests/connect_test.rs: test_paired_devices_crud",
      "command_ref": "cd rust-backend && cargo test --test connect_test"
    },
    {
      "id": "acceptance-test-2",
      "evidence_level": 4,
      "test_ref": "rust-backend/tests/store_test.rs: main",
      "command_ref": "cd rust-backend && cargo test --test store_test"
    },
    {
      "id": "acceptance-test-3",
      "evidence_level": 4,
      "test_ref": "rust-backend/tests/sync_test.rs: main",
      "command_ref": "cd rust-backend && cargo test --test sync_test"
    },
    {
      "id": "acceptance-test-4",
      "evidence_level": 3,
      "test_ref": "test/sync_ui_widget_test.dart: main",
      "command_ref": "flutter test test/sync_ui_widget_test.dart"
    },
    {
      "id": "acceptance-test-5",
      "evidence_level": 3,
      "test_ref": "test/frb_note_repository_test.dart: main",
      "command_ref": "flutter test test/frb_note_repository_test.dart"
    }
  ],
  "dependencies": [],
  "required_evidence_levels": [3, 4],
  "assumptions": [
    {"statement": "现有 iroh Endpoint 连接地址构造和配对设备 IP 缓存可复用于 health-check", "source": "rust-backend/src/sync.rs"},
    {"statement": "FRB 生成代码按项目现有生成流程更新，不手工伪造运行时绑定", "source": "AGENTS.md"},
    {"statement": "当前项目标准 Rust 与 Flutter 测试环境可用", "source": "AGENTS.md"}
  ],
  "unknowns": [
    {"statement": "当前 iroh 版本中最小健康检查帧应复用现有 ALPN 还是增加独立 ALPN，需要执行期以现有协议实现和测试确认", "impact": "protocol implementation choice"},
    {"statement": "数据库迁移在当前 SQLite 初始化路径中的最佳兼容写法，需要执行期验证旧库读取", "impact": "persistence compatibility"}
  ]
}
```

## 任务身份

- 项目：CardMind
- 领域或阶段：设备管理与同步可用性
- 任务类型：`vertical-feature`
- 用户结果或系统能力：用户可在设备页逐台测试已配对设备的当前连接能力，并区分最近可连接与最近同步
- 执行 worktree 约定：`<仓库根目录>/.worktrees/device-connectivity-check`
- 状态：未开始

## 依赖与范围

### 前置条件

- `goal.md` 与 `docs/goal.md` 已记录并确认产品决策
- 现有设备页、FRB repository、Rust SyncService 和 paired_devices 投影可用
- 执行前须完成 pipeline runtime preflight

### 允许修改

- 设备页、Dart repository 接口与实现
- Rust API、同步协议/连接检查、SQLite 投影与迁移
- FRB 生成代码及其源接口（按项目生成流程）
- 对应 Rust/Flutter 测试
- 本任务的 pipeline 证据

### 明确不改

- 不修改配对凭证的产品流程
- 不修改笔记 CRDT 数据格式
- 不引入持续后台在线监控
- 不实现批量设备测试
- 不把检查延迟或检查结果持久化

## 事实、假设与待决

### 已确认事实

- `lib/pages/devices_page.dart` 当前每 2 秒刷新 paired_devices，并以 `last_seen` 判定在线。
- `rust-backend/src/sync.rs` 已有 iroh 连接、push、接收器和 `last_seen` 更新路径。
- `rust-backend/src/store.rs` 当前 `PairedDeviceRow` 只有 `last_seen` 和 `paired_at`，`paired_devices` 尚无 `last_sync_at`。
- `rust-backend/src/api.rs` 已暴露设备列表、push 和同步相关 FRB API。
- 现有项目已有 Rust 连接测试和 Flutter 设备页测试基础设施。

### 未验证事实

- 轻量 health-check 的具体帧格式、ALPN 复用方式和对端兼容处理尚未实现验证。
- 旧数据库迁移和 FRB 自动生成命令尚未在本任务执行期验证。
- Windows/Android 双实例真实 UI 链路尚未验证。

### 禁止猜测

- 不得用全量 push 代替 health-check。
- 不得把连接失败解释成休眠、关机或设备故障。
- 不得把主动检查时间误当最近同步时间。

## 设计与行为契约

[触发] 用户点击某台设备的“测试连接”
→ [处理] Flutter 调用 FRB health-check；Rust 使用配对身份和现有地址策略建立有界 iroh 连接并等待 ACK
→ [状态] 成功更新 `last_seen`；实际笔记同步成功更新 `last_seen` 与 `last_sync_at`；临时检查结果仅存设备页内存
→ [可见结果] 当前设备显示 loading、连接可用/暂不可连接及本次延迟；列表分别显示最近可连接和最近同步

- 同一设备检查期间按钮禁用，其他设备不受影响。
- 失败不更新 `last_seen`，不发送笔记内容，不触发同步。
- 后台刷新不得覆盖检查中的临时 UI 状态；页面销毁后不得 setState。
- 连接检查和同步操作必须有界、可失败、可重试，并保持配对关系不变。

## 环境前置

1. `export PATH="/Users/alexc/.cargo/bin:$PATH"`
2. Flutter 测试使用项目现有依赖；Rust 测试从 `rust-backend` 执行。
3. 真实双实例验证需要 Windows + Android 环境；若本轮无法提供，必须在报告中明确证据边界。

## 验收测试

### 验收测试1：轻量连接检查真实直连链路

- 触发：测试中启动两个真实 `SyncService`，对已配对设备执行连接检查。
- 断言：健康检查收到匹配 ACK，返回成功与延迟；未发送笔记快照；成功更新目标 `last_seen`。
- 测试：`rust-backend/tests/connect_test.rs: test_paired_devices_crud`（执行代理需在该测试文件新增精确 health-check 用例并更新任务证据）
- 命令：`cd rust-backend && cargo test --test connect_test`
- 验收模式：协议 / 集成
- 证据等级：4
- 结果要求：真实 iroh 两端链路通过；失败和超时路径有结构化结果并有界。

### 验收测试2：旧库迁移与时间字段语义

- 触发：打开没有 `last_sync_at` 的旧 paired_devices 数据库，并分别执行主动连接成功、笔记同步成功和失败路径。
- 断言：旧库可读取；主动检查成功只更新最近可连接；同步成功额外更新最近同步；失败不更新时间字段。
- 测试：`rust-backend/tests/store_test.rs: main`（执行代理需新增精确迁移/字段测试）
- 命令：`cd rust-backend && cargo test --test store_test`
- 验收模式：持久化 / 集成
- 证据等级：4
- 结果要求：旧库迁移不丢失设备数据；字段读取与重启恢复符合契约。

### 验收测试3：同步语义回归

- 触发：运行现有同步测试集。
- 断言：实际笔记同步继续可用，并在成功时更新两个时间语义；失败不伪造成功时间。
- 测试：`rust-backend/tests/sync_test.rs: main`
- 命令：`cd rust-backend && cargo test --test sync_test`
- 验收模式：协议 / 集成
- 证据等级：4
- 结果要求：现有同步回归全通过，不能用 mock 替代核心链路。

### 验收测试4：设备页按钮与异步状态

- 触发：在 Flutter widget 测试中渲染已配对设备并点击“测试连接”。
- 断言：显示按钮；点击后进入 loading 并阻止重复点击；成功显示延迟；失败显示暂不可连接和重试；不同设备可独立操作；列表显示最近可连接和最近同步。
- 测试：`test/sync_ui_widget_test.dart: main`（执行代理需新增精确 widget 用例）
- 命令：`flutter test test/sync_ui_widget_test.dart`
- 验收模式：组件
- 证据等级：3
- 结果要求：异步状态、语义标签和后台刷新竞态有测试证据。

### 验收测试5：FRB repository 回读

- 触发：通过真实 FRB repository 打开旧库、执行设备查询并重新打开。
- 断言：`last_seen` 与 `last_sync_at` 正确回读；临时检查结果不因重新打开设备页恢复；旧库迁移可读。
- 测试：`test/frb_note_repository_test.dart: main`（执行代理需新增精确 FRB 用例）
- 命令：`flutter test test/frb_note_repository_test.dart`
- 验收模式：集成
- 证据等级：3
- 结果要求：真实 FRB 链路通过，不以手工构造 Dart model 替代。

## 决策点

出现以下情况时，保留 worktree 并报告给主代理，不得静默改变契约：

1. iroh 对端协议要求改变现有兼容契约，且无法保持旧版本兼容。
2. FRB 生成/本机原生库缺失导致无法验证真实链路。
3. 需要持久化主动检查结果或引入批量/持续监控才能满足实现。
4. 真实 Windows + Android 验证环境不可用；应报告未验证，不得伪装通过。

## 过程记录位置

任务锚点、验收台账、执行记录、设计裁决与最终结果写入 `.pipeline/device-connectivity-check/`，不写入本任务单。
