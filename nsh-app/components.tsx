// CardMind TSX 组件库（施工方案 2.1）：对照 lib/ui/design_system/cardmind_widgets.dart
// 移植 6 个组件，另补「列表项 / 确认对话框」两个规范组件。
//
// 令牌纪律：所有颜色 / 间距 / 圆角 / 触摸目标全部来自 ./theme，禁止裸值。
//
// 按压反馈：View 的 `underlayColor`（nsh 原生按压高亮，见 nsh examples
// gallery/ui.tsx 的 Row）——按下变色但不改布局尺寸，不会引起内容抖动。
//
// 结构（P2-5 纯结构拆分）：本文件仅保留公共 API 的 re-export；类型/常量/
// 组件实现分别落在 ./components/ 子模块（types / constants / glyph / buttons /
// search_field / tag / sync_status / empty_state / list_item / confirm_dialog /
// panel）。各声明逐字未改（token 级等价，见 .pipeline/executor.md）。
export { Glyph } from "./components/glyph";
export { CardMindPrimaryButton, CardMindIconButton } from "./components/buttons";
export { CardMindSearchField } from "./components/search_field";
export { CardMindTag } from "./components/tag";
export { CardMindSyncStatus } from "./components/sync_status";
export { CardMindEmptyState } from "./components/empty_state";
export { CardMindListItem } from "./components/list_item";
export { CardMindConfirmDialog } from "./components/confirm_dialog";
export { panel } from "./components/panel";
export type { IconGlyph } from "./components/types";
