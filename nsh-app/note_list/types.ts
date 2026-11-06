// 笔记列表页数据层类型（自 note_list.tsx 纯结构拆出，未改任何形状/语义）。
//
// `NoteDto` 与 nsh-app/src/lib.rs 的 JsObject 镜像一致。page 数据通过
// `NoteListSource` 解耦——测试/500 篇造数用一个内存源，真实 UI 走 BackendNotes。
export interface NoteDto {
  id: string;
  title: string;
  contentPreview: string;
  tags: string;
  updatedAt: string;
  deletedAt?: string | null;
}

/** 读侧 / 写侧后端表面（TSX 侧能注入假实现）。 */
export interface NoteListSource {
  listNotes(): Promise<NoteDto[]>;
  searchNotes(query: string): Promise<NoteDto[]>;
  getAllTags(): Promise<string[]>;
  searchByTag(tag: string): Promise<NoteDto[]>;
  noteSoftDelete(id: string): Promise<boolean>;
}
