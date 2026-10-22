// CardMind 编辑器 — Tiptap 前端入口（施工方案 3.1）。
// 挂载 StarterKit + tiptap-markdown 到 #editor；完成后向原生发
// "editor-ready" 握手（ReactNativeWebView.postMessage，0.1.1 实测可用；
// 文档中的 window.nsh 留作回退）。
// V9 定案：本包绝不引入 loro/WASM —— 同步走原生侧 LoroDoc，web 只编辑。
import { Editor } from "@tiptap/core";
import StarterKit from "@tiptap/starter-kit";
import { Markdown } from "tiptap-markdown";

declare global {
  interface Window {
    ReactNativeWebView?: { postMessage: (msg: string) => void };
    nsh?: { postMessage: (msg: string) => void };
    __cardmind?: { editor: Editor };
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

  // 原生 → 页通道（下一任务的 markdown 进出协议挂这里；本任务仅桩）。
  window.addEventListener("message", (event: MessageEvent) => {
    const data = typeof event.data === "string" ? event.data : "";
    if (data === "ping") {
      postToNative("pong");
    }
    // nsh-editor-io：load-note / note-update / flush-markdown 等从此分发。
  });

  // 调试与下一任务的协议入口。
  window.__cardmind = { editor };

  // ready 握手：证明 bundle 加载、Tiptap 挂载、桥可用。
  const ok = postToNative("editor-ready");
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
