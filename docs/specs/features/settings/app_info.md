# 应用信息规格
- 相关文档:
  - [设置功能规格](README.md)
- 测试覆盖:
  - `test/unit/providers/app_info_provider_unit_test.dart`
  - 暂无（Rust）

## 概述

本规格定义应用信息展示规则：展示本项目依赖库清单与开源协议。依赖清单按 Flutter 与 Rust 分组，包含全部直接依赖（含开发依赖）。

## GIVEN-WHEN-THEN 场景

### 场景：查看依赖库清单

- **GIVEN** 应用依赖清单可用
- **WHEN** 用户请求依赖库信息
- **THEN** 系统返回 Flutter 与 Rust 两类清单
- **AND** 清单包含运行时依赖与开发依赖

### 场景：查看开源协议

- **GIVEN** 项目开源协议文件可用
- **WHEN** 用户请求开源协议
- **THEN** 系统展示当前项目的开源协议全文
