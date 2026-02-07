# 设备设置规格

**依赖**: [../../domain/pool.md](../../domain/pool.md), [../../architecture/storage/device_config.md](../../architecture/storage/device_config.md), [../../architecture/sync/service.md](../../architecture/sync/service.md)
**相关测试**: `test/feature/features/settings_feature_test.dart`

---

## 概述

本规格定义设备信息查看与设备名称管理的业务规则。设备名称必填且需裁剪前后空白，更新后必须持久化；当设备已加入数据池时，设备信息变更需进入同步流程。

---

## GIVEN-WHEN-THEN 场景

### 场景：查看设备信息

- **GIVEN**: 已存在设备配置
- **WHEN**: 调用方请求设备信息
- **THEN**: 系统返回设备标识、设备名称、设备类型与平台信息
- **AND**: 系统返回设备创建时间戳

### 场景：更新设备名称

- **GIVEN**: 提供的设备名称包含至少一个非空白字符
- **WHEN**: 调用方提交名称更新请求
- **THEN**: 系统裁剪前后空白并更新设备名称
- **AND**: 更新结果持久化到设备配置存储
- **AND**: 若设备已加入数据池，设备信息变更进入同步流程

### 场景：拒绝空设备名称

- **GIVEN**: 提供的设备名称为空或仅包含空白字符
- **WHEN**: 调用方提交名称更新请求
- **THEN**: 系统拒绝更新
- **AND**: 返回错误“设备名称为必填项”
