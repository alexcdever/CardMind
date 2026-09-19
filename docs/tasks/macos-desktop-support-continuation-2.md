# macOS Desktop Support Continuation 2

<!-- Task ID: macos-desktop-support-continuation-2 -->
<!-- Parent task: macos-desktop-support-continuation-1. Contract is frozen after commit. -->

```pipeline-contract
{
  "schema": 1,
  "task_id": "macos-desktop-support-continuation-2",
  "allowed_paths": [
    "rust-backend/Cargo.toml",
    "test/macos_desktop_support_test.dart",
    "docs/tasks/macos-desktop-support-continuation-2.md",
    ".workflow/macos-desktop-support-continuation-2/**"
  ],
  "forbidden_paths": [
    "rust-backend/src/**",
    "lib/src/rust/**",
    ".env"
  ],
  "acceptance_tests": [
    {
      "id": "C2-1",
      "evidence_level": 1,
      "test_ref": "test/macos_desktop_support_test.dart: Rust release profile preserves a dyld-loadable macOS dylib",
      "command_ref": "flutter test test/macos_desktop_support_test.dart --timeout 3m"
    },
    {
      "id": "C2-2",
      "evidence_level": 4,
      "test_ref": "Rust host runtime: cargo release dylib loads through macOS dyld",
      "command_ref": "cargo build --release && /usr/bin/python3 -c \"import ctypes; ctypes.CDLL('rust-backend/target/release/libcardmind_backend.dylib'); print('loaded')\""
    }
  ]
}
```

## 任务身份

- 项目：CardMind
- 父任务：`macos-desktop-support-continuation-1`
- 领域或阶段：macOS Rust host 动态库运行时兼容
- 用户结果或系统能力：Rust release 动态库在 macOS 27 dyld 上可加载，FRB 集成测试不因 Mach-O LINKEDIT 对齐失败
- 状态：未开始

## 依赖与范围

### 前置条件

- macOS Flutter 工程和 bundle 集成已由父任务实现。
- Rust `cargo build --release` 在当前 macOS 27 / Rust 1.98 工具链上能编译但产出 `mis-aligned LINKEDIT string pool`，因为 release 默认 strip debuginfo。
- 临时 `RUSTFLAGS='-C strip=none' cargo build --release` 已验证可生成可由 dyld 加载的 dylib。

### 允许修改

- `rust-backend/Cargo.toml` 的 release profile 配置。
- macOS 专项静态测试和当前任务证据。

### 明确不改

- 不修改 Rust 业务源码、FRB 生成文件、Dart 运行逻辑或其他平台配置。
- 不依赖环境变量作为唯一修复；干净执行 `cargo build --release` 必须得到可加载产物。

## 事实、假设与待决

### 已确认事实

- macOS 27 dyld 报错：`mis-aligned LINKEDIT string pool`。
- 失败 Mach-O 的 `LC_SYMTAB.stroff` 不是 8 字节对齐。
- `RUSTFLAGS='-C strip=none'` 构建出的 dylib可由 Python `ctypes.CDLL` 加载。
- Rust upstream issue `rust-lang/rust#157750` 描述了 Rust release strip debuginfo 在 macOS 上生成未对齐 dylib 的同一问题。

### 未验证事实

- Cargo profile `strip = "none"` 是否在当前 Cargo 版本和 CI macOS runner 上完整覆盖 RUSTFLAGS 行为。

### 禁止猜测

- 不通过修改 dyld、手工二进制补丁或复制临时签名文件规避错误。
- 不降低 macOS deployment target 来绕过问题；工程目标保持 12.0。

## 设计与行为契约

[执行 `cargo build --release`]
→ [release profile 不剥离导致 Mach-O LINKEDIT string pool 保持可加载布局]
→ [FRB 从 Cargo runtime 路径或 app bundle Frameworks 加载 dylib]
→ [macOS 应用与真实 FRB 集成测试可启动]

- release profile 显式 `strip = "none"`，避免依赖 shell 环境变量。
- app bundle 仍由父任务的 Xcode build phase 设置 `@rpath` install name 并复制 dylib。

## 环境前置

1. macOS 27、Xcode 27、Rust 1.98 或同等工具链。
2. 从 `rust-backend/` 执行 `cargo build --release`。

## 验收测试

### 验收测试1：release profile 记录 dyld 修复

- 触发：读取 Rust release profile 和 macOS 工程测试。
- 断言：任务范围记录 `strip = "none"`，并保留 bundle 集成断言。
- 测试：`test/macos_desktop_support_test.dart: Rust release profile preserves a dyld-loadable macOS dylib`
- 命令：`flutter test test/macos_desktop_support_test.dart --timeout 3m`
- 验收模式：静态工程检查
- 证据等级：1
- 结果要求：退出码 0。

### 验收测试2：真实 dyld 加载

- 触发：执行干净 `cargo build --release` 后用 ctypes 加载 host dylib。
- 断言：动态库存在、架构为 arm64、dyld 加载成功。
- 测试：`rust-backend/target/release/libcardmind_backend.dylib`
- 命令：`cargo build --release && /usr/bin/python3 -c "import ctypes; ctypes.CDLL('rust-backend/target/release/libcardmind_backend.dylib'); print('loaded')"`
- 验收模式：真实桌面运行时
- 证据等级：4
- 结果要求：退出码 0，输出包含 `loaded`。

## 决策点

出现以下情况时保留现场并报告：

1. `strip = "none"` 仍不能消除 dyld 错误，需要用户裁决是否升级 Rust 或加入特定 target linker 参数。
2. 修复要求修改 Rust 源码、FRB 生成文件或改变发布二进制策略。

---

## 任务级进度（主代理维护）

### 任务锚点

- 父任务基线：9b5682c8
- 契约提交：-
- 执行分支：主工作树（provider 阻塞后主代理接管）
- 执行 worktree：`/Users/alexc/Projects/CardMind`

### 验收台账

| 验收测试 | 状态 | 当前测试/命令 | 最新证据 | 备注 |
|---|---|---|---|---|
| 验收测试1 | 未开始 | `flutter test test/macos_desktop_support_test.dart --timeout 3m` | - | - |
| 验收测试2 | 未开始 | `cargo build --release && python ctypes load` | - | - |

### 执行记录

| 时间/轮次 | 事件 | 结果 | 证据 | 后续 |
|---|---|---|---|---|
| 2026-09-20 / 0 | continuation 创建 | 未开始 | - | 校验并提交契约后实现 |

### 最终结果

- 状态：未开始
- 独立审查：provider/API key 阻塞，未派发成功
- 主代理最终检查：未开始
- 合并提交：-
- 遗留项：-
