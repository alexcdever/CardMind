# CardMind 工具脚本

本目录保留工具入口：构建、质量检查与本地 Git 质量门禁。

## git_gate.dart - 本地质量门禁 CLI

**用途**: pre-commit 快速相关门禁、pre-push 完整 host suite、计划预览。

```bash
dart run tool/git_gate.dart pre-commit              # format-first + staged 相关快速检查
dart run tool/git_gate.dart pre-push                # format-first + 完整 host suite（读 stdin ref 行）
dart run tool/git_gate.dart full                    # 完整 host suite（独立执行，写缓存）
dart run tool/git_gate.dart plan --staged           # 打印计划（不执行）
dart run tool/git_gate.dart plan --files <path...>  # 按给定文件打印计划
```

选项：`--dry-run` 只打印不执行；`--files <path...>` 用给定文件代替 staged 文件。

环境变量：

- `SKIP_LOCAL_CHECK=1`：由 `.githooks/` 处理，跳过门禁
- `CARDMIND_FORCE_FULL_CHECK=1`：忽略 pre-push HEAD 缓存
- `CARDMIND_GATE_TEST_MODE=1`：测试模式（fake runner，供真实 hook 集成测试）

**设计要点**: format-first 先于一切检查；formatter 改变文件即阻止并提示重新暂存；每个外部进程 3 分钟硬超时；pre-push 完整成功后按 exact HEAD 写 `.git` 内缓存。build-lib 为 gate 内跨平台实现（`cargo build --release` + 运行态同步，Windows/macOS/Linux 各平台正确库名/路径；平台规格与 `dart run tool/build.dart lib` 共用 `tool/src/git_gate/host_build.dart`），不依赖 tool/build.dart 的 CLI 入口。

## lint/markdown_references_linter.dart - 文档路径检查

**用途**: 检查仓库自有文档里的路径引用是否指向真实存在的对象；pre-commit / pre-push 的 `docs:lint` 步骤调用。

**检查两类引用**:

- Markdown 链接（方括号文字 + 圆括号里的 .md 路径），相对所在文件解析
- 行内代码路径：形如 `docs/product.md`、`lib/bridge/`，相对仓库根解析（首段必须是仓库根下真实存在的条目）

**检查范围**: 扫描根下全部 `.md`，排除外部导入的工具/技能包目录（`.claude/`、`.codex/`、`.github/prompts/` 等）以及
`.worktrees/`、`.pipeline/`、`.workflow/`、`node_modules/`、`build/`、`target/` 等非源码目录。
是否跳过按「相对扫描根」的路径段判断，因此在 worktree 内运行时检查的是 worktree 自己的文档，
在主工作树运行时不会递归进 `.worktrees/` 下的其它 checkout。

**构建产物**: 只有确实位于已知构建输出目录**之下**的路径才跳过存在性判定，当前前缀为 `build/`、
`.dart_tool/`、`rust-backend/target/`、`sync-verify/target/`、`android/build/`、`android/app/build/`、
`android/app/src/main/jniLibs/`、`android/.gradle/`、`macos/build/`、`linux/build/`、`windows/build/`
（全新 checkout 中本就不存在）。判定是前缀匹配，段名巧合的路径仍照常判定。

**用法**:

```bash
dart run tool/lint/markdown_references_linter.dart
```

## build.dart - 构建入口

**用途**: 构建 Rust 动态库与 Flutter 应用（`app` / `lib` / `run` 三个子命令）。

**用法**:
```bash
dart run tool/build.dart <app|lib|run> [options]
```

**子命令**:
- `lib`：在 `rust-backend/` 执行 `cargo build --release`（可选 `--target <triple>`），把 cargo 产物同步到当前 host 的运行态路径：Windows `rust-backend/target/release/cardmind_backend.dll` → `build/windows/x64/runner/Release/`，macOS `libcardmind_backend.dylib` → `build/native/macos/`，Linux `libcardmind_backend.so` → `build/linux/x64/release/bundle/lib/`
- `app`：构建 Rust 库 → `flutter_rust_bridge_codegen generate` → `flutter build <platform>`
- `run`：仅 macOS；`lib` → `flutter build macos` → 复制 framework → 打开应用（`--app-copy-name`、`--app-bundle-id` 用于启动隔离副本）

**app 的 `--platform` 取值**: `android`、`macos`、`linux`、`windows`；未指定时取主机可执行平台，取值非法则报错退出。
（`lib` 的平台规格与门禁 build-lib 共用 `tool/src/git_gate/host_build.dart`；带 `--target` 时 cargo 产物在 `rust-backend/target/<triple>/release/` 下，文件名与运行态目标按 triple 推断，推断不出时回退 host 平台。）

**Android 构建**: 用 `cargo ndk` 为 `armeabi-v7a`、`arm64-v8a`、`x86_64` 产出 `libcardmind_backend.so` 到 `build/android-jni/`；
`flutter build` 的输出格式由 `--android-format` 控制：`apk`（默认）、`appbundle`、`split-apk`。

## quality.dart - 质量检查入口

**用途**: 按子命令跑 Flutter / Rust / 文档质量链路。

**用法**:
```bash
dart run tool/quality.dart <flutter|rust|docs|all> [options]
```

**子命令执行内容**:
- `flutter`：markdown references lint → 构建运行态 Rust 库（`cargo build --release` + 进程内 host 运行态同步，平台规格来自 `tool/src/git_gate/host_build.dart`；不再调用 `dart tool/build.dart lib`）→ FRB codegen → `flutter analyze` → `flutter test --coverage` → 测试边界扫描（`--scope=flutter`）
- `rust`：`cargo fmt --all -- --check` → `cargo clippy --all-targets --all-features -- -D warnings` → `cargo test --jobs 1` → 生成 LCOV（`cargo tarpaulin`）→ 测试边界扫描（`--scope=rust`）
- `docs`：markdown references lint
- `all`：先 `flutter` 链路（含 FRB 准备），再 `rust` 链路

**说明**:
- 两个边界扫描步骤都只**告警**，不改变退出码；报告写在运行目录下的 `tmp` 子目录，文件名 `cardmind_test_boundary_report.md`
- Rust LCOV 生成失败（未装 `cargo tarpaulin`）同样只告警
- 不带子命令会打印 usage 并退出非零
