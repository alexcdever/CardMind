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

const here = path.dirname(fileURLToPath(import.meta.url));
const read = (rel: string) => readFileSync(path.join(here, rel), 'utf8');

const WEB_DIR = path.join(here, 'web');
const BUNDLE = path.join(WEB_DIR, 'dist', 'bundle.js');
const INDEX_HTML = path.join(WEB_DIR, 'index.html');
const WEB_SRC_DIR = path.join(WEB_DIR, 'src');

const webSrcFiles = existsSync(WEB_SRC_DIR)
  ? readdirSync(WEB_SRC_DIR).filter((f) => /\.(ts|js|tsx|jsx)$/.test(f))
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
const indexTs = existsSync(path.join(WEB_SRC_DIR, 'index.ts'))
  ? read('web/src/index.ts')
  : '';

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
});

describe('3.2 web/src/index.ts — 页内协议接入', () => {
  it('消息事件分发 JSON（type 字段）而非裸字符串', () => {
    assert.match(codeOnly(indexTs), /JSON\.parse/, 'index.ts 未 JSON.parse 页→原生消息');
    assert.match(codeOnly(indexTs), /type:\s*["']res["']|"res"/, 'index.ts 未生成 res 响应');
  });

  it('load 请求 → setMarkdown 进编辑器', () => {
    assert.match(codeOnly(indexTs), /setMarkdown/, 'index.ts 未接 setMarkdown');
  });

  it('get-markdown 请求 → 回 {type:"res", ok, markdown}', () => {
    const code = codeOnly(indexTs);
    assert.match(code, /get-markdown/, 'index.ts 未处理 get-markdown');
    assert.match(code, /markdown/, 'index.ts 未回传 markdown');
  });

  it('onUpdate → dirty 事件 + autosave debounce（{type:"dirty"} + {type:"markdown"}）', () => {
    const code = codeOnly(indexTs);
    assert.match(code, /onUpdate|\.on\(["']update/, 'index.ts 未监听编辑器 update');
    assert.match(code, /["']dirty["']/, 'index.ts 未发 dirty 事件');
    assert.match(code, /["']markdown["']/, 'index.ts 未发 markdown 事件');
    assert.match(code, /setTimeout\s*\(\s*[^,]+,\s*700\)/, 'index.ts 未 700ms debounce autosave');
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
  const body = (app.match(/function\s+EditorScreen[\s\S]*?\n  \}\);?/s)?.[0] ?? '');

  it('sendRequest 生成 id 并 postMessage JSON', () => {
    assert.match(body, /sendRequest/, 'EditorScreen 未实现 sendRequest');
    assert.match(body, /JSON\.stringify/, 'sendRequest 未 JSON.stringify');
  });

  it('8s 超时兜底（PROTO_TIMEOUT_MS 或 8000）', () => {
    assert.match(body, /8000|TIMEOUT/, 'sendRequest 未挂 8s 超时');
  });
});
