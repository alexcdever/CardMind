# macOS Desktop Support Continuation 3

<!-- Task ID: macos-desktop-support-continuation-3 -->
<!-- Parent task: macos-desktop-support. Contract is frozen after commit. -->

```pipeline-contract
{
  "schema": 1,
  "task_id": "macos-desktop-support-continuation-3",
  "allowed_paths": [
    "test/git_gate_test.dart",
    "docs/tasks/macos-desktop-support-continuation-3.md",
    ".workflow/macos-desktop-support-continuation-3/**"
  ],
  "forbidden_paths": [
    ".env",
    "lib/**",
    "rust-backend/src/**",
    "macos/**"
  ],
  "acceptance_tests": [
    {
      "id": "C3-1",
      "evidence_level": 1,
      "test_ref": "test/git_gate_test.dart: format-first gate 13 Dart 未格式化文件被写回、报告 changed、后续测试 runner 未调用",
      "command_ref": "flutter test test/git_gate_test.dart --plain-name 'format-first gate 13 Dart 未格式化文件被写回、报告 changed、后续测试 runner 未调用' --timeout 3m"
    },
    {
      "id": "C3-2",
      "evidence_level": 1,
      "test_ref": "test/git_gate_test.dart: format-first gate 16 partial staging 不会自动 git add、也不改 index",
      "command_ref": "flutter test test/git_gate_test.dart --plain-name 'format-first gate 16 partial staging 不会自动 git add、也不改 index' --timeout 3m"
    },
    {
      "id": "C3-3",
      "evidence_level": 3,
      "test_ref": "test/vertical_slice_widget_test.dart: list and open slice cleans title, marker and duplicate preview before opening",
      "command_ref": "flutter test test/vertical_slice_widget_test.dart --plain-name 'cleans title, marker and duplicate preview before opening' --timeout 3m"
    },
    {
      "id": "C3-4",
      "evidence_level": 3,
      "test_ref": "full Flutter suite: all tests pass on macOS after cross-platform fixture correction",
      "command_ref": "flutter test --timeout 3m"
    }
  ]
}
```

## 任务身份

- 项目：CardMind
- 父任务：`macos-desktop-support`
- 领域或阶段：跨平台测试 fixture 可移植性与 flaky 复核
- 用户结果或系统能力：Windows/macOS 均可执行 git gate 的 Dart 格式化 fixture；macOS 全量 Flutter 测试不因 Windows 路径假设失败
- 状态：已完成

## 依赖与范围

### 前置条件

- macOS 支持已由 `87d403e6` 实现。
- macOS 全量 Flutter 测试已观察到两个 fixture 因硬编码 `dart.exe` 失败。
- `vertical_slice_widget_test.dart` 的列表打开用例单独重复运行和与 git gate 合并运行均通过，暂未观察到稳定失败。

### 允许修改

- `test/git_gate_test.dart` 中测试 helper `dartExe()` 的平台解析逻辑。
- 当前 continuation 任务单和证据。

### 明确不改

- 不修改生产 Flutter、Rust 或 macOS 工程代码。
- 不修改列表/编辑器产品逻辑；flaky 复核若不能稳定复现，只记录证据，不添加任意延时、重试或放宽断言。
- 不改变 Windows 断言语义：Windows 仍必须解析到 `dart.exe`。

## 事实、假设与待决

### 已确认事实

- 失败命令为 `/opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart.exe format lib`，该路径在 macOS 不存在。
- 失败发生于 `test/git_gate_test.dart` 的 fixture helper，不是 `tool/src/git_gate/formatter.dart` 生产逻辑。
- macOS 上使用相同 SDK 目录的 `dart` 可执行文件后，fixture 13 和 fixture 16 均通过。
- `vertical_slice_widget_test.dart` 的目标用例单独连续运行通过；修复后完整 Flutter 测试也通过。

### 未验证事实

- 尚未在 Windows 实机执行本轮 fixture；Windows 分支仅由当前源码和现有 Windows smoke 断言保护。

### 禁止猜测

- 不把一次全量测试中的时序失败称为确定产品 bug。
- 不以 `sleep`、固定额外 `pump` 或重复执行掩盖 flaky；只有有明确等待条件和红测试证据才允许改测试。

## 设计与行为契约

[git gate 测试 fixture 需要执行真实 Dart formatter]
→ [从 `Platform.resolvedExecutable` 推导 Flutter SDK 缓存中的 Dart CLI]
→ [Windows 选择 `dart.exe`，macOS/Linux 选择 `dart`]
→ [formatter 写回、变更检测、阻止后续 runner 的原有断言保持不变]

- 非 Windows 路径不得包含 `.exe`。
- Windows 路径保持 `dart.exe`。
- fixture 不修改 git index，不调用后续 analyze/test/clippy runner。
- 列表打开测试只在明确失败证据出现时才修改；当前目标是验证其在 macOS 上可稳定运行。

## 环境前置

1. Flutter SDK 可用，当前 macOS 基线为 Flutter 3.44.9 / Dart 3.12.2。
2. 运行 Flutter 测试前确保 Rust host dylib已经构建并可加载。
3. 每条定向测试命令最多 3 分钟，全量 Flutter 测试累计上限 20 分钟。

## 验收测试

### 验收测试1：macOS Dart formatter fixture

- 触发：fixture 13 创建未格式化 Dart 文件并运行 git gate formatter。
- 断言：使用 macOS `dart` 成功格式化，报告 changed，且未调用 analyze/clippy/test。
- 测试：`test/git_gate_test.dart: format-first gate 13 Dart 未格式化文件被写回、报告 changed、后续测试 runner 未调用`
- 命令：`flutter test test/git_gate_test.dart --plain-name 'format-first gate 13 Dart 未格式化文件被写回、报告 changed、后续测试 runner 未调用' --timeout 3m`
- 验收模式：单元/工具 fixture
- 证据等级：1
- 结果要求：退出码 0。

### 验收测试2：partial staging 跨平台 fixture

- 触发：fixture 16 在 staged + unstaged 混合状态运行 formatter。
- 断言：macOS formatter 成功，阻止提交，不修改 git index，不自动 git add。
- 测试：`test/git_gate_test.dart: format-first gate 16 partial staging 不会自动 git add、也不改 index`
- 命令：`flutter test test/git_gate_test.dart --plain-name 'format-first gate 16 partial staging 不会自动 git add、也不改 index' --timeout 3m`
- 验收模式：单元/工具 fixture
- 证据等级：1
- 结果要求：退出码 0。

### 验收测试3：列表打开用例稳定性

- 触发：移动端尺寸下加载带 tags marker 和重复 preview 的笔记并打开。
- 断言：标题和 preview 清理正确，无 marker，编辑器出现。
- 测试：`test/vertical_slice_widget_test.dart: list and open slice cleans title, marker and duplicate preview before opening`
- 命令：`flutter test test/vertical_slice_widget_test.dart --plain-name 'cleans title, marker and duplicate preview before opening' --timeout 3m`
- 验收模式：Widget
- 证据等级：3
- 结果要求：退出码 0；不添加无证据延时。

### 验收测试4：全量回归

- 触发：运行整个 Flutter 测试套件。
- 断言：无 Windows-only `dart.exe` fixture 失败；列表打开用例通过；完整套件退出码 0。
- 测试：项目整体
- 命令：`flutter test --timeout 3m`
- 验收模式：全量 Flutter 回归
- 证据等级：3
- 结果要求：退出码 0；Windows-only smoke 可在 macOS 上按既有 `skip` 规则跳过。

## 决策点

1. 若 Windows 实机显示 Flutter SDK 中可执行文件命名与当前 `dart.exe` 假设不同，保留现场并请求 Windows 环境证据，不静默修改产品行为。
2. 若列表打开用例在隔离运行中稳定失败，另开产品/测试时序 continuation；不得把全量并行下的一次失败直接修成 sleep。

---

## 任务级进度（主代理维护）

### 任务锚点

- 父任务基线：`e2888ff6`
- 契约提交：0aca64fa
- 执行分支：主工作树
- 执行 worktree：`/Users/alexc/Projects/CardMind`

### 验收台账

| 验收测试 | 状态 | 当前测试/命令 | 最新证据 | 备注 |
|---|---|---|---|---|
| 验收测试1 | PASS | fixture 13 | `d9438f71`, exit 0 | macOS `dart` CLI |
| 验收测试2 | PASS | fixture 16 | `d9438f71`, exit 0 | index 未修改 |
| 验收测试3 | PASS | vertical slice | repeated isolated runs, exit 0 | no test-delay change |
| 验收测试4 | PASS | full Flutter | current run exit 0, 235 tests passed | Windows-only smoke skipped |

### 执行记录

| 时间/轮次 | 事件 | 结果 | 证据 | 后续 |
|---|---|---|---|---|
| 2026-09-20 / 0 | continuation 创建 | 已完成 | `0aca64fa` | 冻结跨平台 fixture 范围 |
| 2026-09-20 / 1 | 主代理实现与验收 | PASS | focused/full Flutter tests | 仅修改 test helper |

### 最终结果

- 状态：PASS
- 独立审查：未派发
- 主代理最终检查：PASS
- 合并提交：`d9438f71`
- 合并后复验：focused gate, vertical slice, `flutter analyze` 通过
- 遗留项：无；列表用例未出现可稳定复现的 flaky failure，不添加无证据等待或重试
