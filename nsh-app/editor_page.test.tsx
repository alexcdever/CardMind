// 编辑页行为测试（`nsh test`；harness = EditorHarness.tsx，假 repository，不碰真实 DB/iroh）。
//
// P4-3a 口径：默认 WYSIWYG（`RichEditor`，label:富文本编辑器，探针键 f6=全文
// dump / f7=当前选区注入 append / f9=选中第一条笔记链接）；源码模式经「源码」
// 切换（label:源码编辑器，探针键 mod+shift+e/l 仍可用）。P4-3b 起 `[[` 候选与
// `cardmind://` 链接跳转两条模式都有覆盖（WYSIWYG 走 suggestion 插件 + bubbleMenu）。
//
// 覆盖 task.md 标准 1–6、8 的行为面：
//  ① 打开已有笔记：加载完成才挂载编辑器、WYSIWYG 默认、文本渲染（无 Markdown 标记）；
//  ② 700ms 自动保存 + 保存顺序 + 新笔记只生成一次 id；
//  ③ 关闭 dirty → 先 flush 再返回；保存失败留页可重试；
//  ④ 加载失败 / 超时 → 错误态，不创建/不覆盖；
//  ⑤ 源码模式 `[[` 候选（含空格前缀）来自 autoCompleteLinks，点选插入
//     `[title](cardmind://note/id) `（P4-2 新存储格式）；
//  ⑥ 标签行显示与命中高亮（源码模式选区；WYSIWYG 下本轮不命中）；
//  ⑦ 撤销可用（两种模式各有覆盖）；
//  ⑧ 源码↔WYSIWYG 切换：内容一致、改动不丢、不产生多余保存。
import { expect, open, test } from "nsh/test";
import type { App } from "nsh/test";

/** WYSIWYG 编辑器与源码编辑器的可达标签。 */
const RICH = "label:富文本编辑器";
const EDITOR = "label:源码编辑器";
const RETRY = "label:重试";
const TO_SOURCE = "label:源码";
const TO_RICH = "label:排版";
const SCENARIO_KEY = "test.scenario";

interface Scenario {
  noteId: string;
  note: string | null;
  tags?: string[];
  failLoad?: boolean | "once" | "hang";
  failSave?: boolean | "once";
  candidates?: { id: string; title: string }[];
  /** `f7`/`mod+shift+l` 时注入的文本（构造「最后输入」用；rich=选区插入，
   *  source=末尾插入）。 */
  append?: string;
  /** "desktop"：三栏场景（侧栏列表 + DesktopEditorPane），不经 nav.push editor。 */
  mode?: string;
  /** 桌面场景多笔记内容表（noteGet 按 id 查）。 */
  notes?: { id: string; content: string; tags?: string }[];
  /** 桌面场景初始选中的笔记 id。 */
  selectedNoteId?: string;
}

interface Calls {
  noteGet: number;
  noteCreate: number;
  noteUpdateMetadata: number;
  syncNotesToStore: number;
  generateNoteId: number;
  autoCompleteLinks: string[];
  searchByTag: string[];
  order: string[];
}

const EMPTY_CALLS: Calls = {
  noteGet: 0,
  noteCreate: 0,
  noteUpdateMetadata: 0,
  syncNotesToStore: 0,
  generateNoteId: 0,
  autoCompleteLinks: [],
  searchByTag: [],
  order: [],
};

function scenarioStorage(scenario: Scenario): Record<string, string> {
  return { [SCENARIO_KEY]: JSON.stringify(scenario) };
}

async function openEditor(scenario: Scenario, size?: { width: number; height: number }): Promise<App> {
  return await open("./EditorHarness.tsx", {
    width: size?.width ?? 1200,
    height: size?.height ?? 900,
    storage: scenarioStorage(scenario),
  });
}

function calls(app: App): Calls {
  const raw = app.storage()["test.calls"];
  return raw === undefined ? { ...EMPTY_CALLS } : (JSON.parse(raw) as Calls);
}

function saved(app: App): string | null {
  const value = app.storage()["test.saved"];
  return value === undefined ? null : value;
}

function savedId(app: App): string | null {
  const value = app.storage()["test.savedId"];
  return value === undefined ? null : value;
}

function hasText(app: App, needle: string): boolean {
  return app.texts().some((text) => text.includes(needle));
}

/** 从默认 WYSIWYG 切到源码模式并等 `Editor` 就绪。 */
async function toSource(app: App): Promise<void> {
  await app.press(TO_SOURCE);
  await app.waitFor(EDITOR);
}

/** 从源码模式切回 WYSIWYG 并等 `RichEditor` 就绪。 */
async function toRich(app: App): Promise<void> {
  await app.press(TO_RICH);
  await app.waitFor(RICH);
}

/** WYSIWYG 全文 dump（f6 探针）→ `test.editorValue`。 */
async function dumpRich(app: App): Promise<string> {
  await app.keyboard.press("f6");
  await app.waitUntil(() => app.storage()["test.editorValue"] !== undefined);
  return app.storage()["test.editorValue"];
}

/** 一行覆盖 AC3 结构的 Markdown fixture：标题/链接（cardmind://）/段内换行/
 *  3+ 空行/代码块/中文。 */
const FIXTURE =
  "# 标题\n\n[别名](cardmind://note/note-2) 与 [note-3](cardmind://note/note-3)\n\n行一\n行二\n\n\n\n```\nconst x = 1;\n```\n";

/** FIXTURE 经 RichEditor 往返的 canonical 形式（多空行塌缩为一个空行）。 */
const FIXTURE_CANON =
  "# 标题\n\n[别名](cardmind://note/note-2) 与 [note-3](cardmind://note/note-3)\n\n行一\n行二\n\n```\nconst x = 1;\n```\n";

test("editor: 打开已有笔记默认 WYSIWYG，渲染格式化内容（无 Markdown 标记），未编辑不落盘", async () => {
  const app = await openEditor({ noteId: "note-1", note: FIXTURE, tags: ["工作"] });
  await app.waitFor(RICH);
  // WYSIWYG 默认态：rich-editor 在场、源码 Editor 不在场。
  expect(app.shows(RICH)).toBe(true);
  expect(app.shows(EDITOR)).toBe(false);
  expect(app.shows("id:source-toggle")).toBe(true);
  // 渲染后的文本块（标题无 `#`、列表无 `-`）；texts() 按块给纯文本。
  expect(hasText(app, "标题")).toBe(true);
  expect(hasText(app, "const x = 1;")).toBe(true);
  expect(hasText(app, "# 标题")).toBe(false);
  // f6 dump 全文 Markdown：canonical 形式（多空行归一）。
  expect(await dumpRich(app)).toBe(FIXTURE_CANON);
  await app.wait(900);
  expect(calls(app).noteCreate).toBe(0);
  expect(saved(app)).toBeNull();
});

test("editor: 加载中不挂编辑器（noteGet 未完成）", async () => {
  const app = await openEditor({ noteId: "note-1", note: "abc", failLoad: "hang" });
  // harness 的 Storage.getItem 异步完成后才 nav.push；先等 loading 出现再断言，
  // 否则断言可能落在 notes stub 上（第 1 轮审查的 13/14↔14/14 不稳定来源）。
  await app.waitFor("id:editor-loading");
  expect(app.shows(RICH)).toBe(false);
  expect(app.shows(EDITOR)).toBe(false);
  expect(hasText(app, "加载中")).toBe(true);
});

test("editor: 加载失败显示错误态、不写入；重试成功后挂载并显示原文", async () => {
  const app = await openEditor({ noteId: "note-1", note: "abc", failLoad: "once" });
  await app.waitFor("text:/加载失败/");
  expect(app.shows(RICH)).toBe(false);
  expect(app.shows(EDITOR)).toBe(false);
  await app.wait(900);
  expect(calls(app).noteCreate).toBe(0);
  expect(saved(app)).toBeNull();
  await app.press(RETRY);
  await app.waitFor(RICH);
  expect(app.texts()).toContain("abc");
  expect(calls(app).noteGet).toBe(2);
});

test("editor: noteGet 超时按加载失败处理，不创建/不覆盖", async () => {
  const app = await open("./EditorHarness.tsx", {
    width: 1200,
    height: 900,
    storage: scenarioStorage({ noteId: "note-1", note: "abc", failLoad: "hang" }),
    clock: {},
  });
  await app.waitFor("id:editor-loading");
  expect(app.shows(RICH)).toBe(false);
  await app.clock.runFor(10_500);
  await app.waitFor("text:/加载失败/");
  expect(app.shows(RICH)).toBe(false);
  expect(calls(app).noteCreate).toBe(0);
  expect(saved(app)).toBeNull();
});

test("editor: 新笔记输入停止 700ms 后自动保存为 Markdown，顺序与单次 UUID", async () => {
  const app = await openEditor({ noteId: "new", note: null });
  await app.waitFor(RICH);
  expect(app.texts()).toContain("尚未保存");
  await app.type(RICH, "hello");
  await app.wait(200);
  expect(saved(app)).toBeNull(); // 700ms 去抖未到
  await app.wait(800);
  await app.waitUntil(() => app.storage()["test.saved"] !== undefined);
  // 保存的是序列化 Markdown（不是内部 JSON）：文本原样，允许尾随换行归一。
  expect((app.storage()["test.saved"] ?? "").trimEnd()).toBe("hello");
  const recorded = calls(app);
  expect(recorded.generateNoteId).toBe(1);
  expect(recorded.noteCreate).toBe(1);
  const order = recorded.order;
  expect(order.indexOf("generateNoteId")).toBeLessThan(order.indexOf("noteCreate"));
  expect(order.indexOf("noteCreate")).toBeLessThan(order.indexOf("noteUpdateMetadata"));
  expect(order.indexOf("noteUpdateMetadata")).toBeLessThan(order.indexOf("syncNotesToStore"));
  expect(savedId(app)).toBe("generated-1");
  expect(app.texts()).toContain("已保存");
  // 第二次保存复用同一个 id，不再生成。
  await app.type(RICH, "!");
  await app.wait(900);
  await app.waitUntil(() =>
    (app.storage()["test.saved"] ?? "").trimEnd() === "hello!",
  );
  expect(calls(app).generateNoteId).toBe(1);
});

test("editor: 新笔记空内容不创建；已有笔记允许保存空内容", async () => {
  const fresh = await openEditor({ noteId: "new", note: null });
  await fresh.waitFor(RICH);
  await fresh.wait(900);
  expect(calls(fresh).noteCreate).toBe(0);
  expect(saved(fresh)).toBeNull();
  expect(fresh.texts()).toContain("尚未保存");

  const existing = await openEditor({ noteId: "note-1", note: "abc" });
  await existing.waitFor(RICH);
  expect(existing.texts()).toContain("abc");
  // autoFocus 已让编辑器持焦；RichEditor headless 下 mod+a 不生效，f8 探针
  // 经 session.run(selectAll) 全选后 backspace 删除等价用户清空全文。
  await existing.keyboard.press("f8");
  await existing.wait(200);
  await existing.keyboard.press("backspace");
  await existing.wait(900);
  await existing.waitUntil(() => existing.storage()["test.saved"] !== undefined);
  expect(calls(existing).noteCreate).toBe(1);
  expect(existing.texts()).toContain("已保存");
});

test("editor: 保存失败显示错误、不谎报已保存；重试成功后恢复", async () => {
  const app = await openEditor({ noteId: "new", note: null, failSave: "once" });
  await app.waitFor(RICH);
  await app.type(RICH, "x");
  await app.wait(900);
  await app.waitFor("text:/保存失败/");
  expect(app.texts()).not.toContain("已保存");
  expect(saved(app)).toBeNull();
  expect(calls(app).noteCreate).toBe(1);
  await app.press(RETRY);
  await app.waitUntil(() => (app.storage()["test.saved"] ?? "").trimEnd() === "x");
  expect(app.texts()).toContain("已保存");
  expect(calls(app).noteCreate).toBe(2);
});

test("editor: 关闭时 dirty → 先 flush 最新内容再返回，重开内容含最后输入", async () => {
  const app = await openEditor({ noteId: "note-1", note: "base", append: "Z" });
  await app.waitFor(RICH);
  // 用 harness 的探针键在当前选区注入（等价用户输入）。
  await app.keyboard.press("f7");
  await app.waitUntil(() =>
    (app.storage()["test.editorValue"] ?? "").includes("Z"),
  );
  expect(saved(app)).toBeNull(); // 去抖尚未触发
  await app.back();
  await app.waitFor("id:notes-stub");
  await app.waitUntil(() => app.storage()["test.saved"] !== undefined);
  // 断言含预期最后输入，而不是「重开内容 == 已保存内容」这种自证式比较。
  expect(app.storage()["test.saved"]).toContain("base");
  expect(app.storage()["test.saved"]).toContain("Z");
  expect(calls(app).noteCreate).toBe(1);
  expect(app.shows(RICH)).toBe(false);
  // 重新打开：内容 = 关闭前最后输入。
  await app.press("id:open-editor");
  await app.waitFor(RICH);
  const reopened = await dumpRich(app);
  expect(reopened).toContain("base");
  expect(reopened).toContain("Z");
});

test("editor: 新笔记只输入空白时按返回直接回列表（不创建、不落盘、不卡死）", async () => {
  const app = await openEditor({ noteId: "new", note: null });
  await app.waitFor(RICH);
  await app.type(RICH, "   ");
  expect(saved(app)).toBeNull();
  await app.back();
  await app.waitFor("id:notes-stub");
  expect(app.shows(RICH)).toBe(false);
  expect(calls(app).noteCreate).toBe(0);
  expect(calls(app).generateNoteId).toBe(0);
  expect(saved(app)).toBeNull();
  await app.wait(900);
  expect(saved(app)).toBeNull();
});

test("editor: Markdown 往返保真（wikilink/代码块/段内换行/中文；空白按归一化判据）", async () => {
  const app = await openEditor({ noteId: "note-1", note: FIXTURE, append: "Z" });
  await app.waitFor(RICH);
  // 加载后全文 = canonical（段落间 3+ 空行归一为一个；其余结构逐字节）。
  expect(await dumpRich(app)).toBe(FIXTURE_CANON);
  // 注入编辑 → 700ms 去抖保存 → 存储为序列化 Markdown（canonical + 注入标记）。
  await app.keyboard.press("f7");
  await app.waitUntil(() =>
    (app.storage()["test.editorValue"] ?? "").includes("Z"),
  );
  await app.wait(900);
  await app.waitUntil(() => app.storage()["test.saved"] !== undefined);
  const savedDoc = app.storage()["test.saved"] ?? "";
  // f7 在初始选区（文档起点）注入 "Z" → 落进标题块成 "Z标题"（0.4.0 实测）。
  expect(savedDoc).toContain("# Z标题");
  expect(savedDoc).toContain("[别名](cardmind://note/note-2)");
  expect(savedDoc).toContain("行一\n行二");
  expect(savedDoc).toContain("```\nconst x = 1;\n```");
  // 关闭 → 重开：内容与保存语义一致（getMarkdown 尾随空行在重解析后归一，
  // 按 trimEnd 判据 + 结构逐项校验；AC3「空白归一」口径）。
  await app.back();
  await app.waitFor("id:notes-stub");
  await app.press("id:open-editor");
  await app.waitFor(RICH);
  const reopened = await dumpRich(app);
  expect(reopened.trimEnd()).toBe((app.storage()["test.saved"] ?? "").trimEnd());
  expect(reopened).toContain("# Z标题");
  expect(reopened).toContain("```\nconst x = 1;\n```");
});

test("editor: CRLF 笔记按归一口径载入（CRLF→LF + 空白归一），未编辑不回写", async () => {
  const crlf = "# 标题\r\n\r\n[别名](cardmind://note/note-2)\r\n\r\n\r\n\r\n```\r\nconst x = 1;\r\n```\r\n";
  const canon =
    "# 标题\n\n[别名](cardmind://note/note-2)\n\n```\nconst x = 1;\n```\n";
  const app = await openEditor({ noteId: "note-1", note: crlf });
  await app.waitFor(RICH);
  expect(await dumpRich(app)).toBe(canon);
  await app.wait(900);
  // 未编辑 → 不 dirty → 不回写（不产生 noteCreate）。
  expect(saved(app)).toBeNull();
  expect(calls(app).noteCreate).toBe(0);
});

test("editor: 关闭时保存失败留在页面，可重试后再返回", async () => {
  const app = await openEditor({ noteId: "new", note: null, failSave: "once" });
  await app.waitFor(RICH);
  await app.type(RICH, "x");
  await app.back();
  await app.waitFor("text:/保存失败/");
  expect(app.shows(RICH)).toBe(true);
  expect(app.shows("id:notes-stub")).toBe(false);
  await app.press(RETRY);
  await app.waitUntil(() => (app.storage()["test.saved"] ?? "").trimEnd() === "x");
  expect(app.shows(RICH)).toBe(true); // 重试成功不自动离开
  await app.back();
  await app.waitFor("id:notes-stub");
});

test("editor: 源码模式 [[ 触发候选（来自 autoCompleteLinks），点选插入 [title](cardmind://note/id) 且无残留", async () => {
  const app = await openEditor({
    noteId: "note-1",
    note: "",
    candidates: [
      { id: "note-2", title: "会议记录" },
      { id: "note-1", title: "自身笔记" },
    ],
  });
  await app.waitFor(RICH);
  await toSource(app);
  await app.type(EDITOR, "[[");
  await app.waitFor("id:link-candidates");
  await app.waitFor("id:link-note-2");
  expect(app.shows("id:link-note-1")).toBe(false); // 当前笔记被过滤
  const prefixes = calls(app).autoCompleteLinks;
  expect(prefixes[prefixes.length - 1]).toBe("");
  await app.press("id:link-note-2");
  await app.waitFor("id:link-candidates", { state: "gone" });
  expect(hasText(app, "[会议记录](cardmind://note/note-2)")).toBe(true);
  expect(hasText(app, "[[]]") || hasText(app, "[[[")).toBe(false);
  await app.wait(900);
  await app.waitUntil(
    () => app.storage()["test.saved"] === "[会议记录](cardmind://note/note-2) ",
  );
});

test("editor: 源码模式 [[ 前缀含空格仍出候选（不依赖内建 completion 的 word 限制）", async () => {
  const app = await openEditor({
    noteId: "note-1",
    note: "",
    candidates: [{ id: "note-2", title: "Weekly Buffer" }],
  });
  await app.waitFor(RICH);
  await toSource(app);
  await app.type(EDITOR, "[[Weekly ");
  await app.waitFor("id:link-note-2");
  expect(calls(app).autoCompleteLinks[calls(app).autoCompleteLinks.length - 1]).toBe("Weekly ");
  await app.press("id:link-note-2");
  await app.waitUntil(() => hasText(app, "[Weekly Buffer](cardmind://note/note-2)"));
});

test("editor: 标签行显示 tags；源码模式光标前命中标签时高亮；无标签不显示空行", async () => {
  const app = await openEditor({ noteId: "note-1", note: "工作 记录", tags: ["工作", "笔记"] });
  await app.waitFor(RICH);
  await app.waitFor("label:工作");
  expect(app.shows("label:笔记")).toBe(true);
  await toSource(app);
  const plain = app.spanStyle("id:tag-text-0");
  await app.type(EDITOR, "[[工");
  await app.wait(100);
  const hit = app.spanStyle("id:tag-text-0");
  expect(hit.color).not.toBe(plain.color);

  const noTags = await openEditor({ noteId: "note-1", note: "无标签", tags: [] });
  await noTags.waitFor(RICH);
  expect(noTags.shows("label:工作")).toBe(false);
});

test("editor: WYSIWYG 撤销可用（输入 → mod+z 回退），不产生错误保存", async () => {
  const app = await openEditor({ noteId: "new", note: null });
  await app.waitFor(RICH);
  await app.type(RICH, "xyz");
  expect(hasText(app, "xyz")).toBe(true);
  await app.keyboard.press("mod+z");
  await app.waitUntil(() => !hasText(app, "xyz"));
  await app.wait(900);
  expect(saved(app)).toBeNull();
});

test("editor: 源码模式撤销可用（输入 → mod+z 回退），不产生错误保存", async () => {
  const app = await openEditor({ noteId: "new", note: null });
  await app.waitFor(RICH);
  await toSource(app);
  await app.type(EDITOR, "xyz");
  expect(hasText(app, "xyz")).toBe(true);
  await app.keyboard.press("mod+z");
  await app.waitUntil(() => !hasText(app, "xyz"));
  await app.wait(900);
  expect(calls(app).noteCreate).toBe(0);
  expect(saved(app)).toBeNull();
});

test("editor: 移动窄屏下编辑页仍可输入与返回（布局不回归）", async () => {
  const app = await openEditor({ noteId: "new", note: null }, { width: 390, height: 844 });
  await app.waitFor(RICH);
  await app.type(RICH, "移动");
  await app.back();
  await app.waitFor("id:notes-stub");
  await app.waitUntil(() =>
    (app.storage()["test.saved"] ?? "").includes("移动"),
  );
});

// ─── P4-3a：源码 ⇄ WYSIWYG 切换 ───────────────────────────────────────────────

test("editor: 切到源码显示 Markdown 原文，切回 WYSIWYG；改动不丢、不产生多余保存", async () => {
  const doc = "# 大标题\n\n- 项一\n- 项二\n\n> 引用一句话\n\n```\nconst x = 1;\n```\n\n正文段落。\n";
  const app = await openEditor({ noteId: "note-1", note: doc }, { width: 390, height: 844 });
  await app.waitFor(RICH);
  // WYSIWYG 看不到 `#`/`-`/`>` 源码标记；渲染后的四类块都在。
  expect(hasText(app, "大标题")).toBe(true);
  expect(hasText(app, "项一")).toBe(true);
  expect(hasText(app, "引用一句话")).toBe(true);
  expect(hasText(app, "const x = 1;")).toBe(true);
  await toSource(app);
  // 源码模式：逐字节 = canonical（无编辑，不 dirty 不保存）。
  expect(await dumpRich(app)).toBe(doc);
  await app.wait(900);
  expect(saved(app)).toBeNull();
  expect(calls(app).noteCreate).toBe(0);
  // 切回 WYSIWYG：仍是渲染态，内容一致。
  await toRich(app);
  expect(hasText(app, "大标题")).toBe(true);
  expect(app.shows(EDITOR)).toBe(false);
  expect(await dumpRich(app)).toBe(doc);
  await app.wait(900);
  expect(saved(app)).toBeNull();
  expect(calls(app).noteCreate).toBe(0);
});

test("editor: 源码模式下编辑 → 切回 WYSIWYG 内容同步（源码改动被重新解析显示）", async () => {
  const app = await openEditor({ noteId: "note-1", note: "初稿\n", append: "# 新标题\n\n" });
  await app.waitFor(RICH);
  expect(hasText(app, "新标题")).toBe(false);
  await toSource(app);
  // 源码模式末尾插入一段 Markdown（走探针键；等价在源码里输入）。
  await app.keyboard.press("mod+shift+l");
  await app.waitUntil(() =>
    (app.storage()["test.editorValue"] ?? "").includes("新标题"),
  );
  await toRich(app);
  // WYSIWYG 重新解析：源码插入的 `# 新标题` 渲染为标题块（无 `#` 标记）。
  expect(hasText(app, "新标题")).toBe(true);
  expect(await dumpRich(app)).toContain("# 新标题");
  expect(await dumpRich(app)).toContain("初稿");
});

test("editor: WYSIWYG 编辑 → 切源码后源码含改动，再切回一致", async () => {
  const app = await openEditor({ noteId: "note-1", note: "原文\n", append: "追加" });
  await app.waitFor(RICH);
  await app.keyboard.press("f7");
  await app.waitUntil(() =>
    (app.storage()["test.editorValue"] ?? "").includes("追加"),
  );
  await toSource(app);
  // WYSIWYG 的改动进入源码（Markdown 序列化）。
  const source = await dumpRich(app);
  expect(source).toContain("原文");
  expect(source).toContain("追加");
  await toRich(app);
  const back = await dumpRich(app);
  expect(back).toContain("原文");
  expect(back).toContain("追加");
  await app.wait(900);
  // 已去抖保存一次即回到 saved；不产幻影重复写。
  await app.waitUntil(() => app.storage()["test.saved"] !== undefined);
});

test("editor: 桌面 ≥1280 打开默认 WYSIWYG，源码切换正常（无并排预览回归）", async () => {
  const doc = "# 并排\n\n- 列表项\n";
  const app = await open("./EditorHarness.tsx", {
    width: 1400,
    height: 900,
    storage: scenarioStorage({ noteId: "note-1", note: doc }),
  });
  await app.waitFor(RICH);
  expect(hasText(app, "并排")).toBe(true);
  await toSource(app);
  expect(await dumpRich(app)).toBe(doc);
});

test("editor: 旧格式 [[id|alias]] 笔记加载即归一为新格式链接，编辑后落盘为新格式（惰性迁移）", async () => {
  const legacy = "前文 [[note-2|会议别名]] 与 [[note-3]] 后文\n";
  const app = await openEditor({ noteId: "note-1", note: legacy, append: "X" });
  await app.waitFor(RICH);
  // 加载归一：WYSIWYG dump 出的 Markdown 已是 [alias](cardmind://…) 链接。
  const loaded = await dumpRich(app);
  expect(loaded).toContain("[会议别名](cardmind://note/note-2)");
  expect(loaded).toContain("[note-3](cardmind://note/note-3)");
  expect(loaded).not.toContain("[[");
  await app.wait(900);
  expect(saved(app)).toBeNull();
  expect(calls(app).noteCreate).toBe(0);
  // 编辑 → 保存 → 存储为新格式（不再含 [[）。
  await app.keyboard.press("f7");
  await app.wait(900);
  await app.waitUntil(() => app.storage()["test.saved"] !== undefined);
  const stored = app.storage()["test.saved"] ?? "";
  expect(stored).toContain("[会议别名](cardmind://note/note-2)");
  expect(stored).toContain("X");
  expect(stored).not.toContain("[[");
});

// ─── P3：桌面第三栏（Each key 重建）──────────────────────────────────────────

async function openDesktop(scenario: Scenario): Promise<App> {
  return await open("./EditorHarness.tsx", {
    width: 1200,
    height: 900,
    storage: scenarioStorage(scenario),
  });
}

test("editor: 桌面第三栏渲染真实编辑器（非占位），选中笔记内容显示", async () => {
  const app = await openDesktop({
    noteId: "note-a",
    note: null,
    mode: "desktop",
    notes: [
      { id: "note-a", content: "Alpha 笔记内容" },
      { id: "note-b", content: "Beta 笔记内容" },
    ],
    selectedNoteId: "note-a",
  });
  await app.waitFor("id:desktop-notes");
  await app.waitFor(RICH);
  expect(hasText(app, "Alpha 笔记内容")).toBe(true);
  // 切到 B：第三栏内容换成 B。
  await app.press("id:note-item-note-b");
  await app.waitUntil(() => hasText(app, "Beta 笔记内容"));
  expect(hasText(app, "Alpha 笔记内容")).toBe(false);
});

test("editor: 桌面第三栏 Each key 重建——切笔记 A→B→A 撤销不跨笔记", async () => {
  const app = await openDesktop({
    noteId: "note-a",
    note: null,
    mode: "desktop",
    notes: [
      { id: "note-a", content: "AAAA" },
      { id: "note-b", content: "BBBB" },
    ],
    selectedNoteId: "note-a",
    append: "X",
  });
  await app.waitFor("id:desktop-notes");
  await app.waitFor(RICH);
  // 在 A 当前选区注入 X（未保存，dirty）。
  await app.keyboard.press("f7");
  await app.waitUntil(() =>
    (app.storage()["test.editorValue"] ?? "").includes("X"),
  );
  // 切到 B（触发 key 重建 + unmount flush A）。
  await app.press("id:note-item-note-b");
  await app.waitFor(RICH);
  // B 的内容是 BBBB，不是 AAAA（没共享撤销栈/没串文）。
  expect(await dumpRich(app)).toContain("BBBB");
  expect(await dumpRich(app)).not.toContain("AAAA");
  // 在 B 上撤销应只影响 B（这里 B 无未保存编辑，canUndo 可能无操作；
  // 关键是按 mod+z 不会把 A 的 X 撤掉后串进 B）。
  await app.keyboard.press("mod+z");
  await app.wait(300);
  expect(await dumpRich(app)).toContain("BBBB");
  // 切回 A：A 显示它自己的内容（含已 flush 的注入 X）。
  await app.press("id:note-item-note-a");
  await app.waitFor(RICH);
  const aDoc = await dumpRich(app);
  expect(aDoc).toContain("AAAA");
  expect(aDoc).toContain("X");
  expect(app.storage()["test.saved.note-a"]).toContain("X");
});

// P4 AC1：能区分「每次切换得到新编辑器实例」与「同一实例 setValue 重载」。
// 观测：EditorHarness 对 `onEditorRef`/`onRichSession` 收到的每个**新实例** +1
// 并写入 `test.editorMountCount`。计数由「新实例挂载」驱动：切换 A→B→A
// 若每次都挂载新实例，计数单调递增到 3。
test("editor: 桌面第三栏 Each key 判别——A→B→A 每次切换都新建编辑器实例", async () => {
  const app = await openDesktop({
    noteId: "note-a",
    note: null,
    mode: "desktop",
    notes: [
      { id: "note-a", content: "AAAA" },
      { id: "note-b", content: "BBBB" },
    ],
    selectedNoteId: "note-a",
    append: "Y",
  });
  await app.waitFor("id:desktop-notes");
  await app.waitFor(RICH);
  // A 首挂载：一个实例。
  await app.waitUntil(() => app.storage()["test.editorMountCount"] === "1");
  // 在 A 注入 Y（dirty，用于验证切回 A 后内容与撤销栈）。
  await app.keyboard.press("f7");
  await app.waitUntil(() =>
    (app.storage()["test.editorValue"] ?? "").includes("Y"),
  );
  // A→B：切换笔记 → 编辑器重建 → 第 2 个实例。
  await app.press("id:note-item-note-b");
  await app.waitUntil(() => app.storage()["test.editorMountCount"] === "2");
  expect(await dumpRich(app)).toContain("BBBB");
  // B→A：再次重建 → 第 3 个实例（不是回到第 1 个实例的存活状态）。
  await app.press("id:note-item-note-a");
  await app.waitUntil(() => app.storage()["test.editorMountCount"] === "3");
  const aDoc = await dumpRich(app);
  expect(aDoc).toContain("AAAA");
  expect(aDoc).toContain("Y");
  // 撤销栈随实例重建：回 A 后 mod+z 不会撤掉 flush 前的编辑再把内容串错
  // （A 重建后的基线就是已落盘的内容，无可撤销项）。
  await app.keyboard.press("mod+z");
  await app.wait(300);
  const aDocAfter = await dumpRich(app);
  expect(aDocAfter).toBe(aDoc);
});

// ─── P3：Escape 清候选（源码模式） ─────────────────────────────────────────────

test("editor: 候选打开时用「关闭候选」入口收起候选且不退出编辑页（源码模式）", async () => {
  // 限制（探测证据见 .pipeline/executor.md）：Editor 聚焦时吞掉 Escape，
  // `keymap.bind("escape", …, { when: "always" })` 也收不到；故提供可见的
  // 「关闭候选」按钮作为替代关闭路径（touch/无硬件键盘同样可用）。
  const app = await openEditor({
    noteId: "note-1",
    note: "",
    candidates: [{ id: "note-2", title: "会议记录" }],
  });
  await app.waitFor(RICH);
  await toSource(app);
  await app.type(EDITOR, "[[");
  await app.waitFor("id:link-candidates");
  await app.press("label:关闭候选");
  await app.waitFor("id:link-candidates", { state: "gone" });
  expect(app.shows(EDITOR)).toBe(true); // 仍在编辑页（源码模式）
  expect(app.shows("id:notes-stub")).toBe(false); // 未退回列表
});

// ─── P3：编辑器 autoFocus ─────────────────────────────────────────────────────

test("editor: 打开编辑页可直接输入（无需先 press 聚焦）", async () => {
  // `autoFocus` 已开启；headless `nsh test` 无法断言真实焦点
  // （`keyboard.press("a")` 不走输入 sink），故按 task.md 允许的口径：
  // 打开后直接 `app.type` 即可输入、不必先 `press` 聚焦，autoFocus 的真实
  // 键盘焦点行为留待 `--target`/真机手工确认（见 executor.md）。
  const app = await openEditor({ noteId: "new", note: null });
  await app.waitFor(RICH);
  await app.type(RICH, "直接输入");
  expect(await dumpRich(app)).toContain("直接输入");
});

// ─── P3：回归补强 ─────────────────────────────────────────────────────────────

test("editor: 未编辑 CRLF 笔记关闭后不回写（noteCreate=0）", async () => {
  const crlf = "# 标题\r\n\r\n正文\r\n";
  const app = await openEditor({ noteId: "note-1", note: crlf });
  await app.waitFor(RICH);
  // 不做任何编辑，直接关闭。
  await app.back();
  await app.waitFor("id:notes-stub");
  await app.wait(300);
  // canonical 归一后 text == lastSaved，不是 dirty → 不产生 noteCreate。
  expect(calls(app).noteCreate).toBe(0);
  expect(saved(app)).toBeNull();
});

test("editor: onChange 未触发时关闭仍保存最新内容（WYSIWYG 经 session.getMarkdown）", async () => {
  // f7 走 session.insertContent 改文档；若某运行时下信号未同步，
  // 关闭路径的 readLatestText()（session.getMarkdown）仍能拿到最新内容。
  const app = await openEditor({ noteId: "note-1", note: "base", append: "-尾部" });
  await app.waitFor(RICH);
  await app.keyboard.press("f7");
  await app.waitUntil(() =>
    (app.storage()["test.editorValue"] ?? "").includes("-尾部"),
  );
  await app.back();
  await app.waitFor("id:notes-stub");
  await app.waitUntil(() => app.storage()["test.saved"] !== undefined);
  // 关键：保存的是 session 最新文档（含 -尾部），不是陈旧的信号值。
  expect(app.storage()["test.saved"]).toContain("base");
  expect(app.storage()["test.saved"]).toContain("-尾部");
});

// ─── P4-3a：2 万字 WYSIWYG 打开/模式切换性能测量 ──────────────────────────────

/** 构造 ≈targetChars 字 Markdown（标题/列表/引用/代码块/wikilink/中文，均匀分布）。 */
function bigMarkdown(targetChars: number): string {
  const parts: string[] = [];
  let n = 0;
  let block = 0;
  while (n < targetChars) {
    block += 1;
    const seg =
      `# 第 ${block} 节 标题\n\n` +
      `正文段落，含 [别名${block}](cardmind://note/note-${block}) 与普通文本，用来撑大解析成本。` +
      `中文内容若干，重复填充以达到目标字数规模的真实文档。\n\n` +
      `- 列表项一\n- 列表项二\n- 列表项三\n\n` +
      `> 引用一句话，来自第 ${block} 节。\n\n` +
      "```\nconst x" + block + " = " + block + ";\n```\n\n";
    parts.push(seg);
    n += seg.length;
  }
  return parts.join("");
}

function percentile(sorted: number[], p: number): number {
  const idx = Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1);
  return sorted[idx];
}

test("editor: 2 万字 WYSIWYG 打开 + 源码⇄WYSIWYG 切换性能（墙钟采样）", async () => {
  // RichEditor 首挂载在 dev（未优化）构建下随文档规模超线性增长（P4-3a 实测：
  // 10k≈12s / 20k≈38s / 30k≈66-80s / 50k>180s，n² 疑似在视图首布局；
  // createRichEditor 本身仅 ~0.3-0.6s）。故采样文档取 20k（挂载 ~38s），
  // 记录数字不设阈值；release 构建预期显著更快（task.md：先测量再定阈值）。
  // 单测上限 300s：open 超时 180s + 每轮 to-source/to-rich 各 120s 超时，按超时
  // 算任何一轮都能吃掉上限（只能靠 budgetMs=200_000 轮间截断兜底）；按实测一轮
  // ≈30-40s 算，open≈38s + 4×~40s≈198s 虽在 300s 内但满载时可能贴着走。
  // TARGET 从 4 降到 3 给常态留余量（≈38s+3×~40s≈158s），样本只需 ≥MIN_SAMPLES=2。
  // 真机复测见 docs/testing/nsh-p4-windows-ime-checklist.md §E。
  const doc = bigMarkdown(20_000);
  const tOpen0 = Date.now();
  const app = await openEditor({ noteId: "note-1", note: doc }, { width: 390, height: 844 });
  await app.waitFor(RICH, { timeout: 180_000 });
  const openMs = Date.now() - tOpen0;
  const toSourceSamples: number[] = [];
  const toRichSamples: number[] = [];
  const budgetMs = 200_000; // 单测 300s 上限内留余量给装载/收尾。
  const started = Date.now();
  const TARGET = 3;
  const MIN_SAMPLES = 2;
  for (let i = 0; i < TARGET; i += 1) {
    const t0 = Date.now();
    await app.press(TO_SOURCE);
    await app.waitFor(EDITOR, { timeout: 120_000 });
    toSourceSamples.push(Date.now() - t0);
    const t1 = Date.now();
    await app.press(TO_RICH);
    await app.waitFor(RICH, { timeout: 120_000 });
    toRichSamples.push(Date.now() - t1);
    if (Date.now() - started > budgetMs) break;
  }
  const report = (name: string, samples: number[]): string => {
    const sorted = [...samples].sort((a, b) => a - b);
    const p50 = percentile(sorted, 50);
    const p95 = percentile(sorted, 95);
    return `${name} n=${sorted.length} min=${sorted[0]}ms p50=${p50}ms p95=${p95}ms max=${sorted[sorted.length - 1]}ms`;
  };
  console.log(
    `[perf] wysiwyg ${doc.length} chars: open=${openMs}ms | ` +
      `${report("to-source", toSourceSamples)} | ${report("to-rich", toRichSamples)} ` +
      `(headless dev-build, wall-clock Date.now())`,
  );
  console.log(
    `[perf] samples(ms): toSource=${JSON.stringify(toSourceSamples)} ` +
      `toRich=${JSON.stringify(toRichSamples)}`,
  );
  // 行为断言只锁「测到了有效样本」：不锁固定次数/阈值（dev 构建数字本身
  // 不是验收阈值，见 task.md AC 口径）。
  expect(toSourceSamples.length).toBeGreaterThanOrEqual(MIN_SAMPLES);
  expect(toRichSamples.length).toBeGreaterThanOrEqual(MIN_SAMPLES);
}, 300_000);

// ─── P4-3b：WYSIWYG 的 `[[` 候选（suggestion）与 cardmind 链接跳转 ─────────────

test("editor: WYSIWYG 输入 [[ 出现候选（来自 autoCompleteLinks），前缀随输入更新，删掉触发串后消失", async () => {
  const app = await openEditor({
    noteId: "note-1",
    note: "",
    candidates: [
      { id: "note-2", title: "会议记录" },
      { id: "note-3", title: "Weekly Buffer" },
      { id: "note-1", title: "自身笔记" },
    ],
  });
  await app.waitFor(RICH);
  // `char:"[["` 是**多字符**触发：单个 `[` 不出候选，补成 `[[` 才出。
  await app.type(RICH, "[");
  await app.wait(300);
  expect(app.shows("id:link-candidates")).toBe(false);
  await app.type(RICH, "[");
  await app.waitFor("id:link-candidates");
  await app.waitFor("id:link-note-2");
  expect(app.shows("id:link-note-1")).toBe(false); // 当前笔记被过滤
  const initial = calls(app).autoCompleteLinks;
  expect(initial[initial.length - 1]).toBe("");
  // 继续输入前缀：候选随 query 更新；含空格的标题同样匹配（allowSpaces）。
  await app.type(RICH, "Weekly ");
  await app.waitFor("id:link-note-3");
  await app.waitFor("id:link-note-2", { state: "gone" });
  const typed = calls(app).autoCompleteLinks;
  expect(typed[typed.length - 1]).toBe("Weekly ");
  // 删掉 `[[` 触发串（退格到空文档）：建议失活 → 候选行消失，仍在编辑页。
  for (let i = 0; i < 9; i += 1) await app.keyboard.press("backspace");
  await app.waitFor("id:link-candidates", { state: "gone" });
  expect(app.shows(RICH)).toBe(true);
  // 「关闭候选」在 WYSIWYG 同样结束建议；否则下一字符会按新 query 把候选弹回来。
  await app.type(RICH, "[[");
  await app.waitFor("id:link-candidates");
  await app.press("label:关闭候选");
  await app.waitFor("id:link-candidates", { state: "gone" });
  await app.type(RICH, "好");
  await app.wait(300);
  expect(app.shows("id:link-candidates")).toBe(false);
  // Escape 由 suggestion 插件消解：候选消失且不退出编辑页（删掉触发串后再试，
  // 插件在 Escape 后会记住本次触发，直到文本里的 `[[` 被删掉才重新触发）。
  for (let i = 0; i < 3; i += 1) await app.keyboard.press("backspace");
  await app.type(RICH, "[[");
  await app.waitFor("id:link-candidates");
  await app.keyboard.press("escape");
  await app.waitFor("id:link-candidates", { state: "gone" });
  expect(app.shows(RICH)).toBe(true);
  expect(app.shows("id:notes-stub")).toBe(false);
});

test("editor: WYSIWYG [[ 点候选插入链接文本（link mark、无 [[ 残留），保存为标准 Markdown", async () => {
  const app = await openEditor({
    noteId: "note-1",
    note: "",
    candidates: [{ id: "note-2", title: "会议记录" }],
  });
  await app.waitFor(RICH);
  await app.type(RICH, "[[会");
  await app.waitFor("id:link-note-2");
  await app.press("id:link-note-2");
  await app.waitFor("id:link-candidates", { state: "gone" });
  // 显示为链接（link mark 的下划线样式），不是裸 Markdown 标记。
  const linkStyle = app.spanStyle("text:会议记录");
  expect(linkStyle.underline).toBe(true);
  expect(hasText(app, "[[")).toBe(false);
  // 序列化 Markdown = 标准链接（`[[` 与前缀不残留）。
  const doc = await dumpRich(app);
  expect(doc).toContain("[会议记录](cardmind://note/note-2)");
  expect(doc).not.toContain("[[");
  // 700ms 去抖后落盘同一 Markdown 形式。
  await app.wait(900);
  await app.waitUntil(() =>
    (app.storage()["test.saved"] ?? "").includes("[会议记录](cardmind://note/note-2)"),
  );
});

test("editor: WYSIWYG [[ 方向键移动高亮（不插入、不移动光标），Enter 接受高亮项", async () => {
  const app = await openEditor({
    noteId: "note-1",
    note: "",
    candidates: [
      { id: "note-2", title: "会议记录" },
      { id: "note-3", title: "Weekly Buffer" },
    ],
  });
  await app.waitFor(RICH);
  await app.type(RICH, "[[");
  await app.waitFor("id:link-note-2");
  await app.waitFor("id:link-note-3");
  const firstBefore = app.spanStyle("id:link-text-note-2");
  const secondBefore = app.spanStyle("id:link-text-note-3");
  expect(firstBefore.color).not.toBe(secondBefore.color); // 首项已高亮
  // 方向键被 suggestion 插件吞掉：只移动高亮，不插入文本、不明显移动光标
  // （读 `texts()` 不按键；f6 dump 会结束建议，不能夹在 ArrowDown 与 Enter 之间）。
  const textsBefore = app.texts();
  await app.keyboard.press("ArrowDown");
  await app.waitUntil(
    () => app.spanStyle("id:link-text-note-2").color === secondBefore.color,
  );
  expect(app.spanStyle("id:link-text-note-3").color).toBe(firstBefore.color);
  expect(app.texts()).toEqual(textsBefore);
  expect(hasText(app, "[[")).toBe(true); // 触发串还在（Enter 之前不替换）
  // Enter 接受高亮项（第二项）。
  await app.keyboard.press("Enter");
  await app.waitFor("id:link-candidates", { state: "gone" });
  const doc = await dumpRich(app);
  expect(doc).toContain("[Weekly Buffer](cardmind://note/note-3)");
  expect(doc).not.toContain("[[");
});

test("editor: WYSIWYG 光标落在 cardmind 链接上出现「打开笔记」，桌面注入 onNavigateNote 切选中", async () => {
  const app = await openDesktop({
    noteId: "note-a",
    note: null,
    mode: "desktop",
    notes: [
      { id: "note-a", content: "见 [乙](cardmind://note/note-b) 末尾" },
      { id: "note-b", content: "Beta 笔记内容" },
    ],
    selectedNoteId: "note-a",
  });
  await app.waitFor("id:desktop-notes");
  await app.waitFor(RICH);
  await app.keyboard.press("f9");
  await app.waitFor("id:link-bubble-menu");
  await app.press("label:打开笔记");
  await app.waitUntil(() => hasText(app, "Beta 笔记内容"));
  expect(hasText(app, "见")).toBe(false);
});

test("editor: 未注入 onNavigateNote 时链接跳转走默认 openEditor push", async () => {
  const app = await openEditor({
    noteId: "note-1",
    note: null,
    notes: [
      { id: "note-1", content: "见 [乙](cardmind://note/note-2) 末尾" },
      { id: "note-2", content: "Beta 笔记内容" },
    ],
  });
  await app.waitFor(RICH);
  await app.keyboard.press("f9");
  await app.waitFor("id:link-bubble-menu");
  await app.press("label:打开笔记");
  await app.waitUntil(() => hasText(app, "Beta 笔记内容"));
});
