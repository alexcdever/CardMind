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

**设计要点**: format-first 先于一切检查；formatter 改变文件即阻止并提示重新暂存；每个外部进程 3 分钟硬超时；pre-push 完整成功后按 exact HEAD 写 `.git` 内缓存。build-lib 为 gate 内跨平台实现（`cargo build --release` + 运行态同步，Windows/macOS/Linux 各平台正确库名/路径），不依赖 tool/build.dart。

## lint/markdown_references_linter.dart - 文档路径检查

**用途**: 检查仓库自有文档里的路径引用是否指向真实存在的对象；pre-commit / pre-push 的 `docs:lint` 步骤调用。

**检查两类引用**:

- Markdown 链接（方括号文字 + 圆括号里的 .md 路径），相对所在文件解析
- 行内代码路径：形如 `docs/product.md`、`lib/bridge/`，相对仓库根解析（首段必须是仓库根下真实存在的条目）

**检查范围**: 扫描根下全部 `.md`，排除外部导入的工具/技能包目录（`.claude/`、`.codex/`、`.github/prompts/` 等）以及
`.worktrees/`、`.pipeline/`、`.workflow/`、`node_modules/`、`build/`、`target/` 等非源码目录。
是否跳过按「相对扫描根」的路径段判断，因此在 worktree 内运行时检查的是 worktree 自己的文档，
在主工作树运行时不会递归进 `.worktrees/` 下的其它 checkout。

**构建产物**: `target/`、`build/`、`jniLibs/`、`.dart_tool/`、`.gradle/`、`DerivedData/` 下的路径不做存在性判定
（全新 checkout 中本就不存在）。

**用法**:

```bash
dart run tool/lint/markdown_references_linter.dart
```

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
- Android: 复制到 `android/app/` 下的 `src/main/jniLibs/`（构建产物，仓库不预置）
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
```

**说明**:
- 自动修复默认开启（在 format 之前）
- 始终包含测试步骤
