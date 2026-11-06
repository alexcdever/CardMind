// `nsh test` 专用入口：用假 `NoteListSource` + 真实 `NavStack` 挂载 `NoteListPage`。
//
// 不 import `App.tsx`（顶层 IIFE 会碰真实 DB/iroh）。editor 路由渲染一个
// 带 `testID="editor-route"` 的桩页并显示 `route.noteId`——断言「新建笔记
// 按钮把 editor 路由推上栈」只需路由证据，不挂真实 `EditorScreen`。
import { mount, Text, View, type JSX } from "nsh";
import { NavPage, NavStack } from "nsh/base";
import { nav, screenChrome, type Route } from "./navigation";
import { NoteListPage, setNoteListSource, type NoteDto } from "./note_list";

// 假数据源：空列表 + 空标签（本 harness 只验证「新建笔记」入口的路由行为，
// 不验证列表渲染——列表行为由 App 层/后端验收覆盖）。
const emptyNotes: NoteDto[] = [];
setNoteListSource({
  listNotes: async () => emptyNotes,
  searchNotes: async () => [],
  getAllTags: async () => [],
  searchByTag: async () => [],
  noteSoftDelete: async () => true,
});

/** editor 路由桩页：证明路由被推上栈 + 携带的 noteId 原样显示。 */
function EditorRouteStub(props: { noteId: string }): JSX.Element {
  return (
    <NavPage {...screenChrome("编辑")}>
      <View testID="editor-route" style={{ flex: 1, padding: 16 }}>
        <Text>editor noteId: {props.noteId}</Text>
      </View>
    </NavPage>
  );
}

function Harness(): JSX.Element {
  return (
    <View style={{ flex: 1 }}>
      <NavStack state={nav} style={{ flex: 1 }} testID="note-list-harness">
        {(route: Route) =>
          route.name === "editor" ? (
            <EditorRouteStub noteId={route.noteId} />
          ) : route.name === "notes" ? (
            <NavPage {...screenChrome("笔记")}>
              <NoteListPage />
            </NavPage>
          ) : (
            <NavPage {...screenChrome(route.name)}>
              <View testID={`route-${route.name}`} style={{ flex: 1, padding: 16 }}>
                <Text>{route.name} stub</Text>
              </View>
            </NavPage>
          )
        }
      </NavStack>
    </View>
  );
}

mount(Harness);
