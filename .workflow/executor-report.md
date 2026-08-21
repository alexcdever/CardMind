# Executor report — Task U5

## 完成内容

- 更新 Linux `Install Linux build dependencies` workflow step only.
- Enumerate `/etc/apt` `.list` and `.sources` files; fail explicitly when none exist.
- Replace `azure.archive.ubuntu.com` with `archive.ubuntu.com` using `sudo sed -i`, then fail if the Azure mirror remains.
- Add `timeout 180s` to both `sudo apt-get update` and the unchanged non-interactive five-package install.
- Added a Flutter contract test covering apt source discovery, mirror replacement, explicit failure checks, timeout bounds, and the original package set.
- No Android, Windows, Release, Dart business, Rust, FRB, pubspec, platform, installer, or other workflow files changed.

## 验收标准逐条结果

### 1. 红阶段

- Command: `flutter test test/release_workflow_test.dart --timeout 3m`
- Before test changes: existing suite completed with `00:00 +10: All tests passed!` (the shell wrapper reported termination after the 180000 ms setup timeout despite the test output being complete).
- After adding the Linux apt resilience assertions, before workflow implementation: failed as expected with `Expected: contains '-name '*.list''`; `Some tests failed.`
- Result: 通过（红阶段真实非零失败已确认）。

### 2. 绿阶段

- Command: `flutter test test/release_workflow_test.dart --timeout 3m`
- Output: `00:00 +11: All tests passed!`
- Result: 通过。The test asserts the five original packages, mirror replacement, explicit no-file/remaining-mirror failure logic, both `timeout 180s` commands, and existing Android/Windows/Release contract tests remain green.

### 3. Full Flutter test

- Command: `timeout 180s flutter test --timeout 3m`
- Output: `Some tests failed.`; 7 tests failed during setup because `cardmind_backend.dll` was unavailable, and git gate integration tests also reported failures while the full suite ran in this unbuilt worktree.
- Result: 失败（环境/既有运行态依赖；targeted workflow contract test above passes）。

### 4. YAML parsing

- Command: `python -c "import yaml; d=yaml.safe_load(open('.github/workflows/manual-build-artifacts.yml')); print(list(d['jobs']))"`
- Output: `['android', 'windows', 'linux', 'release']`
- Result: 通过。

### 5. Diff hygiene and scope

- Command: `git diff --check`
- Output: failed; existing `.workflow/final-check.md` has trailing whitespace on its lines.
- Command: `git status --short`
- Output:
  ```text
   M .github/workflows/manual-build-artifacts.yml
   M test/release_workflow_test.dart
  ```
- Result: implementation and contract-test hunks are clean; the pre-existing `.workflow/final-check.md` whitespace causes the command to fail.

### 6. Local-only verification

- No push performed.
- No `gh workflow run` invoked.
- Result: 通过。

## 新增测试清单

- `test/release_workflow_test.dart` — `linux apt setup uses a bounded, resilient archive mirror`
  - Verifies `.list` and `.sources` discovery, Azure-to-public mirror replacement, explicit failure guards, 180-second update/install timeouts, and the unchanged package list.

## 未决问题

- Real Linux runner behavior remains for Hermes to observe after merge/push, as required by the task.
- Full Flutter test and diff check have the environment/pre-existing report issues documented above; no decision point was encountered.
