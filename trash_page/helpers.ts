// 回收站页文本工具（自 trash_page.tsx 纯结构拆出，声明逐字保留）。
import type { TrashNoteDto } from "./types";

// ─── 文本工具（对照 Dart _displayTitle/_formatDate）─────────────────────────

export function displayTitle(note: TrashNoteDto): string {
  const clean = note.title.replace(/^\s*#+\s*/, "").trim();
  return clean.length > 0 ? clean : "无标题";
}

export function formatDate(iso: string | null | undefined): string {
  if (!iso) return "";
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso);
  if (!m) return iso;
  return `${Number(m[2])}月${Number(m[3])}日`;
}
