import { expect, open, test } from "nsh/test";

const EDITOR = "label:Markdown source";
const ROW = "text:# CardMind 探针";

function readLen(app: { texts(): string[] }): number {
  const line = app.texts().find((text) => text.startsWith("stats: len=")) ?? "stats: len=0";
  return Number(line.slice("stats: len=".length).split(" ")[0]);
}

test("opens the Markdown source editor and the TextView preview", async () => {
  const app = await open("./App.tsx", { width: 1200, height: 900 });
  await app.waitFor("text:/stats: len=/");
  const texts = app.texts();
  // The source, line by line.
  expect(texts).toContain("# CardMind 探针");
  expect(texts.some((text) => text.includes("[[会议记录]]"))).toBe(true);
  // The preview: a heading, a list's markers, a table's cells, a code block.
  expect(app.shows("CardMind 探针")).toBe(true);
  expect(app.shows("列 A")).toBe(true);
  expect(app.shows("fn main() { println!(\"hi\"); }")).toBe(true);
});

test("typing with the keyboard grows the text", async () => {
  const app = await open("./App.tsx", { width: 1200, height: 900 });
  await app.waitFor("text:/stats: len=/");
  await app.press(ROW);
  const before = readLen(app);
  for (const key of ["x", "y", "z"]) await app.keyboard.press(key);
  await app.waitFor(`text:/stats: len=${before + 3} /`);
});

test("CJK characters typed through the platform input insert (no IME composition)", async () => {
  const app = await open("./App.tsx", { width: 1200, height: 900 });
  await app.waitFor("text:/stats: len=/");
  const before = readLen(app);
  await app.type(EDITOR, "中文输入");
  await app.waitFor(`text:/stats: len=${before + 4} /`);
});

test("[[ asks for completions and accepting one inserts the wikilink", async () => {
  const app = await open("./App.tsx", { width: 1200, height: 900 });
  await app.waitFor("text:/stats: len=/");
  await app.press(ROW);
  await app.keyboard.press("[");
  await app.keyboard.press("[");
  await app.waitFor("text:/completion: trigger=character char=\\[\\[ q=\"\" /", { timeout: 8000 });
  await app.waitFor("text:会议记录", { timeout: 5000 });
  await app.keyboard.press("enter");
  await app.waitFor("text:/accepted: 会议记录/");
  await app.press("Read value");
  await app.waitFor("text:/read: len=/");
  expect(app.texts().some((text) => text.includes("[[会议记录]]"))).toBe(true);
});

test("undo takes typing back", async () => {
  const app = await open("./App.tsx", { width: 1200, height: 900 });
  await app.waitFor("text:/stats: len=/");
  await app.press(ROW);
  const before = readLen(app);
  for (const key of ["x", "y", "z"]) await app.keyboard.press(key);
  await app.waitFor(`text:/stats: len=${before + 3} /`);
  await app.keyboard.press("mod+z");
  await app.waitFor(`text:/stats: len=${before} /`);
});

test("50k characters round-trip through setValue and value(), timed", async () => {
  const app = await open("./App.tsx", { width: 1200, height: 900 });
  await app.waitFor("text:/stats: len=/");
  await app.press("Perf 50k");
  await app.waitFor("text:/perf: set=/", { timeout: 15000 });
  const line = app.texts().find((text) => text.startsWith("perf: set=")) ?? "";
  console.log("PERF", line);
  expect(line).toMatch(/len=5\d{4,} same=yes/);
});

test("the preview pane hides and shows again", async () => {
  const app = await open("./App.tsx", { width: 1200, height: 900 });
  await app.waitFor("text:/stats: len=/");
  expect(app.count("text:CardMind 探针")).toBe(1);
  await app.press("Preview");
  await app.waitFor("CardMind 探针", { state: "gone" });
  await app.press("Preview");
  await app.waitFor("CardMind 探针");
});

test("a link of the TextView reports its press", async () => {
  const app = await open("./App.tsx", { width: 1200, height: 900 });
  await app.waitFor("text:/stats: len=/");
  await app.press("id:preview >> text:NSH 文档");
  await app.waitFor("text:/link: https:\\/\\/nsh.dev/", { timeout: 5000 });
});
