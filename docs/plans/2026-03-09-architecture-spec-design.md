# 架构规格设计

- 日期：2026-03-09
- 状态：approved
- 目标文件：`docs/specs/architecture.md`

## 1. 背景

当前仓库已经形成两类文档分工：`docs/plans/` 用于记录设计与实施计划，`docs/specs/` 用于记录正式规格。最近新增的 `docs/plans/2026-03-09-flutter-rust-backend-frontend-design.md` 已经明确了目标架构方向：Flutter 作为前端，Rust 作为后端，FRB 作为语言边界。

但现有正式规格体系中仍缺少一份架构级约束文档，无法作为后续计划文档与实现工作的统一上位依据。尤其是以下原则尚未在 `docs/specs/` 中被正式化：

1. Flutter 与 Rust 的前后端职责边界。
2. `LoroDoc` 作为唯一真实信源。
3. `SQLite` 作为查询侧读模型而非真源。
4. 卡片笔记与数据池元数据统一遵循读写分离链路。
5. 查询只能走 `SQLite`，写入必须先落 `LoroDoc`。

## 2. 目标

1. 新增一份独立的项目级架构规格 `docs/specs/architecture.md`。
2. 用正式规格约束 Flutter、Rust、FRB、LoroDoc、SQLite 之间的职责与交互边界。
3. 让后续计划文档能够以这份架构规格为前置约束，而不是继续引用设计文档代替规格。
4. 保持规格文档处于“原则级 + 关键结构约束”层，不下沉为实现蓝图。

## 3. 非目标

1. 不在本次文档中定义具体 API 名称、目录结构或迁移步骤。
2. 不把正式 MUST/FORBIDDEN 约束正文继续写入 `docs/plans/`。
3. 不用 `shared-domain-contract` 替代项目级架构规格。
4. 不在本设计中直接执行实现或代码迁移。

## 4. 方案比较

### 4.1 方案 A（选定）：新增独立架构规格

- 在 `docs/specs/` 新增 `architecture.md`，作为项目级架构正式规格。
- `docs/plans/2026-03-09-flutter-rust-backend-frontend-design.md` 保留为设计依据与决策追溯。
- 后续计划文档直接引用 `docs/specs/architecture.md` 作为前置约束。

优点：

1. 文档边界最清晰。
2. 架构原则有单一正式来源，便于长期治理。
3. 最符合 `docs/standards/spec-first-execution.md` 对 `docs/specs/` 的定位。

缺点：

1. 需要维护一份新的上位规格文档。
2. 需要同步维护 `docs/specs/DIR.md` 与相关引用关系。

### 4.2 方案 B：并入 `shared-domain-contract`

- 把架构原则作为跨域总则追加到 `docs/specs/shared-domain-contract.md`。

优点：

1. 新增文件更少。
2. 看似可以集中管理跨域约束。

缺点：

1. 容易混淆“共享行为总则”与“系统架构约束”。
2. 与现有 `shared-domain-contract` 的语言无关、非技术实现定位不完全一致。

### 4.3 方案 C：拆散到分域规格

- 把架构原则分散写进 `pool.md`、`card-note.md` 等分域规格。

优点：

1. 短期新增文件最少。

缺点：

1. 架构约束容易漂移。
2. 很难形成项目级统一引用入口。
3. 不利于后续计划文档统一依赖。

## 5. 核心决策

1. 采用方案 A：新增独立架构规格 `docs/specs/architecture.md`。
2. `docs/plans/2026-03-09-flutter-rust-backend-frontend-design.md` 继续保留为设计文档，不承载正式规格正文。
3. 新规格定位为“原则级 + 关键结构约束”，用于约束目标架构而非描述实现步骤。
4. 后续实现计划文档必须先引用并遵守 `docs/specs/architecture.md`，再拆解实施任务。

## 6. 文档边界设计

### 6.1 `docs/specs/architecture.md` 应回答的问题

1. Flutter、Rust、FRB、LoroDoc、SQLite 各自承担什么职责。
2. 什么是唯一真实信源，什么是查询读模型。
3. 读写分离链路的强约束是什么。
4. 哪些做法被允许，哪些做法被禁止。
5. 一致性、同步、投影失败的语义边界是什么。

### 6.2 `docs/specs/architecture.md` 不应回答的问题

1. 具体 API 名称与参数长什么样。
2. 代码目录如何拆分。
3. 哪一步先迁移，哪一步后迁移。
4. 某个页面或某个测试文件如何编写。

### 6.3 与现有文档关系

1. `docs/specs/shared-domain-contract.md` 继续作为跨域共享行为总则。
2. `docs/specs/pool.md`、`docs/specs/card-note.md` 等分域规格继续定义领域行为，不重复承载项目级架构分层。
3. 分域规格如涉及架构边界，必须与 `docs/specs/architecture.md` 一致，不得冲突。

## 7. 目标规格结构

建议 `docs/specs/architecture.md` 使用如下结构：

1. 使用说明。
2. 目的与范围。
3. 术语。
4. 规范性规则。
5. 顶层架构职责。
6. 读写分离与数据流。
7. 中层结构约束。
8. 一致性、错误与恢复原则。
9. 禁止事项。
10. 黑盒验收标准。

## 8. 目标规格中的核心约束

### 8.1 顶层职责

1. Flutter MUST 作为前端层，只承担 UI、交互编排、展示状态与后端调用。
2. Rust MUST 作为后端层，承担领域规则、业务写入、投影驱动、同步与稳定契约输出。
3. FRB MUST 仅作为语言边界，不得演变为独立业务层。

### 8.2 真源与读模型

1. `LoroDoc` MUST 是卡片笔记与数据池元数据的唯一真实信源。
2. `SQLite` MUST 仅作为查询侧读模型，不得作为业务真源。
3. 任意业务事实变更 MUST 先落入 `LoroDoc`。

### 8.3 读写分离链路

1. `LoroDoc` 变更 MUST 通过订阅/投影机制更新 `SQLite`。
2. 所有查询 MUST 走 `SQLite`。
3. 外部同步结果 MUST 先进入 `LoroDoc`，再驱动 `SQLite` 收敛。
4. 禁止绕过 `LoroDoc -> SQLite` 链路直接改 `SQLite` 表达业务事实。

### 8.4 前后端边界

1. Flutter FORBIDDEN 复制 Rust 领域写规则。
2. Flutter FORBIDDEN 形成独立的业务写主路径。
3. Rust SHOULD 对 Flutter 暴露稳定边界，而不是泄露内部存储细节。

### 8.5 状态与恢复

1. 业务写成功、投影未收敛、同步未收敛必须被区分表达。
2. 投影失败或同步失败不得伪装成业务写失败。
3. 最终可观察查询结果必须与 `LoroDoc` 一致。

## 9. 对后续计划文档的影响

后续围绕 Flutter/Rust 前后端分层推进的计划文档，应遵循以下顺序：

1. 先新增 `docs/specs/architecture.md` 并更新 `docs/specs/DIR.md`。
2. 再检查 `pool.md`、`card-note.md` 等分域规格是否需要补充对架构规格的引用或对齐说明。
3. 然后再编写实现计划，拆解规格落地、分层迁移、测试与门禁任务。

## 10. 交付物

1. 新增 `docs/specs/architecture.md`。
2. 更新 `docs/specs/DIR.md`。
3. 新增后续实现计划文档，用于拆解规格落地任务。
