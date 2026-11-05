// 编辑页行为测试（`nsh test`；harness = EditorHarness.tsx，假 repository，不碰真实 DB/iroh）。
//
// 覆盖 task.md 标准 1–6、8 的行为面：
//  ① 打开已有笔记：加载完成才挂载 Editor、文本原样显示；
//  ② 700ms 自动保存 + 保存顺序 + 新笔记只生成一次 id；
//  ③ 关闭 dirty → 先 flush 再返回；保存失败留页可重试；
//  ④ 加载失败 / 超时 → 错误态，不创建/不覆盖；
//  ⑤ `[[` 候选（含空格前缀）来自 autoCompleteLinks，点选插入
//     `[title](cardmind://note/id) `（P4-2 新存储格式）；
//  ⑥ 标签行显示与命中高亮；
//  ⑦ 撤销可用。
import { expect, open, test } from "nsh/test";
import type { App } from "nsh/test";

const EDITOR = "label:Markdown 编辑器";
const RETRY = "label:重试";
const SCENARIO_KEY = "test.scenario";

interface Scenario {
  noteId: string;
  note: string | null;
  tags?: string[];
  failLoad?: boolean | "once" | "hang";
  failSave?: boolean | "once";
  candidates?: { id: string; title: string }[];
  /** `mod+shift+l` 时追加到文本末尾的内容（构造「最后输入」用）。 */
  append?: string;
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

/** 一行包含特殊字符的 Markdown fixture：笔记链接（P4-2 新格式
 *  `[alias](cardmind://note/id)`）、3+ 空行、代码块、段内换行
 *  （`行一\n行二` 是同一段的两行）与中文。 */
const FIXTURE =
  "# 标题\n\n[别名](cardmind://note/note-2) 与 [note-3](cardmind://note/note-3)\n\n行一\n行二\n\n\n\n```\nconst x = 1;\n```\n";

test("editor: 打开已有笔记时加载完成才挂载 Editor，markdown 逐字节显示且不落盘", async () => {
  const app = await openEditor({ noteId: "note-1", note: FIXTURE, tags: ["工作"] });
  await app.waitFor(EDITOR);
  await app.keyboard.press("mod+shift+e");
  await app.waitUntil(() => app.storage()["test.editorDumpSeq"] === "1");
  expect(app.storage()["test.editorValue"]).toBe(FIXTURE);
  await app.wait(900);
  expect(calls(app).noteCreate).toBe(0);
  expect(saved(app)).toBeNull();
});

test("editor: 加载中不挂 Editor（noteGet 未完成）", async () => {
  const app = await openEditor({ noteId: "note-1", note: "abc", failLoad: "hang" });
  // harness 的 Storage.getItem 异步完成后才 nav.push；先等 loading 出现再断言，
  // 否则断言可能落在 notes stub 上（第 1 轮审查的 13/14↔14/14 不稳定来源）。
  await app.waitFor("id:editor-loading");
  expect(app.shows(EDITOR)).toBe(false);
  expect(hasText(app, "加载中")).toBe(true);
});

test("editor: 加载失败显示错误态、不写入；重试成功后挂载并显示原文", async () => {
  const app = await openEditor({ noteId: "note-1", note: "abc", failLoad: "once" });
  await app.waitFor("text:/加载失败/");
  expect(app.shows(EDITOR)).toBe(false);
  await app.wait(900);
  expect(calls(app).noteCreate).toBe(0);
  expect(saved(app)).toBeNull();
  await app.press(RETRY);
  await app.waitFor(EDITOR);
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
  expect(app.shows(EDITOR)).toBe(false);
  await app.clock.runFor(10_500);
  await app.waitFor("text:/加载失败/");
  expect(app.shows(EDITOR)).toBe(false);
  expect(calls(app).noteCreate).toBe(0);
  expect(saved(app)).toBeNull();
});

test("editor: 新笔记输入停止 700ms 后自动保存，顺序与单次 UUID", async () => {
  const app = await openEditor({ noteId: "new", note: null });
  await app.waitFor(EDITOR);
  expect(app.texts()).toContain("尚未保存");
  await app.type(EDITOR, "hello");
  await app.wait(200);
  expect(saved(app)).toBeNull(); // 700ms 去抖未到
  await app.wait(800);
  await app.waitUntil(() => app.storage()["test.saved"] === "hello");
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
  await app.type(EDITOR, "!");
  await app.wait(900);
  await app.waitUntil(() => app.storage()["test.saved"] === "hello!");
  expect(calls(app).generateNoteId).toBe(1);
});

test("editor: 新笔记空内容不创建；已有笔记允许保存空内容", async () => {
  const fresh = await openEditor({ noteId: "new", note: null });
  await fresh.waitFor(EDITOR);
  await fresh.wait(900);
  expect(calls(fresh).noteCreate).toBe(0);
  expect(saved(fresh)).toBeNull();
  expect(fresh.texts()).toContain("尚未保存");

  const existing = await openEditor({ noteId: "note-1", note: "abc" });
  await existing.waitFor(EDITOR);
  expect(existing.texts()).toContain("abc");
  await existing.press("text:abc");
  await existing.keyboard.press("mod+a");
  await existing.keyboard.press("backspace");
  await existing.wait(900);
  await existing.waitUntil(() => existing.storage()["test.saved"] === "");
  expect(calls(existing).noteCreate).toBe(1);
  expect(existing.texts()).toContain("已保存");
});

test("editor: 保存失败显示错误、不谎报已保存；重试成功后恢复", async () => {
  const app = await openEditor({ noteId: "new", note: null, failSave: "once" });
  await app.waitFor(EDITOR);
  await app.type(EDITOR, "x");
  await app.wait(900);
  await app.waitFor("text:/保存失败/");
  expect(app.texts()).not.toContain("已保存");
  expect(saved(app)).toBeNull();
  expect(calls(app).noteCreate).toBe(1);
  await app.press(RETRY);
  await app.waitUntil(() => app.storage()["test.saved"] === "x");
  expect(app.texts()).toContain("已保存");
  expect(calls(app).noteCreate).toBe(2);
});

test("editor: 关闭时 dirty → 先 flush 最新 editor.value() 再返回，重开内容 = 最后输入", async () => {
  const app = await openEditor({ noteId: "note-1", note: "base", append: "Z" });
  await app.waitFor(EDITOR);
  // 用 harness 的探针键在文本末尾插入（走 Editor.edit 公开 API，等价用户输入）。
  await app.keyboard.press("mod+shift+l");
  await app.waitUntil(() => app.storage()["test.editorValue"] === "baseZ");
  expect(saved(app)).toBeNull(); // 去抖尚未触发
  await app.back();
  await app.waitFor("id:notes-stub");
  await app.waitUntil(() => app.storage()["test.saved"] !== undefined);
  // 断言等于预期最后输入，而不是「重开内容 == 已保存内容」这种自证式比较。
  expect(app.storage()["test.saved"]).toBe("baseZ");
  expect(calls(app).noteCreate).toBe(1);
  expect(app.shows(EDITOR)).toBe(false);
  // 重新打开：内容 = 关闭前最后输入
  await app.press("id:open-editor");
  await app.waitFor(EDITOR);
  await app.keyboard.press("mod+shift+e");
  await app.waitUntil(() => app.storage()["test.editorDumpSeq"] === "2");
  expect(app.storage()["test.editorValue"]).toBe("baseZ");
});

test("editor: 新笔记只输入空白时按返回直接回列表（不创建、不落盘、不卡死）", async () => {
  const app = await openEditor({ noteId: "new", note: null });
  await app.waitFor(EDITOR);
  await app.type(EDITOR, "   ");
  expect(saved(app)).toBeNull();
  await app.back();
  await app.waitFor("id:notes-stub");
  expect(app.shows(EDITOR)).toBe(false);
  expect(calls(app).noteCreate).toBe(0);
  expect(calls(app).generateNoteId).toBe(0);
  expect(saved(app)).toBeNull();
  await app.wait(900);
  expect(saved(app)).toBeNull();
});

test("editor: markdown 逐字节保真（wikilink/3+空行/代码块/段内换行/中文）加载→编辑→保存→重开", async () => {
  const app = await openEditor({ noteId: "note-1", note: FIXTURE, append: "Z" });
  await app.waitFor(EDITOR);
  // 加载后 Editor 全文必须与 fixture 逐字节相等（LF fixture，无归一化）。
  await app.keyboard.press("mod+shift+e");
  await app.waitUntil(() => app.storage()["test.editorDumpSeq"] === "1");
  expect(app.storage()["test.editorValue"]).toBe(FIXTURE);
  // 编辑（末尾加 Z）→ 700ms 去抖保存 → 保存内容 = fixture + Z，逐字节相等。
  await app.keyboard.press("mod+shift+l");
  await app.waitUntil(() => app.storage()["test.editorValue"] === `${FIXTURE}Z`);
  await app.wait(900);
  await app.waitUntil(() => app.storage()["test.saved"] === `${FIXTURE}Z`);
  expect(app.storage()["test.saved"]).toBe(`${FIXTURE}Z`);
  // 关闭 → 重开：再次读全文，仍是同一字节串（不因保存/重开漂移）。
  await app.back();
  await app.waitFor("id:notes-stub");
  await app.press("id:open-editor");
  await app.waitFor(EDITOR);
  await app.keyboard.press("mod+shift+e");
  await app.waitUntil(() => app.storage()["test.editorDumpSeq"] === "3");
  expect(app.storage()["test.editorValue"]).toBe(`${FIXTURE}Z`);
});

test("editor: CRLF 笔记按 0.3.0 口径归一为 LF（唯一允许的归一），其余逐字节保留", async () => {
  const crlf = "# 标题\r\n\r\n[别名](cardmind://note/note-2)\r\n\r\n\r\n\r\n```\r\nconst x = 1;\r\n```\r\n";
  const lf = crlf.replace(/\r\n/g, "\n");
  const app = await openEditor({ noteId: "note-1", note: crlf });
  await app.waitFor(EDITOR);
  await app.keyboard.press("mod+shift+e");
  await app.waitUntil(() => app.storage()["test.editorDumpSeq"] === "1");
  // 口径：`Editor` 只把 `\r\n`/`\r` 归一为 `\n`（05 §1.2），App 侧加载同口径。
  expect(app.storage()["test.editorValue"]).toBe(lf);
  await app.wait(900);
  // 未编辑 → 不 dirty → 不回写（不产生 noteCreate）。
  expect(saved(app)).toBeNull();
  expect(calls(app).noteCreate).toBe(0);
});

test("editor: 关闭时保存失败留在页面，可重试后再返回", async () => {
  const app = await openEditor({ noteId: "new", note: null, failSave: "once" });
  await app.waitFor(EDITOR);
  await app.type(EDITOR, "x");
  await app.back();
  await app.waitFor("text:/保存失败/");
  expect(app.shows(EDITOR)).toBe(true);
  expect(app.shows("id:notes-stub")).toBe(false);
  await app.press(RETRY);
  await app.waitUntil(() => app.storage()["test.saved"] === "x");
  expect(app.shows(EDITOR)).toBe(true); // 重试成功不自动离开
  await app.back();
  await app.waitFor("id:notes-stub");
});

test("editor: [[ 触发候选（来自 autoCompleteLinks），点选插入 [title](cardmind://note/id) 且无残留", async () => {
  const app = await openEditor({
    noteId: "note-1",
    note: "",
    candidates: [
      { id: "note-2", title: "会议记录" },
      { id: "note-1", title: "自身笔记" },
    ],
  });
  await app.waitFor(EDITOR);
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

test("editor: [[ 前缀含空格仍出候选（不依赖内建 completion 的 word 限制）", async () => {
  const app = await openEditor({
    noteId: "note-1",
    note: "",
    candidates: [{ id: "note-2", title: "Weekly Buffer" }],
  });
  await app.waitFor(EDITOR);
  await app.type(EDITOR, "[[Weekly ");
  await app.waitFor("id:link-note-2");
  expect(calls(app).autoCompleteLinks[calls(app).autoCompleteLinks.length - 1]).toBe("Weekly ");
  await app.press("id:link-note-2");
  await app.waitUntil(() => hasText(app, "[Weekly Buffer](cardmind://note/note-2)"));
});

test("editor: 标签行显示 tags；光标前命中标签时高亮；无标签不显示空行", async () => {
  const app = await openEditor({ noteId: "note-1", note: "工作 记录", tags: ["工作", "笔记"] });
  await app.waitFor(EDITOR);
  await app.waitFor("label:工作");
  expect(app.shows("label:笔记")).toBe(true);
  const plain = app.spanStyle("id:tag-text-0");
  await app.type(EDITOR, "[[工");
  await app.wait(100);
  const hit = app.spanStyle("id:tag-text-0");
  expect(hit.color).not.toBe(plain.color);

  const noTags = await openEditor({ noteId: "note-1", note: "无标签", tags: [] });
  await noTags.waitFor(EDITOR);
  expect(noTags.shows("label:工作")).toBe(false);
});

test("editor: 内建撤销可用（输入 → mod+z 回退），不产生错误保存", async () => {
  const app = await openEditor({ noteId: "new", note: null });
  await app.waitFor(EDITOR);
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
  await app.waitFor(EDITOR);
  await app.type(EDITOR, "移动");
  await app.back();
  await app.waitFor("id:notes-stub");
  await app.waitUntil(() => app.storage()["test.saved"] === "移动");
});

// ─── P3：TextView 预览（移动/桌面）───────────────────────────────────────────

test("editor: 切换到预览渲染标题/列表/引用/代码，切回编辑源码字节不变", async () => {
  const doc =
    "# 大标题\n\n- 项一\n- 项二\n\n> 引用一句话\n\n```\nconst x = 1;\n```\n\n正文段落。\n";
  const app = await openEditor({ noteId: "note-1", note: doc }, { width: 390, height: 844 });
  await app.waitFor(EDITOR);
  // 编辑态看不到渲染后的「大标题」（TextView 才渲染）。
  expect(app.shows("id:preview")).toBe(false);
  await app.press("label:预览");
  await app.waitFor("id:preview");
  // 渲染后四类块都在（标题/列表项/引用/代码）。源码标记 `#`/`-`/`>` 不直接出现。
  expect(hasText(app, "大标题")).toBe(true);
  expect(hasText(app, "项一")).toBe(true);
  expect(hasText(app, "引用一句话")).toBe(true);
  expect(hasText(app, "const x = 1;")).toBe(true);
  // 切回编辑：源码逐字节不变。
  await app.press("label:编辑");
  await app.waitFor(EDITOR);
  await app.keyboard.press("mod+shift+e");
  await app.waitUntil(() => app.storage()["test.editorDumpSeq"] !== undefined);
  expect(app.storage()["test.editorValue"]).toBe(doc);
});

test("editor: 预览中 [alias](cardmind://note/id) 渲染为链接，按下跳转目标笔记", async () => {
  const doc = "前文 [会议别名](cardmind://note/note-2) 与 [note-3](cardmind://note/note-3) 后文\n";
  const app = await openEditor({
    noteId: "note-1",
    note: doc,
    notes: [
      { id: "note-1", content: doc },
      { id: "note-2", content: "note-2 的正文内容" },
      { id: "note-3", content: "note-3 的正文内容" },
    ],
  }, { width: 390, height: 844 });
  await app.waitFor(EDITOR);
  await app.press("label:预览");
  await app.waitFor("id:preview");
  // alias 显示为链接文本；无 alias 的显示写入的文本（target id）。
  expect(hasText(app, "会议别名")).toBe(true);
  expect(hasText(app, "note-3")).toBe(true);
  // 按下笔记链接 → openEditor(note-2) push 新编辑页（重建 Editor 实例）。
  await app.press("text:会议别名");
  await app.waitUntil(() => app.storage()["test.editorMountCount"] === "2");
  await app.waitFor(EDITOR);
  await app.keyboard.press("mod+shift+e");
  await app.waitUntil(() => app.storage()["test.editorValue"] === "note-2 的正文内容");
});

test("editor: 旧格式 [[id|alias]] 笔记加载即显示新格式，保存后落盘为新格式（惰性迁移）", async () => {
  const legacy = "前文 [[note-2|会议别名]] 与 [[note-3]] 后文\n";
  const migrated = "前文 [会议别名](cardmind://note/note-2) 与 [note-3](cardmind://note/note-3) 后文\n";
  const app = await openEditor({ noteId: "note-1", note: legacy, append: "X" });
  await app.waitFor(EDITOR);
  // 编辑器里显示新格式（加载归一）；未编辑不回写。
  await app.keyboard.press("mod+shift+e");
  await app.waitUntil(() => app.storage()["test.editorDumpSeq"] === "1");
  expect(app.storage()["test.editorValue"]).toBe(migrated);
  await app.wait(900);
  expect(saved(app)).toBeNull();
  expect(calls(app).noteCreate).toBe(0);
  // 末尾插入一次编辑 → 保存 → 存储为新格式（不再含 [[）。
  await app.keyboard.press("mod+shift+l");
  await app.wait(900);
  await app.waitUntil(() => app.storage()["test.saved"] === `${migrated}X`);
  expect(app.storage()["test.saved"]).toBe(`${migrated}X`);
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
  await app.waitFor(EDITOR);
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
  await app.waitFor(EDITOR);
  // 在 A 末尾插入 X（未保存，dirty）。
  await app.keyboard.press("mod+shift+l");
  await app.waitUntil(() => app.storage()["test.editorValue"] === "AAAAX");
  // 切到 B（触发 key 重建 + unmount flush A）。
  await app.press("id:note-item-note-b");
  await app.waitFor(EDITOR);
  // B 的内容是 BBBB，不是 AAAA（没共享撤销栈/没串文）。
  await app.keyboard.press("mod+shift+e");
  await app.waitUntil(() => app.storage()["test.editorValue"] === "BBBB");
  // 在 B 上撤销应只影响 B（这里 B 无未保存编辑，canUndo 可能无操作；
  // 关键是按 mod+z 不会把 A 的 X 撤掉后串进 B）。
  await app.keyboard.press("mod+z");
  await app.wait(300);
  expect(app.storage()["test.editorValue"]).toBe("BBBB");
  // 切回 A：A 显示它自己的内容（含已 flush 的 AAAAX）。
  await app.press("id:note-item-note-a");
  await app.waitFor(EDITOR);
  await app.keyboard.press("mod+shift+e");
  await app.waitUntil(() => app.storage()["test.editorValue"] === "AAAAX");
  expect(app.storage()["test.saved.note-a"]).toBe("AAAAX");
});

// P4 AC1：能区分「每次切换得到新 Editor 实例」与「同一实例 setValue 重载」。
// 观测：EditorHarness 的 `recordEditorRef` 对 ref 回调收到的每个**新实例** +1
// 并写入 `test.editorMountCount`。计数由「新 Editor 实例挂载」驱动：切换 A→B→A
// 若每次都挂载新实例，计数单调递增到 3。
// 判别力（实测）：同一实例 `setValue("BBBB")` 重载后计数仍停在 1；把
// `DesktopEditorPane` 退化为固定首篇 id（复用单实例）后本测试必失败（恢复后通过）。
// 注意：task 建议的 `key={() => 0}` 变异在 0.3.0 下无效——`Each` 位于响应式
// thunk 内，选中变化即整段重建，key 不参与重建决策（详见 .pipeline/executor.md）。
test("editor: 桌面第三栏 Each key 判别——A→B→A 每次切换都新建 Editor 实例", async () => {
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
  await app.waitFor(EDITOR);
  // A 首挂载：一个 EditorRef 实例。
  await app.waitUntil(() => app.storage()["test.editorMountCount"] === "1");
  // 在 A 末尾插入 Y（dirty，用于验证切回 A 后内容与撤销栈）。
  await app.keyboard.press("mod+shift+l");
  await app.waitUntil(() => app.storage()["test.editorValue"] === "AAAAY");
  // A→B：切换笔记 → Editor 重建 → 第 2 个 ref 实例。
  await app.press("id:note-item-note-b");
  await app.waitUntil(() => app.storage()["test.editorMountCount"] === "2");
  await app.keyboard.press("mod+shift+e");
  await app.waitUntil(() => app.storage()["test.editorValue"] === "BBBB");
  // B→A：再次重建 → 第 3 个 ref 实例（不是回到第 1 个实例的存活状态）。
  await app.press("id:note-item-note-a");
  await app.waitUntil(() => app.storage()["test.editorMountCount"] === "3");
  await app.keyboard.press("mod+shift+e");
  await app.waitUntil(() => app.storage()["test.editorValue"] === "AAAAY");
  // 计数随切换单调递增：2 次切换 = 2 次新建（不含复用）。
  expect(app.storage()["test.editorMountCount"]).toBe("3");
  // 撤销栈随实例重建：回 A 后 mod+z 不会撤掉 flush 前的编辑再把内容串错
  // （A 重建后的基线就是已落盘的 AAAAY，无可撤销项）。
  await app.keyboard.press("mod+z");
  await app.wait(300);
  await app.keyboard.press("mod+shift+e");
  await app.waitUntil(() => app.storage()["test.editorValue"] === "AAAAY");
  expect(app.storage()["test.editorValue"]).toBe("AAAAY");
});

test("editor: 桌面 ≥1280 预览并排（Editor 与 TextView 同屏）", async () => {
  const doc = "# 并排\n\n- 列表项\n";
  const app = await open("./EditorHarness.tsx", {
    width: 1400,
    height: 900,
    storage: scenarioStorage({ noteId: "note-1", note: doc }),
  });
  await app.waitFor(EDITOR);
  await app.press("label:预览");
  await app.waitFor("id:preview");
  // 并排：Editor 仍显示（编辑可继续），同时预览渲染标题。
  expect(app.shows(EDITOR)).toBe(true);
  expect(hasText(app, "并排")).toBe(true);
});

test("editor: 桌面第三栏按下笔记链接 → onNavigateNote 切选中（不 push 路由）", async () => {
  const app = await openDesktop({
    noteId: "note-a",
    note: null,
    mode: "desktop",
    notes: [
      { id: "note-a", content: "看 [B 的别名](cardmind://note/note-b)" },
      { id: "note-b", content: "note-b 正文" },
    ],
    selectedNoteId: "note-a",
  });
  await app.waitFor("id:desktop-notes");
  await app.waitFor(EDITOR);
  await app.press("label:预览");
  await app.waitFor("id:preview");
  expect(hasText(app, "B 的别名")).toBe(true);
  await app.press("text:B 的别名");
  // harness 的 onNavigateNote 写 selected → 第三栏换到 note-b。
  await app.waitFor(EDITOR);
  await app.keyboard.press("mod+shift+e");
  await app.waitUntil(() => app.storage()["test.editorValue"] === "note-b 正文");
});

// ─── P3：Escape 清候选 ────────────────────────────────────────────────────────

test("editor: 候选打开时用「关闭候选」入口收起候选且不退出编辑页", async () => {
  // 限制（探测证据见 .pipeline/executor.md）：0.3.0 `Editor` 聚焦时吞掉 Escape，
  // `keymap.bind("escape", …, { when: "always" })` 也收不到；故提供可见的
  // 「关闭候选」按钮作为替代关闭路径（touch/无硬件键盘同样可用）。
  const app = await openEditor({
    noteId: "note-1",
    note: "",
    candidates: [{ id: "note-2", title: "会议记录" }],
  });
  await app.waitFor(EDITOR);
  await app.type(EDITOR, "[[");
  await app.waitFor("id:link-candidates");
  await app.press("label:关闭候选");
  await app.waitFor("id:link-candidates", { state: "gone" });
  expect(app.shows(EDITOR)).toBe(true); // 仍在编辑页
  expect(app.shows("id:notes-stub")).toBe(false); // 未退回列表
});

// ─── P3：Editor autoFocus ─────────────────────────────────────────────────────

test("editor: 打开编辑页可直接输入（无需先 press 聚焦）", async () => {
  // `EditorProps.autoFocus` 已开启；headless `nsh test` 无法断言真实焦点
  // （`keyboard.press("a")` 不走 Editor 输入 sink），故按 task.md 允许的口径：
  // 打开后直接 `app.type` 即可输入、不必先 `press` 聚焦，autoFocus 的真实
  // 键盘焦点行为留待 `--target`/真机手工确认（见 executor.md）。
  const app = await openEditor({ noteId: "new", note: null });
  await app.waitFor(EDITOR);
  await app.type(EDITOR, "直接输入");
  await app.keyboard.press("mod+shift+e");
  await app.waitUntil(() => app.storage()["test.editorDumpSeq"] !== undefined);
  expect(app.storage()["test.editorValue"]).toBe("直接输入");
});

// ─── P3：回归补强 ─────────────────────────────────────────────────────────────

test("editor: 未编辑 CRLF 笔记关闭后不回写（noteCreate=0）", async () => {
  const crlf = "# 标题\r\n\r\n正文\r\n";
  const app = await openEditor({ noteId: "note-1", note: crlf });
  await app.waitFor(EDITOR);
  // 不做任何编辑，直接关闭。
  await app.back();
  await app.waitFor("id:notes-stub");
  await app.wait(300);
  // 归一化后 text == lastSaved，不是 dirty → 不产生 noteCreate。
  expect(calls(app).noteCreate).toBe(0);
  expect(saved(app)).toBeNull();
});

test("editor: onChange 未触发时关闭仍用 editor.value() 保存最新文本", async () => {
  // append 走 Editor.edit 公开 API 改文本；若某运行时下 onChange 未同步信号，
  // 关闭路径的 readLatestText()（editor.value()）仍能拿到最新内容。
  const app = await openEditor({ noteId: "note-1", note: "base", append: "-尾部" });
  await app.waitFor(EDITOR);
  await app.keyboard.press("mod+shift+l");
  await app.waitUntil(() => app.storage()["test.editorValue"] === "base-尾部");
  await app.back();
  await app.waitFor("id:notes-stub");
  await app.waitUntil(() => app.storage()["test.saved"] !== undefined);
  // 关键：保存的是 editor.value() 的最新文本（base-尾部），不是陈旧的信号值。
  expect(app.storage()["test.saved"]).toBe("base-尾部");
});

// ─── P4 AC3：5 万字 Markdown 预览切换性能测量 ────────────────────────────────

/** 构造 ≈50,000 字 Markdown（标题/列表/引用/代码块/wikilink/中文，均匀分布）。 */
function bigMarkdown(targetChars: number): string {
  const parts: string[] = [];
  let n = 0;
  let block = 0;
  while (n < targetChars) {
    block += 1;
    const seg =
      `# 第 ${block} 节 标题\n\n` +
      `正文段落，含 [别名${block}](cardmind://note/note-${block}) 与普通文本，用来撑大预览解析成本。` +
      `中文内容若干，重复填充以达到五万字量级的真实文档。\n\n` +
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

test("editor: 5 万字 Markdown 预览切换性能（墙钟采样）", async () => {
  // 5 万字 TextView 在 headless 下渲染成本随整机负载大幅波动（实测单轮
  // 2.8s–8.8s，重载时 >30s）。固定 20 次采样 × 30s 超时在满载机器上必然
  // 超测时上限。故：自适应采样——在单测剩余预算内尽量多测（目标 ≥20，满载
  // 时降级到 ≥3 仍能产出有效分布）；每轮 waitFor 给足超时，让耗时真实反映
  // 渲染成本而非被截断。headless 数字只反映 JS 端解析/布局，真机复测见
  // docs/testing/nsh-p4-windows-ime-checklist.md §E。
  const doc = bigMarkdown(50_000);
  const app = await openEditor({ noteId: "note-1", note: doc }, { width: 390, height: 844 });
  await app.waitFor(EDITOR);
  const samples: number[] = [];
  const budgetMs = 240_000; // 单测 300s 上限内留 60s 余量给装载/收尾。
  const started = Date.now();
  const TARGET = 20;
  const MIN_SAMPLES = 3;
  for (let i = 0; i < TARGET; i += 1) {
    const t0 = Date.now();
    await app.press("label:预览");
    // headless 下 `id:preview`（TextView testID）不可选；预览「渲染完成」
    // 以首个笔记链接的文本出现为代理（P4-2 后链接是内建 link，不再有
    // wikilink-<id> 的 renderCustom testID）。
    await app.waitFor("text:别名1", { timeout: 90_000 });
    samples.push(Date.now() - t0);
    // 回到编辑态（5 万字 Editor 重挂载同样受整机负载影响，给足超时避免
    // 「返回编辑」这一步把整轮打挂；这一步不计入「打开预览」样本）。
    await app.press("label:编辑");
    await app.waitFor(EDITOR, { timeout: 90_000 });
    // 预算耗尽则停止（保住「有样本」而非「凑满 20」）。
    if (Date.now() - started > budgetMs) break;
  }
  samples.sort((a, b) => a - b);
  const n = samples.length;
  const p50 = percentile(samples, 50);
  const p95 = percentile(samples, 95);
  const min = samples[0];
  const max = samples[n - 1];
  console.log(
    `[perf] preview-toggle ${doc.length} chars, n=${n} (target ${TARGET}), ` +
      `min=${min}ms p50=${p50}ms p95=${p95}ms max=${max}ms ` +
      `(headless, wall-clock Date.now())`,
  );
  console.log(`[perf] samples(ms)=${JSON.stringify(samples)}`);
  // 行为断言只锁「测到了有效样本」：不锁固定次数/阈值（满载机器会撑爆固定
  // 20×30s 上限；headless 数字本身不是验收阈值，见 task.md AC3 口径）。
  expect(n).toBeGreaterThanOrEqual(MIN_SAMPLES);
  expect(p95).toBeGreaterThanOrEqual(p50);
}, 300_000);
