# CardMind 安全扫描发现修复

<!-- Task ID: security-scan-findings-repair -->
<!-- 本任务单冻结后不可修改；执行状态与证据写入 .pipeline/security-scan-findings-repair/。 -->

```pipeline-contract
{
  "schema": 4,
  "task_id": "security-scan-findings-repair",
  "task_type": "repair",
  "project_type": "service",
  "risk": "high",
  "goal": {"path": "docs/goal.md"},
  "allowed_paths": ["rust-backend/src/sync.rs", "rust-backend/src/store.rs", "rust-backend/tests/", "tool/feature_test.dart", "test/", ".pipeline/security-scan-findings-repair/"],
  "forbidden_paths": ["C:/Users/alexc/AppData/Local/Temp/cardmind-security-scan-20261001-0325/", "android/", "windows/", "macos/", "linux/"],
  "non_goals": ["不修改临时扫描证据", "不进行无关协议重构或依赖升级", "不把 b5 空 findings 解释为 Android/Windows 安全通过"],
  "operations": [
    {"id": "inbound-authorization", "kind": "repair", "scope": "配对传输身份授权与入站路由", "resources": ["rust-backend/src/sync.rs", "rust-backend/src/store.rs", "rust-backend/tests/"], "resource_mode": "batch", "acceptance_tests": ["acceptance-unauthorized-peer"]},
    {"id": "pairing-identity-binding", "kind": "repair", "scope": "配对请求/响应身份绑定", "resources": ["rust-backend/src/sync.rs", "rust-backend/tests/"], "resource_mode": "batch", "acceptance_tests": ["acceptance-pairing-identity"]},
    {"id": "bounded-frames", "kind": "repair", "scope": "入站帧与长度字段边界", "resources": ["rust-backend/src/sync.rs", "rust-backend/tests/"], "resource_mode": "batch", "acceptance_tests": ["acceptance-bounded-frames"]},
    {"id": "shell-free-feature-runner", "kind": "repair", "scope": "feature-test 设备参数进程启动", "resources": ["tool/feature_test.dart", "test/"], "resource_mode": "batch", "acceptance_tests": ["acceptance-shell-free-runner"]}
  ],
  "chain": {
    "entry": ["tool/feature_test.dart CLI/environment device input", "iroh incoming connection"],
    "interaction": ["SyncService route_incoming and pairing handshake"],
    "application": ["receiver_handle_incoming and pairing confirmation"],
    "domain": ["paired_devices allowlist and authenticated EndpointId"],
    "persistence": ["NoteStore paired_devices and notes projection"],
    "readback": ["NoteStore list_paired_devices/list_notes and SyncService note state"],
    "recovery": ["receiver error isolation, bounded rejection, and existing pairing/sync retry paths"]
  },
  "acceptance_tests": [
    {"id": "acceptance-unauthorized-peer", "evidence_level": 3, "test_ref": "rust-backend/tests/security_sync_test.rs: unauthorized_peer_cannot_import_or_update_presence", "command_ref": "cd rust-backend && cargo test --test security_sync_test unauthorized_peer_cannot_import_or_update_presence"},
    {"id": "acceptance-pairing-identity", "evidence_level": 3, "test_ref": "rust-backend/tests/security_sync_test.rs: pairing_identity_must_match_transport", "command_ref": "cd rust-backend && cargo test --test security_sync_test pairing_identity_must_match_transport"},
    {"id": "acceptance-bounded-frames", "evidence_level": 3, "test_ref": "rust-backend/tests/security_sync_test.rs: oversized_inbound_frames_are_rejected", "command_ref": "cd rust-backend && cargo test --test security_sync_test oversized_inbound_frames_are_rejected"},
    {"id": "acceptance-shell-free-runner", "evidence_level": 3, "test_ref": "test/feature_test_security_test.dart: rejects_shell_syntax_and_uses_non_shell_process", "command_ref": "flutter test test/feature_test_security_test.dart"},
    {"id": "acceptance-existing-sync", "evidence_level": 3, "test_ref": "rust-backend/tests/receiver_continuous_test.rs: receiver_continuously_accepts_push", "command_ref": "cd rust-backend && cargo test --test receiver_continuous_test receiver_continuously_accepts_push"},
    {"id": "acceptance-existing-pairing", "evidence_level": 3, "test_ref": "rust-backend/tests/pairing_test.rs: test_pairing_persists_both_sides", "command_ref": "cd rust-backend && cargo test --test pairing_test test_pairing_persists_both_sides"}
  ],
  "dependencies": [],
  "required_evidence_levels": [3],
  "assumptions": ["iroh EndpointId remote_id is the authenticated transport identity and is available on both inbound and outbound connection objects", "Existing pairing protocol remains compatible when claimed identity is required to equal transport identity"],
  "unknowns": ["The scanner b5 archive schema error may require an external scanner/plugin update before Android/Windows can be rescanned", "The Windows Flutter SDK may expose a non-shell executable path different from flutter.bat"]
}
```

## 任务身份

- 项目：CardMind
- 领域或阶段：安全扫描发现修复
- 任务类型：`repair`
- 用户结果：网络接收、配对身份和测试运行器不再满足扫描报告中的四条漏洞利用路径。
- 执行 worktree：`D:/Projects/CardMind/.worktrees/security-scan-findings-repair`
- 状态：由 lifecycle API/CLI 管理

## 依赖与范围

### 前置条件

- 安全扫描聚合证据：`C:/Users/alexc/AppData/Local/Temp/cardmind-security-scan-20261001-0325/aggregate-findings.json`
- 扫描基线：`87b42ce6be45c431cea55b545fa08f17832f3cd5`
- `rust-backend` 现有 pairing、sync、receiver 测试和 `tool/feature_test.dart` 当前实现。

### 允许修改

- Rust 入站路由、配对身份绑定、边界解析及其 Rust 集成测试。
- `tool/feature_test.dart` 及其 Dart 安全测试。
- 本任务 `.pipeline/security-scan-findings-repair/` 证据。

### 明确不改

- 临时目录中的扫描日志、aggregate 文件和 scanner 配置。
- Android、Windows、macOS、Linux 平台产品代码。
- 与四条扫描发现无关的业务协议、依赖和 UI。

## 事实、假设与待决

### 已确认事实

- `rust-backend/src/sync.rs` 当前在 push、配对请求、设备名和配对响应读取路径使用 `read_to_end(usize::MAX)`。
- 接收 push 后当前直接执行 `import_core_all`、SQLite 投影和 `update_last_seen`，未先查询 paired_devices。
- `PendingPairing` 当前仅保留 request 和 connection；确认逻辑持久化请求声明的 device_id。
- `tool/feature_test.dart` 当前把 device 参数传给 `Process.start(..., runInShell: true)`。
- `NoteStore::update_paired_device_name` 已避免名字帧插入新设备，但 health/push 路径仍需传输身份 allowlist。

### 未验证事实

- b5 scanner schema 错误能否在本机通过升级/重跑参数自愈。
- 当前所有合法快照的最大尺寸及 Windows Flutter 非 shell 启动入口。

### 禁止猜测

- 不因旧客户端兼容性猜测而放宽 transport identity 校验。
- 不用扩大内存上限或恢复 shell 解释来绕过测试失败。
- 不以空 findings 或命令退出码单独证明扫描覆盖完整。

## 设计与行为契约

[入站连接/测试命令] → [transport identity 校验、配对 allowlist、边界解析、argv 直传] → [仅合法配对 peer 导入/投影；拒绝超限或恶意设备参数] → [笔记、presence 和配对记录保持完整性，未知 peer 不产生状态变化]

- 认证传输身份优先于请求/响应中声明的身份。
- 授权发生在读取大 payload、CRDT 导入、SQLite 投影和 last_seen 更新之前。
- 读取、字段、数量和快照解析均有有限上限；失败隔离当前连接，不终止接收器。
- 合法已配对同步、配对、设备名传播和 feature-test 正常路径保持可用。

## 环境前置

1. Rust toolchain、Cargo、SQLite bundled build 可用。
2. Flutter/Dart 工具链可用时运行 Dart/Flutter 验收；不可用时记录环境阻塞，不改契约。
3. Android/Windows b5 补扫需要 scanner 能接受现有 coverage schema；失败须保留外部阻塞证据。

## 验收测试

### 验收测试1：未配对 peer 授权

- 触发：未知 iroh EndpointId 发送 push、health 或设备名帧。
- 断言：连接被拒绝/忽略；不导入 CRDT，不写 notes/links，不更新或创建 paired_devices/last_seen/name。
- 测试：`rust-backend/tests/security_sync_test.rs: unauthorized_peer_cannot_import_or_update_presence`
- 命令：`cd rust-backend && cargo test --test security_sync_test unauthorized_peer_cannot_import_or_update_presence`
- 模式：协议/集成
- 证据等级：3

### 验收测试2：配对身份绑定

- 触发：请求或响应声明的 device_id 与 iroh authenticated remote_id 不一致。
- 断言：握手失败，pending 不保存伪造身份，paired_devices 不落入伪造 id；合法配对仍成功。
- 测试：`rust-backend/tests/security_sync_test.rs: pairing_identity_must_match_transport`
- 命令：`cd rust-backend && cargo test --test security_sync_test pairing_identity_must_match_transport`
- 模式：协议/集成
- 证据等级：3

### 验收测试3：有界入站帧

- 触发：push、配对、设备名帧及 length/count 字段超过限制或声明超大值。
- 断言：在无界读取/预分配前拒绝，接收器可继续服务后续合法帧。
- 测试：`rust-backend/tests/security_sync_test.rs: oversized_inbound_frames_are_rejected`
- 命令：`cd rust-backend && cargo test --test security_sync_test oversized_inbound_frames_are_rejected`
- 模式：协议/单元/集成
- 证据等级：3

### 验收测试4：无 shell 的 feature runner

- 触发：合法 serial、空白/控制字符和 shell 元字符设备参数进入工具。
- 断言：合法参数作为独立 argv 运行；恶意参数在启动前拒绝；`Process.start` 使用 `runInShell: false`。
- 测试：`test/feature_test_security_test.dart: rejects_shell_syntax_and_uses_non_shell_process`
- 命令：`flutter test test/feature_test_security_test.dart`
- 模式：单元/进程
- 证据等级：3

### 验收测试5：合法 receiver 回归

- 触发：已配对 peer 在持续接收器运行期间发送合法 push。
- 断言：push 成功、CRDT 和读模型同步、接收器不阻塞编辑。
- 测试：`rust-backend/tests/receiver_continuous_test.rs: receiver_continuously_accepts_push`
- 命令：`cd rust-backend && cargo test --test receiver_continuous_test receiver_continuously_accepts_push`
- 模式：集成
- 证据等级：3

### 验收测试6：合法 pairing 回归

- 触发：两个真实 SyncService 执行配对握手。
- 断言：双方设备记录、身份和 last_seen 正常；首次同步仍可用。
- 测试：`rust-backend/tests/pairing_test.rs: test_pairing_persists_both_sides`
- 命令：`cd rust-backend && cargo test --test pairing_test test_pairing_persists_both_sides`
- 模式：集成
- 证据等级：3

## 决策点

1. 如果合法旧客户端发送的 claimed identity 与 transport identity 不一致，停止并请求协议兼容裁决。
2. 如果 Windows 环境没有可用的非 shell Flutter 启动入口，保留 worktree 并报告，不恢复 `runInShell: true`。
3. 如果真实合法快照超过拟定上限，依据 fixture/业务证据调整上限并记录，不静默截断。

<!-- pipeline-contract: security-scan-findings-repair -->
