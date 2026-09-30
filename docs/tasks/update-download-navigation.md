# 更新下载跨页面持续任务

<!-- Task ID: update-download-navigation -->

```pipeline-contract
{
  "schema": 4,
  "task_id": "update-download-navigation",
  "task_type": "repair",
  "project_type": "desktop",
  "risk": "medium",
  "goal": {"path": "docs/tasks/update-download-navigation.md"},
  "allowed_paths": [
    "lib/main.dart",
    "lib/pages/settings_page.dart",
    "lib/services/update_download_manager.dart",
    "test/settings_page_test.dart",
    "test/services/update_download_manager_test.dart",
    "docs/tasks/update-download-navigation.md",
    ".pipeline/update-download-navigation/**"
  ],
  "forbidden_paths": [".env", "rust-backend/**", "lib/src/rust/**"],
  "non_goals": [
    "不实现应用进程退出后的系统级后台下载",
    "不修改更新清单格式、下载校验规则或平台安装身份"
  ],
  "operations": [
    {
      "id": "persistent-download-owner",
      "kind": "repair",
      "scope": "Flutter update download lifecycle",
      "resources": ["lib/services/update_download_manager.dart"],
      "resource_mode": "single",
      "acceptance_tests": ["acceptance-test-1", "acceptance-test-2"]
    },
    {
      "id": "settings-reentry-ui",
      "kind": "regression-test",
      "scope": "SettingsPage navigation and state restoration",
      "resources": ["test/settings_page_test.dart", "lib/pages/settings_page.dart"],
      "resource_mode": "batch",
      "acceptance_tests": ["acceptance-test-1", "acceptance-test-3"]
    }
  ],
  "chain": {
    "entry": ["SettingsPage download-update button"],
    "interaction": ["SettingsPage -> UpdateDownloadManager"],
    "application": ["CardMindApp shared manager and /settings route"],
    "domain": ["UpdateDownloadManager download/install state"],
    "persistence": ["not applicable: download state is process-local and is not written to the business database"],
    "readback": ["new SettingsPage restores manifest and final result from shared manager"],
    "recovery": ["explicit cancel and downloader/installer exception recovery"]
  },
  "acceptance_tests": [
    {
      "id": "acceptance-test-1",
      "evidence_level": 3,
      "test_ref": "test/settings_page_test.dart: shared manager keeps download alive across settings navigation (testWidgets)",
      "command_ref": "flutter test test/settings_page_test.dart --timeout 3m"
    },
    {
      "id": "acceptance-test-2",
      "evidence_level": 3,
      "test_ref": "test/services/update_download_manager_test.dart: explicit cancellation wins the success/install race (test); downloader and installer exceptions become visible failure state (test)",
      "command_ref": "flutter test test/services/update_download_manager_test.dart --timeout 3m"
    },
    {
      "id": "acceptance-test-3",
      "evidence_level": 3,
      "test_ref": "test/vertical_slice_widget_test.dart: note list settings entry navigates to settings without losing list (testWidgets)",
      "command_ref": "flutter test test/vertical_slice_widget_test.dart --timeout 3m"
    }
  ],
  "dependencies": [],
  "required_evidence_levels": [2, 3],
  "assumptions": [{"fact": "Flutter test environment is available"}],
  "unknowns": [{"fact": "Windows and Android real installer UI were not exercised in this macOS run"}]
}
```

## 目标

离开设置页不会取消正在进行的更新下载；重新进入设置页后恢复下载状态和最终安装提示。用户明确取消时仍会取消，异常会进入可恢复失败状态。

## 验收边界

本任务覆盖 Flutter 应用进程内的页面导航生命周期，不承诺应用进程被系统终止后的后台下载。
