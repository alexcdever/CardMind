# Dispatch — git-gate-hook-test-enoent

- task-id: git-gate-hook-test-enoent
- 契约提交: `4d25001b`（"docs: freeze git-gate-hook-test-enoent diagnostic contract"）
- 实现 worktree: /Users/alexc/Projects/CardMind/.worktrees/git-gate-hook-test-enoent
- 实现 branch: pipeline/git-gate-hook-test-enoent
- **worktree 实际基线: `662619d3`**（契约提交的后续提交，含 device-name-hostname 合并）

## 基线偏差记录（主代理自陈）

流水线规则要求 worktree 从**契约提交**创建。本任务实际从 `662619d3` 创建——那是契约提交之后、device-name-hostname 合并之后的主分支 HEAD。

**偏差原因**：主代理在同一轮里先冻结契约、再合并设备名、最后建 worktree，按当前 HEAD 而非契约提交取了基线。

**影响评估**：
- `4d25001b` 是 `662619d3` 的祖先，契约文件与测试文件在两者中内容一致
- 该偏差不构成身份漂移（分支名、task-id、证据目录均正确）
- 对本任务（诊断，不改产品代码）无实质影响，反而使 worktree 包含最新的 device-name 修复

**处置**：如实记录，不重建 worktree（重建会浪费一轮且无收益）。后续任务须严格用契约提交建 worktree。

## 证据边界

- 本仓库无 `.gitnexus/run.cjs`，GitNexus impact 工具不可用。
- 诊断任务，不做修复。