// P4-3a 探针 3：RichEditor 在 headless 是否真活着（事件/占位/文本暴露/键探针）。
import { expect, open, test } from "nsh/test";

test("probe3: RichEditor 存活面（events/texts/selectors）", async () => {
  const app = await open("./RichProbe3Harness.tsx", {
    width: 390,
    height: 844,
    storage: {},
  });
  await app.waitUntil(() => app.storage()["probe3.session"] === "made");
  await app.wait(800);
  console.log(`texts=${JSON.stringify(app.texts())}`);
  console.log(
    `shows id:rich-editor=${app.shows("id:rich-editor")} ` +
      `label:富文本编辑器=${app.shows("label:富文本编辑器")} ` +
      `text:写下第一行=${app.shows("text:写下第一行…")} ` +
      `text:探针标题=${app.shows("text:探针标题")} ` +
      `text:第一段=${app.shows("text:第一段 含 粗体 文本")}`,
  );
  console.log(`onFocus=${app.storage()["probe3.onFocus"]}`);
  // 尝试经 label 选择器 type（headless 惯例：label 命中输入框）。
  let typed = false;
  try {
    await app.type("label:富文本编辑器", "ABC");
    typed = true;
  } catch (error) {
    console.log(`app.type(label) failed: ${String(error)}`);
  }
  // 探针键：f7 = setTextSelection(nodeSize-1)+insertContent；f8 = insertContent(pos)
  await app.keyboard.press("f7");
  await app.wait(300);
  await app.keyboard.press("f8");
  await app.wait(300);
  await app.keyboard.press("f6");
  await app.wait(300);
  console.log(
    `typed=${typed} updates=${app.storage()["probe3.updates"]} ` +
      `onChange=${app.storage()["probe3.onChange"]} ` +
      `nodeSize=${app.storage()["probe3.nodeSize"]} ` +
      `f7=${app.storage()["probe3.f7"]} f8=${app.storage()["probe3.f8"]} ` +
      `live=${JSON.stringify(app.storage()["probe3.live"])}`,
  );
  const live = app.storage()["probe3.live"] ?? "";
  expect(live).toContain("探针标题");
  // 末尾插入两种策略至少一种落尾。
  expect(live.includes("末尾-探针") || live.includes("末尾2-探针")).toBe(true);
});
