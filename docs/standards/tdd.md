# TDD 规范

## 核心循环

- 代码变更优先采用 `Red -> Green -> Blue -> Verify` 循环
- `Red`：先新增或调整检查，并确认其按预期失败
- `Green`：用满足检查的最小实现让验证通过
- `Blue`：在验证持续通过的前提下改善命名、结构与重复
- `Verify`：运行与改动范围匹配的最终验证后再交付或提交

若当前任务不适合严格按完整 TDD 顺序推进，必须说明原因，并补足与风险相称的验证证据。

## 适用范围

默认优先采用 TDD 的场景：

- 新功能
- bugfix
- 任何改变生产代码行为的改动
- Flutter、Rust、FRB、存储、同步等跨层契约改动

可以不执行完整 TDD 的场景：

- 文档-only 改动
- 纯索引维护
- 纯格式化
- 不影响行为的机械性脚本或配置修正

如任务看似机械，但实际改变了行为或验证边界，应立即切回完整 TDD。

## 测试与验证要求

- 新功能和 bugfix 必须覆盖成功路径与失败路径
- TSX 前端测试放在 `nsh-app/`（根级 `*_test.ts`）与 `nsh-app/web/src/`
- Rust 集成测试放在 `rust-backend/tests/`
- 最终验证命令应覆盖受影响范围，常见命令包括：`npx tsx --test`（在 `nsh-app/`）、`cargo test`、`dart run tool/git_gate.dart plan --staged`
- 若未采用严格的 `Red -> Green -> Blue` 顺序，最终交付时应明确说明原因、补充的验证手段以及仍然存在的风险

## 验证范围映射

- 文档改动：至少执行文档一致性检查与仓库级引用搜索（`dart tool/lint/markdown_references_linter.dart`）
- TSX 改动：至少执行 `cd nsh-app && npx tsx --test "*_test.ts" "web/src/*_test.ts"`
- Rust 改动：至少执行 `cargo test`，必要时加 `cargo fmt --check` 与 `cargo clippy`
- 门禁/工具改动（tool/**.dart）：至少执行 `dart run tool/git_gate.dart plan --staged`（计划无 flutter 步骤、有 rust+tsx）

验证不足时，不得宣称改动已经完成。
