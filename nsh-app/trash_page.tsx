// CardMind 回收站页（施工方案 2.3）：对照 lib/pages/trash_page.dart。
//
// 功能：列已删笔记（BackendNotes.storeTrashList，含标题 + 删除时间）、
// 恢复（noteRestore）、彻底删除（notePurge，走 CardMindConfirmDialog 危险
// 确认）、定期清理（purgeExpiredTrash，cutoff = now-30d RFC3339，同样走
// 危险确认）、空态（CardMindEmptyState）。
//
// 列表主体用 <List>（virtual_list）——与列表页同一回收复用，回收站也可能
// 积累数百条墓碑。每条行尾挂「恢复」「彻底删除」两个 48×48 图标按钮。
//
// 令牌纪律：所有颜色 / 间距 / 圆角 / 触摸目标全部来自 ./theme，禁止裸值。
import { effect, signal, Text, View } from "nsh";
import { List } from "nsh/list";
import type { JSX } from "nsh";
import { BackendNotes } from "app/native";
import {
  CardMindConfirmDialog,
  CardMindEmptyState,
  CardMindIconButton,
  CardMindListItem,
  Glyph,
  panel,
} from "./components";
import { colors, layout, radii, spacing, typography } from "./theme";

// ─── 数据层（可注入替代；默认值走真后端）─────────────────────────────────────

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

const items = signal<TrashNoteDto[]>([]);
const loading = signal(true);
const loadError = signal<string | undefined>(undefined);
/** 彻底删除确认目标。 */
const purgeTarget = signal<TrashNoteDto | undefined>(undefined);
/** 定期清理确认框开关。 */
const purgeExpiredConfirm = signal(false);
/** 操作反馈行（恢复/删除/清理的结果）。 */
const actionMessage = signal<string | undefined>(undefined);
const busy = signal(false);

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
async function loadTrashWithRetry(attempts = 3, delayMs = 250): Promise<void> {
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

async function restore(note: TrashNoteDto): Promise<void> {
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
function requestPurge(note: TrashNoteDto): void {
  purgeTarget.set(note);
}

async function confirmPurge(): Promise<void> {
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

function cancelPurge(): void {
  purgeTarget.set(undefined);
}

/** 定期清理入口：弹危险确认对话框。 */
function requestPurgeExpired(): void {
  purgeExpiredConfirm.set(true);
}

/** 30 天前的 RFC3339 cutoff（对照 Dart `now.subtract(Duration(days: 30))`
 *  `.toIso8601String()`）。 */
function expiredCutoff(): string {
  const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  return cutoff.toISOString();
}

async function confirmPurgeExpired(): Promise<void> {
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

function cancelPurgeExpired(): void {
  purgeExpiredConfirm.set(false);
}

// ─── 文本工具（对照 Dart _displayTitle/_formatDate）─────────────────────────

function displayTitle(note: TrashNoteDto): string {
  const clean = note.title.replace(/^\s*#+\s*/, "").trim();
  return clean.length > 0 ? clean : "无标题";
}

function formatDate(iso: string | null | undefined): string {
  if (!iso) return "";
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso);
  if (!m) return iso;
  return `${Number(m[2])}月${Number(m[3])}日`;
}

// ─── 列表行 ──────────────────────────────────────────────────────────────────

/** 列表行高估值（virtual_list estimatedItemSize；48 触摸目标 + 副标题行）。 */
const estimatedRowHeight = 72;

function TrashRow(props: { note: () => TrashNoteDto }): JSX.Element {
  const note = props.note;
  return (
    <CardMindListItem
      title={displayTitle(note())}
      subtitle={`删除于 ${formatDate(note().deletedAt ?? note().updatedAt)}`}
      trailing={
        <View
          style={{
            flexDirection: "row",
            alignItems: "center",
            gap: spacing.xs,
          }}
        >
          <CardMindIconButton
            icon="restore"
            tooltip={`恢复「${displayTitle(note())}」`}
            onPress={() => void restore(note())}
          />
          <CardMindIconButton
            icon="delete"
            tooltip={`彻底删除「${displayTitle(note())}」`}
            onPress={() => requestPurge(note())}
          />
        </View>
      }
    />
  );
}

// ─── 页面根 ─────────────────────────────────────────────────────────────────

/**
 * 回收站页：标题行（计数 + 「清理 30 天前」按钮）+ 列表/空态。
 *
 * `status` 插槽：调用方传入的状态面板（App.tsx 的 Phase 1 后端证据行），
 * 渲染在页面底部。
 */
export function TrashPage(props: { status?: JSX.Element }): JSX.Element {
  effect(() => {
    void loadTrashWithRetry();
  });
  return (
    <View style={{ flex: 1, backgroundColor: colors.paper }}>
      {/* 顶部说明 + 定期清理入口 */}
      <View
        style={{
          flexDirection: "row",
          alignItems: "center",
          minHeight: layout.mobileTouchTarget,
          paddingHorizontal: spacing.lg,
          paddingVertical: spacing.sm,
          borderBottomWidth: 1,
          borderBottomColor: colors.border,
          gap: spacing.sm,
        }}
      >
        <Glyph name="trash" size={20} tint={colors.mutedInk} />
        <View style={{ flex: 1 }}>
          <Text
            style={{
              fontSize: typography.bodyMedium.fontSize,
              color: colors.mutedInk,
            }}
          >
            {() =>
              loading()
                ? "加载中…"
                : `${items().length} 条已删笔记 · 保留 30 天`
            }
          </Text>
        </View>
        <View
          onPress={requestPurgeExpired}
          role="button"
          accessibilityLabel="清理 30 天前的笔记"
          accessibilityState={{ disabled: busy() }}
          style={{
            minHeight: layout.mobileTouchTarget,
            paddingHorizontal: spacing.md,
            alignItems: "center",
            justifyContent: "center",
            borderRadius: radii.md,
            borderWidth: 1,
            borderColor: colors.border,
            opacity: busy() ? 0.4 : 1,
          }}
        >
          <Text
            style={{
              color: colors.danger,
              fontSize: typography.bodyMedium.fontSize - 3,
              fontWeight: "600",
            }}
          >
            清理过期
          </Text>
        </View>
      </View>

      {/* 列表主体 */}
      <View style={{ flex: 1 }}>
        {() => {
          if (loading()) {
            return (
              <View
                style={{
                  flex: 1,
                  alignItems: "center",
                  justifyContent: "center",
                }}
              >
                <Text style={{ color: colors.mutedInk }}>加载中…</Text>
              </View>
            );
          }
          if (loadError() !== undefined) {
            return (
              <CardMindEmptyState
                icon="trash"
                title="加载失败"
                message={loadError() ?? ""}
              />
            );
          }
          if (items().length === 0) {
            return (
              <CardMindEmptyState
                icon="trash"
                title="回收站是空的"
                message="删除的笔记会在这里保留 30 天，之后自动清理。"
              />
            );
          }
          return (
            <List
              each={items()}
              keyExtractor={(n) => n.id}
              estimatedItemSize={estimatedRowHeight}
              style={{ flex: 1 }}
            >
              {(note, _index) => <TrashRow note={note} />}
            </List>
          );
        }}
      </View>

      {/* 操作反馈行 */}
      <View
        style={{
          paddingHorizontal: spacing.lg,
          paddingVertical: spacing.sm,
          borderTopWidth: 1,
          borderTopColor: colors.border,
          backgroundColor: panel.sidebar,
        }}
      >
        <Text
          style={{
            color: colors.mutedInk,
            fontSize: typography.bodyMedium.fontSize - 3,
          }}
        >
          {() => actionMessage() ?? "恢复/删除后列表自动刷新"}
        </Text>
      </View>

      <If when={props.status !== undefined}>{props.status}</If>

      {/* 彻底删除确认（危险态） */}
      <CardMindConfirmDialog
        visible={purgeTarget() !== undefined}
        title="彻底删除？"
        message={`「${purgeTarget() ? displayTitle(purgeTarget()!) : "无标题"}」将被永久删除，无法恢复。`}
        confirmLabel="彻底删除"
        onConfirm={confirmPurge}
        onCancel={cancelPurge}
        danger
      />
      {/* 定期清理确认（危险态） */}
      <CardMindConfirmDialog
        visible={purgeExpiredConfirm()}
        title="清理过期笔记？"
        message="删除超过 30 天的笔记将被永久移除，无法恢复。"
        confirmLabel="清理"
        onConfirm={confirmPurgeExpired}
        onCancel={cancelPurgeExpired}
        danger
      />
    </View>
  );
}