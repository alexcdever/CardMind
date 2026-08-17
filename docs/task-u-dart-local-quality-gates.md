# 任务 U：将 CardMind 本地质量门禁迁移为 Dart 并分层执行

## 背景

CardMind 当前 `.githooks/pre-commit` 每次提交都会调用 `scripts/check.sh`，执行 Rust 与 Flutter 全量检查。随着测试数量增加，提交反馈过慢。

用户确认采用分层本地门禁：

1. pre-commit：先格式化全部代码，再按 staged 变更运行相关快速检查；
2. pre-push：先格式化全部代码，再运行完整 host suite；
3. Windows/Android 平台集成和双实例 relay E2E：由任务验收或发布门禁执行，不塞进普通 push；
4. 每个测试/检查进程必须有 3 分钟硬超时；
5. CardMind 仓库自有 `.sh` 逻辑迁移到 Dart，以获得跨平台路径、进程、测试和错误处理能力。

## 仓库与隔离

- 主仓库：`D:/Projects/CardMind`
- 基线分支：`codex/knowledge-base`
- 新分支：`codex/dart-local-quality-gates`
- worktree：`D:/Projects/CardMind/.worktrees/dart-local-quality-gates`
- 当前另有 `codex/signed-pairing-credential` worktree 正在修改配对业务。不得进入、修改、格式化或读取其生成产物。
- 只允许修改本任务声明文件；不得触碰 CardMind 业务实现、FRB 生成绑定、配对代码和 prototype。

## 已确认现状

仓库自有且已纳管的 `.sh` 仅有：

- `scripts/check.sh`

Git hook：

- `.githooks/pre-commit`（无扩展名，POSIX hook 入口）
- 尚无 `.githooks/pre-push`

Git Hook 本身必须保留无扩展名可执行入口。允许保留最多数行的 POSIX 启动壳，仅负责定位仓库并 `exec dart run ...`；不得在 hook 中实现文件分类、格式化、测试选择、超时、缓存或业务逻辑。

## 目标结构

建议结构（可按现有 Dart 风格微调，但职责不变）：

```text
tool/git_gate.dart                 # CLI：pre-commit / pre-push / full / plan
tool/src/git_gate/...              # 分类、format、process timeout、cache 等深模块
test/git_gate_test.dart            # 纯 Dart 选择器与状态测试
integration_test 或 test/...       # 临时 Git repo 的真实 hook 启动测试
.githooks/pre-commit               # 薄启动器
.githooks/pre-push                 # 薄启动器
```

删除：

```text
scripts/check.sh
```

最终 `git ls-files '*.sh'` 必须为空。构建产物、Flutter SDK、Cargo target、依赖缓存不属于仓库迁移范围。

## 一、format-first（两个 Hook 都必须）

任何测试、lint、analyze、clippy 之前，先格式化全部 CardMind 源码：

```text
Dart：lib/、test/、integration_test/、tool/ 下全部 .dart
Rust：rust-backend 下全部 Rust 源码（cargo fmt --all）
```

要求：

1. 格式化必须真的写入文件，不能只 `--check`；
2. 格式化前后记录源码内容快照，覆盖 tracked/untracked 文件；
3. 若 formatter 改变任何文件：
   - 保留格式化结果；
   - 立即阻止 commit/push；
   - 输出改变的相对路径；
   - 提示用户检查并重新暂存/提交；
   - 本轮不得继续执行测试；
4. 不自动 `git add`，避免 partial staging 时扩大提交范围；
5. pre-commit 遇到 staged 文件同时有 unstaged 修改时，也不得自动修改 index；format 改变后按上述规则阻止；
6. pre-push 必须验证将测试的 tracked 源码与 HEAD 一致；存在未提交的 tracked 代码或未跟踪源码时阻止 push，避免测试工作树却缓存 HEAD；
7. 文档-only commit 也先执行 format-first，然后才运行文档检查或跳过代码测试。

## 二、pre-commit 快速相关门禁

读取：

```text
git diff --cached --name-only --diff-filter=ACMR
```

按 staged 文件制定保守计划。

### 必跑规则

- `.md`：Markdown references linter；纯文档不跑 Rust/Flutter 测试；
- Dart/Flutter 业务文件：`flutter analyze` + 相关 `test/*_test.dart`；
- 直接改某个 `test/*_test.dart`：至少运行该测试文件；
- Rust 文件：`cargo clippy --all-targets --all-features -- -D warnings` + 相关 Rust test target；
- 直接改 `rust-backend/tests/foo_test.rs`：至少 `cargo test --test foo_test`；
- FRB API、`lib/src/rust/**`、`rust-backend/src/api.rs`、`rust-backend/src/frb_generated.rs`：跨层风险，必须运行真实 FRB smoke 集（至少 `api_integration_test.dart`、`frb_note_repository_test.dart`、`receiver_store_borrow_test.dart` 中存在的文件）与相关 Rust 测试；
- `pubspec.*`、`Cargo.*`、`flutter_rust_bridge.yaml`、平台 runner/plugin 文件、共享配置：fail closed，升级为对应技术栈全量 host 测试；
- 无法分类的非文档文件：fail closed，升级为 Rust + Flutter host 全量；
- pairing/device/scanner 改动：运行所有现有 `pairing*_test.dart`，以及存在的 sync UI/在线状态相关 widget test；
- sync scheduler/bridge 改动：运行 `sync_scheduler_test.dart`、`sync_ui_widget_test.dart`、`receiver_store_borrow_test.dart`（存在才加入）。

### 计划去重

同一命令只能运行一次，输出清晰的计划，再执行。

提供：

```text
dart run tool/git_gate.dart plan --staged
dart run tool/git_gate.dart plan --files <path...>
```

`plan` 只打印结构化计划，不格式化、不运行命令，便于测试选择器。

## 三、pre-push 完整 host suite

pre-push 从 stdin 正确读取 Git 传入的 ref 行，但普通代码 push 无论文件分类都执行完整 host suite：

1. format-first；
2. 验证 tracked 源码与 HEAD 一致、无未跟踪源码；
3. Markdown references lint；
4. `cargo clippy --all-targets --all-features -- -D warnings`；
5. `cargo test --all-features --jobs 1`；
6. 构建/准备当前宿主运行态 Rust DLL（复用 `tool/build.dart lib`，避免 Flutter FRB 测试使用旧 DLL）；
7. `flutter_rust_bridge_codegen generate`；若生成内容变化则阻止 push，要求提交生成结果；
8. codegen 后再次 format-first；若改变文件则阻止 push；
9. `flutter analyze`；
10. `flutter test --timeout 3m`。

不要在普通 pre-push 中启动：

- Windows integration_test device run；
- Android emulator/device run；
- 双实例 relay E2E；
- ignored live relay test；
- coverage/tarpaulin。

这些属于任务验收或发布门禁。

### 3 分钟硬超时

所有外部检查/测试进程由 Dart runner 设置 3 分钟 hard timeout。超时时：

- 终止完整进程树（Windows 与 POSIX 都要处理）；
- 输出命令、耗时和 timeout；
- exit non-zero；
- 不允许无限等待。

### HEAD 缓存

完整 pre-push 成功后，按 exact HEAD SHA 写入 `.git` 内缓存（不得写工作树、不得提交）。

缓存命中条件至少包括：

- exact HEAD 相同；
- tracked 源码工作树干净；
- 无未跟踪源码；
- gate 版本/fingerprint 相同；
- 本次 push 的 local SHA 集与缓存一致。

任一条件不满足必须重跑。缓存只跳过完整 suite，不跳过 format-first 和工作树一致性检查。

支持：

```text
CARDMIND_FORCE_FULL_CHECK=1 git push
```

强制忽略缓存。

## 四、Hook 启动器

`.githooks/pre-commit` 和 `.githooks/pre-push`：

- 保留 `#!/usr/bin/env sh`；
- 只允许做：跳过环境变量判断（如保留兼容）、定位 repo root、`exec dart run tool/git_gate.dart <mode>`；
- 不得包含测试映射或复杂 shell；
- Windows Git Bash、macOS/Linux 均可用；
- 找不到 `dart` 时给出明确错误并阻止操作；
- pre-push 必须把 stdin ref 行原样传给 Dart 进程。

继续支持：

```text
SKIP_LOCAL_CHECK=1 git commit
SKIP_LOCAL_CHECK=1 git push
```

输出中要明确说明被跳过。

## 五、Dart 测试

必须红-绿完成以下测试。

### 纯逻辑测试

1. docs-only 计划只有 format + docs lint，无代码测试；
2. 单个 Flutter test 文件只选自身（同时含 analyze）；
3. devices/pairing/scanner 选中全部 pairing widget/repository 测试；
4. sync scheduler 选中 sync + receiver borrow 测试；
5. 单个 Rust test 文件选中对应 target；
6. sync.rs 选中 sync/service/receiver/autosync 相关 targets；
7. FRB 边界改动选中真实 FRB smoke + Rust；
8. manifest/shared/unknown fail closed；
9. 命令去重、稳定排序；
10. Windows 反斜杠和 POSIX 斜杠归一化结果相同；
11. exact HEAD + fingerprint 缓存命中/失效；
12. 3 分钟 timeout 状态与错误输出（测试可注入短 timeout，不真实等待 3 分钟）。

### format-first 测试

13. Dart 未格式化文件被写回、报告 changed、后续测试 runner 未调用；
14. Rust 未格式化文件同上（可通过 fake runner 测计划/状态，不要求测试修改真实仓库）；
15. formatter 无变化才继续；
16. partial staging 不会自动 git add；
17. pre-push 的 dirty tracked source / untracked source 会阻止完整 suite；
18. Markdown-only 仍先调用 formatter。

### 真实 Hook 测试

在系统临时目录创建最小 Git repo（不得污染 CardMind）：

19. 安装/复制 hook 后执行真实 `git commit`，证明 pre-commit 能通过 Dart 入口被调用；
20. 配置本地 bare remote，执行真实 `git push`，证明 pre-push 能读取 stdin 并通过 Dart 入口被调用；
21. `SKIP_LOCAL_CHECK=1` 两个 Hook 都可跳过；
22. Dart gate 非零时 commit/push 确实被 Git 阻止。

真实 Hook 测试必须提供 test mode/fake runner，禁止在临时 repo 里执行 CardMind 全量测试。

## 六、文档与引用

更新：

- `docs/standards/testing.md`：四层测试门禁（widget、真实 FRB、平台集成、双实例 E2E）及 commit/push/release 执行阶段；
- `docs/standards/git-and-pr.md`：pre-commit / pre-push 分层、format-first、跳过变量及风险；
- `tool/README.md`：Dart gate CLI；
- 仓库中所有 `scripts/check.sh` 引用改为对应 Dart 命令。

不得把实现细节复制进产品文档。

## 七、验收命令

所有命令单独设置 3 分钟硬上限；任何命令超过 3 分钟停下查因。

```text
# 无仓库自有 .sh
git ls-files '*.sh'
# 期望：空

# Dart 格式与分析
dart format --output=none --set-exit-if-changed tool test
dart analyze tool/git_gate.dart tool/src/git_gate test/git_gate_test.dart

# 选择器测试
flutter test --timeout 3m test/git_gate_test.dart

# 计划 smoke
dart run tool/git_gate.dart plan --files docs/standards/testing.md
dart run tool/git_gate.dart plan --files lib/pages/devices_page.dart
dart run tool/git_gate.dart plan --files rust-backend/src/sync.rs
dart run tool/git_gate.dart plan --files rust-backend/src/api.rs lib/src/rust/frb_generated.dart
dart run tool/git_gate.dart plan --files unknown.file

# Hook 真实启动测试
flutter test --timeout 3m test/git_gate_hook_integration_test.dart

# 快速门禁 dry-run（不得改业务文件）
dart run tool/git_gate.dart pre-commit --dry-run --files test/git_gate_test.dart

# 完整门禁 dry-run
dart run tool/git_gate.dart pre-push --dry-run

# 新 Dart gate 的 host full suite（真实执行一次）
CARDMIND_FORCE_FULL_CHECK=1 dart run tool/git_gate.dart full
```

最后一项只在 worktree 内容干净且 FRB 运行态产物可安全更新时执行。若当前环境无法执行，必须报告具体阻断，不得声称通过。

## 八、git 范围

允许修改：

```text
.githooks/pre-commit
.githooks/pre-push
scripts/check.sh（删除）
tool/git_gate.dart
tool/src/git_gate/**
test/git_gate_test.dart
test/git_gate_hook_integration_test.dart
tool/README.md
docs/standards/testing.md
docs/standards/git-and-pr.md
```

如现有 `test/build_tool_test.dart` 明确覆盖脚本入口，可最小调整；否则不得改。

禁止修改：

```text
lib/**（除任务未允许，全部禁止）
rust-backend/**
integration_test/**
prototype/**
pubspec.yaml / pubspec.lock
Cargo.toml / Cargo.lock
FRB 生成文件
平台 manifest/runner/plugin 文件
```

## 九、交付报告

`.workflow/executor-report.md`、`.workflow/review-report.md`、`.workflow/final-check.md` 必须明确：

- 是否仍有 tracked `.sh`；
- 两个真实 Git Hook 是否触发 Dart；
- formatter 是否先于任何检查；
- staged 分类矩阵逐项输出；
- pre-push 完整 suite 真实输出；
- 缓存命中和强制重跑证据；
- 所有 timeout 证据；
- 未执行的平台/E2E 项不得冒充通过；
- 未触碰签名配对 worktree和业务文件。
