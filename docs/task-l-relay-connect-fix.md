## 任务

CardMind 修复（任务 L）：**跨网段连接缺陷——EndpointAddr 未附加 relay URL**。实机验证发现：自定义 relay 模式下凭 node_id 连接失败（"No addressing information available"），因为地址构建缺 relay URL，iroh 走了 n0 DNS TXT 地址解析（中国大陆不可达）。

背景（Hermes 实机验证，2026-08-16 凌晨）：`live_relay_test` 走真实 dogcloud relay（relay.alexc.cn:9443）配对失败：
```
connect to confirmer
Caused by:
    0: No addressing information available
    2: All address lookup services failed
       Service 'dns' failed: Failed to resolve TXT record (x7)
```
根因：`rust-backend/src/sync.rs` 两处用 `EndpointAddr::new(node_id)`（612 行配对连接、1015 行 push），该构造不带 relay URL → iroh 的地址发现只走 DNS TXT（n0 公共 DNS，GFW 下不可达）。iroh-base 1.0.2 提供 `EndpointAddr::with_relay_url(RelayUrl)`：附加 relay URL 后，连接通过 relay 服务器的地址映射找到对端，不依赖 DNS。

## 主仓库与 worktree

- 主仓库路径: `D:/Projects/CardMind`（当前分支 `codex/knowledge-base`，保持不动）
- worktree 路径: `D:/Projects/CardMind/.worktrees/relay-connect-fix`（主仓库**内部**，已在 .gitignore）
- worktree 分支: `codex/relay-connect-fix`（从 `codex/knowledge-base` 创建）
- 若已存在先 remove 清理再建；建完 `git worktree list` 验证；**不得**移动主仓库当前分支

## 改动范围

- `rust-backend/src/sync.rs` — 两处地址构建附加 relay URL
- `rust-backend/tests/live_relay_test.rs` — 已存在（主仓库有初版，测试挂死问题见下，一并修）
- `rust-backend/tests/relay_config_test.rs` 或新测试文件 — 地址构建单元测试

禁止：`lib/`、`docs/`、`prototype/`、`.gitignore`、`lib/pages/`。

## 设计要求

### 1. sync.rs 地址构建修复（两处）

```rust
// 现有：
let addr = if target.ips.is_empty() {
    EndpointAddr::new(node_id)          // ← 缺 relay URL
} else { ... };

// 改为：
let addr = if target.ips.is_empty() {
    let mut a = EndpointAddr::new(node_id);
    if let Some(u) = self.relay_mode.relay_map().urls().first() {
        a = a.with_relay_url(u.clone());
    }
    a
} else { ... };  // ips 非空路径不变
```
- 612 行（`begin_pairing_connect`）与 1015 行（push 路径，查上下文确认同模式）两处
- **无 relay 配置时行为不变**（urls 空 → 不附加 → 维持现有 DNS 解析路径，局域网 mDNS/直连场景不受影响）
- `relay_map()` 在 Disabled 模式下返回空 map——验证 `urls()` 空时安全（不 panic）

### 2. live_relay_test.rs 测试挂死修复

现有测试的两个问题：
1. **confirmer 侧 accept 无限等待**：发起方超时/失败后，`accept_pairing_request` 阻塞（其内部短窗口 accept 循环无全局超时）→ Runtime drop 等待 task 完成 → 测试进程挂死 2.5 小时。修复：测试内用 `tokio::time::timeout` 包裹 confirmer 侧整个 accept+confirm 流程（120s），超时 panic 输出诊断
2. 测试跑完后清理临时目录（`remove_dir_all`）

### 3. 单元测试（不依赖公网）

`relay_config_test.rs` 增补：
- `test_endpoint_addr_carries_relay_url` — 有 relay.txt 的 service 调内部地址构建（或暴露的 helper）时，空 ips 的 EndpointAddr 含 relay URL；无 relay.txt 时不含
- 若地址构建逻辑不便直接断言，抽取一个小 helper 函数（如 `fn build_connect_addr(&self, node_id, ips) -> EndpointAddr`）供测试

## 验收标准（每条 = 一个测试用例，红绿蓝循环）

**缺陷回归（红阶段必须复现）**：

0. `live_relay_test` 修复前实机跑一次：断言当前代码经 dogcloud relay 连接失败（"No addressing information available"），附失败输出为证；修复后转绿

**单元测试**：

1. `test_endpoint_addr_carries_relay_url` — relay.txt 存在时构建地址含 relay URL
2. `test_endpoint_addr_no_relay_stays_dns_only` — 无 relay.txt 时地址不含 relay URL（行为不变）

**实机测试（需公网，`#[ignore]` + 手动跑）**：

3. `live_pairing_and_sync_over_dogcloud_relay` — 两个持久化 service（数据目录各带 relay.txt = https://relay.alexc.cn:9443）经真实 relay 完成：配对 → 双方持久化对端 → 首次全量同步（发起方看到 n1 笔记）→ 90s 超时保护

**回归验收**：

4. `cd rust-backend && cargo test` 全绿（68 + 新增；live 测试带 ignore 不参与默认跑）
5. `cd rust-backend && cargo test --test live_relay_test -- --ignored --nocapture` **实机通过**（executor 必须在 worktree 内实跑这一条并附真实输出）
6. `flutter test` 全绿（73 不回归，无 Flutter 改动应为纯回归确认）
7. `flutter analyze` 无 error
8. `git status` 改动全在范围内

## 需决策点

1. `relay_map().urls()` 在 RelayMode::Custom 下返回空（构造方式问题）——停下报告 API 形态
2. 实机测试仍失败且错误变化——附完整错误链停下报告，不要 mock 绕过
3. 测试挂死根因与"accept 循环无全局超时"分析不符——停下报告实际根因
