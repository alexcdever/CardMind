# Tech Stack Baseline Standard

## 1. 目标与范围

- 本文档定义 CardMind 的技术栈基线与依赖治理规则，适用于 Flutter、Rust、FRB、构建与测试链路。
- 本文档是跨功能、长期复用的工程标准；功能行为本身以 `docs/adr/` 与 `docs/product.md` 为准。

## 2. 技术栈基线

### 2.1 语言与运行时

- Flutter/Dart：Dart SDK `^3.12.2`，以 `pubspec.yaml` 为准。
- 本地与发布构建基线：Flutter `3.44.9`（Dart `3.12.2`）。
- Rust：Edition `2021`，以 `rust-backend/Cargo.toml` 为准。

### 2.2 跨语言桥接

- Flutter Rust Bridge 是唯一 Flutter-Rust FFI 通道。
- Dart 与 Rust 侧 `flutter_rust_bridge` 必须同版本锁步维护，当前为 `2.12.0`。
- FRB 配置源为 `flutter_rust_bridge.yaml`，修改后必须验证生成产物可编译。

### 2.3 数据与同步内核

- 本地数据与状态内核：`loro`
- 本地读模型：`rusqlite`（`bundled`）
- 网络同步：`iroh`

### 2.4 构建与验证链路

- 应用构建：`dart run tool/build.dart app`
- 库构建：`dart run tool/build.dart lib`
- Flutter 测试：`flutter test`
- Rust 测试：`cargo test`
- 静态检查：`flutter analyze`

### 2.5 平台支持

- 产品目标平台：移动端（Android + iOS，覆盖手机与平板）与桌面端（Linux + Windows + macOS，覆盖台式机与笔记本）。
- 仓库现状：平台工程目录只有 `android/`、`linux/`、`macos/`、`windows/`；iOS 属目标平台，工程目录尚未建立（见 `AGENTS.md` 当前状态）。
- 构建链路入口为 `tool/build.dart`，以下子命令按代码实测描述：
  - `dart run tool/build.dart app [--platform <android|macos|linux|windows>] [--android-format <apk|appbundle|split-apk>]`：先构建 Rust 库（`android` 分支用 `cargo ndk` 输出 armeabi-v7a / arm64-v8a / x86_64 三套 `.so`，其余分支用 `cargo build --release`），再执行 `flutter_rust_bridge_codegen generate`，最后执行 `flutter build <platform>`（Android 分支按 `--android-format` 展开为 `build apk`、`build appbundle` 或 `build apk --split-per-abi`）。
  - `dart run tool/build.dart lib [--target <target-triple>]`：执行 `cargo build --release`（带 `--target` 时产物在 `rust-backend/target/<triple>/release/` 下），并按当前 host 平台把编译产物同步到运行态动态库路径（Windows `build/windows/x64/runner/Release/cardmind_backend.dll`、macOS `build/native/macos/libcardmind_backend.dylib`、Linux `build/linux/x64/release/bundle/lib/libcardmind_backend.so`；平台规格来自 `tool/src/git_gate/host_build.dart`）。
  - `dart run tool/build.dart run [--app-copy-name <name.app>] [--app-bundle-id <id>]`：仅 macOS，依次执行 lib → `flutter build macos --debug` → 拷贝动态库进 app bundle → 启动应用。
- `--platform` 只接受 `android`、`macos`、`linux`、`windows`；省略时解析为当前主机可执行平台（`macos`/`linux`/`windows`），iOS 主机没有默认可执行目标。
- iOS 与移动端构建运行沿用 Flutter 原生命令链路（如 `flutter build ios`、`flutter build apk`）；`tool/build.dart` 当前未封装 iOS 目标。
- `tool/build.dart` 的默认平台解析逻辑应保持与主机可执行平台一致。

## 3. 核心三方依赖

### 3.1 Flutter / Dart

| 依赖 | 版本 | 角色 |
| --- | --- | --- |
| flutter_rust_bridge | 2.12.0 | Flutter 与 Rust 互操作桥接 |
| cupertino_icons | ^1.0.8 | iOS 风格图标 |
| flutter_lints（dev） | ^6.0.0 | Dart/Flutter lint 基线 |

### 3.2 Rust

| 依赖 | 版本 | 角色 |
| --- | --- | --- |
| flutter_rust_bridge | =2.12.0（锁定 2.12.0） | Rust 侧 FRB 绑定 |
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
