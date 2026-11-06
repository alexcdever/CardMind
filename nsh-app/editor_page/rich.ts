// 编辑页 WYSIWYG 接缝（P4-3a）：`RichEditor` 的 schema/plugins/session 工厂
// 与部件样式。单列一个文件：controller 只管「哪个模式用哪份文本」，这里管
// 「Markdown ↔ 富文档」的一切——加载 `createRichEditor({content, format:"markdown"})`、
// 保存 `session.getMarkdown()`、视觉映射 RichEditorStyles。
//
// 0.4.0 实测（.pipeline/progress.md 探针）：
//   - `getMarkdown()` ≡ `schema.serialize(doc,"markdown")`，且不走 doc JSON（便宜）。
//   - 往返：块级（标题/列表/引用/代码块/分隔线）与行内（粗斜体/行内码/~~删~~/
//     [a](cardmind://…)）全保真；唯一归一是「段落间多空行 → 一个空行」；
//     段内 `\n`（行一\n行二）原样保留。
//   - `<RichEditor>` headless 下**必须给 style（flex:1）**才会挂载；mod+shift+* 键
//     会被编辑器吞掉（f* 键不会）。
//   - `editor` prop 只在视图创建时取一次：换 session 必须换 key（模式切换整体
//     卸载/重挂，天然满足）。
import {
  createRichEditor,
  link,
  markdown,
  starterKit,
  starterSchema,
  type RichEditorSession,
  type RichEditorStyles,
  type RichSchema,
} from "nsh/base";
import { colors, radii } from "../theme";

/** 全页共用的 starter schema（paragraph/heading/blockquote/codeBlock/
 *  horizontalRule/hardBreak/image/有序无序列表/task 列表 + bold/italic/code/
 *  link/strike/underline）。单例即可：schema 是无状态的规格对象。 */
export const richSchema: RichSchema = starterSchema();

/** Markdown 的「往返归一」形式：`serialize(parse(md))`。RichEditor 的
 *  parse/serialize 是结构性归一（多空行→一个、标记语法重排），不等于原文。
 *  脏检测/保存基线必须用 canonical 比较，否则「加载即 dirty」幻影写回。
 *  （仅持久化路径调用；逐键路径不调用——19k 字 parse+serialize ≈50–80ms。） */
export function canonicalMarkdown(md: string): string {
  return richSchema.serialize(richSchema.parseMarkdown(md), "markdown");
}

/** 为 `initialMarkdown` 建一个 WYSIWYG 会话。
 *  `link({protocols:["cardmind"], openOnClick:false, enableClickSelection:true})`：
 *  cardmind:// 被认成合法链接协议（P4-2 存储格式 `[alias](cardmind://note/id)`
 *  在 WYSIWYG 里渲染为链接而非裸文本）；`openOnClick:false` 本轮不做点击跳转
 *  （P4-3b 再接管链接按下）。 */
export function createNoteRichSession(initialMarkdown: string): RichEditorSession {
  return createRichEditor({
    schema: richSchema,
    content: initialMarkdown,
    format: "markdown",
    plugins: [
      starterKit(),
      markdown(),
      link({
        protocols: ["cardmind"],
        openOnClick: false,
        enableClickSelection: true,
      }),
    ],
  });
}

/** `RichEditor` 部件样式：映射 theme 令牌（不裸值），按部件名给 TextStyle。
 *  `fontSize`/`lineHeight` 跟随 metrics（移动端/桌面两档），由调用方按当前
 *  metrics 传进来——窗口变宽时编辑器重建样式对象即可，不必重建 session。 */
export function richEditorStyles(metrics: {
  fontSize: number;
  lineHeight: number;
}): RichEditorStyles {
  return {
    root: {
      flex: 1,
      backgroundColor: colors.paper,
      borderRadius: radii.md,
    },
    content: {
      color: colors.ink,
      fontSize: metrics.fontSize,
      lineHeight: metrics.lineHeight,
      paddingHorizontal: 0,
      paddingVertical: 0,
    },
    caret: { backgroundColor: colors.ink },
    selection: { backgroundColor: colors.surfaceLow },
    placeholder: { color: colors.mutedInk },
    nodes: {
      paragraph: {
        color: colors.ink,
        fontSize: metrics.fontSize,
        lineHeight: metrics.lineHeight,
      },
      "heading[level=1]": {
        color: colors.ink,
        fontWeight: "700",
        fontSize: metrics.fontSize + 8,
        lineHeight: metrics.lineHeight + 10,
      },
      "heading[level=2]": {
        color: colors.ink,
        fontWeight: "700",
        fontSize: metrics.fontSize + 4,
        lineHeight: metrics.lineHeight + 8,
      },
      heading: {
        color: colors.ink,
        fontWeight: "600",
        fontSize: metrics.fontSize + 2,
        lineHeight: metrics.lineHeight + 6,
      },
      codeBlock: {
        color: colors.ink,
        backgroundColor: colors.surfaceLow,
        fontSize: metrics.fontSize - 1,
      },
      blockquote: {
        color: colors.mutedInk,
      },
    },
    marks: {
      bold: { fontWeight: "700" },
      italic: { fontStyle: "italic" },
      code: {
        color: colors.ink,
        backgroundColor: colors.surfaceLow,
        fontSize: metrics.fontSize - 1,
      },
      link: {
        color: colors.accent,
        textDecorationLine: "underline",
      },
      strike: { textDecorationLine: "line-through" },
      underline: { textDecorationLine: "underline" },
    },
  };
}
