// 导航骨架（施工方案 2.6）：路由联合类型 + `createNavStack` + `NavStack`/`NavPage`。
//
// 路由：notes（笔记列表）/ trash（回收站）/ settings（设置）/ devices（设备）/
// editor（编辑器，携带 noteId 推栈）。桌面端 notes 页内三栏、编辑器不进栈；
// 移动端编辑器作为栈上页 push。
import type { JSX } from "nsh";
import { createNavStack } from "nsh/base";
import { colors } from "./theme";

/** 应用路由（plain values，按 identity 比较，见 nsh-js navigation.rs）。 */
export type Route =
  | { name: "notes" }
  | { name: "trash" }
  | { name: "settings" }
  | { name: "devices" }
  | { name: "editor"; noteId: string };

/** 全局 navigator：初始路由 notes（0.2.0 `createNavStack` 收初始路由数组）。 */
export const nav = createNavStack<Route>([{ name: "notes" }]);

/** 打开编辑器（push editor 路由）。 */
export function openEditor(noteId: string): void {
  nav.push({ name: "editor", noteId });
}

/** 返回上一页（栈底 notes 保留）。 */
export function goBack(): void {
  nav.pop();
}

/** 顶部导航栏返回键（复用 IconButton 的 back glyph 槽位即可）。 */
export const routes = {
  notes: { name: "notes" } as Route,
  trash: { name: "trash" } as Route,
  settings: { name: "settings" } as Route,
  devices: { name: "devices" } as Route,
} as const;

/** 顶部栏样式（`NavPage` 的颜色入口只有 `headerStyle`；颜色走令牌，不裸色）。 */
export const headerStyle = {
  backgroundColor: colors.paper,
  color: colors.ink,
  tintColor: colors.accent,
} as const;

/** 每个 `<NavPage>` 的公共 props。 */
export function screenChrome(title: string) {
  return { title, headerStyle };
}

export type { JSX };
