// 施工方案 3.9 性能基线复测：真 Tiptap + jsdom，对照 V4 探针基线。
// 测三件（与 spike/nsh-probe/web-editor/src/v4-perf.mjs 同口径）：
//   ① markdown ~5 万字 setContent 耗时
//   ② 单字符插入延迟（3 点取中位）
//   ③ getMarkdown 回写耗时（autosave 路径）
// ⚠️ jsdom 比真 WebView2(Chromium) 慢——数字是「jsdom 量级」，绝对值偏大，
//    只对照相对量级；真 WebView2 实测需 `nsh package` 出包 + 真窗口跑（记为需真机）。
// V4 基线（同 Node+jsdom，探针记录）：setContent 79ms / 输入 12.4ms / getMarkdown 21ms。
// 本文件以 node:test 断言「脚本可跑通且产出三项计时」，真实数字打进 stdout 供 executor.md 引用。
import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { JSDOM } from 'jsdom';

const dom = new JSDOM('<!doctype html><html><body></body></html>', {
  url: 'http://localhost/',
});
const w = dom.window as unknown as Record<string, unknown>;
(globalThis as Record<string, unknown>).window = w;
(globalThis as Record<string, unknown>).document = w.document;
Object.defineProperty(globalThis, 'navigator', {
  value: w.navigator,
  configurable: true,
  writable: true,
});
(globalThis as Record<string, unknown>).DOMParser = w.DOMParser;
(globalThis as Record<string, unknown>).HTMLElement = w.HTMLElement;
(globalThis as Record<string, unknown>).Node = w.Node;
(globalThis as Record<string, unknown>).getSelection = (
  w.getSelection as () => unknown
).bind(w);
(globalThis as Record<string, unknown>).MutationObserver = w.MutationObserver;

// 与 index.ts 完全一致的扩展集（3.5 groupDelay + 软换行/表格/图片扩展）。
const { Editor } = await import('@tiptap/core');
const { default: StarterKit } = await import('@tiptap/starter-kit');
const { Markdown } = await import('tiptap-markdown');
const { Table } = await import('@tiptap/extension-table');
const { TableRow } = await import('@tiptap/extension-table-row');
const { TableHeader } = await import('@tiptap/extension-table-header');
const { TableCell } = await import('@tiptap/extension-table-cell');
const { Image } = await import('@tiptap/extension-image');
const { HardBreak } = await import('@tiptap/extension-hard-break');

// V4 基线（spike/nsh-probe v4-perf.mjs 记录值，同 Node+jsdom 口径）。
const V4 = { setContent: 79, typeChar: 12.4, getMarkdown: 21 } as const;

const wait = (ms: number) => new Promise((r) => setTimeout(r, ms));

let editor: InstanceType<typeof Editor>;
let charCount = 0;
let md = '';

before(async () => {
  // ~5 万字现实文档（复用 v4-perf 的块形态：标题+段+列表+引用+代码块）。
  const block = (i: number): string =>
    `## 第 ${i} 节标题\n` +
    `这是第 ${i} 节的正文段落，包含**粗体**、*斜体*和 \`行内代码\`，还有[链接](https://example.com)。\n` +
    `内容继续展开以便逼近真实笔记的密度，中文与 English words 混排，句子长度参差。\n\n` +
    `- 列表项 A${i}\n- 列表项 B${i}\n- 列表项 C${i}\n\n` +
    `> 引用段落 ${i}，用于测试嵌套结构。\n\n` +
    `\`\`\`js\nconst value${i} = ${i};\n\`\`\`\n`;
  let i = 0;
  while (md.length < 50000) md += block(++i);
  charCount = md.length;

  const el = document.createElement('div');
  document.body.appendChild(el);
  editor = new Editor({
    element: el,
    extensions: [
      StarterKit.configure({ history: { groupDelay: 500 }, hardBreak: false }),
      (HardBreak as { extend: (o: object) => unknown }).extend({
        markdown: true,
      }) as never,
      Table.configure({ resizable: false }),
      TableRow,
      TableHeader,
      TableCell,
      Image,
      Markdown.configure({ html: false, tightLists: true }),
    ],
    content: '',
  });
});

describe('3.9 性能基线（jsdom 量级，对照 V4）', () => {
  it('产出 setContent / 单字符输入 / getMarkdown 三项计时', async () => {
    const getMd = (): string =>
      (
        editor.storage as { markdown: { getMarkdown(): string } }
      ).markdown.getMarkdown();

    // ① setContent(5万字)
    const t1 = performance.now();
    editor.commands.setContent(md);
    const tSetContent = performance.now() - t1;
    await wait(30);

    // ② 单字符插入延迟（3 点：头/中/尾）
    const pmLen = editor.state.doc.content.size;
    const positions = [1, Math.floor(pmLen / 2), Math.max(1, pmLen - 2)];
    const typeLatency: number[] = [];
    for (const pos of positions) {
      const s = performance.now();
      editor.commands.insertContentAt(pos, '测');
      await wait(0);
      typeLatency.push(performance.now() - s);
    }
    const typeMedian = [...typeLatency].sort((a, b) => a - b)[1];

    // ③ getMarkdown 回写（autosave 路径）
    const t2 = performance.now();
    const out = getMd();
    const tGetMarkdown = performance.now() - t2;

    // 报告（executor.md 直接引用 stdout 数字）。
    console.log('\n=== 3.9 性能基线（jsdom / Node ' + process.version + '）===');
    console.log(`文档规模: ${charCount} 字符`);
    console.log(
      `setContent(5万字):  ${tSetContent.toFixed(1)} ms   (V4 基线 ${V4.setContent} ms)`,
    );
    console.log(
      `单字符插入(3点):    ${typeLatency.map((v) => v.toFixed(1)).join(' / ')} ms  中位 ${typeMedian.toFixed(1)} ms   (V4 基线 ${V4.typeChar} ms)`,
    );
    console.log(
      `getMarkdown 回写:   ${tGetMarkdown.toFixed(1)} ms  (输出 ${out.length} 字符)   (V4 基线 ${V4.getMarkdown} ms)`,
    );
    console.log(
      '注：jsdom 比真 WebView2(Chromium) 慢，数字为保守下界/量级参考；真性能需真机。',
    );

    // 断言的是「跑通且产出正数计时」，不卡绝对阈值（jsdom 抖动大）。
    assert.ok(charCount >= 50000, '文档未达 5 万字');
    assert.ok(tSetContent > 0, 'setContent 未计时');
    assert.ok(typeMedian > 0, '输入未计时');
    assert.ok(tGetMarkdown > 0, 'getMarkdown 未计时');
    assert.ok(out.length > 0, 'getMarkdown 输出为空');
    // 量级护栏：jsdom 下不应劣化到 V4 的 20 倍以上（防实现引入灾难性回归）。
    assert.ok(
      tSetContent < V4.setContent * 20,
      `setContent ${tSetContent.toFixed(0)}ms 超 V4 基线 20 倍 —— 疑似量级回归`,
    );
  });
});
