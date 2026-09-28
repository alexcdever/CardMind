# Dispatch — log-dir-load-failure-state

- task-id: log-dir-load-failure-state
- 契约提交: 521a8c5411b62c6aa711dadfee9fc9ff27b39f72
- 主工作树: /Users/alexc/Projects/CardMind (main)
- 实现 worktree: /Users/alexc/Projects/CardMind/.worktrees/log-dir-load-failure-state
- 实现 branch: pipeline/log-dir-load-failure-state
- 创建方式: git worktree add -b pipeline/log-dir-load-failure-state .worktrees/log-dir-load-failure-state 521a8c5411b62c6aa711dadfee9fc9ff27b39f72

## 证据边界
- 本仓库无 .gitnexus/run.cjs，GitNexus impact 工具不可用。
- 真实「解析失败」在生产中难以人为触发，本任务用注入抛异常的 resolver 模拟（既有测试注入机制）。