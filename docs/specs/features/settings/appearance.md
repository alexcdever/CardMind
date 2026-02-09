# 外观设置规格
- 相关文档:
  - [设置功能规格](README.md)
- 测试覆盖:
  - `test/feature/features/settings_feature_test.dart`
  - `test/unit/providers/theme_provider_unit_test.dart`

## 概述

本规格定义日/夜主题切换的业务规则。主题偏好属于本地设置，必须持久化并立即生效，不参与数据池同步。

## GIVEN-WHEN-THEN 场景

### 场景：切换日/夜主题

- **GIVEN** 当前主题模式为日间或夜间
- **WHEN** 用户切换主题模式
- **THEN** 系统立即应用新的主题模式
- **AND** 主题偏好持久化到本地设置
