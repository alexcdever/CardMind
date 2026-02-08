# 池设置规格

## 概述

定义池设置变更的业务规则：可更新名称与密钥；更新密钥需验证旧密钥；密钥以明文保存并使用 SHA-256 哈希进行校验；任何变更必须同步到池内所有设备。

---

## GIVEN-WHEN-THEN 场景

### 场景：更新池名称

- **GIVEN**: 设备已加入某个池且新名称非空
- **WHEN**: 请求更新池名称
- **THEN**: 系统更新池名称并持久化
- **并且**: 变更同步到所有设备

### 场景：更新池名称失败

- **GIVEN**: 新名称为空或仅包含空白字符
- **WHEN**: 请求更新池名称
- **THEN**: 系统拒绝并返回错误 `INVALID_NAME`

### 场景：更新池 secretkey 成功

- **GIVEN**: 设备已加入某个池且提供正确旧 secretkey
- **WHEN**: 请求设置新 secretkey
- **THEN**: 系统保存新 secretkey 明文到池元数据
- **并且**: 变更同步到所有设备

### 场景：旧 secretkey 验证失败

- **GIVEN**: 提供的旧 secretkey 错误
- **WHEN**: 请求更新池 secretkey
- **THEN**: 系统拒绝并返回错误 `INVALID_PASSWORD`
