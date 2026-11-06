// 编辑页类型（自 editor_page.tsx 纯结构拆出，声明逐字保留）。
import type { EditorRef, RichEditorSession } from "nsh/base";

/** `searchByTag` / `autoCompleteLinks` 的行（只取编辑器需要的字段，兼容 NoteDto）。 */
export interface EditorNoteRow {
  id: string;
  title: string;
  contentPreview?: string;
  tags?: string;
  updatedAt?: string;
  deletedAt?: string | null;
}

/** 编辑页的数据接缝：默认实现走 `app/native`，`nsh test` 用假实现（不碰真实 DB/iroh）。 */
export interface EditorRepository {
  noteGet(id: string): Promise<string | null>;
  noteCreate(id: string, content: string): Promise<boolean>;
  noteUpdateMetadata(id: string, tags: string[]): Promise<boolean>;
  syncNotesToStore(): Promise<boolean>;
  autoCompleteLinks(prefix: string): EditorNoteRow[] | Promise<EditorNoteRow[]>;
  searchByTag(tag: string): EditorNoteRow[] | Promise<EditorNoteRow[]>;
  generateNoteId(): string | Promise<string>;
}

/** `EditorPage` 的 props（原入口内联 props 类型提升为命名类型，字段/注释逐字保留）。 */
export interface EditorPageProps {
  noteId: string;
  /** 桌面第三栏内嵌：不套 NavPage，无返回键；关闭改为通知父级清选中。 */
  embedded?: boolean;
  /** 测试接缝：不传则用真后端（`backendEditorRepository`）。 */
  repository?: EditorRepository;
  /** 测试接缝：源码模式 `Editor` 挂载后把 ref 交给调用方（`nsh test` 读全文
   *  做逐字节断言）；WYSIWYG 模式不发 ref，用 `onRichSession`。 */
  onEditorRef?: (ref: EditorRef) => void;
  /** 测试接缝：WYSIWYG 会话建立后把 `RichEditorSession` 交给调用方（`nsh test`
   *  经 `getMarkdown()`/`insertContent` 读全文/注入编辑做断言）；模式切换时重建
   *  会话会再次回调（拿到新实例）。 */
  onRichSession?: (session: RichEditorSession) => void;
  /** 保留接缝：P4-3b 接 WYSIWYG 里点击 `cardmind://note/<id>` 链接的跳转。
   *  当前零生产读取——预览面板已删、RichEditor `openOnClick:false`，谁都不调用；
   *  桌面三栏内嵌时仍由列表侧注入 `openNote`（切选中），先留着等 P4-3b 接上。 */
  onNavigateNote?: (noteId: string) => void;
}
