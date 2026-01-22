## Why

在建立了双语规格编写标准（BILINGUAL_SPEC_GUIDE.md）之后，需要确保主规格目录中的所有文档完全符合双语格式要求。当前状态：

1. **标题已双语化**：所有 50 个规格文件的主标题（# 级别）已添加中文翻译 ✅
2. **章节标题未双语化**：大部分文件的章节标题（## 和 ### 级别）仍为单语
3. **元数据部分不一致**：部分文件的元数据未使用 `**Key** | **键**: value` 格式
4. **需求和场景标题不一致**：部分文件的 Requirement 和 Scenario 标题未双语化

**已完成的工作**：
- ✅ 所有 50 个文件的主标题已双语化
- ✅ `engineering/architecture_patterns.md` 所有章节已双语化
- ✅ `engineering/directory_conventions.md` 所有章节已双语化

**剩余工作**：
- 47 个文件的章节标题需要双语化
- 部分文件的元数据需要规范化

## What Changes

本变更将完成所有主规格文档的双语格式合规性：

1. **完成章节标题双语化**
   - 为所有 ## 和 ### 级别的章节标题添加中文翻译
   - 确保英文在前，中文紧随的格式

2. **规范化元数据格式**
   - 将元数据统一为 `**Key** | **键**: value` 格式
   - 确保所有规格包含必需的元数据字段

3. **验证合规性**
   - 运行验证脚本确认所有文件符合 BILINGUAL_SPEC_GUIDE.md 标准
   - 生成合规性报告

## Capabilities

### Modified Capabilities

所有主规格文档将更新为完全符合双语格式标准：

**engineering/ 目录** (5 个文件):
- `tech_stack.md`
- `spec_coverage_checker.md`
- `spec_migration_validator.md`
- `spec_sync_validator.md`
- `spec_format_standard.md`

**adr/ 目录** (5 个文件):
- 所有 ADR 文档的章节标题

**api/ 目录** (1 个文件):
- `api_spec.md` - 已部分双语化，需完善

**features/ 目录** (31 个文件):
- 所有功能规格的章节标题

**ui_system/ 目录** (4 个文件):
- 所有 UI 系统规格的章节标题

**其他** (1 个文件):
- `spec_coding_guide.md`

## Impact

**受影响的系统**:
- OpenSpec 规格文档系统（50 个规格文件）
- 文档可读性和一致性

**预期成果**:
- 100% 的规格文件完全符合双语格式标准
- 提升文档的可读性和专业性
- 确保 AI 工具和开发者都能准确理解规格内容

**影响范围**:
- 仅影响文档格式，不影响代码实现
- 不改变规格的技术内容，仅添加翻译
