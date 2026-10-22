// 行为断言的 jsdom 挂载器（测试基础设施，不进 bundle）。
//
// 为什么需要它：3.5 的撤销粒度/选区联动此前只靠「web/src 源码正则」断言，
// 错键名（`history:{groupDelay}`）、空桩、删调用留注释都能骗过（审查 D1/D2）。
// 这里把真实生产入口 `web/src/index.ts` 在 jsdom 里例化一次，让断言读
// **真 Editor 实例的 options / 真 postToNative 消息 / 真 #tag-strip DOM**。
//
// 只在 node:test 里用；`esbuild` 从 index.ts 打包，不会引入本文件。
import { JSDOM } from "jsdom";

/** 页→原生消息（JSON 字符串，按发出顺序）。 */
export interface MountedPage {
  window: any;
  document: any;
  /** 真 Tiptap Editor 实例（index.ts 的 window.__cardmind.editor）。 */
  editor: any;
  /** 页→原生消息原文（JSON 字符串）。 */
  posted: string[];
  /** 模拟原生→页：向 window 派发 message 事件。 */
  dispatchToPage(msg: unknown): void;
  /** 已 post 的指定 type 事件（解析后）。 */
  postedEvents(type: string): any[];
  resetPosted(): void;
}

let cached: MountedPage | null = null;

/**
 * 挂载真实编辑器页（幂等：同进程只挂一次）。
 * jsdom 无布局引擎，prosemirror 的 scrollToSelection 会调 getClientRects，
 * 因此桩掉几何 API；requestAnimationFrame 用 setTimeout 兜底（autofocus 用）。
 */
export async function mountEditorPage(): Promise<MountedPage> {
  if (cached) return cached;

  const dom = new JSDOM(
    '<!doctype html><html><body><div id="editor"></div><div id="tag-strip"></div></body></html>',
    { url: "http://localhost/" },
  );
  const w = dom.window as any;
  const posted: string[] = [];
  w.ReactNativeWebView = { postMessage: (m: string) => posted.push(m) };

  const zeroRect = {
    x: 0, y: 0, width: 0, height: 0,
    top: 0, left: 0, right: 0, bottom: 0,
  };
  w.Element.prototype.getClientRects = () => [];
  w.Element.prototype.getBoundingClientRect = () => zeroRect;
  w.Range.prototype.getClientRects = () => [];
  w.Range.prototype.getBoundingClientRect = () => zeroRect;

  const g = globalThis as any;
  g.window = w;
  g.document = w.document;
  Object.defineProperty(g, "navigator", {
    value: w.navigator,
    configurable: true,
    writable: true,
  });
  g.DOMParser = w.DOMParser;
  g.HTMLElement = w.HTMLElement;
  g.Node = w.Node;
  g.getSelection = w.getSelection.bind(w);
  g.MutationObserver = w.MutationObserver;
  g.requestAnimationFrame = (cb: (t: number) => void) => setTimeout(() => cb(Date.now()), 0);
  g.cancelAnimationFrame = (id: any) => clearTimeout(id);

  // 动态 import：必须在 jsdom 全局挂好之后再加载 @tiptap/*。
  await import("./index.ts");

  const editor = w.__cardmind?.editor;
  if (!editor) throw new Error("index.ts 未挂载编辑器（window.__cardmind.editor 缺失）");

  const page: MountedPage = {
    window: w,
    document: w.document,
    editor,
    posted,
    dispatchToPage(msg: unknown) {
      w.dispatchEvent(
        new w.MessageEvent("message", {
          data: typeof msg === "string" ? msg : JSON.stringify(msg),
        }),
      );
    },
    postedEvents(type: string) {
      return posted
        .map((raw) => {
          try {
            return JSON.parse(raw) as Record<string, unknown>;
          } catch {
            return null;
          }
        })
        .filter((m): m is Record<string, unknown> => m !== null && m.type === type);
    },
    resetPosted() {
      posted.length = 0;
    },
  };
  cached = page;
  return page;
}
