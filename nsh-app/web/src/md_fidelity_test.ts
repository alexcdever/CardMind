// 施工方案 3.8 自动化验收：真 Tiptap（jsdom）markdown 往返全保真。
// 覆盖 task.md 标准 3 —— 12 类结构 + [[id|alias]] + 软换行 + 幂等。
// 与 index.ts 保持同一扩展集：StarterKit(groupDelay) + 独立 HardBreak
// （软换行进 <br>）+ Table* + Image + tiptap-markdown，进出走 protocol.ts
// 的 normalizeMarkdownToEditor / normalizeMarkdownFromEditor 覆盖层。
// 注意：jsdom 无 IME/真实选区 —— IME 组合输入与跨块选区属真 WebView2 实测。
import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { JSDOM } from 'jsdom';
import {
  normalizeMarkdownFromEditor,
  normalizeMarkdownToEditor,
} from './protocol.ts';

// jsdom → 全局 DOM（必须在 import @tiptap/* 之前挂好，故用动态 import）。
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

type EditorLike = {
  commands: { setContent: (md: string) => void };
  storage: { markdown: { getMarkdown: () => string } };
};
let editor: EditorLike;

before(async () => {
  const { Editor } = await import('@tiptap/core');
  const { default: StarterKit } = await import('@tiptap/starter-kit');
  const { Markdown } = await import('tiptap-markdown');
  const { Table } = await import('@tiptap/extension-table');
  const { TableRow } = await import('@tiptap/extension-table-row');
  const { TableHeader } = await import('@tiptap/extension-table-header');
  const { TableCell } = await import('@tiptap/extension-table-cell');
  const { Image } = await import('@tiptap/extension-image');
  const { HardBreak } = await import('@tiptap/extension-hard-break');
  const el = document.createElement('div');
  document.body.appendChild(el);
  editor = new Editor({
    element: el,
    extensions: [
      StarterKit.configure({ history: { groupDelay: 500 }, hardBreak: false }),
      // 独立挂 HardBreak 并标记 markdown:true —— tiptap-markdown 据此把
      // hardBreak 序列化成「行尾两空格」，出层 hardToSoft 还原软换行。
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      (HardBreak as any).extend({ markdown: true }),
      Table.configure({ resizable: false }),
      TableRow,
      TableHeader,
      TableCell,
      Image,
      Markdown.configure({ html: false, tightLists: true }),
    ],
    content: '',
  }) as unknown as EditorLike;
});

const setMarkdown = (md: string): void => {
  editor.commands.setContent(normalizeMarkdownToEditor(md));
};
const getMarkdown = (): string =>
  normalizeMarkdownFromEditor(editor.storage.markdown.getMarkdown());
const norm = (s: string): string =>
  s.replace(/\r\n/g, '\n').replace(/[ \t]+$/gm, '').replace(/\n{3,}/g, '\n\n').trim();

// 12 类结构 + [[id|alias]] + 软换行（参照 v9-md-fidelity.mjs / v9b 范围）。
// 表格分隔行按 markdown-it 序列化形态写「| --- | --- |」（保真 = 语义等价）。
const CASES: Array<[string, string]> = [
  ['标题', '# 一级\n\n## 二级\n\n### 三级'],
  ['行内样式', '这是**粗体**、*斜体*、`行内代码`、~~删除线~~。'],
  ['链接', '看[这个链接](https://example.com/a?b=1#c)。'],
  ['无序列表', '- 一\n- 二\n  - 二点一\n- 三'],
  ['有序列表', '1. 甲\n2. 乙\n3. 丙'],
  ['引用', '> 引用一行\n> 引用二行'],
  ['代码块', '```js\nconst x = 1;\nfunction f() { return x; }\n```'],
  ['表格', '| 列A | 列B |\n| --- | --- |\n| 1 | 2 |'],
  ['图片', '![图](/a.png)'],
  [
    '组合',
    '# 标题\n\n段落**粗**。\n\n- 项目\n\n> 引用\n\n```py\nx=1\n```',
  ],
  ['中文标点', '他说：「好的。」然后走了——就这样……'],
  ['Emoji', '表情 😀🎉 与符号 ±×÷'],
  ['双向链接[[id|alias]]', '见 [[abc123|别名]] 与 [[def456]]。'],
  ['软换行', '行一\n行二\n\n块二'],
];

describe('3.8 真 Tiptap(jsdom) markdown 往返保真', () => {
  for (const [name, md] of CASES) {
    it(`首次往返保真：${name}`, () => {
      setMarkdown(md);
      assert.equal(
        norm(getMarkdown()),
        norm(md),
        `往返失真：${name}\n  入:${JSON.stringify(norm(md))}\n  出:${JSON.stringify(norm(getMarkdown()))}`,
      );
    });
  }

  for (const [name, md] of CASES) {
    it(`幂等：${name}（再往返一次不变）`, () => {
      setMarkdown(md);
      const once = getMarkdown();
      setMarkdown(once);
      assert.equal(norm(getMarkdown()), norm(once), `幂等失败：${name}`);
    });
  }

  it('[[id|alias]] 字面保留（Rust parse_links_from_content 纯文本扫描契约）', () => {
    const md = '见 [[note-123|另一篇]] 的结论，再回到 [[note-123]]。';
    setMarkdown(md);
    const out = getMarkdown();
    const inLinks = md.match(/\[\[[^\]]*\]\]/g)?.sort();
    const outLinks = out.match(/\[\[[^\]]*\]\]/g)?.sort();
    assert.deepEqual(outLinks, inLinks, '[[...]] 字面量被破坏');
    assert.doesNotMatch(out, /\\\[/, '输出含转义方括号 \\[');
  });

  it('setMarkdown/getMarkdown 幂等：重复 set 同一 md 输出稳定', () => {
    const md = '# 幂等\n\n正文 [[a|B]]。\n\n- 项';
    setMarkdown(md);
    const a = getMarkdown();
    setMarkdown(md);
    assert.equal(getMarkdown(), a);
  });
});
