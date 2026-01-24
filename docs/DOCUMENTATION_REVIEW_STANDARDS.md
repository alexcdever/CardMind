# 文档 Review 标准
# Documentation Review Standards

**版本 Version**: 1.0.0
**最后更新 Last Updated**: 2026-01-24
**维护者 Maintainer**: CardMind Team

---

## 📖 概述
## Overview

本文档定义了 CardMind 项目中文档 review 的标准和流程，确保文档质量和一致性。
This document defines the standards and process for documentation review in the CardMind project, ensuring documentation quality and consistency.

---

## ✅ Review 检查清单
## Review Checklist

### 1. 内容质量 (Content Quality)
### Content Quality

**必须检查 Must Check**:
- [ ] 内容准确无误 (Content is accurate)
- [ ] 逻辑清晰连贯 (Logic is clear and coherent)
- [ ] 没有拼写错误 (No spelling errors)
- [ ] 没有语法错误 (No grammar errors)
- [ ] 技术术语使用正确 (Technical terms used correctly)

**建议检查 Should Check**:
- [ ] 内容完整性 (Content completeness)
- [ ] 示例代码可运行 (Example code is runnable)
- [ ] 图表清晰易懂 (Diagrams are clear)

---

### 2. 格式规范 (Format Standards)
### Format Standards

**规格文档 Spec Documents**:
- [ ] 遵循双语格式 (Follows bilingual format)
- [ ] 使用 SHALL/SHOULD/MAY 关键字 (Uses SHALL/SHOULD/MAY keywords)
- [ ] 场景遵循 GIVEN-WHEN-THEN 结构 (Scenarios follow GIVEN-WHEN-THEN)
- [ ] 包含必需的元数据 (Contains required metadata):
  - Version / 版本
  - Status / 状态
  - Dependencies / 依赖
  - Related Tests / 相关测试
  - Last Updated / 最后更新

**通用文档 General Documents**:
- [ ] 标题层级正确 (Heading hierarchy is correct)
- [ ] 代码块有语言标记 (Code blocks have language tags)
- [ ] 列表格式一致 (List format is consistent)
- [ ] 表格格式正确 (Table format is correct)

---

### 3. 链接和引用 (Links and References)
### Links and References

**必须检查 Must Check**:
- [ ] 所有链接使用相对路径 (All links use relative paths)
- [ ] 所有链接指向存在的文件 (All links point to existing files)
- [ ] 没有断链 (No broken links)
- [ ] 外部链接有效 (External links are valid)

**自动化检查 Automated Check**:
```bash
# 运行链接检查工具
dart tool/check_markdown_links.dart
```

---

### 4. 规格-测试映射 (Spec-Test Mapping)
### Spec-Test Mapping

**如果是规格文档 If Spec Document**:
- [ ] 规格编号正确 (Spec number is correct): `SP-{MODULE}-{NUMBER}`
- [ ] 测试文件已创建 (Test file created)
- [ ] 测试文件路径正确 (Test file path is correct)
- [ ] 映射表已更新 (Mapping table updated)

**自动化检查 Automated Check**:
```bash
# 运行映射验证工具
dart tool/verify_spec_mapping.dart
```

---

### 5. 索引更新 (Index Updates)
### Index Updates

**如果新增文档 If Adding Document**:
- [ ] `openspec/specs/README.md` 已更新 (如果是规格)
- [ ] `docs/DOCUMENTATION_MAP.md` 已更新 (如果是新模块)
- [ ] `docs/testing/FLUTTER_SPEC_TEST_MAP.md` 已更新 (如果是 Flutter)
- [ ] `docs/adr/README.md` 已更新 (如果是 ADR)

**如果删除文档 If Removing Document**:
- [ ] 所有引用已删除或更新
- [ ] 索引已更新
- [ ] 创建了重定向文档 (如果需要)

---

### 6. 版本控制 (Version Control)
### Version Control

**如果修改规格 If Modifying Spec**:
- [ ] 版本号已更新 (Version number updated)
- [ ] 添加了变更日志 (Changelog added)
- [ ] "最后更新"日期已更新 ("Last Updated" date updated)

**版本号规则 Version Number Rules**:
- 重大变更: 1.0.0 → 2.0.0 (Major changes)
- 功能新增: 1.0.0 → 1.1.0 (Feature additions)
- 小修改: 1.0.0 → 1.0.1 (Minor fixes)

---

## 🚫 常见问题和拒绝理由
## Common Issues and Rejection Reasons

### 自动拒绝 (Auto-Reject)
### Auto-Reject

以下情况应该直接拒绝 PR:
The following cases should directly reject PR:

1. **断链 (Broken Links)**
   - 有任何断链
   - 链接使用绝对路径

2. **格式错误 (Format Errors)**
   - 规格文档不遵循双语格式
   - 缺少必需的元数据

3. **索引未更新 (Index Not Updated)**
   - 新增文档但索引未更新
   - 删除文档但引用未清理

---

### 需要修改 (Needs Changes)
### Needs Changes

以下情况需要作者修改:
The following cases need author to modify:

1. **内容问题 (Content Issues)**
   - 逻辑不清晰
   - 技术术语使用不当
   - 示例代码有错误

2. **完整性问题 (Completeness Issues)**
   - 缺少关键信息
   - 测试用例不完整
   - 依赖关系未声明

3. **一致性问题 (Consistency Issues)**
   - 与现有文档冲突
   - 命名不一致
   - 风格不统一

---

## 📋 Review 流程
## Review Process

### 1. 自动化检查 (Automated Checks)
### Automated Checks

**PR 提交时自动运行 Automatically run on PR submission**:
- GitHub Actions: Documentation Quality Check
- Pre-commit hook (本地 local)

**检查项 Check Items**:
- Markdown 链接有效性
- 规格-测试映射
- 覆盖率报告

---

### 2. 人工审查 (Manual Review)
### Manual Review

**审查者职责 Reviewer Responsibilities**:

1. **快速检查 (5 分钟) Quick Check (5 min)**:
   - 查看 PR 描述
   - 查看自动化检查结果
   - 查看修改的文件列表

2. **内容审查 (10-15 分钟) Content Review (10-15 min)**:
   - 阅读修改的内容
   - 检查逻辑和准确性
   - 验证示例代码

3. **格式审查 (5 分钟) Format Review (5 min)**:
   - 检查格式规范
   - 检查链接和引用
   - 检查索引更新

4. **反馈 (5 分钟) Feedback (5 min)**:
   - 提供具体的修改建议
   - 标记需要修改的地方
   - 批准或请求修改

**总时间 Total Time**: 约 25-30 分钟

---

### 3. 审查优先级 (Review Priority)
### Review Priority

**P0 (紧急 Urgent)**: 24 小时内完成
- 修复断链的 PR
- 修复严重错误的 PR
- 阻塞其他工作的 PR

**P1 (高优先级 High)**: 48 小时内完成
- 新增规格文档的 PR
- 架构决策记录的 PR
- 重要功能文档的 PR

**P2 (正常 Normal)**: 1 周内完成
- 文档改进的 PR
- 格式修正的 PR
- 小修改的 PR

---

## 🎯 Review 标准示例
## Review Standards Examples

### 示例 1: 优秀的规格文档 PR
### Example 1: Excellent Spec Document PR

**特征 Characteristics**:
- ✅ 遵循双语格式
- ✅ 包含完整的元数据
- ✅ 测试文件已创建
- ✅ 索引已更新
- ✅ 所有链接有效
- ✅ 自动化检查通过

**审查意见 Review Comment**:
```markdown
✅ LGTM (Looks Good To Me)

This PR follows all documentation standards:
- Bilingual format ✅
- Complete metadata ✅
- Test file created ✅
- Index updated ✅
- All links valid ✅

Approved and ready to merge.
```

---

### 示例 2: 需要修改的 PR
### Example 2: PR Needs Changes

**问题 Issues**:
- ❌ 缺少测试文件
- ❌ 索引未更新
- ⚠️ 部分链接使用绝对路径

**审查意见 Review Comment**:
```markdown
⚠️ Changes Requested

Issues found:
1. ❌ Test file missing: Please create `test/specs/new_feature_spec_test.dart`
2. ❌ Index not updated: Please update `openspec/specs/README.md`
3. ⚠️ Absolute paths: Please use relative paths in lines 45, 67

Please fix these issues and re-request review.
```

---

### 示例 3: 自动拒绝的 PR
### Example 3: Auto-Rejected PR

**问题 Issues**:
- ❌ 多个断链
- ❌ 规格文档不遵循双语格式

**审查意见 Review Comment**:
```markdown
❌ Changes Rejected

Critical issues found:
1. ❌ Broken links (5 found): Run `dart tool/check_markdown_links.dart` to fix
2. ❌ Spec document not bilingual: Please follow the format in `openspec/engineering/spec_writing_guide.md`

These are blocking issues. Please fix them before re-requesting review.

Automated check results:
[Link to GitHub Actions run]
```

---

## 📊 Review 质量指标
## Review Quality Metrics

### 目标指标 Target Metrics

| 指标 Metric | 目标 Target | 当前 Current |
|-------------|-------------|--------------|
| 平均 review 时间 | < 48 小时 | - |
| 首次通过率 | > 70% | - |
| 自动化检查通过率 | > 90% | - |
| 文档质量评分 | > 8.0/10 | 8.5/10 |

### 监控方法 Monitoring Methods

**每月统计 Monthly Statistics**:
- PR 数量和类型
- Review 时间分布
- 常见问题类型
- 改进建议

---

## 🔄 持续改进
## Continuous Improvement

### 反馈机制 Feedback Mechanism

**收集反馈 Collect Feedback**:
- PR 作者反馈
- 审查者反馈
- 自动化工具报告

**改进流程 Improvement Process**:
1. 每月审查 review 标准
2. 更新检查清单
3. 改进自动化工具
4. 培训审查者

---

## 📚 相关文档
## Related Documents

- [文档更新流程](./DOCUMENTATION_UPDATE_PROCESS.md) - 如何更新文档
- [规格编写指南](../openspec/engineering/spec_writing_guide.md) - 如何编写规格
- [PR 检查清单](../.github/PULL_REQUEST_TEMPLATE.md) - PR 模板

---

## 🆘 获取帮助
## Getting Help

**审查者问题 Reviewer Questions**:
- 不确定如何评价: 查看本文档的"Review 标准示例"
- 发现新问题: 在本文档中添加到"常见问题"
- 需要培训: 联系维护者

**作者问题 Author Questions**:
- Review 被拒绝: 查看审查意见中的具体问题
- 不理解标准: 查看"Review 标准示例"
- 需要帮助: 在 PR 中 @mention 审查者

---

**最后更新 Last Updated**: 2026-01-24
**维护者 Maintainer**: CardMind Team
