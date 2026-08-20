# Task U5: 修复 Linux GitHub runner 依赖安装卡死

## 任务

修复 `CardMind Main Release` workflow 的 Linux job。run `32300446472` 中 Linux runner 在 `Install Linux build dependencies` 步骤卡在 `sudo apt-get update`：Azure Ubuntu mirror `azure.archive.ubuntu.com` 长时间无响应，六小时后整次 run 被取消；FRB、Rust、Flutter 和 AppFlowy 依赖步骤均未开始。Android 和 Windows 已成功，不得修改它们。

## 主仓库与范围

主仓库：`D:/Projects/CardMind`

任务修改在 OpenCode 隔离 worktree 中完成。

只允许修改：

- `.github/workflows/manual-build-artifacts.yml`
- `test/release_workflow_test.dart`
- `.workflow/executor-report.md`
- `.workflow/review-report.md`
- `.workflow/final-check.md`

不得修改 Dart 业务代码、Rust、FRB、pubspec、平台工程、安装脚本或其他 workflow。

## 设计要求

Linux `Install Linux build dependencies` 必须：

1. 将 runner apt 配置中 `azure.archive.ubuntu.com` 替换为 `archive.ubuntu.com`，覆盖 `/etc/apt` 下 `.list` 和 `.sources` 文件；替换失败或没有文件不得使后续命令静默误判成功。
2. `apt-get update` 有 180 秒硬超时。
3. `apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev build-essential` 有 180 秒硬超时。
4. 保留 `sudo`、非交互安装和原有软件包集合。
5. 不修改 Android、Windows、Release job 的逻辑。

推荐 workflow shell 片段：

```yaml
- name: Install Linux build dependencies
  run: |
    sudo find /etc/apt -type f \( -name '*.list' -o -name '*.sources' \) -exec sed -i 's/azure.archive.ubuntu.com/archive.ubuntu.com/g' {} +
    timeout 180s sudo apt-get update
    timeout 180s sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev build-essential
```

如果实现选择不同命令，必须保持同等语义并在报告中解释。

## 验收标准

1. 红阶段：在修改前运行 `flutter test test/release_workflow_test.dart --timeout 3m`，新增/更新 Linux apt resilience 断言必须先失败；记录真实非零结果。
2. 绿阶段：同一测试通过，断言 Linux job：
   - 仍安装原五个包；
   - 替换 apt mirror；
   - `apt-get update` 和 `apt-get install` 都有 `timeout 180s`；
   - Android、Windows、Release job 相关文本未改变。
3. YAML 解析通过：

```bash
python -c "import yaml; d=yaml.safe_load(open('.github/workflows/manual-build-artifacts.yml')); print(list(d['jobs']))"
```

预期 jobs 为 `android`, `windows`, `linux`, `release`。

4. `git diff --check` 通过，改动范围只在允许文件。
5. 不得 push、不得调用 `gh workflow run`；本任务只修 workflow 并做本地契约验证。真实 Linux runner 验证由 Hermes 合并推送后观察。

## 决策点

遇到以下情况停止并报告：

- 现有 workflow 测试无法表达 apt mirror/timeout 契约而需要修改测试框架；
- 需要修改 Android、Windows、Release 或业务代码；
- 无法保证 timeout 在 GitHub Ubuntu runner 上可用；
- 需要新增 apt 软件源凭据、secret 或人工交互。
