# UI 设计系统

**最后更新**: 2026-01-08

---

## 设计原则

基于 CardMind 的产品定位，UI 设计遵循以下核心原则：

### 1. 简洁专注 (Simple & Focused)
- 最小化视觉干扰，让内容成为焦点
- 避免过度装饰和复杂视觉效果
- 每个界面只做一件事

### 2. 快速响应 (Fast & Responsive)
- 清晰的视觉层级，快速定位信息
- 即时的交互反馈
- 支持 30 秒内完成卡片创建

### 3. 轻量舒适 (Light & Comfortable)
- 柔和的颜色，减少视觉疲劳
- 充足的留白，呼吸感强
- 支持深色模式，适应不同环境

### 4. 一致可靠 (Consistent & Reliable)
- 统一的设计语言
- 可预测的交互模式
- 清晰的状态反馈

---

## 颜色系统

### 主色板 (Primary Colors)

CardMind 使用**蓝绿色系**作为主色，传达"知识成长"与"可靠专业"的品牌特质。

#### 主色 - 青色 (Teal)

| 名称 | Light Mode | Dark Mode | 用途 |
|------|-----------|-----------|------|
| Primary 50 | `#E0F7F4` | `#0A2E2A` | 浅背景 |
| Primary 100 | `#B3EDE5` | `#0F4039` | 悬停背景 |
| Primary 200 | `#80E2D6` | `#145249` | 次要元素 |
| Primary 300 | `#4DD6C7` | `#1A6459` | 边框 |
| Primary 400 | `#26CDBB` | `#20766A` | 激活状态 |
| **Primary 500** | `#00BFA5` | `#26A88F` | **主按钮、强调** |
| Primary 600 | `#00B297` | `#2DBF9E` | 悬停主按钮 |
| Primary 700 | `#00A385` | `#4DD6C7` | 按下状态 |
| Primary 800 | `#009473` | `#66E0D0` | 链接 |
| Primary 900 | `#007A5E` | `#80E2D6` | 强调文本 |

**主色使用场景**:
- Primary 500: 主按钮、FAB、选中标签
- Primary 100: 卡片选中背景
- Primary 700: 链接文本、图标强调

### 中性色 (Neutral Colors)

灰度系统，用于文本、背景、边框等基础元素。

#### Light Mode

| 名称 | 色值 | 用途 |
|------|------|------|
| Neutral 0 | `#FFFFFF` | 纯白背景、卡片 |
| Neutral 50 | `#FAFAFA` | 页面背景 |
| Neutral 100 | `#F5F5F5` | 次级背景 |
| Neutral 200 | `#EEEEEE` | 分割线、禁用背景 |
| Neutral 300 | `#E0E0E0` | 边框 |
| Neutral 400 | `#BDBDBD` | 占位符 |
| Neutral 500 | `#9E9E9E` | 辅助文本 |
| Neutral 600 | `#757575` | 次要文本 |
| Neutral 700 | `#616161` | 正文文本 |
| Neutral 800 | `#424242` | 标题文本 |
| Neutral 900 | `#212121` | 主标题、强调文本 |

#### Dark Mode

| 名称 | 色值 | 用途 |
|------|------|------|
| Neutral 900 | `#121212` | 页面背景 |
| Neutral 800 | `#1E1E1E` | 卡片背景 |
| Neutral 700 | `#2A2A2A` | 次级背景 |
| Neutral 600 | `#404040` | 分割线 |
| Neutral 500 | `#6B6B6B` | 边框 |
| Neutral 400 | `#9E9E9E` | 占位符 |
| Neutral 300 | `#B0B0B0` | 辅助文本 |
| Neutral 200 | `#D0D0D0` | 次要文本 |
| Neutral 100 | `#E5E5E5` | 正文文本 |
| Neutral 50 | `#F0F0F0` | 标题文本 |
| Neutral 0 | `#FFFFFF` | 主标题、强调文本 |

### 语义色 (Semantic Colors)

#### 成功 (Success) - 绿色

| 名称 | Light Mode | Dark Mode | 用途 |
|------|-----------|-----------|------|
| Success Light | `#E8F5E9` | `#1B5E20` | 背景 |
| Success Main | `#4CAF50` | `#66BB6A` | 主色 |
| Success Dark | `#388E3C` | `#81C784` | 强调 |

**使用场景**: 同步成功、保存成功、操作完成提示

#### 警告 (Warning) - 橙色

| 名称 | Light Mode | Dark Mode | 用途 |
|------|-----------|-----------|------|
| Warning Light | `#FFF3E0` | `#E65100` | 背景 |
| Warning Main | `#FF9800` | `#FFA726` | 主色 |
| Warning Dark | `#F57C00` | `#FFB74D` | 强调 |

**使用场景**: 冲突警告、存储空间不足、网络不稳定

#### 错误 (Error) - 红色

| 名称 | Light Mode | Dark Mode | 用途 |
|------|-----------|-----------|------|
| Error Light | `#FFEBEE` | `#B71C1C` | 背景 |
| Error Main | `#F44336` | `#EF5350` | 主色 |
| Error Dark | `#D32F2F` | `#E57373` | 强调 |

**使用场景**: 错误提示、删除操作、验证失败

#### 信息 (Info) - 蓝色

| 名称 | Light Mode | Dark Mode | 用途 |
|------|-----------|-----------|------|
| Info Light | `#E3F2FD` | `#0D47A1` | 背景 |
| Info Main | `#2196F3` | `#42A5F5` | 主色 |
| Info Dark | `#1976D2` | `#64B5F6` | 强调 |

**使用场景**: 提示信息、帮助文案、功能说明

### 颜色使用原则

1. **主色节制使用**: 主色仅用于关键交互元素，避免过度使用
2. **中性色为主**: 90% 的界面使用中性色，保持简洁
3. **语义色明确**: 红色只用于错误/删除，绿色只用于成功/确认
4. **深色模式适配**: 所有颜色都有对应的深色模式版本
5. **对比度要求**: 文本与背景对比度 ≥ 4.5:1 (WCAG AA 标准)

---

## 排版系统

### 字体族 (Font Family)

#### 优先级顺序

```css
/* 中文优先 */
font-family:
  "PingFang SC",          /* macOS/iOS 中文 */
  "Microsoft YaHei",      /* Windows 中文 */
  "Noto Sans CJK SC",     /* Linux 中文 */

  /* 西文 */
  -apple-system,          /* macOS/iOS 系统字体 */
  BlinkMacSystemFont,     /* macOS Chrome */
  "Segoe UI",             /* Windows 系统字体 */
  Roboto,                 /* Android */
  "Helvetica Neue",       /* macOS 备选 */
  Arial,                  /* 通用备选 */

  /* 无衬线字体备选 */
  sans-serif;
```

#### 等宽字体 (Monospace)

用于代码块、UUID 等固定宽度文本：

```css
font-family:
  "SF Mono",              /* macOS */
  "Cascadia Code",        /* Windows */
  "Fira Code",            /* 跨平台 */
  Consolas,               /* Windows 备选 */
  "Courier New",          /* 通用备选 */
  monospace;
```

### 字阶系统 (Type Scale)

基于 **1.125 比例** (Major Second) 构建，保持层级清晰且不过分夸张。

| 级别 | 名称 | 字号 | 行高 | 字重 | 用途 |
|------|------|------|------|------|------|
| H1 | Display Large | 32px | 40px | 700 (Bold) | 页面主标题 |
| H2 | Display Medium | 28px | 36px | 600 (SemiBold) | 区块标题 |
| H3 | Headline Large | 24px | 32px | 600 (SemiBold) | 卡片标题（大） |
| H4 | Headline Medium | 20px | 28px | 600 (SemiBold) | 卡片标题（中） |
| H5 | Headline Small | 18px | 24px | 500 (Medium) | 小节标题 |
| H6 | Title | 16px | 24px | 500 (Medium) | 列表标题 |
| Body Large | Body 1 | 16px | 24px | 400 (Regular) | 正文（强调） |
| **Body** | **Body 2** | **14px** | **20px** | **400 (Regular)** | **正文（默认）** |
| Body Small | Body 3 | 13px | 18px | 400 (Regular) | 辅助文本 |
| Caption | Caption | 12px | 16px | 400 (Regular) | 说明文字、时间戳 |
| Overline | Overline | 11px | 16px | 500 (Medium) | 标签、分类 |

### 字重 (Font Weight)

| 名称 | 数值 | 用途 |
|------|------|------|
| Regular | 400 | 正文、描述 |
| Medium | 500 | 小标题、标签 |
| SemiBold | 600 | 二级标题、按钮 |
| Bold | 700 | 主标题、强调 |

**使用原则**:
- 正文统一 400
- 标题使用 500-700
- 避免使用 300 以下（细体在小尺寸下可读性差）
- 避免使用 800 以上（过重，视觉压迫感强）

### Markdown 排版映射

CardMind 支持 Markdown，映射规则如下：

| Markdown | 字阶 | 样式 |
|----------|------|------|
| `# H1` | H3 (24px) | 卡片标题上限 |
| `## H2` | H4 (20px) | 卡片子标题 |
| `### H3` | H5 (18px) | 卡片小节 |
| `#### H4-H6` | H6 (16px) | 最小标题 |
| 段落 | Body 2 (14px) | 正文 |
| 列表 | Body 2 (14px) | 正文 + 缩进 |
| 引用 | Body 2 (14px) | 斜体 + 边框 |
| 代码块 | Body 2 (14px) | 等宽字体 |
| 行内代码 | Body 2 (14px) | 等宽 + 背景色 |

**注意**:
- 卡片内不使用 H1/H2（页面级标题），最大从 H3 开始
- Markdown 标题在卡片预览中可能缩小一级显示

### 行高规则

- **标题**: 1.2-1.4 倍字号（紧凑）
- **正文**: 1.4-1.6 倍字号（舒适）
- **长文本**: 1.6-1.8 倍字号（阅读性）

### 字符间距 (Letter Spacing)

- **标题**: 0px（中文无需额外间距）
- **正文**: 0px
- **大写英文**: +0.5px（全大写标题）
- **Overline/Caption**: +0.3px（小字号增加可读性）

---

## 间距系统

### 基准单位

CardMind 使用 **8px 栅格系统**，所有间距都是 8 的倍数。

```
4px  = 0.5 单位 (特殊情况)
8px  = 1 单位
16px = 2 单位
24px = 3 单位
32px = 4 单位
40px = 5 单位
48px = 6 单位
64px = 8 单位
```

### 间距语义

| 名称 | 尺寸 | 用途 |
|------|------|------|
| `spacing-xs` | 4px | 紧密元素间距（图标与文字） |
| `spacing-sm` | 8px | 相关元素间距（按钮内边距） |
| `spacing-md` | 16px | 默认元素间距（卡片内容） |
| `spacing-lg` | 24px | 区块间距（卡片之间） |
| `spacing-xl` | 32px | 大区块间距（页面分区） |
| `spacing-2xl` | 48px | 页面边距 |
| `spacing-3xl` | 64px | 特大留白 |

### 内边距 (Padding)

#### 容器内边距

| 元素 | 内边距 | 说明 |
|------|--------|------|
| 页面 | 16px (mobile), 24px (tablet), 32px (desktop) | 响应式调整 |
| 卡片 | 16px | 标准卡片内容区 |
| 按钮（小） | 8px 16px | 垂直 水平 |
| 按钮（中） | 12px 24px | 垂直 水平 |
| 按钮（大） | 16px 32px | 垂直 水平 |
| 输入框 | 12px 16px | 垂直 水平 |
| 对话框 | 24px | 统一内边距 |
| 底部栏 | 16px | 底部导航 |

### 外边距 (Margin)

#### 垂直间距

| 上下文 | 间距 | 说明 |
|--------|------|------|
| 卡片之间 | 16px | 列表中的卡片 |
| 区块之间 | 24px | 不同功能区 |
| 页面顶部 | 24px | 顶部标题下方 |
| 页面底部 | 32px | 底部留白 |
| 段落之间 | 12px | Markdown 段落 |
| 标题下方 | 8px | 标题与内容间距 |

#### 水平间距

| 上下文 | 间距 | 说明 |
|--------|------|------|
| 图标与文字 | 8px | 按钮、列表项 |
| 按钮之间 | 8px | 按钮组 |
| 表单标签与输入框 | 8px | 垂直表单 |
| 侧边栏 | 16px | 抽屉式侧边栏 |

---

## 组件样式

### 圆角 (Border Radius)

CardMind 使用**柔和圆角**，营造现代、友好的视觉感受。

| 名称 | 尺寸 | 用途 |
|------|------|------|
| `radius-none` | 0px | 无圆角（特殊情况） |
| `radius-sm` | 4px | 小元素（标签、徽章） |
| `radius-md` | 8px | 默认（按钮、输入框） |
| `radius-lg` | 12px | 卡片 |
| `radius-xl` | 16px | 大卡片、模态框 |
| `radius-full` | 9999px | 圆形（头像、FAB） |

**使用原则**:
- 卡片统一 12px
- 按钮/输入框统一 8px
- 避免使用过大的圆角（> 20px），保持专业感

### 阴影 (Elevation)

使用**多层阴影**模拟真实深度，遵循 Material Design 3.0 规范。

#### Light Mode

| 级别 | 阴影值 | 用途 |
|------|--------|------|
| Level 0 | `none` | 无阴影（平铺元素） |
| Level 1 | `0 1px 2px rgba(0,0,0,0.05)` | 悬浮卡片 |
| Level 2 | `0 2px 4px rgba(0,0,0,0.08)` | 卡片默认 |
| Level 3 | `0 4px 8px rgba(0,0,0,0.12)` | 卡片悬停 |
| Level 4 | `0 8px 16px rgba(0,0,0,0.15)` | 对话框、抽屉 |
| Level 5 | `0 16px 32px rgba(0,0,0,0.20)` | 模态框 |

#### Dark Mode

深色模式下阴影不明显，使用**发光边框**代替：

| 级别 | 效果 | 用途 |
|------|------|------|
| Level 0 | `none` | 无效果 |
| Level 1 | `0 0 0 1px rgba(255,255,255,0.05)` | 分割线 |
| Level 2 | `0 0 0 1px rgba(255,255,255,0.08)` | 卡片默认 |
| Level 3 | `0 0 0 1px rgba(255,255,255,0.12)` | 卡片悬停 |
| Level 4 | `0 0 0 1px rgba(255,255,255,0.15)` | 对话框 |
| Level 5 | `0 8px 32px rgba(0,0,0,0.5)` | 模态框 |

**使用原则**:
- 浅色模式优先使用阴影
- 深色模式优先使用边框 + 背景层级
- 避免过度使用高级阴影

### 边框 (Border)

| 类型 | 样式 | 用途 |
|------|------|------|
| 默认 | `1px solid Neutral-300` (Light) / `Neutral-600` (Dark) | 分割线、卡片边框 |
| 强调 | `2px solid Primary-500` | 选中状态 |
| 虚线 | `1px dashed Neutral-400` | 拖放区域 |

**使用原则**:
- 浅色模式优先使用阴影，边框辅助
- 深色模式边框更明显
- 选中状态使用 2px 主色边框

### 透明度 (Opacity)

| 名称 | 值 | 用途 |
|------|-----|------|
| Disabled | 0.38 | 禁用状态 |
| Inactive | 0.54 | 非活跃图标 |
| Secondary | 0.74 | 次要文本 |
| Active | 1.0 | 正常状态 |

---

## 布局规范

### 栅格系统 (Grid System)

CardMind 使用 **12 列栅格系统**，响应式断点如下：

| 断点 | 屏幕宽度 | 列间距 | 页边距 | 设备 |
|------|----------|--------|--------|------|
| Mobile | < 600px | 16px | 16px | 手机 |
| Tablet | 600-1024px | 24px | 24px | 平板 |
| Desktop | > 1024px | 32px | 32px | 电脑 |

### 卡片布局

#### 卡片尺寸

| 视图模式 | 宽度 | 最小高度 | 说明 |
|----------|------|----------|------|
| 列表视图 | 100% | 80px | 单列展示 |
| 网格视图 (Mobile) | 100% | 120px | 单列 |
| 网格视图 (Tablet) | calc(50% - 12px) | 120px | 双列 |
| 网格视图 (Desktop) | calc(33.33% - 16px) | 120px | 三列 |
| 详情视图 | 100% (max 800px) | 200px | 全屏阅读 |

#### 卡片内部结构

```
┌─────────────────────────────────────┐
│ ↕ 16px (padding-top)                │
│ ← 16px →  [标题 H4]      ← 16px →   │
│           [内容 Body2]               │
│           [标签、时间 Caption]       │
│ ↕ 16px (padding-bottom)             │
└─────────────────────────────────────┘
```

### 最大内容宽度

为保证阅读舒适度，限制最大内容宽度：

- **卡片详情**: 最大 800px，居中显示
- **文章阅读**: 最大 720px（约 60-80 字符/行）
- **列表视图**: 无限制

---

## 动效规范

### 动画时长

| 类型 | 时长 | 用途 |
|------|------|------|
| 微交互 | 100-150ms | 按钮点击、开关切换 |
| 标准 | 200-300ms | 卡片展开、对话框出现 |
| 复杂 | 300-500ms | 页面切换、抽屉滑出 |

### 缓动曲线 (Easing)

```css
/* 标准 - 对称动画 */
--ease-standard: cubic-bezier(0.4, 0.0, 0.2, 1);

/* 减速 - 进入动画 */
--ease-decelerate: cubic-bezier(0.0, 0.0, 0.2, 1);

/* 加速 - 退出动画 */
--ease-accelerate: cubic-bezier(0.4, 0.0, 1, 1);

/* 强调 - 弹性效果 */
--ease-emphasized: cubic-bezier(0.4, 0.0, 0.1, 1);
```

**使用原则**:
- 进入动画：减速（从快到慢）
- 退出动画：加速（从慢到快）
- 切换动画：标准（对称）
- 避免使用弹簧动效（过于活泼，不符合专业定位）

---

## 图标规范

### 图标尺寸

| 名称 | 尺寸 | 用途 |
|------|------|------|
| Small | 16px | 行内图标、标签 |
| Medium | 20px | 按钮图标（默认） |
| Large | 24px | 工具栏图标 |
| XLarge | 32px | 主功能图标 |

### 图标样式

- **风格**: Outlined（描边风格），统一 2px 线宽
- **颜色**: 继承父元素文本颜色
- **来源**: Material Symbols (Google)

**推荐图标集**:
- Add: `add_circle_outline`
- Edit: `edit_outlined`
- Delete: `delete_outline`
- Search: `search`
- Sync: `sync`
- More: `more_vert`

---

## 无障碍要求

### 对比度

- **正文文本**: 对比度 ≥ 4.5:1 (WCAG AA)
- **大字体 (≥18px)**: 对比度 ≥ 3:1 (WCAG AA)
- **图形元素**: 对比度 ≥ 3:1

### 可触摸区域

- **最小触摸区域**: 44x44px (iOS) / 48x48px (Material)
- **按钮之间间距**: ≥ 8px

### 焦点指示

- **键盘焦点**: 2px 主色边框 + 4px 偏移
- **焦点顺序**: 逻辑顺序（从上到下，从左到右）

---

## 响应式设计

### 适配策略

| 屏幕 | 策略 | 重点 |
|------|------|------|
| Mobile | 单列布局，大触摸区域 | 快速捕捉，拇指可达 |
| Tablet | 双列布局，利用空间 | 浏览与编辑平衡 |
| Desktop | 三列布局，快捷键 | 效率优先，批量操作 |

### 字体缩放

支持用户系统字体缩放（iOS/Android 辅助功能）：
- 测试范围：80% - 150%
- 关键元素使用 `rem` 单位
- 固定元素（图标）使用 `px` 单位

---

## 设计资源

### Figma 设计文件

（待创建）

### 颜色变量文件

```dart
// lib/theme/colors.dart
class AppColors {
  // Primary
  static const primary500 = Color(0x00BFA5);
  static const primary600 = Color(0x00B297);

  // Neutral (Light)
  static const neutral50 = Color(0xFAFAFA);
  static const neutral900 = Color(0x212121);

  // 详见完整实现...
}
```

### 排版变量文件

```dart
// lib/theme/typography.dart
class AppTypography {
  static const h3 = TextStyle(
    fontSize: 24,
    height: 1.33, // 32/24
    fontWeight: FontWeight.w600,
  );

  static const body2 = TextStyle(
    fontSize: 14,
    height: 1.43, // 20/14
    fontWeight: FontWeight.w400,
  );

  // 详见完整实现...
}
```

---

**设计决策记录**已移至 [ADR-0004: UI 设计决策](./../../adr/0004-ui-design.md)

---

**文档维护**:
- 此文档定义 UI 设计标准，所有界面实现必须遵循
- 如需调整，需更新此文档并记录决策理由
- 实现细节参考代码：`lib/theme/`

**相关文档**:
- 产品定位 → [product_vision.md](../requirements/product_vision.md)
- 系统设计 → [system_design.md](../architecture/system_design.md)
- UI 设计决策 → [ADR-0004](../../adr/0004-ui-design.md)
