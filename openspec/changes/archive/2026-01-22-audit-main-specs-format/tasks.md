## 1. 规格审查准备

- [x] 1.1 扫描 `openspec/specs/` 中包含 “Transformation/Core Changes/Key Changes/Behavior Change” 的文档
- [x] 1.2 复核扫描结果并确认需修正的主规格清单（预期 card_store/device_config）

## 2. 主规格格式标准化文档

- [x] 2.1 将 `spec-format-standard` 同步到主规格目录并补充到规格索引
- [x] 2.2 在 `openspec/specs/SPEC_TEMPLATE.md` 增加主规格 vs Delta Spec 说明与禁止关键词提示
- [x] 2.3 在 `openspec/specs/SPEC_EXAMPLE.md` 增加稳定描述示例，移除任何变更叙述

## 3. 标准化 CardStore 主规格

- [x] 3.1 更新 `openspec/specs/domain/card_store.md` 标题为 “CardStore Specification”
- [x] 3.2 改写 Overview 为稳定行为描述并移除 “Core Changes” 段落
- [x] 3.3 移除 Implementation 中 “Behavior Change” 注释，确保需求/场景内容不变

## 4. 标准化 DeviceConfig 主规格

- [x] 4.1 移除 `openspec/specs/domain/device_config.md` 中 “Key Changes” 段落
- [x] 4.2 改写 Overview 为稳定描述，保持需求/场景内容不变
- [x] 4.3 确认结构描述仅包含单一 `pool_id` 字段（不包含 legacy 字段）

## 5. 复核与验证

- [x] 5.1 复扫 `openspec/specs/` 确认无变更风格关键词残留
- [x] 5.2 复查相关测试引用与依赖链接仍然有效
- [x] 5.3 如需，更新 CLAUDE.md 或其他指南以提醒主规格格式约束
