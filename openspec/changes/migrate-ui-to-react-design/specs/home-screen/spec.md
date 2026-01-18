# Home Screen Specification

## MODIFIED Requirements

### Requirement: Adaptive layout rendering
主屏幕 SHALL 根据平台类型渲染不同的布局。

#### Scenario: 移动端布局
- **WHEN** 应用在移动端平台运行
- **THEN** 主屏幕显示底部导航栏、单栏笔记列表、浮动操作按钮

#### Scenario: 桌面端布局
- **WHEN** 应用在桌面端平台运行
- **THEN** 主屏幕显示三栏布局（设备管理 + 笔记列表 + 设置），顶部固定导航栏

#### Scenario: 响应式切换
- **WHEN** 用户调整窗口大小跨越断点
- **THEN** 主屏幕自动切换到对应的布局模式

### Requirement: Top navigation bar
主屏幕 SHALL 显示顶部导航栏（桌面端）。

#### Scenario: 显示应用标题
- **WHEN** 渲染顶部导航栏
- **THEN** 导航栏左侧显示应用图标和"分布式笔记"标题

#### Scenario: 显示同步状态
- **WHEN** 渲染顶部导航栏
- **THEN** 导航栏右侧显示同步状态指示器

#### Scenario: 显示新建按钮
- **WHEN** 渲染顶部导航栏
- **THEN** 导航栏右侧显示"新建笔记"按钮

### Requirement: Search functionality
主屏幕 SHALL 提供笔记搜索功能。

#### Scenario: 搜索笔记标题
- **WHEN** 用户在搜索框中输入关键词
- **THEN** 系统过滤笔记列表，显示标题包含关键词的笔记

#### Scenario: 搜索笔记内容
- **WHEN** 用户在搜索框中输入关键词
- **THEN** 系统过滤笔记列表，显示内容包含关键词的笔记

#### Scenario: 搜索标签
- **WHEN** 用户在搜索框中输入关键词
- **THEN** 系统过滤笔记列表，显示标签包含关键词的笔记

#### Scenario: 清空搜索
- **WHEN** 用户清空搜索框
- **THEN** 系统显示所有笔记

### Requirement: Create new note
主屏幕 SHALL 支持创建新笔记。

#### Scenario: 桌面端创建笔记
- **WHEN** 用户点击顶部导航栏的"新建笔记"按钮
- **THEN** 系统创建新笔记，添加到列表顶部，自动进入编辑模式

#### Scenario: 移动端创建笔记
- **WHEN** 用户点击浮动操作按钮
- **THEN** 系统创建新笔记，打开全屏编辑器

### Requirement: Display note list
主屏幕 SHALL 显示笔记列表。

#### Scenario: 显示笔记网格（桌面端）
- **WHEN** 在桌面端显示笔记列表
- **THEN** 笔记以网格形式排列（1-2 列）

#### Scenario: 显示笔记列表（移动端）
- **WHEN** 在移动端显示笔记列表
- **THEN** 笔记以单栏列表形式排列

#### Scenario: 显示空状态
- **WHEN** 没有笔记或搜索无结果
- **THEN** 显示空状态提示和创建笔记的引导

### Requirement: Three-column layout (desktop)
主屏幕 SHALL 在桌面端显示三栏布局。

#### Scenario: 左侧设备管理栏
- **WHEN** 在桌面端渲染主屏幕
- **THEN** 左侧显示设备管理面板和设置面板

#### Scenario: 右侧笔记区域
- **WHEN** 在桌面端渲染主屏幕
- **THEN** 右侧显示搜索栏和笔记网格

### Requirement: Tab-based navigation (mobile)
主屏幕 SHALL 在移动端支持标签页导航。

#### Scenario: 笔记标签页
- **WHEN** 用户选择笔记标签
- **THEN** 显示搜索栏和笔记列表

#### Scenario: 设备标签页
- **WHEN** 用户选择设备标签
- **THEN** 显示设备管理面板

#### Scenario: 设置标签页
- **WHEN** 用户选择设置标签
- **THEN** 显示设置面板

### Requirement: Floating action button (mobile)
主屏幕 SHALL 在移动端显示浮动操作按钮。

#### Scenario: 显示 FAB
- **WHEN** 在移动端渲染主屏幕
- **THEN** 屏幕右下角显示圆形的浮动操作按钮，距离底部导航栏 80px

#### Scenario: 点击 FAB
- **WHEN** 用户点击浮动操作按钮
- **THEN** 系统创建新笔记，打开全屏编辑器
