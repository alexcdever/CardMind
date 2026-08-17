# Git 与 PR 规范

## 本地质量门禁（分层）

CardMind 的本地质量门禁由 `dart run tool/git_gate.dart` 统一实现，Git Hook 只做薄启动：

### pre-commit（快速相关门禁）

每次 `git commit` 执行：

1. **format-first**：先格式化全部源码（Dart `lib/ test/ integration_test/ tool/` + Rust `cargo fmt --all`），formatter 必须真的写入文件；
2. 若 formatter 改变了任何文件：立即阻止提交，输出改变路径，提示检查并重新暂存/提交，本轮不执行任何测试；**不自动 `git add`**，也不修改 index；
3. 按 staged 文件（`git diff --cached`）分类执行快速检查：文档走 markdown references lint；Dart/Flutter 业务文件走 `flutter analyze` + 相关测试；Rust 文件走 `cargo clippy -D warnings` + 相关 test target；FRB 边界改动（`lib/src/rust/**`、`rust-backend/src/api.rs`、`rust-backend/src/frb_generated.rs`）走真实 FRB smoke 集 + 相关 Rust 测试；manifest/共享配置/无法分类文件 fail closed，升级为对应技术栈全量 host 测试。

### pre-push（完整 host suite）

每次 `git push` 执行：

1. format-first（同上）；
2. 验证将测试的 tracked 源码与 HEAD 一致、且无未跟踪源码；不一致时阻止 push（避免测试工作树却缓存 HEAD）；
3. 从 stdin 读取 Git 传入的 ref 行；
4. 完整 host suite：markdown references lint → `cargo clippy --all-targets --all-features -- -D warnings` → `cargo test --all-features --jobs 1` → 构建运行态 host Rust 库（`cargo build --release` 后同步到运行态路径；Windows `build/windows/x64/runner/Release/cardmind_backend.dll`，macOS `build/native/macos/libcardmind_backend.dylib`，Linux `build/linux/x64/release/bundle/lib/libcardmind_backend.so`；不再调用 `dart run tool/build.dart lib`）→ `flutter_rust_bridge_codegen generate`（生成内容变化则阻止，要求提交生成结果）→ codegen 后再次 format-first（改变则阻止）→ `flutter analyze` → `flutter test --timeout 3m`；
5. 成功后按 exact HEAD SHA 写入 `.git` 内缓存；满足 HEAD/fingerprint/push SHA 集一致且工作树干净时跳过完整 suite（format-first 与一致性检查始终执行）。

平台集成测试（`integration_test/`）、双实例 relay E2E、Android/Windows 平台运行、coverage/tarpaulin 不塞入普通 pre-push，由任务验收或发布门禁执行。

### 跳过变量与风险

- `SKIP_LOCAL_CHECK=1 git commit` / `git push`：跳过门禁（输出中会明确说明）。**谨慎使用**——跳过意味着绕过全部本地质量检查，风险自担。
- `CARDMIND_FORCE_FULL_CHECK=1 git push`：强制忽略 pre-push 缓存，重新执行完整 suite。
- 每个外部检查/测试进程都有 3 分钟硬超时；超时终止进程树并以非零退出，不会无限等待。
- format-first 会改写工作树文件：若被阻止，请检查改动、重新暂存后重试。

## 提交规范

- 提交信息使用清晰前缀，如 `feat(scope):`、`fix(scope):`、`docs:`、`refactor:`、`test:`
- 提交说明应表达变更意图，优先说明为什么改，而不是只列文件操作
- 单个提交应保持单一意图，避免把无关改动混在一起

## PR 说明要求

- PR 必须说明变更目标、主要改动、验证结果与剩余风险
- 涉及 UI 变化时附截图或录屏
- 涉及 Flutter/Rust/FRB 契约变化时，明确受影响边界与验证证据
- 涉及规格变化时，引用对应 `docs/specs/` 或 `docs/plans/`

## 合并前检查

- 只提交与当前任务相关的变更
- 验证命令与结果需和改动范围匹配
- 若存在未解决风险或未执行的检查，必须在交付或 PR 中明确说明
