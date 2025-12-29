# 开发环境搭建指南

本文档提供详细的开发环境搭建步骤，帮助新开发者快速启动项目。

## 系统要求

### 硬件要求
- **磁盘空间**: 至少 10GB 可用空间
- **内存**: 8GB 或以上
- **处理器**: 双核或以上

### 操作系统
- **Windows**: Windows 10 或更高版本
- **macOS**: macOS 10.14 (Mojave) 或更高版本
- **Linux**: Ubuntu 18.04+、Fedora、Arch Linux 等主流发行版

---

## 1. 安装 Git

### Windows
```powershell
# 使用 Scoop (推荐)
scoop install git

# 或下载安装器
# 访问 https://git-scm.com/download/win
```

### macOS
```bash
# 使用 Homebrew
brew install git

# 或使用 Xcode Command Line Tools
xcode-select --install
```

### Linux
```bash
# Debian/Ubuntu
sudo apt-get update
sudo apt-get install git

# Fedora
sudo dnf install git

# Arch Linux
sudo pacman -S git
```

### 验证安装
```bash
git --version
# 应输出: git version 2.x.x
```

---

## 2. 安装 Flutter

### Windows

```powershell
# 使用 Scoop (推荐)
scoop bucket add extras
scoop install flutter

# 或手动安装
# 1. 下载 Flutter SDK: https://docs.flutter.dev/get-started/install/windows
# 2. 解压到 C:\src\flutter
# 3. 添加到 PATH: C:\src\flutter\bin
```

### macOS

```bash
# 使用 Homebrew
brew install --cask flutter

# 或手动安装
# 下载: https://docs.flutter.dev/get-started/install/macos
```

### Linux

```bash
# 使用 Snap (推荐)
sudo snap install flutter --classic

# 或手动安装
# 1. 下载 Flutter SDK
cd ~
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.x.x-stable.tar.xz
# 2. 解压
tar xf flutter_linux_3.x.x-stable.tar.xz
# 3. 添加到 PATH
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
source ~/.bashrc
```

### 配置 Flutter

```bash
# 运行 Flutter doctor 检查环境
flutter doctor

# 可能需要接受 Android licenses
flutter doctor --android-licenses

# 配置镜像（中国大陆用户）
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

### 验证安装
```bash
flutter --version
# 应输出: Flutter 3.x.x

flutter doctor -v
# 检查所有依赖是否安装正确
```

---

## 3. 安装 Rust

### Windows

```powershell
# 下载并运行 rustup-init.exe
# 访问: https://rustup.rs/

# 或使用 Scoop
scoop install rustup

# 安装完成后，重启终端并运行
rustup default stable
```

### macOS / Linux

```bash
# 使用官方安装脚本
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 选择默认安装选项 (1)

# 配置环境变量
source "$HOME/.cargo/env"

# 或手动添加到 shell 配置文件
echo 'source "$HOME/.cargo/env"' >> ~/.bashrc  # 或 ~/.zshrc
```

### 验证安装
```bash
rustc --version
# 应输出: rustc 1.x.x

cargo --version
# 应输出: cargo 1.x.x
```

### 安装必要的 Rust 工具

```bash
# 安装 clippy (静态分析工具)
rustup component add clippy

# 安装 rustfmt (代码格式化工具)
rustup component add rustfmt

# 安装 cargo-tarpaulin (测试覆盖率工具，可选)
cargo install cargo-tarpaulin
```

---

## 4. 安装 flutter_rust_bridge 代码生成器

```bash
# 安装 flutter_rust_bridge_codegen
cargo install flutter_rust_bridge_codegen

# 验证安装
flutter_rust_bridge_codegen --version
```

---

## 5. 配置 IDE

### 选项 A: Visual Studio Code (推荐)

#### 安装 VS Code
- 访问: https://code.visualstudio.com/
- 下载并安装

#### 安装必要扩展

```bash
# Flutter 扩展
code --install-extension Dart-Code.flutter

# Rust 扩展
code --install-extension rust-lang.rust-analyzer

# TOML 支持
code --install-extension tamasfe.even-better-toml

# Markdown 预览增强
code --install-extension shd101wyy.markdown-preview-enhanced
```

#### 配置 settings.json

在 VS Code 中，按 `Ctrl+Shift+P` (macOS: `Cmd+Shift+P`)，输入 "Preferences: Open Settings (JSON)"，添加：

```json
{
  "editor.formatOnSave": true,
  "rust-analyzer.checkOnSave.command": "clippy",
  "[dart]": {
    "editor.formatOnSave": true,
    "editor.rulers": [80]
  }
}
```

### 选项 B: Android Studio / IntelliJ IDEA

#### 安装插件
- Flutter plugin
- Dart plugin
- Rust plugin

---

## 6. 克隆项目

```bash
# 克隆仓库
git clone https://github.com/YOUR_USERNAME/CardMind.git
cd CardMind

# 切换到开发分支
git checkout develop
```

---

## 7. 安装项目依赖

### Flutter 依赖

```bash
# 获取 Flutter 依赖
flutter pub get
```

### Rust 依赖

```bash
# 进入 Rust 目录
cd rust

# 构建项目（会自动下载依赖）
cargo build

# 返回项目根目录
cd ..
```

---

## 8. 生成桥接代码

```bash
# 使用Dart脚本（跨平台，Windows/macOS/Linux通用）
dart tool/generate_bridge.dart

# 脚本会自动:
# 1. 检查环境依赖
# 2. 生成桥接代码
# 3. 格式化生成的代码
```

---

## 9. 运行测试

### Rust 测试

```bash
cd rust
cargo test

# 应该看到所有测试通过（初期可能没有测试）
```

### Flutter 测试

```bash
flutter test

# 应该看到所有测试通过（初期可能没有测试）
```

---

## 10. 运行应用

### 启动模拟器/连接设备

#### Android
```bash
# 列出可用设备
flutter devices

# 启动 Android 模拟器
flutter emulators
flutter emulators --launch <emulator_id>
```

#### iOS (仅 macOS)
```bash
# 启动 iOS 模拟器
open -a Simulator
```

#### Desktop
```bash
# 直接运行即可，无需模拟器
```

### 运行应用

```bash
# 运行应用（默认设备）
flutter run

# 选择特定设备
flutter run -d <device_id>

# Debug 模式运行
flutter run --debug

# Release 模式运行
flutter run --release
```

---

## 11. 验证开发环境

运行以下命令确保所有工具正常工作：

```bash
# 1. Flutter 环境检查
flutter doctor -v

# 2. Rust 静态检查
cd rust
cargo clippy --all-targets --all-features

# 3. Flutter 静态分析
flutter analyze

# 4. 运行所有测试
cargo test && cd .. && flutter test
```

如果所有命令都成功执行，说明开发环境搭建完成！

---

## 常见问题

### Q1: Flutter doctor 显示 Android license not accepted

**解决方案**:
```bash
flutter doctor --android-licenses
# 按 'y' 接受所有许可
```

### Q2: cargo build 很慢或失败

**解决方案**:
```bash
# 中国大陆用户配置镜像
# 在 ~/.cargo/config.toml 添加:
[source.crates-io]
replace-with = 'ustc'

[source.ustc]
registry = "https://mirrors.ustc.edu.cn/crates.io-index"
```

### Q3: flutter_rust_bridge_codegen 未找到

**解决方案**:
```bash
# 确保 cargo bin 目录在 PATH 中
echo $PATH | grep cargo

# 如果没有，添加到 PATH
export PATH="$HOME/.cargo/bin:$PATH"
```

### Q4: 桥接代码生成失败

**解决方案**:
```bash
# 确认已安装flutter_rust_bridge_codegen
flutter_rust_bridge_codegen --version

# 如果未安装
cargo install flutter_rust_bridge_codegen

# 使用Dart脚本重新生成（跨平台）
dart tool/generate_bridge.dart
```

### Q5: Rust 编译错误：linker not found

**Windows 解决方案**:
```powershell
# 安装 Visual Studio Build Tools
# 访问: https://visualstudio.microsoft.com/downloads/
# 选择 "Desktop development with C++"
```

**macOS 解决方案**:
```bash
xcode-select --install
```

**Linux 解决方案**:
```bash
# Debian/Ubuntu
sudo apt-get install build-essential

# Fedora
sudo dnf install gcc
```

### Q6: Flutter 运行时找不到 Rust 库

**解决方案**:
```bash
# 重新生成桥接代码
dart tool/generate_bridge.dart

# 清理并重建
flutter clean
flutter pub get
cd rust && cargo clean && cargo build && cd ..
flutter run
```

---

## 下一步

环境搭建完成后，建议按以下顺序继续：

1. **阅读 [CLAUDE.md](../CLAUDE.md)** - 了解项目架构和开发规范
2. **阅读 [TESTING_GUIDE.md](TESTING_GUIDE.md)** - 学习 TDD 开发流程
3. **查看 [ROADMAP.md](ROADMAP.md) Phase 1** - 开始第一个开发任务

---

## 获取帮助

遇到问题？

1. 查看 [FAQ.md](FAQ.md) - 常见问题解答
2. 搜索项目 Issues
3. 提交新 Issue（附上错误信息和系统信息）

---

## 环境信息收集（提 Issue 时使用）

```bash
# 收集环境信息
echo "=== Flutter ===" && flutter --version && \
echo "=== Rust ===" && rustc --version && cargo --version && \
echo "=== Git ===" && git --version && \
echo "=== OS ===" && uname -a
```

将输出附在 Issue 中，便于问题诊断。

---

**祝你开发顺利！** 🚀
