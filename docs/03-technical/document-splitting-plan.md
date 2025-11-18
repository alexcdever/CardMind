# CardMind文档拆分计划

## 1. 概述

本文档详细描述了对CardMind项目中超过500行的Markdown文档进行拆分重构的计划，目标是将所有文档控制在500行以内，提高文档的可读性和维护性。

## 2. 超过500行的文档列表

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

### 3.1 拆分原则

1. **按功能模块拆分**：将综合性文档按功能模块拆分为独立文档
2. **保持单一职责**：每个文档只关注一个特定主题
3. **建立清晰导航**：在主文档中保留导航链接，指向拆分后的子文档
4. **统一文档结构**：所有拆分后的文档采用一致的结构和格式
5. **控制文档大小**：单个文档尽量控制在500行以内

### 3.2 具体拆分方案

#### 3.2.1 api-testing-design.md (1743行)

该文档已经开始拆分，目前需要完成剩余部分的拆分：

- 已拆分：AuthService, DeviceService, CardService, EncryptionService, SyncService API
- 已拆分：authStore, deviceStore, cardStore, syncStore API
- 剩余部分：系统测试、回归测试、测试工具等

拆分计划：
1. 保留主文档作为导航和概述
2. 将系统测试拆分为独立文档：`testing/system-testing.md`
3. 将回归测试拆分为独立文档：`testing/regression-testing.md`
4. 将测试工具拆分为独立文档：`testing/testing-tools.md`

#### 3.2.2 interaction-logic.md (1540行)

该文档包含所有UI组件的交互逻辑，需要按组件类型拆分：

拆分计划：
1. 保留主文档作为导航和概述
2. 拆分为组件特定的交互逻辑文档：
   - `ui-interaction/card-list-interaction.md`
   - `ui-interaction/card-editor-interaction.md`
   - `ui-interaction/auth-interaction.md`
   - `ui-interaction/settings-interaction.md`
   - `ui-interaction/sync-test-tool-interaction.md`

#### 3.2.3 cross-platform-compatibility.md (1369行)

该文档包含跨平台兼容性的各个方面，需要按功能类型拆分：

拆分计划：
1. 保留主文档作为导航和概述
2. 拆分为以下子文档：
   - `cross-platform/network-compatibility.md`
   - `cross-platform/storage-compatibility.md`
   - `cross-platform/system-capabilities-compatibility.md`
   - `cross-platform/ui-compatibility.md`

#### 3.2.4 pure-p2p-architecture.md (1140行)

该文档包含P2P架构的各个方面，需要按功能类型拆分：

拆分计划：
1. 保留主文档作为导航和概述
2. 拆分为以下子文档：
   - `p2p/p2p-protocol-design.md`
   - `p2p/p2p-connection-management.md`
   - `p2p/p2p-data-synchronization.md`
   - `p2p/p2p-security.md`

#### 3.2.5 store-api文档 (sync-store-api.md, card-store-api.md)

这些文档已经是拆分后的Store API文档，但仍然超过500行，需要进一步优化：

优化计划：
1. 将接口定义和实现分开
2. 将测试部分拆分为独立文档
3. 简化示例代码，只保留核心部分

#### 3.2.6 其他文档

对于剩余的超过500行的文档，采用类似的拆分策略，按功能模块拆分为独立文档。

## 4. 实施步骤

### 4.1 第一阶段：高优先级文档 (1-2周)

1. 完成api-testing-design.md的剩余拆分
2. 完成interaction-logic.md的拆分

### 4.2 第二阶段：中优先级文档 (2-3周)

1. 完成cross-platform-compatibility.md的拆分
2. 完成pure-p2p-architecture.md的拆分
3. 完成sync-store-api.md和card-store-api.md的优化
4. 完成offline-lan-architecture.md的拆分
5. 完成local-signaling-server.md的拆分
6. 完成cross-platform-architecture.md的拆分
7. 完成system-testing-plan.md的拆分

### 4.3 第三阶段：低优先级文档 (1-2周)

1. 完成implementation-examples.md的拆分
2. 完成card-service-api.md的优化

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