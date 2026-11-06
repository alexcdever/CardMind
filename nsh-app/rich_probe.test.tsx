// P4-3a 探针测试（`nsh test`）：验证 0.4.0 `createRichEditor`/`starterSchema`
// 的 Markdown 往返保真度与 `<RichEditor>` 的 headless 挂载。输入经 storage
// `probe.inputs`（JSON 字符串数组）注入；RichProbeHarness 逐个
// createRichEditor → serialize("markdown") 写回 `probe.out.<i>`。
import { expect, open, test } from "nsh/test";

/** 覆盖 AC3 要求的结构：标题/段落/有序无序列表/引用/代码块/分隔线/
 *  粗斜体/行内代码/链接（含 cardmind://）/删除线/下划线/硬换行/3+ 空行。 */
const INPUTS: string[] = [
  // 0: 基础块结构
  "# 标题一\n\n正文段落。\n\n## 二级标题\n\n- 项一\n- 项二\n  - 子项\n\n1. 第一步\n2. 第二步\n\n> 引用一句话\n\n```\nconst x = 1;\n```\n\n---\n",
  // 1: 行内标记 + cardmind 链接
  "前文 [会议别名](cardmind://note/note-2) 与 [外链](https://example.com) 后文\n\n**粗**、*斜*、`行内代码`、~~删~~\n",
  // 2: 段内换行 + 3+ 空行（现有 FIXTURE 的形态）
  "# 标题\n\n[别名](cardmind://note/note-2) 与 [note-3](cardmind://note/note-3)\n\n行一\n行二\n\n\n\n```\nconst x = 1;\n```\n",
  // 3: 空文档与纯文本
  "",
  // 4: 下划线（starter schema 声称支持 underline；Markdown 无原生语法）
  "<u>下划线</u> 与 _em_ 混排\n",
  // 5: 5 万字级文档（构造与 editor_page.test.tsx 的 bigMarkdown 同型）。
  (() => {
    const parts: string[] = [];
    for (let block = 1; block <= 120; block += 1) {
      parts.push(
        `# 第 ${block} 节 标题\n\n` +
          `正文段落，含 [别名${block}](cardmind://note/note-${block}) 与普通文本，用来撑大解析成本。` +
          `中文内容若干，重复填充以达到五万字量级的真实文档。\n\n` +
          `- 列表项一\n- 列表项二\n- 列表项三\n\n` +
          `> 引用一句话，来自第 ${block} 节。\n\n` +
          "```\nconst x" + block + " = " + block + ";\n```\n\n",
      );
    }
    return parts.join("");
  })(),
];

test("probe: Markdown 往返（serialize('markdown') vs getMarkdown）", async () => {
  const app = await open("./RichProbeHarness.tsx", {
    width: 1200,
    height: 900,
    storage: { "probe.inputs": JSON.stringify(INPUTS) },
  });
  await app.waitUntil(() => app.storage()["probe.done"] === "1");
  for (let i = 0; i < INPUTS.length; i += 1) {
    const out = app.storage()[`probe.out.${i}`];
    const getmd = app.storage()[`probe.getmd.${i}`];
    const same = app.storage()[`probe.same.${i}`];
    const ms = app.storage()[`probe.ms.${i}`];
    console.log(`--- input[${i}] (${ms}) ---`);
    console.log(INPUTS[i]);
    console.log(`--- out[${i}] (schema.serialize) ---`);
    console.log(out);
    console.log(`--- getmd[${i}] (session.getMarkdown) ---`);
    console.log(getmd);
    console.log(`same=${same}`);
  }
  // 宽松断言：所有输入都产出非 undefined 的输出（往返具体差异人工读日志定）。
  for (let i = 0; i < INPUTS.length; i += 1) {
    expect(app.storage()[`probe.out.${i}`]).not.toBeUndefined();
  }
});

test("probe: RichEditor 视图 headless 挂载 + 探针键 dump", async () => {
  const app = await open("./RichProbeHarness.tsx", {
    width: 390,
    height: 844,
    storage: { "probe.inputs": JSON.stringify(["# 探针\n\n正文\n"]) },
  });
  await app.waitFor("id:rich-editor");
  await app.keyboard.press("mod+shift+e");
  await app.waitUntil(() => app.storage()["probe.live"] !== undefined);
  console.log("live markdown:", app.storage()["probe.live"]);
  // 末尾插入 → onChange 路径外插入，读 session 验证文档变化。
  await app.keyboard.press("mod+shift+l");
  await app.keyboard.press("mod+shift+e");
  await app.waitUntil(() =>
    (app.storage()["probe.live"] ?? "").includes("探针插入"),
  );
  expect(app.storage()["probe.live"]).toContain("探针插入");
});
