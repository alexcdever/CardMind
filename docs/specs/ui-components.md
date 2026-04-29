# UI 组件与交互规格

本文档记录 CardMind 已确认的共享 UI 组件、导航模式和状态视图模式。来源为 cardmind.pen 设计稿与现有 Flutter 实现。

## 共享组件

### 1. BrandHeader（品牌头部）

**文件**: `lib/features/shared/widgets/brand_header.dart`

**变体**:

| 变体 | 结构 | 使用场景 |
|---|---|---|
| 移动端 | `[grid 图标(14px)] [Card Mind 文字(14px)]` | 笔记列表、编辑器、Pool 页面顶部 |
| 移动端(编辑器) | `[grid 图标(14px)] [Card Mind 文字(14px)] [spacer] [完成按钮(60×30)]` | 编辑器顶部 |
| 移动端(Pool) | `[grid 图标(14px)] [Card Mind 文字(14px)] [spacer] [status 文字]` | Pool 设置/成员页顶部 |

**规则**:
- 品牌图标固定为 `Icons.grid_view_rounded`，颜色 `brand`
- 品牌文字固定为 "Card Mind"，14px w800，颜色 `brand`

### 2. DesktopSidebar（桌面侧栏）

**文件**: `lib/features/shared/widgets/desktop_sidebar.dart`

**结构**: 垂直布局，宽度 190px
1. 品牌行（图标 24px + "Card Mind" 14px）
2. 「新建笔记」按钮（brand 背景，白色文字/图标，42px 高，r8）
3. 导航项（垂直排列，间距 8px）
   - 笔记（notebook 图标，36px 高，r8）
   - 数据池（network 图标，36px 高，r8）
4. Spacer（填充剩余空间，bg-subtle 色）

**状态**:
- 活跃导航项：白色背景(`bg-surface`)，文字/图标 brand 色
- 非活跃导航项：透明背景，文字/图标 `text-secondary` 色

**内边距**: `[26, 12, 24, 12]` (上,右,下,左)

### 3. BottomNav（移动端底部导航）

**文件**: `lib/features/shared/widgets/bottom_nav.dart`

**结构**: 水平居中，高度 64px，背景 `bg-canvas`，圆角 14px
- 「笔记」项：78×44px，notebook 图标 + 文字
- 「数据池」项：78×44px，network 图标 + 文字
- 两项使用 spaceEvenly 水平居中分布，视觉间距约 42px

**状态**:
- 活跃项：`brand-light-bg` 背景，图标 + 文字 brand 色
- 非活跃项：透明背景，图标 + 文字 `text-primary`

**规则**:
- 图标 16px，文字 10px w800
- 图标与文字间距 4px（垂直居中布局）

### 4. NoteCard（笔记卡片）

**文件**: `lib/features/shared/widgets/note_card.dart`

**结构**: 垂直布局
1. 标签文字（10px w800，brand 色或 muted 色）
2. 标题（移动端 15px w800 / 桌面端 14px w800，行高 1.25）
3. 正文摘要（11px，行高 1.35，`text-secondary`）

**状态**:
- 选中态：`bg-surface` 背景，左边框 3px brand（桌面端）
- 非选中态：移动端 `bg-canvas` / 桌面端 `bg-subtle`
- 圆角：r12（移动端）/ r10（桌面端）
- 内边距：16px（移动端）/ 14px（桌面端）

**参数**:
- `compact`: `false`（移动端默认）使用移动端规格；`true`（桌面端）使用小型化规格
- `selected`: 控制选中态样式
- `tagColor`: 可覆盖标签颜色（默认 brand 色）

**规则**:
- 卡片内元素间距 8px
- 标签可为 brand 色（已同步/同步中）或 muted 色（本地优先、离线）
- 点击选中后进入编辑器

### 5. StyledSearchField（搜索输入框）

**文件**: `lib/features/shared/widgets/search_field.dart`

**结构**: search 图标(14px) + TextField
- 移动端（`compact: false`）：背景色 `bg-canvas`，圆角 r10，高度约 42px
- 桌面端（`compact: true`）：背景色 `bg-input`，圆角 r8，高度约 32-34px
- 图标 `text-muted` 色
- 占位文字 12px

### 6. Badge / Pill（徽章标签）

**当前状态**: 在 `pool_page_sections.dart`（`_SoftLabel`）和 `app_lock_screen.dart`（`_AppLockBadge`）中为私有组件，尚未提升为共享组件。

**设计规格**:
- 圆角：pill (999px)
- 内边距：水平 10px，垂直 6px
- 文字：10–11px w700–w800

**变体**:
| 变体 | 背景色 | 文字色 | 使用场景 |
|---|---|---|---|
| Pool badge | `brand-light-bg` | `brand` | "连接中心"、"数据池" |
| AppLock badge | `#CCFBF1` | `#115E59` | "需要身份验证"、"已锁定" |

### 7. SetupCard（设置操作卡片）

**当前状态**: 在 `pool_page_sections.dart`（`_PoolSetupCard`）中为私有组件。

**结构**: 垂直布局，r12，内边距 20px，元素间距 14px
1. 图标（32px，brand 色）
2. 标题（18px w800，`text-primary`）
3. 说明文字（12px，`text-secondary`，行高 1.45）
4. 操作文字按钮（12px w800，brand 色，带箭头后缀）

**变体**:
| 变体 | 背景色 |
|---|---|
| 主要操作（创建） | `bg-surface` (白色) |
| 次要操作（加入） | `brand-muted-bg` |

### 8. AppLock Form Card（应用锁表单卡片）

**文件**: `lib/features/security/app_lock/app_lock_screen.dart`（内联 Widget）

**结构**:
- 卡片容器：r14，背景 `#F1F5F9`，边框 `#DDE7EA`，内边距 20px
- 卡片内标题：22px w800，`#0F172A`

**Setup 模式元素**:
1. PIN 输入域（白色背景，r8，边框 `#CBD5E1`，padding 14）
   - 标签：11px w700 `#64748B`
   - 输入框：16px w700，obscured
2. 确认 PIN 域（同上结构）
3. 生物识别开关行（白色背景，r8，边框 `#E2E8F0`，padding 14）
   - 文字："可用时启用生物识别解锁" 14px w700
   - Toggle 开关：42×24px，圆角 pill
4. 提交按钮：r8，brand 背景，白色 14px w800 文字

**Unlock 模式元素**:
1. 生物识别按钮：brand 背景，r8，"使用生物识别解锁"
2. 分隔文字："或输入数字密码" 12px w700 `#64748B`
3. PIN 输入域（同上）
4. 解锁按钮：r8，brand 背景
5. 帮助文字：12px `#64748B`

### 9. Pool Member Tile（池成员卡片）

**文件**: `lib/features/pool/pool_page_sections.dart`（`_RuntimeMemberTile`）

**设计规格**（移动端）:
- 水平布局，r10，内边距 12px，元素间距 12px
- 头像区：36×44–50px，r8，设备颜色背景
- 文字区（垂直）：
  - 设备名：13px w800
  - 元信息：11px（"本地设备 · 你"、"7 分钟前活跃"）
- 状态标识：10px w800

**设备头像颜色变体**:
| 设备 | 头像背景 |
|---|---|
| 本地主设备 | `text-primary` (#203234) |
| 活跃设备 | `#E1F3F0` |
| 半活跃设备 | `#F0F4F4` |
| 离线设备 | `#E5EAEA` |

## 导航模式

### 桌面端

**布局**: 三栏 `Row`
1. DesktopSidebar (190px) — 品牌 + 新建按钮 + 导航 + spacer
2. 列表/表单区 (330px 或 fill) — 卡片列表、搜索、或设置表单
3. 详情区 (fill) — 笔记内容预览/编辑

**适用页面**:
- 笔记列表：侧栏 + 卡列表 + 只读详情面板（点击笔记展示标签、标题、元数据、正文）
- 数据池设置：侧栏 + 设置表单
- 数据池成员：侧栏 + 成员搜索 + 成员网格
- 桌面编辑器：侧栏 + 编辑工作区（纸面卡片式编辑器）

**导航切换**: 侧栏内「笔记」↔「数据池」切换当前主视区。

### 移动端

**布局**: 单栏 `Scaffold` + BottomNav
1. 页面内容（全宽）
2. BottomNav（固定在底部，64px）
3. 笔记列表额外有 FAB（右下角 42×42px）

**导航切换**: BottomNav「笔记」↔「数据池」切换页面。

### 编辑器入口

| 平台 | 入口 | 行为 |
|---|---|---|
| 移动端 | 卡片点击 + FAB | Navigator.push EditorPage |
| 桌面端 | 侧栏「新建笔记」 | Navigator.push EditorPage（桌面布局） |
| 桌面端 | 卡片点击 | 右侧只读详情面板展示笔记内容 |
| 编辑器返回 | 完成/放弃按钮 | 保存 draft → pop |

## 状态视图模式

### Pool 状态机

`PoolShell → AppLockGate → AppLockScreen | PoolPage`

| 状态 | 视图组件 | 说明 |
|---|---|---|
| unconfigured | `AppLockScreen` (setup 模式) | 未设置应用锁 → PIN 设置表单 |
| locked | `AppLockScreen` (unlock 模式) | 已锁定 → 生物识别或 PIN 解锁 |
| unlocked + notJoined | `_PoolNotJoinedView` | 显示创建/加入数据池两张卡片 |
| unlocked + joined | `_PoolJoinedView` | 显示成员列表、指标、邀请面板 |
| unlocked + joinPending | `_PoolJoinPendingView` | 等待管理员审批 |
| error | `AppLockScreen` (error) / `_PoolErrorView` | 错误信息 + 操作按钮 |
| exitPartialCleanup | `_PoolExitPartialCleanupView` | 退出清理异常 |

### AppLock 状态流

```
启动 → refresh() → 判断 appLockStatus
  ├─ !configured → AppLockScreen(setup)
  │   └─ setupPin("1234") → unlocked → 显示子页面
  └─ configured + locked → AppLockScreen(unlock)
      ├─ unlockWithPin("1234") → unlocked
      └─ unlockWithBiometricSuccess() → unlocked
```

### 笔记列表状态

| 状态 | 表现 |
|---|---|
| 加载中 | 列表空、等待卡片加载 |
| 有数据 | 卡片列表（含搜索、标签、标题、摘要） |
| 搜索中 | 搜索栏有文字，列表实时过滤 |
| 空结果 | 列表空（暂无专门空态占位） |

## 交互行为定义

### 笔记操作

| 操作 | 移动端 | 桌面端 |
|---|---|---|
| 新建笔记 | FAB → EditorPage | 侧栏「新建笔记」→ EditorPage（桌面布局） |
| 打开笔记 | 点击卡片 → EditorPage | 点击卡片 → 右侧只读详情面板（标题、元数据、正文） |
| 保存笔记 | EditorPage「完成」→ pop 并保存 | EditorPage 内 Ctrl+S / 保存按钮 |
| 离开编辑 | PopScope 拦截 → 确认对话框 | PopScope 拦截 + 快捷保存 |

### 数据池操作

| 操作 | 交互 |
|---|---|
| 创建数据池 | SetupCard「开始 →」→ controller.createPool() |
| 加入数据池 | SetupCard「立即连接 →」→ onScanJoin() |
| 查看成员 | 创建成功后自动进入 _PoolJoinedView |
| 退出数据池 | 「退出池」按钮 → 确认 → controller.leavePool() |

### 应用锁操作

| 操作 | 交互 |
|---|---|
| 设置 PIN | 输入 PIN + 确认 PIN + 可选生物识别 → setupPin() |
| 解锁 PIN | 输入 PIN → unlockWithPin() |
| 生物识别解锁 | 点击生物识别按钮 → unlockWithBiometricSuccess() |
