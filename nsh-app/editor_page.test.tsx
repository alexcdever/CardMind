// 编辑页行为测试（`nsh test`；harness = EditorHarness.tsx，假 repository，不碰真实 DB/iroh）。
//
// 覆盖 task.md 标准 1–6、8 的行为面：
//  ① 打开已有笔记：加载完成才挂载 Editor、文本原样显示；
//  ② 700ms 自动保存 + 保存顺序 + 新笔记只生成一次 id；
//  ③ 关闭 dirty → 先 flush 再返回；保存失败留页可重试；
//  ④ 加载失败 / 超时 → 错误态，不创建/不覆盖；
//  ⑤ `[[` 候选（含空格前缀）来自 autoCompleteLinks，点选插入 `[[id|title]] `；
//  ⑥ 标签行显示与命中高亮；
//  ⑦ 撤销可用。
import { expect, open, test } from "nsh/test";
import type { App } from "nsh/test";

const EDITOR = "label:Markdown 编辑器";
const BACK = "label:返回";
const RETRY = "label:重试";
const SCENARIO_KEY = "test.scenario";

interface Scenario {
  noteId: string;
  note: string | null;
  tags?: string[];
  failLoad?: boolean | "once" | "hang";
  failSave?: boolean | "once";
  candidates?: { id: string; title: string }[];
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

/** 一行包含特殊字符的 Markdown fixture：wikilink（id|alias）、3+ 空行、代码块。 */
const FIXTURE =
  "# 标题\n\n[[note-2|别名]] 与 [[note-3]]\n\n行一\n行二\n\n\n\n```\nconst x = 1;\n```\n";

test("editor: 打开已有笔记时加载完成才挂载 Editor，markdown 原样显示且不落盘", async () => {
  const app = await openEditor({ noteId: "note-1", note: FIXTURE, tags: ["工作"] });
  await app.waitFor(EDITOR);
  expect(app.texts()).toContain("# 标题");
  expect(hasText(app, "[[note-2|别名]] 与 [[note-3]]")).toBe(true);
  expect(app.texts()).toContain("const x = 1;");
  await app.wait(900);
  expect(calls(app).noteCreate).toBe(0);
  expect(saved(app)).toBeNull();
});

test("editor: 加载中不挂 Editor（noteGet 未完成）", async () => {
  const app = await openEditor({ noteId: "note-1", note: "abc", failLoad: "hang" });
  expect(app.shows(EDITOR)).toBe(false);
  expect(hasText(app, "加载中")).toBe(true);
  expect(app.shows("id:editor-loading")).toBe(true);
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

test("editor: 关闭时 dirty → 先 flush 最新文本再返回，重开内容一致", async () => {
  const app = await openEditor({ noteId: "note-1", note: "base" });
  await app.waitFor(EDITOR);
  await app.type(EDITOR, "Z");
  expect(saved(app)).toBeNull(); // 去抖尚未触发
  await app.back();
  await app.waitFor("id:notes-stub");
  await app.waitUntil(() => app.storage()["test.saved"] !== undefined);
  const savedText = app.storage()["test.saved"];
  expect(savedText).not.toBeNull();
  expect(calls(app).noteCreate).toBe(1);
  expect(app.shows(EDITOR)).toBe(false);
  // 重新打开：内容 = 关闭前最后输入
  await app.press("id:open-editor");
  await app.waitFor(EDITOR);
  expect(app.texts()).toContain(savedText);
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

test("editor: [[ 触发候选（来自 autoCompleteLinks），点选插入 [[id|title]] 且无残留", async () => {
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
  expect(hasText(app, "[[note-2|会议记录]]")).toBe(true);
  expect(hasText(app, "[[]]") || hasText(app, "[[[")).toBe(false);
  await app.wait(900);
  await app.waitUntil(
    () => app.storage()["test.saved"] === "[[note-2|会议记录]] ",
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
  await app.waitUntil(() => hasText(app, "[[note-2|Weekly Buffer]]"));
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
