# 双语规格转换指南

**版本**：1.0.0
**最后更新**：2026-01-23

---


## 转换方法

### 方法 1：手动转换（推荐用于核心规格）

**最适合**：
- 核心领域规格
- 结构复杂的规格
- 需要高质量翻译的规格

**步骤**：
1. 打开规格文件
2. 复制 `spec_template.md` 作为起点
3. 填写元数据（版本、状态、依赖）
4. 转换每个需求部分：
   - 添加英文标题
   - 紧随其后添加中文翻译
   - 使用 GIVEN/WHEN/THEN 关键字转换场景
5. 添加测试覆盖部分
6. 添加相关文档部分

**示例**：查看 `features/card_editor/note_card.md` 作为完整示例。

### 方法 2：半自动转换（用于简单规格）

**最适合**：
- 已使用 ADDED Requirements 格式的规格
- 最近创建的新规格
- 结构一致的规格

**步骤**：
1. 运行转换脚本：
   ```bash
   python3 tool/convert_to_bilingual.py --dry-run
   ```
2. 查看预览输出
3. 运行实际转换：
   ```bash
   python3 tool/convert_to_bilingual.py
   ```
4. **重要**：查看并填写 `[待翻译]` 占位符
5. 验证结果

**注意**：脚本会为中文翻译添加占位符。您必须手动填写这些占位符以确保翻译准确。

### 方法 3：基于模板创建（用于新规格）

**最适合**：
- 从头创建新规格
- 从一开始确保双语格式

**步骤**：
1. 复制 `spec_template.md` 到新位置
2. 重命名文件
3. 同时填写两种语言的所有部分
4. 参考 `SPEC_EXAMPLE.md` 获取指导

---

## 转换工作流

### 阶段 1：核心领域规格 ✅ 已完成

优先级：**高**

- [x] `domain/card_store.md` ✅
- [x] `domain/device_config.md` ✅
- [x] `domain/sync_protocol.md` ✅
- [x] `domain/common_types.md` ✅
- [x] `domain/pool_model.md` ✅（之前已完成）

**方法**：手动转换并仔细翻译
**状态**：✅ 所有核心领域规格已转换

### 阶段 2：新功能规格（进行中）

优先级：**中**

**卡片编辑器（已完成）**：
- [x] `features/card_editor/note_card.md` ✅
- [x] `features/card_editor/fullscreen_editor.md` ✅
- [x] `features/card_editor/card_editor_screen.md` ✅

**同步反馈（已完成）**：
- [x] `features/sync_feedback/sync_status_indicator.md` ✅
- [x] `features/sync_feedback/sync_details_dialog.md` ✅

**卡片列表与详情（已完成）**：
- [x] `features/card_list/card_list_item.md` ✅
- [x] `features/card_detail/card_detail_screen.md` ✅

**同步与导航（已完成）**：
- [x] `features/sync/sync_screen.md` ✅
- [x] `features/home_screen/home_screen.md` ✅
- [x] `features/navigation/mobile_nav.md` ✅

**设置（已完成）**：
- [x] `features/settings/device_manager_panel.md` ✅
- [x] `features/settings/settings_panel.md` ✅
- [x] `features/settings/settings_screen.md` ✅

**方法**：半自动 + 手动审查

### 阶段 3：平台特定规格（第 3 周）

优先级：**低**

- [ ] 桌面端规格（6 个文件）
- [ ] 移动端规格（7 个文件）
- [ ] 共享规格（剩余 2 个）

**方法**：半自动转换

### 阶段 4：API 和 UI 系统（第 4 周）

优先级：**中**

- [ ] `api/api_spec.md`
- [ ] `ui_system/adaptive_ui_components.md`
- [ ] `ui_system/design_tokens.md`
- [ ] `ui_system/responsive_layout.md`
- [ ] `ui_system/shared_widgets.md`

**方法**：混合（复杂部分手动，简单部分半自动）

---

## 质量检查清单

在将规格标记为"已转换"之前，请验证：

- [ ] **元数据**：所有元数据字段以双语格式呈现
- [ ] **标题**：英文和中文标题都存在
- [ ] **需求**：所有需求都有双语标题和 SHALL 陈述
- [ ] **场景**：所有场景在两种语言中都使用 GIVEN/WHEN/THEN 关键字
- [ ] **翻译**：中文翻译准确且一致
- [ ] **无占位符**：所有 `[待翻译]` 占位符已移除
- [ ] **链接**：所有依赖使用 Markdown 链接
- [ ] **测试部分**：测试覆盖部分完整
- [ ] **相关文档**：相关文档部分存在

---

## 翻译指南

### 关键术语

完整术语表请参考 `BILINGUAL_SPEC_GUIDE.md`。

### 翻译原则

1. **准确性优先**：技术准确性 > 字面翻译
2. **一致性**：在整个文档中对相同的英文术语使用相同的中文术语
3. **自然性**：中文对母语者来说应该读起来自然
4. **简洁性**：尽可能保持中文翻译简洁

### 常见模式

**SHALL 陈述**：
```markdown
The system SHALL [verb] [object].
系统应[动词][宾语]。
```

**场景**：
```markdown
- **GIVEN** [precondition]
- **前置条件**：[前置条件]
- **WHEN** [action]
- **操作**：[操作]
- **THEN** [outcome]
- **预期结果**：[结果]
```

---

## 工具和资源

**模板**：
- `openspec/engineering/spec_template.md` - 空白模板
- `openspec/engineering/spec_example.md` - 完整示例

**指南**：
- `openspec/engineering/bilingual_spec_guide.md` - 编写指南
- `openspec/engineering/spec_conversion_guide.md` - 本指南

**工具**：
- `tool/convert_to_bilingual.py` - 转换脚本
- `tool/verify_spec_sync.dart` - 验证工具

**示例**：
- `domain/pool_model.md` - 领域规格示例
- `features/card_editor/note_card.md` - 功能规格示例

---

## 后续步骤

1. **从阶段 1 开始**：手动转换核心领域规格
2. **查看示例**：学习已转换的示例作为指导
3. **使用工具**：利用转换脚本处理简单规格
4. **迭代**：审查、改进和完善翻译
5. **验证**：转换后运行验证工具

---

**有疑问？**

参考已完成的示例或查阅双语规格指南。

---

**最后更新**：2026-01-23
**维护者**：CardMind Team
