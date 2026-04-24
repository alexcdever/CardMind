# 工作流状态快照

> 本文档记录项目当前状态，每次 `/checkpoint` 时更新。
> 这是第三层记忆：当前快照（第一层：auto memory，第二层：工作日志）

## 当前进行中的工作

1. Pencil 数据池原型已补齐应用锁前置流程：桌面端和移动端均包含 App Lock Setup 与 App Lock Unlock。
2. App Lock 页面已插入原有流程链路：Data Pool 入口 -> 应用锁设置 / 解锁 -> Data Pool Setup -> Data Pool Members。
3. Pencil 画布排版已调整，避免新增解锁页面覆盖既有数据池页面；`snapshot_layout(problemsOnly: true)` 已确认无布局问题。
4. 当前正在执行存档与提交保存；本轮 Pencil 改动已通过截图复核与 `git diff --check`。

## 最近完成的工作

1. ~~Pencil 数据池应用锁前置流程补齐~~ ✅ **已完成**（2026-04-24）
   - 新增桌面端 App Lock Setup / App Lock Unlock 原型页
   - 新增移动端 App Lock Setup / App Lock Unlock 原型页
   - 将应用锁页面插入原有数据池流程链路，而不是作为孤立补充页
   - 同步调整流程箭头与说明：进入 Data Pool 先设置 / 解锁，验证通过后进入 Data Pool Setup
   - Pencil 截图复核通过，`snapshot_layout(problemsOnly: true)` 返回无布局问题

2. ~~数据池运行态 UI 与 Rust API 串接~~ ✅ **已完成**（2026-04-24）
   - `PoolRuntimeApiClient` 聚合运行态 summary、members runtime view 与 active invites
   - `PoolController` 新增 runtime view 状态、加载状态、create invite 与 revoke invite 动作
   - `PoolPage` 已加入态按 poolId 懒加载 runtime view
   - 数据池页面重做为贴近 Pencil 的 setup / network nodes 展示，同时保留既有测试依赖的关键文案与操作入口
   - 单元测试与组件测试已覆盖运行态加载、invite 撤销刷新与已加入页面 runtime 信息展示

3. ~~GitNexus 清理与本地卸载~~ ✅ **已完成**（2026-04-24）
   - `AGENTS.md` 已移除 GitNexus agent 指引块
   - 仓库根部 `.claude/`、`.gitnexus/` 产物已删除
   - 本地 pnpm 全局 `gitnexus` 已卸载，残留包目录与 bin 链接已清理
   - 已验证 `command -v gitnexus` 无结果，agent 文档无 GitNexus 内容，仓库根部无 GitNexus 产物目录

4. ~~GitNexus 与 AI 正确性适配评估~~ ✅ **已完成**（2026-04-24）
   - 将评估目标收敛为“是否提升 AI 改代码正确性”，重点关注少漏改影响点与跨模块/跨语言关系理解
   - 基于当前仓库结构梳理出 CardMind 中 AI 最容易漏改的 8 类影响链，覆盖 Rust API -> FRB -> Dart 调用方 -> 测试、Pool/Sync 状态链路、运行态构建链与 `docs/specs/` 真相源
   - 结论收敛为：`GitNexus` 对本项目“可以关注，但暂不优先”，暂不投入接入成本

4. ~~脚本级硬约束方向评估~~ ✅ **已完成**（2026-04-24）
   - 评估了哪些问题适合通过脚本、hook、CI 强约束解决，哪些不适合硬卡
   - 收敛出最值得做的方向：FRB 生成物新鲜度检查、按改动范围提升质量门禁、把增量高优先级边界未覆盖从 warning 升级为 fail
   - 用户确认本轮不推进实现，只保留评估结论供后续参考

5. ~~GitNexus 协作入口文档更新~~ ✅ **已完成**（2026-04-24）
   - 在 `AGENTS.md` 与 `CLAUDE.md` 末尾新增 GitNexus 使用约束，补齐 impact analysis、detect changes 与高风险告警要求
   - 在 `.gitignore` 中新增 `.gitnexus`，避免本地索引目录误入版本控制
   - 本次提交范围明确排除未跟踪的外部工具/提示词目录，只保留与仓库协作入口直接相关的文件

6. ~~Flutter / Rust 依赖升级与 FRB 同步~~ ✅ **已完成**（2026-04-23）
   - Flutter 侧已升级 `flutter_rust_bridge ^2.12.0`、`freezed_annotation ^3.1.0`、`freezed ^3.2.5`、`analyzer ^10.0.1`
   - Rust 侧已升级 `flutter_rust_bridge =2.12.0`、`iroh 0.98.1`、`loro 1.11.1`、`rusqlite 0.39`、`thiserror 2`
   - `flutter_rust_bridge_codegen generate` 已重新执行，FRB 生成产物已同步
   - 为兼容新依赖，已收口 `iroh` endpoint builder、`argon2` `OsRng` 引入、测试桩与 `analyzer` AST API 适配
   - 关键验证已通过：`cargo test`、`cargo fmt --all -- --check`、`cargo clippy --all-targets --all-features -- -D warnings`、`flutter analyze`、`flutter test`

4. ~~FRB 质量链与 Flutter 边界扫描收口~~ ✅ **已完成**（2026-04-23）
   - `tool/quality.dart` 的 Flutter 质量链已改为 `markdown lint -> build lib -> FRB codegen -> flutter analyze -> flutter test -> boundary scan`
   - `quality_cli_test.dart` 已同步覆盖新顺序与 FRB 构建失败路径
   - 新增 `debug_startup_support.dart` 及对应测试，补齐启动调试导出辅助逻辑的可测性
   - `SyncStatus` 派生语义与 `FrbPoolApiClient` 缺失运行态上下文的失败路径已补齐单元测试
   - `tool/test_boundary_scanner.dart` 已下调 Flutter 侧几类已验证但会误拦截的逻辑表达式/循环边界
   - 关键验证已通过：`dart run tool/quality.dart flutter`、`dart run tool/test_boundary_scanner.dart --scope=flutter`、相关新增/更新测试

5. ~~测试质量链并发与稳定性收口~~ ✅ **已完成**（2026-04-22）
   - `tool/quality.dart` 已显式收口为 Flutter `-j 4`、Rust `--jobs 1`
   - `quality_cli_test.dart` 已同步断言新命令行参数
   - Rust 删除了 `integration_exact` / `unit_exact` 两个重复测试入口
   - Rust 网络测试已补齐测试专用 `PoolNetwork` 残留清理，修复 `Failed to create netmon monitor`
   - 关键验证已通过：`flutter test test/integration/infrastructure/quality_cli_test.dart`、`cargo test -q --test integration`、`cargo test -q --jobs 1`、`cargo fmt --all -- --check`

6. ~~Rust prototype API-gap / invite 审批链路修复~~ ✅ **已完成**（2026-04-22）
   - invite join 已改为正式审批流：收到 invite 后先落 join request，再由 admin 审批通过后入池
   - invite code 改为每次创建唯一，撤销后不会因重复 code 残留而继续有效
   - `submit_join_request` 与 `approve_join_request` 已补齐 endpoint 可用性校验，守住单 pool 不变量
   - 数据池规格已同步更新到 `docs/specs/pool.md`
   - Rust / Flutter 相关验证已通过，功能分支已 merge 回 `main`，worktree 已移除

7. ~~数据池 pending 语义修正与 Pencil 复现收口~~ ✅ **已完成**（2026-04-16）
   - Pencil 已覆盖当前 Flutter 项目的主要桌面/移动 UI，并按用户反馈调整数据池页结构与成员列表表现
   - `PoolState` 新增 `PoolJoinPending`，加入申请提交后进入独立 pending 页面，不再混入 joined 页面语义
   - 取消加入申请后回到 `PoolNotJoined`
   - 调试导出路径与对应测试改为同步文件 IO，规避当前 widget test 环境下异步文件 API 卡住问题
   - code review 发现并修复 pending 页面同步反馈按钮空实现回归，相关测试与 analyze 已通过

8. ~~iOS Rust framework 自动重建与真实联机复验~~ ✅ **已完成**（2026-04-15）
   - 定位 iOS `join_pool_by_invite(debug_trace)` 新增 FRB panic 的根因是运行态 framework 二进制陈旧，而非网络超时
   - `ios/Podfile` 的 `Copy Rust Framework` build phase 已改为按 `SDK_NAME` 自动执行 `cargo build --release --target <ios-target>`
   - 当前生效的 `ios/Runner.xcodeproj/project.pbxproj` 已同步更新同样逻辑，避免依赖手工再次 `pod install`
   - 新增 `test/integration/infrastructure/ios_podfile_test.dart` 防回退
   - 在不手工预构建 iOS Rust dylib 的前提下，`macOS owner -> iOS simulator joiner` 已再次真实成功 joined

9. ~~数据池 invite 串入池与业务层 handle 收口~~ ✅ **已完成**（2026-04-13）
   - Rust FFI 新增 `create_pool_invite` / `join_pool_by_invite` / `get_pool_network_endpoint_id`
   - `network_id` 背后改为持久 runtime，修复 iroh endpoint 跨 runtime 触发的 `Internal consistency error`
   - `FrbPoolApiClient` 支持仅靠 `appDataDir` 懒加载 runtime，业务层不再需要显式传入 runtime handle
   - `Pool` owner 页面已显示 invite string，真实组网验证路径已具备最小 UI 支撑
   - Rust / Flutter 相关合同、单元、组件、自动化测试均已通过

10. ~~文档治理第二轮收口（B+授权）~~ ✅ **已完成**（2026-04-10）
   - `AGENTS.md` 收敛为仓库入口提示词，不再展开协作流程正文
   - `docs/standards/ai-collaboration.md` 成为唯一协作流程正文，并新增 `Agent` 授权边界
   - `docs/standards/spec-lifecycle.md` 收敛为纯边界判断文档
   - `docs/standards/tdd.md` 改为“默认优先采用 TDD，例外时说明原因并补足验证”
   - 审查 `git-and-pr.md` 与 `testing.md`，确认当前无需调整

11. ~~质量门禁补强：Markdown 引用检查与 docs 子命令~~ ✅ **已完成**（2026-04-10）
   - `tool/lint/markdown_references_linter.dart` 支持锚点、title 文本、URL 编码空格，并在失效时返回非零退出码
   - `tool/quality.dart` 新增 `docs` 子命令，`flutter` 质量链改为先跑文档引用检查
   - 修正主工作区 `docs/` 历史相对引用，并让 linter 默认忽略 `.worktrees/`
   - `README.md` 与 `AGENTS.md` 已同步新增 `dart run tool/quality.dart docs` 说明
   - `dart run tool/quality.dart docs` 与 `dart run tool/quality.dart flutter` 已恢复可用

12. ~~文档体系结构性重构第一轮收口~~ ✅ **已完成**（2026-04-09）
   - 明确 `AGENTS.md`、`docs/specs/`、`docs/plans/`、`docs/standards/` 的职责边界
   - 明确 spec 由“正式行为确认变更”触发更新，而不是由“开始实现”触发更新
   - 新增文档体系结构性重构实施计划
   - 删除 `docs/` 之外的全部 `DIR.md`
   - `fractal-doc-standard.md` 重命名并收口为 `docs-dir-indexing.md`

13. ~~首页壳层测试护栏补齐~~ ✅ **已完成**（2026-04-08）
   - 首页测试明确 `pool` 分域装配经由 `PoolShell`
   - 修正与当前壳层分层方向冲突的旧断言
   - 首页壳层边界开始具备测试级防回退能力

14. ~~首页壳层第一步约束落地~~ ✅ **已完成**（2026-04-08）
   - 新增 `PoolShell`
   - `AppLockGate` 从 `AppHomepagePage` 下沉到 `PoolShell`
   - 首页壳层不再直接承接 pool 分域入口 gate
   - 首页相关测试通过

15. ~~Rust macOS 动态库运行态路径统一~~ ✅ **已完成**（2026-04-08）
   - 官方运行态 dylib 收口到 `build/native/macos/libcardmind_rust.dylib`
   - `tool/build.dart lib` 改为构建后自动同步官方运行态 dylib
   - `tool/build.dart run` 改为从官方运行态目录复制到 app bundle
   - `main.dart` 与 FRB 真库测试统一改走共享 dylib 路径入口
   - `README.md`、`AGENTS.md`、`tool/DIR.md`、`lib/DIR.md` 已同步更新路径职责说明

14. ~~Pool 前端一轮实质减负~~ ✅ **已完成**（2026-04-07）
   - `PoolPage` 主文件收成状态分发入口
   - 特殊错误判断从散写逻辑收成控制器私有守卫
   - `approvalMessage` 从 `PoolState` 中移出，改为 `PoolController.noticeMessage`
   - `exitShouldFail` / `rejectShouldFail` 从生产状态模型移除
   - 测试改为通过 fake API client 制造失败路径
   - 相关 unit / widget / integration 测试通过

15. ~~Pool 前端第一轮结构收口~~ ✅ **已完成**（2026-04-07）
   - `PoolPage` 主文件收成状态分发入口
   - 对话框逻辑拆到 `pool_page_dialogs.dart`
   - 页面块拆到 `pool_page_sections.dart`
   - 同步反馈拆到 `pool_sync_feedback.dart`
   - 相关 widget 测试通过

16. ~~文档权威边界收紧~~ ✅ **已完成**（2026-04-07）
   - 明确 `docs/standards/` 与 `docs/specs/` 是当前实现依据
   - 将 `docs/plans/` 降权为历史设计/计划/审计记录目录
   - 收紧 spec 生命周期规则，禁止把未确认项直接写成正式规格

17. ~~Phase 3 数据池规格定版~~ ✅ **已完成**（2026-04-07）
   - 应用锁前置条件
   - 加入申请取消
   - 解散后只读态
   - 退出/重新加入后的访问边界
   - 黑盒验收标准补齐

18. ~~Phase 3 数据池治理与安全基线~~ ✅ **已完成**（2026-04-05）
   - 应用锁（Rust 状态机 + Flutter guard/UI）
   - 数据池 API 应用锁 gating
   - 最后管理员不能退出
   - 池解散与已解散只读态
   - 加入申请提交 / 审批 / 拒绝 / 取消
   - Rust / Flutter / FRB / contract / integration / widget 测试链路打通

19. ~~质量门禁基线清理~~ ✅ **已完成**（2026-04-05）
   - `flutter analyze` 通过
   - `cargo fmt --check` 通过
   - `cargo clippy` 通过
   - `dart run tool/quality.dart all` 通过

20. ~~应用锁前置能力~~ ✅ **已完成**（2026-04-05）
   - Rust 安全状态机与存储抽象
   - Flutter 应用锁服务、界面与 guard
   - 池相关 API 必须在解锁后访问

## 待办事项

- [ ] 如继续实现 Flutter UI，可把 Pencil 中的应用锁前置流程映射到当前 `AppLockScreen` 的视觉与交互细节
- [ ] 如继续推进数据池能力，优先做真实双端联机验证或新的定向 code review
- [ ] 如继续提升 UI 验证质量，可补一轮不同窗口尺寸下的数据池页面人工/自动截图检查
- [ ] 如后续重新评估 AI 协作基础设施，优先验证 FRB 新鲜度门禁和按改动范围提升质量门禁，而不是先引入新的索引型工具
- [ ] 如后续希望降低 AI 漏改风险，可把本轮整理的 8 类影响链转成 AI 改动前检查清单或增量门禁脚本
- [ ] 如需继续提升覆盖率质量，优先处理 `tmp/cardmind_test_boundary_report.md` 中现存的常规未覆盖边界
- [ ] 如继续推进数据池能力，优先做下一轮真实双端联机验证或新的定向 code review
- [ ] 如继续优化 Rust 质量链，优先评估 `cargo tarpaulin` 阶段的耗时与稳定性，而不是继续增加测试并发
- [ ] 评估是否为 `tool/debug_pool.dart` 增加更可读的阶段日志、失败诊断与收尾清理输出
- [ ] 评估是否为 app 内置最小网络自检模块，输出 endpoint 可达性 / 地址可见性 / 连接尝试结果
- [ ] 评估是否改为直接从 Flutter debug 会话或 VM Service 获取 invite / 状态，而不是继续依赖文件导出
- [ ] 视需要把 `debug_pool` 的 macOS 隔离副本策略抽成更通用的调试基础设施
- [ ] 评估 `Copy Rust Framework` 最小方案是否需要升级为更稳定的 xcframework/统一产物流程
- [ ] 如继续收口架构，评估 `PoolShell` / `SyncService` 装配面对 `network_id` 的剩余暴露
- [ ] 如继续优化文档治理，输出一页职责地图，明确核心文档负责什么、不再负责什么
- [ ] 如需继续提升多 worktree 开发体验，评估是否引入共享 Cargo 编译缓存策略

## 阻塞/卡点

- 当前无业务阻塞；若继续推进，主要遗留是数据池真实双端联机复验、覆盖率提升、Rust 覆盖率链路稳定性，以及未来是否需要把 AI 漏改风险进一步转为门禁脚本

## 最近的决策

| 日期 | 决策内容 | 原因 |
|------|----------|------|
| 2026-04-24 | Pencil 中应用锁页面必须接入数据池流程链路，而不是独立摆放 | 数据池应用锁是进入数据池前的强制前置条件，原型应表达完整路径而非孤立页面 |
| 2026-04-24 | App Lock 同时展示 Setup 与 Unlock 两种状态 | 首次使用需要设置 PIN / 生物识别；后续会话只需要解锁，两者都是数据池前置路径的一部分 |
| 2026-04-24 | 数据池 UI 本轮只落实现有 Pencil 目标和 Rust 已有 API，不扩展新的产品语义 | 用户目标是把已有 UI/API 串起来，避免在未确认情况下扩张数据池业务范围 |
| 2026-04-24 | 运行态 invite 操作统一在 API client 层聚合刷新后的 runtime view | Flutter 控制器只关心页面状态，避免把多 Rust API 调用顺序散落到 UI 层 |
| 2026-04-24 | GitNexus 不再作为当前仓库 agent 执行前置要求 | 用户明确要求删除 GitNexus 产物、移除 agent 文档内容并卸载本地程序 |
| 2026-04-24 | `GitNexus` 对 CardMind 的结论定为“可以关注，但暂不优先” | 其潜在收益主要在跨 Dart/Rust/FRB 影响面分析，但当前仓库已有较强的 docs/specs/verification 治理体系，暂未证明值得接入成本 |
| 2026-04-24 | 不推进新的脚本级硬约束实现 | 用户明确决定“还是不搞了”，本轮只保留评估结论 |
| 2026-04-24 | 本次提交纳入 `AGENTS.md`、`CLAUDE.md`、`.gitignore` 与存档文档，不纳入未跟踪的工具目录 | 避免将与本次会话无关的噪音文件混入仓库，同时让仓库入口说明与本次评估结论保持一致 |
| 2026-04-23 | Flutter 质量链必须先准备 FRB 运行态 dylib 与 codegen 产物，再跑 analyze/test | Flutter 侧已有真实 FRB 烟测与合同测试，不能依赖工作区中偶然残留的旧产物 |
| 2026-04-23 | 边界扫描出口规则只保留真正有诊断价值的 Flutter 高优先级项 | 避免已验证但低价值的逻辑表达式/循环误拦截，降低假阳性 |
| 2026-04-23 | 依赖升级按 Rust -> FRB -> Flutter 的顺序收口 | 用户明确要求先确保 Rust 侧稳定，再升级 Flutter |
| 2026-04-23 | 本轮只修复依赖升级直接引起的兼容性问题，不顺带扩展业务改动 | 保持任务边界稳定，避免范围膨胀 |
| 2026-04-23 | 本轮完成状态以分层验证为准，不以 `quality all` 单次结果作为唯一标准 | 当前仓库脚本会在 Flutter 测试触发 codegen 后影响 Rust `fmt --check`，不属于本轮升级引入的业务错误 |
| 2026-04-22 | invite 只能发起加入申请，不能直接让成员入池 | 用户明确确认“是否允许新成员加入”必须由管理员审核决定，invite 不应绕过正式审批链路 |
| 2026-04-22 | 数据池内任意成员都可以创建、查看并撤销 invite | 用户明确澄清 invite 管理边界不是 admin 专属，admin 的权限边界只体现在审批新成员加入 |
| 2026-04-22 | 同一 endpoint 在任一时刻只能属于一个未解散 pool，并且提交申请与审批阶段都要校验 | 需要把单 pool 约束从入口校验扩展到完整审批链路，避免后续再被绕过 |
| 2026-04-22 | Flutter 质量脚本默认固定 `-j 4`，Rust 质量脚本默认固定 `--jobs 1` | Flutter 并发收益明确；Rust 主要问题在 test target 进程层级冲突，不适合继续提并发 |
| 2026-04-22 | 删除 `integration_exact` / `unit_exact` 两个重复测试入口 | 当前仓库没有现行脚本依赖它们，保留只会重复执行与放大网络型不稳定 |
| 2026-04-22 | 不修改 `reset_app_config_for_tests()` 的正式语义，改为新增测试专用网络句柄清理函数 | 部分测试显式依赖切换 app config 时保留既有 network handle，直接改 reset 会引入回归 |
| 2026-04-16 | “加入申请处理中”必须建模为独立 `PoolJoinPending` 页面与状态，而不是继续塞进 joined 页面 | 用户明确指出 joined 页面出现“取消申请/等待审批”在逻辑上不成立，必须从状态模型与展示层同时修正 |
| 2026-04-16 | 数据池调试导出路径与对应测试改用同步文件 IO | 当前 widget test 环境下异步文件 API 会卡住，影响验证稳定性 |
| 2026-04-16 | pending 页面同步反馈条必须接真实恢复动作，不能保留空回调 | code review 发现“重试同步/重新连接”按钮可见可点但不执行，属于实质性交互回归 |
| 2026-04-15 | iOS `Copy Rust Framework` build phase 必须在复制前自动重建对应 Rust dylib | 手工先跑 `cargo build --target aarch64-apple-ios-sim` 依赖人工记忆，无法从根上避免运行态 framework 二进制陈旧导致的 FRB 签名错位 |
| 2026-04-15 | iOS 新出现的 `join_pool_by_invite(debug_trace)` panic 优先按运行态签名不一致处理，而不是继续深挖网络 | 真实错误已稳定收敛为 FRB 解码长度不一致，继续查网络会偏离根因 |
| 2026-04-14 | 真实联机验证阶段优先从 app 容器目录读取 `debug_status.log` / `debug_invite.txt` | macOS app 对仓库路径写入受沙盒影响，容器目录更稳定可观测 |
| 2026-04-14 | macOS `.worktrees/...` 下真实运行优先从 app bundle `Frameworks/` 目录加载 dylib | 直接读取 worktree 外部 `build/native/macos` 会触发 app 文件沙盒拦截，复制进 bundle 后真实 `flutter run` 验证恢复可用 |

## 相关文档链接

- [今日工作日志（2026-04-24）](./memory/2026-04-24.md)
- [今日工作日志（2026-04-23）](./memory/2026-04-23.md)
- [今日工作日志（2026-04-22）](./memory/2026-04-22.md)
- [最小网络互通调试方案](./plans/2026-04-14-network-diagnostic-debug-plan.md)
- [网络调试实现计划](./plans/2026-04-14-network-debug-trace-implementation.md)
- [今日工作日志（2026-04-16）](./memory/2026-04-16.md)
- [今日工作日志（2026-04-15）](./memory/2026-04-15.md)
- [今日工作日志（2026-04-14）](./memory/2026-04-14.md)
- [今日工作日志（2026-04-13）](./memory/2026-04-13.md)
- [今日工作日志（2026-04-10）](./memory/2026-04-10.md)
- [今日工作日志（2026-04-09）](./memory/2026-04-09.md)
- [今日工作日志（2026-04-08）](./memory/2026-04-08.md)
- [今日工作日志](./memory/2026-04-07.md)
- [文档总入口](./DIR.md)
- [计划目录说明](./plans/DIR.md)
- [规格目录说明](./specs/DIR.md)
- [Spec 生命周期规范](./standards/spec-lifecycle.md)
- [Docs DIR 索引说明](./standards/docs-dir-indexing.md)
- [数据池规格](./specs/pool.md)
- [边界扫描报告](../tmp/cardmind_test_boundary_report.md)

---

*最后更新：2026-04-24*
