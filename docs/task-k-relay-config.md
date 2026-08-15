## 任务

CardMind relay 可配置化（任务 K）：relay 从硬编码 `RelayMode::Default`（官方公共 relay）改为**可选配置项**——默认仅局域网（无 relay），配置了 relay URL 才启用。

背景：实机测试验证官方公共 relay（relay.n0.iroh.link）在中国大陆不可达（GFW 墙，Clash 规则亦判直连）。用户决策（2026-08-15）：relay 是**可选项**，默认零配置仅局域网；跨网段需求的客户自行部署 relay 并填写配置。测试用自建 relay 已部署：`https://relay.alexc.cn:9443`（香港 dogcloud，iroh-relay v1.0.3，HTTPS 9443 + QUIC 7942，仅测试不对外）。

现状：`rust-backend/src/sync.rs` 的 `SyncService::new()` / `new_persistent()` 用 `RelayMode::Default`；任务 F 加了 `relay_mode()` getter 和 `relay_mode` 字段。

## 主仓库与 worktree

- 主仓库路径: `D:/Projects/CardMind`（当前分支 `codex/knowledge-base`，保持不动）
- worktree 路径: `D:/Projects/CardMind/.worktrees/relay-config`（主仓库**内部**，已在 .gitignore）
- worktree 分支: `codex/relay-config`（从 `codex/knowledge-base` 创建）
- 若已存在先 remove 清理再建；建完 `git worktree list` 验证；**不得**移动主仓库当前分支

## 改动范围

- `rust-backend/src/sync.rs` — RelayMode 配置化
- `rust-backend/src/api.rs` — FRB API
- `rust-backend/tests/` — 测试调整 + 新增
- `lib/bridge/bridge_helper.dart` — 初始化传参
- `lib/bridge/note_repository.dart` / `frb_note_repository.dart` — 如需
- `test/` — 测试

禁止：`docs/`、`prototype/`、`.gitignore`、`lib/pages/`（本任务不做 UI 设置页，relay 配置先走配置文件）。

## 设计要求

### 1. 配置来源：数据目录下的 `relay.txt`（极简）

- 数据目录（`new_persistent` 的 path 父目录）下的 `relay.txt`：内容为 relay URL 字符串（如 `https://relay.alexc.cn:9443`），单行，无文件 = 不启用 relay
- 理由：无需新配置文件格式/序列化依赖；客户自行部署时只需在数据目录放一个文本文件。后续 UI 设置页可覆盖此文件
- 注意：**内存版 `new()` 保持 `RelayMode::Disabled`**（测试隔离，不读文件）

### 2. SyncService 构造

- `new_persistent(path)` 时读取 `<数据目录>/relay.txt`：
  - 无文件/空内容 → `RelayMode::Disabled`
  - 有 URL → `RelayMode::Custom(url.parse::<RelayUrl>()?)`，解析失败 → **报错而非静默忽略**（配置错误要显式）
- `relay_mode()` getter 保留（任务 F 的测试用）
- 构造失败语义：relay URL 无效时 `new_persistent` 返回 Err（fail fast）

### 3. FRB

- 不加新 API（Flutter 侧无需感知）；如 Flutter 侧已有 relay 相关调用需适配，按需小改
- 若 `new_persistent` 签名不变，FRB 无需重新 codegen（验收时验证幂等）

### 4. 测试环境 relay.txt 隔离

- 现有测试用临时目录，天然隔离；**主仓库数据目录（用户数据）不生成 relay.txt**（测试用配置文件由测试自己写临时目录）

## 验收标准（每条 = 一个测试用例，红绿蓝循环）

**Rust 集成测试（rust-backend/tests/relay_config_test.rs，新增）**：

1. `test_no_relay_file_disables_relay` — 临时目录无 relay.txt → new_persistent 后 relay_mode() == Disabled
2. `test_relay_file_enables_custom_mode` — 临时目录写入 `https://relay.alexc.cn:9443` → new_persistent 后 relay_mode() 含该 URL（Custom）
3. `test_invalid_relay_url_fails_fast` — 写入 `not-a-url` → new_persistent 返回 Err
4. `test_empty_relay_file_disables` — 空文件 → Disabled
5. `test_memory_service_never_reads_relay_file` — 内存版 new() 保持 Disabled（隔离性）

**回归验收**：

6. `cd rust-backend && cargo test` 全绿（63 + 新增）
7. `flutter pub get && flutter test` 全绿（73 不回归）
8. `flutter analyze` 无 error
9. `flutter_rust_bridge_codegen generate` 幂等（无 diff 或有新 API 出现）
10. `git status` 改动全在范围内

## 需决策点

1. `RelayMode::Custom` 的构造在 iroh 1.0.2 需要更多参数（如 https_only 等）——停下报告 API 形态
2. 现有任务 F 的 `test_relay_cross_network_connect` 依赖 Default relay 模式——若改为 Disabled 后该测试失败，停下报告（不要改成 mock 绕过）
3. relay.txt 位置/命名如与现有数据文件冲突——停下报告
