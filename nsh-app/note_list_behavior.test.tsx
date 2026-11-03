// 笔记列表行为测试（`nsh test`；harness = NoteListHarness.tsx，假 NoteListSource）。
//
// P4 AC2：<960 宽度（390×844 手机口）移动布局头部「新建笔记」IconButton
// 把 editor 路由推上栈且 noteId === "new"。这是 P3 审查发现的测试盲区：
// 此前该按钮无任何行为测试覆盖。
//
// 变异自检（见 .pipeline/executor.md）：把 `note_list.tsx` 移动头部的
// `CardMindIconButton`（tooltip="新建笔记"）的 `onPress` 去掉/置空后，
// 本测试必须失败（按钮 disabled、路由不推进）；恢复后通过。
import { expect, open, test } from "nsh/test";

test("note: 移动布局点「新建笔记」进入编辑路由（noteId === \"new\"）", async () => {
  const app = await open("./NoteListHarness.tsx", { width: 390, height: 844 });
  // 移动布局头部（<960）：列表先装载完成，新建按钮可见可用。
  await app.waitFor("id:note-list-harness");
  await app.waitFor("label:新建笔记");
  expect(app.enabled("label:新建笔记")).toBe(true);
  await app.press("label:新建笔记");
  // editor 路由被推上栈：桩页出现且携带 noteId "new"。
  await app.waitFor("id:editor-route");
  expect(app.shows("id:editor-route")).toBe(true);
  expect(app.texts().some((t) => t.includes("new"))).toBe(true);
});
