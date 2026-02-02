# Design: Audit and Standardize Main Spec Format

## Context

主规格目录 (`openspec/specs/`) 当前包含 42 个规格文档，覆盖：
- 5 个 ADR（架构决策记录）
- 5 个 Engineering 规格
- 5 个 Domain 规格
- 1 个 API 规格
- 14 个 Feature 规格
- 3 个 UI System 规格
- 9 个 UI 组件规格（测试即规格）

通过初步审查发现：
- `openspec/specs/domain/card_store.md` - 标题为 "CardStore Transformation Specification"，包含多处 "Behavior Change" 注释
- `openspec/specs/domain/device_config.md` - 包含 "Key Changes" 段落

这些文档使用了 **delta spec 风格**（描述变更过程），而主规格应使用**稳定描述风格**（描述最终状态）。

**当前约束**：
- 不能破坏现有规格的语义和需求
- 必须保留所有测试用例引用
- 改写必须是格式层面的，不能改变技术内容

**利益相关者**：
- OpenSpec 工作流使用者
- 规格文档维护者
- 新加入项目的开发者

## Goals / Non-Goals

**Goals:**
- 识别所有不符合主规格标准的文档（完整扫描）
- 将变更风格的规格改写为稳定描述风格
- 创建主规格格式标准文档，明确主规格 vs delta spec 的区别
- 更新 SPEC_TEMPLATE.md 和 SPEC_EXAMPLE.md，提供清晰的格式指南
- 确保所有主规格使用一致的描述风格

**Non-Goals:**
- 不改变规格的技术内容和需求定义
- 不修改测试用例代码
- 不重新实现任何功能
- 不修改 delta spec（仅审查主规格）
- 不创建新的验证工具（手工审查即可）

## Decisions

### Decision 1: 采用双阶段审查流程

**选择**: 先自动扫描识别，再人工审查改写

**理由**:
- 自动扫描可以快速定位所有可疑文档（grep 关键词）
- 人工审查确保不误改语义和技术内容
- 改写工作量不大（仅 2 个文档），不需要自动化

**备选方案**:
- ❌ 纯人工审查：容易遗漏文档
- ❌ 完全自动化改写：风险高，可能破坏语义

### Decision 2: 改写规则明确化

**选择**: 创建详细的改写检查清单

**改写规则**:
1. **标题层面**:
   - "X Transformation Specification" → "X Specification"
   - "X 改造规格" → "X 规格"

2. **Overview 层面**:
   - 从 "defines the X transformation to support Y" → "defines the X system for Y"
   - 移除 "Core Changes"、"Key Changes" 段落

3. **代码注释层面**:
   - "Behavior Change: X" → "X" （描述当前行为，不提历史）
   - 保留所有功能描述，只移除"变更"语气

4. **需求和场景层面**:
   - 保持不变（Requirement/Scenario 本身是稳定格式）

**理由**:
- 规则明确可复现
- 易于审查和验证
- 避免主观判断差异

**备选方案**:
- ❌ 逐文档定制规则：不一致，难维护

### Decision 3: 创建 spec-format-standard 文档

**选择**: 在 `specs/` 目录下创建专门的格式标准文档

**位置**: `openspec/changes/audit-main-specs-format/specs/spec-format-standard/spec.md`

**内容包括**:
- 主规格 vs delta spec 的定义和区别
- 主规格禁止使用的关键词列表
- 主规格标准格式示例
- 格式审查检查清单

**理由**:
- 集中管理格式标准
- 可复用的审查依据
- 新规格创建时的参考

**备选方案**:
- ❌ 仅更新 SPEC_TEMPLATE.md：分散，不够显式
- ❌ 写在 engineering/guide.md：不够独立

### Decision 4: 改写现有规格的方式

**选择**: 直接在主规格文件上修改（in-place edit）

**理由**:
- 改动小（仅 2 个文件），不需要复杂的迁移
- 保持文件路径和引用不变
- 改写后状态即为最终期望状态

**备选方案**:
- ❌ 创建新文件后删除旧文件：引用断裂风险
- ❌ 先移到 changes/，改写后再移回：过度工程

### Decision 5: 更新模板文档的策略

**选择**: 在 SPEC_TEMPLATE.md 顶部添加 "格式说明" 段落

**内容**:
```markdown
## 📌 格式说明：主规格 vs Delta Spec

**本模板用于主规格（Main Spec）**：
- 位置：`openspec/specs/`
- 风格：描述系统的**稳定、已实现状态**（"是什么"）
- 禁止使用：Transformation、Core Changes、Behavior Change、Key Changes 等变更描述

**Delta Spec（变更规格）**：
- 位置：`openspec/changes/<change-name>/specs/`
- 风格：描述**正在进行的变更**（"如何改造"）
- 生命周期：变更完成后，改写为主规格风格并同步到 `openspec/specs/`

详见：[spec-format-standard](../specs/spec-format-standard/spec.md)
```

**理由**:
- 在使用点提供上下文提示
- 明确区分两种规格的使用场景
- 链接到详细标准文档

**备选方案**:
- ❌ 创建单独的 DELTA_SPEC_TEMPLATE.md：增加维护负担
- ❌ 不在模板中说明：新用户容易混淆

## Risks / Trade-offs

### Risk 1: 改写过程中可能误改语义

**缓解措施**:
- 改写前完整阅读规格内容
- 仅改动格式层面的内容（标题、Overview、注释）
- 保留所有 Requirement、Scenario、测试用例
- 改写后对比 diff，确保仅为格式变更

### Risk 2: 可能有其他未发现的变更风格规格

**缓解措施**:
- 使用多个关键词进行全量扫描：
  ```bash
  grep -r "Transformation\|Core Changes\|Key Changes\|Behavior Change" openspec/specs/
  ```
- 扫描结果记录在 design.md 中
- 改写完成后再次扫描验证

### Risk 3: 未来可能再次引入变更风格的规格

**缓解措施**:
- 创建明确的格式标准文档（spec-format-standard）
- 在 SPEC_TEMPLATE.md 中添加显著说明
- 在 CLAUDE.md 中补充格式审查提醒
- 考虑在 Project Guardian 中添加格式检查规则（后续工作）

### Trade-off: 不创建自动化验证工具

**取舍**:
- ✅ 节省开发时间（2 个文档的改写工作量很小）
- ✅ 避免过度工程
- ❌ 未来需要手工审查新规格

**判断**: 可接受。规格创建频率不高，手工审查成本可控。如果未来规格数量大幅增长，再考虑自动化。

## Migration Plan

**不适用**：这是纯文档工作，无需部署和回滚策略。

**实施步骤**（记录在 tasks.md）：
1. 全量扫描识别问题文档
2. 创建 spec-format-standard 文档
3. 改写 card_store.md
4. 改写 device_config.md
5. 更新 SPEC_TEMPLATE.md
6. 更新 SPEC_EXAMPLE.md
7. 更新 CLAUDE.md（可选）
8. 验证扫描确认无遗漏

## Open Questions

无待解决问题。实施方案已明确。
