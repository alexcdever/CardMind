## Context

### 当前状态

主规格目录结构（`openspec/specs/`）包含 39 个文档，分布在以下目录：

```
openspec/specs/
├── api/              # 1 个文档 - 公共 API 规范
├── domain/           # 5 个文档 - 混合了领域模型和功能规格
├── features/         # 29 个文档 - 混合了 UI 组件和屏幕规格
└── ui_system/        # 4 个文档 - UI 系统规范
```

**核心问题**：
1. **domain/ 语义不清**：包含 card_store.md（存储实现）、sync_protocol.md（同步协议）等技术实现文档，而非纯粹的领域模型定义
2. **features/ 内容混乱**：包含大量 UI 组件文档（card_list_item.md、note_card.md、sync_status_indicator.md），而非业务功能描述
3. **缺少功能层**：没有清晰的业务功能规格（如"卡片管理"、"数据池管理"、"P2P 同步"）

### 代码库真实结构

基于对 Rust 和 Flutter 代码的深入分析：

**Rust 后端结构**：
```
rust/src/
├── models/           # 领域模型（Card, Pool, Device）
├── store/            # 存储层（CardStore, PoolStore, SQLite）
├── api/              # API 层（暴露给 Flutter）
├── p2p/              # P2P 同步模块
└── security/         # 安全模块
```

**Flutter 前端结构**：
```
lib/
├── providers/        # 业务逻辑（CardProvider, PoolProvider, SyncProvider）
├── screens/          # 屏幕（HomeScreen, CardEditorScreen, SyncScreen）
├── widgets/          # UI 组件（NoteCard, SyncStatusIndicator）
└── adaptive/         # 自适应 UI 系统
```

### 约束条件

1. **保持双语合规**：所有文档必须保持中英双语格式
2. **保持测试引用**：文档中的测试文件路径引用需要保持有效
3. **保持 ADR 引用**：架构决策记录中的引用需要更新
4. **最小化破坏性**：尽量保留现有文档内容，仅重新组织和分类

### 利益相关者

- **开发者**：需要清晰的文档结构来理解业务逻辑和技术实现
- **新成员**：需要快速了解项目的领域模型和功能模块
- **维护者**：需要易于维护和更新的文档组织方式

---

## Goals / Non-Goals

### Goals

1. **清晰的领域层**：domain/ 目录仅包含领域模型、领域服务、业务规则的定义
2. **清晰的功能层**：features/ 目录包含业务功能规格（用户视角的功能描述）
3. **清晰的 UI 层**：ui/ 目录包含 UI 组件和屏幕规格（技术视角的 UI 实现）
4. **清晰的技术层**：architecture/ 目录包含技术架构和实现细节
5. **文档结构与代码结构对齐**：便于开发者在文档和代码之间快速切换

### Non-Goals

1. **不改变文档格式**：保持现有的双语规格格式
2. **不删除现有内容**：仅重新组织，不删除有价值的内容
3. **不改变代码结构**：这是纯文档重组，不涉及代码变更
4. **不改变 OpenSpec 工作流**：保持现有的规格驱动开发流程

---

## Decisions

### Decision 1: 四层文档架构

**决策**：将主规格目录重组为四层架构：

```
openspec/specs/
├── domain/           # 领域层：领域模型、业务规则、领域服务
├── features/         # 功能层：业务功能规格（用户视角）
├── ui/               # UI 层：UI 组件、屏幕、交互规格
└── architecture/     # 架构层：技术架构、存储、同步、安全
```

**理由**：
- **分离关注点**：每层有明确的职责边界
- **对齐代码结构**：与 Rust 和 Flutter 的代码分层一致
- **降低认知负担**：开发者可以根据需求快速定位到对应层级的文档

**替代方案**：
- ❌ **保持现有结构**：问题依旧，不解决根本问题
- ❌ **按技术栈分层**（rust/、flutter/）：打破了业务逻辑的连贯性
- ❌ **按模块分层**（card/、pool/、sync/）：过于细粒度，难以管理

### Decision 2: domain/ 目录内容定义

**决策**：domain/ 目录仅包含领域模型和业务规则：

```
domain/
├── card/
│   ├── model.md          # Card 实体定义、属性、生命周期
│   └── rules.md          # 卡片业务规则（软删除、标签管理）
├── pool/
│   ├── model.md          # Pool 和 Device 实体定义
│   └── rules.md          # 单池约束、成员管理规则
├── sync/
│   └── model.md          # 同步版本、冲突解决模型
└── types.md              # 共享类型定义（UUID v7、时间戳）
```

**理由**：
- **纯粹的领域定义**：不包含技术实现细节
- **业务语言**：使用业务术语，而非技术术语
- **稳定性**：领域模型变化频率低，适合作为文档基础

**从现有文档迁移**：
- `pool_model.md` → `domain/pool/model.md`（保留领域定义部分）
- `common_types.md` → `domain/types.md`（保留类型定义部分）
- `card_store.md` → 拆分到 `domain/card/rules.md`（业务规则）和 `architecture/storage/card_store.md`（技术实现）

### Decision 3: features/ 目录内容定义

**决策**：features/ 目录包含业务功能规格（用户视角）：

```
features/
├── card_management/
│   └── spec.md           # 创建、编辑、查看、删除、标签管理
├── pool_management/
│   └── spec.md           # 创建、加入、离开、密码验证、成员管理
├── p2p_sync/
│   └── spec.md           # 设备发现、数据同步、冲突解决、同步状态
├── search_and_filter/
│   └── spec.md           # 全文搜索、标签过滤、排序
└── settings/
    └── spec.md           # 主题、mDNS、设备配置
```

**理由**：
- **用户视角**：描述用户可以做什么，而非如何实现
- **功能完整性**：每个功能规格覆盖完整的用户旅程
- **测试驱动**：功能规格直接对应验收测试

**从现有文档迁移**：
- 从 `features/card_editor/`、`features/card_detail/` 提取业务功能 → `features/card_management/spec.md`
- 从 `features/settings/` 提取业务功能 → `features/settings/spec.md`
- 从 `features/sync/` 提取业务功能 → `features/p2p_sync/spec.md`

### Decision 4: ui/ 目录内容定义

**决策**：新增 ui/ 目录包含 UI 组件和屏幕规格，按平台分层：

```
ui/
├── screens/
│   ├── mobile/
│   │   ├── home_screen.md        # 移动端主屏幕
│   │   ├── card_editor_screen.md # 移动端卡片编辑器
│   │   ├── card_detail_screen.md # 移动端卡片详情
│   │   ├── sync_screen.md        # 移动端同步屏幕
│   │   └── settings_screen.md    # 移动端设置屏幕
│   ├── desktop/
│   │   ├── home_screen.md        # 桌面端主屏幕（三栏布局）
│   │   ├── card_editor_screen.md # 桌面端卡片编辑器（内联编辑）
│   │   └── settings_screen.md    # 桌面端设置屏幕
│   └── shared/
│       └── onboarding_screen.md  # 共享的引导屏幕
├── components/
│   ├── mobile/
│   │   ├── card_list_item.md     # 移动端卡片列表项
│   │   ├── mobile_nav.md         # 移动端导航栏
│   │   ├── fab.md                # 移动端浮动按钮
│   │   └── gestures.md           # 移动端手势交互
│   ├── desktop/
│   │   ├── card_list_item.md     # 桌面端卡片列表项
│   │   ├── desktop_nav.md        # 桌面端导航
│   │   ├── toolbar.md            # 桌面端工具栏
│   │   └── context_menu.md       # 桌面端右键菜单
│   └── shared/
│       ├── note_card.md          # 共享的笔记卡片组件
│       ├── fullscreen_editor.md  # 共享的全屏编辑器
│       ├── sync_status_indicator.md  # 同步状态指示器
│       ├── sync_details_dialog.md    # 同步详情对话框
│       ├── device_manager_panel.md   # 设备管理面板
│       └── settings_panel.md     # 设置面板
└── adaptive/
    ├── layouts.md                # 自适应布局（三栏、两栏）
    ├── components.md             # 自适应组件（按钮、列表项）
    └── platform_detection.md     # 平台检测逻辑
```

**理由**：
- **平台分层**：移动端和桌面端的 UI 交互逻辑截然不同，需要明确区分
  - 移动端：单栏布局、全屏编辑、手势交互、底部导航
  - 桌面端：多栏布局、内联编辑、鼠标交互、侧边导航
- **共享组件**：部分组件在两个平台上共享相同的逻辑（如 note_card、sync_status_indicator）
- **技术视角**：描述 UI 如何实现，而非业务功能
- **前端开发友好**：前端开发者可以直接查找对应平台的 UI 组件规格
- **与 Flutter 代码对齐**：目录结构与 `lib/screens/` 和 `lib/widgets/` 对应，同时反映 `lib/adaptive/` 的平台适配逻辑

**从现有文档迁移**：
- `features/card_list/card_list_item.md` → 拆分为 `ui/components/mobile/card_list_item.md` 和 `ui/components/desktop/card_list_item.md`
- `features/card_list/mobile.md` → `ui/screens/mobile/home_screen.md`（卡片列表是主屏幕的一部分）
- `features/card_list/desktop.md` → `ui/screens/desktop/home_screen.md`
- `features/card_editor/note_card.md` → `ui/components/shared/note_card.md`
- `features/card_editor/mobile.md` → `ui/screens/mobile/card_editor_screen.md`
- `features/card_editor/desktop.md` → `ui/screens/desktop/card_editor_screen.md`
- `features/sync_feedback/sync_status_indicator.md` → `ui/components/shared/sync_status_indicator.md`
- `features/home_screen/home_screen.md` → 拆分为 `ui/screens/mobile/home_screen.md` 和 `ui/screens/desktop/home_screen.md`
- `features/navigation/mobile_nav.md` → `ui/components/mobile/mobile_nav.md`
- `features/toolbar/desktop.md` → `ui/components/desktop/toolbar.md`
- `features/context_menu/desktop.md` → `ui/components/desktop/context_menu.md`
- `features/fab/mobile.md` → `ui/components/mobile/fab.md`
- `features/gestures/mobile.md` → `ui/components/mobile/gestures.md`

### Decision 5: architecture/ 目录内容定义

**决策**：新增 architecture/ 目录包含技术架构和实现细节：

```
architecture/
├── storage/
│   ├── dual_layer.md         # 双层架构（Loro + SQLite）
│   ├── card_store.md         # CardStore 实现
│   ├── pool_store.md         # PoolStore 实现
│   └── sqlite_cache.md       # SQLite 缓存实现
├── sync/
│   ├── protocol.md           # P2P 同步协议
│   ├── mdns_discovery.md     # mDNS 设备发现
│   └── conflict_resolution.md # CRDT 冲突解决
├── security/
│   ├── password.md           # 密码管理（bcrypt）
│   ├── keyring.md            # Keyring 存储
│   └── privacy.md            # 隐私保护（mDNS 隐私）
└── bridge/
    └── flutter_rust_bridge.md # Flutter-Rust 桥接
```

**理由**：
- **技术深度**：包含技术实现细节和架构决策
- **与 Rust 代码对齐**：目录结构与 `rust/src/` 对应
- **架构文档集中**：便于架构师和高级开发者查找

**从现有文档迁移**：
- `domain/card_store.md` → 拆分到 `architecture/storage/card_store.md`（技术实现）
- `domain/sync_protocol.md` → `architecture/sync/protocol.md`
- `domain/device_config.md` → `architecture/storage/device_config.md`

### Decision 6: 保留和调整现有目录

**决策**：保留和调整以下现有目录：

```
openspec/specs/
├── api/                  # 保留：公共 API 规范
└── ui_system/            # 保留：UI 设计系统（设计令牌、响应式布局）
```

**移除**：
```
specs/bilingual-compliance/ → 迁移到 engineering/bilingual_compliance_spec.md
```

**理由**：
- **api/**：公共 API 规范是跨层的，不属于任何单一层级
- **ui_system/**：UI 设计系统是全局的，不是具体的 UI 组件
- **bilingual-compliance/**：这是工程指南性质的文档，不是业务规格，应该放在 `engineering/` 目录

**bilingual-compliance 问题分析**：
1. **来源**：由 OpenSpec 变更 `bilingual-spec-compliance` 归档时创建（提交 38d86a4）
2. **性质**：定义文档编写规则和格式标准，属于元规范/工程指南
3. **问题**：OpenSpec 的 `archive` 流程会将 `specs/` 目录下的内容同步到主规格目录，导致工程指南被错误地放入主规格目录
4. **解决方案**：
   - 将 `specs/bilingual-compliance/spec.md` 迁移到 `engineering/bilingual_compliance_spec.md`
   - 更新 OpenSpec 工作流，避免将工程指南类文档归档到主规格目录
   - 在变更的 `specs/` 目录中只放置真正的业务规格

### Decision 7: 文档迁移策略

**决策**：采用"拆分-合并-重写"策略：

1. **拆分**：将混合内容的文档拆分为多个单一职责的文档
   - 例如：`card_store.md` 拆分为 `domain/card/rules.md` 和 `architecture/storage/card_store.md`

2. **合并**：将分散的相关内容合并为完整的功能规格
   - 例如：`card_editor/`、`card_detail/` 合并为 `features/card_management/spec.md`

3. **重写**：根据新的层级定义重写文档内容
   - 领域层：使用业务语言，去除技术细节
   - 功能层：使用用户视角，描述完整的用户旅程
   - UI 层：使用技术语言，描述 UI 实现细节
   - 架构层：使用技术语言，描述架构决策和实现细节

**理由**：
- **保留价值内容**：不丢失现有文档中的有价值信息
- **提升文档质量**：通过重写提升文档的清晰度和准确性
- **渐进式迁移**：可以逐步迁移，不需要一次性完成

---

## Risks / Trade-offs

### Risk 1: 文档引用失效

**风险**：文档路径变更后，现有的引用链接会失效

**影响**：
- ADR 文档中的引用
- 测试文件中的规格引用
- 其他规格文档中的交叉引用

**缓解措施**：
1. 在迁移过程中维护一个映射表（旧路径 → 新路径）
2. 使用脚本批量更新所有引用
3. 在旧路径位置保留重定向文档（指向新路径）
4. 在 tasks 阶段明确列出所有需要更新引用的文件

### Risk 2: 文档内容拆分不当

**风险**：拆分文档时可能丢失上下文或重复内容

**影响**：
- 文档可读性下降
- 维护成本增加

**缓解措施**：
1. 在拆分前仔细分析文档内容的逻辑边界
2. 使用交叉引用保持文档之间的关联
3. 在每个文档的"Related Documents"部分明确列出相关文档
4. 进行文档审查，确保拆分后的文档仍然完整和连贯

### Risk 3: 迁移工作量大

**风险**：39 个文档的重组工作量可能超出预期

**影响**：
- 迁移时间延长
- 可能影响其他开发工作

**缓解措施**：
1. 采用渐进式迁移策略，优先迁移核心文档
2. 使用脚本自动化部分迁移工作（如文件移动、引用更新）
3. 在 tasks 阶段将工作分解为小的、可管理的任务
4. 允许新旧文档共存一段时间，逐步完成迁移

### Risk 4: 新结构不符合预期

**风险**：新的文档结构可能不符合团队的实际使用习惯

**影响**：
- 文档查找效率下降
- 团队成员不适应新结构

**缓解措施**：
1. 在实施前与团队成员讨论和确认新结构
2. 提供文档结构导航指南（README）
3. 在迁移完成后收集反馈，必要时调整结构
4. 保留旧文档的重定向，降低切换成本

---

## Trade-offs

### Trade-off 1: 文档数量 vs 文档粒度

**选择**：增加文档数量，降低单个文档的粒度

**优势**：
- 每个文档职责单一，易于理解和维护
- 便于并行编辑，减少冲突

**劣势**：
- 文档总数增加，可能增加查找成本
- 需要更多的交叉引用来保持文档关联

**决策**：接受这个 trade-off，因为清晰的职责边界比文档数量更重要

### Trade-off 2: 文档完整性 vs 重复内容

**选择**：允许适度的内容重复，保持每个文档的独立完整性

**优势**：
- 每个文档可以独立阅读，不需要频繁跳转
- 降低文档之间的耦合

**劣势**：
- 内容更新时需要同步多个文档
- 可能导致内容不一致

**决策**：接受这个 trade-off，但通过以下方式控制：
- 仅重复核心概念的简要说明
- 详细内容仅在一个文档中维护，其他文档通过引用链接
- 使用自动化工具检测内容不一致

### Trade-off 3: 渐进式迁移 vs 一次性迁移

**选择**：采用渐进式迁移策略

**优势**：
- 降低风险，可以逐步验证新结构
- 不阻塞其他开发工作
- 可以根据反馈调整策略

**劣势**：
- 迁移周期较长
- 新旧文档共存期间可能造成混淆

**决策**：接受这个 trade-off，因为降低风险比快速完成更重要

---

## Migration Plan

### Phase 1: 准备阶段

1. **处理 bilingual-compliance 问题**
   ```bash
   # 迁移文档
   mv specs/bilingual-compliance/spec.md engineering/bilingual_compliance_spec.md

   # 删除空目录
   rmdir specs/bilingual-compliance/

   # 更新引用（如果有）
   grep -r "bilingual-compliance" . --include="*.md" | # 查找所有引用
   # 手动更新引用路径
   ```

2. **创建新目录结构**
   ```bash
   mkdir -p specs/domain/{card,pool,sync}
   mkdir -p specs/features/{card_management,pool_management,p2p_sync,search_and_filter,settings}
   mkdir -p specs/ui/screens/{mobile,desktop,shared}
   mkdir -p specs/ui/components/{mobile,desktop,shared}
   mkdir -p specs/ui/adaptive
   mkdir -p specs/architecture/{storage,sync,security,bridge}
   ```

3. **创建迁移映射表**
   - 文档：`changes/reorganize-main-specs-content/migration_map.md`
   - 格式：`旧路径 | 新路径 | 迁移类型（移动/拆分/合并）| 平台（mobile/desktop/shared）`

4. **创建文档模板**
   - 领域层模板
   - 功能层模板
   - UI 层模板（移动端/桌面端/共享）
   - 架构层模板

### Phase 2: 核心文档迁移

**优先级 1：领域层**（最稳定，影响最大）
1. 迁移 `pool_model.md` → `domain/pool/model.md`
2. 迁移 `common_types.md` → `domain/types.md`
3. 拆分 `card_store.md` → `domain/card/rules.md`

**优先级 2：架构层**（技术文档，开发者常用）
1. 拆分 `card_store.md` → `architecture/storage/card_store.md`
2. 迁移 `sync_protocol.md` → `architecture/sync/protocol.md`
3. 迁移 `device_config.md` → `architecture/storage/device_config.md`

**优先级 3：功能层**（新增文档，需要合并现有内容）
1. 创建 `features/card_management/spec.md`
2. 创建 `features/pool_management/spec.md`
3. 创建 `features/p2p_sync/spec.md`

**优先级 4：UI 层**（数量最多，但影响相对较小，需要按平台拆分）
1. 迁移屏幕文档到 `ui/screens/{mobile,desktop,shared}/`
   - 拆分 `features/home_screen/home_screen.md` → `ui/screens/mobile/home_screen.md` + `ui/screens/desktop/home_screen.md`
   - 拆分 `features/card_editor/card_editor_screen.md` → `ui/screens/mobile/card_editor_screen.md` + `ui/screens/desktop/card_editor_screen.md`
   - 迁移 `features/onboarding/shared.md` → `ui/screens/shared/onboarding_screen.md`
2. 迁移组件文档到 `ui/components/{mobile,desktop,shared}/`
   - 拆分 `features/card_list/card_list_item.md` → `ui/components/mobile/card_list_item.md` + `ui/components/desktop/card_list_item.md`
   - 迁移 `features/card_editor/note_card.md` → `ui/components/shared/note_card.md`
   - 迁移 `features/fab/mobile.md` → `ui/components/mobile/fab.md`
   - 迁移 `features/toolbar/desktop.md` → `ui/components/desktop/toolbar.md`
3. 迁移自适应文档到 `ui/adaptive/`
   - 合并 `features/gestures/mobile.md` + 自适应相关内容 → `ui/adaptive/platform_detection.md`

### Phase 3: 引用更新

1. **更新 ADR 引用**
   - 扫描 `docs/adr/` 目录
   - 更新所有规格文档引用

2. **更新测试引用**
   - 扫描 `test/` 和 `rust/tests/` 目录
   - 更新测试文件中的规格引用注释

3. **更新文档交叉引用**
   - 扫描所有规格文档
   - 更新 "Related Documents" 部分的引用

4. **更新 README**
   - 更新 `openspec/specs/README.md`
   - 添加新目录结构说明和导航指南

### Phase 4: 验证和清理

1. **验证文档完整性**
   - 检查所有文档是否已迁移
   - 检查所有引用是否有效
   - 检查双语合规性

2. **创建重定向文档**
   - 在旧路径位置创建重定向文档
   - 格式：`此文档已迁移到 [新路径](新路径)`

3. **清理旧文档**
   - 删除已迁移的旧文档（保留重定向）
   - 删除空目录

4. **更新 OpenSpec 配置**
   - 如果需要，更新 OpenSpec 工具的配置

### Rollback Strategy

如果迁移过程中发现重大问题，可以回滚：

1. **保留旧文档**：在迁移过程中不删除旧文档，仅创建新文档
2. **使用 Git 分支**：在独立分支上进行迁移，主分支保持不变
3. **分阶段合并**：每个 Phase 完成后单独合并，便于回滚单个阶段
4. **保留映射表**：映射表可以用于反向迁移（新路径 → 旧路径）

---

## Open Questions

### Q1: 是否需要保留旧文档的历史版本？

**问题**：迁移后，旧文档的 Git 历史是否需要保留？

**选项**：
- A: 使用 `git mv` 保留历史
- B: 创建新文档，旧文档标记为 deprecated
- C: 删除旧文档，历史仅在 Git 中保留

**建议**：选项 A，使用 `git mv` 保留历史，便于追溯文档演变

### Q2: 是否需要为每个层级创建独立的 README？

**问题**：每个层级目录（domain/、features/、ui/、architecture/）是否需要独立的 README 说明？

**选项**：
- A: 每个层级一个 README
- B: 仅在顶层 `openspec/specs/README.md` 中说明
- C: 不需要额外的 README

**建议**：选项 A，每个层级一个 README，便于开发者快速了解该层级的内容和组织方式

### Q3: 是否需要自动化工具辅助迁移？

**问题**：是否需要开发脚本或工具来自动化迁移过程？

**选项**：
- A: 手动迁移，确保质量
- B: 开发脚本自动化文件移动和引用更新
- C: 使用现有工具（如 sed、awk）批量处理

**建议**：选项 B，开发简单的 Python 或 Bash 脚本，自动化文件移动和引用更新，但保留人工审查环节

### Q5: 如何处理 OpenSpec 工作流避免类似 bilingual-compliance 的问题？

**问题**：如何改进 OpenSpec 工作流，避免工程指南类文档被错误地归档到主规格目录？

**根本原因**：
- OpenSpec 的 `archive` 流程会将变更中的 `specs/` 目录内容同步到主规格目录 `openspec/specs/`
- 变更 `bilingual-spec-compliance` 在其 `specs/` 目录中创建了 `bilingual-compliance/spec.md`
- 归档时，这个文档被同步到了主规格目录，但它实际上是工程指南

**选项**：
- A: 在 OpenSpec 工作流中添加验证规则，禁止工程指南类文档进入主规格目录
- B: 在变更的 `specs/` 目录中只放置真正的业务规格，工程指南放在其他位置
- C: 归档后手动审查并移动错误放置的文档

**建议**：选项 B + A 组合
- **短期**：在本次重组中将 `bilingual-compliance` 迁移到 `engineering/`
- **长期**：在 OpenSpec 工作流文档中明确说明：
  - 变更的 `specs/` 目录仅用于业务规格
  - 工程指南、最佳实践、元规范应放在变更的其他位置（如 `docs/`）
  - 归档时只同步业务规格到主规格目录
- **工具支持**：开发验证脚本，检查归档的文档是否符合业务规格的特征（如包含 Requirement、Scenario 等）

**问题**：如果有正在进行的 OpenSpec 变更引用了旧路径，如何处理？

**选项**：
- A: 暂停所有变更，完成迁移后再继续
- B: 允许变更继续，迁移时更新变更中的引用
- C: 变更使用旧路径，迁移完成后统一更新

**建议**：选项 B，允许变更继续，迁移时同步更新变更中的引用，避免阻塞开发工作
