# 文档贡献指南

本指南定义 CardMind 项目的文档编写标准，适用于人类贡献者和 AI Agent。

---

## 📐 文档设计哲学

### 设计类文档（描述"空间结构"）

设计文档描述"系统是什么"，生命周期长（几个月不变）：

- **需求文档** = 灵魂（业务意图）
  - 定义"为什么做"和"做什么"
  - 无技术细节，面向产品和业务

- **交互文档** = 皮肤（用户感知）
  - 定义"用户如何感知"
  - 界面流转、反馈设计、信息架构

- **架构文档** = 骨架（技术契约）
  - 定义"系统如何组织"
  - 设计原则、数据契约、层次划分

- **代码实现** = 血肉（具体执行）
  - 由 `cargo doc` 自动生成
  - 文档只定义契约，不写实现

### 管理类文档（描述"时间进度"）

管理文档描述"我们做到哪了"，频繁更新（每天变化）：

- **路线图（Roadmap）** - 战略规划
  - 里程碑、优先级、版本规划
  - 生命周期较长（按版本更新）

- **任务进度（TODO）** - 战术执行
  - 当前状态（Doing/Done）
  - AI 可通过 TodoWrite 工具自动更新

---

## 🎯 核心原则

### 1. 设计文档不写代码

**坚持"不写实施细节"**：

✅ **应该做**：
- 定义数据契约和接口
- 描述设计原则和决策理由
- 使用伪代码展示契约（仅展示签名）
- 指向 `cargo doc` 查看实现

❌ **不应做**：
- 写完整的函数实现
- 复制粘贴代码到文档
- 详细描述算法步骤
- 维护与代码同步的示例

**理由**：
1. **保持文档生命周期**：设计意图稳定，代码实现易变
2. **给 AI 留出最优解空间**：只定义契约，让 AI 结合 LSP 上下文生成最优代码
3. **降低 Token 消耗**：清晰逻辑描述比长篇伪代码更高效

### 2. 区分"空间"与"时间"

- **设计文档**：描述"它是什么"（空间结构）
- **管理文档**：描述"我们做到哪了"（时间进度）

**降低 AI 干扰**：
- 修 Bug 时只读架构文档，不读 TODO.md
- 总结进度时只读 TODO.md 和 roadmap.md，不读架构文档
- 场景化阅读减少 50% 无关上下文

### 3. 面向 AI 优化

- TODO.md 放根目录，方便 AI 的 TodoWrite 工具直接读写
- 每类文档职责清晰，AI 可快速定位
- 术语保持一致性，降低理解成本

---

## 📁 文档目录结构

```
CardMind/
├── CLAUDE.md                     # [管理] AI 指挥中心（索引+关键约束）
├── TODO.md                       # [管理] 当前任务进度（AI 可读写，频繁更新）
├── CHANGELOG.md                  # [管理] 版本发布历史
├── README.md                     # 项目概览
│
├── docs/
│   ├── requirements/             # [设计] 需求层 - "为什么"和"做什么"
│   │   ├── product_vision.md    # 产品愿景、定位、目标用户
│   │   ├── user_scenarios.md    # 用户场景和用例（无技术细节）
│   │   ├── business_rules.md    # 业务规则和约束（领域模型）
│   │   └── success_metrics.md   # 成功指标和验收标准
│   │
│   ├── interaction/              # [设计] 交互层 - "用户如何感知"
│   │   ├── ui_flows.md          # 界面流转和状态转换图
│   │   ├── feedback_design.md   # 用户反馈设计（同步状态、错误提示）
│   │   ├── information_arch.md  # 信息架构和页面层级
│   │   └── accessibility.md     # 无障碍设计原则
│   │
│   ├── architecture/             # [设计] 架构层 - "系统如何组织"
│   │   ├── system_design.md     # 系统设计原则和架构决策
│   │   ├── data_contract.md     # 数据契约（仅字段定义，无实现）
│   │   ├── layer_separation.md  # 分层策略（Repository/Service/Bridge）
│   │   ├── sync_mechanism.md    # 同步机制设计（订阅驱动、P2P）
│   │   └── tech_constraints.md  # 技术选型理由（为什么，不是怎么做）
│   │
│   ├── implementation/           # [指南] 实现指南（指向代码和工具）
│   │   ├── rust_doc_guide.md    # Rust 文档编写规范
│   │   ├── testing_guide.md     # 测试方法论和 TDD 流程
│   │   └── logging.md           # 日志规范和最佳实践
│   │
│   ├── roadmap.md                # [管理] 长期战略规划（里程碑、优先级）
│   ├── user_guide.md             # [参考] 用户使用手册
│   │
│   └── CONTRIBUTING.md           # 本文档 - 文档编写规范
│
└── tool/
    └── BUILD_GUIDE.md            # 构建和开发环境指南
```

---

## 📝 各层文档规范

### Requirements 层（需求文档）

**职责**：定义业务需求和产品目标

**应该包含**：
- 产品定位和目标用户
- 用户场景和用例
- 业务规则和领域模型
- 成功指标和验收标准

**不应包含**：
- 技术实现细节（Loro、SQLite、Flutter）
- 数据结构定义（应在 architecture/data_contract.md）
- UI 界面描述（应在 interaction/ 层）
- 代码示例

**命名规范**：
- 小写下划线：`product_vision.md`、`user_scenarios.md`
- 简洁明确，体现文档用途

**示例**：
```markdown
### 核心价值主张
- **数据永不丢失**：即使多设备同时编辑，系统自动合并冲突
- **完全离线可用**：无需网络连接，随时记录想法
- **去中心化同步**：本地网络自动发现设备并同步，无需服务器

（注意：不提及 CRDT、UUID v7 等技术细节）
```

---

### Interaction 层（交互文档）

**职责**：定义用户体验和界面交互

**应该包含**：
- 界面流转图（Mermaid 状态图）
- 用户反馈设计（同步状态、错误提示）
- 信息架构和页面层级
- 无障碍设计原则

**不应包含**：
- Flutter Widget 代码
- 具体的颜色值和样式（除非是设计系统）
- 技术实现细节

**命名规范**：
- 小写下划线：`ui_flows.md`、`feedback_design.md`

**示例**：
```markdown
## 卡片编辑流程

\`\`\`mermaid
stateDiagram-v2
    [*] --> 卡片列表
    卡片列表 --> 新建卡片 : 点击新建
    卡片列表 --> 卡片详情 : 点击卡片
    卡片详情 --> 编辑模式 : 点击编辑
    编辑模式 --> 预览模式 : 点击预览
    预览模式 --> 编辑模式 : 点击编辑
\`\`\`

### 状态定义
**编辑模式**：
- 显示 Markdown 工具栏
- 内容区可编辑
- 显示自动保存指示器

（注意：不写具体的 Widget 树结构）
```

---

### Architecture 层（架构文档）

**职责**：定义系统结构和技术契约

**应该包含**：
- 系统设计原则和架构决策
- 数据契约（字段定义、类型约束）
- 分层策略和职责划分
- 同步机制设计原理
- 技术选型理由（为什么选，不是怎么用）

**不应包含**：
- 完整的 Rust 代码实现
- SQL 建表语句（可以有表结构定义）
- 详细的算法步骤（应在代码注释或 cargo doc）

**命名规范**：
- 小写下划线：`system_design.md`、`data_contract.md`

**示例 - 数据契约**：
```markdown
## 卡片数据契约

### 字段定义

| 字段 | 类型 | 约束 | 业务含义 |
|------|------|------|---------|
| `id` | UniqueIdentifier | 必填、全局唯一、时间有序 | 卡片唯一标识 |
| `title` | OptionalText | 可选、最大 256 字符 | 卡片标题 |
| `content` | MarkdownText | 必填 | 卡片内容（Markdown 格式） |
| `created_at` | Timestamp | 自动生成 | 创建时间（毫秒级） |
| `is_deleted` | Boolean | 默认 false | 软删除标记 |

### 类型说明

**UniqueIdentifier**：
- 要求：分布式环境下全局唯一，无需中心化协调
- 要求：按创建时间排序
- 实现：由技术选型决定（见 tech_constraints.md）

（注意：只定义契约，不写 Rust struct 定义）
```

**示例 - 分层策略**：
```markdown
## Repository 层

**职责**：
- 隔离数据源实现细节
- 提供统一的数据访问接口
- 处理数据持久化

**契约**（伪代码）：
\`\`\`rust
trait CardRepository {
    fn create(card: Card) -> Result<Card>;
    fn get(id: CardId) -> Result<Option<Card>>;
    fn list(filter: Filter) -> Result<Vec<Card>>;
}
\`\`\`

**保证**：
- 所有数据操作幂等
- 失败时返回明确错误类型，不抛异常
- 不暴露底层存储细节（CRDT、SQL 等）

（注意：只展示接口签名，具体实现见 `cargo doc`）
```

---

### Implementation 层（实现指南）

**职责**：指导开发者如何编写代码和文档

**应该包含**：
- Rust 文档编写规范（如何写 cargo doc）
- 测试方法论和 TDD 流程
- 日志规范和最佳实践
- 构建和开发环境指南

**不应包含**：
- 具体业务逻辑的实现代码
- 重复架构文档的内容

**命名规范**：
- 小写下划线：`rust_doc_guide.md`、`testing_guide.md`

---

### Management 层（管理文档）

**职责**：跟踪项目进度和规划

**应该包含**：
- TODO.md：当前任务状态（AI 可自动更新）
- roadmap.md：版本规划和里程碑
- CHANGELOG.md：版本发布历史

**不应包含**：
- 设计决策（应在 architecture/ 层）
- 实现细节

**命名规范**：
- 大写：`TODO.md`、`CHANGELOG.md`
- 小写：`roadmap.md`

---

## 🛠️ 编写指南

### 如何编写需求文档

1. **使用用户视角**：
   - ✅ "用户在地铁上突然有灵感，打开应用快速记录"
   - ❌ "系统调用 CardService.create() 创建卡片实例"

2. **避免技术术语**：
   - ✅ "系统自动合并冲突，无需用户干预"
   - ❌ "使用 Loro CRDT 的 OpLog 实现冲突解决"

3. **关注"为什么"**：
   - ✅ "支持离线编辑，因为用户可能在无网络环境下使用"
   - ❌ "实现本地 SQLite 缓存"

### 如何编写架构文档

1. **定义契约和边界**：
   - 使用表格定义数据契约
   - 使用伪代码展示接口签名
   - 明确各层职责和保证（Guarantees）

2. **关注"为什么"而非"怎么做"**：
   - ✅ "为什么选择双层架构？因为 CRDT 无索引，SQLite 提供快速查询"
   - ❌ "以下是 SQLite 表的完整 CREATE TABLE 语句..."

3. **指向代码实现**：
   - ✅ "具体实现见 `cargo doc --open` 的 CardRepository 文档"
   - ❌ 在文档中粘贴完整的 Rust 代码

### 术语和格式规范

- **术语一致性**：使用 GLOSSARY.md 维护术语表
- **Markdown 格式**：遵循 CommonMark 规范
- **Mermaid 图表**：用于流程图、状态图、架构图
- **代码块**：仅用于展示契约和接口，不写完整实现

### 文档模板

**需求文档模板**：
```markdown
# [功能名称]

## 业务背景
[为什么需要这个功能？]

## 用户场景
[用户在什么情况下使用？]

## 业务规则
[有哪些约束和规则？]

## 成功指标
[如何定义"完成"？]
```

**架构文档模板**：
```markdown
# [组件/模块名称]

## 设计原则
[核心设计理念]

## 职责定义
[这个组件负责什么？]

## 接口契约
[对外提供哪些接口？]

## 技术约束
[有哪些限制和保证？]

## 实现参考
[指向 cargo doc 或相关代码]
```

---

## 🔍 维护和审查

### 定期回顾

- **每个开发阶段结束后**：回顾文档是否仍符合分层原则
- **重构代码时**：检查是否需要更新架构文档
- **发现文档腐化**：及时归档过时内容到 `docs/archive/`

### 文档质量检查清单

**设计文档**：
- [ ] 是否包含代码实现？（应删除）
- [ ] 是否混淆了不同层的职责？（应拆分）
- [ ] 术语是否与 GLOSSARY.md 一致？
- [ ] 是否定义了清晰的契约和边界？

**管理文档**：
- [ ] TODO.md 是否及时更新？（AI 应自动更新）
- [ ] roadmap.md 是否与实际进度同步？
- [ ] CHANGELOG.md 是否记录了所有版本变更？

### 常见问题

**Q: 什么时候应该更新架构文档？**
A: 当设计决策发生变化时（如改变分层策略、修改数据契约）。单纯的代码实现优化不需要更新。

**Q: 文档中可以有代码示例吗？**
A: 可以有伪代码展示接口契约，但不应有完整实现。指向 `cargo doc` 查看真实代码。

**Q: Interaction 层在 MVP 阶段需要吗？**
A: 如果 UI 足够简单，可以暂时不创建。当 UI 复杂度上升时再补充。

**Q: 如何避免文档过时？**
A: 遵循"不写代码"原则，文档只描述设计意图，与代码解耦，自然延长生命周期。

---

## 📌 快速参考

### 文档分类速查

| 问题 | 应查阅 |
|------|--------|
| 为什么要做这个功能？ | requirements/product_vision.md |
| 用户如何使用？ | requirements/user_scenarios.md |
| 界面如何流转？ | interaction/ui_flows.md |
| 系统如何设计？ | architecture/system_design.md |
| 数据字段有哪些？ | architecture/data_contract.md |
| 为什么选这个技术？ | architecture/tech_constraints.md |
| 如何编写测试？ | implementation/testing_guide.md |
| 如何构建项目？ | tool/BUILD_GUIDE.md |
| 当前做到哪了？ | TODO.md |
| 长期规划是什么？ | docs/roadmap.md |

### AI 使用场景

| 场景 | AI 应读取的文档 |
|------|----------------|
| 修复 Bug | architecture/ + cargo doc |
| 实现新功能 | requirements/ + architecture/ |
| 优化性能 | architecture/system_design.md |
| 编写测试 | implementation/testing_guide.md |
| 总结进度 | TODO.md + roadmap.md |
| 规划任务 | roadmap.md + requirements/ |

---

## 📖 延伸阅读

- [CLAUDE.md](../CLAUDE.md) - AI 工作流程指南
- [roadmap.md](roadmap.md) - 项目长期规划
- [architecture/system_design.md](architecture/system_design.md) - 核心架构设计
- [implementation/rust_doc_guide.md](implementation/rust_doc_guide.md) - Rust 文档规范

---

**最后更新**：2026-01-04
