// CardMind 组件库 — 面板底色集合（P2-5 自 components.tsx 纯结构拆出，声明逐字未改）。
import { colors } from "../theme";

/** 供页面复用的面板底色集合（paper 画布 / surfaceLow 侧栏 / surfaceRaised 卡片）。 */
export const panel = {
  canvas: colors.paper,
  sidebar: colors.surfaceLow,
  card: colors.surfaceRaised,
} as const satisfies Record<string, string>;
