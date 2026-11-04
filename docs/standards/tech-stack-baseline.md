# Tech Stack Baseline Standard

## 1. 目标与范围

- 本文档定义 CardMind 的技术栈基线与依赖治理规则，适用于 NSH/TSX（nsh-app）、Rust、构建与测试链路。
- 本文档是跨功能、长期复用的工程标准；功能行为本身以 `docs/adr/` 与 `docs/product.md` 为准。

## 2. 技术栈基线

### 2.1 语言与运行时

- NSH/TSX 前端：nsh `0.1.1`（`nsh-app/nsh.json`；UI 为 TSX + tiptap，`nsh-app/package.json`）。
- Dart 工具链（仅 `tool/` 门禁/lint，不再是产品 UI）：Dart SDK `^3.12.2` 起可用；产品侧无 `pubspec.yaml`（4.6 已删除）。
- Rust：Edition `2021`，以 `rust-backend/Cargo.toml` 为准。

### 2.2 跨语言桥接

- 前端与 Rust 的边界由 NSH 运行时承载（nsh-app 的 Rust crate 直接嵌入业务后端，`rust = "."` 指 `nsh-app/Cargo.toml` → `rust-backend`）。
- 旧 Flutter Rust Bridge 桥（`flutter_rust_bridge` + `lib/src/rust/` 生成代码 + `flutter_rust_bridge.yaml`）已随 4.6 整删。

### 2.3 数据与同步内核

- 本地数据与状态内核：`loro`
- 本地读模型：`rusqlite`（`bundled`）
- 网络同步：`iroh`

### 2.4 构建与验证链路

- 前端测试：`cd nsh-app && npx tsx --test "*_test.ts" "web/src/*_test.ts"`（node --test，经 tsx 加载 TS）
- 前端打包：`cd nsh-app && npm run build`（需 `NSH_SOURCE` 指向 nsh 源码 checkout）
- Rust 测试：`cd rust-backend && cargo test --all-features --jobs 1`
- Rust 静态检查：`cd rust-backend && cargo clippy --all-targets --all-features --workspace -- -D warnings`
- 门禁：`dart run tool/git_gate.dart plan --staged` / `full`（pre-commit 快速路由；pre-push/full 跑 docs lint → rust clippy → rust test → build-lib → tsx test）

### 2.5 平台支持

- 产品目标平台：移动端（Android + iOS，覆盖手机与平板）与桌面端（Linux + Windows + macOS，覆盖台式机与笔记本）。
- 仓库现状：Flutter runner 工程 `android/`、`linux/`、`macos/`、`windows/` 已删除，仓库不含任何平台工程目录；iOS 属目标平台，工程目录亦未建立（见 `AGENTS.md` 当前状态）。平台产物统一由 `nsh package . --target <platform>` 产出。
- 构建链路入口为 `nsh-app/build-nsh.mjs`（`npm run build`），走 0.3.0 CLI 的 `nsh build . -o out`，不需要 `NSH_SOURCE`；旧 tool/build.dart（`app`/`lib`/`run` 子命令，Flutter 构建链）已随 4.6 删除。
- host runtime 动态库由门禁 `rust:build-lib` 步骤产出（`cargo build --release`）并同步到运行态路径（`tool/src/git_gate/host_build.dart` 的平台规格：Windows `cardmind_backend.dll`、macOS `libcardmind_backend.dylib`、Linux `libcardmind_backend.so`）。

## 3. 核心三方依赖

### 3.1 前端（nsh-app，npm）

| 依赖 | 版本 | 角色 |
| --- | --- | --- |
| @tiptap/core / starter-kit / 各 extension | ^3.32.0 | 编辑器内核 |
| tsx（dev） | ^4.19.2 | TSX 测试加载器（node --test） |
| typescript（dev） | ^5.6.3 | TSX 类型 |
| esbuild（dev） | ^0.28.2 | web 编辑器 bundle |
| jsdom（dev） | ^30.1.3 | 测试 DOM |

### 3.2 Rust

| 依赖 | 版本 | 角色 |
| --- | --- | --- |
| flutter_rust_bridge | =2.12.0（锁定 2.12.0） | Rust 侧 FRB 绑定（代码生成产物 `frb_generated.rs` 保留在 rust-backend；Flutter 侧消费方已删，待后续清理或替换为 NSH 边界） |
| loro | 1（锁定 1.13.6） | CRDT 数据内核 |
| iroh | 1（锁定 1.0.2） | P2P 网络同步；dev-dependency 启用 `test-utils`，用本地 relay 服务器做离线验证 |
| tokio | 1（锁定 1.52.3） | 异步运行时（`features = ["full"]`） |
| anyhow | 1（锁定 1.0.103） | 错误传播与上下文 |
| atomic-write-file | 0.2（锁定 0.2.3） | 原子写文件 |
| mdns-sd | 0.20（锁定 0.20.1） | mDNS 设备发现 |
| rusqlite | 0.31（锁定 0.31.0） | 本地 SQLite 读模型（`bundled`） |
| chrono | 0.4（锁定 0.4.45） | 时间戳（`serde` 特性） |
| uuid | 1（锁定 1.23.4） | UUID（`v7`、`serde` 特性） |
| rand | 0.8（锁定 0.8.6） | 配对码生成的密码学随机 |
| tracing | 0.1（锁定 0.1.44） | 结构化调试日志 |
| base64 | 0.22（锁定 0.22.1） | URL-safe base64 编解码 |
| libc | 0.2（锁定 0.2.186） | 主机名探测（`gethostname`） |

说明：

- 上表只列 `rust-backend/Cargo.toml` 的直接依赖；“锁定”版本取自 `rust-backend/Cargo.lock`。
- `serde`、`thiserror`、`postcard` 等仅作为传递依赖进入 `Cargo.lock`，不是本仓库的直接依赖，因此不在此登记。

## 4. 版本治理与变更规则

- 依赖升级采用最小必要原则，避免无目的升级。
- FRB 升级必须双端同步并完成端到端编译验证。
- 新增或替换核心技术栈前，必须先形成设计记录（长期决策写入 `docs/adr/`）并在任务交付中说明，再更新本文档。
- 任何会改变构建、测试、发布门禁的技术栈变更，都需同步更新对应标准文档。

## 5. 与其他规范的关系

- 正式行为变更的判定与更新要求，遵循 `docs/standards/spec-lifecycle.md`
- 开发与验证循环遵循 `docs/standards/tdd.md`
- 测试组织与边界优先级遵循 `docs/standards/testing.md`
- 提交与协作流程遵循 `docs/standards/git-and-pr.md`
