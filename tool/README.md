# CardMind 工具脚本

本目录仅保留两个入口脚本：构建与质量检查。

## build.dart - 构建入口

**用途**:
- 生成 FRB 桥接代码
- 构建 Rust 库并复制到平台集成路径
- 构建 Flutter 应用（app 子命令）

**用法**:
```bash
# 仅生成桥接与库
dart tool/build.dart bridge [--android|--linux|--windows|--macos|--ios]

# 生成桥接与库，然后构建应用
dart tool/build.dart app [--android|--linux|--windows|--macos|--ios]
```

**默认平台**（未指定平台参数时）:
- Linux: Android + Linux
- Windows: Android + Windows
- macOS: Android + iOS + macOS

**bridge 子命令行为**:
- 生成 FRB 代码并格式化
- 构建 Rust 库（按平台）
- Android: 复制到 `android/app/src/main/jniLibs/`
- macOS/iOS: 生成 `cardmind_rust.xcframework` 并更新 Xcode 工程配置

**app 子命令行为**:
- 先执行 bridge 流程
- 构建 Flutter 应用
- Linux/Windows: 复制 Rust 库到 bundle/runner

## quality.dart - 质量检查入口

**用途**:
- 单元测试覆盖率检查（公开项数量 vs 单元测试数量，阈值 ≥ 90%）
- Rust: `cargo fmt` → `cargo check` → `cargo clippy` → `cargo test`
- 生成桥接与库（宿主平台 + Android；macOS 额外 iOS）
- Dart/Flutter: `dart fix --apply` → `dart format` → `flutter analyze` → `flutter test`

**用法**:
```bash
dart tool/quality.dart
dart tool/quality.dart fuzz
```

**说明**:
- 自动修复默认开启（在 format 之前）
- 始终包含测试步骤

**fuzz 子命令**:
- Rust: cargo-fuzz 目标列表（默认 2–3 个目标，每目标 60 秒）
- Flutter: flutter test test/fuzz
