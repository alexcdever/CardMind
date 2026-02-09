# 卡片列表与搜索过滤业务规格
- 相关文档:
  - [卡片功能总览](README.md)
  - [卡片领域模型](../../domain/card.md)
- 测试覆盖:
  - `rust/tests/sqlite_cache_feature_test.rs`
  - `test/feature/features/search_and_filter_feature_test.dart`

## 概述

本规格定义卡片列表、搜索与过滤的业务规则。默认仅返回未删除卡片，关键词搜索匹配标题或内容。分页与增量加载不在本规格范围。

## GIVEN-WHEN-THEN 场景

### 场景：空条件返回未删除卡片

- **GIVEN** 卡片集合中存在已删除与未删除卡片
- **WHEN** 调用方提交空查询条件
- **THEN** 系统应仅返回 `deleted = false` 的卡片

### 场景：关键词搜索匹配标题或内容

- **GIVEN** 存在标题或内容包含关键词的卡片
- **WHEN** 调用方提供关键词查询
- **THEN** 系统应匹配标题或内容包含该关键词的卡片
- **AND** 关键词匹配应不区分大小写

### 场景：默认排序为最近更新优先

- **GIVEN** 查询结果包含多张卡片
- **WHEN** 调用方未指定排序条件
- **THEN** 系统应按 `updated_at` 倒序返回（从新到旧）

### 场景：显式包含已删除卡片

- **GIVEN** 存在已删除卡片
- **WHEN** 调用方明确请求包含已删除卡片
- **THEN** 系统应在结果中包含已删除卡片
