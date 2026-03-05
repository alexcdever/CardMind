# Tech Stack Baseline Standard

## 1. 目标与范围

- 本文档定义 CardMind 的技术栈基线与依赖治理规则，适用于 Flutter、Rust、FRB、构建与测试链路。
- 本文档是跨功能、长期复用的工程标准；功能行为本身以 `docs/specs/` 为准。

## 2. 技术栈基线（强约束）

### 2.1 语言与运行时

- Flutter/Dart：Dart SDK `^3.11.0`（以 `pubspec.yaml` 为准）。
- Rust：Edition `2024`（以 `rust/Cargo.toml` 为准）。

### 2.2 跨语言桥接

- Flutter Rust Bridge（FRB）为唯一 Flutter-Rust FFI 通道。
- `flutter_rust_bridge` 与 Rust 侧 `flutter_rust_bridge` 必须同版本锁步维护（当前 `2.11.1`）。
- FRB 配置源为 `flutter_rust_bridge.yaml`，修改后必须验证生成产物可编译。

### 2.3 数据与同步内核

- 本地数据与状态内核：`loro`。
- 本地读模型：`rusqlite`（`bundled`）。
- 网络同步：`iroh`。

### 2.4 构建与验证链路

- 应用构建：`dart run tool/build.dart app`。
- 库构建：`dart run tool/build.dart lib`。
- Flutter 测试：`flutter test`。
- Rust 测试：`cargo test`。
- 静态检查：`flutter analyze`。

### 2.5 平台支持

- 产品交付形态为移动端与桌面端双端：移动端（`android`、`ios`）与桌面端（`macos`、`linux`、`windows`）。
- `tool/build.dart app` 当前封装的是桌面可执行平台构建链路（`macos`、`linux`、`windows`）。
- 移动端构建与运行采用 Flutter 原生命令链路（如 `flutter run -d <device>`、`flutter build apk`、`flutter build ios`）。
- `tool/build.dart` 的默认平台解析逻辑应保持与主机可执行平台一致。

## 3. 扩展依赖清单（核心三方库）

### 3.1 Flutter / Dart

| 依赖 | 版本 | 角色 |
| --- | --- | --- |
| flutter_rust_bridge | 2.11.1 | Flutter 与 Rust 互操作桥接 |
| uuid | ^4.5.3 | 标识生成 |
| cupertino_icons | ^1.0.8 | iOS 风格图标 |
| flutter_lints（dev） | ^6.0.0 | Dart/Flutter lint 基线 |

### 3.2 Rust

| 依赖 | 版本 | 角色 |
| --- | --- | --- |
| flutter_rust_bridge | =2.11.1 | Rust 侧 FRB 绑定 |
| serde | 1 | 序列化/反序列化 |
| uuid | 1 | UUID（含 v7/serde/fast-rng） |
| thiserror | 1 | 错误类型定义 |
| loro | 1.10.3 | CRDT 数据内核 |
| rusqlite | 0.31 | 本地 SQLite 读模型（bundled） |
| postcard | 1 | 二进制序列化 |
| base64 | 0.22 | 编解码 |
| iroh | 0.96.1 | P2P 网络同步 |
| tokio | 1 | 异步运行时 |
| tempfile（dev） | 3 | 测试临时文件支持 |

## 4. 版本治理与变更规则

- 依赖升级采用最小必要原则；避免为“可升级而升级”。
- FRB 升级必须双端同步（Dart/Rust 同步变更）并完成端到端编译验证。
- 新增或替换核心技术栈（语言、框架、存储、同步、桥接）前，必须先在 `docs/plans/` 形成设计记录，再更新本文档。
- 任何会改变构建、测试、发布门禁的技术栈变更，需同步更新对应标准文档（如 TDD、Git/PR 规范）。

## 5. 与其他规范的关系

- 文档维护要求遵循 `docs/standards/documentation.md`。
- 功能实现与行为变更遵循 `docs/standards/spec-first-execution.md`。
- 测试与质量门禁遵循 `docs/standards/tdd.md`。
- 提交与协作流程遵循 `docs/standards/git-and-pr.md`。
