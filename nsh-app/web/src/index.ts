// CardMind 编辑器 — Tiptap 前端入口（施工方案 3.1 + 3.2/3.3/3.4/3.6）。
// 挂载 StarterKit + tiptap-markdown 到 #editor；原生↔页走 JSON 消息协议：
//   原生→页  {id, type:"load"|"get-markdown"|"set-tags", ...} → 页回 {id,type:"res"}
//   页→原生  {type:"editor-ready"|"dirty"|"markdown", ...}
// V9 定案：本包绝不引入 loro/WASM —— 同步走原生侧 LoroDoc，web 只编辑。
// 3.6 定案：软换行覆盖保真（见 web/src/protocol.ts 头注）。
import { Editor } from "@tiptap/core";
import StarterKit from "@tiptap/starter-kit";
import { HardBreak } from "@tiptap/extension-hard-break";
import { Image } from "@tiptap/extension-image";
import { Table } from "@tiptap/extension-table";
import { TableCell } from "@tiptap/extension-table-cell";
import { TableHeader } from "@tiptap/extension-table-header";
import { TableRow } from "@tiptap/extension-table-row";
import { Markdown } from "tiptap-markdown";
import {
  AUTOSAVE_DEBOUNCE_MS,
  EVT_DIRTY,
  EVT_MARKDOWN,
  EVT_READY,
  EVT_SELECTION,
  TEXT_BEFORE_CHARS,
  handleEditorMessage,
  linkPrefixFromContext,
  normalizeMarkdownFromEditor,
  normalizeMarkdownToEditor,
  selectionPayload,
} from "./protocol";

declare global {
  interface Window {
    ReactNativeWebView?: { postMessage: (msg: string) => void };
    nsh?: { postMessage: (msg: string) => void };
    __cardmind?: {
      editor: Editor;
      setMarkdown: (md: string) => void;
      getMarkdown: () => string;
      isDirty: () => boolean;
    };
  }
}

/** 页 → 原生消息桥（双兼容：ReactNativeWebView 实测、nsh 文档）。 */
function postToNative(msg: string): boolean {
  const w = window;
  if (w.ReactNativeWebView?.postMessage) {
    w.ReactNativeWebView.postMessage(msg);
    return true;
  }
  if (w.nsh?.postMessage) {
    w.nsh.postMessage(msg);
    return true;
  }
  return false;
}

function postEvent(type: string, extra?: Record<string, unknown>): boolean {
  return postToNative(JSON.stringify({ type, ...extra }));
}

function mount(): void {
  const el = document.getElementById("editor");
  if (!el) return;

  const editor = new Editor({
    element: el,
    extensions: [
      // 3.5：撤销分组延迟 500ms —— 中文 IME 组合/快速输入在一个
      // 窗口内连续产生的多笔事务合并为一步撤销（对齐 Dart/proseMirror 习惯）。
      // 真键名是 `undoRedo:{newGroupDelay}`（StarterKit 3.32：UndoRedo 扩展的
      // option；`history:{groupDelay}` 是死键，被静默忽略、只碰默认 500 才看似对）。
      // hardBreak:false 是为了独立挂带 markdown:true 标记的 HardBreak ——
      // tiptap-markdown 据此把段内 <br> 序列化成「行尾两空格」，配合
      // protocol.hardToSoft 还原软换行（3.6/3.8 全保真链路的一环）。
      StarterKit.configure({
        undoRedo: { newGroupDelay: 500 },
        hardBreak: false,
      }),
      (HardBreak as { extend(o: object): unknown }).extend({
        markdown: true,
      }) as typeof HardBreak,
      Table.configure({ resizable: false }),
      TableRow,
      TableHeader,
      TableCell,
      Image,
      Markdown.configure({ html: false, tightLists: true }),
    ],
    content: "",
    autofocus: "start",
  });

  // ── 3.6 序列化器覆盖（覆盖保真）────────────────────────────────
  // setMarkdown：存储 markdown → 编辑器（软换行→硬换行进 Tiptap）
  const setMarkdown = (md: string): void => {
    editor.commands.setContent(normalizeMarkdownToEditor(md));
  };
  // getMarkdown：编辑器 → 存储 markdown（硬换行→软换行 + [[link]] 还原）
  const getMarkdown = (): string =>
    normalizeMarkdownFromEditor(
      (editor.storage as { markdown: { getMarkdown(): string } }).markdown.getMarkdown(),
    );

  // ── 3.4 dirty/autosave（700ms debounce，对齐 Dart `_scheduleAutosave`）──
  let dirty = false;
  let autosaveTimer: ReturnType<typeof setTimeout> | null = null;
  const scheduleAutosave = (): void => {
    if (autosaveTimer !== null) clearTimeout(autosaveTimer);
    autosaveTimer = setTimeout(() => {
      autosaveTimer = null;
      // autosave 吐 markdown 后页面视为已提交（原生侧再置「已保存」）。
      dirty = false;
      postEvent(EVT_MARKDOWN, { markdown: getMarkdown() });
    }, AUTOSAVE_DEBOUNCE_MS);
  };
  editor.on("update", () => {
    dirty = true;
    postEvent(EVT_DIRTY, { dirty: true });
    scheduleAutosave();
  });

  // ── 3.5 选区 → 原生（标签↔选区联动：原生侧可据选区高亮/挂补全入口）──
  editor.on("selectionUpdate", ({ editor: ed }) => {
    const p = selectionPayload({ editor: ed });
    postEvent(EVT_SELECTION, p);
  });

  // ── 3.5 标签区（最小可用：#tag-strip 渲染当前笔记标签）──
  const tagStrip = document.getElementById("tag-strip");
  const renderTags = (tags: string[]): void => {
    if (!tagStrip) return;
    tagStrip.textContent = "";
    for (const t of tags) {
      const chip = document.createElement("span");
      chip.className = "tag";
      chip.textContent = `#${t}`;
      tagStrip.appendChild(chip);
    }
  };

  // ── 3.2 原生 → 页协议（load / get-markdown / set-tags）─────────
  window.addEventListener("message", (event: MessageEvent) => {
    const data = typeof event.data === "string" ? event.data : "";
    const res = handleEditorMessage(data, {
      onLoad: (markdown) => {
        setMarkdown(markdown);
        dirty = false;
      },
      onGetMarkdown: () => getMarkdown(),
      onSetTags: (tags) => {
        // 3.5：原生 set-tags → 把标签写进页内标签区（最小联动锚点）。
        renderTags(tags);
      },
      onInsertLink: (title) => {
        // 3.5：原生侧 [[ 补全候选被点选 → 把用户已打的「[[prefix」替换成 [[title]]。
        const { from } = editor.state.selection;
        const textBefore = editor.state.doc.textBetween(
          Math.max(0, from - TEXT_BEFORE_CHARS),
          from,
          "\n",
        );
        const prefix = linkPrefixFromContext(textBefore);
        // prefix 非 null 时，回删「[[ + prefix」（2 + prefix.length 个字符）。
        const back = prefix === null ? 0 : prefix.length + 2;
        const chain = editor.chain().focus();
        if (back > 0) chain.deleteRange({ from: from - back, to: from });
        chain.insertContent(`[[${title}]] `).run();
      },
      onPing: () => {
        postToNative("pong");
      },
    });
    if (res !== null) {
      postToNative(JSON.stringify(res));
    }
  });

  // 调试与下一任务的协议入口。
  window.__cardmind = { editor, setMarkdown, getMarkdown, isDirty: () => dirty };

  // ready 握手：证明 bundle 加载、Tiptap 挂载、桥可用。
  const ok = postEvent(EVT_READY);
  if (!ok) {
    // 无桥环境（浏览器直开）：静默继续，编辑器仍可本地用。
    console.warn("[cardmind] native bridge unavailable");
  }
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", mount);
} else {
  mount();
}
