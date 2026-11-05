// 回收站页类型（自 trash_page.tsx 纯结构拆出，声明逐字保留）。

/** 回收站行（与 nsh-app/src/lib.rs 的 NoteDto 镜像一致）。 */
export interface TrashNoteDto {
  id: string;
  title: string;
  contentPreview: string;
  tags: string;
  updatedAt: string;
  deletedAt?: string | null;
}

/** 回收站后端表面（TSX 侧能注入假实现）。 */
export interface TrashSource {
  trashList(): Promise<TrashNoteDto[]>;
  noteRestore(id: string): Promise<boolean>;
  notePurge(id: string): Promise<boolean>;
  purgeExpiredTrash(cutoff: string): Promise<number>;
}
