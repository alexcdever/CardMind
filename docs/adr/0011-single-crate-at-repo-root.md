# ADR 0011 — Rust 内核单 crate，源码在仓库根

- **日期**：2026-11-26
- **状态**：已采纳
- **决策者**：@alexc

---

> 来源：`docs/archive/migration-nsh.md`、[ADR 0010](0010-ui-runtime-flutter-to-nsh.md)（UI 运行时换 NSH 后，
> Rust 内核的存放位置成为遗留问题）；内核边界与前史见 [ADR 0002](0002-rust-single-backend-core-multi-entry.md)、
> [ADR 0005](0005-rust-runtime-library-single-path.md)。
> 这两份 ADR 记录的是 Flutter 时代的判断，本文**不修改**它们，只登记现状变更。

## 背景

`2026-11` 之前，仓库有两个 Rust crate：

| crate | 位置 | 角色 | 形态 |
|---|---|---|---|
| `cardmind-backend` | `rust-backend/` | LoroDoc + SQLite + iroh + mDNS 内核 | 独立 workspace，`edition 2021` |
| `nsh-app-cardmind` | `nsh-app/` | NSH 原生模块（`#[native_module("app/native")]`）外壳 | 独立 workspace，`edition 2024` |

两者的关系是 `nsh-app/Cargo.toml` 里一行 path 依赖
（`cardmind-backend = { path = "../rust-backend" }`）。这个形态继承自 Flutter 时代：
当时前端是 Dart，后端必须编成动态库经 `flutter_rust_bridge` 加载，**crate 边界就是 FFI 边界**，
谁也不能把内核源码直接编进前端进程（[ADR 0005](0005-rust-runtime-library-single-path.md) 的
「运行态动态库唯一路径」就是为那条链路定的）。

[ADR 0010](0010-ui-runtime-flutter-to-nsh.md) 把 UI 换成 NSH 之后，这个前提消失了：NSH 原生支持
Rust——`nsh.json` 的 `rust` 字段直接指向一个 crate，`nsh check` / `nsh package` 把它的
`#[native_module]` 编进应用二进制，没有动态库、没有 FFI 边界、没有绑定生成。

于是两个 crate 的代价开始全部落在「没有收益的那一半」：

- **两套构建产物**：`rust-backend/target/` 与 `nsh-app/target/`（本机实测前者 13.7 GB），
  同一批依赖（loro、iroh、rusqlite…）各编一遍。
- **两份锁文件**：`rust-backend/Cargo.lock` 与 `nsh-app/Cargo.lock` 会各自解析出不同版本
  （合并前实测 loro 两处都是 1.x 但锁到不同 patch），依赖告警要修两遍。
- **两个 workspace，两套 edition/feature/lint 口径**：内核留在 2021，外壳在 2024，
  clippy 的 `let-chains`、`gen` 关键字等新规则只在外壳生效，边界处的规则因此长期不一致。
- **路径依赖把两侧绑成隐式耦合**：内核改动必然牵动外壳重编，但门禁的 `workingDirectory`
  只指向 `rust-backend`，`nsh-app` 侧的 Rust 检查靠 `nsh check` 兜底——两个门禁各自只看到一半。
- **文档与工具里到处都是 `cd rust-backend`**：门禁 5 条 Rust 命令、3 个 CI workflow、
  5 个 TSX 测试、markdown linter 的构建产物前缀，全是「因为有两个 crate」而存在的转录成本。

## 决策

**把 `rust-backend/` 整体并入 `nsh-app/`，仓库只保留一个 Rust crate（`nsh-app-cardmind`，
edition 2024）。**

1. **内核源码进 `nsh-app/src/kernel/`**：`store.rs`、`sync.rs`、`discovery.rs`、`qr.rs`、`debug_log.rs`
   原样搬入（`src/backend/` 已占用 store/sync 这两个名字，故加 `kernel/` 一级）。
   模块内容不变，只改 4 处 `crate::` 路径与 12 处外壳侧引用。
2. **集成测试进 `nsh-app/tests/`，example 进 `nsh-app/examples/`**：21 个 test target +
   `tests/common/mod.rs` 与既有的 `coexist_notes_probe.rs` 并列；测试内 `use cardmind_backend::…`
   改为 `use nsh_app_cardmind::kernel::…`（外部 crate 视角，不能用 `crate::`）。
3. **两侧 manifest 合流**：内核的依赖全集、`test-utils` feature、`[profile.release] strip = true`
   并入 `nsh-app/Cargo.toml`；`tokio` 的 `["sync"]` 与 `["full"]` 取并集（`full`）；
   `[dev-dependencies]` 的自引用改名为 `nsh-app-cardmind = { path = ".", features = ["test-utils"] }`
   ——`tests/*.rs` 是独立 crate，这条自引用是让测试拿到 `#[doc(hidden)]` 后门的既有机制，机制不变。
4. **锁文件由 cargo 在 `nsh-app/` 重新生成**，不手工合并两份 lock。
5. **门禁与 CI 的 Rust 步骤统一指向 `nsh-app`**：`cargo fmt` / `clippy` / `test` / `build --release`
   的 `workingDirectory` 全部改为 `nsh-app`；`rust_quality.yml` 的 `paths` 收窄到
   `nsh-app/src|tests|examples/**` + `nsh-app/Cargo.toml|Cargo.lock`，**不写 `nsh-app/**`**
   （那会与 `nsh_app.yml` 完全重叠，同一次 push 触发两条重复流水线）。
6. **内核边界改由源码断言守护**：原先「内核不能依赖 `nsh-core` / `JsObject`」由 crate 边界天然成立；
   合并后这条约束落在 `nsh-app/skeleton_test.ts`（`src/backend/` 不出现 `loro`/`iroh`/`mdns_sd`/`rusqlite`
   + manifest 仍有 `test-utils` 与自引用）与 `nsh-app/notes_sync_pairing_test.ts`
   （`src/kernel/{store,sync}.rs` 不出现 `nsh_core` / `nsh-core` / `JsObject`）两处断言上。
7. **历史文档不改**：`docs/adr/` 下的 0002、0005、0006、0007、0008 五份 与 `docs/archive/**` 里的 `rust-backend/…`
   是历史记录，正文保持原样；改由 markdown linter 的 `deletedHistoryPrefixes` 增列 `'rust-backend/'`
   整体前缀来豁免（并删掉被它覆盖的三条窄前缀与 `buildOutputPrefixes` 里的 `'rust-backend/target/'`）。

## 拒绝的方案

### 方案 B：保持双 crate，只统一依赖解析

做法：两侧都加 `[patch]` / 共享 `[workspace.dependencies]` 主 workspace，把 loro、iroh、rusqlite
等锁到同一版本；`rust-backend/` 继续做独立 crate。

- 优点：crate 边界仍在，内核的「不得依赖外壳」约束不用另找机制；改动面最小。
- **拒绝理由**：它只解决「版本漂移」，不解决「为什么要编两遍」。合并的真正收益是构建产物、
  锁文件、edition/lint 口径各只剩一份，而这些在双 crate 下**结构上无法获得**；
  引入 workspace 继承反而新增第三层 manifest，把「两个 crate 为什么必须分开」这个已经过时的前提
  固化下来。代价（13.7 GB 重复构建、两套门禁只看半边）与收益不成比例。

### 方案 C：内核留 `rust-backend/`，外壳继续 path 依赖

即维持现状不动。

- 优点：零改动、零风险。
- **拒绝理由**：NSH 已经把 FFI 边界消除（`rust: '.'` 指 `nsh-app`），继续留一个只为「Flutter 时代
  动态库」存在的 crate 就是纯历史包袱；且它使 `cargo test` / `cargo clippy` 无法一次覆盖全部
  Rust 代码（要跑两次，工作目录不同），门禁的分层与 CI 的 `paths` 都因此复杂化。

## 后果

**正面**：

- **单 `target/`、单 `Cargo.lock`**：一次 `cargo test --all-features --jobs 1` 覆盖内核 187 +
  coexist 探针 1 = 188 项，一次 `cargo clippy --workspace` 覆盖全部 Rust 代码。
- **edition 统一在 2024**：内核源码搬入时暴露并修掉 3 类破坏（`rng.gen()` 关键字冲突 2 处、
  clippy `collapsible_if` 4 处、`cargo fmt` 的 import 排序），此后新规则对所有 Rust 代码一致生效。
- **门禁与 CI 简化**：5 条 Rust 命令、3 个 workflow、`rust_quality.yml` 的 `paths` 都只剩一个目录口径；
  `nsh_app.yml` 可以删掉 `'rust-backend/**'` 这个只为触发配套流水线而存在的条目。
- **文档只有一处真相**：`AGENTS.md` / `README.md` / 技术栈基线里的「去哪跑 cargo」不再有歧义。

**代价与新增验证面**（必须如实记账）：

- **crate 边界没了，内核纯度变成「断言出来的」**：`src/kernel/` 里任何代码现在都能 `use nsh_core::*`，
  只有 TSX 测试会拦（`notes_sync_pairing_test.ts`）。这是**弱于编译期保证**的机制；
  新增内核模块时要同步补断言，否则约束会被悄悄绕过。
- **`cargo test` 变重**：内核测试与外壳 crate 同一次编译，任一 tests 目标编译失败都会挡住全部 Rust 测试
  （原先 `rust-backend` 编不过时至少 `nsh-app` 侧不受影响）。缓解：`--jobs 1` 与 sccache 已在本机/CI 生效。
- **`nsh check` 与 `cargo check` 的职责重叠增加**：两者现在编同一个 crate，冷启动耗时叠加
  （本机实测 `nsh check .` 冷 ≈ 8 分钟，含 crate 构建）。
- **`rust_quality.yml` 的每个测试都编译 NSH 依赖**（`nsh-core`/`nsh-base`）：CI 的 Rust 质量流水线
  从此需要 NSH 工具链可获取，不再是「纯 Rust 仓库即可跑」。这是合并的直接后果，不是缺陷。

## 非目标

- 不改内核业务逻辑（读写分离、LoroDoc 唯一信源、iroh 直连、配对凭据协议均不变）；
- 不改测试断言的**产品语义**（只改导入路径与「旧目录不存在」这类结构断言）；
- 不合并 TSX 外壳与内核的模块划分（`src/backend/` 仍是唯一对 TSX 暴露的接缝）；
- 不引入多入口（HTTP/MCP/CLI）——[ADR 0002](0002-rust-single-backend-core-multi-entry.md) 的方向仍未被采纳。

---

## 2026-11-26 追加：nsh-app/ 层摊平到仓库根

本 ADR 通过之后不久，`nsh-app/` 目录层被整体移除：TSX 页面/组件、`src/`（含 `src/kernel/`
与 `src/backend/`）、`tests/`、`examples/`、`Cargo.toml`、`Cargo.lock`、`nsh.json`、
`package.json`、`tsconfig.json`、`build-nsh.mjs`、全部 `*_test.ts`/`*.test.tsx` 经 `git mv`
平移到仓库根（历史保留）；`nsh-app/` 目录不复存在，连同 `spike/` 探针目录一并删除
（`nsh test` 会递归编译其中的用例，且未跟踪）。

- **动机**：`nsh-app/` 是 Flutter 时代留下的最后一层目录壳——Flutter 链已整删、`rust-backend/`
  已并入，它只剩「前端在子目录」的历史语义。`nsh check/build/package/test/run` 只认 cwd，
  `rust: "."` 语义是「与本文件同目录的 crate」，扁平化后该值不变。唯一硬约束是 `nsh test`：
  它从仓库根递归发现所有 `*.test.ts(x)` 且 `--filter` 挡不住编译错误，故 `spike/`（内含
  `nsh-editor-md-probe` 的 `.test.tsx` 探针）一并删除，历史引用由 linter 豁免兜住。
- **被否掉的做法**：保留中间层（如改名 `app/`）只是换个名字——目录层级本身的转录成本
  （门禁 `workingDirectory`、CI `paths`、文档里的 `cd nsh-app`）一分不少，无收益。
- **crate 仍只有一个**：`nsh-app-cardmind`，只是位置从 `nsh-app/` 变为仓库根；`nsh.json` 的
  `rust = '.'` 指向根 `Cargo.toml`，内涵不变。
- **门禁与 CI 目录口径再次归零**：`tool/src/git_gate/` 的 `workingDirectory` 全部改为仓库根；
  三个 workflow 去掉 `working-directory: nsh-app` / `cd nsh-app`，`paths` 收窄到根级源码目录
  + manifest；markdown linter 的构建产物前缀改为 `target/`、`.nsh/`、`out/`，已删除历史前缀
  新增 `'nsh-app/'` 与 `'spike/'`。
- **本 ADR 正文中的 `nsh-app/…` 路径**（如 `nsh-app/src/kernel/`、`nsh-app/tests/`）是合并时刻
  的真实布局，保留为历史叙述；当前等价物是去掉 `nsh-app/` 前缀的同路径（`src/kernel/`、
  `tests/`、…）。
- **本文文件名随之改为 `0011-single-crate-at-repo-root.md`**；ADR 0005、0010 及更早文档中的
  `nsh-app/` 引用与 `docs/archive/**` 一样保持原样，由 linter 的 `deletedHistoryPrefixes`
  豁免。
