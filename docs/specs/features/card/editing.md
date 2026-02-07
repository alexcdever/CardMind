# 卡片编辑业务规格

**状态**: 活跃
**依赖**: [../../domain/card.md](../../domain/card.md), [../../architecture/storage/dual_layer.md](../../architecture/storage/dual_layer.md), [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md), [../../architecture/storage/device_config.md](../../architecture/storage/device_config.md), [../../architecture/sync/service.md](../../architecture/sync/service.md)
**相关测试**: `test/feature/features/card_management_feature_test.dart`

---

## 概述

本规格定义卡片编辑的业务规则。编辑应更新标题与内容，并同步更新 `updated_at` 与 `last_edit_device`。任何成功的编辑变更都必须进入同步流程。

## GIVEN-WHEN-THEN 场景

### 场景：更新卡片标题与内容

- **GIVEN** 存在一张可编辑的卡片
- **WHEN** 调用方提交新的标题与内容
- **THEN** 系统应更新卡片标题与内容
- **AND** `updated_at` 应更新为当前时间戳
- **AND** `last_edit_device` 应更新为当前设备标识
- **AND** 变更应进入同步流程

### 场景：拒绝空标题保存

- **GIVEN** 调用方提交空标题或仅包含空白字符的编辑请求
- **WHEN** 系统验证标题
- **THEN** 系统应拒绝保存
- **AND** 卡片保持上一次已保存状态

### 场景：拒绝空内容保存

- **GIVEN** 调用方提交内容为空或仅包含空白字符的编辑请求
- **WHEN** 系统验证内容
- **THEN** 系统应拒绝保存
- **AND** 卡片保持上一次已保存状态
