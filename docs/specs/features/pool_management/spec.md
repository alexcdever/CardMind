# 池管理功能规格

**状态**: 活跃
**依赖**: [../../domain/pool.md](../../domain/pool.md), [../../architecture/storage/pool_store.md](../../architecture/storage/pool_store.md), [../../architecture/storage/device_config.md](../../architecture/storage/device_config.md)
**相关测试**: `test/features/pool_management_test.dart`

---

## 概述

本规格定义了池管理功能，使用户能够创建池、加入现有池、管理池设置和离开池。该功能强制执行单池约束，即每个设备一次最多只能加入一个池，设备上创建的所有卡片自动属于已加入的池。

**核心用户旅程**:
- 创建包含名称和密码的新池
- 使用池 ID 和密码加入现有池
- 查看当前池信息和设置
- 更新池名称和密码
- 离开池并清除所有本地数据
- 查看池中的设备

---

## 需求：池创建

用户应能够创建包含名称和密码的新池。

### 场景：使用名称和密码创建池

- **前置条件**: 设备未加入任何池
- **操作**: 用户创建名称为"Family Notes"、密码为"secure123"的新池
- **预期结果**: 系统应使用 UUID v7 标识符创建池
- **并且**: 池名称应设置为"Family Notes"
- **并且**: 密码应使用 bcrypt 哈希并存储
- **并且**: 设备应自动加入池
- **并且**: 使用正确密码加入的所有设备应可见该池

### 场景：拒绝创建空名称的池

- **前置条件**: 用户尝试创建池
- **操作**: 用户提供空名称或仅包含空格的名称
- **预期结果**: 系统应拒绝创建
- **并且**: 系统应显示错误消息"池名称为必填项"

### 场景：拒绝创建弱密码的池

- **前置条件**: 用户尝试创建池
- **操作**: 用户提供少于6个字符的密码
- **预期结果**: 系统应拒绝创建
- **并且**: 系统应显示错误消息"密码必须至少6个字符"

### 场景：已加入池时拒绝创建池

- **前置条件**: 设备已加入一个池
- **操作**: 用户尝试创建新池
- **预期结果**: 系统应以错误"ALREADY_JOINED_POOL"拒绝创建
- **并且**: 系统应提示用户先离开当前池

**实现逻辑**:

```
structure PoolManagement:
    currentPool: Pool?
    deviceConfig: DeviceConfig

    // 创建新池
    function createPool(name, password):
        // 步骤1：检查是否已加入池
        if currentPool != null:
            return error("ALREADY_JOINED_POOL", "请先离开当前池")

        // 步骤2：验证池名称
        if name.trim().isEmpty():
            return error("INVALID_NAME", "池名称为必填项")

        // 步骤3：验证密码强度
        if password.length < 6:
            return error("WEAK_PASSWORD", "密码必须至少6个字符")

        // 步骤4：生成池 ID
        poolId = generateUUIDv7()

        // 步骤5：哈希密码
        passwordHash = bcrypt.hash(password, cost=12)

        // 步骤6：创建池
        pool = Pool(
            id: poolId,
            name: name,
            passwordHash: passwordHash,
            createdAt: currentTime(),
            devices: [deviceConfig.deviceId]
        )

        // 步骤7：保存池
        poolStore.save(pool)

        // 步骤8：设备加入池
        deviceConfig.joinPool(poolId)

        // 步骤9：更新当前池
        currentPool = pool

        return ok(pool)
```

---

## 需求：池加入

用户应能够使用池 ID 和密码加入现有池。

### 场景：使用有效凭据加入池

- **前置条件**: 存在 ID 为"pool-123"、密码为"secure123"的池
- **并且**: 设备未加入任何池
- **操作**: 用户使用 ID"pool-123"和密码"secure123"加入池
- **预期结果**: 系统应根据存储的哈希验证密码
- **并且**: 设备应添加到池的设备列表
- **并且**: 设备配置应使用池 ID 更新
- **并且**: 系统应开始同步池数据

### 场景：拒绝使用无效密码加入

- **前置条件**: 存在 ID 为"pool-123"、密码为"secure123"的池
- **操作**: 用户尝试使用密码"wrong-password"加入
- **预期结果**: 系统应拒绝加入请求
- **并且**: 系统应显示错误消息"密码无效"
- **并且**: 设备不应添加到池

### 场景：拒绝使用不存在的池 ID 加入

- **前置条件**: 用户尝试加入池
- **操作**: 用户提供不存在的池 ID
- **预期结果**: 系统应拒绝加入请求
- **并且**: 系统应显示错误消息"未找到池"
- **并且**: 设备不应添加到池

### 场景：已加入池时拒绝加入

- **前置条件**: 设备已加入一个池
- **操作**: 用户尝试加入另一个池
- **预期结果**: 系统应以错误"ALREADY_JOINED_POOL"拒绝加入
- **并且**: 系统应提示用户先离开当前池

**实现逻辑**:

```
structure PoolJoining:
    currentPool: Pool?
    deviceConfig: DeviceConfig

    // 加入现有池
    function joinPool(poolId, password):
        // 步骤1：检查是否已加入池
        if currentPool != null:
            return error("ALREADY_JOINED_POOL", "请先离开当前池")

        // 步骤2：查找池
        pool = poolStore.getPool(poolId)
        if pool == null:
            return error("POOL_NOT_FOUND", "未找到池")

        // 步骤3：验证密码
        if not bcrypt.verify(password, pool.passwordHash):
            return error("INVALID_PASSWORD", "密码无效")

        // 步骤4：添加设备到池
        pool.devices.add(deviceConfig.deviceId)
        poolStore.save(pool)

        // 步骤5：设备加入池
        deviceConfig.joinPool(poolId)

        // 步骤6：更新当前池
        currentPool = pool

        // 步骤7：开始同步
        syncService.startSync(poolId)

        return ok(pool)
```

---

## 需求：池查看

用户应能够查看当前池的信息。

### 场景：查看池信息

- **前置条件**: 设备已加入池
- **操作**: 用户打开池信息视图
- **预期结果**: 系统应显示池 ID
- **并且**: 系统应显示池名称
- **并且**: 系统应显示池中的设备数量

### 场景：查看池设备

- **前置条件**: 设备已加入池
- **操作**: 用户查看池中的设备
- **预期结果**: 系统应显示所有已加入设备的列表
- **并且**: 系统应指示当前设备
- **并且**: 系统应显示每个设备的名称和类型

**实现逻辑**:

```
structure PoolViewing:
    currentPool: Pool
    deviceConfig: DeviceConfig

    // 查看池信息
    function viewPoolInfo():
        return {
            poolId: currentPool.id,
            poolName: currentPool.name,
            deviceCount: currentPool.devices.length,
            createdAt: currentPool.createdAt
        }

    // 查看池设备
    function viewPoolDevices():
        devices = []

        for deviceId in currentPool.devices:
            device = deviceStore.getDevice(deviceId)
            devices.add({
                deviceId: deviceId,
                deviceName: device.name,
                deviceType: device.type,
                isCurrent: deviceId == deviceConfig.deviceId
            })

        return devices
```

---

## 需求：池设置

用户应能够管理池设置。

### 场景：更新池名称

- **前置条件**: 设备已加入池
- **操作**: 用户将池名称更新为"New Name"
- **预期结果**: 系统应更新池名称
- **并且**: 更改应同步到所有设备

### 场景：更新池密码

- **前置条件**: 设备已加入池
- **操作**: 用户更新池密码
- **预期结果**: 系统应使用新密码哈希更新
- **并且**: 更改应同步到所有设备
- **并且**: 现有设备应保持加入

**实现逻辑**:

```
structure PoolSettings:
    currentPool: Pool

    // 更新池名称
    function updatePoolName(newName):
        // 步骤1：验证名称
        if newName.trim().isEmpty():
            return error("INVALID_NAME", "池名称为必填项")

        // 步骤2：更新池名称
        currentPool.name = newName
        poolStore.save(currentPool)

        // 步骤3：同步到所有设备
        syncService.syncPoolUpdate(currentPool)

        return ok()

    // 更新池密码
    function updatePoolPassword(newPassword):
        // 步骤1：验证密码强度
        if newPassword.length < 6:
            return error("WEAK_PASSWORD", "密码必须至少6个字符")

        // 步骤2：哈希新密码
        newPasswordHash = bcrypt.hash(newPassword, cost=12)

        // 步骤3：更新池密码
        currentPool.passwordHash = newPasswordHash
        poolStore.save(currentPool)

        // 步骤4：同步到所有设备
        syncService.syncPoolUpdate(currentPool)

        return ok()
```

---

## 需求：离开池

用户应能够离开池并清除本地数据。

### 场景：离开池

- **前置条件**: 设备已加入池
- **操作**: 用户选择离开池并确认
- **预期结果**: 系统应从池的设备列表中移除设备
- **并且**: 系统应清除本地池数据
- **并且**: 系统应清除所有本地卡片数据
- **并且**: 设备应导航到引导流程

### 场景：取消离开池

- **前置条件**: 用户触发离开池操作
- **操作**: 用户在确认对话框中点击"取消"
- **预期结果**: 系统应保持设备在池中
- **并且**: 所有数据应保持不变

**实现逻辑**:

```
structure PoolLeaving:
    currentPool: Pool
    deviceConfig: DeviceConfig

    // 离开池
    function leavePool():
        // 步骤1：显示确认对话框
        confirmed = showConfirmDialog(
            title: "离开池",
            message: "确定要离开池吗？所有本地数据将被清除。",
            confirmText: "离开",
            cancelText: "取消"
        )

        if not confirmed:
            return cancelled()

        // 步骤2：从池的设备列表中移除设备
        currentPool.devices.remove(deviceConfig.deviceId)
        poolStore.save(currentPool)

        // 步骤3：通知其他设备
        syncService.notifyDeviceLeft(currentPool.id, deviceConfig.deviceId)

        // 步骤4：清除本地池数据
        poolStore.delete(currentPool.id)

        // 步骤5：清除所有本地卡片数据
        cardStore.deleteAll()

        // 步骤6：清除设备配置
        deviceConfig.leavePool()

        // 步骤7：更新当前池
        currentPool = null

        // 步骤8：导航到引导流程
        navigateTo(OnboardingScreen())

        return ok()
```

---

## 测试覆盖

**测试文件**: `test/features/pool_management_test.dart`

**单元测试**:
- `test_create_pool_with_name_and_password()` - 使用名称和密码创建池
- `test_reject_pool_with_empty_name()` - 拒绝空名称的池
- `test_reject_pool_with_weak_password()` - 拒绝弱密码的池
- `test_reject_create_when_already_joined()` - 已加入时拒绝创建
- `test_join_pool_with_valid_credentials()` - 使用有效凭据加入池
- `test_reject_join_with_invalid_password()` - 拒绝无效密码加入
- `test_reject_join_with_nonexistent_pool()` - 拒绝不存在的池加入
- `test_reject_join_when_already_joined()` - 已加入时拒绝加入
- `test_view_pool_information()` - 查看池信息
- `test_view_pool_devices()` - 查看池设备
- `test_update_pool_name()` - 更新池名称
- `test_update_pool_password()` - 更新池密码
- `test_leave_pool()` - 离开池
- `test_cancel_leave_pool()` - 取消离开池

**集成测试**:
- `test_pool_creation_syncs_to_all_devices()` - 池创建同步到所有设备
- `test_pool_join_syncs_to_all_devices()` - 池加入同步到所有设备
- `test_pool_settings_sync_to_all_devices()` - 池设置同步到所有设备
- `test_leave_pool_notifies_all_devices()` - 离开池通知所有设备

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 所有集成测试通过
- [ ] 池创建在所有平台上正常工作
- [ ] 池加入在所有平台上正常工作
- [ ] 池设置在在所有平台上正常工作
- [ ] 离开池在所有平台上正常工作
- [ ] 密码安全存储（bcrypt 哈希）
- [ ] 代码审查通过
- [ ] 文档已更新

---

## 相关文档


- [Pool Model](../../domain/pool.md) - 池模型
- [Pool Store](../../architecture/storage/pool_store.md) - 池存储
- [Device Config](../../architecture/storage/device_config.md) - 设备配置
- [Sync Service](../../architecture/sync/service.md) - 同步服务

---

**最后更新**: 2026-01-23
**作者**: CardMind Team
