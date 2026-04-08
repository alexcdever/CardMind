# 工作流状态快照

> 本文档记录项目当前状态，每次 `/checkpoint` 时更新。
> 这是第三层记忆：当前快照（第一层：auto memory，第二层：工作日志）

## 当前进行中的工作

1. `Pool` 前端已完成一轮实质减负并先停住；首页壳层已完成第一步约束落地（`PoolShell` 下沉 gate）并补齐测试护栏，下一步可继续评估返回键/退出确认职责是否需要进一步固化。
2. Rust macOS 动态库运行态路径统一已完成并合并到 `main`；如需继续提升工程体验，下一步可评估 worktree 间共享 Cargo 编译缓存。

## 最近完成的工作

1. ~~首页壳层测试护栏补齐~~ ✅ **已完成**（2026-04-08）
   - 首页测试明确 `pool` 分域装配经由 `PoolShell`
   - 修正与当前壳层分层方向冲突的旧断言
   - 首页壳层边界开始具备测试级防回退能力

2. ~~首页壳层第一步约束落地~~ ✅ **已完成**（2026-04-08）
   - 新增 `PoolShell`
   - `AppLockGate` 从 `AppHomepagePage` 下沉到 `PoolShell`
   - 首页壳层不再直接承接 pool 分域入口 gate
   - 首页相关测试通过

3. ~~Rust macOS 动态库运行态路径统一~~ ✅ **已完成**（2026-04-08）
   - 官方运行态 dylib 收口到 `build/native/macos/libcardmind_rust.dylib`
   - `tool/build.dart lib` 改为构建后自动同步官方运行态 dylib
   - `tool/build.dart run` 改为从官方运行态目录复制到 app bundle
   - `main.dart` 与 FRB 真库测试统一改走共享 dylib 路径入口
   - `README.md`、`AGENTS.md`、`tool/DIR.md`、`lib/DIR.md` 已同步更新路径职责说明

4. ~~Pool 前端一轮实质减负~~ ✅ **已完成**（2026-04-07）
   - `PoolPage` 主文件收成状态分发入口
   - 特殊错误判断从散写逻辑收成控制器私有守卫
   - `approvalMessage` 从 `PoolState` 中移出，改为 `PoolController.noticeMessage`
   - `exitShouldFail` / `rejectShouldFail` 从生产状态模型移除
   - 测试改为通过 fake API client 制造失败路径
   - 相关 unit / widget / integration 测试通过

5. ~~Pool 前端第一轮结构收口~~ ✅ **已完成**（2026-04-07）
   - `PoolPage` 主文件收成状态分发入口
   - 对话框逻辑拆到 `pool_page_dialogs.dart`
   - 页面块拆到 `pool_page_sections.dart`
   - 同步反馈拆到 `pool_sync_feedback.dart`
   - 相关 widget 测试通过

6. ~~文档权威边界收紧~~ ✅ **已完成**（2026-04-07）
   - 明确 `docs/standards/` 与 `docs/specs/` 是当前实现依据
   - 将 `docs/plans/` 降权为历史设计/计划/审计记录目录
   - 收紧 `spec-first-execution`，禁止把未确认项直接写成正式规格

7. ~~Phase 3 数据池规格定版~~ ✅ **已完成**（2026-04-07）
   - 应用锁前置条件
   - 加入申请取消
   - 解散后只读态
   - 退出/重新加入后的访问边界
   - 黑盒验收标准补齐

8. ~~Phase 3 数据池治理与安全基线~~ ✅ **已完成**（2026-04-05）
   - 应用锁（Rust 状态机 + Flutter guard/UI）
   - 数据池 API 应用锁 gating
   - 最后管理员不能退出
   - 池解散与已解散只读态
   - 加入申请提交 / 审批 / 拒绝 / 取消
   - Rust / Flutter / FRB / contract / integration / widget 测试链路打通

9. ~~质量门禁基线清理~~ ✅ **已完成**（2026-04-05）
   - `flutter analyze` 通过
   - `cargo fmt --check` 通过
   - `cargo clippy` 通过
   - `dart run tool/quality.dart all` 通过

10. ~~应用锁前置能力~~ ✅ **已完成**（2026-04-05）
   - Rust 安全状态机与存储抽象
   - Flutter 应用锁服务、界面与 guard
   - 池相关 API 必须在解锁后访问

## 待办事项

- [ ] 如继续处理首页壳层，将禁止继续注入 `AppHomepagePage` 的职责清单落到规则或存档入口
- [ ] 如继续处理首页壳层，评估返回键/退出确认职责是否需要进一步固化为规则或测试护栏
- [ ] 如需继续提升多 worktree 开发体验，评估是否引入共享 Cargo 编译缓存策略
- [ ] 如需继续优化，补 `tmp/cardmind_test_boundary_report.md` 中高优先级边界测试

## 阻塞/卡点

- 当前无工程阻塞，主要问题转为信息架构与历史资产收口

## 最近的决策

| 日期 | 决策内容 | 原因 |
|------|----------|------|
| 2026-04-08 | macOS 运行态 dylib 的唯一真相源收口为 `build/native/macos/libcardmind_rust.dylib` | 统一测试、运行与 app bundle 的动态库来源，降低“库不存在/库有问题”的路径漂移风险 |
| 2026-04-08 | `rust/target/release/libcardmind_rust.dylib` 仅保留为 Cargo 编译缓存源 | 避免 Cargo 编译产物继续被误用为运行态真相源 |
| 2026-04-07 | `docs/plans/` 默认不作为当前实现依据，仅保留历史记录与 ADR 参考价值 | 避免历史设计/计划文档继续误导当前实现与 AI 判断 |
| 2026-04-07 | 当前实现依据收敛为 `docs/standards/` 与 `docs/specs/` | 需要明确真相源，降低文档层混乱与跑偏风险 |
| 2026-04-07 | 采用“持续开发 + 关键停顿点”的协作理解 | 比硬阶段切分更符合个人开发节奏和 superpowers 的使用方式 |
| 2026-04-07 | `PoolPage` 前端层可保留但不可继续扩展，后续再碰必须先收口结构边界 | 页面、控制器与状态模型已开始混入测试/模拟/提示拼装职责，继续叠功能会显著增加维护暴雷风险 |
| 2026-04-07 | `PoolPage` 第一轮收口先只处理页面结构与明显的特殊错误判断，不扩展到整套消息体系 | 先提升可读性并降低膨胀风险，避免过早卷入 `PoolState` 与提示体系的更大重构 |
| 2026-04-07 | `Pool` 前端测试失败路径必须通过 fake API client 制造，不再写进生产状态模型 | 避免测试味字段继续污染 `PoolState`，让生产代码只处理真实错误语义 |
| 2026-04-07 | 首页壳层可保留为主壳资产，但不应继续承担新的跨功能编排职责 | 当前控制器与壳层组件边界仍然健康，但 `AppHomepagePage` 已开始承接全局入口编排，继续扩责会滑向总装入口 |
| 2026-04-07 | 首页壳层禁止继续注入新的产品流程判定、跨功能 guard、全局弹窗、业务入口装配与业务状态持有 | 保持首页壳层只负责导航与壳层返回行为，避免继续演化成产品总调度页 |
| 2026-04-08 | `Pool` 分域入口 gate 已下沉到 `PoolShell` | 用分域壳层承接分域前置条件，比继续挂在首页壳层更符合前端入口分层约束 |
| 2026-04-08 | 首页壳层边界应通过测试护栏保护，至少确保 `pool` 分域装配经由 `PoolShell` | 仅靠文档约束不足以防回退，测试可直接阻止首页再次吸收 pool 分域入口职责 |
| 2026-04-07 | `AppLock` 前端层当前健康，可继续保留 | 状态模型、服务、guard 与 screen 边界清晰，当前不属于高风险负资产 |
| 2026-04-05 | 应用锁作为数据池功能前置安全基线 | 离线设备数据无法强制删除，需要先保证本地访问受控 |
| 2026-04-05 | 应用锁采用 Rust 负责状态与存储、Flutter 负责 UI 与生物识别调度 | 保持 Rust-first 业务真相源，同时复用设备原生交互能力 |
| 2026-04-05 | 数据池相关 API 统一增加应用锁 gating | 避免在未解锁状态下访问池治理与同步能力 |

## 相关文档链接

- [今日工作日志（2026-04-08）](docs/memory/2026-04-08.md)
- [今日工作日志](docs/memory/2026-04-07.md)
- [文档总入口](docs/DIR.md)
- [计划目录说明](docs/plans/DIR.md)
- [规格目录说明](docs/specs/DIR.md)
- [规格优先执行规范](docs/standards/spec-first-execution.md)
- [动态库路径统一设计](docs/plans/2026-04-08-rust-dylib-runtime-path-unification-design.md)
- [动态库路径统一实施计划](docs/plans/2026-04-08-rust-dylib-runtime-path-unification-implementation-plan.md)
- [Phase 3 设计文档](docs/plans/2026-03-27-phase3-data-flow-extension-assessment-design.md)
- [数据池规格](docs/specs/pool.md)
- [边界扫描报告](tmp/cardmind_test_boundary_report.md)

---

*最后更新：2026-04-08*
