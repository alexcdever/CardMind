# 工作流状态快照

> 本文档记录项目当前状态，每次 `/checkpoint` 时更新。
> 这是第三层记忆：当前快照（第一层：auto memory，第二层：工作日志）

## 当前进行中的工作

<!-- 列出当前正在进行的任务，最多3个 -->

1. 按 `docs/plans/2026-03-23-phase2-trust-first-recovery-implementation-plan.md` 执行 `Phase 2` 信任优先恢复实现 - 进度 0%
2. 迁移 Flutter / FRB / 测试代码中对旧 `projectionState` 的依赖到 `queryConvergenceState` 等新契约字段 - 进度 0%
3. 维持 Rust-first 恢复契约边界，避免 Flutter 重新承担恢复语义推断 - 进度 15%

## 待办事项

<!-- 待处理但尚未开始的任务 -->

- [ ] 开始执行 `Phase 2` trust-first recovery implementation plan
- [ ] 完成 Rust 侧 `query_convergence / sync / instance_continuity` 恢复契约落地
- [ ] 完成 Flutter 侧 `queryConvergenceState` 契约消费与 UI 反馈迁移
- [ ] 清理 `lib/` 与 `test/` 中遗留的 `projectionState` 引用
- [ ] 跑完 plan 里定义的 bridge / quality / boundary scan 验证

## 阻塞/卡点

<!-- 当前遇到的阻碍 -->

- 当前无工程阻塞
- 当前主要工作不是继续做产品收敛，而是开始执行已确认的 `Phase 2` implementation plan

## 最近的决策

<!-- 最近做出的重要决策 -->

| 日期 | 决策内容 | 原因 |
|------|----------|------|
| 2026-03-18 | 边界扫描器按语言范围 gate | Flutter 与 Rust 质量门禁应分别校验，避免互相阻塞 |
| 2026-03-18 | 停止跟踪 boundary scanner 构建产物 | 避免 target/debug 生成物持续污染工作区 |
| 2026-03-18 | Test Boundary Guardian 系统已合并到 main | 功能开发完成，质量检查通过 |
| 2026-03-18 | 新增网络层单元测试 54 个 | endpoint.rs 和 pool_network.rs 纯函数全覆盖 |
| 2026-03-20 | 新增 `docs/specs/product.md` 作为产品级真相源 | 统一终极目标、阶段目标、目标用户和能力边界，减少 AI 与文档漂移 |
| 2026-03-20 | 新增 `docs/specs/user-journeys.md` 作为旅程层下游规格 | 把“产品是什么”下沉为“用户如何感知产品成立”的正式真相源 |
| 2026-03-20 | 当前阶段移除设置一级入口，而不是补设置中心 | 设置空壳入口持续制造完成度损伤与优先级误导，应先收紧公开主导航语义 |
| 2026-03-20 | 私人背景转入本地 `AGENT.local.md` 而非公开仓库 | 信息对 AI 有价值，但不适合开源暴露 |
| 2026-03-20 | 产品相关 design/plan 文档继续统一放在 `docs/plans/` | 遵循当前仓库的文档分层规范 |
| 2026-03-23 | `Phase 1` 实施改为 Rust-first | 同步、恢复与连续性语义应由 Rust 契约定义，Flutter 只负责消费与展示 |
| 2026-03-23 | API integration tests 串行化 | 避免 `app_config` 全局状态在全量 Rust 测试时互相污染 |
| 2026-03-23 | FRB 生成链补齐 `freezed_annotation` / `freezed` / `build_runner` | 新 DTO 字段进入边界层后需要重新生成 Rust/Dart 绑定 |
| 2026-03-23 | `Phase 2` 主目标定义为“内容安全信任优先” | 异常持续存在时，首先要让用户相信本地内容仍安全 |
| 2026-03-23 | 内部术语从“投影”改为“查询收敛” | `LoroDoc -> SQLite` 读模型收敛比“投影”更准确、也更易理解 |
| 2026-03-23 | 用户层保留“设备”，系统层使用“app 实例” | 同时兼顾用户理解成本和契约精度 |
| 2026-03-23 | `Phase 2` implementation plan 已完成并通过 reviewer 收口 | 可以从设计阶段切换到执行阶段 |

## 相关文档链接

<!-- 链接到相关的 specs 和 plans -->

- [产品级真相源规格](docs/specs/product.md)
- [用户旅程规格](docs/specs/user-journeys.md)
- [roadmap design](docs/plans/2026-03-23-next-phase-roadmap-design.md)
- [roadmap implementation plan](docs/plans/2026-03-23-next-phase-roadmap-implementation-plan.md)
- [phase2 trust-first recovery design](docs/plans/2026-03-23-phase2-trust-first-recovery-design.md)
- [phase2 trust-first recovery implementation plan](docs/plans/2026-03-23-phase2-trust-first-recovery-implementation-plan.md)
- [产品深度审计](docs/plans/2026-03-19-cardmind-product-audit.md)
- [产品真相源实施计划](docs/plans/2026-03-19-product-truth-source-implementation-plan.md)
- [移除设置一级入口设计](docs/plans/2026-03-20-remove-settings-primary-entry-design.md)
- [移除设置一级入口实施计划](docs/plans/2026-03-20-remove-settings-primary-entry-implementation-plan.md)
- [今日工作日志](docs/memory/2026-03-23.md)

---

*最后更新：2026-03-23*
