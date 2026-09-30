# 任务：恢复更新任务单的精确验收测试引用

<!-- Task ID: repair-task-acceptance-test-refs -->

```pipeline-contract
{
  "schema": 4,
  "task_id": "repair-task-acceptance-test-refs",
  "task_type": "repair",
  "project_type": "service",
  "risk": "low",
  "goal": {"path": "docs/goal.md"},
  "allowed_paths": ["docs/tasks/update-download-navigation.md", ".pipeline/repair-task-acceptance-test-refs/"],
  "forbidden_paths": ["lib/**", "test/**", "rust-backend/**", ".env"],
  "non_goals": ["不修改生产代码或测试行为", "不改变任务单验收命令和产品契约", "不清理历史证据或 worktree"],
  "operations": [{"id":"restore-test-refs","kind":"documentation-repair","scope":"恢复三个 acceptance_tests.test_ref 的精确测试名称","resources":["docs/tasks/update-download-navigation.md"],"resource_mode":"single","acceptance_tests":["acceptance-test-refs","acceptance-test-check"]}],
  "chain": {
    "entry": ["docs/tasks/update-download-navigation.md acceptance_tests"],
    "interaction": ["not applicable: documentation-only repair"],
    "application": ["not applicable: documentation-only repair"],
    "domain": ["not applicable: documentation-only repair"],
    "persistence": ["not applicable: documentation-only repair"],
    "readback": ["docs/tasks/update-download-navigation.md exact test_ref values"],
    "recovery": ["existing acceptance command references remain unchanged"]
  },
  "acceptance_tests": [
    {"id":"acceptance-test-refs","evidence_level":1,"test_ref":"docs/tasks/update-download-navigation.md: acceptance_tests","command_ref":"git grep -n 'test_ref' -- docs/tasks/update-download-navigation.md"},
    {"id":"acceptance-test-check","evidence_level":1,"test_ref":"test/settings_page_test.dart: shared manager keeps download alive across settings navigation (testWidgets)","command_ref":"flutter test --timeout 3m test/settings_page_test.dart test/services/update_download_manager_test.dart test/vertical_slice_widget_test.dart"}
  ],
  "dependencies": [],
  "required_evidence_levels": [1],
  "assumptions": ["三个精确测试名称当前仍存在"],
  "unknowns": []
}
```

## 目标
恢复 `update-download-navigation` 任务单中三个验收测试的精确 `test_ref`，使后续审查可以直接定位用例，而不改变测试命令或代码行为。

## 允许修改
- `docs/tasks/update-download-navigation.md`
- `.pipeline/repair-task-acceptance-test-refs/` 任务证据

## 明确不改
- 生产代码、测试代码、依赖、平台配置和其他任务单
- 历史 `.workflow` 证据与 worktree

## 已确认事实
- 当前三个 `test_ref` 仅指向文件。
- 精确用例仍存在：
  - `test/settings_page_test.dart: shared manager keeps download alive across settings navigation (testWidgets)`
  - `test/services/update_download_manager_test.dart: explicit cancellation wins the success/install race (test); downloader and installer exceptions become visible failure state (test)`
  - `test/vertical_slice_widget_test.dart: note list settings entry navigates to settings without losing list (testWidgets)`
- 当前 Flutter 聚焦测试与 `flutter analyze` 已通过；本任务只恢复文档精度。

## 验收
恢复以上三个精确引用；原有命令保持不变；文档检查和对应 Flutter 测试通过。

## 决策点
如果任何精确测试已不存在，保留 worktree并报告，不自行改写为近似引用。
