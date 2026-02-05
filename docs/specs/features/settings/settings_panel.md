# 设置面板规格

**状态**: 活跃
**依赖**: [../../architecture/storage/device_config.md](../../architecture/storage/device_config.md), [../../architecture/sync/service.md](../../architecture/sync/service.md)
**相关测试**: `flutter/test/features/settings/settings_panel_test.dart`

---

## 概述

本规格定义设置面板组件，显示和管理按逻辑部分组织的应用程序设置，确保设置分组清晰、主题可自定义、同步配置可管理、数据管理可用，并展示应用信息。

**适用平台**:
- iOS
- Android
- macOS
- Windows
- Linux

**技术栈**:
- Flutter ListView - 设置列表
- Switch/Toggle - 开关控件
- Provider/Riverpod - 状态管理

---

## 需求：主题自定义

系统应提供主题自定义选项。

### 场景：显示当前主题模式

- **前置条件**: 设置面板已打开
- **操作**: 显示设置面板
- **预期结果**: 系统应显示当前主题模式(浅色/深色)
- **并且**: 显示切换或开关控件
- **并且**: 控件状态应反映当前主题

### 场景：切换主题

- **前置条件**: 设置面板已打开
- **操作**: 用户切换主题开关
- **预期结果**: 系统应使用新主题偏好调用 onThemeChanged 回调
- **并且**: 立即应用主题更改
- **并且**: 更改应持久化

**实现逻辑**:

```
structure ThemeSettings:
    currentTheme: ThemeMode

    // 渲染主题设置
    function renderThemeSettings():
        return SettingsSection(
            title: "外观",
            items: [
                SettingsItem(
                    title: "深色模式",
                    subtitle: "使用深色主题",
                    trailing: Switch(
                        value: currentTheme == ThemeMode.dark,
                        onChanged: toggleTheme
                    )
                )
            ]
        )

    // 切换主题
    function toggleTheme(enabled):
        // 步骤1:更新主题模式
        newTheme = enabled ? ThemeMode.dark : ThemeMode.light

        // 步骤2:调用回调
        onThemeChanged(newTheme)

        // 步骤3:持久化设置
        deviceConfig.saveThemePreference(newTheme)

        // 步骤4:更新UI
        currentTheme = newTheme
```

---

## 需求：同步设置

系统应显示与同步相关的配置选项。

### 场景：显示自动同步设置

- **前置条件**: 设置面板已打开
- **操作**: 显示同步设置
- **预期结果**: 系统应显示自动同步启用/禁用切换
- **并且**: 显示当前状态

### 场景：显示同步频率选项

- **前置条件**: 自动同步已启用
- **操作**: 查看同步设置
- **预期结果**: 系统应显示同步频率选项(立即、每5分钟等)
- **并且**: 显示当前选中的频率

**实现逻辑**:

```
structure SyncSettings:
    autoSyncEnabled: bool
    syncFrequency: Duration

    // 渲染同步设置
    function renderSyncSettings():
        return SettingsSection(
            title: "同步",
            items: [
                SettingsItem(
                    title: "自动同步",
                    subtitle: "检测到更改时自动同步",
                    trailing: Switch(
                        value: autoSyncEnabled,
                        onChanged: toggleAutoSync
                    )
                ),
                if autoSyncEnabled:
                    SettingsItem(
                        title: "同步频率",
                        subtitle: formatFrequency(syncFrequency),
                        onTap: showFrequencyPicker
                    )
            ]
        )

    // 切换自动同步
    function toggleAutoSync(enabled):
        autoSyncEnabled = enabled
        onAutoSyncChanged(enabled)
        deviceConfig.saveSyncSettings(autoSyncEnabled, syncFrequency)

    // 显示频率选择器
    function showFrequencyPicker():
        showDialog(FrequencyPickerDialog(
            current: syncFrequency,
            options: [
                Duration(seconds: 0),    // 立即
                Duration(minutes: 5),
                Duration(minutes: 15),
                Duration(minutes: 30),
                Duration(hours: 1)
            ],
            onSelected: (frequency) => {
                syncFrequency = frequency
                onSyncFrequencyChanged(frequency)
                deviceConfig.saveSyncSettings(autoSyncEnabled, syncFrequency)
            }
        ))
```

---

## 需求：应用信息

系统应显示应用程序版本和构建信息。

### 场景：显示应用版本

- **前置条件**: 设置面板已打开
- **操作**: 显示关于部分
- **预期结果**: 系统应从包信息中显示应用程序版本号
- **并且**: 显示格式为"版本 X.Y.Z"

### 场景：显示应用名称和描述

- **前置条件**: 设置面板已打开
- **操作**: 显示关于部分
- **预期结果**: 系统应显示应用程序名称
- **并且**: 显示应用的简要描述

**实现逻辑**:

```
structure AppInfo:
    appName: String
    appVersion: String
    appDescription: String

    // 渲染应用信息
    function renderAppInfo():
        return SettingsSection(
            title: "关于",
            items: [
                SettingsItem(
                    title: appName,
                    subtitle: appDescription
                ),
                SettingsItem(
                    title: "版本",
                    subtitle: "版本 {appVersion}"
                )
            ]
        )

    // 加载应用信息
    function loadAppInfo():
        packageInfo = PackageInfo.fromPlatform()
        appName = packageInfo.appName
        appVersion = packageInfo.version
        appDescription = "离线优先的卡片笔记应用"
```

---

## 需求：设备管理

系统应链接到设备管理界面。

### 场景：导航到设备管理

- **前置条件**: 设置面板已打开
- **操作**: 用户点击"管理设备"选项
- **预期结果**: 系统应导航到设备管理屏幕
- **并且**: 显示当前设备和配对设备

**实现逻辑**:

```
structure DeviceManagement:
    // 渲染设备管理设置
    function renderDeviceSettings():
        return SettingsSection(
            title: "设备",
            items: [
                SettingsItem(
                    title: "管理设备",
                    subtitle: "查看和管理配对设备",
                    trailing: Icon(Icons.chevron_right),
                    onTap: navigateToDeviceManager
                )
            ]
        )

    // 导航到设备管理器
    function navigateToDeviceManager():
        navigator.push(DeviceManagerScreen())
```

---

## 需求：数据管理

系统应提供管理应用程序数据的选项。

### 场景：清除缓存

- **前置条件**: 设置面板已打开
- **操作**: 用户选择"清除缓存"选项
- **预期结果**: 系统应显示确认对话框
- **并且**: 确认后清除缓存数据
- **并且**: 显示成功消息

### 场景：导出数据

- **前置条件**: 设置面板已打开
- **操作**: 用户选择"导出数据"选项
- **预期结果**: 系统应启动数据导出流程
- **并且**: 允许用户保存导出的数据文件

**实现逻辑**:

```
structure DataManagement:
    // 渲染数据管理设置
    function renderDataSettings():
        return SettingsSection(
            title: "数据",
            items: [
                SettingsItem(
                    title: "清除缓存",
                    subtitle: "清除临时数据",
                    onTap: clearCache
                ),
                SettingsItem(
                    title: "导出数据",
                    subtitle: "导出所有笔记",
                    onTap: exportData
                )
            ]
        )

    // 清除缓存
    function clearCache():
        confirmed = showConfirmDialog(
            title: "清除缓存",
            message: "确定要清除缓存吗？这不会删除您的笔记。"
        )

        if confirmed:
            cacheManager.clearCache()
            showToast("缓存已清除")

    // 导出数据
    function exportData():
        // 步骤1:选择导出位置
        path = showFilePicker(
            title: "选择导出位置",
            defaultName: "cardmind_export_{currentDate()}.json"
        )

        if not path:
            return

        // 步骤2:导出数据
        dataExporter.export(path)

        // 步骤3:显示成功消息
        showToast("数据已导出到 {path}")
```

---

## 需求：法律文档

系统应提供访问法律文档和隐私政策的途径。

### 场景：查看隐私政策

- **前置条件**: 设置面板已打开
- **操作**: 用户选择"隐私政策"选项
- **预期结果**: 系统应打开隐私政策文档
- **并且**: 在浏览器或应用内查看器中显示

### 场景：查看服务条款

- **前置条件**: 设置面板已打开
- **操作**: 用户选择"服务条款"选项
- **预期结果**: 系统应打开服务条款文档

**实现逻辑**:

```
structure LegalDocuments:
    // 渲染法律文档设置
    function renderLegalSettings():
        return SettingsSection(
            title: "法律",
            items: [
                SettingsItem(
                    title: "隐私政策",
                    trailing: Icon(Icons.open_in_new),
                    onTap: () => openUrl("https://cardmind.app/privacy")
                ),
                SettingsItem(
                    title: "服务条款",
                    trailing: Icon(Icons.open_in_new),
                    onTap: () => openUrl("https://cardmind.app/terms")
                )
            ]
        )

    // 打开URL
    function openUrl(url):
        launchUrl(url, mode: LaunchMode.externalApplication)
```

---

## 需求：设置分组

系统应将相关设置分组到逻辑部分。

### 场景：显示分组设置

- **前置条件**: 设置面板已打开
- **操作**: 渲染设置面板
- **预期结果**: 系统应将设置分组到部分标题下:外观、同步、数据、关于、法律
- **并且**: 每个部分应有清晰的标题
- **并且**: 部分之间应有视觉分隔

**实现逻辑**:

```
structure SettingsPanel:
    // 渲染完整设置面板
    function render():
        return ListView([
            renderThemeSettings(),
            Divider(),
            renderSyncSettings(),
            Divider(),
            renderDeviceSettings(),
            Divider(),
            renderDataSettings(),
            Divider(),
            renderAppInfo(),
            Divider(),
            renderLegalSettings()
        ])
```

---

## 测试覆盖

**测试文件**: `flutter/test/features/settings/settings_panel_test.dart`

**单元测试**:
- `test_show_current_theme_mode()` - 显示当前主题模式
- `test_toggle_theme()` - 切换主题
- `test_show_auto_sync_preference()` - 显示自动同步偏好
- `test_show_sync_frequency_options()` - 显示同步频率选项
- `test_show_app_version()` - 显示应用版本
- `test_show_app_name_description()` - 显示应用名称和描述
- `test_navigate_to_device_manager()` - 导航到设备管理器
- `test_clear_local_cache()` - 清除本地缓存
- `test_export_data()` - 导出数据
- `test_show_privacy_policy()` - 显示隐私政策
- `test_show_terms_of_service()` - 显示服务条款
- `test_group_settings_by_sections()` - 按部分分组设置

**功能测试**:
- `test_complete_settings_workflow()` - 完整设置流程
- `test_theme_switching_workflow()` - 主题切换流程

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 所有功能测试通过
- [ ] 主题切换正常工作
- [ ] 同步设置功能正常
- [ ] 数据管理操作可靠
- [ ] 代码审查通过
- [ ] 文档已更新
