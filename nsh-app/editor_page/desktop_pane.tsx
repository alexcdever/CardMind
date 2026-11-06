// 桌面第三栏编辑面板（自 editor_page.tsx 纯结构拆出，函数体逐字保留）。
// `EditorPage` 经入口 `../editor_page` 取（与 `note_list/desktop.tsx` 取
// `../editor_page` 同式；Entry→desktop_pane→Entry 为循环 import，依赖的是
// `Each` 渲染时才解引用的 function 提升绑定，安全）。
import { View, type JSX } from "nsh";
import type { EditorRef, RichEditorSession } from "nsh/base";
import { CardMindEmptyState } from "../components";
import { colors } from "../theme";
import { EditorPage } from "../editor_page";
import type { EditorRepository } from "./types";

/**
 * 桌面第三栏：选中笔记 → 内嵌 `EditorPage`（`embedded`，不套 NavPage/返回键）。
 *
 * 跨笔记状态隔离（06 §2.4）：`<Each>` 以 `noteId` 为 key，0.3.0 的 Each
 * 「rows are kept by key」（`globals.d.ts`）——key 变化即旧行移除、新行创建，
 * `Editor` 的撤销栈随之重建，切笔记后 Ctrl+Z 不会撤回上一篇内容。
 * 未选中时显示空态；新建入口由列表/侧栏的「新建笔记」负责（push 编辑路由）。
 */
export function DesktopEditorPane(props: {
  /** 选中笔记 id 的访问器（`note_list.tsx` 传 `selectedNoteId`，测试传 signal）。 */
  noteId: () => string | undefined;
  /** 测试接缝：不传则用真后端。 */
  repository?: EditorRepository;
  /** 测试接缝：把内嵌源码 Editor 的 ref 交给调用方。 */
  onEditorRef?: (ref: EditorRef) => void;
  /** 测试接缝：把内嵌 WYSIWYG 会话交给调用方（`nsh test` 读全文断言）。 */
  onRichSession?: (session: RichEditorSession) => void;
  /** 预览里按下笔记链接的跳转：桌面三栏应切换选中（由列表侧注入 openNote），
   *  不传则退回 EditorPage 默认的 `openEditor` push 路由。
   *  P4-3a 仅保留接缝（预览面板已移除；P4-3b 接 WYSIWYG 链接按下）。 */
  onNavigateNote?: (noteId: string) => void;
}): JSX.Element {
  return (
    <View style={{ flex: 1, backgroundColor: colors.paper }}>
      {() => {
        const id = props.noteId();
        if (id === undefined) {
          return (
            <CardMindEmptyState
              icon="edit"
              title="选择一篇笔记"
              message="在左侧列表选择笔记，或创建一篇新笔记。"
            />
          );
        }
        return (
          <Each of={[id]} key={(noteId: string) => noteId}>
            {(noteId: () => string) => (
              <EditorPage
                noteId={noteId()}
                embedded
                repository={props.repository}
                onEditorRef={props.onEditorRef}
                onRichSession={props.onRichSession}
                onNavigateNote={props.onNavigateNote}
              />
            )}
          </Each>
        );
      }}
    </View>
  );
}
