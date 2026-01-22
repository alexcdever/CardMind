# Proposal: Refactor OpenSpec Structure to Domain-Driven Organization

## Problem Statement

当前的 OpenSpec 规格文档结构按技术栈分类（`rust/` 和 `flutter/`），导致以下问题：

1. **业务逻辑割裂**：同一功能的后端逻辑和前端实现分散在不同目录，AI 和开发者需要在多个目录间跳转才能理解完整的功能
2. **AI 不友好的命名**：使用 `SP-FLT-MOB-001` 这种编号前缀，AI 需要额外解析才能理解语义
3. **查找困难**：实现某个功能（如"搜索"）时，需要分别在 `rust/` 和 `flutter/mobile/`、`flutter/desktop/` 中查找相关规格
4. **扩展性差**：新增功能时需要考虑编号冲突和目录归属

## Proposed Solution

将规格文档结构从"技术栈分类"重构为"领域/功能分类"：

### 新结构概览

```
specs/
├── engineering/          # 工程规范（新增）
│   ├── guide.md
│   ├── tech_stack.md
│   └── directory_conventions.md
├── adr/                  # 架构决策（保持）
├── domain/               # 核心业务逻辑（新增）
│   ├── pool_model.md
│   ├── card_store.md
│   ├── sync_protocol.md
│   └── device_config.md
├── api/                  # 接口契约（新增）
│   └── api_spec.md
├── features/             # 具体业务特性（新增）
│   ├── card_editor/
│   │   ├── logic.md
│   │   ├── ui_desktop.md
│   │   └── ui_mobile.md
│   ├── card_list/
│   ├── search/
│   └── ...
└── ui_system/            # 全局 UI 规范（新增）
    ├── design_tokens.md
    └── shared_widgets.md
```

### 核心改进

1. **业务逻辑聚合**：每个功能的所有规格（后端 + 前端）在同一目录下
2. **语义化命名**：使用 `card_editor.md` 而不是 `SP-FLT-MOB-002-card-editor.md`
3. **领域驱动**：按业务领域（domain）和功能（features）组织，而非技术栈
4. **AI 友好**：文件名即功能名，AI 可以直接理解和定位

## Benefits

### 对 AI 的好处

- **语义理解更准确**：`features/card_editor/ui_mobile.md` 比 `SP-FLT-MOB-002` 更直观
- **上下文更完整**：修改"搜索"功能时，可以同时读取 `features/search/` 下的所有相关规格
- **查找更高效**：直接定位到功能目录，不需要在技术栈目录间跳转

### 对开发者的好处

- **业务逻辑聚合**：一个功能的所有规格在同一目录
- **命名更直观**：文件名即功能名，不需要记忆编号规则
- **扩展性更好**：新增功能时创建 `features/<new_feature>/` 即可

## Implementation Strategy

### 阶段 1: 准备（不破坏现有结构）

1. 创建新目录结构
2. 创建目录约束文档（`engineering/directory_conventions.md`）
3. 创建 OpenSpec 配置文件（`.openspec/config.json`）

### 阶段 2: 逐步迁移（保持向后兼容）

1. 复制文件到新位置（保留旧文件）
2. 更新索引文件（`specs/README.md`）
3. 更新工程规范（`engineering/guide.md`）
4. 更新相关文档（`CLAUDE.md`、`AGENTS.md`）

### 阶段 3: 废弃旧结构（可选）

1. 在旧目录添加 `DEPRECATED.md`
2. 保留旧文件 3-6 个月
3. 最终删除（可选）

## Risks and Mitigations

| 风险 | 缓解措施 |
|------|---------|
| 破坏现有引用 | 保留旧文件，逐步迁移 |
| Git 历史丢失 | 使用 `git mv` 保留历史 |
| OpenSpec CLI 不兼容 | 通过配置文件适配 |
| 团队混淆 | 添加 `DEPRECATED.md` 说明 |

## Success Criteria

- [ ] 新目录结构创建完成
- [ ] 所有规格文件迁移到新位置
- [ ] 索引文件更新完成
- [ ] 相关文档（CLAUDE.md、AGENTS.md）更新完成
- [ ] OpenSpec CLI 配置完成并测试通过
- [ ] 旧目录标记为 deprecated

## Timeline

- **阶段 1**（准备）：1 小时
- **阶段 2**（迁移）：2-3 小时
- **阶段 3**（废弃）：可选，3-6 个月后

## References

- 建议来源：`docs/advice/openspec-doc-advice.md`
- 当前规格索引：`openspec/specs/README.md`
- Spec Coding 指南：`openspec/specs/SPEC_CODING_GUIDE.md`
