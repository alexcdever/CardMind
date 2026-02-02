## Context

CardMind 项目刚完成两次重大重构：
1. **规格结构重构**（2026-01-20）：从技术栈驱动（`rust/`, `flutter/`）迁移到领域驱动组织（`engineering/`, `domain/`, `api/`, `features/`, `ui_system/`）
2. **UI 重构**（2026-01-20）：从传统导航模式迁移到 React 风格设计（移动端底部导航+全屏编辑器，桌面端三栏布局+内联编辑）

**当前状态**：
- 新领域驱动规格结构：28 个规格文档（5 engineering + 5 domain + 1 api + 14 features + 3 ui_system）
- Rust 后端：~9000 行代码（Loro CRDT + SQLite 双层架构）
- Flutter 前端：~8000 行代码（新增 8 个现代化组件 + 17 个测试文件）
- 旧规格文档：保留在 `rust/` 和 `flutter/` 目录（已标记 DEPRECATED）

**约束条件**：
- 必须保持 OpenSpec 工作流的完整性
- 不能破坏现有的规格文档结构
- 验证工具需要易于集成和维护
- 必须遵循 Project Guardian 约束（Unix LF, 无 unwrap/panic）

**利益相关者**：
- 开发者：需要可靠的规格文档指导开发
- 维护者：需要及时发现规格-代码不一致
- AI Agents（Claude）：依赖准确的规格文档理解系统

## Goals / Non-Goals

**Goals:**
- 验证新领域驱动规格结构的完整性和准确性
- 识别代码与规格的覆盖率缺口（有代码无规格 / 有规格无代码）
- 检测规格内容与实际实现的不一致（方法签名、数据结构、行为差异）
- 生成可操作的同步报告，指导规格更新
- 建立可重复的验证流程，防止未来脱节

**Non-Goals:**
- 不自动修改规格或代码（仅报告，人工审核后修改）
- 不重新组织已归档的旧规格（`rust/` 和 `flutter/` 保持不变）
- 不实现实时同步机制（阶段性手动验证即可）
- 不集成到 CI/CD（本次仅建立验证能力，集成可后续考虑）
- 不验证测试覆盖率（专注于规格-代码同步，不评估测试质量）

## Decisions

### Decision 1: 验证工具实现语言 - Dart

**选择**: 使用 Dart 实现验证工具（`tool/verify_spec_sync.dart`）

**理由**:
- 项目已有 Dart 工具链基础设施（`tool/validate_constraints.dart`, `tool/fix_lint.dart`）
- Dart 对 Flutter/Rust 项目结构理解良好（可解析 Dart 代码和 Rust 文件）
- 开发者熟悉 Dart，维护成本低
- 可以复用现有的文件扫描和报告生成逻辑

**替代方案**:
- ❌ Rust：需要额外维护 Rust 工具链，且解析 Dart 代码较困难
- ❌ Python：引入新依赖，项目无现有 Python 基础设施
- ❌ Shell script：复杂度高，可维护性差

### Decision 2: 验证范围 - 三层检查

**选择**: 分三层验证：覆盖率检查 → 结构验证 → 内容一致性

**层次 1: 覆盖率检查（Spec Coverage）**
- 扫描代码文件（`rust/src/`, `lib/`），识别模块/组件
- 对比规格目录（`domain/`, `features/`, `api/`），检查是否有对应规格
- 输出：缺失规格清单、孤立规格清单

**层次 2: 结构验证（Structure Validation）**
- 验证规格文档结构完整性（必需章节：Overview, Requirements, Examples）
- 检查规格间的依赖关系（Referenced specs 是否存在）
- 验证文件命名约定（snake_case, 无技术栈前缀）

**层次 3: 内容一致性（Content Consistency）**
- 提取规格中的 API 签名、数据结构定义
- 对比实际代码中的函数签名、struct/class 定义
- 报告不匹配项（参数类型、返回值、字段变更）

**理由**:
- 分层检查从粗到细，优先发现高优先级问题（缺失规格）
- 层次递进，复杂度递增，便于分阶段实现
- 每层独立可运行，灵活调整验证深度

**替代方案**:
- ❌ 全量深度验证：实现复杂度高，首次运行可能失败率高
- ❌ 仅覆盖率检查：无法发现已有规格的内容错误

### Decision 3: 报告格式 - Markdown + JSON

**选择**: 生成两种格式报告
- **Markdown 报告**（`SPEC_SYNC_REPORT.md`）：人类可读，包含详细说明和建议
- **JSON 报告**（`spec_sync_report.json`）：机器可解析，便于后续自动化

**Markdown 报告结构**:
```markdown
# Spec-Code Sync Report

## Summary
- Coverage: X% (Y/Z modules with specs)
- Inconsistencies: N issues found
- Generated: YYYY-MM-DD

## Missing Specs
- [CRITICAL] rust/src/pool.rs → No spec in domain/
- [WARNING] lib/widgets/adaptive_fab.dart → No spec in features/

## Orphaned Specs
- features/search/logic.md → No implementation found

## Content Inconsistencies
- domain/card_store.md:
  - Method `create_card` → Signature mismatch (expected 3 args, found 4)
```

**理由**:
- Markdown 便于人工审查和决策
- JSON 便于集成到工具链或 CI/CD
- 双格式覆盖不同使用场景

**替代方案**:
- ❌ 仅 Markdown：难以自动化处理
- ❌ 仅 JSON：人工查看体验差

### Decision 4: 验证粒度 - 模块级为主

**选择**: 以模块/组件为粒度验证，不深入到函数级

**粒度定义**:
- Rust：一个 `.rs` 文件 = 一个模块（如 `card_store.rs`）
- Flutter：一个 Widget 文件 = 一个组件（如 `note_card.dart`）
- 规格：对应到 `domain/<module>.md` 或 `features/<feature>/ui_*.md`

**检查内容**:
- ✅ 模块存在性（代码有，规格有？）
- ✅ 公共 API 签名（函数名、参数数量、返回类型）
- ✅ 核心数据结构（struct/class 名称、主要字段）
- ❌ 不检查：私有函数、实现细节、注释一致性

**理由**:
- 模块级粒度平衡了准确性和实现复杂度
- 避免过度耦合规格与实现细节
- 公共 API 是最重要的契约，需要严格同步

**替代方案**:
- ❌ 函数级：过于细粒度，规格与代码过度耦合，维护成本高
- ❌ 目录级：粒度太粗，无法发现具体问题

### Decision 5: 旧规格处理 - 标记但不验证

**选择**:
- 标记旧规格目录（`rust/`, `flutter/`）为 DEPRECATED
- 不对旧规格进行同步验证
- 验证仅针对新领域驱动结构（`engineering/`, `domain/`, `api/`, `features/`, `ui_system/`）

**理由**:
- 旧规格已归档，不再是主要参考
- 验证资源集中在新结构上，效率更高
- 避免混淆（旧规格可能与当前实现严重不一致）

**替代方案**:
- ❌ 同时验证新旧：浪费资源，且旧规格不一致是预期的

## Risks / Trade-offs

### Risk 1: 代码解析准确性

**风险**: Dart 工具解析 Rust/Dart 代码可能不够准确，导致误报

**缓解措施**:
- 使用保守的解析策略（如正则匹配公共函数签名，而非完整 AST 解析）
- 首次运行人工审查所有报告，校准解析逻辑
- 允许误报，由人工判断（报告标注置信度）

### Risk 2: 规格文档多样性

**风险**: 规格文档格式不统一，难以自动提取 API 定义

**缓解措施**:
- 先验证结构完整性（必需章节），推动规格标准化
- 内容一致性检查仅针对明确标记的 API 定义（如代码块）
- 提供规格模板指导，逐步规范化

### Risk 3: 维护负担

**风险**: 验证工具需要随规格结构演化而更新

**缓解措施**:
- 验证逻辑基于约定（文件命名、目录结构），而非硬编码
- 使用配置文件（如 `.openspec/config.json`）定义规格路径
- 文档化验证逻辑，便于后续维护者理解

### Trade-off: 完整性 vs 实现成本

**选择**: 优先实现覆盖率检查和结构验证（80% 价值），内容一致性检查作为 v2

**理由**:
- 覆盖率缺口（缺失规格）是最高优先级问题
- 结构验证可以快速标准化规格质量
- 内容一致性检查实现复杂，但价值增量较小（大部分不一致可通过人工 code review 发现）

## Migration Plan

### Phase 1: 工具开发（本提案）
1. 创建 `tool/verify_spec_sync.dart`
2. 实现覆盖率检查（Layer 1）
3. 实现结构验证（Layer 2）
4. 生成 Markdown + JSON 报告
5. 添加使用文档到 README.md

### Phase 2: 首次验证运行
1. 运行 `dart tool/verify_spec_sync.dart`
2. 人工审查生成的报告
3. 识别高优先级问题（缺失规格、严重不一致）
4. 创建任务清单（哪些规格需要补充/更新）

### Phase 3: 规格更新
1. 补充缺失的规格文档
2. 更新不一致的规格内容
3. 删除孤立的规格（如果确认无对应实现）
4. 再次运行验证，确认问题修复

### Phase 4: 持续验证机制
1. 更新 CLAUDE.md，添加验证工具使用说明
2. 建议在重大变更后运行验证
3. （可选）集成到 pre-commit hook 或 CI/CD

### 回滚策略
- 验证工具纯读操作，无破坏性，无需回滚
- 如果报告误导，修复工具逻辑后重新运行即可

## Open Questions

### Q1: 是否要验证测试文件与规格的对应关系？

**当前决策**: 不验证（Non-Goal）

**需要决策**: 如果发现测试覆盖率也是问题，可以在 v2 中考虑

### Q2: 内容一致性检查的实现深度？

**当前决策**: v1 不实现，v2 可选

**待确认**: 首次覆盖率报告后，评估是否需要深度内容检查

### Q3: 验证频率？

**当前决策**: 阶段性手动运行（重大变更后）

**待确认**: 是否需要定期（每周/每月）自动运行并生成趋势报告

### Q4: 如何处理归档的 UI 规格？

**问题**: `migrate-ui-to-react-design` 的 9 个 delta specs 归档时未同步到主规格，是否需要补充？

**当前建议**:
- 首次验证报告会显示 Flutter UI 组件缺少规格
- 评估哪些组件需要补充规格（优先核心组件）
- 新规格应遵循领域驱动结构（`features/<feature>/ui_*.md`）
