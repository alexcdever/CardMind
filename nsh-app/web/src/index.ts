// CardMind 编辑器 — Tiptap 前端入口（施工方案 3.1 + 3.2/3.3/3.4/3.6）。
// 挂载 StarterKit + tiptap-markdown 到 #editor；原生↔页走 JSON 消息协议：
//   原生→页  {id, type:"load"|"get-markdown"|"set-tags", ...} → 页回 {id,type:"res"}
//   页→原生  {type:"editor-ready"|"dirty"|"markdown", ...}
// V9 定案：本包绝不引入 loro/WASM —— 同步走原生侧 LoroDoc，web 只编辑。
// 3.6 定案：软换行覆盖保真（见 web/src/protocol.ts 头注）。
import { Editor } from "@tiptap/core";
import StarterKit from "@tiptap/starter-kit";
import { Markdown } from "tiptap-markdown";
import {
  AUTOSAVE_DEBOUNCE_MS,
  EVT_DIRTY,
  EVT_MARKDOWN,
  EVT_READY,
  handleEditorMessage,
  normalizeMarkdownFromEditor,
  normalizeMarkdownToEditor,
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
      StarterKit,
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

  // ── 3.2 原生 → 页协议（load / get-markdown / set-tags）─────────
  window.addEventListener("message", (event: MessageEvent) => {
    const data = typeof event.data === "string" ? event.data : "";
    const res = handleEditorMessage(data, {
      onLoad: (markdown) => {
        setMarkdown(markdown);
        dirty = false;
      },
      onGetMarkdown: () => getMarkdown(),
      onSetTags: () => {
        // 标签联动桩：下一任务（3.5 selection/标签）接管。
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
