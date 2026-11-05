// 文本工具（Dart _displayTitle/_preview/_formatDate/_parseTags 镜像）与行度量。
// 自 note_list.tsx 纯结构拆出，函数体逐字保留。
import type { NoteDto } from "./types";

export function parseTags(tags: string): string[] {
  return tags
    .split(",")
    .map((t) => t.trim())
    .filter((t) => t.length > 0);
}

export function displayTitle(note: NoteDto): string {
  const clean = note.title
    .replace(/^\s*#+\s*/, "")
    .trim();
  return clean.length > 0 ? clean : "无标题";
}

export function previewLine(note: NoteDto): string {
  const lines = note.contentPreview.split("\n").map((l) => l.trim());
  const first = lines.find((l) => l.length > 0) ?? "";
  return first.slice(0, 80);
}

export function formatDate(iso: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso);
  if (!m) return iso;
  return `${Number(m[2])}月${Number(m[3])}日`;
}

/** 列表行高估值（virtual_list estimatedItemSize；桌面 96 / 移动 112 取中）。 */
export const estimatedRowHeight = 104;
/** 滑动删除的位移上限（px）：拖到这么左就执行删除。 */
export const swipeTrigger = 80;
