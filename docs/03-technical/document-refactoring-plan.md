# CardMind文档拆分重构计划

## 1. 概述

本文档描述了对CardMind项目中文档进行拆分重构的计划，目标是将所有超过500行的文档拆分为更小、更聚焦的文档，提高文档的可读性和维护性。

## 2. 需要拆分的文档列表

根据初步分析，以下文档需要进行拆分重构：

| 文档路径 | 当前行数 | 拆分优先级 |
|---------|---------|-----------|
d:\Projects\CardMind\docs\03-technical\api-testing-design.md | 1743 | 高 |
d:\Projects\CardMind\docs\03-technical\interaction-logic.md | 1540 | 高 |
d:\Projects\CardMind\docs\03-technical\cross-platform-compatibility.md | 1369 | 中 |
d:\Projects\CardMind\docs\03-technical\pure-p2p-architecture.md | 1140 | 中 |
d:\Projects\CardMind\docs\03-technical\api\sync-store-api.md | 971 | 中 |
d:\Projects\CardMind\docs\03-technical\offline-lan-architecture.md | 847 | 中 |
d:\Projects\CardMind\docs\03-technical\local-signaling-server.md | 834 | 中 |
d:\Projects\CardMind\docs\03-technical\api\card-store-api.md | 833 | 中 |
d:\Projects\CardMind\docs\03-technical\cross-platform-architecture.md | 771 | 中 |
d:\Projects\CardMind\docs\03-technical\testing\system-testing-plan.md | 750 | 中 |
d:\Projects\CardMind\docs\03-technical\implementation-examples.md | 646 | 低 |
d:\Projects\CardMind\docs\03-technical\api\card-service-api.md | 516 | 低 |

## 3. 拆分策略

### 3.1 整体拆分原则

1. **按功能模块拆分**：将综合性文档按功能模块拆分为独立文档
2. **保持单一职责**：每个文档只关注一个特定主题
3. **建立清晰导航**：在主文档中保留导航链接，指向拆分后的子文档
4. **统一文档结构**：所有拆分后的文档采用一致的结构和格式
5. **控制文档大小**：单个文档尽量控制在500行以内

### 3.2 具体拆分方案

#### 3.2.1 api-testing-design.md (1743行)

该文档已经开始拆分，目前需要完成剩余部分的拆分：

- 已拆分：AuthService, DeviceService, CardService, EncryptionService, SyncService
- 剩余部分：集成测试、端到端测试、回归测试等

拆分计划：
1. 将集成测试拆分为独立文档：`integration-testing-plan.md`
2. 将端到端测试拆分为独立文档：`e2e-testing-plan.md`
3. 将回归测试拆分为独立文档：`regression-testing-plan.md`
4. 保留主文档作为导航和概述

#### 3.2.2 interaction-logic.md (1540行)

该文档包含所有UI组件的交互逻辑，需要按组件类型拆分：

拆分计划：
1. 拆分为组件特定的交互逻辑文档：
   - `card-list-interaction.md`
   - `card-editor-interaction.md`
   - `auth-interaction.md`
   - `settings-interaction.md`
   - `sync-test-tool-interaction.md`
2. 保留主文档作为导航和概述

#### 3.2.3 cross-platform-compatibility.md (1369行)

该文档包含跨平台兼容性的各个方面，需要按功能类型拆分：

拆分计划：
1. 拆分为以下子文档：
   - `network-compatibility.md`
   - `storage-compatibility.md`
   - `system-capabilities-compatibility.md`
   - `ui-compatibility.md`
2. 保留主文档作为导航和概述

#### 3.2.4 pure-p2p-architecture.md (1140行)

该文档包含P2P架构的各个方面，需要按功能类型拆分：

拆分计划：
1. 拆分为以下子文档：
   - `p2p-protocol-design.md`
   - `p2p-connection-management.md`
   - `p2p-data-synchronization.md`
   - `p2p-security.md`
2. 保留主文档作为导航和概述

#### 3.2.5 store-api文档 (card-store-api.md, sync-store-api.md等)

这些文档已经是拆分后的Store API文档，但仍然超过500行：

优化计划：
1. 进一步优化文档结构，简化内容
2. 考虑将接口定义和测试拆分为独立文档

## 4. 实施步骤

### 4.1 第一阶段：优先处理最大的文档 (高优先级)

1. 完成api-testing-design.md的剩余拆分
2. 开始拆分interaction-logic.md

### 4.2 第二阶段：处理中等大小的文档 (中优先级)

1. 拆分cross-platform-compatibility.md
2. 拆分pure-p2p-architecture.md
3. 拆分offline-lan-architecture.md
4. 拆分local-signaling-server.md
5. 优化card-store-api.md和sync-store-api.md

### 4.3 第三阶段：处理较小的文档 (低优先级)

1. 拆分implementation-examples.md
2. 优化card-service-api.md

## 5. 文档结构规范

所有拆分后的文档应遵循以下结构：

```
# 文档标题

## 1. 概述

## 2. 核心功能

## 3. 实现细节

## 4. 测试策略

## 5. 相关文档
```

## 6. 维护说明

1. 所有文档更新应保持同步
2. 主文档应始终包含最新的子文档链接
3. 新增功能应更新相应的文档结构
4. 定期检查文档大小，确保不超过500行限制

## 7. 完成标准

1. 所有文档行数不超过500行
2. 文档结构清晰，内容聚焦
3. 主文档提供完整的导航链接
4. 文档格式统一，符合项目规范

---

**创建日期**：2024年1月
**维护人**：文档重构团队