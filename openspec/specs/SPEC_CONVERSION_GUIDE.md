# Bilingual Specification Conversion Guide
# 双语规格转换指南

**Version** | **版本**: 1.0.0
**Last Updated** | **最后更新**: 2026-01-21

---

## Conversion Progress | 转换进度

### ✅ Completed | 已完成

**Templates & Guides | 模板和指南**:
- ✅ `SPEC_TEMPLATE.md` - Standard bilingual template | 标准双语模板
- ✅ `SPEC_EXAMPLE.md` - Complete example specification | 完整示例规格
- ✅ `BILINGUAL_SPEC_GUIDE.md` - Writing guide | 编写指南
- ✅ `SPEC_CONVERSION_GUIDE.md` - This conversion guide | 本转换指南

**Converted Specifications | 已转换规格**:

**Phase 1 - Core Domain (Completed) | 阶段1 - 核心领域（已完成）**:
- ✅ `domain/pool_model.md` - Single Pool Model | 单池模型
- ✅ `domain/card_store.md` - CardStore transformation | CardStore 改造
- ✅ `domain/device_config.md` - Device configuration | 设备配置
- ✅ `domain/sync_protocol.md` - Sync layer | 同步层
- ✅ `domain/common_types.md` - Common type system | 通用类型系统

**Phase 2 - Feature Specs (In Progress) | 阶段2 - 功能规格（进行中）**:

**Card Editor | 卡片编辑器** (Completed | 已完成):
- ✅ `features/card_editor/note_card.md` - NoteCard component | NoteCard 组件
- ✅ `features/card_editor/fullscreen_editor.md` - Fullscreen editor | 全屏编辑器
- ✅ `features/card_editor/card_editor_screen.md` - Card editor screen | 卡片编辑器屏幕

**Sync Feedback | 同步反馈** (Completed | 已完成):
- ✅ `features/sync_feedback/sync_status_indicator.md` - Sync status indicator | 同步状态指示器
- ✅ `features/sync_feedback/sync_details_dialog.md` - Sync details dialog | 同步详情对话框

**Tools | 工具**:
- ✅ `tool/convert_to_bilingual.py` - Batch conversion script | 批量转换脚本
- ✅ `tool/update_spec_references.py` - Reference format updater | 引用格式更新器

### 📋 Pending Conversion | 待转换

**Medium Priority (Feature Specs) | 中优先级（功能规格）**:

All medium priority feature specs completed! ✅

**Low Priority (Platform-Specific Specs) | 低优先级（平台特定规格）**:
- `features/*/desktop.md` (6 files)
- `features/*/mobile.md` (7 files)
- `features/*/shared.md` (3 files)

**API & UI System | API 和 UI 系统** (Completed | 已完成):
- [x] `api/api_spec.md` ✅
- [x] `ui_system/adaptive_ui_components.md` ✅
- [x] `ui_system/design_tokens.md` ✅
- [x] `ui_system/responsive_layout.md` ✅
- [x] `ui_system/shared_widgets.md` ✅

**Low Priority (Platform-Specific Specs) | 低优先级（平台特定规格）**:
- **Completed | 已完成**: 37/40 files (92.5%) | 37/40 个文件（92.5%）
- **Remaining | 剩余**: 3 files | 3 个文件

**Recently Completed (This Session) | 最近完成（本次会话）**:
- ✅ `features/card_list/desktop.md` - Desktop card grid
- ✅ `features/card_list/mobile.md` - Mobile card list
- ✅ `features/card_editor/desktop.md` - Desktop inline editor
- ✅ `features/card_editor/mobile.md` - Mobile fullscreen editor
- ✅ `features/context_menu/desktop.md` - Desktop context menu
- ✅ `features/fab/mobile.md` - Mobile FAB
- ✅ `features/gestures/mobile.md` - Mobile gestures
- ✅ `features/home_screen/shared.md` - Shared home screen spec
- ✅ `features/onboarding/shared.md` - Shared onboarding spec
- ✅ `features/search/desktop.md` - Desktop search
- ✅ `features/search/mobile.md` - Mobile search
- ✅ `features/sync_feedback/shared.md` - Shared sync feedback
- ✅ `features/toolbar/desktop.md` - Desktop toolbar

---

## Conversion Methods | 转换方法

### Method 1: Manual Conversion (Recommended for Core Specs)
### 方法 1：手动转换（推荐用于核心规格）

**Best for | 最适合**:
- Core domain specifications | 核心领域规格
- Specifications with complex structures | 结构复杂的规格
- Specifications requiring high-quality translations | 需要高质量翻译的规格

**Steps | 步骤**:
1. Open the specification file | 打开规格文件
2. Copy `SPEC_TEMPLATE.md` as starting point | 复制 `SPEC_TEMPLATE.md` 作为起点
3. Fill in metadata (Version, Status, Dependencies) | 填写元数据（版本、状态、依赖）
4. Convert each requirement section:
   - Add English title | 添加英文标题
   - Add Chinese translation immediately after | 紧随其后添加中文翻译
   - Convert scenarios using GIVEN/WHEN/THEN keywords | 使用 GIVEN/WHEN/THEN 关键字转换场景
5. Add test coverage section | 添加测试覆盖部分
6. Add related documents section | 添加相关文档部分

**Example | 示例**: See `features/card_editor/note_card.md` for a complete example.
查看 `features/card_editor/note_card.md` 作为完整示例。

### Method 2: Semi-Automated Conversion (For Simple Specs)
### 方法 2：半自动转换（用于简单规格）

**Best for | 最适合**:
- Specifications already using ADDED Requirements format | 已使用 ADDED Requirements 格式的规格
- New specifications created recently | 最近创建的新规格
- Specifications with consistent structure | 结构一致的规格

**Steps | 步骤**:
1. Run the conversion script | 运行转换脚本:
   ```bash
   python3 tool/convert_to_bilingual.py --dry-run
   ```
2. Review the preview output | 查看预览输出
3. Run actual conversion | 运行实际转换:
   ```bash
   python3 tool/convert_to_bilingual.py
   ```
4. **IMPORTANT**: Review and fill in `[待翻译]` placeholders | **重要**：查看并填写 `[待翻译]` 占位符
5. Verify the result | 验证结果

**Note | 注意**: The script adds placeholders for Chinese translations. You MUST manually fill these in for accurate translations.

脚本会为中文翻译添加占位符。您必须手动填写这些占位符以确保翻译准确。

### Method 3: Template-Based Creation (For New Specs)
### 方法 3：基于模板创建（用于新规格）

**Best for | 最适合**:
- Creating new specifications from scratch | 从头创建新规格
- Ensuring bilingual format from the start | 从一开始确保双语格式

**Steps | 步骤**:
1. Copy `SPEC_TEMPLATE.md` to new location | 复制 `SPEC_TEMPLATE.md` 到新位置
2. Rename the file | 重命名文件
3. Fill in all sections in both languages simultaneously | 同时填写两种语言的所有部分
4. Reference `SPEC_EXAMPLE.md` for guidance | 参考 `SPEC_EXAMPLE.md` 获取指导

---

## Conversion Workflow | 转换工作流

### Phase 1: Core Domain Specs ✅ COMPLETED
### 阶段 1：核心领域规格 ✅ 已完成

Priority: **HIGH** | 优先级：**高**

- [x] `domain/card_store.md` ✅
- [x] `domain/device_config.md` ✅
- [x] `domain/sync_protocol.md` ✅
- [x] `domain/common_types.md` ✅
- [x] `domain/pool_model.md` ✅ (completed earlier | 之前已完成)

**Method | 方法**: Manual conversion with careful translation | 手动转换并仔细翻译
**Status | 状态**: ✅ All core domain specs converted | 所有核心领域规格已转换

### Phase 2: New Feature Specs (In Progress)
### 阶段 2：新功能规格（进行中）

Priority: **MEDIUM** | 优先级：**中**

**Card Editor | 卡片编辑器** (Completed | 已完成):
- [x] `features/card_editor/note_card.md` ✅
- [x] `features/card_editor/fullscreen_editor.md` ✅
- [x] `features/card_editor/card_editor_screen.md` ✅

**Sync Feedback | 同步反馈** (Completed | 已完成):
- [x] `features/sync_feedback/sync_status_indicator.md` ✅
- [x] `features/sync_feedback/sync_details_dialog.md` ✅

**Card List & Detail | 卡片列表与详情** (Completed | 已完成):
- [x] `features/card_list/card_list_item.md` ✅
- [x] `features/card_detail/card_detail_screen.md` ✅

**Sync & Navigation | 同步与导航** (Completed | 已完成):
- [x] `features/sync/sync_screen.md` ✅
- [x] `features/home_screen/home_screen.md` ✅
- [x] `features/navigation/mobile_nav.md` ✅

**Settings | 设置** (Completed | 已完成):
- [x] `features/settings/device_manager_panel.md` ✅
- [x] `features/settings/settings_panel.md` ✅
- [x] `features/settings/settings_screen.md` ✅

**Method | 方法**: Semi-automated + manual review | 半自动 + 手动审查

### Phase 3: Platform-Specific Specs (Week 3)
### 阶段 3：平台特定规格（第 3 周）

Priority: **LOW** | 优先级：**低**

- [ ] Desktop specifications (6 files)
- [ ] Mobile specifications (7 files)
- [ ] Shared specifications (2 remaining)

**Method | 方法**: Semi-automated conversion | 半自动转换

### Phase 4: API & UI System (Week 4)
### 阶段 4：API 和 UI 系统（第 4 周）

Priority: **MEDIUM** | 优先级：**中**

- [ ] `api/api_spec.md`
- [ ] `ui_system/adaptive_ui_components.md`
- [ ] `ui_system/design_tokens.md`
- [ ] `ui_system/responsive_layout.md`
- [ ] `ui_system/shared_widgets.md`

**Method | 方法**: Mixed (manual for complex parts, semi-automated for simple parts) | 混合（复杂部分手动，简单部分半自动）

---

## Quality Checklist | 质量检查清单

Before marking a specification as "converted", verify:

在将规格标记为"已转换"之前，请验证：

- [ ] **Metadata** | **元数据**: All metadata fields present in bilingual format | 所有元数据字段以双语格式呈现
- [ ] **Title** | **标题**: Both English and Chinese titles present | 英文和中文标题都存在
- [ ] **Requirements** | **需求**: All requirements have bilingual titles and SHALL statements | 所有需求都有双语标题和 SHALL 陈述
- [ ] **Scenarios** | **场景**: All scenarios use GIVEN/WHEN/THEN keywords in both languages | 所有场景在两种语言中都使用 GIVEN/WHEN/THEN 关键字
- [ ] **Translations** | **翻译**: Chinese translations are accurate and consistent | 中文翻译准确且一致
- [ ] **No Placeholders** | **无占位符**: All `[待翻译]` placeholders removed | 所有 `[待翻译]` 占位符已移除
- [ ] **Links** | **链接**: All dependencies use Markdown links | 所有依赖使用 Markdown 链接
- [ ] **Test Section** | **测试部分**: Test coverage section complete | 测试覆盖部分完整
- [ ] **Related Docs** | **相关文档**: Related documents section present | 相关文档部分存在

---

## Translation Guidelines | 翻译指南

### Key Terminology | 关键术语

Refer to `BILINGUAL_SPEC_GUIDE.md` for the complete terminology table.

完整术语表请参考 `BILINGUAL_SPEC_GUIDE.md`。

### Translation Principles | 翻译原则

1. **Accuracy First** | **准确性优先**: Technical accuracy > literal translation | 技术准确性 > 字面翻译
2. **Consistency** | **一致性**: Use the same Chinese term for the same English term throughout | 在整个文档中对相同的英文术语使用相同的中文术语
3. **Naturalness** | **自然性**: Chinese should read naturally to native speakers | 中文对母语者来说应该读起来自然
4. **Brevity** | **简洁性**: Keep Chinese translations concise where possible | 尽可能保持中文翻译简洁

### Common Patterns | 常见模式

**SHALL statements | SHALL 陈述**:
```markdown
The system SHALL [verb] [object].
系统应[动词][宾语]。
```

**Scenarios | 场景**:
```markdown
- **GIVEN** [precondition]
- **前置条件**：[前置条件]
- **WHEN** [action]
- **操作**：[操作]
- **THEN** [outcome]
- **预期结果**：[结果]
```

---

## Tools & Resources | 工具和资源

**Templates | 模板**:
- `openspec/specs/SPEC_TEMPLATE.md` - Blank template | 空白模板
- `openspec/specs/SPEC_EXAMPLE.md` - Complete example | 完整示例

**Guides | 指南**:
- `openspec/specs/BILINGUAL_SPEC_GUIDE.md` - Writing guide | 编写指南
- `openspec/specs/SPEC_CONVERSION_GUIDE.md` - This guide | 本指南

**Tools | 工具**:
- `tool/convert_to_bilingual.py` - Conversion script | 转换脚本
- `tool/verify_spec_sync.dart` - Validation tool | 验证工具

**Examples | 示例**:
- `domain/pool_model.md` - Domain specification example | 领域规格示例
- `features/card_editor/note_card.md` - Feature specification example | 功能规格示例

---

## Next Steps | 后续步骤

1. **Start with Phase 1** | **从阶段 1 开始**: Convert core domain specifications manually | 手动转换核心领域规格
2. **Review Examples** | **查看示例**: Study converted examples for guidance | 学习已转换的示例作为指导
3. **Use Tools** | **使用工具**: Leverage conversion scripts for simple specs | 利用转换脚本处理简单规格
4. **Iterate** | **迭代**: Review, improve, and refine translations | 审查、改进和完善翻译
5. **Validate** | **验证**: Run verification tool after conversion | 转换后运行验证工具

---

**Questions? | 有疑问？**

Refer to completed examples or consult the bilingual spec guide.

参考已完成的示例或查阅双语规格指南。

---

**Last Updated** | **最后更新**: 2026-01-21
**Maintained By** | **维护者**: CardMind Team
