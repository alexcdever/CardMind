// CardMind 组件库 — 共享视觉常量（P2-5 自 components.tsx 纯结构拆出，声明逐字未改）。
import { spacing } from "../theme";

/** 图标的视觉尺寸（px）。18/19/20 档对照 Flutter 侧 Icon size；非触摸目标。 */
export const glyphSize = {
  md: 18,
  lg: 20,
} as const;

/** 同步状态圆点直径（px，对照 Flutter Container width/height: 7）。 */
export const statusDotSize = 7;

/** 空态图标占位尺寸（px，对照 Flutter Icon size: 42）。 */
export const emptyIconSize = 42;

/** 搜索框垂直内边距（px，对照 contentPadding vertical: mobile 12 / desktop 10）。 */
export const searchPaddingY = { mobile: 12, desktop: 10 } as const;

/** 标签文字字号（px，对照 fontSize: comfortable 13 / default 12）。 */
export const tagFontSize = { comfortable: 13, compact: 12 } as const;

/** 标签垂直内边距（px，对照 top/bottom: comfortable 14 / default 4=spacing.xs）。 */
export const tagPaddingY = { comfortable: 14, compact: spacing.xs } as const;

/** 标签删除图标视觉尺寸（px，对照 size: comfortable 16 / default 14）。 */
export const tagDeleteGlyph = { comfortable: 16, compact: 14 } as const;

/** 空态说明区最大宽度（px，对照 ConstrainedBox maxWidth: 320）。 */
export const emptyStateMaxWidth = 320;

/** 对话框内容宽度（px，高对比模态框的固定栏宽）。 */
export const dialogWidth = 340;

/** 标签垂直内边距（px，对照 top/bottom: comfortable 14 / default 4=spacing.xs）。 */
export const activeStripeWidth = 2;

/** disabled 态透明度（对照 nsh 惯例 `disabled:opacity-40`，即 0.4）。 */
export const disabledOpacity = 0.4;
