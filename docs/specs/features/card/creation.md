# 卡片创建业务规格

**状态**: 活跃
**依赖**: [../../domain/card.md](../../domain/card.md), [../../domain/pool.md](../../domain/pool.md), [../../architecture/storage/dual_layer.md](../../architecture/storage/dual_layer.md), [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md), [../../architecture/sync/service.md](../../architecture/sync/service.md)
**相关测试**: `test/feature/features/card_management_feature_test.dart`

---

## 概述

本规格定义卡片创建的业务规则。创建时标题必填，内容必填且不可为空或仅空白字符，必须在已加入的池内创建。创建成功后应生成 UUID v7 标识符，初始化时间戳与最后编辑设备信息，并进入同步流程。

## GIVEN-WHEN-THEN 场景

### 场景：创建包含标题与内容的卡片

- **GIVEN** 调用方已加入某个池
- **WHEN** 调用方提交有效标题与非空内容的创建请求
- **THEN** 系统应创建卡片并分配 UUID v7 标识符
- **AND** 卡片应关联到当前池
- **AND** `created_at` 与 `updated_at` 设为当前时间戳
- **AND** `last_edit_device` 设为当前设备标识
- **AND** 创建事件应进入同步流程

### 场景：拒绝空标题创建

- **GIVEN** 调用方提交空标题或仅包含空白字符的创建请求
- **WHEN** 系统验证标题
- **THEN** 系统应拒绝创建
- **AND** 返回错误“标题为必填项”

### 场景：拒绝空内容创建

- **GIVEN** 调用方提交内容为空或仅包含空白字符的创建请求
- **WHEN** 系统验证内容
- **THEN** 系统应拒绝创建
- **AND** 返回错误“内容为必填项”

### 场景：未加入池时拒绝创建

- **GIVEN** 调用方未加入任何池
- **WHEN** 调用方提交创建请求
- **THEN** 系统应拒绝创建
- **AND** 返回错误代码 `NOT_JOINED_POOL`
