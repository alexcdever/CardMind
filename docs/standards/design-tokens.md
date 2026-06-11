# 设计语言令牌（Design Tokens）

本文档定义 CardMind 的设计语言令牌体系，提取自 Digital Parchment 设计系统，作为 UI 构建的权威参考。

## 色彩体系

### 语义色

| Token | Hex | 用途 |
|---|---|---|
| `paper-white` | `#F9F9F8` | 页面底色、画布背景 |
| `ink-charcoal` | `#1A1A1A` | 正文、标题文字 |
| `graphite-gray` | `#666666` | 辅助文字、元数据 |
| `muted-border` | `#E2E2E0` | 边框、分隔线 |
| `active-teal` | `#4A707A` | 品牌主色、主按钮、活跃态指示 |
| `danger-red` | `#A34F4F` | 危险动作、错误提示 |

### 表面色（Surface）

| Token | Hex | 用途 |
|---|---|---|
| `surface` | `#F9F9F8` | 基础表面 |
| `surface-dim` | `#DADAD9` | 暗表面 |
| `surface-bright` | `#F9F9F8` | 亮表面 |
| `surface-container-lowest` | `#FFFFFF` | 最低层容器（白色） |
| `surface-container-low` | `#F3F4F3` | 低层容器 |
| `surface-container` | `#EEEEED` | 中层容器 |
| `surface-container-high` | `#E8E8E7` | 高层容器 |
| `surface-container-highest` | `#E2E2E2` | 最高层容器 |
| `on-surface` | `#1A1C1C` | 表面上的文字 |
| `on-surface-variant` | `#41484A` | 表面上的变体文字 |
| `inverse-surface` | `#2F3130` | 反向表面（Dark 模式） |
| `inverse-on-surface` | `#F1F1F0` | 反向表面上的文字 |

### 主色（Primary）

| Token | Hex | 用途 |
|---|---|---|
| `primary` | `#315861` | 主色 |
| `on-primary` | `#FFFFFF` | 主色上的文字 |
| `primary-container` | `#4A707A` | 主色容器（active-teal） |
| `on-primary-container` | `#CAF2FE` | 主色容器上的文字 |
| `inverse-primary` | `#A5CDD8` | 反向主色 |
| `primary-fixed` | `#C1E9F5` | 主色固定 |
| `primary-fixed-dim` | `#A5CDD8` | 主色固定暗 |
| `on-primary-fixed` | `#001F26` | 主色固定上的文字 |
| `on-primary-fixed-variant` | `#254C55` | 主色固定变体上的文字 |

### 次要色（Secondary）

| Token | Hex | 用途 |
|---|---|---|
| `secondary` | `#5F5E5E` | 次要色 |
| `on-secondary` | `#FFFFFF` | 次要色上的文字 |
| `secondary-container` | `#E4E2E1` | 次要色容器 |
| `on-secondary-container` | `#656464` | 次要色容器上的文字 |
| `secondary-fixed` | `#E4E2E1` | 次要色固定 |
| `secondary-fixed-dim` | `#C8C6C6` | 次要色固定暗 |

### 第三色（Tertiary）

| Token | Hex | 用途 |
|---|---|---|
| `tertiary` | `#6E4A2E` | 第三色 |
| `on-tertiary` | `#FFFFFF` | 第三色上的文字 |
| `tertiary-container` | `#896244` | 第三色容器 |
| `on-tertiary-container` | `#FFE7D8` | 第三色容器上的文字 |

### 错误色（Error）

| Token | Hex | 用途 |
|---|---|---|
| `error` | `#BA1A1A` | 错误 |
| `on-error` | `#FFFFFF` | 错误上的文字 |
| `error-container` | `#FFDAD6` | 错误容器 |
| `on-error-container` | `#93000A` | 错误容器上的文字 |

### 轮廓色（Outline）

| Token | Hex | 用途 |
|---|---|---|
| `outline` | `#71787A` | 轮廓 |
| `outline-variant` | `#C1C8CA` | 轮廓变体 |

## 圆角

| Token | 值 | 用途 |
|---|---|---|
| `radius.sm` | `2px` | 小装饰元素 |
| `radius.md` | `4px` | 卡片、按钮、输入框（标准） |
| `radius.lg` | `6px` | 中等容器 |
| `radius.xl` | `8px` | 搜索栏、工具栏 |
| `radius.2xl` | `12px` | 面板、底部导航容器 |
| `radius.pill` | `9999px` | 徽章、标签（胶囊形） |

## 间距

| Token | 值 | 用途 |
|---|---|---|
| `space.xs` | `4px` | 图标与文字间距 |
| `space.sm` | `8px` | 标签间距、元素内间距 |
| `space.md` | `12px` | 紧凑列表项间距 |
| `space.lg` | `16px` | 标准容器内边距 |
| `space.xl` | `24px` | 大区块间距 |
| `space.2xl` | `32px` | 页面级外间距 |

## 字体

| 角色 | 字体 | 用途 |
|---|---|---|
| UI | Inter | 导航、按钮、标题等全部 UI 元素 |
| 编辑器 | JetBrains Mono | 笔记正文编辑区 |

## 字号层级

| 层级 | 字号 | 字重 | 行高 | 字距 | 用途 |
|---|---|---|---|---|---|
| `display-lg` | 24px | 600 | 32px | -0.02em | 页面大标题 |
| `headline-md` | 18px | 600 | 24px | — | 区块标题 |
| `body-md` | 15px | 400 | 22px | — | 正文 |
| `editor-text` | 14px | 400 | 24px | — | 编辑器内容（JetBrains Mono） |
| `label-caps` | 11px | 700 | 16px | 0.05em | 标签、状态字（全大写） |
| `status-sm` | 12px | 500 | 16px | — | 同步状态指示文字 |

## 布局参数

| 场景 | 值 | 说明 |
|---|---|---|
| 桌面端侧栏宽 | 260px | 左侧导航栏 |
| 桌面端列表区宽 | 360px | 中间笔记列表 |
| 编辑器最大宽 | 48rem | 编辑区居中最大宽度 |
| 移动端标准内边距 | 16px | 页面左右内边距 |
| 桌面端标准内边距 | 24px | 页面左右内边距 |

## 约束规则

1. 颜色优先使用语义 Token，避免硬编码 Hex。
2. 圆角和间距统一使用 Token，不使用裸数字。
3. 新增组件前检查本文档是否有匹配 Token。

> 本文档以 Digital Parchment 设计系统为基准。
