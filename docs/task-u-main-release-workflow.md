# Task U: main 分支三端自动构建并发布 Release

## 任务

将当前仅支持手动运行且已经漂移的 `.github/workflows/manual-build-artifacts.yml` 改为可在每次推送 `main` 时自动构建 CardMind 当前真实支持的三个发布目标，并将三个成功产物放到同一个 GitHub 预发布 Release：Android APK、Windows Inno Setup EXE 安装包、Linux x64 tar.gz。保留 `workflow_dispatch` 以便手动重跑。

Windows 面向用户的唯一发布产物是 `CardMind-Setup.exe`，不发布 Windows ZIP 或 MSIX。当前仓库不存在 `macos/` 和 `ios/`，不得添加 macOS/iOS 构建 job 或虚构对应产物。

## 主仓库与 worktree

主仓库路径: `D:/Projects/CardMind`

worktree 路径: `D:/Projects/CardMind/.worktrees/main-release-workflow`

worktree 分支: `codex/main-release-workflow`

流水线必须创建上述新 worktree 和分支，不得在主仓库工作树修改实现文件。

## 改动范围

仅允许修改或新增：

- `.github/workflows/manual-build-artifacts.yml`
- `tool/installer/cardmind.iss`
- `test/release_workflow_test.dart`
- `.workflow/executor-report.md`
- `.workflow/review-report.md`
- `.workflow/final-check.md`

不得修改 Flutter/Rust 业务代码、生成的 FRB 绑定、依赖版本、`pubspec.yaml`、`pubspec.lock`、平台工程文件或其他 workflow。

## 设计要求

### 触发与权限

- workflow 显示名改成能准确表达自动发布用途的名称。
- `push.branches` 只包含 `main`。
- 保留 `workflow_dispatch`。
- `permissions.contents` 必须为 `write`，用于创建 tag、Release 和上传资产。
- concurrency 按分支隔离；同一分支的新运行取消旧运行，避免旧提交晚于新提交发布。
- 任何构建失败都不得创建不完整 Release；发布 job 必须显式依赖 Android、Windows、Linux 三个构建 job 全部成功。

### 通用版本与目录基线

- Rust crate 当前目录是 `rust-backend/`，所有 cargo build/cache workspaces 必须指向该目录，禁止继续使用旧 `rust/`。
- Flutter Rust Bridge 当前版本是 `2.12.0`，codegen 安装版本必须与 `rust-backend/Cargo.toml` 一致，不得保留 `2.11.1`。
- 所有平台均先 `flutter pub get`、安装/缓存 Rust 与 FRB codegen、执行 `flutter_rust_bridge_codegen generate`，再构建平台产物。
- 不得提交 codegen 或构建过程产生的文件。

### Android

- runner 使用 `ubuntu-latest`，Java 17。
- 安装 `aarch64-linux-android`、`armv7-linux-androideabi`、`x86_64-linux-android` Rust targets 和 `cargo-ndk`。
- cargo-ndk 输出必须是仓库现行 Gradle 配置实际读取的 `build/android-jni`，包含 `armeabi-v7a`、`arm64-v8a`、`x86_64`。
- 构建 `flutter build apk --release`。
- job artifact 中的发布文件名固定为 `CardMind-Android.apk`。

### Windows

- runner 使用 `windows-latest`。
- 在 `rust-backend/` 执行 release cargo build，并在 Flutter Windows release 构建完成后把 `rust-backend/target/release/cardmind_backend.dll` 复制到 `build/windows/x64/runner/Release/cardmind_backend.dll`；复制后必须检查目标文件存在且非空。
- 构建 `flutter build windows --release`。
- 使用 Inno Setup 6 编译 `tool/installer/cardmind.iss`，必要时在 runner 上安装 Inno Setup；不得依赖开发机绝对路径。
- `tool/installer/cardmind.iss` 必须允许从 ISCC 命令行覆盖 `SourceDir`、`OutputDir`、`MyAppVersion`，并为本地手动调用保留基于脚本位置/仓库相对路径的默认值。
- 安装脚本必须递归打包整个 `build/windows/x64/runner/Release/` 运行目录，保证所有当前和未来插件 DLL、`data/`、native assets 被包含；不得继续逐个硬编码 DLL 清单。
- job artifact 中只包含 `CardMind-Setup.exe`；不得上传 Windows ZIP、MSIX 或 loose bundle。

### Linux

- runner 使用 `ubuntu-latest`，安装 Flutter Linux 构建所需系统包（至少 GTK 3、CMake、Ninja、pkg-config 和编译工具）。
- 在 `rust-backend/` 执行 release cargo build，构建 `flutter build linux --release` 后，把 `rust-backend/target/release/libcardmind_backend.so` 复制到 `build/linux/x64/release/bundle/lib/libcardmind_backend.so`；复制后必须检查目标文件存在且非空。
- 将完整 `build/linux/x64/release/bundle/` 打包为 `CardMind-Linux-x64.tar.gz`，压缩包根目录应为 `cardmind/`，不能只打包可执行文件。

### Release

- 发布 job 下载三个 job artifacts，并验证恰好存在 `CardMind-Android.apk`、`CardMind-Setup.exe`、`CardMind-Linux-x64.tar.gz` 三个非空文件。
- 每个提交使用独立预发布 tag，格式为 `dev-YYYYMMDD-<7位短SHA>`，与仓库已有 dev Release 习惯一致；Release 标题为 `CardMind <tag>`，target 为本次 `github.sha`。
- 同一提交手动重跑必须可幂等更新同一个 Release 的同名资产，而不是因 tag/资产已存在失败。
- Release notes 至少写明这是 `main` 自动开发构建、完整 commit SHA，并列出三个资产的用途。
- 不得修改或覆盖正式版本 tag（例如 `v0.0.1`）。

## 验收标准（每条均为测试用例）

### 1. 红阶段：现有 workflow 漂移必须先被测试锁定

先新增 `test/release_workflow_test.dart`，测试名称至少包含以下五个用例，并在修改 workflow/installer 前运行：

1. `main push and manual dispatch trigger complete release`
2. `build matrix matches the three supported platforms`
3. `desktop jobs install current Rust runtime libraries`
4. `windows release is an Inno Setup exe rather than a zip`
5. `release waits for all builds and uploads exact assets idempotently`

命令：

```bash
flutter test test/release_workflow_test.dart --timeout 3m
```

红阶段必须因当前旧 workflow 仍为仅手动、旧 `rust/` 路径、FRB `2.11.1`、macOS job、Windows ZIP、无 Release job、Inno 绝对路径/硬编码 DLL 等真实缺陷失败。executor 报告必须记录至少一个代表性失败断言和非零退出码；禁止用无关的故意失败制造红阶段。

### 2. 绿阶段：静态发布契约全部通过

实现后运行：

```bash
flutter test test/release_workflow_test.dart --timeout 3m
```

预期：上述五个测试全部通过，退出码 0。测试应使用 Dart `yaml` 解析 workflow 的结构化字段，并仅对 GitHub expression、shell 命令或 Inno 语法中无法结构化解析的部分做精确文本/正则断言；不得只断言文件包含一个宽泛关键词。

### 3. YAML 与 Inno Setup 基本语法/契约验证

运行一个不修改仓库文件的解析检查，确认 `.github/workflows/manual-build-artifacts.yml` 可被 Dart `yaml` 成功解析，并输出顶层键与 jobs 名称；再由测试断言 `tool/installer/cardmind.iss` 的条件 define、递归完整目录打包和固定输出名。

预期：解析命令退出码 0；jobs 只含 Android、Windows、Linux、Release 所需 job，不含 macOS/iOS。

### 4. 变更范围验证

运行：

```bash
git status --short
git diff --check
git diff -- .github/workflows/manual-build-artifacts.yml tool/installer/cardmind.iss test/release_workflow_test.dart
```

预期：除允许范围和 `.workflow/` 报告外无修改；`git diff --check` 退出码 0；不得出现 `pubspec.lock`、FRB 生成文件或业务代码变更。

### 5. reviewer 与 build 独立复验

reviewer 必须独立重跑第 2、3、4 条并检查：

- Windows Release 资产只有 EXE 安装包；
- 三个桌面/移动发布文件都来自当前真实平台目录；
- publish job 在任一构建失败时不会运行；
- 同一 SHA 重跑不会因已存在 tag/asset 失败；
- 没有密钥、token 或本机绝对路径进入配置。

build 主代理在 reviewer 通过后再次重跑第 2、3、4 条，并把真实输出写入 `.workflow/final-check.md`。

## 需决策点

遇到以下任一情况必须停下报告，不得自行扩大范围：

- 当前 GitHub runner 无法在不引入长期凭据/签名证书的情况下生成可运行的 APK、EXE 或 tar.gz；
- 实现需要修改 Flutter/Rust 业务代码、平台工程、依赖清单或 FRB 生成文件；
- Inno Setup 无法通过 runner 预装工具或 Chocolatey 非交互安装获得；
- GitHub Actions 无法用仓库 `GITHUB_TOKEN` 创建预发布 Release；
- workflow 需要改为“允许部分平台失败仍发布”才能工作；本任务明确禁止不完整发布。
