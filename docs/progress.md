# 工作流状态快照

> 本文档记录项目当前状态，每次 `/checkpoint` 时更新。
> 这是第三层记忆：当前快照（第一层：auto memory，第二层：工作日志）

## 当前进行中的工作

1. 数据池 pending 语义与 Pencil 复现收尾：Pencil 已覆盖主要桌面/移动 UI，数据池页已按用户反馈移除“我的身份”、增强成员列表标签信息，并将“申请中”与“已加入”在代码和展示上彻底拆开。当前仅剩提交与推送收尾。
1. 跨端真实调试工具第一版已落地：`dart run tool/debug_pool.dart` 现已能自动编排 `macOS owner -> macOS joiner` 与 `macOS owner -> iOS simulator joiner` 两条真实调试链路，自动抓取 invite、拉起 joiner 并汇总最终 `joined:` 结果。macOS 路径已收口为“复制隔离 app 副本 -> 改 bundle id -> ad-hoc 重签 -> 读取对应 `Application Support/<bundleId>` 调试文件”的稳定方案，避免再次复用同一个 `cardmind.app`。
2. 真实双实例联机验证已完成关键闭环：`macOS owner -> macOS joiner` 在独立 bundle id / 独立 `appDataDir` 条件下已真实成功；`macOS owner -> iOS simulator joiner` 也已在“iOS build phase 自动重建 Rust dylib”的前提下再次真实跑通。iOS 路径新增收敛出的两类根因都已闭环：`get_joined_pool_view()` 过去误用 `get_any_pool()` 会在容器残留旧池时触发 `NOT_MEMBER`；`Copy Rust Framework` 过去只复制旧 dylib，会让 FRB 在 `join_pool_by_invite(debug_trace)` 上因运行态签名落后而解码 panic。两者现均已通过代码修复与真实复验确认。
3. `FrbPoolApiClient` 已基本收口 runtime handle 暴露面，业务层可只靠 `appDataDir` 完成 invite 入池；本轮已确认若显式注入 `networkId`，真实同步链路可稳定打通，后续如继续推进，可继续评估 `PoolShell` / `SyncService` 装配面是否还需进一步隐藏 `network_id`。
4. iOS 模拟器集成已补到可真实启动且能自动跟进 Rust 签名变化：新增最小合法 `cardmind_rust.framework` 注入，并将 Podfile / 当前生效 Xcode build phase 收口为“按 `SDK_NAME` 自动重建对应 iOS Rust dylib 再复制到 app bundle”。后续如继续保留 iOS 路径，应评估是否把当前最小注入方案升级为稳定的 framework/xcframework 产物流程。
5. 文档治理第二轮收口已完成，质量门禁保持可用；本轮新增的 Rust / Flutter 合同、路径与构建相关回归均已通过。

## 最近完成的工作

1. ~~数据池 pending 语义修正与 Pencil 复现收口~~ ✅ **已完成**（2026-04-16）
   - Pencil 已覆盖当前 Flutter 项目的主要桌面/移动 UI，并按用户反馈调整数据池页结构与成员列表表现
   - `PoolState` 新增 `PoolJoinPending`，加入申请提交后进入独立 pending 页面，不再混入 joined 页面语义
   - 取消加入申请后回到 `PoolNotJoined`
   - 调试导出路径与对应测试改为同步文件 IO，规避当前 widget test 环境下异步文件 API 卡住问题
   - code review 发现并修复 pending 页面同步反馈按钮空实现回归，相关测试与 analyze 已通过

2. ~~iOS Rust framework 自动重建与真实联机复验~~ ✅ **已完成**（2026-04-15）
   - 定位 iOS `join_pool_by_invite(debug_trace)` 新增 FRB panic 的根因是运行态 framework 二进制陈旧，而非网络超时
   - `ios/Podfile` 的 `Copy Rust Framework` build phase 已改为按 `SDK_NAME` 自动执行 `cargo build --release --target <ios-target>`
   - 当前生效的 `ios/Runner.xcodeproj/project.pbxproj` 已同步更新同样逻辑，避免依赖手工再次 `pod install`
   - 新增 `test/integration/infrastructure/ios_podfile_test.dart` 防回退
   - 在不手工预构建 iOS Rust dylib 的前提下，`macOS owner -> iOS simulator joiner` 已再次真实成功 joined

3. ~~数据池 invite 串入池与业务层 handle 收口~~ ✅ **已完成**（2026-04-13）
   - Rust FFI 新增 `create_pool_invite` / `join_pool_by_invite` / `get_pool_network_endpoint_id`
   - `network_id` 背后改为持久 runtime，修复 iroh endpoint 跨 runtime 触发的 `Internal consistency error`
   - `FrbPoolApiClient` 支持仅靠 `appDataDir` 懒加载 runtime，业务层不再需要显式传入 runtime handle
   - `Pool` owner 页面已显示 invite string，真实组网验证路径已具备最小 UI 支撑
   - Rust / Flutter 相关合同、单元、组件、自动化测试均已通过

4. ~~文档治理第二轮收口（B+授权）~~ ✅ **已完成**（2026-04-10）
   - `AGENTS.md` 收敛为仓库入口提示词，不再展开协作流程正文
   - `docs/standards/ai-collaboration.md` 成为唯一协作流程正文，并新增 `Agent` 授权边界
   - `docs/standards/spec-lifecycle.md` 收敛为纯边界判断文档
   - `docs/standards/tdd.md` 改为“默认优先采用 TDD，例外时说明原因并补足验证”
   - 审查 `git-and-pr.md` 与 `testing.md`，确认当前无需调整

5. ~~质量门禁补强：Markdown 引用检查与 docs 子命令~~ ✅ **已完成**（2026-04-10）
   - `tool/lint/markdown_references_linter.dart` 支持锚点、title 文本、URL 编码空格，并在失效时返回非零退出码
   - `tool/quality.dart` 新增 `docs` 子命令，`flutter` 质量链改为先跑文档引用检查
   - 修正主工作区 `docs/` 历史相对引用，并让 linter 默认忽略 `.worktrees/`
   - `README.md` 与 `AGENTS.md` 已同步新增 `dart run tool/quality.dart docs` 说明
   - `dart run tool/quality.dart docs` 与 `dart run tool/quality.dart flutter` 已恢复可用

6. ~~文档体系结构性重构第一轮收口~~ ✅ **已完成**（2026-04-09）
   - 明确 `AGENTS.md`、`docs/specs/`、`docs/plans/`、`docs/standards/` 的职责边界
   - 明确 spec 由“正式行为确认变更”触发更新，而不是由“开始实现”触发更新
   - 新增文档体系结构性重构实施计划
   - 删除 `docs/` 之外的全部 `DIR.md`
   - `fractal-doc-standard.md` 重命名并收口为 `docs-dir-indexing.md`

7. ~~首页壳层测试护栏补齐~~ ✅ **已完成**（2026-04-08）
   - 首页测试明确 `pool` 分域装配经由 `PoolShell`
   - 修正与当前壳层分层方向冲突的旧断言
   - 首页壳层边界开始具备测试级防回退能力

8. ~~首页壳层第一步约束落地~~ ✅ **已完成**（2026-04-08）
   - 新增 `PoolShell`
   - `AppLockGate` 从 `AppHomepagePage` 下沉到 `PoolShell`
   - 首页壳层不再直接承接 pool 分域入口 gate
   - 首页相关测试通过

9. ~~Rust macOS 动态库运行态路径统一~~ ✅ **已完成**（2026-04-08）
   - 官方运行态 dylib 收口到 `build/native/macos/libcardmind_rust.dylib`
   - `tool/build.dart lib` 改为构建后自动同步官方运行态 dylib
   - `tool/build.dart run` 改为从官方运行态目录复制到 app bundle
   - `main.dart` 与 FRB 真库测试统一改走共享 dylib 路径入口
   - `README.md`、`AGENTS.md`、`tool/DIR.md`、`lib/DIR.md` 已同步更新路径职责说明

10. ~~Pool 前端一轮实质减负~~ ✅ **已完成**（2026-04-07）
   - `PoolPage` 主文件收成状态分发入口
   - 特殊错误判断从散写逻辑收成控制器私有守卫
   - `approvalMessage` 从 `PoolState` 中移出，改为 `PoolController.noticeMessage`
   - `exitShouldFail` / `rejectShouldFail` 从生产状态模型移除
   - 测试改为通过 fake API client 制造失败路径
   - 相关 unit / widget / integration 测试通过

11. ~~Pool 前端第一轮结构收口~~ ✅ **已完成**（2026-04-07）
   - `PoolPage` 主文件收成状态分发入口
   - 对话框逻辑拆到 `pool_page_dialogs.dart`
   - 页面块拆到 `pool_page_sections.dart`
   - 同步反馈拆到 `pool_sync_feedback.dart`
   - 相关 widget 测试通过

12. ~~文档权威边界收紧~~ ✅ **已完成**（2026-04-07）
   - 明确 `docs/standards/` 与 `docs/specs/` 是当前实现依据
   - 将 `docs/plans/` 降权为历史设计/计划/审计记录目录
   - 收紧 spec 生命周期规则，禁止把未确认项直接写成正式规格

13. ~~Phase 3 数据池规格定版~~ ✅ **已完成**（2026-04-07）
   - 应用锁前置条件
   - 加入申请取消
   - 解散后只读态
   - 退出/重新加入后的访问边界
   - 黑盒验收标准补齐

14. ~~Phase 3 数据池治理与安全基线~~ ✅ **已完成**（2026-04-05）
   - 应用锁（Rust 状态机 + Flutter guard/UI）
   - 数据池 API 应用锁 gating
   - 最后管理员不能退出
   - 池解散与已解散只读态
   - 加入申请提交 / 审批 / 拒绝 / 取消
   - Rust / Flutter / FRB / contract / integration / widget 测试链路打通

15. ~~质量门禁基线清理~~ ✅ **已完成**（2026-04-05）
   - `flutter analyze` 通过
   - `cargo fmt --check` 通过
   - `cargo clippy` 通过
   - `dart run tool/quality.dart all` 通过

16. ~~应用锁前置能力~~ ✅ **已完成**（2026-04-05）
   - Rust 安全状态机与存储抽象
   - Flutter 应用锁服务、界面与 guard
   - 池相关 API 必须在解锁后访问

## 待办事项

- [ ] 评估是否为 `tool/debug_pool.dart` 增加更可读的阶段日志、失败诊断与收尾清理输出
- [ ] 评估是否为 app 内置最小网络自检模块，输出 endpoint 可达性 / 地址可见性 / 连接尝试结果
- [ ] 评估是否改为直接从 Flutter debug 会话或 VM Service 获取 invite / 状态，而不是继续依赖文件导出
- [ ] 视需要把 `debug_pool` 的 macOS 隔离副本策略抽成更通用的调试基础设施
- [ ] 评估 `Copy Rust Framework` 最小方案是否需要升级为更稳定的 xcframework/统一产物流程
- [ ] 如继续收口架构，评估 `PoolShell` / `SyncService` 装配面对 `network_id` 的剩余暴露
- [ ] 如继续优化文档治理，输出一页职责地图，明确核心文档负责什么、不再负责什么
- [ ] 如需继续提升多 worktree 开发体验，评估是否引入共享 Cargo 编译缓存策略

## 阻塞/卡点

- 真实双实例联机验证的剩余工作，已从“定位 join 失败根因”切换为“是否要把独立双开/跨端调试流程固化为正式工具链”，当前业务 join 主路径已验证通过

## 最近的决策

| 日期 | 决策内容 | 原因 |
|------|----------|------|
| 2026-04-16 | “加入申请处理中”必须建模为独立 `PoolJoinPending` 页面与状态，而不是继续塞进 joined 页面 | 用户明确指出 joined 页面出现“取消申请/等待审批”在逻辑上不成立，必须从状态模型与展示层同时修正 |
| 2026-04-16 | 数据池调试导出路径与对应测试改用同步文件 IO | 当前 widget test 环境下异步文件 API 会卡住，影响验证稳定性 |
| 2026-04-16 | pending 页面同步反馈条必须接真实恢复动作，不能保留空回调 | code review 发现“重试同步/重新连接”按钮可见可点但不执行，属于实质性交互回归 |
| 2026-04-15 | iOS `Copy Rust Framework` build phase 必须在复制前自动重建对应 Rust dylib | 手工先跑 `cargo build --target aarch64-apple-ios-sim` 依赖人工记忆，无法从根上避免运行态 framework 二进制陈旧导致的 FRB 签名错位 |
| 2026-04-15 | iOS 新出现的 `join_pool_by_invite(debug_trace)` panic 优先按运行态签名不一致处理，而不是继续深挖网络 | 真实错误已稳定收敛为 FRB 解码长度不一致，继续查网络会偏离根因 |
| 2026-04-14 | 真实联机验证阶段优先从 app 容器目录读取 `debug_status.log` / `debug_invite.txt` | macOS app 对仓库路径写入受沙盒影响，容器目录更稳定可观测 |
| 2026-04-14 | macOS `.worktrees/...` 下真实运行优先从 app bundle `Frameworks/` 目录加载 dylib | 直接读取 worktree 外部 `build/native/macos` 会触发 app 文件沙盒拦截，复制进 bundle 后真实 `flutter run` 验证恢复可用 |
| 2026-04-14 | macOS Runner entitlements 补齐 `com.apple.security.network.client` | DebugProfile 只有 `network.server` 不足以支撑主动 join 连接；补齐后真实 join 已不再停在原 connect 超时 |
| 2026-04-14 | macOS 真双实例验证必须使用独立 app bundle id 与独立 `appDataDir` | 同一个 `cardmind.app` 被 `flutter run/open` 复用时，无法稳定形成真正隔离的 owner/joiner 进程与容器；独立 bundle 后 `macOS owner -> macOS joiner` 已真实成功 joined |
| 2026-04-14 | `get_joined_pool_view()` 必须按当前 `endpoint_id` 选择所属池 | iOS 模拟器容器残留旧池时，`get_any_pool()` 会误命中旧池并对当前 runtime endpoint 返回 `NOT_MEMBER`；按成员归属选池后，`macOS owner -> iOS simulator joiner` 已真实成功 joined |
| 2026-04-14 | 先补 join 错误 message 透传链路，再继续真实联机验证 | 需要把 `INTERNAL` 泛化错误收敛为可定位的具体 message |
| 2026-04-14 | 将下一阶段定位重点从“角色方向差异”切换为“连接建立阶段网络互通与可观测性” | 双向角色路径都复现 `connect failed: internal error: timed out`，已不再像单侧平台问题 |
| 2026-04-13 | 真实双实例验证先通过调试导出路径打通 owner 自动建池、invite 导出与 joiner 状态回读 | 先让真实链路可观测，再定位最后一段运行时差异，比继续依赖 GUI 自动化更稳妥 |
| 2026-04-13 | iOS 端采用最小合法 `cardmind_rust.framework` 注入而不先做完整 xcframework | 目标是尽快跑通模拟器 joiner 真实启动，避免过早扩张到完整 iOS 分发策略 |
| 2026-04-13 | Android 模拟器不再作为当前 `iroh` 真实联机主验证环境 | 模拟器底层网络能力被 SELinux 限制，继续深挖收益低 |
| 2026-04-13 | owner 侧 invite 先以字符串形式直接暴露到页面，不先做二维码 | 先满足真实组网验证最短路径，避免表现层过早扩张 |
| 2026-04-13 | `network_id` 背后改为持久 runtime，而不是每次 API 调用临时建 Tokio runtime | iroh endpoint 跨 runtime 复用会触发 `Internal consistency error`，必须从根上收口生命周期 |
| 2026-04-13 | `network_id` 继续保留为 Rust FFI 内部句柄，不上升为业务概念 | 用户约束是一实例一节点一数据池，业务层不应承担 Rust 运行时对象编排 |
| 日期 | 决策内容 | 原因 |
|------|----------|------|
| 2026-04-10 | 采用 `B+授权` 重构文档治理 | 先消除入口层与执行层职责重叠，再以最小成本补上 agent 授权边界 |
| 2026-04-10 | Markdown 文档引用检查默认忽略 `.worktrees/` | 保证主工作区质量门禁稳定可用，避免并行 worktree 副本持续造成假阳性 |
| 2026-04-10 | 先恢复 docs / flutter 质量链可用性，再单独处理边界扫描缺口 | 当前目标是恢复主门禁，不在同一会话内扩张到新一轮补测实现 |
| 2026-04-10 | `AGENTS.md` 回到仓库入口提示词定位 | 它在运行时作为项目级全局提示词生效，不应继续复制协作流程正文 |
| 2026-04-10 | `docs/standards/ai-collaboration.md` 成为唯一协作流程正文 | 让 agent 只在一处获取任务分级、执行、验证与交付规则 |
| 2026-04-10 | `docs/standards/tdd.md` 调整为“默认优先采用 TDD” | 保留质量要求，同时避免机械化流程门禁压制 agent 的工程自治 |
| 2026-04-09 | `docs/specs/` 收敛为“当前已确认的正式行为真相源” | 降低 spec、plan、design 混用，减少 AI 与贡献者理解偏差 |
| 2026-04-09 | spec 更新由“正式行为确认变更”触发，而不是由“开始实现”触发 | 保留 spec 约束价值，同时避免所有任务都被文档前置流程拖重 |
| 2026-04-09 | 仅在 `docs/` 体系内保留 `DIR.md` | 文档目录有导航价值，代码/平台目录的 `DIR.md` 只会增加维护噪音 |
| 2026-04-09 | `fractal-doc-standard.md` 退役并改为 `docs-dir-indexing.md` | 避免旧名称继续暗示仓库仍采用分形文档治理与文件头规则 |
| 2026-04-08 | macOS 运行态 dylib 的唯一真相源收口为 `build/native/macos/libcardmind_rust.dylib` | 统一测试、运行与 app bundle 的动态库来源，降低“库不存在/库有问题”的路径漂移风险 |
| 2026-04-08 | `rust/target/release/libcardmind_rust.dylib` 仅保留为 Cargo 编译缓存源 | 避免 Cargo 编译产物继续被误用为运行态真相源 |
| 2026-04-07 | `docs/plans/` 默认不作为当前实现依据，仅保留历史记录与 ADR 参考价值 | 避免历史设计/计划文档继续误导当前实现与 AI 判断 |
| 2026-04-07 | 当前实现依据收敛为 `docs/standards/` 与 `docs/specs/` | 需要明确真相源，降低文档层混乱与跑偏风险 |
| 2026-04-07 | 采用“持续开发 + 关键停顿点”的协作理解 | 比硬阶段切分更符合个人开发节奏和 superpowers 的使用方式 |
| 2026-04-07 | `PoolPage` 前端层可保留但不可继续扩展，后续再碰必须先收口结构边界 | 页面、控制器与状态模型已开始混入测试/模拟/提示拼装职责，继续叠功能会显著增加维护暴雷风险 |
| 2026-04-07 | `PoolPage` 第一轮收口先只处理页面结构与明显的特殊错误判断，不扩展到整套消息体系 | 先提升可读性并降低膨胀风险，避免过早卷入 `PoolState` 与提示体系的更大重构 |
| 2026-04-07 | `Pool` 前端测试失败路径必须通过 fake API client 制造，不再写进生产状态模型 | 避免测试味字段继续污染 `PoolState`，让生产代码只处理真实错误语义 |
| 2026-04-07 | 首页壳层可保留为主壳资产，但不应继续承担新的跨功能编排职责 | 当前控制器与壳层组件边界仍然健康，但 `AppHomepagePage` 已开始承接全局入口编排，继续扩责会滑向总装入口 |
| 2026-04-08 | `Pool` 分域入口 gate 已下沉到 `PoolShell` | 用分域壳层承接分域前置条件，比继续挂在首页壳层更符合前端入口分层约束 |
| 2026-04-08 | 首页壳层边界应通过测试护栏保护，至少确保 `pool` 分域装配经由 `PoolShell` | 仅靠文档约束不足以防回退，测试可直接阻止首页再次吸收 pool 分域入口职责 |
| 2026-04-07 | `AppLock` 前端层当前健康，可继续保留 | 状态模型、服务、guard 与 screen 边界清晰，当前不属于高风险负资产 |

## 相关文档链接

- [最小网络互通调试方案](./plans/2026-04-14-network-diagnostic-debug-plan.md)
- [网络调试实现计划](./plans/2026-04-14-network-debug-trace-implementation.md)
- [今日工作日志（2026-04-16）](./memory/2026-04-16.md)
- [今日工作日志（2026-04-15）](./memory/2026-04-15.md)
- [今日工作日志（2026-04-13）](./memory/2026-04-13.md)
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
- [文档体系结构性重构实施计划](./plans/2026-04-09-documentation-structure-refactor-implementation-plan.md)
- [动态库路径统一设计](./plans/2026-04-08-rust-dylib-runtime-path-unification-design.md)
- [动态库路径统一实施计划](./plans/2026-04-08-rust-dylib-runtime-path-unification-implementation-plan.md)
- [Phase 3 设计文档](./plans/2026-03-27-phase3-data-flow-extension-assessment-design.md)
- [数据池规格](./specs/pool.md)
- [边界扫描报告](../tmp/cardmind_test_boundary_report.md)

---

*最后更新：2026-04-16*
