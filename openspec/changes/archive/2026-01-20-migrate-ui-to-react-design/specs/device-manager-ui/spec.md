# Device Manager UI Specification

## ADDED Requirements

### Requirement: Display current device
系统 SHALL 显示当前设备的信息。

#### Scenario: 显示设备信息
- **WHEN** 渲染设备管理面板
- **THEN** 面板显示当前设备的名称、类型图标和在线状态

#### Scenario: 高亮当前设备
- **WHEN** 显示当前设备
- **THEN** 当前设备使用特殊背景色和边框高亮显示

### Requirement: Rename current device
系统 SHALL 允许用户重命名当前设备。

#### Scenario: 进入重命名模式
- **WHEN** 用户点击当前设备的编辑按钮
- **THEN** 设备名称变为可编辑的输入框

#### Scenario: 保存新名称
- **WHEN** 用户输入新名称并点击保存
- **THEN** 系统更新设备名称，退出编辑模式

#### Scenario: 取消重命名
- **WHEN** 用户点击取消按钮
- **THEN** 设备名称恢复到原始值，退出编辑模式

### Requirement: Display paired devices
系统 SHALL 显示所有已配对的设备列表。

#### Scenario: 显示设备列表
- **WHEN** 渲染设备管理面板
- **THEN** 面板显示所有已配对设备的名称、类型、状态和最后在线时间

#### Scenario: 显示空列表
- **WHEN** 没有已配对的设备
- **THEN** 面板显示"暂无配对设备"的提示信息

### Requirement: Add new device
系统 SHALL 支持添加新设备。

#### Scenario: 打开添加设备对话框
- **WHEN** 用户点击"添加设备"按钮
- **THEN** 系统打开添加设备对话框，显示两种配对方式：扫码配对和局域网发现

#### Scenario: 扫码配对
- **WHEN** 用户选择扫码配对标签页
- **THEN** 系统显示当前设备的二维码和配对说明

#### Scenario: 局域网发现
- **WHEN** 用户选择局域网发现标签页
- **THEN** 系统扫描局域网内的可用设备，显示设备列表

#### Scenario: 手动添加设备
- **WHEN** 用户输入设备名称、选择设备类型并点击添加
- **THEN** 系统添加新设备到配对列表，关闭对话框

### Requirement: Remove paired device
系统 SHALL 支持移除已配对的设备。

#### Scenario: 移除设备
- **WHEN** 用户点击设备的删除按钮
- **THEN** 系统从配对列表中移除该设备

### Requirement: Device status indication
系统 SHALL 显示设备的在线状态。

#### Scenario: 在线设备
- **WHEN** 设备在线
- **THEN** 设备显示绿色的在线图标

#### Scenario: 离线设备
- **WHEN** 设备离线
- **THEN** 设备显示灰色的离线图标和最后在线时间

### Requirement: Device type icons
系统 SHALL 为不同类型的设备显示对应的图标。

#### Scenario: 手机图标
- **WHEN** 设备类型为手机
- **THEN** 显示手机图标

#### Scenario: 笔记本图标
- **WHEN** 设备类型为笔记本
- **THEN** 显示笔记本图标

#### Scenario: 平板图标
- **WHEN** 设备类型为平板
- **THEN** 显示平板图标
