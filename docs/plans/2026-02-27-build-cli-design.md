# CardMind 多平台构建 CLI 设计（2026-02-27）

## 1. 目标与背景
- 提供统一的 Dart CLI 入口，支持在不同系统执行一致的构建流程。
- 明确拆分 Rust 动态库构建与 Flutter App 构建，避免流程混淆。
- 保障 FRB 绑定生成顺序正确，避免读取旧产物导致的联调不一致。

## 2. 命令模型

### 2.1 入口
- 命令入口：`dart run tool/build.dart <subcommand> [options]`

### 2.2 子命令
- `lib`：仅构建 Rust 动态库。
- `app`：构建应用，可执行流程固定为：`lib` -> `codegen` -> `flutter build`。

## 3. 行为定义

### 3.1 `lib` 子命令
- 在 `rust/` 目录执行 Cargo 构建。
- 默认使用 `--release`（动态库默认按发布配置构建）。
- 支持可选 `--target <triple>` 透传至 Cargo。

### 3.2 `app` 子命令
- 首先调用 `lib` 子命令，确保 Rust 产物为最新。
- 然后执行 `flutter_rust_bridge_codegen generate`。
- 最后执行 `flutter build <platform>`。
- 默认平台为当前系统可执行目标：
  - macOS -> `macos`
  - Linux -> `linux`
  - Windows -> `windows`
- 支持 `--platform` 手动覆盖平台。

## 4. 平台与错误处理
- 在执行前检查所需工具是否可用（`dart`、`flutter`、`cargo`、`flutter_rust_bridge_codegen`）。
- 平台不匹配时输出明确错误（例如在非 macOS 环境请求 `ios`）。
- 任一步骤失败即退出并返回非 0 状态码，停止后续步骤。

## 5. 输出与可观测性
- 统一日志前缀（如 `[build]`、`[lib]`、`[app]`），便于 CI/本地阅读。
- 每步输出完整命令和工作目录。
- 成功后提示关键产物位置（Rust 动态库与 Flutter 构建目录）。

## 6. 验收标准
- `dart run tool/build.dart lib` 可独立构建 Rust 动态库。
- `dart run tool/build.dart app` 会按 `lib` -> `codegen` -> `flutter build` 顺序执行。
- `app` 不传平台参数时，默认构建当前系统可执行目标。
- 手动指定平台时，命令能正确解析并执行/报错。
- 失败时退出码非 0，且有可读错误信息。

## 7. 首版不做项
- 不做并行多平台一次性构建（由外部 CI 矩阵完成）。
- 不做自动发布打包流程（如 notarization、签名、上传）。
- 不做复杂配置文件系统（首版以命令参数为主）。
