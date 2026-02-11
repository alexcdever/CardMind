# 构建准备脚本（prepare）设计

**目标**: 将构建前的环境检测与工具安装独立为 `tool/prepare.dart`，由 `tool/build.dart` 在每次构建前强制调用，统一生成并应用本次构建所需环境。

## 背景
当前构建脚本内含较多环境检测与安装逻辑，难以复用与维护。需求要求：
- 统一构建前准备流程（检测/安装/环境变量写入）。
- 根据当前操作系统判断可构建平台集合，避免请求不可用平台。
- NDK 路径不可写死，应根据系统与已安装目录动态选择。
- 安装策略：macOS 使用 Homebrew，Windows 使用 Scoop，Linux 使用 Linuxbrew。

## 设计原则
- **入口单一**: 所有构建必须先调用 `tool/prepare.dart`。
- **自动化优先**: 能自动安装的全部自动安装；不可自动项（如完整 Xcode）按策略执行并失败提示。
- **平台感知**: 根据当前 OS 计算可构建平台集合，拒绝不支持的平台请求。
- **环境可重现**: 本次构建使用 `prepare` 输出的环境映射，确保立即生效。

## 平台矩阵（默认规则）
- macOS: Android + iOS + macOS
- Windows: Windows
- Linux: Linux
- Web: 可扩展（默认不启用）

## 入口与参数
### 1) prepare 脚本
路径: `tool/prepare.dart`

用法:
- `dart tool/prepare.dart [--android|--linux|--windows|--macos|--ios]`

行为:
- 未指定平台参数时，默认准备“当前系统可构建的全部平台”。
- 若请求的平台不被当前系统支持，则失败退出并提示原因。

### 2) build 脚本
路径: `tool/build.dart`

行为:
- 任何构建入口必须先调用 `tool/prepare.dart`。
- `prepare` 失败 → 构建立即停止。
- 读取 `prepare` 生成的环境文件并合并到后续 `Process.run`。

## 依赖检测与安装
`prepare` 负责检测/安装以下内容（按平台）：
- Flutter（`flutter --version`/`flutter doctor`）
- Rust 工具链（确保使用 rustup shim，必要时运行 `rustup-init -y`）
- flutter_rust_bridge_codegen
- cargo-ndk
- Android SDK/NDK（仅 Android 目标）
- Xcode（仅 iOS/macOS 目标）

安装策略：
- macOS: Homebrew
- Windows: Scoop
- Linux: Linuxbrew

不可完全自动安装的项：
- Xcode：先执行 `xcode-select --install`，若仍缺完整 Xcode 则失败退出并提示 App Store 安装。

## NDK 选择策略（不写死）
- 优先读取 `ANDROID_SDK_ROOT` / `ANDROID_HOME`。
- 在 `<sdk>/ndk/` 下扫描版本目录，选择最高版本。
- 根据当前 OS 选择 `toolchains/llvm/prebuilt/{darwin-arm64|darwin-x86_64|linux-x86_64|windows-x86_64}` 中实际存在的目录。
- 将最终路径写入 `ANDROID_NDK_HOME`。

## 环境写入与即时生效
- 将必要环境变量写入 `~/.zshrc`（已确认）。
- 同时生成 `tool/.prepare_env.json` 供 `build` 读取并合并到 `Process.run`，确保本次构建立即生效。

## 错误处理
- 任意关键步骤失败 → 非 0 退出。
- 输出“失败原因 + 解决建议”。
- 对不可自动完成的项给出明确安装指引。

## 验证方式
- `flutter test test/unit/tool/prepare_dart_unit_test.dart`
- `flutter test test/unit/tool/build_dart_unit_test.dart`
- `dart tool/build.dart app --android --ios --macos`

