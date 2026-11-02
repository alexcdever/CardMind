// CardMind 编辑器纯文本工具（从 web/src/protocol.ts 迁入的 DOM-free 部分）。
//
// 只放不依赖 DOM / NSH 引擎的纯函数：`[[prefix` 探测、标签高亮命中、编辑器
// `{line,column}`（UTF-16）与本地 text 的 offset 互换、候选替换 range。
// `editor_text_test.ts` 用 node:test 覆盖；`editor_page.tsx` 与 `EditorHarness.tsx`
// 只调用这里的函数，不再有 soft/hard 换行与方括号转义那套有损归一化。

/** 光标前文本窗口（字符数）：`[[prefix` 补全只需最近 40 个 UTF-16 code unit。 */
export const TEXT_BEFORE_CHARS = 40;

/** 自动保存防抖（ms），沿用旧编辑器的 700ms（06 §2.3）。 */
export const AUTOSAVE_DEBOUNCE_MS = 700;

/** 加载 noteGet 的超时（ms）：超时按加载失败处理，不挂 Editor、不落盘。 */
export const LOAD_TIMEOUT_MS = 10_000;

/** 草稿/新笔记的 noteId 占位（沿用旧 `App.tsx` 的约定）。 */
export const NEW_NOTE_IDS: readonly string[] = ['', 'new'];

/** 编辑器位置（0 起；column 按 UTF-16 code unit，与 0.3.0 `EditorPosition` 一致）。 */
export interface TextPosition {
  line: number;
  column: number;
}

/** 文本内 offset 范围（UTF-16；end 不含）。 */
export interface TextRange {
  start: number;
  end: number;
}

/** `[[id|title]]` 补全候选（只依赖 id/title，不绑 NoteDto）。 */
export interface WikiCandidate {
  id: string;
  title: string;
}

/** 选区上下文：光标前窗口 + 当前选中文本（折叠时为空串）。 */
export interface SelectionContext {
  /** head（主选区活动端）的 UTF-16 offset。 */
  offset: number;
  /** 光标前最近 `TEXT_BEFORE_CHARS` 个字符。 */
  textBefore: string;
  /** anchor..head 的选中文本；折叠光标为 ""。 */
  selected: string;
}

/** 从光标前文本里抓「未闭合的 `[[prefix`」——`[[` 补全的触发信号。
 *  只认 `textBefore`；已闭合 `[[x]]`、`[[x|y`、跨行都不触发。
 *  null = 不触发；返回前缀串（可为 ""，即刚输入 `[[`）。 */
export function linkPrefixFromContext(textBefore: string): string | null {
  const match = textBefore.match(/\[\[([^\[\]\|\n]*)$/);
  return match ? match[1] : null;
}

/** 标签高亮命中：光标前有未闭合 `[[p` 时命中 `tag.startsWith(p)`（大小写不敏感）；
 *  否则选中文本非空时命中与选中文本完全相等的 tag；其余不高亮。 */
export function matchTags(
  tags: string[],
  selection: { text?: string; textBefore?: string },
): string[] {
  const prefix = linkPrefixFromContext(selection.textBefore ?? '');
  if (prefix !== null) {
    const p = prefix.toLowerCase();
    return tags.filter((tag) => tag.toLowerCase().startsWith(p));
  }
  const selected = (selection.text ?? '').trim();
  if (selected !== '') {
    return tags.filter((tag) => tag === selected);
  }
  return [];
}

/** 每行起始 offset 的行首表（UTF-16；最后一项 = 末行起点）。 */
export function lineStartOffsets(text: string): number[] {
  const starts = [0];
  for (let index = 0; index < text.length; index += 1) {
    if (text[index] === '\n') starts.push(index + 1);
  }
  return starts;
}

/** `{line,column}` → UTF-16 offset；越界 line/column 收敛到文本范围内
 *  （column 不跨过该行行尾换行符）。 */
export function positionToOffset(text: string, position: TextPosition): number {
  const starts = lineStartOffsets(text);
  const line = Math.max(0, Math.min(Math.trunc(position.line), starts.length - 1));
  const start = starts[line];
  const lineEnd = line + 1 < starts.length ? starts[line + 1] - 1 : text.length;
  const column = Math.max(0, Math.trunc(position.column));
  return Math.max(0, Math.min(start + column, lineEnd));
}

/** UTF-16 offset → `{line,column}`；越界收敛到文本末尾/开头。 */
export function offsetToPosition(text: string, offset: number): TextPosition {
  const target = Math.max(0, Math.min(Math.trunc(offset), text.length));
  const starts = lineStartOffsets(text);
  let line = starts.length - 1;
  while (line > 0 && starts[line] > target) line -= 1;
  return { line, column: target - starts[line] };
}

/** 候选点选时要替换的范围：把已输入的 `[[` + prefix 整段换掉。
 *  start = offset - 2 - prefix.length（收敛到 0），end = 光标 offset。 */
export function completionOffsets(offset: number, prefix: string): TextRange {
  const safeOffset = Math.max(0, Math.trunc(offset));
  return {
    start: Math.max(0, safeOffset - 2 - prefix.length),
    end: safeOffset,
  };
}

/** 候选插入文本：`[[id|title]] `（Rust `parse_links` 可按 `|` 拆出 id/alias；
 *  尾随空格让光标离开 `]]`，便于继续输入）。 */
export function wikilinkText(candidate: WikiCandidate): string {
  return `[[${candidate.id}|${candidate.title}]] `;
}

/** 由 anchor/head 两个位置算出选区上下文（offset 按 head，selected 按范围）。 */
export function selectionContext(
  text: string,
  anchor: TextPosition,
  head: TextPosition,
): SelectionContext {
  const offset = positionToOffset(text, head);
  const anchorOffset = positionToOffset(text, anchor);
  const selected =
    anchorOffset === offset
      ? ''
      : text.slice(Math.min(anchorOffset, offset), Math.max(anchorOffset, offset));
  return {
    offset,
    textBefore: text.slice(Math.max(0, offset - TEXT_BEFORE_CHARS), offset),
    selected,
  };
}

/** `searchByTag("")` 返回的逗号分隔标签串 → 标签数组（trim、丢空项、保序）。 */
export function tagsFromCsv(csv: string | null | undefined): string[] {
  if (typeof csv !== 'string') return [];
  return csv
    .split(',')
    .map((tag) => tag.trim())
    .filter((tag) => tag.length > 0);
}

/** `Editor.onChange` 的取值兼容：0.3.0 签名是 `(value: string)`；运行时若给
 *  事件对象 `{ value }` 也接住；其余非法值返回 ""（不把 undefined 写进文档）。 */
export function textOfChange(value: unknown): string {
  if (typeof value === 'string') return value;
  if (
    value !== null &&
    typeof value === 'object' &&
    typeof (value as { value?: unknown }).value === 'string'
  ) {
    return (value as { value: string }).value;
  }
  return '';
}

/** 换行归一：`\r\n`/`\r` → `\n`。这是 0.3.0 `Editor.value()` 唯一允许的归一
 *  （05 §1.2），App 侧对加载文本做同一归一，好让「未编辑的 CRLF 笔记」不被误判
 *  为 dirty（否则一打开就会回写一次）。其余字符（`[[id|alias]]`、空行、代码块、
 *  段内换行、中文）一律逐字节保留。 */
export function normalizeNewlines(text: string): string {
  return text.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
}
