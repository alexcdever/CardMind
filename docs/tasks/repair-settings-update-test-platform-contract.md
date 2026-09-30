# 任务：修复更新流程跨平台测试契约

<!-- Task ID: repair-settings-update-test-platform-contract -->

```pipeline-contract
{
  "schema": 4,
  "task_id": "repair-settings-update-test-platform-contract",
  "task_type": "repair",
  "project_type": "desktop",
  "risk": "medium",
  "goal": {"path": "docs/goal.md"},
  "allowed_paths": ["test/settings_page_test.dart", ".pipeline/repair-settings-update-test-platform-contract/"],
  "forbidden_paths": ["lib/rust/**", "rust-backend/**", "pubspec.yaml", "pubspec.lock", ".env"],
  "non_goals": ["不改变生产更新流程或平台产品行为", "不删除 macOS/Linux 打开安装包行为的覆盖", "不清理历史 worktree 或旧证据"],
  "operations": [
    {
      "id": "repair-platform-aware-widget-test",
      "kind": "modify-test",
      "scope": "使设置页更新下载测试匹配平台条件，同时保持现有安装器与路径断言",
      "resources": ["test/settings_page_test.dart"],
      "resource_mode": "single",
      "acceptance_tests": ["acceptance-test-focused", "acceptance-test-analysis"]
    }
  ],
  "chain": {
    "entry": ["test/settings_page_test.dart: download button shows progress and installer result"],
    "interaction": ["lib/pages/settings_page.dart: _SettingsPageState.build"],
    "application": ["test/settings_page_test.dart: UpdateService and _InstallerFake assertions"],
    "domain": [{"not_applicable": true, "reason": "本修复只调整已有 Widget 测试的平台条件，不改变领域行为"}],
    "persistence": [{"not_applicable": true, "reason": "本修复不修改持久化"}],
    "readback": ["test/settings_page_test.dart: installation path and platform action assertions"],
    "recovery": ["test/settings_page_test.dart: platform-aware assertion keeps the test runnable on Windows and preserves non-Windows coverage"]
  },
  "acceptance_tests": [
    {
      "id": "acceptance-test-focused",
      "evidence_level": 3,
      "test_ref": "test/settings_page_test.dart: download button shows progress and installer result",
      "command_ref": "flutter test --timeout 3m test/services/platform_update_installer_test.dart test/services/update_download_manager_test.dart test/settings_page_test.dart"
    },
    {
      "id": "acceptance-test-analysis",
      "evidence_level": 3,
      "test_ref": "test/settings_page_test.dart: download button shows progress and installer result",
      "command_ref": "flutter analyze"
    }
  ],
  "dependencies": [],
  "required_evidence_levels": [3],
  "assumptions": ["Windows 当前不显示 open-update-package 是既定平台条件", "生产代码的跨平台 UI 条件不在本任务范围内"],
  "unknowns": ["当前环境是否具备完整 Flutter 依赖与全量测试所需原生运行库"]
}
```

## 任务身份

- 项目：CardMind
- 领域：Flutter 设置页更新流程测试
- 任务类型：`repair`
- 用户结果：更新下载 Widget 测试在 Windows 上可靠通过，同时不削弱 macOS/Linux 的打开安装包覆盖。
- 执行 worktree：`D:/Projects/CardMind/.worktrees/repair-settings-update-test-platform-contract`

## 依赖与范围

### 允许修改

- `test/settings_page_test.dart`
- `.pipeline/repair-settings-update-test-platform-contract/` 中的任务证据

### 明确不改

- `lib/pages/settings_page.dart` 及所有生产代码
- 更新服务、安装器、清单格式、Rust/FRB、依赖和平台配置
- 历史 worktree、历史 `.workflow` 证据和任务单

## 已确认事实

- 主工作树已快进到 `6e85685a` 且 `main` 与 `origin/main` 一致。
- `test/settings_page_test.dart:202` 的测试无条件查找 `open-update-package`。
- `lib/pages/settings_page.dart:351-356` 仅在 `Platform.isMacOS || Platform.isLinux` 渲染该按钮。
- 独立检查子代理实际运行聚焦测试并报告 Windows 下 `23 passed, 1 failed`，失败为 `Bad state: No element`。

## 设计与行为契约

测试应始终验证：发现更新、下载完成、安装器启动结果、收到的文件和安装包路径。仅当当前平台渲染 `open-update-package` 时，才验证打开安装包回调；在 Windows 上应验证实际存在的安装结果，而不是查找不存在的控件。不得通过跳过整个测试或删除核心断言来消除失败。

## 环境前置

- 从任务 worktree 根目录执行 Flutter 测试和分析。
- 测试命令外层超时 180 秒，Flutter 测试使用 `--timeout 3m`。

## 验收测试

### 验收测试1：跨平台更新 Widget 测试

- 触发：运行更新下载设置页测试。
- 断言：Windows 不再因不存在的 `open-update-package` 失败；安装器启动、文件和路径断言保留；macOS/Linux 条件行为仍被验证。
- 测试：`test/settings_page_test.dart: download button shows progress and installer result`
- 命令：`flutter test --timeout 3m test/services/platform_update_installer_test.dart test/services/update_download_manager_test.dart test/settings_page_test.dart`
- 验收模式：Widget/单元
- 证据等级：3
- 结果要求：退出码 0，所有测试通过。

### 验收测试2：静态分析

- 触发：分析修改后的 Dart 测试。
- 断言：无新增分析错误。
- 测试：`test/settings_page_test.dart: download button shows progress and installer result`
- 命令：`flutter analyze`
- 验收模式：静态分析
- 证据等级：3
- 结果要求：退出码 0。

## 决策点

若发现必须改变生产 UI 才能合理完成跨平台契约，或必须扩大到 macOS/Linux 实机测试环境，保留 worktree 并报告，不自行扩大范围。
