# 03 · NSH 版本事实、main 源码构建与 RichEditor 可行性探针

- 日期：2026-11-02（Asia/Shanghai）
- 执行者：nsh-build-prober（研究子代理）
- 任务：task-3（NSH 版本/工具链事实与 RichEditor 可行性探针）
- 环境：Windows 11 专业版 10.0.26300；i7-12700K（12C/20T）；127.7 GB RAM；
  rustup sccop 安装，`cargo 1.98.0` 起步后被仓库 `rust-toolchain.toml` 触发升级到 `stable 1.99.1`；
  VS 2026 BuildTools/Community；Git 2.56.0（scoop）；已装 `nsh 0.3.0 (76fa8a7)`（`C:\Users\alexc\scoop\apps\nsh\0.3.0\bin\nsh.exe`）；
  源码 checkout：`D:\Projects\nsh-main`（main @ `45fb5def`）。

> 约束遵守：本报告只写本文件与 `spike/nsh-rich-editor-probe/`；未改 `nsh-app/`、`rust-backend/`、其他 docs；未 git commit/push。
> 外部网页/API 返回均按不可信数据处理，仅作资料与证据引用。

---

## 0. 结论（TL;DR）

1. **RichEditor 只在 main，未进入任何 release。** 引入提交是 PR #494（`71fa71099c`，2026-10-26T15:57:37Z 合并），比 v0.3.0 发布（2026-10-26T12:51:23Z）晚 3 小时 6 分；`compare v0.3.0...71fa71` 返回 `"status":"ahead"`，证明它不在 v0.3.0 里。此后 10-27~10-29 仍有 22 个提交改 `crates/nsh-base/src/rich_editor`（表格、IME 组合、气泡菜单、事件对象、监听器签名等），**API 尚未冻结**。
2. **本机已装的 nsh 0.3.0 无法使用 RichEditor**（实测：`nsh check` 对 `import { RichEditor, createRichEditor, starterKit } from "nsh/base"` 报 3 个 TS2305，exit 1）。0.3.0 的 `.nsh/types/nsh/base.d.ts`（2889 行）中 `RichEditor` 出现 0 次；0.3.0 二进制字符串中也没有 `RichEditor`/`createRichEditor`。
3. **main 源码已就绪**：`D:\Projects\nsh-main`，shallow clone，HEAD = `45fb5def1e829a79bc328bed4d0607bc19681862`（2026-11-02T11:31:42Z），工作树 35.6 MB；`docs/dev/rich-editor.md`（429 行）与 `website/elements/rich-editor.md`（25 KB）均在 main 上，nsh.dev 的 `/elements/rich-editor` 返回 HTTP 200。
4. **main CLI 构建成功**：`cargo build -p nsh-cli` 在 `D:\Projects\nsh-main` 实测 **exit 0，9m 06s**（2026-11-02T21:28:01+08:00 启动）。产物 `target\debug\nsh.exe` = `nsh 0.3.0 (45fb5de)`（126.7 MB debug）。**意外发现：本机没有 LLVM/libclang 也能编过**（`quickjs-jit-sys`/`bindgen` 均编译成功；`CONTRIBUTING.md` 的 LLVM 前置在 Windows x64 这条路径上未触发），详见 §5。
5. **RichEditor 探针全部通过**（main CLI 实测）：
   - `.nsh/types/nsh/base.d.ts`（5995 行，0.3.0 是 2889 行）含 RichEditor 相关 52 处，导出 `RichEditor`、`createRichEditor`、`starterKit()`、`class StarterKit`、`class TableKit`；
   - `nsh check .` exit 0（1.4 s）；`nsh build .` exit 0（0.9 s，960 B js + 1994 B bytecode）；
   - `nsh test .` exit 0，**2 tests: 2 passed**（539 ms）：headless 渲染 markdown 后 `app.texts()` 能取到标题/列表文本，`createRichEditor` 的 `doc.type === "doc"`、`isEmpty === false`。
6. **测试路径可行（0.3.0 与 main 均实测）**：`nsh test` 在 Windows 上 headless 跑最小 TSX app：0.3.0 `✓ 1 test: 1 passed`（0.5 s）；main CLI 跑 RichEditor 探针 `✓ 2 tests: 2 passed`（1.2 s）。不需要 host runtime；但测试文件必须 import `nsh/test`（现有 `npx tsx --test` + `node:test` 测试不能直接复用）。
7. **真实窗口也跑通了**：`nsh run --target windows` 先构建 host（`cargo build -p nsh-windows-host`，**2m 44s**），随后 `nsh-windows-host.exe` 开窗、`• Windows (WIN) connected, build 1`；用 `PrintWindow` 截图确认 RichEditor 渲染出 markdown 的标题/段落/列表文本（`spike/nsh-rich-editor-probe/logs/rich-editor-printwindow.png`）。**但 RichEditor 默认无样式**（标题不放大、列表无可见 marker/缩进），CardMind 必须自带 node/mark 样式。两个可复现性前提：固定 `RUSTUP_TOOLCHAIN`、并让 nsh 内部 cargo 走镜像（§5.6）。
8. **最短可用路径（已验证）**：main checkout 里 `cargo build -p nsh-cli`（9 min）→ `target\debug\nsh.exe init/check/build/test`；RichEditor 由 CLI 自带 UI set（nsh-base）提供，**不需要 CardMind 自己的 Rust crate 升级**即可跑 TSX 探针。

---

## 1. 查证方法总览

| 事实 | 方法 | 证据 |
|---|---|---|
| releases / tags | GitHub REST API | `https://api.github.com/repos/longbridge/nsh/releases?per_page=20`；`/tags?per_page=30` |
| main HEAD 与时间 | GitHub API + 本地 checkout | `GET /repos/longbridge/nsh/commits/main?per_page=1`；`git -C D:\Projects\nsh-main log -1 --date=iso-strict` |
| RichEditor 引入提交 | GitHub commits API 按路径 + commits 搜索 | `GET /commits?sha=main&path=crates/nsh-base/src/rich_editor&per_page=30`；`GET /search/commits?q=repo:longbridge/nsh+RichEditor`；`GET /pulls/494` |
| 是否进过 release | compare API 祖先判定 | `GET /repos/longbridge/nsh/compare/v0.3.0...71fa71099cd...` → `"status":"ahead"`；`compare/v0.3.0...main` → `ahead_by=267, behind_by=0` |
| 0.3.0 是否含 RichEditor | 本机 0.3.0 CLI 生成类型 + `nsh check` + 二进制字符串扫描 | 见 §4 |
| 文档状态 | 本地 main checkout 的 `docs/`、`website/` + nsh.dev HTTP | `website/elements/rich-editor.md`；`https://nsh.dev/elements/rich-editor` → HTTP 200 |
| 兼容承诺 | `longbridge/nsh-compat` README | "No release is recorded yet: nothing is frozen." |
| 源码获取 | SSH git clone（Lead 完成，本代理核验）；HTTPS codeload 备选实测 | 见 §3 |
| 构建 | 本机实测 `cargo build -p nsh-cli` | 见 §5 |

---

## 2. 版本事实（带时间戳）

### 2.1 Releases（GitHub API，`published_at` 原样 UTC）

| tag | published_at | 名称 |
|---|---|---|
| `v0.3.0` | `2026-10-26T12:51:23Z` | nsh v0.3.0 |
| `v0.2.0` | `2026-10-22T03:29:35Z` | Native Shell v0.2.0 |
| `v0.1.1` | `2026-10-18T06:25:06Z` | nsh v0.1.1 |
| `v0.1.0` | `2026-10-17T12:18:51Z` | nsh v0.1.0 |

tags（`GET /tags?per_page=30`，仅这 4 个）：

```
v0.3.0  76fa8a7fed47ea51aea01fa85bb40960be15d984
v0.2.0  669b62b11449b2ab787b7c82649a392cbff25b8f
v0.1.1  85be2a2e34ab4879acfa74bde3c5bbdc3cc737d0
v0.1.0  3ef38f5f372d6df04f1746439d6ad974878c2bb2
```

v0.3.0 的 tag 指向 `76fa8a7`（提交信息是 `base: Let nsh-base publish before nsh-js (#497)`，**不是** release-prep PR #496 本身），因此判断"是否进 release"必须以 `compare` 祖先关系为准，不能只看日期或 tag 名。

### 2.2 main HEAD（本地核验）

```
$ git -C D:\Projects\nsh-main log -1 --date=iso-strict --format='%H%n%cd%n%s'
45fb5def1e829a79bc328bed4d0607bc19681862
2026-11-02T19:31:42+08:00
text: Grow a line for an inline view taller than the line height on Apple (#810)
```

（即 `2026-11-02T11:31:42Z`；与 `https://github.com/longbridge/nsh/commits/main.atom` 的 `<updated>2026-11-02T11:31:42Z</updated>` 一致。）

### 2.3 RichEditor 是什么时候、怎么进 main 的

```
$ curl https://api.github.com/repos/longbridge/nsh/pulls/494
number           : 494
title            : base: Add RichEditor, a ProseMirror-style rich text editor
state            : closed
merged_at        : 2026-10-26T15:57:38Z
created_at       : 2026-10-26T09:26:56Z
base             : main
merge_commit_sha : 71fa71099cde1dfa2c48ef1e0d97a028b9698df9
user             : huacnlee
html_url         : https://github.com/longbridge/nsh/pull/494
```

提交本身的 committer date：`2026-10-26T15:57:37Z`。

**关键判定**：v0.3.0 发布 `2026-10-26T12:51:23Z`，PR #494 合并 `2026-10-26T15:57:38Z`，**晚 3h06m**。
直接祖先验证：

```
$ curl https://api.github.com/repos/longbridge/nsh/compare/v0.3.0...71fa71099cde1dfa2c48ef1e0d97a028b9698df9
"status":"ahead"
```

→ `71fa71099c` 在 `v0.3.0` 之后（ahead），**不在 0.3.0 里**。

`compare/v0.3.0...main`：`"status":"ahead"`，`ahead_by=267`，`behind_by=0`（0.3.0 之后 main 累积 267 个提交，无回退）。

### 2.4 RichEditor 之后仍在变（说明 API 未冻结）

`GET /commits?sha=main&path=crates/nsh-base/src/rich_editor&per_page=30` 返回 **22** 个提交（shallow checkout 中该目录 100 个文件）。摘录：

| 提交 | 日期 (UTC) | 主题 |
|---|---|---|
| `71fa71099c` | 2026-10-26T15:57:37Z | base: Add RichEditor, a ProseMirror-style rich text editor (#494) |
| `d9e52f2dd7` | 2026-10-26T16:23:33Z | base: Rename the rich editor's TextStyle extension to RichTextStyle (#515) |
| `0d385b2abf` | 2026-10-26T16:24:07Z | base: Fix RichEditor's list commands and add a bubble menu (#516) |
| `ad7aadd5a3` | 2026-10-26T19:54:42Z | base: Pick RichEditor's Mac or PC keys by the platform it runs on (#523) |
| `2d7d52d81b` | 2026-10-27T02:29:44Z | base: Keep an input method's composition out of RichEditor's document until it commits (#543) |
| `03384ede37` | 2026-10-27T02:25:52Z | base: Add tables to RichEditor, with merged cells, resizing and reordering (#518) |
| `857f9a987f` | 2026-10-27T04:04:24Z | base: Keep text typed again after RichEditor's caret moves (#555) |
| `e87d5b5f04` | 2026-10-27T08:57:31Z | core: Pass every event one object (#558) |
| `6ef7b54a42` | 2026-10-28T01:54:57Z | base: Keep a paste over the whole document under a character limit (#569) |
| `7a989f7a30` | 2026-10-28T05:40:14Z | core: Return objects, and give each element a ref type of its own (#593) |
| `186ada8558` | 2026-10-28T09:39:55Z | core: Make every listener `on(event, l)` returning a stop function (#612) |
| `5d4b416fbd` | 2026-10-28T17:43:35Z | core: Report every failure of what JS calls one way, with a stable code (#651) |
| `5585f498e5` | 2026-10-28T15:35:01Z | base: Name a rich editor's document JSON `getJSON`, as Tiptap does (#658) |
| `78f85f60d9` | 2026-10-28T16:11:03Z | base: Add `Link`, which opens its `href` or lets the app route it (#624) |
| `d77fb795cf` | 2026-10-29T04:14:31Z | rich_editor: Show compositions in the line, with steady candidates (#686) |

注：GitHub commits 列表按文件路径过滤，可能漏掉只改 `nsh-base` 其它文件但影响 JS 面的提交；上表足以证明 10-27~10-29 API 仍在改。

### 2.5 兼容承诺：`nsh-compat` 尚为空

- v0.3.0 release notes 原文："The compatibility baseline is still being prepared; 0.3.0 is not a frozen compatibility release."
- `longbridge/nsh-compat` README 原文："**No release is recorded yet: nothing is frozen.**"（仓库内容：`Cargo.toml`、`closed.txt`、`src/`、`README.md`）
- 含义：即使将来 0.4.0（或含 RichEditor 的版本）发布，也要看它是否被记录进 nsh-compat；目前"RichEditor 能否稳定跨版本"没有上游承诺。

### 2.6 下一版是否已知

**待验证/无公开证据**：GitHub 只有 v0.3.0 一个最新 release，无 roadmap/里程碑文档说明下个版本号与日期。发布节奏参考：v0.1.0(10-17) → v0.1.1(10-18) → v0.2.0(10-22) → v0.3.0(10-26)，大约 1–6 天/版，但 0.3.0 之后已过 7 天且 RichEditor 仍在迭代，**不能据此预测**。

---

## 3. 源码获取（方法与耗时）

| 方法 | 结果 | 证据/耗时 |
|---|---|---|
| SSH `git clone --depth 1 git@github.com:longbridge/nsh.git` | ✅ 成功（Lead 执行，本代理核验） | `D:\Projects\nsh-main`；`.git/shallow` 只含 `45fb5def...`；工作树 35.6 MB；`git describe --tags --always` → `45fb5de` |
| SSH `git ls-remote git@github.com:longbridge/nsh.git refs/heads/main` | ✅ 7.8 s，exit 0 | 输出 `45fb5def1e829a79bc328bed4d0607bc19681862` |
| HTTPS clone | ❌ 本机 TLS 失败（Lead 既有事实，未重复尝试） | — |
| `https://codeload.github.com/longbridge/nsh/tar.gz/refs/heads/main` | ✅ 可用但慢：HTTP 200；实测约 23 KB/s（65 s 只下 1.5 MB），在 SSH clone 完成后主动中止 | `curl -sSI -L` 返回 200；后台下载任务已 kill |
| `raw.githubusercontent.com` | ✅ 可用（拉 README/CONTRIBUTING/rust-toolchain.toml 用于前置调查） | exit 0 |

结论：**本机获取 main 源码的可靠方法是 SSH clone**；HTTPS/codeload 只适合小文件或兜底。

---

## 4. 已装 nsh 0.3.0 实测（RichEditor 负向验证 + 测试路径）

### 4.1 版本与命令面

```
$ C:\Users\alexc\scoop\apps\nsh\0.3.0\bin\nsh.exe --version
nsh 0.3.0 (76fa8a7)
exit 0
```

`nsh init --help` 摘要：`--template` 取值 `ts` / `rust` / `mixed`；`--nsh-source <DIR>` 只在 `rust`/`mixed` 下有效（"depend on the nsh crates of this checkout by path, instead of crates.io's at this CLI's version"）。

### 4.2 0.3.0 生成的类型没有 RichEditor

```
$ nsh init app --template ts
✓ created app: .gitignore, App.tsx, App.test.tsx, tsconfig.json, nsh.json
init exit=0
```

生成 `.nsh/types/` 文件：`nsh/index.d.ts`、`nsh/base.d.ts`、`nsh/base/plot.d.ts`、`nsh/mobile.d.ts`、`nsh/desktop.d.ts`、`nsh/test.d.ts`、`nsh/types.d.ts`、`nsh/globals.d.ts`、`nsh/jsx-runtime.d.ts`、`nsh/tokens.d.ts`、`nsh/assets.d.ts`、`standard/*`、`fs/promises.d.ts`、`net.d.ts`、`os.d.ts`、`process.d.ts`、`websocket.d.ts`。

- `nsh/base.d.ts` 共 2889 行，`RichEditor` 出现次数 **0**；有 `Editor`/`DiffView`（0.3.0 的代码编辑器，不是富文本）。
- 二进制字符串扫描 `nsh.exe`（49,730,048 B）：`RichEditor` / `createRichEditor` / `starterKit` 均 **not found**；只有 `NSH_SOURCE`（见 §7.2）。

### 4.3 `nsh check` 复现 TS2305（0.3.0 负向定论）

探针文件（`spike/nsh-rich-editor-probe/probe-030/App.tsx`）：

```tsx
import { mount, Text, View } from "nsh";
import { RichEditor, createRichEditor, starterKit } from "nsh/base";

const editor = createRichEditor({ extensions: [starterKit()], content: "# hello" });

function App() {
  return (
    <View class="flex-1">
      <RichEditor editor={editor} class="flex-1" />
      <Text>probe</Text>
    </View>
  );
}

mount(App);
```

```
$ nsh check .
App.tsx(2,10): error TS2305: Module '"nsh/base"' has no exported member 'RichEditor'.
App.tsx(2,22): error TS2305: Module '"nsh/base"' has no exported member 'createRichEditor'.
App.tsx(2,40): error TS2305: Module '"nsh/base"' has no exported member 'starterKit'.
error type check failed (exit code: 1)
=== nsh check exit=1 elapsed=0.4s ===
```

（`nsh check` 用 TypeScript 7 原生编译器，首次会自动下载 tsc；本机已缓存，故 0.4 s。）

### 4.4 `nsh test` 在 Windows 可用（与构建无关，纯运行时）

最小 0.3.0 模板 app（无 RichEditor）直接跑：

```
$ nsh test .
✓ bundled App.tsx (1115 B in 5.7 ms)
✓ App.test.tsx › counts taps (337ms)
✓ 1 test: 1 passed, 0 failed (356ms)
=== nsh test exit=0 elapsed=0.5s ===
```

结论：**headless 测试路径在 Windows 上不依赖 host runtime、不依赖 Rust 工具链**，这决定了后续 RichEditor 探针至少可以先用 `nsh test` 验证文档/命令/序列化行为（渲染效果仍需 host 或截帧）。

### 4.5 打包命令面（0.3.0）

- `nsh package --target <ios|ios-simulator|android|linux|macos|windows|web>`：用预构建 runtime 打包，"no Rust needed"；默认输出 `.nsh/out`。
- `nsh publish`：release 构建 + 签名成 `.nshpkg`（给嵌入 nsh 的宿主校验运行）。
- `nsh keygen` / `certify` / `verify` / `revoke`：签名体系命令。

---

## 5. main 构建探针（`cargo build -p nsh-cli`）

### 5.1 环境前置与修复过程（重要，含踩坑）

1. 仓库 `rust-toolchain.toml` 指定 `channel = "stable"` 且列出 7 个 cross target（aarch64-apple-darwin/ios 等）。在本 checkout 内直接跑 rustup/cargo 会**自动同步并安装这些 target**。
2. 首次 `rustup show`（我误用 `| Select-Object -First 20` 截断管道）在下载途中被终止，导致 stable 工具链处于**半安装状态**（`cargo.exe`/`rustc.exe` 丢失）。
   实测报错：`error: the 'cargo.exe' binary ... is not applicable to the 'stable-x86_64-pc-windows-msvc' toolchain`。
3. `static.rust-lang.org` 下载实测：
   ```
   static.rust-lang.org: http=200 size=943486 speed=50122 B/s time=18.8s   # 约 50 KB/s
   rsproxy.cn:           http=200 size=943486 speed=530792 B/s time=1.78s   # 约 530 KB/s
   mirrors.tuna:         http=200 size=844128 speed=224088 B/s time=3.77s
   ```
4. 用镜像修复：`RUSTUP_DIST_SERVER=https://rsproxy.cn`、`RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup`，
   `rustup toolchain install stable-x86_64-pc-windows-msvc --profile minimal`；随后所有命令固定
   `RUSTUP_TOOLCHAIN=stable-x86_64-pc-windows-msvc`，绕过 `rust-toolchain.toml` 的 iOS/Android target 安装。
5. 修复后核验：
   ```
   $ cargo metadata --no-deps --format-version 1   (cwd=D:\Projects\nsh-main)
   metadata exit=0 elapsed=0.2s
   ```
   工作区 28 个成员，`target_directory = D:\Projects\nsh-main\target`；`nsh-cli` v0.3.0。

### 5.2 平台依赖清单（本机实测 + 上游文档）

| 依赖 | 要求 | 本机状态 |
|---|---|---|
| Rust stable | 仓库 `rust-toolchain.toml` = stable（当前解析 1.99.1） | ✅ 已恢复（rsproxy） |
| VS C++ Build Tools + Windows SDK | `CONTRIBUTING.md` Windows 前置 | ✅ VS 2026 BuildTools/Community（18.11.12324.101），`cl.exe` 在 `...\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\cl.exe`（**不在 PATH**）；`link.exe` 同目录存在 |
| LLVM / libclang | `CONTRIBUTING.md`："For Windows (10 1809 or later): ... and LLVM (libclang, for QuickJS' bindings; found in `C:\Program Files\LLVM`, else set `LIBCLANG_PATH`)" | ❌ **未找到**：`C:\Program Files\LLVM` 不存在；`C:\Program Files (x86)\LLVM` 不存在；VS 18 两个安装的 `VC\Tools\Llvm` 下无 `libclang.dll`；scoop apps 无 llvm；`LIBCLANG_PATH` 未设。**但构建实测不需要它**（见 §5.4）：`quickjs-jit-sys 0.14.1`、`bindgen 0.72.1` 均编译成功，`cargo build -p nsh-cli` exit 0。结论：在这条 Windows x64 + 当前 feature 组合下，上游文档的 LLVM 前置**未触发**（待上游确认是否只在 Apple/Android 目标或重生成 bindings 时才需要） |
| QuickJS 绑定 | `crates/nsh-js/Cargo.toml`：非 wasm 目标 `rquickjs = { features = ["bindgen"] }`；`Cargo.lock` 有 `bindgen 0.72.1`、`quickjs-jit-sys 0.14.1` | ✅ 实测编译通过；`quickjs-jit-sys` 编 C 用的 MSVC `cl.exe` 由 cargo/cc 自动找到（不在 PATH 也可以） |

### 5.3 实际执行的构建命令（后台）

```powershell
$env:RUSTUP_TOOLCHAIN='stable-x86_64-pc-windows-msvc'
$env:RUST_MIN_STACK='268435456'          # 上游 CONTRIBUTING 对 windows crate 栈溢出的建议
cd D:\Projects\nsh-main
cargo --config 'source.crates-io.replace-with="rsproxy"' `
      --config 'source.rsproxy.registry="sparse+https://rsproxy.cn/index/"' `
      build -p nsh-cli
```

- 启动时间：`2026-11-02T21:28:01+08:00`（后台 job，日志：`spike/nsh-rich-editor-probe/logs/cargo-build-nsh-cli.log`）
- 依赖规模：`Cargo.lock` 共 751 个包，含 `rolldown 1.2.13`、整套 `oxc`、`wgpu`、`windows 0.62`、`quickjs-jit`、`syntect`、`image`、`zip`、`tar`。
- 依赖下载：约 70 s 下载 311 个包（rsproxy 稀疏索引），`target/` 尚未创建时即已开始。
- **构建结果：见 §5.4（写作时仍在进行，完成后更新本文件）**。

### 5.4 构建结果（实测成功）

```
=== cargo build exit=0 elapsed=547.1s ===
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 9m 06s
```

- 命令：§5.3；工作目录 `D:\Projects\nsh-main`；日志 `spike/nsh-rich-editor-probe/logs/cargo-build-nsh-cli.log`。
- **退出码 0，总耗时 9 分 06 秒（547.1 s）**；依赖下载约 2–3 min（546+ 个 crate 从 rsproxy），编译约 6–7 min。
- 产物：`D:\Projects\nsh-main\target\debug\nsh.exe`，132,857,856 B（126.7 MB，debug）。
- 版本：`nsh 0.3.0 (45fb5de)`（= main HEAD 短 hash，而非 tag 的 `76fa8a7`）。
- 二进制字符串扫描：`createRichEditor` / `RichEditor` / `starterKit` / `StarterKit` 均 **FOUND**（说明 main 的 nsh-base 被链进 CLI）。
- 磁盘代价：`target/` 约 **11.2 GB**（debug 构建 565 个 .d 依赖单元）。
- **没有安装 LLVM/libclang 也编过了**：`quickjs-jit-sys v0.14.1`、`bindgen v0.72.1` 都在编译列表里且无报错。原先按 `CONTRIBUTING.md` 推断的"Windows 必须 LLVM"在这条路径（Windows x64 主机、默认 features）上**不成立**——记录为实测反例；真要复现上游的 Apple/Android 交叉编译时是否触发，**待验证**。
- 唯一的环境事故：第一次 `rustup show` 被管道截断导致工具链半安装（§5.1），与 nsh 本身无关；修复后构建一次通过。

### 5.5 RichEditor 探针结果（main CLI，全部通过）

前置：`D:\Projects\nsh-main\target\debug\nsh.exe`；探针目录 `spike/nsh-rich-editor-probe/app-main/`。

1. `nsh init app-main --template ts` → exit 0，0.6 s；生成 `.nsh/types/`。
2. 类型生成：
   - `nsh/base.d.ts` 5995 行（0.3.0 为 2889 行）；`RichEditor|createRichEditor|StarterKit` 共 **52 处**。
   - 关键导出（原样）：
     ```
     export declare const RichEditor: ((props: RichEditorProps) => JSX.Element);
     export declare function createRichEditor(options?: RichEditorOptions | null): RichEditorSession;
     export declare function starterKit(): RichPluginSpec;
     export declare class StarterKit { ... }
     export declare class TableKit { ... }
     ```
3. 探针 `App.tsx`（markdown 初始内容）：
   ```tsx
   import { createRichEditor, RichEditor, StarterKit } from "nsh/base";
   const editor = createRichEditor({
     extensions: [StarterKit],
     content: "# CardMind\n\nRichEditor probe: **bold**, *italic* and a list\n\n- one\n- two",
     format: "markdown",
   });
   <RichEditor editor={editor} class="flex-1" placeholder="Write…" accessibilityLabel="Note editor" />
   ```
4. 实测：

   | 命令（cwd=`app-main`） | 退出码 | 耗时 | 输出摘要 |
   |---|---|---|---|
   | `nsh check .` | 0 | 1.4 s | 无错误（0.3.0 下同一 import 是 TS2305） |
   | `nsh build .` | 0 | 0.9 s | `✓ built App.tsx into .nsh\out (960 B js, 1.9 KB bytecode, 264ms)` |
   | `nsh test .` | 0 | 1.2 s | `✓ App.test.tsx › RichEditor renders markdown content (242ms)`；`✓ App.test.tsx › createRichEditor parses markdown into a document (9ms)`；`✓ 2 tests: 2 passed, 0 failed (539ms)` |

   `nsh test` 的断言（headless、无窗口）：`app.texts()` 包含 `"CardMind RichEditor probe"`（外层 Text）、`"CardMind"`（markdown `#` 标题）、`"one"`/`"two"`（列表项）；`createRichEditor(...).doc.type === "doc"`、`.isEmpty === false`。

→ **结论：RichEditor 在 main 上可用且可测**；TSX-only 应用不需要任何 Rust crate 升级。

### 5.6 `nsh run --target windows`（真实窗口渲染）——实测成功

2026-11-02T21:38:14 首次启动时踩坑（下方保留，作为可复现性经验）；最终成功的一次：

```
$env:RUSTUP_TOOLCHAIN='stable-x86_64-pc-windows-msvc'
# 且 checkout 的 .cargo/config.toml 配了 rsproxy 镜像（见下）
cd D:\Projects\CardMind\spike\nsh-rich-editor-probe\app-main
D:\Projects\nsh-main\target\debug\nsh.exe run . --target windows
```

stderr（原样）：

```
✓ built App.tsx (1.4 KB js, 3.7 KB bytecode, 23ms)
✓ built the development host for Windows (debug build) (1.3s)
• Windows (WIN) connected, build 1
```

进程与窗口（`Get-Process` / `Get-CimInstance Win32_Process`）：

```
nsh              pid=51296
nsh-windows-host pid=24152  MainWindowTitle=nsh  MainWindowHandle=4791544
命令：nsh-windows-host.exe --dev-server ws://127.0.0.1:8790/ws --app-id com.example.appmain
```

**真实渲染证据**：用 `PrintWindow(hwnd, hdc, PW_RENDERFULLCONTENT=2)` 截取窗口（窗口被其他窗口遮挡也能截到），
保存为 `spike/nsh-rich-editor-probe/logs/rich-editor-printwindow.png`（1213×836）。图中可见：

- 窗口标题栏 `nsh`；
- 外层 `<Text>` 的 `CardMind RichEditor probe`；
- RichEditor 渲染出的 markdown 内容：`CardMind`（`#` 标题块）、
  `RichEditor probe: bold, italic and a list`、`one`、`two`（列表项文本）。

**重要观察（对 CardMind 有价值）**：RichEditor 默认**不带样式**——`#` 标题没有放大、列表项没有可见的
`•` 标记/缩进（文档 `docs/dev/rich-editor.md` 也说明外观由 app 的 `classes` / `styles` / 主题 parts 决定，
view 自己的外观只有 caret/selection/placeholder/composition）。因此 CardMind 接入时必须提供一套
node/mark 的样式（类似 Tiptap 的 CSS），否则视觉上就是"无格式文本"。列表标记未见也可能是本探针没传
`classes.nodes.listMarker` 的样式；**待验证**（下一步可用 `classes` 注入样式后对比截图）。

#### 首次失败的教训（可复现性）

首次 `nsh run` 时 `nsh` 子进程是 `rustup.exe "cargo" build -p nsh-windows-host`，该子 `cargo` 继承不到外层固定的
`RUSTUP_TOOLCHAIN`，于是按仓库 `rust-toolchain.toml` 又触发 rustup 同步 stable + 7 个 cross target
（`static.rust-lang.org` ~50 KB/s），5 分钟无进展；`CARGO_NET_OFFLINE=true` 也不行（nsh 内部 cargo 用 crates.io 源，
与 rsproxy 缓存不匹配：`error: no matching package named 'wgpu-core' found / location searched: crates.io index`）。

**最终可行的两个环境前提**：

1. 固定 `RUSTUP_TOOLCHAIN=stable-x86_64-pc-windows-msvc`（避免每次触发 `rust-toolchain.toml` 的 target 安装）；
2. 让 nsh 内部 cargo 也走镜像：在 checkout 的 `.cargo/config.toml` 追加（本次已写入，原文件备份为
   `.cargo/config.toml.bak-probe`）：
   ```toml
   [source.crates-io]
   replace-with = "rsproxy"

   [source.rsproxy]
   registry = "sparse+https://rsproxy.cn/index/"
   ```
   之后 `nsh run` 的 host 构建只花 **1.3 s**（已缓存）。

### 5.7 `nsh-windows-host` 构建结果

- 命令（固定工具链 + 镜像）：
  ```powershell
  $env:RUSTUP_TOOLCHAIN='stable-x86_64-pc-windows-msvc'; $env:RUST_MIN_STACK='268435456'
  cd D:\Projects\nsh-main; cargo build -p nsh-windows-host
  ```
- **exit 0，2m 44s（164.4 s）**；日志 `spike/nsh-rich-editor-probe/logs/cargo-build-nsh-windows-host.log`。
- 产物 `target\debug\nsh-windows-host.exe` = 98,116,096 B（93.6 MB debug）；窗口成功打开（§5.6）。
- 这一步额外拉入 `wgpu/wgpu-core/naga/webview2-com/syntect` 等（nsh-cli 构建未需要的 host 依赖）；
  全部完成后 `target/` 约 **19.8 GB**。

---

## 6. RichEditor 源码事实（main @ 45fb5def）

### 6.1 位置与规模

- 内核：`crates/nsh-base/src/rich_editor/`，**100 个 .rs 文件**，分层：
  `model/`（Schema/Node/Fragment/Mark/Slice/ResolvedPos）、`transform/`（Step/StepMap/Mapping/Transform）、
  `state/`（EditorState/Transaction/Selection/plugins/decorations）、`commands/`（prosemirror-commands + list + tiptap 命令注册）、
  `extensions/`（history/keymap/input_rules/markdown/starter/kit/link/character_count/suggestion/tables 等）、
  `tables/`（prosemirror-tables 移植：TableMap、CellSelection、table_editing、fix_tables）、
  `formats/`（JSON / Markdown / HTML / PlainText，含 `markdown.rs` 44 KB）、
  `js/`（JS 桥：`mod.rs` 68 KB、`extension_api.rs` 34 KB、`plugins.rs` 35 KB、`tables.rs` 7.6 KB）、
  `view/`（原生视图：`controller.rs` 101 KB、`render.rs` 51 KB、`session.rs` 29 KB、`table.rs` 36 KB、`geometry.rs`）。
- 文档：`docs/dev/rich-editor.md`（429 行，本报告大量引用）；官网源码 `website/elements/rich-editor.md`（25 KB，main 上）。
- 上游文档定位：ProseMirror 的 Rust 移植 + Tiptap 扩展层（MIT，文档 §Credits 明示）；"logic is Rust, JS describes"。

### 6.2 JS API 表面（文档 + 源码交叉）

`docs/dev/rich-editor.md` 的示例（原文）：

```tsx
import { createRichEditor, RichEditor, history, keymap, inputRules, markdownRules, markdown, toggleMark } from "nsh/base";

const editor = createRichEditor({ schema, doc, plugins: [history(), keymap({ "Mod-b": toggleMark("bold") }), inputRules(markdownRules()), markdown()] });
editor.run(toggleMark("bold")); editor.can(toggleMark("bold")); editor.isActive("bold");
editor.dispatchTransaction = (tr) => editor.applyTransaction(tr);

<RichEditor editor={editor} class="…" />;
```

Tiptap 风格入口（文档 §Extensions）：

```tsx
createRichEditor({ extensions: [StarterKit.configure({ heading: { levels: [1, 2, 3] } }), Underline], content, editable })
```

对照源码 `crates/nsh-base/src/rich_editor/js/`：
- `createRichEditor` 返回 `RichEditorSession` 实例；`#[class]` 注册 `RichSchema`、`RichEditorSession`、`RichEditorPlugin`，`module::<RichEditorApi>`、`module::<tables::RichTableApi>`（`js/mod.rs:123-132`）。
- 内置扩展是**类**（`StarterKit`、`TableKit`、`Bold`、`Underline`、`RichImage`、`RichLink`、`RichTextStyle` 等），带 `configure` / `extend` 静态方法（`extension_api.rs`）。
- 插件工厂：`history()`、`keymap()`、`inputRules()`、`markdownRules()`、`markdown()`、`link()`、`characterCount()`、`suggestion()`、`starterKit()`（`js/plugins.rs`，其中 `StarterKit` 也是一种 plugin kind）。
- 命令：`command("toggleHeading", {level:2})`、`chain`、`first`、`can`；查询 `isActive/getAttributes/getMarkRange/findParentNode/coordsAtPos/posAtCoords/selectionRect/pageCoordsAtPos/posAtPageCoords`。
- 事件：`revision`、`create`、`update`、`selectionUpdate`、`transaction`、`focus`、`blur`、`paste`、`drop`、`delete`、`destroy`；监听器签名在 #612 改为 `on(event, l)` 返回 stop 函数。
- 协作钩子：`dispatchTransaction` / `applyTransaction`（文档 §JS API、§Phases）。
- 自定义：`defineExtension({ name, priority, node|mark, addOptions, addKeyboardShortcuts, addCommands, addInputRules, addPasteRules, addProseMirrorPlugins, addGlobalAttributes, addStorage })`；Rust 侧 `registry.rich_extension(name, make)` 注册。
- 文档 JSON：`getJSON`（#658 更名，对齐 Tiptap）；`parse` / `serialize`（Markdown 默认）/ `setContent`。

**注意**：任务简报中提到的 `import { RichEditor, createRichEditor, starterKit } from "nsh/base"` 中，`starterKit()` 作为插件工厂存在，但按文档推荐的 `extensions` 写法应使用类 `StarterKit`；探针采用后者，若构建后发现导出名不同，以构建生成的 `.nsh/types/nsh/base.d.ts` 为准。

### 6.3 文档明示的完成度（main）

`docs/dev/rich-editor.md` §Phases（原文）：

1. The headless kernel: model, transform, state, commands, history, keymaps, input rules, the starter schema, formats. **Done.**
2. The native view: rendering, selection and caret, input and IME on each platform, node views, decorations.
3. The base extensions as components (lists, links, images, tables, mentions), `createRichEditor` and `<RichEditor>` with their declarations and compat cases; the gallery and website examples.

§Future work: collaboration（原文）："Steps are already what collaboration needs ... A collaboration extension (prosemirror-collab's central authority, or a CRDT binding) **comes after the view**."

→ 对 CardMind 的含义：**没有现成 Loro/CRDT 协作扩展**；可自建 `dispatchTransaction` 拦截（JS 侧）或 Rust 侧插件，都属自研，文档未提供参考实现。与 Loro 的集成属"待验证/需设计"（另见 task-2）。

### 6.4 v0.3.0 里"Editor"是另一回事

v0.3.0 release notes 的 "Editors" 指 `Editor`（代码编辑器，带行号/诊断/语法高亮）与 `DiffView`（PR #452、#459、#460、#462、#464），**不是 RichEditor**。0.3.0 类型里 `Editor`/`DiffView` 存在、`RichEditor` 不存在，正好互证（§4.2）。

---

## 7. CardMind 升级路径事实

### 7.1 `nsh.json` 键（0.3.0 源码 `crates/nsh-cli/src/package.rs` 的 `AppConfig`，`deny_unknown_fields`）

| 键 | 含义 | 备注 |
|---|---|---|
| `name` / `id` / `version` / `build` | 显示名、bundle id、版本、构建号 | `build` 为 u32 |
| `icon` | 方形 PNG（理想 1024×1024），相对 `nsh.json` | |
| `minRuntime` | 签名包可运行的最低 runtime（`nsh publish`） | |
| `tailwind` / `theme` / `resolve` / `capabilities` | 由 bundler 读取并校验 | `capabilities` 见 `crates/nsh-core/src/access.rs` |
| `appearance` | `"light"`/`"dark"`/`"system"` | |
| `statusBar` | 状态栏默认值 | |
| `rust` | 应用的 Rust crate：目录（`"."`）或列表 | 见 §7.3 |
| `root` | Rust app 的根组件（`nsh.json` 为 entry） | |
| `web` | `{ host, connect }`：web 宿主模块与 connect-src 白名单 | |

CardMind 现状（`nsh-app/nsh.json`，只读核对）：

```json
{
  "name": "cardmind",
  "id": "com.cardmind.nsh",
  "version": "0.1.0",
  "build": 1,
  "rust": ".",
  "capabilities": { "webview": { "hosts": ["cardmind.editor"] } }
}
```

→ 结构上**仍然合法**（`webview.hosts` 在 main 的 `access.rs` 里仍是有效能力），升到 0.3.0/main 不需要改 `nsh.json` 键。

### 7.2 `NSH_SOURCE` 机制已变（重要）

- 0.3.0 二进制里 `NSH_SOURCE` 字符串只出现在 `--nsh-source` 的 clap env（上下文：`TEMPLATE...NSH_SOURCEWith --template rust or mixed: depend on the nsh crates of this checkout by path...`），即**只对 `nsh init` 有意义**。
- main 源码中全仓搜 `NSH_SOURCE`：只有 `crates/nsh-js/src/modules.rs` 的 `NSH_SOURCES`（JS 模块源表，与构建无关）与 docs 提到它；**没有 build 时的 NSH_SOURCE 环境变量**。
- `nsh build` 决定 nsh crates 来源的方式（`crates/nsh-cli/src/rust_app.rs` `Nsh::of`）：读应用 crate 的依赖（`cargo metadata --no-deps`），三选一：
  - `Registry`：crates.io，**必须与 CLI 的版本号精确匹配**；
  - `Source(PathBuf)`：应用 crate 用 path 依赖指向某个 checkout，**该 checkout 的版本必须等于 CLI 版本**；
  - `Git { checkout, url }`：Cargo 解析到的 git checkout。
  混用或版本不符会在构建前报错。
- 因此 CardMind 的 `nsh-app/build-nsh.mjs` 里"必须设置 `NSH_SOURCE` 否则退出 1"的逻辑，在 0.3.0/main 上**已不是 nsh 的要求**（是 0.1.1 时代的约束）。真正约束变成：`nsh-app/Cargo.toml` 的 nsh 依赖（当前 `nsh-core = "0.2.0"`、`nsh-base = "0.2.0"`、平台 crate `0.2.0`）必须与所用 CLI 版本一致。
- 版本不匹配时报错文案（源码 `Nsh::of`，原样）：
  `"{crate} asks for {name} {req} and this nsh is {VERSION}: install nsh {req}, or ask for {name} = \"{VERSION}\""`
- **对 CardMind 的直接影响**：本机 scoop CLI 已是 0.3.0，而 `nsh-app/Cargo.toml` 仍要 0.2.0（`.nsh/rust` 生成物里也是 `=0.2.0`）→ 现在直接 `nsh build` 会在版本检查处失败；升 0.3.0 要么把依赖改成 0.3.0（crates.io 已发 0.3.0），要么用 `nsh init --template rust --nsh-source <main checkout>` 生成 path 依赖（要求 checkout 的 workspace version == CLI version；main 当前仍是 `0.3.0`，见 §7.4）。

### 7.3 `nsh init` 模板与 Rust crate 关系

- `--template ts`：纯 TSX，无 Rust crate（本任务探针用）。
- `--template rust`：纯 Rust app（`nsh.json` 的 `"root"`，无 QuickJS）。
- `--template mixed`：TSX + 自带 Rust crate（CardMind 现状的同构形态；`"rust": "."`）。
- `--nsh-source <DIR>`：rust/mixed 下把 nsh crates 写成 path 依赖（"the app's hosts build from the same place"）。

### 7.4 main 的版本号仍是 0.3.0

`crates/nsh-main/Cargo.toml` 的 `[workspace.package] version = "0.3.0"`（main HEAD 未 bump）。含义：
- 用 main 源码构建出的 CLI 自称 `0.3.0`，但包含未发布的 RichEditor；
- 它与 crates.io 的 0.3.0 属于"同一版本号、不同代码"，**不能混用**（TSX-only app 不受影响，因为 CLI 自带 UI set；带 Rust crate 的 app 会按 §7.2 规则解析，容易踩坑）。

### 7.5 0.2.0 → 0.3.0 breaking changes（release notes 摘要，原文要点）

- **API 归位（#488）**：每个 API 只有一个家——原语/环境/能力在 `nsh`；无样式功能组件在 `nsh/base`；平台 API 在 `nsh/mobile` / `nsh/desktop`；**旧 import 路径被删除**：
  ```diff
  - import { Clipboard } from "nsh/clipboard";
  + import { Clipboard } from "nsh";
  - import { Input, type InputProps } from "nsh";
  + import { Input, type InputProps } from "nsh/base";
  - import { Keyboard, safeAreaInsets } from "nsh/base";
  + import { Keyboard, safeAreaInsets } from "nsh";
  - import { BackHandler } from "nsh/android";
  - import { InputAccessoryView } from "nsh/ios";
  + import { BackHandler, InputAccessoryView } from "nsh/mobile";
  ```
  原 `nsh/animated|device|gesture|clipboard|host|picker|storage|keymap|native|accessibility|image|list|canvas|webview|video` 全部并入 `nsh`。
- `SafeAreaView`/`KeyboardAvoidingView`/`SelectionArea` → CSS env（`env(safe-area-inset-*)`、`env(keyboard-inset-height)`）/ `<View selectable>`。
- `Tooltip` 的 `tooltip` 从字符串改为元素；Android `Toast.show` → `nsh/base` 的 `Toast`/`ToastManager`；iOS/Android `isAvailable` → `platform.os`。
- Rust：`nsh_core::ui` → `nsh_core::element`；用 `nsh_core::prelude`；`element::element` → `element::builder`；导航/对话框用 `nsh_base::{nav_stack, nav_page, dialog, alert_dialog}`。
- **兼容基线未冻结**（§2.5）。

### 7.6 `nsh test` 与现有 `npx tsx --test` 的关系

| 维度 | `nsh test`（0.3.0+） | 现有 CardMind 测试 |
|---|---|---|
| 发现规则 | 目录下 `*.test.tsx`、`*.test.ts`（排除隐藏目录、`node_modules`、`target`） | 手动 glob：`"*_test.ts" "web/src/*_test.ts"`（`*_test.ts` 下划线） |
| 运行时 | 自带 QuickJS VM（headless），每个测试文件独立 engine；`open(entry)` 起一个 `Headless` app | Node + tsx + `node:test` |
| 断言 | `nsh/test` 的 `expect`（Jest 风格：`toBe`/`toEqual`/`toContain`/`toMatch`/rejects…） | `node:assert` / `node:test` |
| UI 驱动 | `app.press/texts/shows/value/scroll/waitUntil`，可 `--trace` 打印 batch | 无（现有测试测纯逻辑/桥协议） |
| Rust 集成 | 有 `nsh.json` `"rust"` 时先跑 `cargo test --no-fail-fast`（每个 crate），再跑 TS 测试 | 无（Rust 测试另跑 `cargo test`） |
| 平台 | 默认 headless；`--target windows/linux/macos/gpui/web/ios/android` 用真实 host | 无 |

关键结论：
1. **命名不冲突**：CardMind 是 `*_test.ts`，`nsh test` 找 `*.test.ts`，两者可共存。
2. **不能复用**：现有测试 import `node:test`/`node:assert` 与 tsx 生态，`nsh test` 不能跑；迁移需要把行为测试改写为 `import { test, open, expect } from "nsh/test"`。
3. `nsh test` 的 headless 能力足以覆盖"编辑器行为"的大部分断言（文本、选择、命令、markdown 往返），但**视觉/布局/IME 真机行为**仍需 `--target` + host。
4. 0.3.0 的 `nsh test` 还负责跑 app 的 Rust crate 测试（0.3.0 release notes 的 "`nsh check` and `nsh test` now also run Cargo checks and tests for apps with Rust crates"）——对 CardMind 意味着迁移后测试入口可能统一，但 Rust 测试的 target dir/workspace 语义需另验证。

### 7.7 `nsh package` vs `nsh publish`

- `package`：从预构建 runtime 打包安装物（`.ipa`/`.apk`/`.app`/Windows 目录+zip/web 静态站点），**不需要 Rust 工具链**，`--target` 必填；元数据来自 `nsh.json`，可被命令行覆盖。
- `publish`：release 模式构建 + 签名成 `.nshpkg`，给"嵌入 nsh 的宿主 app"校验并运行；用 `keygen`/`certify`/`verify`/`revoke` 管理密钥链。
- 对 CardMind 的分发决策（MSIX vs `.nshpkg`）是另一个议题，但 0.3.0 的 `nsh package --target windows` 与既有 0.1.1 流程（31 MB exe + zip）在同一命令面上延续。

---

## 8. 最短可行路径（本机立即用 RichEditor）

### 8.1 当前状态判定

- **今天/现在不能**：已装 0.3.0 CLI 没有 RichEditor（§4.2/4.3）；RichEditor 只在 main。
- 要用 RichEditor，**必须从 main 源码构建 CLI**（或等含 RichEditor 的下一个 release）。
- 构建通过后，TSX-only 探针**不需要** CardMind 的 Rust crate 升级（RichEditor 由 CLI 自带 UI set 提供）；但若要在 CardMind 现有 `nsh-app`（含 Rust crate）里用，需要按 §7.2/§7.4 处理版本/路径依赖。

### 8.2 依赖与时间估算（已用实测校正）

| 步骤 | 内容 | 实测/估算 |
|---|---|---|
| 1 | 修复 Rust 工具链（rsproxy 镜像） | ✅ 已完成：约 5–10 min（含一次误操作修复，§5.1） |
| 2 | 安装 LLVM/libclang | **实际不需要**：未安装任何 LLVM，构建成功（§5.4）。若上游其他目标需要，属另行验证 |
| 3 | cargo 依赖下载（751 包，rsproxy ~0.5 MB/s） | ✅ 约 2–3 min（546+ 个 crate 下载） |
| 4 | `cargo build -p nsh-cli`（debug，含 oxc/rolldown/QuickJS） | ✅ **9m 06s**（12700K，一次性） |
| 5 | `nsh init` + `nsh check` + `nsh build` + `nsh test` 探针 | ✅ 总计约 5 s（init 0.6 s / check 1.4 s / build 0.9 s / test 1.2 s） |
| 6（可选） | `nsh run --target windows` 看真实渲染 | ✅ 另需构建 host：`cargo build -p nsh-windows-host` **2m 44s**；之后 `nsh run` 秒级开窗（§5.6/5.7） |
| 7 | 磁盘 | `target/` 约 **19.8 GB**（CLI + windows host 的 debug 构建） |

**总估（已验证）**：从零到"RichEditor 通过 check/build/test" = **约 15–20 min**（工具链修复 + 依赖下载 + 9m06s 构建 + 秒级探针）；
到"真实窗口里看到 RichEditor"再加 **约 3 min**（windows host 构建 2m44s + 启动），合计 **约 20–25 min**。

### 8.3 "不想装 LLVM"的旧假设已被推翻

原计划：`cargo check -p nsh-base` 作为不装 LLVM 的替代验证。实测**不需要**——直接完整构建 `nsh-cli` 成功（§5.4）。
若将来在 macOS/Linux/Apple/Android 目标上构建，仍应按 `CONTRIBUTING.md` 准备 LLVM；**待验证**。

---

## 9. 工程权衡：等 release vs 跟 main

| 维度 | 等 release（含 RichEditor 的下一个版本） | 跟 main（锁 commit） |
|---|---|---|
| RichEditor 可用性 | 要等（发布时间未知；0.3.0 后已 7 天，仍在迭代） | 立即可用（构建通过后） |
| 稳定性 | 相对高（release 经过 CI/发布流程），但 RichEditor 本身仍新；nsh-compat **尚未记录任何 release**，兼容承诺未开始 | 低-中：10-27~10-29 仍改 API（事件对象、监听器签名、getJSON、错误码） |
| 构建成本 | 下载预构建 CLI，零构建 | 需要 LLVM + 完整 Rust 构建；CardMind 的 host/打包链路也要跟着自建 |
| CardMind 现有锁版策略 | 与现有"锁 CLI 版本 + 对应 NSH 源码"策略一致 | 需要改写：锁 commit + 自建 CLI；`NSH_SOURCE` 旧机制已不适用（§7.2） |
| 风险 | 等不到/延期；RichEditor 可能在下个版本前继续改 | API 漂移、main 回归、自建构建链维护成本；需 pin commit 并定期 rebase |
| 适用阶段 | 产品化/交付 | 技术预研/spike/原型（本任务） |

**建议（供 Lead 决策）**：
1. 短期用 main 固定 commit（`45fb5def`）构建 CLI 做 RichEditor 可行性 spike，验证 [[wikilink]]/标签/表格/IME/Markdown 往返等 CardMind 关键场景；
2. 产品化不要直接跟 main：等一个把 RichEditor 纳入且 nsh-compat 开始记录 release 的版本；期间可以用 `nsh-compat` 是否出现 `releases/v<version>/` 作为"可依赖"信号；
3. 若必须在 main 上做产品，锁 commit + 自建 `nsh-cli`/host 构建，并把"升级=换 commit + 重跑探针套件"写入迁移计划。

---

## 10. 待验证清单

- [x] `cargo build -p nsh-cli` 的最终结果：exit 0 / 9m06s / 无需 LLVM（§5.4）。
- [x] main CLI `nsh init app --template ts` 后 `.nsh/types` 含 `RichEditor` / `createRichEditor` / `StarterKit` / `TableKit`（§5.5）。
- [x] `nsh check` / `nsh build` / `nsh test` 对 RichEditor 探针：全部 exit 0（§5.5）。
- [x] `nsh test` 覆盖 headless 渲染断言（`app.texts()` 拿到 RichEditor 渲染的标题/列表文本）与内核文档断言（`doc.type`）。
- [x] `nsh run --target windows` 的最终结果与 windows host 构建耗时：host **exit 0 / 2m44s**，窗口成功打开并截图（§5.6/5.7）。
- [ ] RichEditor 的真实渲染质量（中文、IME、表格、图片、样式定制）——已确认能渲染文本；样式需 app 提供，需进一步截图对比。
- [ ] 列表 marker/缩进在原生视图中的实际表现（本次截图中未见 `•`，是否因未传 `classes.nodes.listMarker` **待验证**）。
- [ ] markdown 往返（`getMarkdown`/`setContent`）、撤销、表格命令在 headless 下的可测性（`nsh test` 能覆盖多少）。
- [ ] 含 RichEditor 的下一个 release 版本号与时间（无公开 roadmap 证据）；以及它是否会被 nsh-compat 记录。
- [ ] 上游 `CONTRIBUTING.md` 的 LLVM 前置在 Windows 路径上为何未触发（是否只在交叉编译/重生成 bindings 时需要）。
- [ ] CardMind `nsh-app` 升 main 的完整改动清单（依赖版本/path、`build-nsh.mjs` 是否保留、测试迁移）。

---

## 11. 证据索引（本地文件）

| 内容 | 路径 |
|---|---|
| 0.3.0 init 日志 | `spike/nsh-rich-editor-probe/logs/probe-030-init.log` |
| 0.3.0 `nsh check` TS2305 日志 | `spike/nsh-rich-editor-probe/logs/probe-030-check.log` |
| 0.3.0 `nsh test` 日志 | `spike/nsh-rich-editor-probe/logs/probe-030-test.log` |
| main 构建日志 | `spike/nsh-rich-editor-probe/logs/cargo-build-nsh-cli.log` |
| main CLI `nsh init` 日志 | `spike/nsh-rich-editor-probe/logs/app-main-init.log` |
| main CLI `nsh check` 日志 | `spike/nsh-rich-editor-probe/logs/app-main-check.log` |
| main CLI `nsh build` 日志 | `spike/nsh-rich-editor-probe/logs/app-main-build.log` |
| main CLI `nsh test` 日志 | `spike/nsh-rich-editor-probe/logs/app-main-test.log` |
| main CLI `nsh run --target windows` 日志 | `spike/nsh-rich-editor-probe/logs/app-main-run-windows.log`、`run-stderr.log` |
| windows host 构建日志 | `spike/nsh-rich-editor-probe/logs/cargo-build-nsh-windows-host.log` |
| RichEditor 真实渲染截图（Windows host） | `spike/nsh-rich-editor-probe/logs/rich-editor-printwindow.png`（PrintWindow 截取，窗口被遮挡也有效）；`rich-editor-windows-host.png` 为整屏截图（可能被其他窗口遮挡，仅参考） |
| 0.3.0 探针 app | `spike/nsh-rich-editor-probe/probe-030/` |
| main 探针 app（RichEditor，已通过 check/build/test） | `spike/nsh-rich-editor-probe/app-main/` |
| 探针说明 | `spike/nsh-rich-editor-probe/README.md` |
| main 源码 checkout | `D:\Projects\nsh-main`（HEAD `45fb5def`） |
| RichEditor 上游文档 | `D:\Projects\nsh-main\docs\dev\rich-editor.md`；`D:\Projects\nsh-main\website\elements\rich-editor.md` |
| 构建前置文档 | `D:\Projects\nsh-main\CONTRIBUTING.md`（Windows: VS Build Tools + LLVM/libclang——后者实测未触发） |
| nsh.json schema | `D:\Projects\nsh-main\crates\nsh-cli\src\package.rs`（`AppConfig`） |
| nsh crates 来源解析 | `D:\Projects\nsh-main\crates\nsh-cli\src\rust_app.rs`（`Nsh::of`） |
| 上游发布 | https://github.com/longbridge/nsh/releases ；https://github.com/longbridge/nsh/releases/tag/v0.3.0 |
| 兼容记录 | https://github.com/longbridge/nsh-compat |
