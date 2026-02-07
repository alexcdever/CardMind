# 数据管理规格

**状态**: 生效中
**依赖**: [../../architecture/storage/dual_layer.md](../../architecture/storage/dual_layer.md), [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md), [../../architecture/storage/pool_store.md](../../architecture/storage/pool_store.md), [../../architecture/storage/sqlite_cache.md](../../architecture/storage/sqlite_cache.md)
**相关测试**: `test/feature/features/settings_feature_test.dart`

---

## 概述

本规格定义数据存储使用统计、缓存清理、数据导出与导入的业务规则。缓存清理仅影响临时缓存数据，不得删除用户内容；导出与导入使用 UTF-8 编码的 JSON 格式，并执行结构校验。

---

## GIVEN-WHEN-THEN 场景

### 场景：查看存储使用情况

- **GIVEN**: 本地存在卡片与缓存数据
- **WHEN**: 调用方请求存储使用统计
- **THEN**: 系统返回总占用与分类占用（卡片数据、缓存数据）

### 场景：清理缓存

- **GIVEN**: 存在可清理的缓存数据
- **WHEN**: 调用方提交清理缓存请求
- **THEN**: 系统清理缓存数据
- **AND**: 卡片与数据池等用户内容保持不变

### 场景：导出数据

- **GIVEN**: 本地存在数据池与卡片数据
- **WHEN**: 调用方发起导出请求
- **THEN**: 系统导出当前设备可访问的数据池与卡片数据
- **AND**: 导出格式为 UTF-8 编码的 JSON

### 场景：导入数据

- **GIVEN**: 提供有效的导入文件
- **WHEN**: 调用方发起导入请求
- **THEN**: 系统验证结构后导入数据池与卡片数据

### 场景：拒绝无效导入文件

- **GIVEN**: 导入文件格式不符合预期
- **WHEN**: 系统执行结构校验
- **THEN**: 系统拒绝导入
- **AND**: 返回错误“导入文件格式无效”
