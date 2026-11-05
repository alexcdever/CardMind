// 编辑页类型（自 editor_page.tsx 纯结构拆出，声明逐字保留）。
import type { EditorRef } from "nsh/base";

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
  /** 测试接缝：Editor 挂载后把 ref 交给调用方（`nsh test` 读全文做逐字节断言）。 */
  onEditorRef?: (ref: EditorRef) => void;
  /** 预览里按下 `cardmind://note/<id>` 链接的跳转入口：默认 `openEditor`（push
   *  编辑路由）；桌面三栏内嵌时由列表侧改为切换选中（DesktopEditorPane 注入）。 */
  onNavigateNote?: (noteId: string) => void;
}
