// CardMind 设计令牌 —— TSX 侧唯一来源。
// 值必须与 lib/ui/design_system/cardmind_theme.dart 逐一对齐；
// nsh-app/theme_test.ts 会读 Dart 源文本逐项比对，漂移即红。

/** 颜色令牌，对齐 CardMindTokens.light（10 个）。 */
export const colors = {
  paper: '#F9F9F8',
  ink: '#1A1A1A',
  mutedInk: '#666666',
  border: '#E2E2E0',
  accent: '#4A707A',
  accentHover: '#3E646E',
  surfaceLow: '#F3F4F3',
  surfaceRaised: '#FFFFFF',
  danger: '#A34F4F',
  /** 长时间未同步警告色（stale dot），只用于状态圆点。 */
  stale: '#B08D2E',
} as const;

/** 间距档位（px），对齐 CardMindSpacing（6 档）。 */
export const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  xxl: 32,
} as const;

/** 圆角档位（px），对齐 CardMindRadii（4 档）。 */
export const radii = {
  sm: 2,
  md: 4,
  lg: 6,
  xl: 8,
} as const;

/** 布局常量（px），对齐 CardMindLayout（5 个）。 */
export const layout = {
  desktopBreakpoint: 960,
  sidebarWidth: 240,
  listWidth: 360,
  editorMaxWidth: 768,
  mobileTouchTarget: 48,
} as const;

export interface TypeToken {
  /** 字号 px */
  fontSize: number;
  /** 行高 px（Dart `height: a / b` 中的分子 a）；labelLarge 未设则为 undefined */
  lineHeight?: number;
  /** 字重；600 = FontWeight.w600，undefined = 默认字重 */
  fontWeight?: number;
}

/** 排版档位，对齐 CardMindTheme.light textTheme（4 档）。 */
export const typography = {
  headlineSmall: { fontSize: 24, lineHeight: 32, fontWeight: 600 },
  titleMedium: { fontSize: 18, lineHeight: 24, fontWeight: 600 },
  bodyMedium: { fontSize: 15, lineHeight: 22 },
  labelLarge: { fontSize: 14, fontWeight: 600 },
} as const satisfies Record<string, TypeToken>;

/** 字体回退链，对齐 fontFamilyFallback。 */
export const fontFamilyFallback = ['Source Han Sans CN'] as const;
