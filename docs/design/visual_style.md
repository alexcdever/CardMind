# 视觉风格指南

> **文档类型**: 视觉设计规范（非可执行规格）
> **用途**: 定义 CardMind 的视觉外观、颜色、字体等设计元素

---

## 📋 文档说明

本文档定义 CardMind 的**视觉设计元素**，包括颜色、字体、间距等。

**注意**: 本文档不包含交互行为规格。交互规格请查看 `openspec/specs/flutter/`。

---

## 1. 设计原则

### 1.1 简洁专注 (Simple & Focused)
- 最小化视觉干扰，让内容成为焦点
- 避免过度装饰和复杂视觉效果
- 每个界面只做一件事

### 1.2 快速响应 (Fast & Responsive)
- 清晰的视觉层级，快速定位信息
- 即时的交互反馈（交互规格见 `openspec/specs/flutter/`）

### 1.3 轻量舒适 (Light & Comfortable)
- 柔和的颜色，减少视觉疲劳
- 充足的留白，呼吸感强
- 支持深色模式，适应不同环境

### 1.4 一致可靠 (Consistent & Reliable)
- 统一的设计语言
- 可预测的交互模式（交互规格见 `openspec/specs/flutter/`）

---

## 2. 色彩系统

### 2.1 主色调

CardMind 使用**蓝绿色系**作为主色，传达"知识成长"与"可靠专业"的品牌特质。

```
主色 (Primary):
- 色值: #00897B (Teal 600)
- 用途: 主要按钮、强调元素、品牌标识

辅助色 (Secondary):
- 色值: #5E35B1 (Deep Purple 600)
- 用途: 次要按钮、标签、装饰元素
```

### 2.2 语义色彩

```
成功 (Success):
- 色值: #43A047 (Green 600)
- 用途: 成功提示、同步完成状态

警告 (Warning):
- 色值: #FB8C00 (Orange 600)
- 用途: 警告提示、存储空间提示

错误 (Error):
- 色值: #E53935 (Red 600)
- 用途: 错误提示、删除确认

信息 (Info):
- 色值: #1E88E5 (Blue 600)
- 用途: 信息提示、帮助文本
```

### 2.3 中性色

```
浅色模式:
- 背景: #FFFFFF (白色)
- 表面: #F5F5F5 (灰色 100)
- 文字主色: #212121 (灰色 900)
- 文字次色: #757575 (灰色 600)
- 分割线: #E0E0E0 (灰色 300)

深色模式:
- 背景: #121212 (深灰)
- 表面: #1E1E1E (深灰)
- 文字主色: #FFFFFF (白色)
- 文字次色: #B0B0B0 (浅灰)
- 分割线: #2C2C2C (深灰)
```

---

## 3. 字体系统

### 3.1 字体族

```
中文字体:
- iOS/macOS: PingFang SC
- Android: Noto Sans CJK SC
- Windows: Microsoft YaHei

英文字体:
- iOS/macOS: SF Pro Text
- Android: Roboto
- Windows: Segoe UI

代码字体:
- 跨平台: JetBrains Mono, Fira Code
```

### 3.2 字号层级

```
标题 1 (H1): 24px / 1.5em, 粗体
标题 2 (H2): 20px / 1.25em, 粗体
标题 3 (H3): 18px / 1.125em, 粗体
正文 (Body): 16px / 1em, 常规
辅助文字 (Caption): 14px / 0.875em, 常规
小字 (Small): 12px / 0.75em, 常规
```

### 3.3 行高

```
标题: 1.3
正文: 1.6
代码: 1.5
```

---

## 4. 间距系统

### 4.1 基础间距单位

使用 **8px 网格系统**：

```
xs:  4px  (0.5 单位)
sm:  8px  (1 单位)
md:  16px (2 单位)
lg:  24px (3 单位)
xl:  32px (4 单位)
xxl: 48px (6 单位)
```

### 4.2 组件间距

```
卡片内边距: 16px (md)
卡片间距: 12px
列表项高度: 72px
按钮内边距: 12px 24px
输入框内边距: 12px 16px
```

---

## 5. 圆角系统

```
小圆角 (Small): 4px
- 用途: 标签、小按钮

中圆角 (Medium): 8px
- 用途: 卡片、输入框、普通按钮

大圆角 (Large): 12px
- 用途: 对话框、底部抽屉

圆形 (Circle): 50%
- 用途: 头像、图标按钮
```

---

## 6. 阴影系统

```
轻阴影 (Light):
- elevation: 2
- 用途: 卡片、按钮

中阴影 (Medium):
- elevation: 4
- 用途: 悬浮按钮、AppBar

重阴影 (Heavy):
- elevation: 8
- 用途: 对话框、抽屉
```

---

## 7. 图标系统

### 7.1 图标库

使用 **Material Icons** 作为主要图标库。

### 7.2 图标尺寸

```
小图标: 16px
常规图标: 24px
大图标: 32px
特大图标: 48px
```

### 7.3 常用图标

```
导航:
- 返回: arrow_back
- 菜单: menu
- 更多: more_vert

操作:
- 添加: add
- 编辑: edit
- 删除: delete
- 搜索: search
- 设置: settings

状态:
- 同步中: sync
- 已同步: cloud_done
- 同步失败: cloud_off
- 加载中: CircularProgressIndicator
```

---

## 8. 动效参数

### 8.1 动画时长

```
快速: 150ms
- 用途: 按钮点击、开关切换

标准: 300ms
- 用途: 页面过渡、对话框弹出

慢速: 500ms
- 用途: 复杂动画、列表展开
```

### 8.2 缓动曲线

```
标准: Curves.easeInOut
快速进入: Curves.easeOut
快速退出: Curves.easeIn
弹性: Curves.elasticOut
```

**注意**: 具体的动画触发条件和交互行为，请查看 `openspec/specs/flutter/` 中的交互规格。

---

## 9. 响应式断点

```
手机 (Mobile): < 600px
- 布局: 单列
- 特点: 拇指操作优先

平板 (Tablet): 600px - 1024px
- 布局: 双列或自适应
- 特点: 浏览与编辑平衡

桌面 (Desktop): > 1024px
- 布局: 三列或多列
- 特点: 效率优先
```

---

## 10. 无障碍设计

### 10.1 对比度

```
正文文字: 至少 4.5:1
大字标题: 至少 3:1
图标按钮: 至少 3:1
```

### 10.2 触摸目标

```
最小触摸区域: 48x48 dp
推荐触摸区域: 56x56 dp
```

### 10.3 字体缩放

支持系统字体大小设置（0.8x - 1.3x）。

---

## 11. 相关文档

### 设计文档
- [布局指南](./layout_guide.md) - 响应式布局详细规范
- [组件库](./component_library.md) - 可复用组件设计

### 交互规格（可执行）
- [UI 交互规格](../../openspec/specs/flutter/ui_interaction_spec.md)
- [主页交互规格](../../openspec/specs/flutter/home_screen_spec.md)
- [初始化流程规格](../../openspec/specs/flutter/onboarding_spec.md)

### 产品文档
- [产品愿景](../requirements/product_vision.md)
- [用户手册](../user_guide.md)

---

**最后更新**: 2026-01-16
**维护者**: CardMind Design Team
