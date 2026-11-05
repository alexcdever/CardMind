// 编辑页视觉/行为常量（自 editor_page.tsx 纯结构拆出，声明逐字保留）。
import type { TextViewStyles } from "nsh/base";
import { colors, radii, typography } from "../theme";

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
  editorLabel: "Markdown 编辑器",
  placeholder: "开始写 Markdown…",
  loading: "加载中…",
  loadFailed: "加载失败",
  retry: "重试",
  back: "返回",
  saveRetry: "重试",
  preview: "预览",
  backToEdit: "编辑",
  closeCandidates: "关闭候选",
} as const;

/** 加载指示器（视觉常量，与 components.tsx 的模块级视觉常量同风格）。 */
export const LOADING_SPINNER = { size: 20, stroke: 2 } as const;
/** 失焦后延迟清空候选：点候选 chip 会先失焦，立即清会让按下落空。 */
export const CANDIDATE_BLUR_HIDE_MS = 150;
/** 关闭时最多 flush 两轮（保存期间又有输入时再存一次）。 */
export const CLOSE_FLUSH_ATTEMPTS = 2;
/** 桌面编辑区并排预览的最小宽度：≥1280pt 才并排（C2，06 §6-7）；
 *  <1280 用单栏编辑↔预览切换（C1）。 */
export const SIDE_BY_SIDE_WIDTH = 1280;
/** 预览去抖（ms）：预览可见时打字停止这么久才重解析（05 §3.3/R6）。 */
export const PREVIEW_DEBOUNCE_MS = 450;

/** 预览的 TextView 部件样式：映射 theme 令牌（不裸值）。
 *  只覆盖高频 part（root/heading/link/code/blockquote），其余用默认。
 *  link（P4-2）：cardmind:// 笔记链接与普通外链同走内建渲染；近 chip 外观
 *  = accent 文字 + surfaceLow 底色 + 圆角（TextView 不渲染 `renderCustom` 了，
 *  旧 [[id|alias]] 加载时已归一为标准链接）。 */
export const PREVIEW_STYLES: TextViewStyles = {
  root: {
    color: colors.ink,
    fontSize: typography.bodyMedium.fontSize,
    lineHeight: typography.bodyMedium.lineHeight + 4,
  },
  heading: { color: colors.ink, fontWeight: "600" },
  link: {
    color: colors.accent,
    backgroundColor: colors.surfaceLow,
    borderRadius: radii.sm,
  },
  code: {
    color: colors.ink,
    backgroundColor: colors.surfaceLow,
    fontSize: typography.bodyMedium.fontSize - 1,
  },
  codeBlock: {
    backgroundColor: colors.surfaceLow,
    borderRadius: radii.md,
  },
  blockquote: {
    borderLeftColor: colors.accent,
  },
};
