# git_gate hook 集成测试非确定性 ENOENT（诊断任务）

- task-id: `git-gate-hook-test-enoent`
- 状态：待派发（诊断类任务）
- 基线：`bf619421`
- 证据目录：`.pipeline/git-gate-hook-test-enoent/`

## 1. 现象

`test/git_gate_hook_integration_test.dart` 的用例 19–22 会**非确定性**失败：

```
ProcessException: No such file or directory
  Command: git commit -m t1
dart:io                                          Process.run
test/git_gate_hook_integration_test.dart 122:20  main.gitRun
```

失败点在 `gitRun`（`test:122`），触发命令是 `git commit -m t1`（`test:144` / `test:202` / `test:255` / `test:304`）。

## 2. 已观察到的非确定性（主代理实测）

同一条命令 `flutter test test/git_gate_hook_integration_test.dart`：

| 轮次 | 结果 |
|---|---|
| 早期（审查配对任务时） | `+4: All tests passed!` |
| 早期（device-name 收尾） | `+0 -4: Some tests failed.` |
| 抖动率实测（连跑 4 次） | **4/4 全部 `+0 -4`** |

**结论：非确定性。** 这解释了此前三方结论不一致——执行方报失败、审查方报通过、主代理两次得到不同结果，**三方都没编造，只是命中了不同分支**。

## 3. 已排除的假设（均有实测证据）

| 假设 | 证据 | 结论 |
|---|---|---|
| `PATH` 内容坏了导致 `git` 找不到 | 探针实测 `dartBinDir()=/opt/homebrew/share/flutter/bin/cache/dart-sdk/bin`、`dartBinExists=true`、`PATH` 含 `/usr/bin` | **排除** |
| `git` 可执行文件缺失 | `git --version` 正常；探针里 `git init/config/add` 全部 `exit=0` | **排除** |
| 传 `environment:` 覆盖导致 `git` 找不到 | 探针 A（`...Platform.environment` + `PATH`）`commit exit=0`；探针 B（**精确复刻** `gateEnv`，含 `dartBinDir()` 拼接 + `CARDMIND_GATE_TEST_MODE`）同样 `exit=0` | **排除** |
| 全局 `core.hooksPath` 干扰 | `git config --global core.hooksPath` 未设置 | **排除** |
| `workingDirectory` 指向不存在的目录 | 探针中 `Directory(dir.path).existsSync()=true` | **排除**（至少在探针路径下） |

## 4. 仍未解释的关键矛盾

**探针能复刻 `gateEnv` 却无法复现失败。** 探针与真实测试的差异只剩：

1. 真实测试**并行跑 4 个用例**（19/20/21/22），探针只跑 1 个
2. 真实测试会先 `copyGateTooling()` 安装 hook 到 `.git/hooks/`
3. 真实测试的 `createTempGitRepo` 用 `Directory.systemTemp.createTemp('cardmind_hook_$name')`，与探针的前缀不同
4. 真实测试在 `git commit` 前有 `git add` 成功（同 `gitRun`，但**不传** `environment`）

第 4 点最可疑：**同一函数、同一 repo，不带 env 的调用成功、带 env 的调用抛 ENOENT**。若成立，差异必在 `environment` 参数本身，而探针已证明该 map 的内容无害。

## 5. 下一步（给执行子代理）

### 首选定证方向：在真实测试内部加探针

不要继续在外围写探针——**直接在 `gitRun` 里加临时诊断**，捕获失败瞬间的状态：

```dart
Future<ProcessResult> gitRun(String repo, List<String> args, {Map<String, String>? environment}) {
  // [DEBUG-a4f2] 临时
  if (args.first == 'commit') {
    print('[DEBUG-a4f2] repo=$repo exists=${Directory(repo).existsSync()}');
    print('[DEBUG-a4f2] env=${environment == null ? "null" : "keys=${environment.length} PATH=${environment['PATH']?.split(':').take(2).join(':')}"}');
    print('[DEBUG-a4f2] cwd=${Directory.current.path}');
  }
  return Process.run('git', args, workingDirectory: repo, environment: environment);
}
```

跑失败的用例，把 `[DEBUG-a4f2]` 输出贴进证据。**用完必须删除**（`grep -r 'DEBUG-a4f2'` 应为空）。

### 备选方向

- 单独写一个只跑用例 19 的最小测试文件，看是否稳定通过 → 若通过，则问题是**并行**触发
- 用 `flutter test --concurrency=1` 跑该文件，对比是否稳定通过 → 验证并发假设
- 若并发假设成立：可能是 4 个用例各自 `Directory.systemTemp.createTemp` 在同一进程内创建大量子进程，触发了 `fork/exec` 资源限制

## 6. 约束

- **不要修改 `test/git_gate_hook_integration_test.dart` 的断言语义**（除临时 debug 输出，且必须清理）
- 不要为了让测试通过而放宽断言
- 若定位到产品代码缺陷，另开修复任务单，不在诊断任务里改
- 环境：rustup 默认工具链已切到 `system`（Homebrew Rust 1.98.1）；Flutter 需 `PUB_HOSTED_URL=https://pub.flutter-io.cn`

## 7. 验收

- **D1**：产出**可复现的红/绿对照**——一条命令能稳定触发失败，另一条稳定通过，二者差异即根因（若做不到稳定复现，必须给出抖动率的量化数据）
- **D2**：给出根因结论，或明确标注「未能定位」并列出已验证排除的假设与剩余怀疑方向
- **D3**：所有临时 instrumentation 已清理（`grep -rn 'DEBUG-a4f2' test/` 为空）

## 8. 优先级说明

**本任务不阻塞任何功能。** 该失败已确证：
- 与 `pairing-credential-ip`、`log-dir-discoverability`、`device-name-hostname` 三个改动**零因果**（三个任务期间均复现同一失败，且失败集合与基线逐条相同）
- 不影响发布工作流（CI 不跑该文件所在的测试集）

因此按低优先级排期。

## 9. 已知证据边界

- 本仓库不存在 `.gitnexus/run.cjs`，GitNexus MCP impact 工具不可用。
- 本任务只做诊断，不做修复。

<!-- pipeline-contract
 task-id: git-gate-hook-test-enoent
 contract-version: 1
 baseline: bf619421
 scope: test/git_gate_hook_integration_test.dart,tool/git_gate.dart,tool/src/git_gate
 acceptance: D1-reproducible-red-green-or-flake-rate; D2-root-cause-or-explicit-unlocated; D3-instrumentation-cleaned
 execution-worktree: pending-contract-freeze
 evidence-dir: .pipeline/git-gate-hook-test-enoent/
-->