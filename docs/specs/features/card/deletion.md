# 卡片删除业务规格

**依赖**: [../../domain/card.md](../../domain/card.md), [../../architecture/storage/dual_layer.md](../../architecture/storage/dual_layer.md), [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md), [../../architecture/sync/service.md](../../architecture/sync/service.md)
**相关测试**: `test/feature/features/card_management_feature_test.dart`

---

## 概述

本规格定义卡片删除的业务规则。删除必须在确认后执行，采用软删除方式保留数据；已删除卡片在显式查询条件下仍可被检索，并且删除变更必须同步。

## GIVEN-WHEN-THEN 场景

### 场景：确认后软删除

- **GIVEN** 卡片存在且未被删除
- **WHEN** 调用方提交带有删除确认标记的删除请求
- **THEN** 系统应将卡片标记为 `deleted = true`
- **AND** `updated_at` 应更新为当前时间戳
- **AND** 删除变更应进入同步流程

### 场景：未确认则不删除

- **GIVEN** 卡片存在且未被删除
- **WHEN** 调用方提交未包含确认标记的删除请求
- **THEN** 系统不应更改卡片状态

### 场景：查询已删除卡片

- **GIVEN** 卡片已被软删除
- **WHEN** 调用方以显式条件请求包含已删除卡片
- **THEN** 系统应返回该已删除卡片
