// CardMind 编辑器页内协议层（施工方案 3.2 + 3.6）。
//
// ── 3.2 消息协议 ──
// 页↔原生全走 JSON `{id?, type, ...}`：
//   请求（原生→页）：{id, type:"load"|"get-markdown"|"set-tags", ...}
//   响应（页→原生）：{id, type:"res", ok, markdown?|error?}
//   事件（页→原生）：{type:"editor-ready"|"dirty"|"markdown"|"selection", ...}
// 每个请求 id 挂 8s 超时（PROTO_TIMEOUT_MS），原生侧配对回应。
//
// ── 3.6 软换行覆盖（已定案：覆盖保真）──
// tiptap-markdown/markdown-it 默认把段内 `\n`（软换行）渲染成空格，出序列化
// 也只写 `\\\n` 或 `  \n` 硬换行——`行一\n行二` 会丢成 `行一 行二`。
// 覆盖方案：
//   进 softToHard：段内单 `\n` → `  \n`（CommonMark 硬换行），编辑器得到
//                  `<br>`，视觉保留换行；块间 `\n\n` 不动。
//   出 hardToSoft：`  \n` / `\\\n` → `\n`，写回存储仍是软换行。
//   unescapeBrackets：markdown-it 会把 `[[x|y]]` 转义成 `\[\[x|y\]\]`，还原
//                  之；CardMind 的双向链接靠纯文本 `[[id|alias]]` 扫描。
// 探针验证（spike/nsh-probe v3）：10/10 首次往返 + 10/10 幂等。

/** 请求超时（ms）：原生侧 sendRequest 等待 res 的最长时间。 */
export const PROTO_TIMEOUT_MS = 8000;

/** 页→原生事件类型。 */
export const EVT_READY = "editor-ready";
export const EVT_DIRTY = "dirty";
export const EVT_MARKDOWN = "markdown";
export const EVT_SELECTION = "selection";

/** 原生→页请求类型。 */
export const REQ_LOAD = "load";
export const REQ_GET_MARKDOWN = "get-markdown";
export const REQ_SET_TAGS = "set-tags";
/** 原生→页：在光标处插入 [[title]]（3.5 补全候选 chip 的落点，见 index.ts）。 */
export const REQ_INSERT_LINK = "insert-link";

/** 响应类型。 */
export const RES = "res";

/** autosave 防抖（ms），对齐 Dart `_scheduleAutosave` 的 700ms。 */
export const AUTOSAVE_DEBOUNCE_MS = 700;

export interface EditorRequest {
  id?: number | string;
  type: string;
  markdown?: string;
  tags?: string[];
  /** insert-link 请求：要插入为 [[title]] 的链接标题。 */
  title?: string;
}

export interface EditorResponse {
  id?: number | string;
  type: typeof RES;
  ok: boolean;
  markdown?: string;
  error?: string;
}

export interface EditorEvent {
  type: string;
  dirty?: boolean;
  markdown?: string;
  /** selection 事件：选区锚点/头（3.5 标签↔选区联动）。 */
  from?: number;
  to?: number;
  /** 选区文本；折叠（光标）时恒为 ""（语义：无选中内容）。 */
  text?: string;
  /** 光标前最近一段文本（≤40 字符）—— 原生侧探测 [[prefix 补全的输入信号。
   *  折叠选区 text 恒 ""（正常打字），若无此字段 [[ 补全永不触发（D5）。 */
  textBefore?: string;
  [key: string]: unknown;
}

/** selection 事件里带的「光标前文本」窗口大小（字符数）。
 *  `[[prefix` 补全只需要探测最近一小段，40 足够且不拖大 payload。 */
export const TEXT_BEFORE_CHARS = 40;

/** selectionUpdate → 页→原生 selection 事件的 payload 形态。
 *  入参是 Tiptap selectionUpdate 回调拿到的 { editor }（或含 state 的任意对象），
 *  抽出 from/to/text 三字段供 postToNative。
 *
 *  text    = 选区文本（折叠时 ""）；
 *  textBefore = 光标前最近 TEXT_BEFORE_CHARS 个字符（原生侧 [[ 补全的输入信号，D5）。 */
export function selectionPayload(source: {
  state?: { selection?: { from?: number; to?: number } };
  editor?: {
    state: {
      selection: { from: number; to: number; empty?: boolean };
      doc: { textBetween: (from: number, to: number, sep?: string) => string };
    };
  };
}): { from: number; to: number; text: string; textBefore: string } {
  const ed = source.editor;
  if (ed?.state?.selection) {
    const { from, to } = ed.state.selection;
    const text =
      from === to ? '' : ed.state.doc.textBetween(from, to, ' ');
    // textBetween(0, pos) 在文档起点处也能工作，故光标在文首时安全。
    const textBefore = ed.state.doc.textBetween(
      Math.max(0, from - TEXT_BEFORE_CHARS),
      from,
      '\n',
    );
    return { from, to, text, textBefore };
  }
  const sel = source.state?.selection;
  return {
    from: sel?.from ?? 0,
    to: sel?.to ?? 0,
    text: '',
    textBefore: '',
  };
}

/** 从光标前文本里抓「未闭合的 [[prefix」——`[[` 补全的触发信号。
 *  只认 `textBefore`（光标前）：已闭合的 `[[x]]`、普通选中文字不触发。
 *  返回 null = 不触发；返回前缀串（可为 ""，即刚输入 `[[`）= 触发 autoCompleteLinks。 */
export function linkPrefixFromContext(textBefore: string): string | null {
  const m = textBefore.match(/\[\[([^\[\]\|\n]*)$/);
  return m ? m[1] : null;
}

/** 标签高亮命中：只有标签名命中 `[[prefix` 或完整等于选中文本才高亮。
 *  旧实现是「任一 selection 事件高亮全部 tag」（D7）；这里按命中过滤。
 *  命中规则（按序）：① 若光标前有未闭合 `[[p`，命中 tag.startsWith(p)（大小写不敏感）；
 *  ② 否则若选中文本非空，命中 tag 等于选中文本（trim 后）；
 *  ③ 否则不高亮。 */
export function matchTags(
  tags: string[],
  selection: { text?: string; textBefore?: string },
): string[] {
  const prefix = linkPrefixFromContext(selection.textBefore ?? '');
  if (prefix !== null) {
    const p = prefix.toLowerCase();
    return tags.filter((t) => t.toLowerCase().startsWith(p));
  }
  const sel = (selection.text ?? '').trim();
  if (sel !== '') {
    return tags.filter((t) => t === sel);
  }
  return [];
}

/** 进：markdown 段内软换行 → CommonMark 硬换行（行尾两空格）。 */
export function softToHard(md: string): string {
  return md.replace(/([^\n])\n(?!\n)/g, (_m, ch: string) => `${ch}  \n`);
}

/** 出：CommonMark 硬换行（"  \n" 或 "\\\n"）→ 软换行。 */
export function hardToSoft(md: string): string {
  return md.replace(/[ \t]+\n/g, "\n").replace(/\\\n/g, "\n");
}

/** 出：markdown-it 转义的 `\[`/`\]` 还原，保 `[[id|alias]]` 字面量。 */
export function unescapeBrackets(md: string): string {
  return md.replace(/\\(\[|\])/g, "$1");
}

/** 编辑器输出 → 存回存储的 markdown（硬换行→软换行 + 方括号还原）。 */
export function normalizeMarkdownFromEditor(raw: string): string {
  return unescapeBrackets(hardToSoft(raw)).replace(/\n{3,}/g, "\n\n");
}

/** 存储 markdown → 喂给编辑器的形态（软换行→硬换行）。 */
export function normalizeMarkdownToEditor(md: string): string {
  return softToHard(md);
}

/**
 * 页内请求分发：把原生下发的 JSON 请求映射成 EditorResponse。
 * `handlers` 由各调用方（index.ts）注入真正的编辑器操作。
 */
export function handleEditorMessage(
  raw: string,
  handlers: {
    onLoad?: (markdown: string) => void;
    onGetMarkdown?: () => string;
    onSetTags?: (tags: string[]) => void;
    /** 原生侧 [[ 补全候选被点选后，页内在光标处插入 [[title]]。 */
    onInsertLink?: (title: string) => void;
    onPing?: () => void;
  },
): EditorResponse | null {
  let msg: EditorRequest;
  try {
    msg = JSON.parse(raw) as EditorRequest;
  } catch {
    // 兼容裸字符串握手（上一任务遗留 ping/editor-ready 形态）。
    if (raw === "ping") {
      handlers.onPing?.();
      return null;
    }
    return { type: RES, ok: false, error: `bad-json:${raw.slice(0, 32)}` };
  }

  switch (msg.type) {
    case REQ_LOAD:
      handlers.onLoad?.(msg.markdown ?? "");
      return { id: msg.id, type: RES, ok: true };
    case REQ_GET_MARKDOWN: {
      const markdown = handlers.onGetMarkdown?.() ?? "";
      return { id: msg.id, type: RES, ok: true, markdown };
    }
    case REQ_SET_TAGS:
      handlers.onSetTags?.(msg.tags ?? []);
      return { id: msg.id, type: RES, ok: true };
    case REQ_INSERT_LINK: {
      const title = msg.title;
      if (typeof title !== "string" || title.length === 0) {
        return {
          id: msg.id,
          type: RES,
          ok: false,
          error: "insert-link:missing-title",
        };
      }
      handlers.onInsertLink?.(title);
      return { id: msg.id, type: RES, ok: true };
    }
    default:
      return {
        id: msg.id,
        type: RES,
        ok: false,
        error: `unknown-type:${msg.type}`,
      };
  }
}
