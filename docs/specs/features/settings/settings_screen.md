# 设置屏幕规格

**版本**: 1.0.0

**状态**: 活跃

**依赖**: [../../architecture/storage/device_config.md](../../architecture/storage/device_config.md), [../../architecture/sync/service.md](../../architecture/sync/service.md)

**相关测试**: `flutter/test/features/settings/settings_screen_test.dart`

---

## 概述


本规格定义设置屏幕,提供按逻辑类别组织的全面应用程序配置和管理选项,确保:

- 清晰的设置分组
- 主题和显示自定义
- 设备管理访问
- 同步配置选项
- 数据管理功能
- 应用信息展示
- 法律文档访问

**适用平台**:
- iOS
- Android
- macOS
- Windows
- Linux

**技术栈**:
- Flutter Scaffold - 页面框架
- ListView - 列表展示
- Provider/Riverpod - 状态管理

---

## 需求:设置分组


系统应将设置组织到逻辑类别中以便于导航。

### 场景:显示设置部分

- **前置条件**:设置屏幕加载
- **操作**:渲染设置屏幕
- **预期结果**:系统应显示分组到以下部分的设置:外观、设备、同步、数据、关于

### 场景:部分标题清晰

- **前置条件**:设置屏幕已显示
- **操作**:查看设置列表
- **预期结果**:每个部分应有清晰的标题
- **并且**:部分之间应有视觉分隔

**实现逻辑**:

```
structure SettingsScreen:
    sections: List<SettingsSection>

    // 初始化设置部分
    function initSections():
        sections = [
            SettingsSection(
                title: "外观",
                items: [
                    SettingItem(type: THEME_TOGGLE),
                    SettingItem(type: TEXT_SIZE)
                ]
            ),
            SettingsSection(
                title: "设备",
                items: [
                    SettingItem(type: DEVICE_NAME),
                    SettingItem(type: DEVICE_MANAGER)
                ]
            ),
            SettingsSection(
                title: "同步",
                items: [
                    SettingItem(type: AUTO_SYNC),
                    SettingItem(type: SYNC_FREQUENCY),
                    SettingItem(type: SYNC_DETAILS)
                ]
            ),
            SettingsSection(
                title: "数据",
                items: [
                    SettingItem(type: STORAGE_INFO),
                    SettingItem(type: CLEAR_CACHE),
                    SettingItem(type: EXPORT_DATA),
                    SettingItem(type: IMPORT_DATA)
                ]
            ),
            SettingsSection(
                title: "关于",
                items: [
                    SettingItem(type: APP_VERSION),
                    SettingItem(type: LICENSES),
                    SettingItem(type: HELP_SUPPORT),
                    SettingItem(type: PRIVACY_POLICY),
                    SettingItem(type: TERMS_OF_SERVICE)
                ]
            )
        ]

    // 渲染设置屏幕
    function render():
        return Scaffold(
            appBar: AppBar(
                title: Text("设置")
            ),
            body: ListView(
                sections.map((section) => Column([
                    SectionHeader(section.title),
                    ...section.items.map((item) => renderSettingItem(item)),
                    Divider()
                ]))
            )
        )
```

---

## 需求:外观自定义


系统应提供主题和显示自定义选项。

### 场景:切换主题模式

- **前置条件**:用户在设置屏幕上
- **操作**:用户切换主题设置
- **预期结果**:系统应在浅色和深色模式之间切换
- **并且**:立即应用主题

### 场景:调整文本大小

- **前置条件**:用户在设置屏幕上
- **操作**:用户更改文本大小设置
- **预期结果**:系统应更新整个应用的文本大小
- **并且**:显示更改预览

**实现逻辑**:

```
structure AppearanceSettings:
    currentTheme: ThemeMode
    textSize: double

    // 切换主题
    function toggleTheme(newTheme):
        // 步骤1:更新主题模式
        currentTheme = newTheme

        // 步骤2:应用主题
        ThemeManager.setTheme(newTheme)

        // 步骤3:持久化设置
        deviceConfig.saveThemePreference(newTheme)

        // 步骤4:更新UI
        notifyListeners()

    // 调整文本大小
    function adjustTextSize(newSize):
        // 步骤1:验证范围
        if newSize < 12 or newSize > 24:
            return

        // 步骤2:更新文本大小
        textSize = newSize

        // 步骤3:应用到应用
        ThemeManager.setTextSize(newSize)

        // 步骤4:持久化设置
        deviceConfig.saveTextSize(newSize)

        // 步骤5:更新UI
        notifyListeners()

    // 渲染外观设置
    function renderAppearanceSettings():
        return Column([
            SwitchListTile(
                title: "深色模式",
                subtitle: "使用深色主题",
                value: currentTheme == ThemeMode.dark,
                onChanged: (enabled) => toggleTheme(
                    enabled ? ThemeMode.dark : ThemeMode.light
                )
            ),
            ListTile(
                title: "文本大小",
                subtitle: "当前: {textSize.toInt()}",
                trailing: Slider(
                    value: textSize,
                    min: 12,
                    max: 24,
                    onChanged: adjustTextSize
                )
            )
        ])
```

---

## 需求:设备管理导航


系统应提供到设备管理界面的导航。

### 场景:导航到设备管理器

- **前置条件**:用户在设置屏幕上
- **操作**:用户选择"管理设备"选项
- **预期结果**:系统应导航到设备管理屏幕

### 场景:显示当前设备信息

- **前置条件**:显示设备设置
- **操作**:查看设备部分
- **预期结果**:系统应显示当前设备名称和类型

**实现逻辑**:

```
structure DeviceSettings:
    currentDevice: Device

    // 渲染设备设置
    function renderDeviceSettings():
        return Column([
            ListTile(
                title: "当前设备",
                subtitle: "{currentDevice.name} ({currentDevice.type})",
                leading: Icon(getDeviceIcon(currentDevice.type))
            ),
            ListTile(
                title: "管理设备",
                subtitle: "查看和管理配对设备",
                trailing: Icon(Icons.chevron_right),
                onTap: navigateToDeviceManager
            )
        ])

    // 导航到设备管理器
    function navigateToDeviceManager():
        navigator.push(DeviceManagerScreen())

    // 获取设备图标
    function getDeviceIcon(deviceType):
        switch deviceType:
            case PHONE:
                return Icons.phone_android
            case TABLET:
                return Icons.tablet
            case LAPTOP:
                return Icons.laptop
            case DESKTOP:
                return Icons.computer
            default:
                return Icons.devices
```

---

## 需求:同步配置


系统应提供同步配置选项。

### 场景:切换自动同步

- **前置条件**:用户在设置屏幕上
- **操作**:用户切换自动同步
- **预期结果**:系统应启用或禁用自动同步

### 场景:修改同步设置

- **前置条件**:用户在设置屏幕上
- **操作**:用户修改同步设置
- **预期结果**:系统应允许配置同步频率、网络偏好等

### 场景:导航到同步详情

- **前置条件**:用户在设置屏幕上
- **操作**:用户选择"同步详情"选项
- **预期结果**:系统应导航到同步屏幕

**实现逻辑**:

```
structure SyncSettings:
    autoSyncEnabled: bool
    syncFrequency: Duration

    // 渲染同步设置
    function renderSyncSettings():
        return Column([
            SwitchListTile(
                title: "自动同步",
                subtitle: "检测到更改时自动同步",
                value: autoSyncEnabled,
                onChanged: toggleAutoSync
            ),
            if autoSyncEnabled:
                ListTile(
                    title: "同步频率",
                    subtitle: formatFrequency(syncFrequency),
                    onTap: showFrequencyPicker
                ),
            ListTile(
                title: "同步详情",
                subtitle: "查看同步状态和历史",
                trailing: Icon(Icons.chevron_right),
                onTap: navigateToSyncScreen
            )
        ])

    // 切换自动同步
    function toggleAutoSync(enabled):
        autoSyncEnabled = enabled
        syncService.setAutoSync(enabled)
        deviceConfig.saveSyncSettings(autoSyncEnabled, syncFrequency)

    // 导航到同步屏幕
    function navigateToSyncScreen():
        navigator.push(SyncScreen())
```

---

## 需求:数据管理


系统应提供管理应用程序数据的选项。

### 场景:查看存储使用情况

- **前置条件**:显示数据设置
- **操作**:查看存储信息
- **预期结果**:系统应显示应用使用的总存储空间
- **并且**:按类别细分(卡片、附件、缓存)

### 场景:清除缓存

- **前置条件**:用户在设置屏幕上
- **操作**:用户选择"清除缓存"
- **预期结果**:系统应显示确认对话框
- **并且**:确认后清除缓存数据

### 场景:导出数据

- **前置条件**:用户在设置屏幕上
- **操作**:用户选择"导出数据"
- **预期结果**:系统应启动数据导出流程
- **并且**:将导出的数据保存到用户选择的位置

### 场景:导入数据

- **前置条件**:用户在设置屏幕上
- **操作**:用户选择"导入数据"
- **预期结果**:系统应打开文件选择器
- **并且**:从选定文件导入数据

**实现逻辑**:

```
structure DataManagement:
    storageInfo: StorageInfo

    // 渲染数据管理设置
    function renderDataSettings():
        return Column([
            ListTile(
                title: "存储使用情况",
                subtitle: "总计: {formatBytes(storageInfo.totalBytes)}",
                onTap: showStorageDetails
            ),
            ListTile(
                title: "清除缓存",
                subtitle: "清除临时数据",
                onTap: clearCache
            ),
            ListTile(
                title: "导出数据",
                subtitle: "导出所有笔记",
                onTap: exportData
            ),
            ListTile(
                title: "导入数据",
                subtitle: "从文件导入",
                onTap: importData
            )
        ])

    // 显示存储详情
    function showStorageDetails():
        showDialog(StorageDetailsDialog(
            cards: storageInfo.cardsBytes,
            cache: storageInfo.cacheBytes,
            attachments: storageInfo.attachmentsBytes
        ))

    // 清除缓存
    function clearCache():
        confirmed = showConfirmDialog(
            title: "清除缓存",
            message: "确定要清除缓存吗?这不会删除您的笔记。"
        )

        if confirmed:
            cacheManager.clearCache()
            showToast("缓存已清除")
            refreshStorageInfo()

    // 导出数据
    function exportData():
        path = showFilePicker(
            title: "选择导出位置",
            defaultName: "cardmind_export_{currentDate()}.json"
        )

        if path:
            dataExporter.export(path)
            showToast("数据已导出到 {path}")

    // 导入数据
    function importData():
        path = showFilePicker(
            title: "选择导入文件",
            fileTypes: ["json"]
        )

        if path:
            result = dataImporter.import(path)
            if result.success:
                showToast("数据导入成功")
            else:
                showToast("导入失败: {result.error}")
```

---

## 需求:应用信息和法律


系统应显示应用程序和法律信息。

### 场景:查看应用版本

- **前置条件**:查看关于部分
- **操作**:查看应用信息
- **预期结果**:系统应显示应用版本、构建号和发布日期

### 场景:查看开源许可证

- **前置条件**:用户在设置屏幕上
- **操作**:用户选择"开源许可证"
- **预期结果**:系统应显示第三方许可证

### 场景:访问帮助和支持

- **前置条件**:用户需要帮助
- **操作**:用户选择"帮助与支持"
- **预期结果**:系统应打开支持文档或联系表单

### 场景:查看隐私政策

- **前置条件**:用户在设置屏幕上
- **操作**:用户选择"隐私政策"
- **预期结果**:系统应打开隐私政策文档

### 场景:查看服务条款

- **前置条件**:用户在设置屏幕上
- **操作**:用户选择"服务条款"
- **预期结果**:系统应打开服务条款文档

**实现逻辑**:

```
structure AboutAndLegal:
    appInfo: AppInfo

    // 渲染关于和法律设置
    function renderAboutSettings():
        return Column([
            ListTile(
                title: "版本",
                subtitle: "版本 {appInfo.version} ({appInfo.buildNumber})"
            ),
            ListTile(
                title: "开源许可证",
                trailing: Icon(Icons.chevron_right),
                onTap: showLicenses
            ),
            ListTile(
                title: "帮助与支持",
                trailing: Icon(Icons.open_in_new),
                onTap: openSupport
            ),
            Divider(),
            ListTile(
                title: "隐私政策",
                trailing: Icon(Icons.open_in_new),
                onTap: () => openUrl("https://cardmind.app/privacy")
            ),
            ListTile(
                title: "服务条款",
                trailing: Icon(Icons.open_in_new),
                onTap: () => openUrl("https://cardmind.app/terms")
            )
        ])

    // 显示许可证
    function showLicenses():
        showLicensePage(
            context: context,
            applicationName: appInfo.name,
            applicationVersion: appInfo.version
        )

    // 打开支持
    function openSupport():
        openUrl("https://cardmind.app/support")

    // 打开URL
    function openUrl(url):
        launchUrl(url, mode: LaunchMode.externalApplication)
```

---

## 需求:反馈和评分


系统应允许用户提供反馈并为应用评分。

### 场景:发送反馈

- **前置条件**:用户在设置屏幕上
- **操作**:用户选择"发送反馈"
- **预期结果**:系统应打开反馈表单或电子邮件客户端

### 场景:为应用评分

- **前置条件**:用户在设置屏幕上
- **操作**:用户选择"为应用评分"
- **预期结果**:系统应打开应用商店评分页面

**实现逻辑**:

```
structure FeedbackAndRating:
    // 渲染反馈设置
    function renderFeedbackSettings():
        return Column([
            ListTile(
                title: "发送反馈",
                subtitle: "帮助我们改进",
                trailing: Icon(Icons.feedback),
                onTap: sendFeedback
            ),
            ListTile(
                title: "为应用评分",
                subtitle: "在应用商店评分",
                trailing: Icon(Icons.star),
                onTap: rateApp
            )
        ])

    // 发送反馈
    function sendFeedback():
        // 步骤1:收集设备信息
        deviceInfo = collectDeviceInfo()

        // 步骤2:打开邮件客户端
        emailUrl = "mailto:support@cardmind.app?subject=Feedback&body={deviceInfo}"
        launchUrl(emailUrl)

    // 为应用评分
    function rateApp():
        // 步骤1:获取应用商店URL
        storeUrl = getAppStoreUrl()

        // 步骤2:打开应用商店
        launchUrl(storeUrl, mode: LaunchMode.externalApplication)

    // 获取应用商店URL
    function getAppStoreUrl():
        if Platform.isIOS:
            return "https://apps.apple.com/app/cardmind/id123456789"
        else if Platform.isAndroid:
            return "https://play.google.com/store/apps/details?id=com.cardmind.app"
        else:
            return "https://cardmind.app"
```

---

## 测试覆盖


**测试文件**: `flutter/test/features/settings/settings_screen_test.dart`

**单元测试**:
- `test_show_settings_sections()` - 显示设置部分
- `test_section_headers_clear()` - 部分标题清晰
- `test_toggle_theme_mode()` - 切换主题模式
- `test_adjust_text_size()` - 调整文本大小
- `test_navigate_to_device_manager()` - 导航到设备管理器
- `test_show_current_device_info()` - 显示当前设备信息
- `test_configure_auto_sync()` - 配置自动同步
- `test_set_sync_preferences()` - 设置同步偏好
- `test_navigate_to_sync_details()` - 导航到同步详情
- `test_view_storage_usage()` - 查看存储使用情况
- `test_clear_cache()` - 清除缓存
- `test_export_data()` - 导出数据
- `test_import_data()` - 导入数据
- `test_show_app_version()` - 显示应用版本
- `test_show_licenses()` - 显示许可证
- `test_access_support()` - 访问支持
- `test_view_privacy_policy()` - 查看隐私政策
- `test_view_terms_of_service()` - 查看服务条款
- `test_send_feedback()` - 发送反馈
- `test_rate_app()` - 评分应用

**集成测试**:
- `test_complete_settings_workflow()` - 完整设置流程
- `test_theme_switching_workflow()` - 主题切换流程
- `test_data_management_workflow()` - 数据管理流程

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 所有集成测试通过
- [ ] 设置逻辑组织清晰
- [ ] 所有配置选项正常工作
- [ ] 导航流程直观
- [ ] 主题切换立即生效
- [ ] 数据管理操作可靠
- [ ] 代码审查通过
- [ ] 文档已更新

---

## 相关文档


**相关规格**:
- [../../architecture/storage/device_config.md](../../architecture/storage/device_config.md) - 设备配置
- [../../architecture/sync/service.md](../../architecture/sync/service.md) - 同步服务
- [device_manager_panel.md](device_manager_panel.md) - 设备管理器
- [settings_panel.md](settings_panel.md) - 设置面板
- [../sync/sync_screen.md](../sync/sync_screen.md) - 同步屏幕

**架构决策记录**:
- 无

---

**最后更新**: 2026-02-02
**作者**: CardMind Team
