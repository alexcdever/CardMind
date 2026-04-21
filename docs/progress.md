# 工作流状态快照

> 本文档记录项目当前状态，每次 `/checkpoint` 时更新。
> 这是第三层记忆：当前快照（第一层：auto memory，第二层：工作日志）

## 当前进行中的工作

1. 当前主线无进行中的功能开发；`feat/rust-prototype-api-gap` 已完成开发、验证、合并回 `main`，相关 worktree 也已清理。
2. 数据池 invite / join / 审批规则已收口为正式规格：任意成员可创建、查看、撤销 invite；invite 只能发起加入申请；只有管理员可以审批加入；同一 endpoint 任一时刻只能属于一个未解散 pool。
3. 主仓当前处于收尾状态，仅保留用户当前工作区中的文档与设计文件变更待提交。

## 最近完成的工作

1. ~~Rust prototype API-gap / invite 审批链路修复~~ ✅ **已完成**（2026-04-22）
   - invite join 已改为正式审批流：收到 invite 后先落 join request，再由 admin 审批通过后入池
   - invite code 改为每次创建唯一，撤销后不会因重复 code 残留而继续有效
   - `submit_join_request` 与 `approve_join_request` 已补齐 endpoint 可用性校验，守住单 pool 不变量
   - 数据池规格已同步更新到 `docs/specs/pool.md`
   - Rust / Flutter 相关验证已通过，功能分支已 merge 回 `main`，worktree 已移除

2. ~~数据池 pending 语义修正与 Pencil 复现收口~~ ✅ **已完成**（2026-04-16）
   - Pencil 已覆盖当前 Flutter 项目的主要桌面/移动 UI，并按用户反馈调整数据池页结构与成员列表表现
   - `PoolState` 新增 `PoolJoinPending`，加入申请提交后进入独立 pending 页面，不再混入 joined 页面语义
   - 取消加入申请后回到 `PoolNotJoined`
   - 调试导出路径与对应测试改为同步文件 IO，规避当前 widget test 环境下异步文件 API 卡住问题
   - code review 发现并修复 pending 页面同步反馈按钮空实现回归，相关测试与 analyze 已通过

3. ~~iOS Rust framework 自动重建与真实联机复验~~ ✅ **已完成**（2026-04-15）
   - 定位 iOS `join_pool_by_invite(debug_trace)` 新增 FRB panic 的根因是运行态 framework 二进制陈旧，而非网络超时
   - `ios/Podfile` 的 `Copy Rust Framework` build phase 已改为按 `SDK_NAME` 自动执行 `cargo build --release --target <ios-target>`
   - 当前生效的 `ios/Runner.xcodeproj/project.pbxproj` 已同步更新同样逻辑，避免依赖手工再次 `pod install`
   - 新增 `test/integration/infrastructure/ios_podfile_test.dart` 防回退
   - 在不手工预构建 iOS Rust dylib 的前提下，`macOS owner -> iOS simulator joiner` 已再次真实成功 joined

4. ~~数据池 invite 串入池与业务层 handle 收口~~ ✅ **已完成**（2026-04-13）
   - Rust FFI 新增 `create_pool_invite` / `join_pool_by_invite` / `get_pool_network_endpoint_id`
   - `network_id` 背后改为持久 runtime，修复 iroh endpoint 跨 runtime 触发的 `Internal consistency error`
   - `FrbPoolApiClient` 支持仅靠 `appDataDir` 懒加载 runtime，业务层不再需要显式传入 runtime handle
   - `Pool` owner 页面已显示 invite string，真实组网验证路径已具备最小 UI 支撑
   - Rust / Flutter 相关合同、单元、组件、自动化测试均已通过

5. ~~文档治理第二轮收口（B+授权）~~ ✅ **已完成**（2026-04-10）
   - `AGENTS.md` 收敛为仓库入口提示词，不再展开协作流程正文
   - `docs/standards/ai-collaboration.md` 成为唯一协作流程正文，并新增 `Agent` 授权边界
   - `docs/standards/spec-lifecycle.md` 收敛为纯边界判断文档
   - `docs/standards/tdd.md` 改为“默认优先采用 TDD，例外时说明原因并补足验证”
   - 审查 `git-and-pr.md` 与 `testing.md`，确认当前无需调整

6. ~~质量门禁补强：Markdown 引用检查与 docs 子命令~~ ✅ **已完成**（2026-04-10）
   - `tool/lint/markdown_references_linter.dart` 支持锚点、title 文本、URL 编码空格，并在失效时返回非零退出码
   - `tool/quality.dart` 新增 `docs` 子命令，`flutter` 质量链改为先跑文档引用检查
   - 修正主工作区 `docs/` 历史相对引用，并让 linter 默认忽略 `.worktrees/`
   - `README.md` 与 `AGENTS.md` 已同步新增 `dart run tool/quality.dart docs` 说明
   - `dart run tool/quality.dart docs` 与 `dart run tool/quality.dart flutter` 已恢复可用

7. ~~文档体系结构性重构第一轮收口~~ ✅ **已完成**（2026-04-09）
   - 明确 `AGENTS.md`、`docs/specs/`、`docs/plans/`、`docs/standards/` 的职责边界
   - 明确 spec 由“正式行为确认变更”触发更新，而不是由“开始实现”触发更新
   - 新增文档体系结构性重构实施计划
   - 删除 `docs/` 之外的全部 `DIR.md`
   - `fractal-doc-standard.md` 重命名并收口为 `docs-dir-indexing.md`

8. ~~首页壳层测试护栏补齐~~ ✅ **已完成**（2026-04-08）
   - 首页测试明确 `pool` 分域装配经由 `PoolShell`
   - 修正与当前壳层分层方向冲突的旧断言
   - 首页壳层边界开始具备测试级防回退能力

9. ~~首页壳层第一步约束落地~~ ✅ **已完成**（2026-04-08）
   - 新增 `PoolShell`
   - `AppLockGate` 从 `AppHomepagePage` 下沉到 `PoolShell`
   - 首页壳层不再直接承接 pool 分域入口 gate
   - 首页相关测试通过

10. ~~Rust macOS 动态库运行态路径统一~~ ✅ **已完成**（2026-04-08）
   - 官方运行态 dylib 收口到 `build/native/macos/libcardmind_rust.dylib`
   - `tool/build.dart lib` 改为构建后自动同步官方运行态 dylib
   - `tool/build.dart run` 改为从官方运行态目录复制到 app bundle
   - `main.dart` 与 FRB 真库测试统一改走共享 dylib 路径入口
   - `README.md`、`AGENTS.md`、`tool/DIR.md`、`lib/DIR.md` 已同步更新路径职责说明

11. ~~Pool 前端一轮实质减负~~ ✅ **已完成**（2026-04-07）
   - `PoolPage` 主文件收成状态分发入口
   - 特殊错误判断从散写逻辑收成控制器私有守卫
   - `approvalMessage` 从 `PoolState` 中移出，改为 `PoolController.noticeMessage`
   - `exitShouldFail` / `rejectShouldFail` 从生产状态模型移除
   - 测试改为通过 fake API client 制造失败路径
   - 相关 unit / widget / integration 测试通过

12. ~~Pool 前端第一轮结构收口~~ ✅ **已完成**（2026-04-07）
   - `PoolPage` 主文件收成状态分发入口
   - 对话框逻辑拆到 `pool_page_dialogs.dart`
   - 页面块拆到 `pool_page_sections.dart`
   - 同步反馈拆到 `pool_sync_feedback.dart`
   - 相关 widget 测试通过

13. ~~文档权威边界收紧~~ ✅ **已完成**（2026-04-07）
   - 明确 `docs/standards/` 与 `docs/specs/` 是当前实现依据
   - 将 `docs/plans/` 降权为历史设计/计划/审计记录目录
   - 收紧 spec 生命周期规则，禁止把未确认项直接写成正式规格

14. ~~Phase 3 数据池规格定版~~ ✅ **已完成**（2026-04-07）
   - 应用锁前置条件
   - 加入申请取消
   - 解散后只读态
   - 退出/重新加入后的访问边界
   - 黑盒验收标准补齐

15. ~~Phase 3 数据池治理与安全基线~~ ✅ **已完成**（2026-04-05）
   - 应用锁（Rust 状态机 + Flutter guard/UI）
   - 数据池 API 应用锁 gating
   - 最后管理员不能退出
   - 池解散与已解散只读态
   - 加入申请提交 / 审批 / 拒绝 / 取消
   - Rust / Flutter / FRB / contract / integration / widget 测试链路打通

16. ~~质量门禁基线清理~~ ✅ **已完成**（2026-04-05）
   - `flutter analyze` 通过
   - `cargo fmt --check` 通过
   - `cargo clippy` 通过
   - `dart run tool/quality.dart all` 通过

17. ~~应用锁前置能力~~ ✅ **已完成**（2026-04-05）
   - Rust 安全状态机与存储抽象
   - Flutter 应用锁服务、界面与 guard
   - 池相关 API 必须在解锁后访问

## 待办事项

- [ ] 如继续推进数据池能力，优先做下一轮真实双端联机验证或新的定向 code review
- [ ] 评估是否为 `tool/debug_pool.dart` 增加更可读的阶段日志、失败诊断与收尾清理输出
- [ ] 评估是否为 app 内置最小网络自检模块，输出 endpoint 可达性 / 地址可见性 / 连接尝试结果
- [ ] 评估是否改为直接从 Flutter debug 会话或 VM Service 获取 invite / 状态，而不是继续依赖文件导出
- [ ] 视需要把 `debug_pool` 的 macOS 隔离副本策略抽成更通用的调试基础设施
- [ ] 评估 `Copy Rust Framework` 最小方案是否需要升级为更稳定的 xcframework/统一产物流程
- [ ] 如继续收口架构，评估 `PoolShell` / `SyncService` 装配面对 `network_id` 的剩余暴露
- [ ] 如继续优化文档治理，输出一页职责地图，明确核心文档负责什么、不再负责什么
- [ ] 如需继续提升多 worktree 开发体验，评估是否引入共享 Cargo 编译缓存策略

## 阻塞/卡点

- 当前无阻塞；若继续推进，重点已从修复 invite / 审批链路转为是否将真实双端调试流程进一步产品化或工具化

## 最近的决策

| 日期 | 决策内容 | 原因 |
|------|----------|------|
| 2026-04-22 | invite 只能发起加入申请，不能直接让成员入池 | 用户明确确认“是否允许新成员加入”必须由管理员审核决定，invite 不应绕过正式审批链路 |
| 2026-04-22 | 数据池内任意成员都可以创建、查看并撤销 invite | 用户明确澄清 invite 管理边界不是 admin 专属，admin 的权限边界只体现在审批新成员加入 |
| 2026-04-22 | 同一 endpoint 在任一时刻只能属于一个未解散 pool，并且提交申请与审批阶段都要校验 | 需要把单 pool 约束从入口校验扩展到完整审批链路，避免后续再被绕过 |
| 2026-04-16 | “加入申请处理中”必须建模为独立 `PoolJoinPending` 页面与状态，而不是继续塞进 joined 页面 | 用户明确指出 joined 页面出现“取消申请/等待审批”在逻辑上不成立，必须从状态模型与展示层同时修正 |
| 2026-04-16 | 数据池调试导出路径与对应测试改用同步文件 IO | 当前 widget test 环境下异步文件 API 会卡住，影响验证稳定性 |
| 2026-04-16 | pending 页面同步反馈条必须接真实恢复动作，不能保留空回调 | code review 发现“重试同步/重新连接”按钮可见可点但不执行，属于实质性交互回归 |
| 2026-04-15 | iOS `Copy Rust Framework` build phase 必须在复制前自动重建对应 Rust dylib | 手工先跑 `cargo build --target aarch64-apple-ios-sim` 依赖人工记忆，无法从根上避免运行态 framework 二进制陈旧导致的 FRB 签名错位 |
| 2026-04-15 | iOS 新出现的 `join_pool_by_invite(debug_trace)` panic 优先按运行态签名不一致处理，而不是继续深挖网络 | 真实错误已稳定收敛为 FRB 解码长度不一致，继续查网络会偏离根因 |
| 2026-04-14 | 真实联机验证阶段优先从 app 容器目录读取 `debug_status.log` / `debug_invite.txt` | macOS app 对仓库路径写入受沙盒影响，容器目录更稳定可观测 |
| 2026-04-14 | macOS `.worktrees/...` 下真实运行优先从 app bundle `Frameworks/` 目录加载 dylib | 直接读取 worktree 外部 `build/native/macos` 会触发 app 文件沙盒拦截，复制进 bundle 后真实 `flutter run` 验证恢复可用 |

## 相关文档链接

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

*最后更新：2026-04-22*
