# CardMind 构建指南

本指南说明如何使用 `build_all.dart` 脚本构建 CardMind 全平台应用。

---

## 环境要求

### 必需工具

1. **Flutter** 3.x
   ```bash
   # 验证安装
   flutter --version
   flutter doctor
   ```

2. **Rust** 1.70+
   ```bash
   # 验证安装
   rustc --version
   cargo --version
   ```

3. **flutter_rust_bridge_codegen**
   ```bash
   cargo install flutter_rust_bridge_codegen
   ```

### 平台特定要求

**Android**:
- Android SDK（通过 Android Studio 或 sdkmanager）
- Android NDK
- 目标 API Level 23+

**Linux**:
- `build-essential`, `libsqlite3-dev`
- GTK 3 开发库

**macOS**:
- Xcode 和 Command Line Tools

**Windows**:
- Visual Studio 2022 with C++ 工具链

**iOS**:
- macOS + Xcode
- CocoaPods

完整的安装步骤请参考各工具的官方文档。

---

## 快速开始

### 构建所有支持的平台

```bash
# 在 Linux 上（默认构建 Android 和 Linux）
dart tool/build_all.dart

# 在 macOS 上（默认构建 Android、iOS 和 macOS）
dart tool/build_all.dart

# 在 Windows 上（默认构建 Android 和 Windows）
dart tool/build_all.dart
```

### 构建特定平台

```bash
# 只构建 Android
dart tool/build_all.dart --android

# 只构建 Linux
dart tool/build_all.dart --linux

# 构建 Android 和 Linux
dart tool/build_all.dart --android --linux

# 构建所有可用平台（需要在对应系统上）
dart tool/build_all.dart --android --linux --windows --macos --ios
```

### 其他选项

```bash
# 清理所有构建产物
dart tool/build_all.dart --clean

# Debug 模式构建（默认是 Release）
dart tool/build_all.dart --debug

# Debug 模式构建特定平台
dart tool/build_all.dart --debug --android
```

## 构建流程

脚本会自动完成以下步骤：

1. **环境检查**
   - 检查 Flutter、Rust、flutter_rust_bridge_codegen 是否已安装
   - 检查平台特定的工具和依赖
   - 自动安装缺失的工具（如 flutter_rust_bridge_codegen、cargo-ndk）

2. **构建 Rust 库**
   - 为每个目标平台编译 Rust 动态库
   - Android: 编译 4 个架构（arm64-v8a, armeabi-v7a, x86_64, x86）
   - 其他平台: 编译对应架构的库

3. **部署 Rust 库**
   - 自动将编译好的 Rust 库复制到 Flutter 需要的位置
   - Android: 复制到 `android/app/src/main/jniLibs/[架构]/`
   - Linux: 复制到 `build/linux/x64/release/bundle/lib/`
   - Windows: 复制到 `build/windows/x64/runner/release/`
   - 其他平台类似

4. **构建 Flutter 应用**
   - 运行 `flutter build` 为每个平台构建应用
   - 自动处理平台特定的环境变量（如 Linux 的 PKG_CONFIG_PATH）

5. **生成构建报告**
   - 显示所有构建产物的位置和大小
   - 标注构建成功或失败的平台

## 平台特定要求

### Android

**必需工具**:
- Android SDK
- Android NDK（脚本会自动安装）
- cargo-ndk（脚本会自动安装）

**Rust 目标**:
```bash
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android
```

**环境变量**:
- `ANDROID_HOME` 或 `ANDROID_SDK_ROOT`: Android SDK 路径
- `ANDROID_NDK_HOME`: Android NDK 路径（可选，脚本会自动检测）

### Linux

**必需工具**:
```bash
sudo apt-get install libgtk-3-dev pkg-config cmake ninja-build
```

**注意事项**:
- 脚本会自动设置 `PATH=/usr/bin:$PATH` 以使用系统的 pkg-config
- 如果您使用 Homebrew，可能需要临时调整 PATH

### Windows

**必需工具**:
- Visual Studio 2019 或更高版本（包含 C++ 桌面开发工具）

### macOS

**必需工具**:
- Xcode
- Xcode Command Line Tools

### iOS

**必需工具**:
- Xcode
- iOS 模拟器或真机

**Rust 目标**:
```bash
rustup target add aarch64-apple-ios x86_64-apple-ios
```

## 构建产物

构建成功后，产物位于以下位置：

- **Android**: `build/app/outputs/flutter-apk/app-release.apk`
- **Linux**: `build/linux/x64/release/bundle/`
- **Windows**: `build/windows/x64/runner/release/`
- **macOS**: `build/macos/Build/Products/Release/`
- **iOS**: `build/ios/iphoneos/`

## 故障排除

### 1. flutter_rust_bridge_codegen 安装失败

手动安装：
```bash
cargo install flutter_rust_bridge_codegen
```

### 2. Android NDK 未找到

设置环境变量：
```bash
export ANDROID_NDK_HOME=/path/to/android-sdk/ndk/26.1.10909125
```

或者让 sdkmanager 自动安装：
```bash
sdkmanager "ndk;26.1.10909125"
```

### 3. Linux 构建失败：找不到 gtk+-3.0

安装 GTK 开发库：
```bash
sudo apt-get install libgtk-3-dev pkg-config
```

### 4. Rust 库未复制到正确位置

检查构建日志中是否有复制失败的错误信息。手动复制：

```bash
# Linux
cp rust/target/release/libcardmind_rust.so build/linux/x64/release/bundle/lib/

# Windows
cp rust/target/release/cardmind_rust.dll build/windows/x64/runner/release/

# Android (示例：arm64-v8a)
cp rust/target/aarch64-linux-android/release/libcardmind_rust.so \
   android/app/src/main/jniLibs/arm64-v8a/
```

### 5. 权限问题

确保脚本有执行权限：
```bash
chmod +x tool/build_all.dart
```

## 高级用法

### 只重新构建 Rust 库

```bash
cd rust
cargo build --release
```

### 手动部署 Rust 库到 Android

```bash
# 构建所有 Android 架构
cargo install cargo-ndk
cargo ndk -t armeabi-v7a -t arm64-v8a -t x86 -t x86_64 \
  -o ../android/app/src/main/jniLibs \
  build --release
```

### 自定义构建配置

编辑 `tool/build_all.dart`，可以修改：
- 目标架构列表
- 构建模式（debug/release）
- 环境变量
- 复制路径

## 持续集成（CI）

在 CI 环境中使用：

```yaml
# .github/workflows/build.yml 示例
- name: Build Android
  run: dart tool/build_all.dart --android

- name: Build Linux
  run: dart tool/build_all.dart --linux
```

## 贡献

如果您在使用构建脚本时遇到问题或有改进建议，请：

1. 检查本指南的故障排除部分
2. 查看 GitHub Issues
3. 提交新的 Issue 或 Pull Request

## 许可证

本构建脚本遵循 CardMind 项目的许可证。
