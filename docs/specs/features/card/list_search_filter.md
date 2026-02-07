# 卡片列表与搜索过滤业务规格

**依赖**: [../../domain/card.md](../../domain/card.md), [../../architecture/storage/sqlite_cache.md](../../architecture/storage/sqlite_cache.md), [../../architecture/storage/dual_layer.md](../../architecture/storage/dual_layer.md)
**相关测试**: `test/feature/features/search_and_filter_feature_test.dart`

---

## 概述

本规格定义卡片列表、搜索与过滤的业务规则。系统应在无条件时返回未删除卡片全量，在有条件时叠加过滤并按默认排序返回。分页与增量加载不在本规格范围。

## GIVEN-WHEN-THEN 场景

### 场景：条件为空返回未删除全量

- **GIVEN** 卡片集合中存在已删除与未删除卡片
- **WHEN** 调用方提交空查询条件
- **THEN** 系统应仅返回 `deleted = false` 的卡片

### 场景：条件不为空叠加过滤

- **GIVEN** 调用方提供搜索关键词与标签条件
- **WHEN** 系统执行查询
- **THEN** 系统应仅返回同时满足所有条件的卡片

### 场景：默认排序为最近更新优先

- **GIVEN** 查询结果包含多张卡片
- **WHEN** 调用方未指定排序条件
- **THEN** 系统应按 `updated_at` 倒序返回（从新到旧）

### 场景：按标题或内容关键词搜索

- **GIVEN** 存在标题或内容包含关键词的卡片
- **WHEN** 调用方提供关键词查询
- **THEN** 系统应匹配标题或内容包含该关键词的卡片
- **AND** 关键词匹配应不区分大小写

### 场景：按标签过滤

- **GIVEN** 存在带有不同标签的卡片
- **WHEN** 调用方提供一个或多个标签作为条件
- **THEN** 系统应仅返回包含全部指定标签的卡片

### 场景：显式包含已删除卡片

- **GIVEN** 存在已删除卡片
- **WHEN** 调用方明确请求包含已删除卡片
- **THEN** 系统应在结果中包含已删除卡片
