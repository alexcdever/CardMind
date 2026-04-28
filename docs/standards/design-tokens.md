# 设计语言令牌（Design Tokens）

本文档定义 CardMind 的设计语言令牌体系，提取自 cardmind.pen 设计稿与现有 Flutter 代码，作为 UI 构建的权威参考。

## 色彩体系

### 品牌色

| Token 名 | Hex 值 | Dart 常量 | 用途 |
|---|---|---|---|
| brand | `#0F766E` | `CardMindColors.brand` | 主品牌色，按钮背景、链接文字、活跃态指示 |

### 品牌扩展色

| Token 名 | Hex 值 | Dart 常量 | 用途 |
|---|---|---|---|
| brand-light-bg | `#E6F4F2` | `CardMindColors.brandLightBg` | 品牌浅底，活跃标签背景（如 BottomNav 选中项） |
| brand-muted-bg | `#EEF3F3` | `CardMindColors.brandMutedBg` | 品牌弱底，次要卡片背景（如 Join Pool 卡） |

### 背景色

| Token 名 | Hex 值 | Dart 常量 | 用途 |
|---|---|---|---|
| bg-canvas | `#F8FAFB` | `CardMindColors.bgCanvas` | 页面底层背景，Scaffold background |
| bg-surface | `#FFFFFF` | `CardMindColors.bgSurface` | 卡片、面板前景背景（选中态卡片、详情面板） |
| bg-subtle | `#EEF5F5` | `CardMindColors.bgSubtle` | 次级背景，侧栏底色、列表非活跃项 |
| bg-input | `#ECF3F3` | `CardMindColors.bgInput` | 输入域/搜索栏填充色 |

### 文字色

| Token 名 | Hex 值 | Dart 常量 | 用途 |
|---|---|---|---|
| text-primary | `#203234` | `CardMindColors.textPrimary` | 正文、标题文字 |
| text-secondary | `#5F7274` | `CardMindColors.textSecondary` | 辅助说明文字、卡片正文 |
| text-muted | `#8BA1A3` | `CardMindColors.textMuted` | 弱化文字、占位提示、离线状态 |
| text-brand | `#0F766E` | `CardMindColors.textBrand` | 品牌色文字（标签、链接） |
| text-on-brand | `#FFFFFF` | `CardMindColors.textOnBrand` | 品牌底上的文字（按钮内文字） |

### 边框与状态色

| Token 名 | Hex 值 | Dart 常量 | 用途 |
|---|---|---|---|
| border-subtle | `#D9E4E8` | `CardMindColors.borderSubtle` | 默认边框色（设计稿外框、卡片分隔线） |
| status-synced | `#0F766E` | `CardMindColors.statusSynced` | 已同步状态指示 |
| status-offline | `#8BA1A3` | `CardMindColors.statusOffline` | 离线状态指示 |

### AppLock 专用色（从 cardmind.pen 提取，暂未独立 Token 化）

| 名称 | Hex 值 | 用途 |
|---|---|---|
| app-lock-badge-bg | `#CCFBF1` | 应用锁徽章背景 |
| app-lock-badge-text | `#115E59` | 应用锁徽章文字 |
| app-lock-title | `#0F172A` | 应用锁标题深色 |
| app-lock-intro | `#475569` | 应用锁说明文字 |
| app-lock-label | `#64748B` | 应用锁字段标签 |
| app-lock-card-bg | `#F1F5F9` | 应用锁卡片背景 |
| app-lock-card-border | `#DDE7EA` | 应用锁卡片边框 |
| app-lock-field-border | `#CBD5E1` | 应用锁输入域边框 |
| app-lock-bio-border | `#E2E8F0` | 应用锁生物识别行边框 |

## 圆角

| Token 名 | 值 | Flutter 常量 | 使用场景 |
|---|---|---|---|
| sm | 8px | `CardMindRadii.sm` | 按钮、输入框、工具栏、侧栏导航项 |
| md | 10px | `CardMindRadii.md` | 搜索栏、成员卡片、FAB |
| lg | 12px | `CardMindRadii.lg` | 笔记卡片、设置卡片 |
| xl | 14px | `CardMindRadii.xl` | 应用锁卡片、BottomNav 容器 |
| 2xl | 18px | `CardMindRadii.twoXl` | 暂无使用 |
| pill | 999px | `CardMindRadii.pill` | 徽章、标签（胶囊形） |

## 间距

| Token 名 | 值 | Flutter 常量 | 使用场景 |
|---|---|---|---|
| xs | 4px | `CardMindSpacing.xs` | 底部导航图标与文字间距 |
| sm | 8px | `CardMindSpacing.sm` | 卡片内元素间距、标签间距 |
| md | 10px | `CardMindSpacing.md` | 编辑器 meta 行间距 |
| lg | 16px | `CardMindSpacing.lg` | 面板块间距 |
| xl | 18px | `CardMindSpacing.xl` | 页面级垂直间距、内边距 |
| 2xl | 20px | `CardMindSpacing.twoXl` | 卡片内边距 |
| 3xl | 24px | `CardMindSpacing.threeXl` | 桌面列表区水平内边距 |

## 字号

| 大小 | 字重 | 行高 | 使用场景 |
|---|---|---|---|
| 10px | w800 | — | 卡片标签、导航文字、徽章 |
| 11px | w600/w800 | — | 桌面笔记卡片标签、备注元信息 |
| 12px | w400/w600/w700/w800 | 1.35–1.45 | 辅助文字、按钮文字、面包屑、脚注 |
| 13px | w400/w800 | 1.45 | 说明文字、侧栏导航项、成员名 |
| 14px | w800 | — | 品牌英文名、卡片内按钮 |
| 15px | w400/w800 | 1.25–1.6 | 笔记标题(移动端)、正文 |
| 18px | w400/w800 | — | 品牌名(大)、设置卡片标题 |
| 20px | w800 | — | 桌面大标题 |
| 21px | w800 | — | 集卡片标题 |
| 22px | w800 | — | 应用锁卡片内标题 |
| 24px | w800 | — | 页面主标题(移动端) |
| 26px | w800 | — | 数据池成员标题(移动端) |
| 27px | w800 | 1.12 | 页面大标题(移动端) |
| 28px | w800 | — | 指标数值 |
| 31px | w800 | 1.06 | 应用锁标题 |
| 37px | w800 | 1.08 | 桌面端笔记详情标题 |
| 42px | w800 | 1.1 | 桌面端设置页大标题 |
| 44px | w800 | 1.05 | 桌面端应用锁标题 |

## 字体

| 平台 | 字体 | 用途 |
|---|---|---|
| Flutter Mobile | 系统默认（Material Design 字体） | 全部 |
| Flutter Desktop | 系统默认（Material Design 字体） | 全部 |
| 设计稿 | Inter | 全部文字 |

## 布局参数

### 页面 Padding

| 场景 | 值 | 说明 |
|---|---|---|
| 移动端页面 | `[18, 20]` (水平, 垂直) | 笔记列表、编辑器、Pool 设置等所有移动端页面 |
| 移动端 AppLock | `[24, 32, 24, 28]` (左, 上, 右, 下) | 应用锁设置/解锁页面 |
| 桌面端侧栏 | `[26, 12, 24, 12]` (上, 右, 下, 左) | 桌面侧栏内边距 |
| 桌面端列表区 | `[24, 20]` (水平, 垂直) | 桌面端左侧笔记列表面板 |
| 桌面端详情区 | `[28, 30, 24, 32]` (上, 右, 下, 左) | 桌面端右侧笔记详情面板 |

### 组件高度

| 组件 | 高度 | 说明 |
|---|---|---|
| 移动端 Header | 30px | 品牌行 |
| 移动端搜索栏 | 42px | 搜索输入框 |
| 移动端 BottomNav 容器 | 64px | 底部导航整体 |
| 移动端 BottomNav 项 | 44px (每项) | 单个导航项 |
| 移动端 FAB | 42×42px | 新建笔记按钮 |
| 桌面端侧栏品牌图标 | 24px | 侧栏中的品牌图标 |
| 桌面端新建按钮 | 42px | 侧栏「新建笔记」按钮 |
| 桌面端侧栏导航项 | 36px | 侧栏 笔记/数据池 导航项 |
| 工具栏(编辑器) | 42px | 移动端编辑器格式工具栏 |
| 桌面端编辑器工具栏 | 38px | 桌面端编辑器格式工具栏 |

## 约束规则

1. **颜色使用优先用语义常量**，避免硬编码 Hex 值，除非该色仅出现在单一场景且不具跨组件复用价值。
2. **圆角和间距**统一使用 `CardMindRadii` / `CardMindSpacing` 中的常量，不使用裸数字。
3. **字号**尚未 Token 化，Flutter 代码中允许直接使用 `fontSize: N`，但必须与本文档中的字号级保持一致。
4. 新增组件应先检查本文档中是否已有匹配的 Token 定义；如没有且该值在多处出现，应补充 Token。
