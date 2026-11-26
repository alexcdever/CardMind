// 回收站页状态与处理函数（自 trash_page.tsx 纯结构拆出）：makeBackendSource/
// source/setTrashSource、全部 module-level signals（单一创建点）、数据加载与
// 恢复/彻底删除/定期清理处理函数。声明顺序与函数体逐字保留，仅给对外使用的
// 顶层声明加 export 前缀。
import { signal } from "nsh";
import { BackendNotes } from "app/native";
import { displayTitle } from "./helpers";
import type { TrashNoteDto, TrashSource } from "./types";

// ─── 数据层（可注入替代；默认值走真后端）─────────────────────────────────────

/** 默认源：BackendNotes 的 DTO（0.2.0 起 camelCase）直读；写操作后刷新投影。 */
function makeBackendSource(): TrashSource {
  const map = (r: TrashNoteDto): TrashNoteDto => r;
  return {
    trashList: async () => (await BackendNotes.storeTrashList()).map(map),
    noteRestore: async (id) => {
      await BackendNotes.noteRestore(id);
      await BackendNotes.syncNotesToStore();
      return true;
    },
    notePurge: async (id) => {
      await BackendNotes.notePurge(id);
      await BackendNotes.syncNotesToStore();
      return true;
    },
    purgeExpiredTrash: async (cutoff) => {
      const n = await BackendNotes.purgeExpiredTrash(cutoff);
      await BackendNotes.syncNotesToStore();
      return n;
    },
  };
}

let source: TrashSource = makeBackendSource();

/** 替换数据源（测试/演示用）。 */
export function setTrashSource(s: TrashSource): void {
  source = s;
}

// ─── 页面状态 ────────────────────────────────────────────────────────────────

export const items = signal<TrashNoteDto[]>([]);
export const loading = signal(true);
export const loadError = signal<string | undefined>(undefined);
/** 彻底删除确认目标。 */
export const purgeTarget = signal<TrashNoteDto | undefined>(undefined);
/** 定期清理确认框开关。 */
export const purgeExpiredConfirm = signal(false);
/** 操作反馈行（恢复/删除/清理的结果）。 */
export const actionMessage = signal<string | undefined>(undefined);
export const busy = signal(false);

// ─── 数据加载 ────────────────────────────────────────────────────────────────

async function loadTrash(): Promise<void> {
  loading.set(true);
  try {
    const list = await source.trashList();
    items.set(list);
    loadError.set(undefined);
  } catch (error) {
    loadError.set(`加载回收站失败：${String(error)}`);
  } finally {
    loading.set(false);
  }
}

/** 首次装载重试：store 可能与 App 层 createNoteStore 并发未开，重试三次。 */
export async function loadTrashWithRetry(attempts = 3, delayMs = 250): Promise<void> {
  let lastError: unknown;
  for (let i = 0; i < attempts; i += 1) {
    try {
      await loadTrash();
      return;
    } catch (error) {
      lastError = error;
      if (i + 1 < attempts) {
        await new Promise((resolve) => setTimeout(resolve, delayMs));
      }
    }
  }
  items.set([]);
  void lastError;
}

// ─── 操作 ────────────────────────────────────────────────────────────────────

export async function restore(note: TrashNoteDto): Promise<void> {
  if (busy()) return;
  busy.set(true);
  try {
    await source.noteRestore(note.id);
    actionMessage.set(`已恢复「${displayTitle(note)}」`);
    await loadTrash().catch(() => undefined);
  } catch (error) {
    actionMessage.set(`恢复失败：${String(error)}`);
  } finally {
    busy.set(false);
  }
}

/** 彻底删除入口：弹危险确认对话框（不直删）。 */
export function requestPurge(note: TrashNoteDto): void {
  purgeTarget.set(note);
}

export async function confirmPurge(): Promise<void> {
  const target = purgeTarget();
  purgeTarget.set(undefined);
  if (!target || busy()) return;
  busy.set(true);
  try {
    await source.notePurge(target.id);
    actionMessage.set(`「${displayTitle(target)}」已彻底删除`);
    await loadTrash().catch(() => undefined);
  } catch (error) {
    actionMessage.set(`删除失败：${String(error)}`);
  } finally {
    busy.set(false);
  }
}

export function cancelPurge(): void {
  purgeTarget.set(undefined);
}

/** 定期清理入口：弹危险确认对话框。 */
export function requestPurgeExpired(): void {
  purgeExpiredConfirm.set(true);
}

/** 30 天前的 RFC3339 cutoff（对照 Dart `now.subtract(Duration(days: 30))`
 *  `.toIso8601String()`）。 */
function expiredCutoff(): string {
  const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  return cutoff.toISOString();
}

export async function confirmPurgeExpired(): Promise<void> {
  purgeExpiredConfirm.set(false);
  if (busy()) return;
  busy.set(true);
  try {
    const n = await source.purgeExpiredTrash(expiredCutoff());
    actionMessage.set(
      n > 0 ? `已清理 ${n} 条过期笔记` : "没有需要清理的过期笔记",
    );
    await loadTrash().catch(() => undefined);
  } catch (error) {
    actionMessage.set(`清理失败：${String(error)}`);
  } finally {
    busy.set(false);
  }
}

export function cancelPurgeExpired(): void {
  purgeExpiredConfirm.set(false);
}
