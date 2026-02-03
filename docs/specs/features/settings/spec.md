# 设置功能规格

**状态**: 活跃
**依赖**: [../../architecture/storage/device_config.md](../../architecture/storage/device_config.md), [../../domain/pool/model.md](../../domain/pool/model.md)
**相关测试**: `test/features/settings_test.dart`

---

## 概述

本规格定义设置功能，使用户能够配置应用程序偏好、管理设备设置、控制同步行为并访问应用程序信息，覆盖设备名称管理、外观自定义、同步配置、数据管理以及隐私和法律文档访问。

**适用平台**:
- iOS
- Android
- macOS
- Windows
- Linux

**技术栈**:
- Flutter - UI框架
- SharedPreferences - 本地存储
- Provider/Riverpod - 状态管理

**业务规则**:
- 设备名称不应为空或仅包含空格，前导和尾随空格需裁剪。
- 用户偏好(主题、文本大小、同步设置)应本地持久化，不应同步到其他设备。
- 缓存清除仅删除临时缓存数据，不应删除用户内容(卡片、池)。
- 数据导出使用 UTF-8 编码的 JSON 格式。
- 导入数据需校验结构，拒绝不符合预期模式的文件。
- 主题更改应立即应用，无需重启应用程序。

---

## 需求：设备名称管理

用户应能够查看和修改当前设备名称。

### 场景：查看当前设备名称

- **前置条件**: 设备有已配置的名称
- **操作**: 用户打开设备设置
- **预期结果**: 系统应显示当前设备名称
- **并且**: 系统应显示设备 ID
- **并且**: 系统应显示设备类型(手机、平板、笔记本)

### 场景：更新设备名称

- **前置条件**: 用户正在查看设备设置
- **操作**: 用户将设备名称更改为"My Work Phone"
- **并且**: 用户保存更改
- **预期结果**: 系统应在设备配置中更新设备名称
- **并且**: 系统应将更改持久化到存储
- **并且**: 更改应同步到池中的其他设备
- **并且**: 系统应显示确认消息"设备名称已更新"

### 场景：拒绝空设备名称

- **前置条件**: 用户正在编辑设备名称
- **操作**: 用户提供空名称或仅包含空格的名称
- **预期结果**: 系统应拒绝更改
- **并且**: 系统应显示错误消息"设备名称不能为空"

### 场景：查看设备信息

- **前置条件**: 用户正在查看设备设置
- **操作**: 用户访问设备信息
- **预期结果**: 系统应显示设备 ID(UUID v7 格式)
- **并且**: 系统应显示设备类型
- **并且**: 系统应显示平台信息(iOS、Android 等)
- **并且**: 系统应显示设备创建时间戳

**实现逻辑**:

```
structure DeviceNameManagement:
    currentDevice: Device

    // 查看设备信息
    function viewDeviceInfo():
        return DeviceInfo(
            name: currentDevice.name,
            id: currentDevice.id,
            type: currentDevice.type,
            platform: currentDevice.platform,
            createdAt: currentDevice.createdAt
        )

    // 更新设备名称
    function updateDeviceName(newName):
        // 步骤1:验证名称
        trimmedName = newName.trim()
        if trimmedName.isEmpty():
            showError("设备名称不能为空")
            return false

        // 步骤2:更新设备配置
        currentDevice.name = trimmedName

        // 步骤3:持久化到存储
        deviceConfig.save(currentDevice)

        // 步骤4:同步到其他设备
        syncService.syncDeviceInfo(currentDevice)

        // 步骤5:显示确认
        showToast("设备名称已更新")
        return true
```

---

## 需求：外观自定义

用户应能够自定义应用程序的视觉外观。

### 场景：切换主题模式

- **前置条件**: 应用程序处于浅色模式
- **操作**: 用户将主题设置切换为深色模式
- **预期结果**: 系统应立即应用深色主题
- **并且**: 系统应持久化主题偏好
- **并且**: 主题应应用于所有屏幕

### 场景：调整文本大小

- **前置条件**: 用户正在查看外观设置
- **操作**: 用户将文本大小更改为"大"
- **预期结果**: 系统应更新整个应用程序的文本大小
- **并且**: 系统应显示更改预览
- **并且**: 系统应持久化文本大小偏好

### 场景：使用系统主题偏好

- **前置条件**: 用户正在查看主题设置
- **操作**: 用户选择"跟随系统"选项
- **预期结果**: 系统应检测并应用系统主题
- **并且**: 系统应在系统偏好更改时更新主题

**实现逻辑**:

```
structure AppearanceCustomization:
    currentTheme: ThemeMode
    textSize: TextSize

    // 切换主题模式
    function toggleTheme(newTheme):
        // 步骤1:更新主题
        currentTheme = newTheme

        // 步骤2:立即应用
        ThemeManager.applyTheme(newTheme)

        // 步骤3:持久化偏好
        preferences.setTheme(newTheme)

        // 步骤4:通知所有屏幕
        notifyThemeChanged()

    // 调整文本大小
    function adjustTextSize(newSize):
        // 步骤1:更新文本大小
        textSize = newSize

        // 步骤2:应用到应用
        ThemeManager.setTextSize(newSize)

        // 步骤3:显示预览
        showPreview(newSize)

        // 步骤4:持久化偏好
        preferences.setTextSize(newSize)

    // 使用系统主题
    function useSystemTheme():
        // 步骤1:检测系统主题
        systemTheme = PlatformDispatcher.instance.platformBrightness

        // 步骤2:应用系统主题
        toggleTheme(systemTheme == Brightness.dark ? ThemeMode.dark : ThemeMode.light)

        // 步骤3:监听系统主题变化
        PlatformDispatcher.instance.onPlatformBrightnessChanged = () => {
            useSystemTheme()
        }
```

---

## 需求：同步配置

用户应能够配置同步行为和偏好。

### 场景：启用自动同步

- **前置条件**: 自动同步当前已禁用
- **操作**: 用户启用自动同步
- **预期结果**: 系统应启用自动同步
- **并且**: 系统应持久化偏好
- **并且**: 如果连接到对等设备，系统应立即开始同步

### 场景：禁用自动同步

- **前置条件**: 自动同步当前已启用
- **操作**: 用户禁用自动同步
- **预期结果**: 系统应停止自动同步
- **并且**: 系统应持久化偏好
- **并且**: 用户应仍能够触发手动同步

### 场景：配置同步频率

- **前置条件**: 自动同步已启用
- **操作**: 用户将同步频率设置为"每5分钟"
- **预期结果**: 系统应更新同步间隔
- **并且**: 系统应持久化偏好
- **并且**: 系统应按配置的间隔同步

### 场景：配置网络偏好

- **前置条件**: 用户正在查看同步设置
- **操作**: 用户启用"仅在 Wi-Fi 上同步"
- **预期结果**: 系统应将同步限制为 Wi-Fi 连接
- **并且**: 系统应在使用蜂窝网络时暂停同步
- **并且**: 系统应在 Wi-Fi 可用时恢复同步

### 场景：导航到同步详情

- **前置条件**: 用户正在查看同步设置
- **操作**: 用户选择"查看同步详情"
- **预期结果**: 系统应导航到同步屏幕
- **并且**: 同步屏幕应显示详细的同步状态和历史

**实现逻辑**:

```
structure SyncConfiguration:
    autoSyncEnabled: bool
    syncFrequency: Duration
    wifiOnlyEnabled: bool

    // 启用自动同步
    function enableAutoSync():
        // 步骤1:启用自动同步
        autoSyncEnabled = true

        // 步骤2:持久化偏好
        preferences.setAutoSync(true)

        // 步骤3:如果有对等设备,立即同步
        if syncService.hasConnectedPeers():
            syncService.syncNow()

    // 禁用自动同步
    function disableAutoSync():
        // 步骤1:禁用自动同步
        autoSyncEnabled = false

        // 步骤2:停止自动同步
        syncService.stopAutoSync()

        // 步骤3:持久化偏好
        preferences.setAutoSync(false)

    // 配置同步频率
    function configureSyncFrequency(frequency):
        // 步骤1:更新频率
        syncFrequency = frequency

        // 步骤2:持久化偏好
        preferences.setSyncFrequency(frequency)

        // 步骤3:重新配置同步服务
        syncService.setSyncInterval(frequency)

    // 配置网络偏好
    function configureNetworkPreference(wifiOnly):
        // 步骤1:更新偏好
        wifiOnlyEnabled = wifiOnly

        // 步骤2:持久化偏好
        preferences.setWifiOnly(wifiOnly)

        // 步骤3:检查当前网络
        if wifiOnly and not isWifiConnected():
            syncService.pauseSync()
        else:
            syncService.resumeSync()
```

---

## 需求：数据管理

用户应能够管理应用程序数据，包括缓存、导出和导入。

### 场景：查看存储使用情况

- **前置条件**: 用户正在查看数据设置
- **操作**: 用户访问存储信息
- **预期结果**: 系统应显示应用程序使用的总存储空间
- **并且**: 系统应按类别细分存储(卡片、缓存、附件)
- **并且**: 系统应以人类可读格式显示存储(MB、GB)

### 场景：清除缓存

- **前置条件**: 应用程序有缓存数据
- **操作**: 用户选择"清除缓存"
- **预期结果**: 系统应显示确认对话框"清除所有缓存数据?"
- **并且**: 如果用户确认，系统应删除所有缓存数据
- **并且**: 系统应保留用户数据(卡片、池)
- **并且**: 系统应显示确认消息"缓存已清除"

### 场景：导出所有数据

- **前置条件**: 设备已加入包含卡片的池
- **操作**: 用户选择"导出数据"
- **预期结果**: 系统应生成包含所有卡片和池数据的导出文件
- **并且**: 系统应将导出格式化为 JSON
- **并且**: 系统应打开文件选择器供用户选择保存位置
- **并且**: 系统应显示确认消息"数据导出成功"

### 场景：导入数据

- **前置条件**: 用户有导出文件
- **操作**: 用户选择"导入数据"
- **预期结果**: 系统应打开文件选择器
- **并且**: 系统应验证选定的文件格式
- **并且**: 如果有效，系统应导入卡片和池数据
- **并且**: 系统应显示确认消息"数据导入成功"

### 场景：拒绝无效的导入文件

- **前置条件**: 用户正在导入数据
- **操作**: 用户选择格式无效的文件
- **预期结果**: 系统应拒绝导入
- **并且**: 系统应显示错误消息"文件格式无效"

**实现逻辑**:

```
structure DataManagement:
    storageInfo: StorageInfo

    // 查看存储使用情况
    function viewStorageUsage():
        // 步骤1:计算各类别存储
        cardsSize = calculateCardsStorage()
        cacheSize = calculateCacheStorage()
        attachmentsSize = calculateAttachmentsStorage()

        // 步骤2:返回存储信息
        return StorageInfo(
            total: cardsSize + cacheSize + attachmentsSize,
            cards: cardsSize,
            cache: cacheSize,
            attachments: attachmentsSize
        )

    // 清除缓存
    function clearCache():
        // 步骤1:显示确认对话框
        confirmed = showConfirmDialog(
            title: "清除缓存",
            message: "清除所有缓存数据?"
        )

        if not confirmed:
            return

        // 步骤2:删除缓存数据
        cacheManager.clearAll()

        // 步骤3:保留用户数据
        // (卡片和池数据不受影响)

        // 步骤4:显示确认
        showToast("缓存已清除")

    // 导出所有数据
    function exportAllData():
        // 步骤1:收集所有数据
        cards = cardStore.getAllCards()
        pools = poolStore.getAllPools()

        // 步骤2:格式化为JSON
        exportData = {
            version: "1.0",
            exportedAt: now(),
            cards: cards,
            pools: pools
        }
        jsonData = JSON.stringify(exportData, indent: 2)

        // 步骤3:打开文件选择器
        path = showFilePicker(
            title: "选择保存位置",
            defaultName: "cardmind_export_{currentDate()}.json"
        )

        if not path:
            return

        // 步骤4:保存文件
        File(path).writeAsString(jsonData, encoding: utf8)

        // 步骤5:显示确认
        showToast("数据导出成功")

    // 导入数据
    function importData():
        // 步骤1:打开文件选择器
        path = showFilePicker(
            title: "选择导入文件",
            fileTypes: ["json"]
        )

        if not path:
            return

        // 步骤2:读取文件
        jsonData = File(path).readAsString(encoding: utf8)

        // 步骤3:验证格式
        try:
            importData = JSON.parse(jsonData)

            if not importData.version or not importData.cards:
                showError("文件格式无效")
                return
        catch error:
            showError("文件格式无效")
            return

        // 步骤4:导入数据
        for card in importData.cards:
            cardStore.importCard(card)

        for pool in importData.pools:
            poolStore.importPool(pool)

        // 步骤5:显示确认
        showToast("数据导入成功")
```

---

## 需求：应用程序信息

用户应能够访问应用程序版本、构建信息和支持资源。

### 场景：查看应用程序版本

- **前置条件**: 用户正在查看关于部分
- **操作**: 用户访问应用程序信息
- **预期结果**: 系统应显示应用程序版本号
- **并且**: 系统应显示构建号
- **并且**: 系统应显示发布日期

### 场景：查看开源许可证

- **前置条件**: 用户正在查看关于部分
- **操作**: 用户选择"开源许可证"
- **预期结果**: 系统应显示所有第三方库许可证
- **并且**: 系统应按库名称分组许可证

### 场景：访问帮助和支持

- **前置条件**: 用户需要帮助
- **操作**: 用户选择"帮助与支持"
- **预期结果**: 系统应打开支持文档或联系表单
- **并且**: 系统应提供报告问题的选项

### 场景：发送反馈

- **前置条件**: 用户想要提供反馈
- **操作**: 用户选择"发送反馈"
- **预期结果**: 系统应打开反馈表单或电子邮件客户端
- **并且**: 系统应预填充设备和应用信息

### 场景：为应用评分

- **前置条件**: 用户想要为应用评分
- **操作**: 用户选择"为应用评分"
- **预期结果**: 系统应打开应用商店评分页面

**实现逻辑**:

```
structure ApplicationInfo:
    appInfo: PackageInfo

    // 查看应用版本
    function viewAppVersion():
        return AppVersion(
            version: appInfo.version,
            buildNumber: appInfo.buildNumber,
            releaseDate: appInfo.buildDate
        )

    // 查看开源许可证
    function viewLicenses():
        showLicensePage(
            context: context,
            applicationName: appInfo.appName,
            applicationVersion: appInfo.version
        )

    // 访问帮助和支持
    function accessSupport():
        openUrl("https://cardmind.app/support")

    // 发送反馈
    function sendFeedback():
        // 步骤1:收集设备信息
        deviceInfo = {
            device: currentDevice.name,
            platform: Platform.operatingSystem,
            version: appInfo.version
        }

        // 步骤2:打开邮件客户端
        emailUrl = "mailto:support@cardmind.app?subject=Feedback&body={deviceInfo}"
        launchUrl(emailUrl)

    // 为应用评分
    function rateApp():
        // 步骤1:获取应用商店URL
        storeUrl = getAppStoreUrl()

        // 步骤2:打开应用商店
        launchUrl(storeUrl, mode: LaunchMode.externalApplication)
```

---

## 需求：隐私和法律访问

用户应能够访问隐私政策和法律文档。

### 场景：查看隐私政策

- **前置条件**: 用户正在查看法律部分
- **操作**: 用户选择"隐私政策"
- **预期结果**: 系统应打开隐私政策文档
- **并且**: 文档应以用户的首选语言显示

### 场景：查看服务条款

- **前置条件**: 用户正在查看法律部分
- **操作**: 用户选择"服务条款"
- **预期结果**: 系统应打开服务条款文档
- **并且**: 文档应以用户的首选语言显示

**实现逻辑**:

```
structure PrivacyAndLegal:
    userLocale: Locale

    // 查看隐私政策
    function viewPrivacyPolicy():
        // 步骤1:获取用户语言
        language = userLocale.languageCode

        // 步骤2:构建URL
        url = "https://cardmind.app/privacy?lang={language}"

        // 步骤3:打开文档
        launchUrl(url, mode: LaunchMode.externalApplication)

    // 查看服务条款
    function viewTermsOfService():
        // 步骤1:获取用户语言
        language = userLocale.languageCode

        // 步骤2:构建URL
        url = "https://cardmind.app/terms?lang={language}"

        // 步骤3:打开文档
        launchUrl(url, mode: LaunchMode.externalApplication)
```

---

## 需求：设置组织

系统应将设置组织到逻辑部分以便于导航。

### 场景：显示设置部分

- **前置条件**: 用户打开设置屏幕
- **操作**: 设置屏幕加载
- **预期结果**: 系统应显示分组到部分的设置
- **并且**: 部分应包括:外观、设备、同步、数据、关于、法律
- **并且**: 每个部分应有清晰的标题

### 场景：在设置部分之间导航

- **前置条件**: 用户正在查看设置
- **操作**: 用户点击某个部分
- **预期结果**: 系统应展开或导航到该部分
- **并且**: 系统应在返回时保持滚动位置

**实现逻辑**:

```
structure SettingsOrganization:
    sections: List<SettingsSection>
    scrollPosition: double = 0

    // 初始化设置部分
    function initSections():
        sections = [
            SettingsSection(
                title: "外观",
                icon: Icons.palette,
                items: [appearanceSettings]
            ),
            SettingsSection(
                title: "设备",
                icon: Icons.devices,
                items: [deviceSettings]
            ),
            SettingsSection(
                title: "同步",
                icon: Icons.sync,
                items: [syncSettings]
            ),
            SettingsSection(
                title: "数据",
                icon: Icons.storage,
                items: [dataSettings]
            ),
            SettingsSection(
                title: "关于",
                icon: Icons.info,
                items: [aboutSettings]
            ),
            SettingsSection(
                title: "法律",
                icon: Icons.gavel,
                items: [legalSettings]
            )
        ]

    // 导航到部分
    function navigateToSection(section):
        // 步骤1:保存当前滚动位置
        scrollPosition = getCurrentScrollPosition()

        // 步骤2:导航到部分
        navigator.push(SectionDetailScreen(section))

    // 恢复滚动位置
    function restoreScrollPosition():
        scrollController.jumpTo(scrollPosition)
```

---

## 测试覆盖

**测试文件**: `test/features/settings_test.dart`

**单元测试**:
- `test_view_current_device_name()` - 查看设备名称
- `test_update_device_name()` - 更新设备名称
- `test_reject_empty_device_name()` - 拒绝空名称
- `test_view_device_information()` - 查看设备信息
- `test_toggle_theme_mode()` - 切换主题
- `test_adjust_text_size()` - 调整文本大小
- `test_use_system_theme()` - 使用系统主题
- `test_enable_auto_sync()` - 启用自动同步
- `test_disable_auto_sync()` - 禁用自动同步
- `test_configure_sync_frequency()` - 配置同步频率
- `test_configure_network_preferences()` - 配置网络偏好
- `test_navigate_to_sync_details()` - 导航到同步详情
- `test_view_storage_usage()` - 查看存储使用情况
- `test_clear_cache()` - 清除缓存
- `test_export_all_data()` - 导出数据
- `test_import_data()` - 导入数据
- `test_reject_invalid_import()` - 拒绝无效导入
- `test_view_app_version()` - 查看应用版本
- `test_view_licenses()` - 查看许可证
- `test_access_support()` - 访问支持
- `test_send_feedback()` - 发送反馈
- `test_rate_app()` - 为应用评分
- `test_view_privacy_policy()` - 查看隐私政策
- `test_view_terms_of_service()` - 查看服务条款
- `test_display_settings_sections()` - 显示部分
- `test_navigate_between_sections()` - 在部分之间导航

**集成测试**:
- `test_complete_settings_workflow()` - 完整设置流程
- `test_data_export_import_workflow()` - 数据导出导入流程

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 所有集成测试通过
- [ ] 设备名称管理正常工作
- [ ] 主题和外观设置立即应用
- [ ] 同步配置功能正常
- [ ] 数据管理操作可靠工作
- [ ] 导出和导入保持数据完整性
- [ ] 设置逻辑组织良好
- [ ] 代码审查通过
- [ ] 文档已更新
