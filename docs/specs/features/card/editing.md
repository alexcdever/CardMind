# 卡片编辑业务规格
- 相关文档:
  - [卡片领域模型](../../domain/card.md)
  - [卡片存储](../../architecture/storage/card_store.md)
  - [池同步](../pool/sync.md)
- 测试覆盖:
  - `rust/tests/card_store_feature_test.rs`
  - `test/feature/specs/card_editor_spec_feature_test.dart`

## 概述

本规格定义卡片编辑的业务规则：编辑更新标题与内容，同时更新 `updated_at` 与 `last_edit_peer`；数据池卡片的变更进入同步流程，本地卡片仅本地生效。

## GIVEN-WHEN-THEN 场景

### 场景：编辑卡片并更新时间戳

- **GIVEN** 存在一张可编辑的卡片
- **WHEN** 提交新的标题与/或内容
- **THEN** 系统应更新卡片数据
- **AND** `updated_at` 更新为当前时间戳
- **AND** `last_edit_peer` 更新为当前节点 PeerId
- **AND** 若卡片归属数据池，则变更进入同步流程

### 场景：拒绝空标题或空内容保存

- **GIVEN** 标题为空或仅包含空白字符，或内容为空/仅空白
- **WHEN** 提交编辑请求
- **THEN** 系统应拒绝保存
- **AND** 卡片保持上一次已保存状态
