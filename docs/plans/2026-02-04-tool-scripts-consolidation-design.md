# 工具脚本收敛设计

**目标**: 将 `tool/` 目录收敛为两个 Dart 入口脚本（构建 + 质量），删除其他脚本，确保 Flutter/Rust 构建与测试能使用最新的 FRB 代码与动态/静态库。

## 背景
当前 `tool/` 脚本分散、入口过多，且存在脚本间职责重叠。需求明确为：仅保留 Dart 脚本，且仅保留两个用途的入口（构建与静态代码质量检测）。同时，需要保证 Flutter 测试不会加载旧的 Rust 动态库，并在 macOS/iOS 上通过 Xcode 配置实现库的集成。

## 设计原则
- **入口极简**: 只保留两个入口脚本，其他脚本全部删除。
- **跨平台默认**: 未指定平台参数时，默认构建“当前系统能构建的全部”。
- **稳定可重复**: 任何流程失败即停止并返回非 0。
- **保持 Dart-only**: 工具脚本仅使用 Dart 实现与组织。

## 入口与参数
### 1) 构建脚本
路径: `tool/build.dart`

用法:
- `dart tool/build.dart bridge [--android|--linux|--windows|--macos|--ios]`
- `dart tool/build.dart app [--android|--linux|--windows|--macos|--ios]`

平台默认（未指定平台参数时）:
- Linux: Android + Linux
- Windows: Android + Windows
- macOS: Android + iOS + macOS

仅保留平台参数，不提供 `--debug` / `--clean` 等非平台参数。

### 2) 质量脚本
路径: `tool/quality.dart`

用法:
- `dart tool/quality.dart`

无可选参数。默认执行自动修复与全量测试。

## 构建脚本流程
### bridge 子命令
1. 环境检查（Flutter / Rust / FRB codegen / 平台依赖）。
2. 生成 FRB 代码（沿用现有 codegen 逻辑）。
3. 格式化生成代码（Dart format / Rust fmt）。
4. Rust 库构建：按平台和架构编译。
5. 复制产物到平台集成路径：
   - Android: `android/app/src/main/jniLibs/<abi>/libcardmind_rust.so`
   - macOS/iOS: 生成 `cardmind_rust.xcframework` 并复制到 `macos/Runner/Frameworks/` 与 `ios/Runner/Frameworks/`

### app 子命令
1. 执行 `bridge` 子流程（确保库与桥接代码最新）。
2. 构建 Flutter 应用（按平台集合）。
3. 复制桌面端库到最终 bundle/runner：
   - Linux: `build/linux/x64/release/bundle/lib/libcardmind_rust.so`
   - Windows: `build/windows/x64/runner/Release/cardmind_rust.dll`

## 质量脚本流程
顺序固定，确保 Flutter 测试加载最新库：
1. Rust: `cargo fmt` → `cargo check` → `cargo clippy` → `cargo test`
2. 构建桥接与库：调用 `tool/build.dart bridge`，平台集合为：
   - Linux/Windows: 宿主平台 + Android
   - macOS: 宿主平台 + Android + iOS
3. Dart/Flutter: `dart fix --apply` → `dart format` → `flutter analyze` → `flutter test`

## macOS/iOS 集成策略（静态 xcframework）
- Rust 生成静态库（`libcardmind_rust.a`），通过 `xcodebuild -create-xcframework` 打包为 `cardmind_rust.xcframework`。
- `build.dart bridge` 负责复制到 `macos/Runner/Frameworks/` 与 `ios/Runner/Frameworks/`。
- 自动修改 `macos/Runner.xcodeproj/project.pbxproj` 与 `ios/Runner.xcodeproj/project.pbxproj`：
  - 增加 `cardmind_rust.xcframework` 文件引用
  - 添加到 `Frameworks` 链接阶段
  - 添加到 `Embed Frameworks` 阶段
  - 必要时补充 `FRAMEWORK_SEARCH_PATHS` 指向 `Runner/Frameworks`
- 为适配静态库，Dart 初始化改为在 iOS/macOS 使用 `ExternalLibrary.process()`。

## 删除清单
删除 `tool/` 内除下列文件之外的所有脚本与旧 README：
- `tool/build.dart`
- `tool/quality.dart`
- `tool/README.md`

## 风险与控制
- **pbxproj 修改风险**: 使用幂等插入策略，检测已存在条目避免重复。
- **Xcode 结构差异**: 仅定位 Runner target 的 `Frameworks` 与 `Embed Frameworks` 阶段，失败时输出明确报错。
- **Flutter 测试加载旧库**: 质量脚本在 Dart 测试前执行 `bridge` 生成与库构建。

## 验证方式
- 执行 `dart tool/build.dart bridge` 与 `dart tool/build.dart app`，确认产物路径正确。
- 执行 `dart tool/quality.dart`，确认 Rust/Dart 两侧检查与测试均可运行。
- 在 macOS/iOS 上确认 Xcode 工程配置中 `cardmind_rust.xcframework` 已链接并嵌入。
