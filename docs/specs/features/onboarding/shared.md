# 引导流程规格（共享）

**状态**: 活跃
**依赖**: [../../architecture/storage/device_config.md](../../architecture/storage/device_config.md), [../../domain/pool.md](../../domain/pool.md)
**相关测试**: `flutter/test/features/onboarding/shared_onboarding_test.dart`

---

## 概述

本规格定义 CardMind 应用初始化流程规范，覆盖首次启动检测、欢迎引导、加入/创建池及同步初始化。

**核心目标**:
- 首次用户获得适当指导
- 与 DeviceConfig 的 join_pool 机制无缝集成
- 正确初始化本地存储和同步服务
- 跨平台一致的初始化体验

**适用平台**:
- Android
- iOS
- iPadOS
- macOS
- Windows
- Linux

**技术栈**:
- Flutter Navigator - 页面导航
- Provider/Riverpod - 状态管理
- flutter_rust_bridge - 数据桥接

---

## 需求：应用应检测首次启动

应用应检测首次启动。

### 场景：首次启动显示欢迎屏幕

- **前置条件**: 用户首次打开应用
- **操作**: 应用启动
- **预期结果**: 欢迎页应显示
- **并且**: 设备配置不应存在

### 场景：后续启动显示主屏幕

- **前置条件**: 用户已完成引导
- **操作**: 应用启动
- **预期结果**: 主屏幕应显示
- **并且**: 设备配置应存在

**实现逻辑**:

```
structure OnboardingFlow:
    isFirstLaunch: bool

    // 检测首次启动
    function checkFirstLaunch():
        // 步骤1：检查设备配置是否存在
        deviceConfig = deviceConfigStore.getConfig()

        // 步骤2：判断是否首次启动
        if deviceConfig == null:
            isFirstLaunch = true
            showWelcomeScreen()
        else:
            isFirstLaunch = false
            showHomeScreen()

    // 显示欢迎屏幕
    function showWelcomeScreen():
        navigateTo(WelcomeScreen())

    // 显示主屏幕
    function showHomeScreen():
        navigateTo(HomeScreen())
```

---

## 需求：欢迎屏幕应介绍应用

欢迎页应介绍应用。

### 场景：欢迎屏幕显示应用名称

- **前置条件**: 欢迎页已显示
- **操作**: 查看屏幕
- **预期结果**: 应用名称 "CardMind" 应显示
- **并且**: 应用描述应显示

### 场景：开始使用按钮可用

- **前置条件**: 欢迎页已显示
- **操作**: 查看屏幕
- **预期结果**: "开始使用"按钮应可见
- **并且**: 按钮应启用

**实现逻辑**:

```
structure WelcomeScreen:
    // 渲染欢迎屏幕
    function render():
        return Screen(
            title: "欢迎使用 CardMind",
            description: "一个简单、安全的笔记应用，支持多设备同步",
            content: [
                AppLogo(),
                AppDescription(),
                Button(
                    text: "开始使用",
                    onPressed: showActionSelection
                )
            ]
        )

    // 显示操作选择
    function showActionSelection():
        navigateTo(ActionSelectionScreen())
```

---

## 需求：用户应创建或加入池

用户应创建或加入池。

### 场景：用户可以创建新池

- **前置条件**: 用户点击"开始使用"
- **操作**: 操作选择屏幕出现
- **预期结果**: "创建新池"选项应可用
- **并且**: 点击选项应显示池创建表单

### 场景：池创建需要名称

- **前置条件**: 池创建表单已显示
- **操作**: 用户输入池名称
- **预期结果**: 名称应验证
- **并且**: 空名称应被拒绝

### 场景：池创建成功

- **前置条件**: 用户输入有效的池名称
- **操作**: 用户确认创建
- **预期结果**: 池应被创建
- **并且**: 设备应加入池
- **并且**: 应用应导航到主屏幕

**实现逻辑**:

```
structure PoolCreation:
    poolName: String
    password: String

    // 创建新池
    function createPool():
        // 步骤1：验证池名称
        if poolName.trim().isEmpty():
            showError("池名称不能为空")
            return

        // 步骤2：验证密码
        if password.length < 8:
            showError("密码至少需要 8 位字符")
            return

        // 步骤3：创建池
        pool = poolStore.createPool(
            name: poolName,
            password: password
        )

        // 步骤4：设备加入池
        deviceConfig = deviceConfigStore.joinPool(
            poolId: pool.id,
            password: password
        )

        // 步骤5：初始化存储
        initializeStorage()

        // 步骤6：配置同步
        configureSyncService(pool.id)

        // 步骤7：导航到主屏幕
        navigateTo(HomeScreen())

    // 显示池创建表单
    function showPoolCreationForm():
        return Form(
            fields: [
                TextField(
                    label: "池名称",
                    value: poolName,
                    onChanged: (value) => poolName = value
                ),
                PasswordField(
                    label: "密码",
                    value: password,
                    onChanged: (value) => password = value
                )
            ],
            actions: [
                Button("取消", onCancel),
                Button("创建", createPool)
            ]
        )
```

---

## 需求：用户应能够加入现有池

用户应能够加入现有池。

### 场景：用户可以加入池

- **前置条件**: 用户点击"开始使用"
- **操作**: 操作选择屏幕出现
- **预期结果**: "加入现有池"选项应可用
- **并且**: 点击选项应显示池加入表单

### 场景：池加入需要池 ID

- **前置条件**: 池加入表单已显示
- **操作**: 用户输入池 ID
- **预期结果**: ID 应验证
- **并且**: 空 ID 应被拒绝

### 场景：池加入成功

- **前置条件**: 用户输入有效的池 ID
- **操作**: 用户确认加入
- **预期结果**: 设备应加入池
- **并且**: 应用应导航到主屏幕

**实现逻辑**:

```
structure PoolJoining:
    poolId: String
    password: String

    // 加入现有池
    function joinPool():
        // 步骤1：验证池 ID
        if poolId.trim().isEmpty():
            showError("池 ID 不能为空")
            return

        // 步骤2：验证密码
        if password.isEmpty():
            showError("密码不能为空")
            return

        // 步骤3：验证池是否存在
        pool = poolStore.getPool(poolId)
        if pool == null:
            showError("池不存在")
            return

        // 步骤4：验证密码
        if not verifyPassword(password, pool.passwordHash):
            showError("密码错误")
            return

        // 步骤5：设备加入池
        deviceConfig = deviceConfigStore.joinPool(
            poolId: poolId,
            password: password
        )

        // 步骤6：初始化存储
        initializeStorage()

        // 步骤7：配置同步
        configureSyncService(poolId)

        // 步骤8：导航到主屏幕
        navigateTo(HomeScreen())

    // 显示池加入表单
    function showPoolJoiningForm():
        return Form(
            fields: [
                TextField(
                    label: "池 ID",
                    value: poolId,
                    onChanged: (value) => poolId = value
                ),
                PasswordField(
                    label: "密码",
                    value: password,
                    onChanged: (value) => password = value
                )
            ],
            actions: [
                Button("取消", onCancel),
                Button("加入", joinPool)
            ]
        )
```

---

## 需求：引导应初始化存储

引导应初始化本地存储。

### 场景：创建池时初始化存储

- **前置条件**: 用户创建新池
- **操作**: 池创建成功
- **预期结果**: 本地存储应初始化
- **并且**: 数据库表应创建

### 场景：加入池时初始化存储

- **前置条件**: 用户加入现有池
- **操作**: 池加入成功
- **预期结果**: 本地存储应初始化
- **并且**: 数据库表应创建

**实现逻辑**:

```
structure StorageInitialization:
    // 初始化存储
    function initializeStorage():
        // 步骤1：创建数据库
        database = createDatabase()

        // 步骤2：创建表
        database.execute("""
            CREATE TABLE IF NOT EXISTS cards (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            )
        """)

        database.execute("""
            CREATE TABLE IF NOT EXISTS pools (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                password_hash TEXT NOT NULL,
                created_at INTEGER NOT NULL
            )
        """)

        // 步骤3：初始化 Loro 文档
        loroDoc = createLoroDocument()

        // 步骤4：保存初始状态
        saveLoroDocument(loroDoc)
```

---

## 需求：引导应配置同步

引导应配置同步服务。

### 场景：创建池时配置同步

- **前置条件**: 用户创建新池
- **操作**: 池创建成功
- **预期结果**: 同步服务应配置
- **并且**: 设备应开始监听连接

### 场景：加入池时配置同步

- **前置条件**: 用户加入现有池
- **操作**: 池加入成功
- **预期结果**: 同步服务应配置
- **并且**: 设备应开始发现对等点

**实现逻辑**:

```
structure SyncConfiguration:
    // 配置同步服务
    function configureSyncService(poolId):
        // 步骤1：初始化同步服务
        syncService = SyncService.initialize(poolId)

        // 步骤2：启动 mDNS 发现
        syncService.startDiscovery()

        // 步骤3：监听连接
        syncService.listenForConnections()

        // 步骤4：订阅同步事件
        syncService.onSyncEvent((event) => {
            handleSyncEvent(event)
        })

    // 处理同步事件
    function handleSyncEvent(event):
        if event.type == "peer_discovered":
            showToast("发现新设备: {event.deviceName}")
        else if event.type == "sync_started":
            showToast("开始同步...")
        else if event.type == "sync_completed":
            showToast("同步完成")
```

---

## 相关文档

**相关规格**:
- [../../architecture/storage/device_config.md](../../architecture/storage/device_config.md) - 设备配置
- [../../domain/pool.md](../../domain/pool.md) - 数据池领域模型
- [../../architecture/storage/pool_store.md](../../architecture/storage/pool_store.md) - 数据池存储
- [../../architecture/sync/service.md](../../architecture/sync/service.md) - 同步服务

---

## 测试覆盖

**测试文件**: `flutter/test/features/onboarding/shared_onboarding_test.dart`

**单元测试**:
- `test_check_first_launch()` - 测试首次启动检测
- `test_show_welcome_screen()` - 测试显示欢迎屏幕
- `test_show_home_screen()` - 测试显示主屏幕
- `test_create_pool()` - 测试创建池
- `test_create_pool_validation()` - 测试池创建验证
- `test_join_pool()` - 测试加入池
- `test_join_pool_validation()` - 测试池加入验证
- `test_initialize_storage()` - 测试初始化存储
- `test_configure_sync()` - 测试配置同步

**功能测试**:
- `test_onboarding_create_pool_workflow()` - 测试创建池完整流程
- `test_onboarding_join_pool_workflow()` - 测试加入池完整流程

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 首次启动检测正确
- [ ] 池创建流程正常
- [ ] 池加入流程正常
- [ ] 存储初始化成功
- [ ] 同步配置正确
- [ ] 代码审查通过
- [ ] 文档已更新
