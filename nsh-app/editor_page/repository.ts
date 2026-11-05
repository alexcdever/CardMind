// 编辑页数据接缝的默认实现与新笔记判定（自 editor_page.tsx 纯结构拆出，逐字保留）。
import { BackendNotes, BackendStore } from "app/native";
import { NEW_NOTE_IDS } from "../editor_text";
import type { EditorRepository } from "./types";

/** 真后端实现（`nsh-app/src/lib.rs` 导出的 `BackendNotes` / `BackendStore`）。 */
export const backendEditorRepository: EditorRepository = {
  noteGet: (id) => BackendNotes.noteGet(id),
  noteCreate: (id, content) => BackendNotes.noteCreate(id, content),
  noteUpdateMetadata: (id, tags) => BackendNotes.noteUpdateMetadata(id, tags),
  syncNotesToStore: () => BackendNotes.syncNotesToStore(),
  autoCompleteLinks: (prefix) => BackendNotes.autoCompleteLinks(prefix),
  searchByTag: (tag) => BackendNotes.searchByTag(tag),
  generateNoteId: () => BackendStore.generateNoteId(),
};

/** `""`/`"new"` 都表示「新笔记」，无已落盘 id。 */
export function isNewNoteId(noteId: string): boolean {
  return NEW_NOTE_IDS.includes(noteId);
}
