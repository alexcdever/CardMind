// CardMind 组件库 — 类型（P2-5 自 components.tsx 纯结构拆出，声明逐字未改）。
import type { ViewStyle } from "nsh";

/** 小写图标集：占位 glyph 用线性几何图形而非 emoji（规范：不用 emoji 当图标）。 */
export type IconGlyph =
  | "add"
  | "back"
  | "close"
  | "delete"
  | "devices"
  | "edit"
  | "notes"
  | "restore"
  | "search"
  | "settings"
  | "tag"
  | "trash"
  | "warning";

/** 供 JSX style 展开的类型别名（保持与 nsh ViewStyle 一致）。 */
export type { ViewStyle };
