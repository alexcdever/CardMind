## 任务

CardMind 同步网络模块 3（任务 G）：**配对流程**。6 位配对码（10 分钟过期）、配对握手交换设备身份、配对后设备持久化到 paired_devices 表。

背景设计依据（`docs/sync-network.md`）：
- 决策 12：配对码——新设备显示 6 位短码，在已信任设备上输入确认；10 分钟过期；单向输入
- 决策 13：设备页——本机信息、已配对设备列表、解除配对、发起配对（本任务做后端 + repository 层，设备页 UI 在模块 5）
- 决策 8：首次配对自动全量同步（配对成功后新设备拉取全部笔记）

现状（模块 2 已合并）：`SyncService` 有稳定 `device_id()`（device.key 持久化）、`RelayMode::Default`、`push_to_paired_devices`；`NoteStore` 有 `paired_devices` 表 + CRUD 方法。`discovery.rs` 有 mDNS 发现。

## 配对协议设计（设计方定稿，不允许偏离）

**角色**：发起方（新设备，输入码的一方展示码）与确认方（已信任设备，输入码的一方）。

**流程**：

1. **确认方进入"添加设备"**：调 `begin_pairing_accept()` → 生成 6 位数字码（密码学随机，防猜测），记录 (code, created_at)，10 分钟有效。返回码。
2. **发起方看到码**：调 `begin_pairing_connect(code)` → 发起方生成请求，包含：发起方 device_id、发起方设备名、发起方 relay 信息（iroh EndpointAddr 解析信息）。发起方如何到达确认方？**经 relay 中转**：配对请求是小的控制消息，通过 relay 的 gossip/中转机制（研究 iroh 1.x：两个 endpoint 未经 discovery 如何互达——用 relay 中转的小消息通道；或者用 mDNS 发现 + TCP 直连——同网段时）。**实现选择**（executor 研究后选定并在报告中说明）：优先 iroh 官方机制（relay 中转握手），同网段 mDNS 自然加速。
3. **确认方输入码**：调 `confirm_pairing(code, requester_info)` → 校验码有效未过期 → 双方交换 device_id → 双方各自 `upsert_paired_device` → 返回 (peer_id, peer_name)。
4. **首次全量同步**（决策 8）：确认方立即 `push_to_paired_devices` 推送全量快照给新设备（发起方 accept_push + import）。

**简化说明**：iroh 提供 `iroh::discovery` 和 relay 中转能力，但本任务不发明新传输协议——配对码本身通过**用户口头传达**（人在同一物理空间），网络上的握手只需"双方在确认时交换 node_id + 地址信息"。最简实现：确认方展示码时同时启动监听（已有 accept_push）；发起方需要知道确认方地址才能连——**经 mDNS**（同网段，配对场景大概率同网段面对面）或 **relay 地址解析**。如果 executor 研究后确认"经 relay 无需地址即可互连"（iroh 1.x 的 node_id 直接 connect 走 relay），采用该路径并在报告中写明。

**配对码安全**：
- 码 = 6 位数字（100000-999999 随机）
- 过期 10 分钟（以 created_at 判断）
- 校验失败次数：同一码连续错 5 次失效（防暴力猜测）
- 内存态存储即可（重启失效可接受——用户重新发起）

## 主仓库与 worktree

- 主仓库路径: `D:/Projects/CardMind`（当前分支 `codex/knowledge-base`，保持不动）
- worktree 路径: `D:/Projects/CardMind/.worktrees/pairing`（主仓库**内部**，已在 .gitignore）
- worktree 分支: `codex/pairing`（从 `codex/knowledge-base` 创建）
- 若已存在先 remove 清理再建；建完 `git worktree list` 验证；**不得**移动主仓库当前分支

## 改动范围

- `rust-backend/src/sync.rs` — 配对码生成/校验、配对握手、push 触发
- `rust-backend/src/api.rs` — 新 FRB
- `rust-backend/tests/` — 新增配对集成测试
- `lib/bridge/note_repository.dart`、`lib/bridge/frb_note_repository.dart`、`lib/bridge/bridge_helper.dart` — repository 接口 + 实现
- `rust-backend/src/discovery.rs` — 如 mDNS 通道用于配对握手（可选，不强制）

禁止：`lib/pages/`（设备页 UI 模块 5 做）、`docs/`、`prototype/`、`.gitignore`。

## 验收标准（每条 = 一个测试用例，红绿蓝循环）

**Rust 集成测试（rust-backend/tests/pairing_test.rs，新增）**：

1. `test_pairing_code_generation_and_validation` — begin_pairing_accept 返回 6 位数字码；confirm_pairing(正确码) 成功返回 peer 信息；confirm_pairing(错误码) 失败
2. `test_pairing_code_expires` — 码创建后（可注入时间或直接操作状态）超过 10 分钟，confirm 失败
3. `test_pairing_code_brute_force_limit` — 同一码错 5 次后即使输正确码也失败（需重新发起）
4. `test_pairing_persists_both_sides` — 配对成功后确认方 store.list_paired_devices 含发起方 id；发起方（经握手响应）upsert 确认方
5. `test_pairing_triggers_initial_full_sync` — 确认方配对成功后自动推送快照；发起方 import 后笔记可见（同进程两 endpoint，loopback）
6. `test_unpair_removes_device` — remove_paired_device 后 list 消失（复用模块 2 API）

**Flutter repository 测试（test/frb_note_repository_test.dart 扩展或新文件）**：

7. `repository pair flow` — repository 层封装配对 API 调用链正确（fake 或真实 FRB）

**回归验收**：

8. `cd rust-backend && cargo test` 全绿（48 + 新增）
9. `flutter pub get && flutter test` 全绿（53 不回归）
10. `flutter analyze` 无 error
11. `flutter_rust_bridge_codegen generate` 成功
12. `git status` 改动全在范围内

## 需决策点

1. iroh 1.x 无"免地址经 relay 直连"机制，配对握手必须引入地址交换（mDNS/手动输 IP）——停下报告研究结论，给备选方案
2. 同进程测试中两个 endpoint 的 relay 握手不可复现真实网络行为——停下报告
3. 配对码内存态导致 FRB 状态跨调用丢失（FRB 每次调用重建 service）——**重要**：检查 FRB 如何持有 SyncService 状态（现有 svc 参数是每次传入的），若配对码状态需要跨调用保留，设计存储位置（如 store 表或静态/文件），在报告中说明方案。此点允许自行设计但必须在报告中显著说明
