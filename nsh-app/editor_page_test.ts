// 施工方案 3.1 + 3.7 验收测试（task.md 标准 2/3/4）：读文件断言。
//
// 断言面：
//  ① web/dist/bundle.js 存在且非空（esbuild 产物）；
//  ② index.html 挂载点 #editor + 引用 bundle；
//  ③ web 前端源码含 Tiptap（@tiptap/core + @tiptap/starter-kit）与
//     tiptap-markdown 引用；
//  ④ web 源码/依赖不含 loro（V9 定案：web 侧零 WASM/CRDT）—— import 行
//     与 package.json deps 都不得出现 loro；
//  ⑤ App.tsx EditorScreen 真接 nsh/webview：import WebView、
//     source={{ html, baseUrl }}、onMessage editor-ready 握手、noteId 保留。
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
// 行为断言：在 jsdom 里例化真实生产入口 web/src/index.ts（见 web/src/editor_mount.ts）。
import { mountEditorPage } from './web/src/editor_mount.ts';

const here = path.dirname(fileURLToPath(import.meta.url));
const read = (rel: string) => readFileSync(path.join(here, rel), 'utf8');

const WEB_DIR = path.join(here, 'web');
const BUNDLE = path.join(WEB_DIR, 'dist', 'bundle.js');
const INDEX_HTML = path.join(WEB_DIR, 'index.html');
const WEB_SRC_DIR = path.join(WEB_DIR, 'src');

const webSrcFiles = existsSync(WEB_SRC_DIR)
  ? readdirSync(WEB_SRC_DIR).filter(
      // 排除 *_test.ts：否则测试文件自身的源码也能满足「源码含 X」断言
      // （审查缺陷 D1：红提交里 groupDelay 断言被测试文件自己满足）。
      (f) => /\.(ts|js|tsx|jsx)$/.test(f) && !/_test\.(ts|js)$/.test(f),
    )
  : [];
const webSrc = webSrcFiles.map((f) => read(path.join('web', 'src', f))).join('\n');
const indexHtml = existsSync(INDEX_HTML) ? read(path.join('web', 'index.html')) : '';
const app = read('App.tsx');
const pkg = JSON.parse(read('package.json')) as {
  dependencies?: Record<string, string>;
  devDependencies?: Record<string, string>;
};

/** 去掉行注释/块注释后的代码（查 import 是否真引 loro）。 */
const codeOnly = (src: string) =>
  src.replace(/\/\/[^\n]*/g, '').replace(/\/\*[\s\S]*?\*\//g, '');

describe('3.1 web/dist 构建产物', () => {
  it('web/dist/bundle.js 存在且非空（>100KB：真 Tiptap 打包而非骨架）', () => {
    assert.ok(existsSync(BUNDLE), 'web/dist/bundle.js 不存在 — npm run build:web 未跑');
    const size = statSync(BUNDLE).size;
    assert.ok(size > 0, 'web/dist/bundle.js 为空');
    assert.ok(
      size > 100 * 1024,
      `bundle.js 仅 ${size}B —— 真 Tiptap 打包应 >100KB，疑似骨架产物`,
    );
  });

  it('产物不含 loro/WASM（grep loro 0 命中）', () => {
    if (!existsSync(BUNDLE)) return; // 上一条已报缺失
    const bundle = readFileSync(BUNDLE, 'utf8');
    assert.equal(
      bundle.match(/loro/gi)?.length ?? 0,
      0,
      'web/dist/bundle.js 含 loro 引用 —— V9 定案禁止 web 侧 WASM/CRDT',
    );
  });
});

describe('3.1 index.html 挂载点', () => {
  it('#editor 挂载点存在', () => {
    assert.ok(existsSync(INDEX_HTML), 'web/index.html 不存在');
    assert.match(indexHtml, /id=["']editor["']/, 'index.html 缺 <div id="editor">');
  });

  it('引用 bundle（./dist/bundle.js 或内联 script）', () => {
    assert.match(
      indexHtml,
      /(dist\/bundle\.js|<script[\s\S]*?[\s\S]{200,}[\s\S]*?<\/script>)/,
      'index.html 既不引 ./dist/bundle.js 也无内联 bundle',
    );
  });
});

describe('3.1 web 前端源码：Tiptap + tiptap-markdown', () => {
  it('web/src 下有源码文件', () => {
    assert.ok(webSrcFiles.length > 0, 'web/src/ 无 .ts/.js 源码');
  });

  it('引用 @tiptap/core（Editor）', () => {
    assert.match(
      codeOnly(webSrc),
      /from\s+['"]@tiptap\/core['"]/,
      'web 源码未 import @tiptap/core',
    );
  });

  it('引用 @tiptap/starter-kit', () => {
    assert.match(
      codeOnly(webSrc),
      /from\s+['"]@tiptap\/starter-kit['"]/,
      'web 源码未 import @tiptap/starter-kit',
    );
  });

  it('引用 tiptap-markdown（markdown 进出）', () => {
    assert.match(
      codeOnly(webSrc),
      /from\s+['"]tiptap-markdown['"]/,
      'web 源码未 import tiptap-markdown',
    );
  });

  it('package.json deps 含 @tiptap/* 与 tiptap-markdown', () => {
    const deps = { ...pkg.dependencies, ...pkg.devDependencies };
    for (const name of ['@tiptap/core', '@tiptap/starter-kit', 'tiptap-markdown']) {
      assert.ok(deps[name], `package.json 缺依赖 ${name}`);
    }
  });
});

describe('3.1 web 侧零 loro（V9 定案）', () => {
  it('web/src 代码无 loro import（注释豁免）', () => {
    const code = codeOnly(webSrc);
    assert.doesNotMatch(
      code,
      /from\s+['"][^'"]*loro[^'"]*['"]|require\(\s*['"][^'"]*loro/,
      'web 源码含 loro import —— 禁止',
    );
    // 代码体里出现 "loro" 字样也只允许是变量名之外绝无引用
    assert.doesNotMatch(
      code,
      /\bloro[-_]crdt|loro[-_]prosemirror|LoroDoc|LoroSyncPlugin|LoroUndoPlugin/,
      'web 源码引用 loro 符号 —— 禁止',
    );
  });

  it('package.json 全部 deps 无 loro', () => {
    const all = JSON.stringify({
      dependencies: pkg.dependencies ?? {},
      devDependencies: pkg.devDependencies ?? {},
    });
    assert.doesNotMatch(all, /loro/i, 'package.json deps 含 loro —— 禁止');
  });
});

describe('3.7 App.tsx — EditorScreen 接 nsh/webview', () => {
  it('import WebView from nsh/webview', () => {
    assert.match(
      app,
      /import\s*\{[^}]*\bWebView\b[^}]*\}\s*from\s*['"]nsh\/webview['"]/,
      'App.tsx 未 import { WebView } from "nsh/webview"',
    );
  });

  it('EditorScreen 渲染 <WebView>（非占位 Text）', () => {
    const m = app.match(/function\s+EditorScreen[\s\S]*?\n}/);
    const body = m ? m[0] : '';
    assert.match(body, /<WebView\b/, 'EditorScreen 未渲染 <WebView> —— 仍是占位');
  });

  it('source={{ html, baseUrl }} 内联 HTML 形态', () => {
    const m = app.match(/function\s+EditorScreen[\s\S]*?\n}/);
    const body = m ? m[0] : '';
    assert.match(
      body,
      /source=\{\{[^}]*\bhtml\b[^}]*\bbaseUrl\b[^}]*\}\}/,
      'EditorScreen 的 WebView 缺 source={{ html, baseUrl }}',
    );
  });

  it('onMessage 处理 editor-ready 握手', () => {
    const m = app.match(/function\s+EditorScreen[\s\S]*?\n}/);
    const body = m ? m[0] : '';
    assert.match(body, /onMessage=/, 'EditorScreen 的 WebView 缺 onMessage');
    assert.match(
      body,
      /editor-ready|editor_ready|editorReady/i,
      'onMessage 未识别 editor-ready 握手消息',
    );
  });

  it('noteId 仍展示/透传（下一任务 noteGet 加载留口）', () => {
    const m = app.match(/function\s+EditorScreen[\s\S]*?\n}/);
    const body = m ? m[0] : '';
    assert.match(body, /noteId/, 'EditorScreen 丢 noteId');
  });
});

// ── 施工方案 3.2/3.3/3.4/3.6：协议 + markdown 进出 + autosave + 软换行 ──

const PROTOCOL = 'web/src/protocol.ts';
const protocolPath = path.join(WEB_SRC_DIR, 'protocol.ts');
const protocol = existsSync(protocolPath) ? read('web/src/protocol.ts') : '';

describe('3.2 web/src/protocol.ts — 消息协议层', () => {
  it('protocol.ts 存在（页内协议辅助模块）', () => {
    assert.ok(existsSync(protocolPath), 'web/src/protocol.ts 不存在');
  });

  it('导出协议超时常量（8s）', () => {
    assert.match(protocol, /export\s+const\s+PROTO_TIMEOUT_MS\s*=\s*8000/, '缺 PROTO_TIMEOUT_MS=8000 常量');
  });

  it('导出页内消息分发函数 handleEditorMessage（id 配对回 res）', () => {
    assert.match(
      protocol,
      /export\s+function\s+handleEditorMessage/,
      'protocol.ts 缺 handleEditorMessage 分发函数',
    );
  });
});

describe('3.6 protocol.ts — 软换行覆盖（定案：覆盖保真）', () => {
  it('softToHard：段内 \\n → markdown 硬换行（"  \\n"）', async () => {
    const mod = await import('./web/src/protocol.ts');
    assert.equal(typeof mod.softToHard, 'function', 'protocol.ts 未导出 softToHard');
    assert.equal(mod.softToHard('行一\n行二'), '行一  \n行二');
    assert.equal(mod.softToHard('a\n\nb'), 'a\n\nb', '块间空行不得变硬换行');
    assert.equal(mod.softToHard('abc'), 'abc');
  });

  it('hardToSoft：硬换行（"  \\n" / "\\\n"）还原为 \\n', async () => {
    const mod = await import('./web/src/protocol.ts');
    assert.equal(typeof mod.hardToSoft, 'function', 'protocol.ts 未导出 hardToSoft');
    assert.equal(mod.hardToSoft('行一  \n行二'), '行一\n行二');
    assert.equal(mod.hardToSoft('行一\\\n行二'), '行一\n行二');
    assert.equal(mod.hardToSoft('a\n\nb'), 'a\n\nb');
  });

  it('unescapeBrackets：\\[\\] 还原（[[wikilink]] 不被转义破坏）', async () => {
    const mod = await import('./web/src/protocol.ts');
    assert.equal(typeof mod.unescapeBrackets, 'function', 'protocol.ts 未导出 unescapeBrackets');
    assert.equal(mod.unescapeBrackets('见 \\[\\[a|B\\]\\] 链接'), '见 [[a|B]] 链接');
    assert.equal(mod.unescapeBrackets('a\\nb'), 'a\\nb', '非方括号反斜杠保留');
  });

  // 标准 3：markdown 往返（页内逻辑单测，走真实的软换行覆盖函数）
  it('往返：行一\\n行二 → 覆盖进 → 覆盖出 → 仍是 行一\\n行二', async () => {
    const mod = await import('./web/src/protocol.ts');
    const roundtrip = (md: string) =>
      mod.normalizeMarkdownFromEditor(
        mod.normalizeMarkdownToEditor(md),
      );
    assert.equal(roundtrip('行一\n行二'), '行一\n行二', '软换行丢失 —— 3.6 覆盖保真失败');
    assert.equal(roundtrip('一\n二\n三。'), '一\n二\n三。');
  });

  it('往返：结构 markdown 保真（标题 + 列表 + 引用 + 代码块 + [[链接]]）', async () => {
    const mod = await import('./web/src/protocol.ts');
    const roundtrip = (md: string) =>
      mod.normalizeMarkdownFromEditor(mod.normalizeMarkdownToEditor(md));
    const cases = [
      '# 标题\n\n- 列表\n- 项二',
      '段一。\n\n段二。',
      '> 引用一\n> 引用二',
      '```\ncode line1\ncode line2\n```',
      '见 [[a|B]] 链接。\n下一行。',
      '# 读书笔记\n\n今天读了 [[book-1|某本书]]，记两点：\n\n- 观点 A\n- 观点 B\n\n> 书里说：「慢即是快。」\n\n再回到 [[book-1]]。',
    ];
    for (const md of cases) {
      assert.equal(roundtrip(md), md, `往返失真：${JSON.stringify(md)}`);
    }
  });
});

describe('3.2 web/src — 页内协议接入（index.ts + protocol.ts）', () => {
  // webSrc = web/src/*.ts 全部源码（顶部已拼接）；JSON.parse/res/load/
  // get-markdown/dirty/markdown/700ms 在 protocol.ts 与 index.ts 的合计里查。
  const code = codeOnly(webSrc);

  it('消息事件分发 JSON（type 字段）而非裸字符串', () => {
    assert.match(code, /JSON\.parse/, '页内未 JSON.parse 原生→页消息');
    assert.match(code, /type:\s*RES|["']res["']/, '页内未生成 res 响应');
  });

  it('load 请求 → setMarkdown 进编辑器', () => {
    assert.match(code, /["']load["']|REQ_LOAD/, '页内未识别 load 请求');
    assert.match(code, /setMarkdown/, '页内未实现 setMarkdown');
  });

  it('get-markdown 请求 → 回 {type:"res", ok, markdown}', () => {
    assert.match(code, /get-markdown/, '页内未处理 get-markdown');
    assert.match(code, /markdown/, '页内未回传 markdown');
  });

  it('onUpdate → dirty 事件 + autosave debounce（{type:"dirty"} + {type:"markdown"}）', () => {
    assert.match(code, /\.on\(["']update["']/, 'index.ts 未监听编辑器 update');
    assert.match(code, /["']dirty["']/, '页内未发 dirty 事件');
    assert.match(code, /["']markdown["']/, '页内未发 markdown 事件');
    assert.match(
      code,
      /AUTOSAVE_DEBOUNCE_MS\s*=\s*700|setTimeout\s*\(\s*[^,]+,\s*700\)/,
      '页内未 700ms debounce autosave',
    );
  });
});

describe('3.3/3.4 App.tsx EditorScreen — markdown↔Rust + 可安全退出', () => {
  const body = (app.match(/function\s+EditorScreen[\s\S]*?\n  \}\);?/s)?.[0] ??
    app.match(/function\s+EditorScreen[\s\S]*?\n}/s)?.[0] ??
    '');

  it('editor-ready 后 noteGet 加载 markdown 并发 load 给页', () => {
    assert.match(body, /BackendNotes\.noteGet/, 'EditorScreen 未调 BackendNotes.noteGet');
    assert.match(body, /postToPage|postMessage|sendRequest.*load/, '未把 markdown post 给页');
  });

  it('新笔记 noteId 空/new → generateNoteId', () => {
    assert.match(body, /generateNoteId|generate_note_id/, 'EditorScreen 未用 generateNoteId');
  });

  it('autosave：收 markdown 事件 → noteCreate + noteUpdateMetadata', () => {
    assert.match(body, /BackendNotes\.noteCreate/, 'EditorScreen 未调 noteCreate 保存');
    assert.match(body, /BackendNotes\.noteUpdateMetadata/, 'EditorScreen 未调 noteUpdateMetadata');
  });

  it('保存态三态：正在保存 / 尚未保存 / 已保存', () => {
    assert.match(body, /正在保存/, '缺「正在保存」态');
    assert.match(body, /尚未保存/, '缺「尚未保存」态');
    assert.match(body, /已保存/, '缺「已保存」态');
  });

  it('可安全退出：返回前若有 dirty 先 get-markdown 存完再 goBack', () => {
    assert.match(body, /get-markdown|flushMarkdown/, '返回前未发 get-markdown 兜底');
    assert.match(body, /goBack\(\)/, '返回未走 goBack');
  });
});
describe('3.2 App.tsx — 原生侧协议（sendRequest + 8s 超时 + id 配对）', () => {
  const body = (app.match(/function\s+EditorScreen[\s\S]*?\n}/s)?.[0] ?? '');

  it('sendRequest 生成 id 并 postMessage JSON', () => {
    assert.match(body, /sendRequest/, 'EditorScreen 未实现 sendRequest');
    assert.match(body, /JSON\.stringify/, 'sendRequest 未 JSON.stringify');
  });

  it('8s 超时兜底（PROTO_TIMEOUT_MS 或 8000）', () => {
    assert.match(body, /8000|TIMEOUT/, 'sendRequest 未挂 8s 超时');
  });
});

// ── 施工方案 3.5：撤销粒度 + 标签↔选区联动（最小可用）──
//
// 审查 D1/D2 加固：此前这组断言全是「web/src 源码正则」——错键名
// （`history:{groupDelay}`；StarterKit 3.32 的真键是 `undoRedo.newGroupDelay`）、
// 空桩、删真实调用只留注释都能骗过。现在改为在 jsdom 里例化**真实生产入口**
// `web/src/index.ts`，断言读真 Editor 的 options、真 postToNative 消息、
// 真 `#tag-strip` DOM（挂载器见 web/src/editor_mount.ts）。

describe('3.5 撤销粒度 — StarterKit 真键名且真生效（D3）', () => {
  it('StarterKit 收 undoRedo.newGroupDelay=500，且不再有 history 死键', async () => {
    const page = await mountEditorPage();
    const starterKit = page.editor.extensionManager.extensions.find(
      (e: { name: string }) => e.name === 'starterKit',
    );
    assert.ok(starterKit, '编辑器未挂 StarterKit');
    const opts = (starterKit.options ?? {}) as Record<string, any>;
    assert.equal(
      Object.prototype.hasOwnProperty.call(opts, 'history'),
      false,
      'StarterKit 仍收到 `history` 死键 —— 3.32 的 StarterKitOptions 无此键' +
        '（tsc TS2353），会被静默忽略，将来改成非默认值也不生效',
    );
    assert.equal(
      opts.undoRedo?.newGroupDelay,
      500,
      `StarterKit 未用真键 undoRedo:{newGroupDelay:500}（实际 ${JSON.stringify(opts.undoRedo)}）`,
    );
  });

  it('配置真流入 live undoRedo 扩展（不是碰巧等于默认 500）', async () => {
    const page = await mountEditorPage();
    const starterKit = page.editor.extensionManager.extensions.find(
      (e: { name: string }) => e.name === 'starterKit',
    );
    const live = page.editor.extensionManager.extensions.find(
      (e: { name: string }) => e.name === 'undoRedo',
    );
    assert.ok(live, '编辑器未挂 undoRedo 扩展');
    assert.equal(
      live.options.newGroupDelay,
      (starterKit.options as Record<string, any>).undoRedo.newGroupDelay,
      'undoRedo.newGroupDelay 未从 StarterKit 配置流入扩展实例',
    );
  });

  it('撤销分组真按 newGroupDelay 生效：窗口内合并 1 步，窗口外 2 步', async () => {
    const page = await mountEditorPage();
    const ed = page.editor;
    const wait = (ms: number) => new Promise((r) => setTimeout(r, ms));
    // 组窗口 = 500ms：先让 setContent 的组闭合，再对比 100ms / 900ms 间隔。
    const undoSteps = async (gap: number): Promise<string> => {
      ed.commands.setContent('起始');
      ed.commands.setTextSelection(ed.state.doc.content.size - 1);
      await wait(700);
      ed.commands.insertContent('a');
      await wait(gap);
      ed.commands.insertContent('b');
      await wait(10);
      ed.commands.undo();
      await wait(10);
      return ed.getText();
    };
    assert.equal(await undoSteps(100), '起始', '500ms 窗口内的两笔事务应合并为一步撤销');
    assert.equal(await undoSteps(900), '起始a', '跨 500ms 窗口的两笔事务应分两步撤销');
  });
});

describe('3.5 标签↔选区联动 — 真消息 / 真 DOM（D2/D5/D7）', () => {
  it('set-tags → 页内 #tag-strip 真渲染标签并回 res', async () => {
    const page = await mountEditorPage();
    page.resetPosted();
    page.dispatchToPage({ id: 11, type: 'set-tags', tags: ['alpha', 'beta'] });
    const strip = page.document.getElementById('tag-strip');
    assert.ok(strip, 'index.html 缺 #tag-strip 容器');
    assert.equal(
      strip.children.length,
      2,
      `#tag-strip 未渲染 2 个标签 chip（实际 ${strip.children.length}）—— onSetTags 仍是空桩`,
    );
    assert.equal(strip.textContent, '#alpha#beta', '#tag-strip 文本与标签不符');
    const res = page.postedEvents('res').find((m: any) => m.id === 11);
    assert.equal(res?.ok, true, 'set-tags 未回 {id,type:"res",ok:true}');
  });

  it('正常打字（折叠光标）的 selection 事件带光标前文本，[[ 可被探测（D5）', async () => {
    const page = await mountEditorPage();
    const ed = page.editor;
    page.dispatchToPage({ id: 12, type: 'load', markdown: '见' });
    ed.commands.setTextSelection(ed.state.doc.content.size - 1);
    page.resetPosted();
    ed.commands.insertContent('[['); // 模拟用户正常打字输入 `[[`
    const last = page.postedEvents('selection').at(-1) as any;
    assert.ok(last, '打字后未发 selection 事件');
    assert.equal(last.from, last.to, '测试前提：正常打字后是折叠选区');
    assert.match(
      String(last.textBefore ?? ''),
      /\[\[$/,
      `selection 事件未带光标前文本（textBefore=${JSON.stringify(last.textBefore)}）` +
        '—— 折叠选区 text 恒 ""，原生侧 [[ 补全永不触发',
    );
  });

  it('selectionPayload 对折叠选区给出 textBefore（协议单测）', async () => {
    const mod = await import('./web/src/protocol.ts');
    const doc = { textBetween: (f: number, t: number) => '见 [[ab'.slice(f, t) };
    const p = mod.selectionPayload({
      editor: { state: { selection: { from: 4, to: 4, empty: true }, doc } },
    });
    assert.equal(p.text, '', '折叠选区 text 仍应为 ""（语义不变）');
    assert.equal(p.textBefore, '见 [[', '折叠选区未带光标前文本');
  });

  it('linkPrefixFromContext：只认光标前未闭合的 [[prefix', async () => {
    const mod = await import('./web/src/protocol.ts');
    assert.equal(
      typeof mod.linkPrefixFromContext,
      'function',
      'protocol.ts 未导出 linkPrefixFromContext —— 原生侧触发逻辑不可行为化测试',
    );
    assert.equal(mod.linkPrefixFromContext('见 [[ab'), 'ab');
    assert.equal(mod.linkPrefixFromContext('见 [[ab]] 之后'), null);
    assert.equal(mod.linkPrefixFromContext('普通文字'), null);
    assert.equal(mod.linkPrefixFromContext(''), null);
    assert.equal(mod.linkPrefixFromContext('a[[b[[cd'), 'cd');
  });

  it('matchTags：只高亮命中 [[prefix 或选区文本的标签（D7）', async () => {
    const mod = await import('./web/src/protocol.ts');
    assert.equal(typeof mod.matchTags, 'function', 'protocol.ts 未导出 matchTags');
    assert.deepEqual(
      mod.matchTags(['alpha', 'beta', '阿尔法'], { text: '', textBefore: '见 [[al' }),
      ['alpha'],
      '[[prefix 应只命中 alpha（旧实现是任一 selection 高亮全部 tag）',
    );
    assert.deepEqual(
      mod.matchTags(['alpha', 'beta'], { text: '', textBefore: '普通' }),
      [],
      '无选区无 [[prefix 时不应高亮任何标签',
    );
    assert.deepEqual(mod.matchTags(['alpha', 'beta'], { text: 'beta', textBefore: '' }), [
      'beta',
    ]);
  });

  it('insert-link 请求 → 把已打的「[[prefix」替换成 [[title]]（不残留 [[）', async () => {
    const page = await mountEditorPage();
    const ed = page.editor;
    // 模拟用户已输入「见 [[ab」（光标在尾、折叠选区）。
    page.dispatchToPage({ id: 13, type: 'load', markdown: '见' });
    ed.commands.setTextSelection(ed.state.doc.content.size - 1);
    ed.commands.insertContent(' [[ab');
    page.resetPosted();
    page.dispatchToPage({ id: 14, type: 'insert-link', title: '某笔记' });
    const doc = ed.getText();
    assert.equal(
      doc,
      '见 [[某笔记]] ',
      `insert-link 未用 [[title]] 替换已打的 [[prefix（实际 ${JSON.stringify(doc)}）`,
    );
    const res = page.postedEvents('res').find((m: any) => m.id === 14);
    assert.equal(res?.ok, true, 'insert-link 未回 ok 响应');
  });
});

describe('3.5 App.tsx — 原生侧联动真调用（D2：注释/类型定义不算）', () => {
  const body = codeOnly(
    app.match(/function\s+EditorScreen[\s\S]*?\n}/s)?.[0] ?? '',
  );

  it('最小标签行存在（渲染 CardMindTag，触摸目标 ≥48dp）', () => {
    assert.match(body, /<CardMindTag\b/, 'EditorScreen 未渲染 CardMindTag 标签行');
    assert.match(
      body,
      /<CardMindTag\b[^>]*comfortable/,
      '标签 chip 未传 comfortable（compact 高约 28px < 48dp 触摸目标，D6）',
    );
  });

  it('selection 事件消费光标前文本（textBefore），不只是选区文本', () => {
    assert.match(body, /textBefore/, 'onSelection 未消费 textBefore —— 折叠选区路径仍断');
    assert.match(
      body,
      /linkPrefixFromContext\s*\(/,
      '[[ 触发未走可单测的 linkPrefixFromContext',
    );
  });

  it('[[ 补全入口调 BackendNotes.autoCompleteLinks', () => {
    assert.match(
      body,
      /BackendNotes\.autoCompleteLinks\s*\(/,
      'EditorScreen 未真调 BackendNotes.autoCompleteLinks',
    );
  });

  it('标签高亮按命中过滤（matchTags），不是任一 selection 全高亮', () => {
    assert.match(body, /matchTags\s*\(/, '标签高亮未按 selection/[[prefix 命中过滤（D7）');
  });

  it('加载后把标签经 set-tags 发给页（sendRequest("set-tags")）', () => {
    assert.match(
      body,
      /sendRequest\(\s*["']set-tags["']/,
      'EditorScreen 未真发 sendRequest("set-tags", { tags })',
    );
  });

  it('候选 chip 点击接行为（sendRequest("insert-link")），不留空 onTap', () => {
    assert.match(
      body,
      /sendRequest\(\s*["']insert-link["']/,
      '补全候选未接 insert-link —— 仍是 onTap:() => undefined 惰性按钮',
    );
    assert.doesNotMatch(
      body,
      /onTap=\{\s*\(\)\s*=>\s*undefined\s*\}/,
      '仍有 onTap:() => undefined 的惰性按钮',
    );
  });
});

// ── 施工方案 3.8：自动化验收（真 Tiptap jsdom 往返在 web/src/md_fidelity_test.ts）──

describe('3.8 自动化验收 — jsdom 真 Tiptap 往返单测存在', () => {
  it('web/src/md_fidelity_test.ts 存在（12 类结构+[[id|alias]]+软换行全保真）', () => {
    assert.ok(
      existsSync(path.join(WEB_SRC_DIR, 'md_fidelity_test.ts')),
      'web/src/md_fidelity_test.ts 不存在 —— 3.8 真 Tiptap 往返回归未落地',
    );
  });
});

// ── 施工方案 3.9：性能基线复测（web/src/editor_perf_test.ts）──

describe('3.9 性能基线 — 脚本存在且跑三项计时', () => {
  it('web/src/editor_perf_test.ts 存在（setContent/输入/getMarkdown 计时）', () => {
    assert.ok(
      existsSync(path.join(WEB_SRC_DIR, 'editor_perf_test.ts')),
      'web/src/editor_perf_test.ts 不存在 —— 3.9 性能脚本未落地',
    );
  });

  it('perf 脚本对照 V4 基线并标注 jsdom 量级', () => {
    const perf = existsSync(path.join(WEB_SRC_DIR, 'editor_perf_test.ts'))
      ? read('web/src/editor_perf_test.ts')
      : '';
    assert.match(perf, /setContent|insertContent/, 'perf 脚本未测 setContent/输入');
    assert.match(perf, /getMarkdown/, 'perf 脚本未测 getMarkdown');
    assert.match(perf, /V4|基线|jsdom/i, 'perf 脚本未对照 V4 基线/未标 jsdom 量级');
  });
});

// ── 审查 D4：V4 基线口径标注（V4 = 真 WebView2 数字，不是 jsdom）──

describe('3.9 V4 基线口径 — 如实标注（D4）', () => {
  const perf = existsSync(path.join(WEB_SRC_DIR, 'editor_perf_test.ts'))
    ? read('web/src/editor_perf_test.ts')
    : '';

  it('perf 脚本注明 V4 是真实 WebView2 数字，本测是 jsdom 量级', () => {
    assert.match(
      perf,
      /V4[^\n]*WebView2|WebView2[^\n]*V4/,
      'perf 脚本未说明 V4 基线来自真实 WebView2',
    );
    assert.match(perf, /jsdom/, 'perf 脚本未标本测为 jsdom 量级');
    assert.doesNotMatch(
      perf,
      /V4\s*基线[^\n]*同[^\n]*(Node\s*\+\s*)?jsdom\s*口径|同\s*Node\s*\+\s*jsdom\s*口径[^\n]*V4/,
      'perf 脚本仍称 V4 基线「同 Node+jsdom 口径」—— 口径写错（V4 是真 WebView2）',
    );
  });
});

// 「App.tsx 从 nsh 导入的符号必须在 .nsh/types 里真实存在」——拦住 `If` 这类
// 不存在的导出（esbuild 不校验命名导出，nsh trace 运行时才报
// `Could not find export 'If' in module 'nsh'`、应用渲染不出东西）。
describe('App.tsx 的 nsh 导入面真实存在（防不存在的导出）', () => {
  it('from "nsh" 的每个命名导入都在 .nsh/types/nsh/index.d.ts 里声明', () => {
    const app = readFileSync(path.join(here, 'App.tsx'), 'utf8');
    const dts = readFileSync(
      path.join(here, '.nsh', 'types', 'nsh', 'index.d.ts'),
      'utf8',
    );
    const m = app.match(/import\s*\{([^}]*)\}\s*from\s*['"]nsh['"]/);
    assert.ok(m, 'App.tsx 未从 "nsh" 导入任何符号');
    const names = m[1]
      .split(',')
      .map((s) => s.trim().replace(/^type\s+/, ''))
      .filter((s) => s.length > 0);
    assert.ok(names.length > 0, '解析出的 nsh 导入为空');
    for (const name of names) {
      assert.match(
        dts,
        new RegExp(`\\b${name}\\b`),
        `App.tsx 从 "nsh" 导入了 ${name}，但 .nsh/types/nsh/index.d.ts 里没有这个符号 —— nsh trace 会在运行时报 "Could not find export '${name}'" 且应用渲染不出`,
      );
    }
  });
});
