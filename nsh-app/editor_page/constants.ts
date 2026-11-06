// 编辑页视觉/行为常量（自 editor_page.tsx 纯结构拆出，声明逐字保留）。

/** 保存态文案（同时有文字，颜色不作唯一状态指示）。 */
export const SAVE_STATE = {
  saved: "已保存",
  saving: "正在保存",
  dirty: "尚未保存",
  failed: "保存失败",
} as const;
export type SaveState = (typeof SAVE_STATE)[keyof typeof SAVE_STATE];

/** 空态/提示文案。 */
export const COPY = {
  /** 两种编辑模式的可达标签：`label:源码编辑器`/`label:富文本编辑器` 供自动化定位。 */
  sourceLabel: "源码编辑器",
  richLabel: "富文本编辑器",
  placeholder: "写下第一行…",
  loading: "加载中…",
  loadFailed: "加载失败",
  retry: "重试",
  back: "返回",
  saveRetry: "重试",
  /** 源码/排版切换（P4-3a：默认 WYSIWYG，源码是可切换的模式）。 */
  sourceMode: "源码",
  richMode: "排版",
  closeCandidates: "关闭候选",
} as const;

/** 加载指示器（视觉常量，与 components.tsx 的模块级视觉常量同风格）。 */
export const LOADING_SPINNER = { size: 20, stroke: 2 } as const;
/** 失焦后延迟清空候选：点候选 chip 会先失焦，立即清会让按下落空。 */
export const CANDIDATE_BLUR_HIDE_MS = 150;
/** 关闭时最多 flush 两轮（保存期间又有输入时再存一次）。 */
export const CLOSE_FLUSH_ATTEMPTS = 2;
