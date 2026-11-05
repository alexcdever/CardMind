// 笔记列表页模块级状态与数据/事件处理（自 note_list.tsx 纯结构拆出）。
//
// 所有 `signal`/`computed` 单例只在本模块创建一次；组件/入口一律从这里 import，
// 不得另地重建同名状态。`source`/`searchGeneration`/`searchTimer` 等可变 module
// 状态也仅存于此。函数体逐字保留，未改任何行为。
import { computed, signal, windowSize } from "nsh";
import { BackendNotes } from "app/native";
import { openEditor } from "../navigation";
import { layout } from "../theme";
import { parseTags } from "./helpers";
import type { NoteDto, NoteListSource } from "./types";

// ─── 数据层（可注入替代；默认值走真后端）─────────────────────────────────────

/**
 * 默认源：nsh BackendNotes 的 DTO（0.2.0 起 camelCase，与 NoteDto 同形）直读。
 *
 * `listNotes` 目前没有独立的 `storeListNotes`：读模型侧用「按标签搜索空串」
 * 退化为全量列表（`search_by_tag("")` 的 LIKE 模式 `%` 匹配全部非删除行），
 * 等价于 list_notes() 的语义且避免改 Rust 端。
 */
function makeBackendSource(): NoteListSource {
  const map = (r: NoteDto): NoteDto => r;
  return {
    listNotes: async () =>
      (await BackendNotes.searchByTag("")).map(map),
    searchNotes: async (q) =>
      (await BackendNotes.searchNotes(q)).map(map),
    getAllTags: () => Promise.resolve(BackendNotes.getAllTags()),
    searchByTag: async (t) => (await BackendNotes.searchByTag(t)).map(map),
    noteSoftDelete: async (id) => {
      await BackendNotes.noteSoftDelete(id);
      await BackendNotes.syncNotesToStore();
      return true;
    },
  };
}

/** 当前列表页用的数据源；调用方（App）可换为演示/假数据实现。 */
let source: NoteListSource = makeBackendSource();

/** 替换数据源（500 篇造数/测试用）。 */
export function setNoteListSource(s: NoteListSource): void {
  source = s;
}

// ─── 页面状态 ────────────────────────────────────────────────────────────────

export const notes = signal<NoteDto[]>([]);
export const allTags = signal<string[]>([]);
export const searchResults = signal<NoteDto[]>([]);
export const loading = signal(true);
export const searchText = signal("");
export const searchError = signal<string | undefined>(undefined);
export const selectedTag = signal<string | undefined>(undefined);
/** 桌面三栏选中笔记 id（移动端点击直接 openEditor）。 */
export const selectedNoteId = signal<string | undefined>(undefined);
/** 待删除确认：非空时显示确认对话框（按钮/手势共用的确认入口）。 */
export const deleteTarget = signal<NoteDto | undefined>(undefined);

/** 去抖序列号：递增作废旧搜索（等同 Dart 的 _searchGeneration）。 */
let searchGeneration = 0;
let searchTimer: ReturnType<typeof setTimeout> | undefined;

export const isSearching = computed(() => searchText().trim().length > 0);
export const isDesktop = computed(
  () => windowSize().width >= layout.desktopBreakpoint,
);

/** 搜索结果态（_displayedNotes 的搜索分支）。 */
const filteredByTag = computed(() => {
  const tag = selectedTag();
  if (!tag) return notes();
  const lower = tag.toLowerCase();
  return notes().filter((n) =>
    parseTags(n.tags).some((t) => t.toLowerCase() === lower),
  );
});
export const displayedNotes = computed(() =>
  isSearching() ? searchResults() : filteredByTag(),
);
export const listHeader = computed(() =>
  isSearching() ? "搜索结果" : "全部笔记",
);

// ─── 数据加载 ────────────────────────────────────────────────────────────────

async function loadNotes(): Promise<void> {
  loading.set(true);
  try {
    const [list, tags] = await Promise.all([
      source.listNotes(),
      source.getAllTags(),
    ]);
    notes.set(list);
    allTags.set(tags);
    // 选中态纠偏：当前选中若已不在列表里（被删/被清空），回到第一篇或空。
    const sel = selectedNoteId();
    if (sel !== undefined && !list.some((n) => n.id === sel)) {
      selectedNoteId.set(list.length > 0 ? list[0].id : undefined);
    }
  } finally {
    loading.set(false);
  }
}

/** 首次装载重试：App 层 createNoteStore 与页面装载并发，store 未开时稍候重试；
 *  三次仍失败才落空态（loadNotes 的 catch 在重试层）。 */
export async function loadNotesWithRetry(attempts = 3, delayMs = 250): Promise<void> {
  let lastError: unknown;
  for (let i = 0; i < attempts; i += 1) {
    try {
      await loadNotes();
      return;
    } catch (error) {
      lastError = error;
      if (i + 1 < attempts) {
        await new Promise((resolve) => setTimeout(resolve, delayMs));
      }
    }
  }
  notes.set([]);
  allTags.set([]);
  void lastError;
}

export function onSearchChanged(query: string): void {
  searchText.set(query);
  const normalized = query.trim();
  searchGeneration += 1;
  if (searchTimer !== undefined) {
    clearTimeout(searchTimer);
    searchTimer = undefined;
  }
  if (normalized.length === 0) {
    searchResults.set([]);
    searchError.set(undefined);
    return;
  }
  const generation = searchGeneration;
  searchTimer = setTimeout(() => {
    void performSearch(normalized, generation);
  }, 300);
}

async function performSearch(query: string, generation: number): Promise<void> {
  try {
    const hits = await source.searchNotes(query);
    if (generation !== searchGeneration) return;
    searchResults.set(hits);
    searchError.set(undefined);
  } catch {
    if (generation !== searchGeneration) return;
    searchResults.set([]);
    searchError.set("搜索失败");
  }
}

export function clearSearch(): void {
  onSearchChanged("");
}

export function selectTag(tag: string): void {
  const next = selectedTag() === tag ? undefined : tag;
  selectedTag.set(next);
  if (next !== undefined) {
    // 后端命中集也走一遍 searchByTag（验证通道）；展示仍靠前端
    // `filteredByTag` 二次收窄——与 Dart `_filteredNotes` 语义一致。
    void source.searchByTag(next).catch(() => undefined);
  }
}

/** 软删除入口（按钮/手势共用）：弹危险确认对话框。 */
export function requestDelete(note: NoteDto): void {
  deleteTarget.set(note);
}

export async function confirmDelete(): Promise<void> {
  const target = deleteTarget();
  deleteTarget.set(undefined);
  if (!target) return;
  await source.noteSoftDelete(target.id);
  if (selectedNoteId() === target.id) {
    selectedNoteId.set(undefined);
  }
  await loadNotes().catch(() => undefined);
}

export function cancelDelete(): void {
  deleteTarget.set(undefined);
}

export function openNote(id: string): void {
  if (isDesktop()) {
    selectedNoteId.set(id);
  } else {
    openEditor(id);
  }
}
