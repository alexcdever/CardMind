## 任务

CardMind 同步网络模块 2（任务 F）：**连接层**。启用 iroh relay（跨网段能力）、设备身份持久化（SecretKey 稳定，device_id 不再每次启动变化）、配对设备表、跨网段连接辅助。

背景设计依据（`docs/sync-network.md`）：
- 决策 2：全对等 mesh，无主设备
- 决策 3：启用 iroh relay 模式（官方公共 relay 起步，relay 不存储不读取数据）
- 决策 5：按需拨号（推送时拨号连接，无常驻长连接）
- 决策 6：移动端仅 WiFi 自动同步（本任务不涉及，模块 4 做）

现状：`rust-backend/src/sync.rs` 已有 iroh endpoint（`RelayMode::Disabled`）、`push_to_peer(peer_id, peer_ips)` / `accept_push()` 手动推拉；`device_id()` 返回随机生成的 endpoint id（每次启动变化）。`discovery.rs` 有 mDNS 发现。

## 主仓库与 worktree

- 主仓库路径: `D:/Projects/CardMind`（当前分支 `codex/knowledge-base`，保持不动）
- worktree 路径: `D:/Projects/CardMind/.worktrees/connect`（主仓库**内部**，已在 .gitignore）
- worktree 分支: `codex/connect`（从 `codex/knowledge-base` 创建）
- 若已存在先 remove 清理再建；建完 `git worktree list` 验证；**不得**移动主仓库当前分支

## 改动范围

- `rust-backend/Cargo.toml` — 如 iroh relay 特性需调整 feature（先研究现状，无必要则不动）
- `rust-backend/src/sync.rs` — relay 启用、SecretKey 持久化、新连接方法
- `rust-backend/src/store.rs` — 配对设备表（paired_devices）
- `rust-backend/src/api.rs` — 新 FRB
- `rust-backend/tests/sync_test.rs` 或新增 `rust-backend/tests/connect_test.rs` — 集成测试
- `lib/bridge/*` — repository 接口（如需）

禁止：`lib/pages/`、`lib/src/rust/`（仅 codegen 产物）、`docs/`、`prototype/`、`.gitignore`。

## 设计要求

### 1. Relay 启用（sync.rs）

- `RelayMode::Disabled` → iroh 官方公共 relay（研究 iroh 0.98 API：`Endpoint::builder()` 默认 relay 配置或显式 relay URL）。研究 `~/.cargo/registry` 里 iroh 0.98.1 源码确认正确用法
- 保持直连优先：同网段直连，跨网段经 relay 打洞/中转（iroh 默认行为）

### 2. 设备身份持久化（sync.rs）

- `SyncService::new()` 目前每次生成随机 SecretKey。改为：数据目录下 `device.key` 文件（16/32 字节 hex 或 SecretKey 序列化），存在则加载，不存在则生成并写入
- 文件权限/位置：数据目录由 `new_persistent(path)` 的 path 父目录决定；内存版 `new()` 保持随机（测试用）
- `device_id()` 因此稳定。FRB 已有 `get_device_id`（如无则加）
- 注意：`new_persistent` 已有持久化路径参数，`new()` 无路径——设计一个 `load_or_create_secret_key(dir: Option<&Path>)` 辅助函数，`new()` 传 None 用随机

### 3. 配对设备表（store.rs）

```sql
CREATE TABLE IF NOT EXISTS paired_devices (
  peer_id TEXT PRIMARY KEY,     -- 对端 iroh node id
  name TEXT,                    -- 对端设备名
  last_seen TEXT,               -- ISO8601，最后成功连接/同步时间
  paired_at TEXT                -- ISO8601，配对时间
);
```

- store 方法：`list_paired_devices()`、`upsert_paired_device(peer_id, name)`、`update_last_seen(peer_id)`、`remove_paired_device(peer_id)`

### 4. 跨网段连接辅助（sync.rs）

- 现有 `push_to_peer(peer_id, peer_ips)` 需要调用方提供 IP（同网段 mDNS 发现）。新增/改进：
  - `push_to_paired_devices(&self, devices: &[(String, Option<Vec<String>>)])` —— 逐个推送，单个失败不中断整体（返回每设备结果），设备地址缺省时经 relay 尝试连接（研究 iroh 0.98：`connect_by_node_id` / relay 地址解析的正确调用方式）
  - `sync_notes_to_store` 模式对齐：推送用 export_all 快照（含墓碑），接收端 import_all（已存在）
- 连接超时：单设备连接超时 10 秒，超时记为失败继续下一个

### 5. FRB API（api.rs）

- `list_paired_devices(store)` → Vec<PairedDeviceRow>
- `get_device_id(svc)` → String（已有则不动）
- `push_to_devices(svc, devices)` → 每设备 (peer_id, ok/err message)
- `remove_paired_device(store, peer_id)`

## 验收标准（每条 = 一个测试用例，红绿蓝循环）

**Rust 集成测试（rust-backend/tests/connect_test.rs，新增）**：

1. `test_device_identity_persists` — new_persistent(带路径) 创建服务 A，记 device_id；drop 后重新 new_persistent 同一路径，断言 device_id 相同；`device.key` 文件存在
2. `test_memory_service_random_identity` — 两次 new() 的 device_id 不同（内存版保持随机）
3. `test_paired_devices_crud` — upsert 两台设备 → list 含两台；update_last_seen 后排序/字段正确；remove 后 list 消失
4. `test_push_receive_roundtrip_relay_or_direct` — 两个 endpoint（同进程）互推快照：A 创建笔记并 push_to_peer(B)（B 提供实际地址），B accept_push 收到数据 import 后笔记可见。**网络测试**：本机 loopback，防火墙已关，可直接跑
5. `test_push_multi_device_partial_failure` — 推 3 台（1 台假地址），断言真设备成功、假设备失败、其余不受影响
6. `test_relay_mode_enabled` — 断言 endpoint relay_mode != Disabled（读 builder 配置或公开的 getter；若无 getter，用行为测试：两个跨网段模拟 endpoint 经 relay 连接——若环境无法访问公共 relay，改为断言配置构造正确并报告）

**回归验收**：

7. `cd rust-backend && cargo test` 全绿
8. `flutter pub get && flutter test` 全绿（53 不回归）
9. `flutter analyze` 无 error
10. `flutter_rust_bridge_codegen generate` 成功
11. `git status` 改动全在范围内

## 需决策点

1. iroh 0.98.1 的 relay 默认配置在无网/断网环境下 Endpoint 创建失败或极慢——停下报告现象
2. 公共 relay 在本机网络（GFW）不可达，测试 6 无法实机通过——停下报告（不要 mock 掉断言后悄悄通过）
3. SecretKey 持久化需要改动 envelope 或 FRB 桥接初始化签名——停下报告
