// CardMind 笔记列表页（施工方案 2.2 + 2.7）：对照 lib/pages/note_list_page.dart。
//
// 布局：宽度 ≥ layout.desktopBreakpoint(960) → 桌面三栏（侧栏 240 | 列表 360 |
// 编辑器）；<960 → 移动布局（搜索 + 标签 + 列表，底部双 Tab「笔记/设备」）。
//
// 交互：CardMindSearchField 搜索（BackendNotes.searchNotes，300ms 去抖）+
// CardMindTag 标签行（BackendNotes.getAllTags / searchByTag）+ 行内删除按钮
// 软删除（BackendNotes.noteSoftDelete）+ 滑动手势删除（PanResponder 翻译，纯
// 视觉手势层）+ CardMindEmptyState 空态。
//
// 滑动删除的无障碍替代：每个列表项本身挂一个 48×48 删除按钮（不论桌面/移动、
// 不论是否支持滑动手势都在）——滑动手势只是触觉增强，删除的真实入口是按钮。
//
// 虚拟化：列表主体是 <List>（"nsh" 导出的 virtual_list）：只渲染视口附近的
// 行，单元格被回收。行 key 用稳定 note.id（keyExtractor）。
//
// 令牌纪律：所有颜色 / 间距 / 圆角 / 触摸目标全部来自 ./theme，禁止裸值。
import {
  AnimatedValue,
  cleanup,
  computed,
  effect,
  keymap,
  List,
  PanResponder,
  Scroll,
  signal,
  Text,
  View,
  windowSize,
} from "nsh";
import type { JSX } from "nsh";
import { BackendNotes } from "app/native";
import {
  CardMindConfirmDialog,
  CardMindEmptyState,
  CardMindIconButton,
  CardMindListItem,
  CardMindPrimaryButton,
  CardMindSearchField,
  CardMindSyncStatus,
  CardMindTag,
  Glyph,
} from "./components";
import { goBack, nav, openEditor, routes } from "./navigation";
import { colors, layout, spacing, typography } from "./theme";

// ─── 数据层（可注入替代；默认值走真后端）─────────────────────────────────────
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

const notes = signal<NoteDto[]>([]);
const allTags = signal<string[]>([]);
const searchResults = signal<NoteDto[]>([]);
const loading = signal(true);
const searchText = signal("");
const searchError = signal<string | undefined>(undefined);
const selectedTag = signal<string | undefined>(undefined);
/** 桌面三栏选中笔记 id（移动端点击直接 openEditor）。 */
const selectedNoteId = signal<string | undefined>(undefined);
/** 待删除确认：非空时显示确认对话框（按钮/手势共用的确认入口）。 */
const deleteTarget = signal<NoteDto | undefined>(undefined);

/** 去抖序列号：递增作废旧搜索（等同 Dart 的 _searchGeneration）。 */
let searchGeneration = 0;
let searchTimer: ReturnType<typeof setTimeout> | undefined;

const isSearching = computed(() => searchText().trim().length > 0);
const isDesktop = computed(
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
const displayedNotes = computed(() =>
  isSearching() ? searchResults() : filteredByTag(),
);
const listHeader = computed(() =>
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
async function loadNotesWithRetry(attempts = 3, delayMs = 250): Promise<void> {
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

function onSearchChanged(query: string): void {
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

function clearSearch(): void {
  onSearchChanged("");
}

function selectTag(tag: string): void {
  const next = selectedTag() === tag ? undefined : tag;
  selectedTag.set(next);
  if (next !== undefined) {
    // 后端命中集也走一遍 searchByTag（验证通道）；展示仍靠前端
    // `filteredByTag` 二次收窄——与 Dart `_filteredNotes` 语义一致。
    void source.searchByTag(next).catch(() => undefined);
  }
}

/** 软删除入口（按钮/手势共用）：弹危险确认对话框。 */
function requestDelete(note: NoteDto): void {
  deleteTarget.set(note);
}

async function confirmDelete(): Promise<void> {
  const target = deleteTarget();
  deleteTarget.set(undefined);
  if (!target) return;
  await source.noteSoftDelete(target.id);
  if (selectedNoteId() === target.id) {
    selectedNoteId.set(undefined);
  }
  await loadNotes().catch(() => undefined);
}

function cancelDelete(): void {
  deleteTarget.set(undefined);
}

function openNote(id: string): void {
  if (isDesktop()) {
    selectedNoteId.set(id);
  } else {
    openEditor(id);
  }
}

// ─── 文本工具（Dart _displayTitle/_preview/_formatDate/_parseTags 镜像）──────

function parseTags(tags: string): string[] {
  return tags
    .split(",")
    .map((t) => t.trim())
    .filter((t) => t.length > 0);
}

function displayTitle(note: NoteDto): string {
  const clean = note.title
    .replace(/^\s*#+\s*/, "")
    .trim();
  return clean.length > 0 ? clean : "无标题";
}

function previewLine(note: NoteDto): string {
  const lines = note.contentPreview.split("\n").map((l) => l.trim());
  const first = lines.find((l) => l.length > 0) ?? "";
  return first.slice(0, 80);
}

function formatDate(iso: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso);
  if (!m) return iso;
  return `${Number(m[2])}月${Number(m[3])}日`;
}

// ─── 列表行（单个 Cell 的 JSX）──────────────────────────────────────────────

/** 列表行高估值（virtual_list estimatedItemSize；桌面 96 / 移动 112 取中）。 */
const estimatedRowHeight = 104;
/** 滑动删除的位移上限（px）：拖到这么左就执行删除。 */
const swipeTrigger = 80;

function NoteRow(props: {
  note: () => NoteDto;
  index: () => number;
  desktop: boolean;
}): JSX.Element {
  const note = props.note;
  const selected = () => props.desktop && selectedNoteId() === note().id;

  // ── 滑动删除的纯视觉手势层 ──
  // AnimatedValue 驱动 translateX（UI 线程）；release 过阈值 → requestDelete，
  // 无论删除与否都 spring 归零。真实删除的是 requestDelete 里弹的确认对话框。
  const dragX = new AnimatedValue(0);
  const responder = PanResponder.create({
    onMoveShouldSetPanResponder: (_, g) =>
      Math.abs(g.dx) > Math.abs(g.dy) && g.dx < -spacing.xs,
    onPanResponderMove: (_, g) => dragX.set(Math.min(0, g.dx)),
    onPanResponderRelease: (_, g) => {
      if (g.dx < -swipeTrigger) {
        requestDelete(note());
      }
      dragX.spring(0, { velocity: g.vx, stiffness: 180, damping: 22 });
    },
    onPanResponderTerminate: () =>
      dragX.spring(0, { stiffness: 180, damping: 22 }),
  });

  return (
    <View
      {...responder.panHandlers}
      testID={`note-${note().id}`}
      accessibilityLabel={`笔记：${displayTitle(note())}`}
      role="button"
      accessibilityState={{ selected: selected() }}
      style={{
        transform: [{ translateX: dragX }],
        backgroundColor: colors.surfaceRaised,
      }}
    >
      <CardMindListItem
        title={displayTitle(note())}
        subtitle={previewLine(note())}
        selected={selected()}
        onPress={() => openNote(note().id)}
        trailing={
          <View
            style={{
              flexDirection: "row",
              alignItems: "center",
              gap: spacing.sm,
            }}
          >
            <Text
              style={{
                color: colors.mutedInk,
                fontSize: typography.bodyMedium.fontSize - 3,
                fontWeight: "600",
              }}
            >
              {formatDate(note().updatedAt)}
            </Text>
            {/* 无障碍删除替代：每个列表项的可见删除按钮（48×48）。 */}
            <CardMindIconButton
              icon="delete"
              tooltip={`删除「${displayTitle(note())}」`}
              onPress={() => requestDelete(note())}
            />
          </View>
        }
      />
    </View>
  );
}

// ─── 标签过滤条 ─────────────────────────────────────────────────────────────

function TagFilterBar(props: { comfortable?: boolean }): JSX.Element {
  return (
    <Scroll
      horizontal
      scrollbar={false}
      style={{
        flexDirection: "row",
        paddingBottom: spacing.md,
      }}
      contentStyle={{
        flexDirection: "row",
        gap: spacing.sm,
      }}
    >
      {() =>
        allTags().map((tag) => (
          <CardMindTag
            label={tag}
            selected={selectedTag() === tag}
            comfortable={props.comfortable === true}
            onTap={() => selectTag(tag)}
          />
        ))
      }
    </Scroll>
  );
}

// ─── 列表主体（虚拟化 + 空态分支）───────────────────────────────────────────

function ListBody(props: { desktop: boolean }): JSX.Element {
  // 整体放进响应式 thunk：loading/notes/displayedNotes 变化时整段重估。
  return (
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
        if (notes().length === 0 && !isSearching()) {
          return (
            <CardMindEmptyState
              icon="notes"
              title="还没有笔记"
              message="创建第一篇笔记，内容会保存在这台设备上。"
            />
          );
        }
        if (searchError() !== undefined) {
          return (
            <CardMindEmptyState
              icon="search"
              title="搜索失败"
              message={searchError() ?? ""}
            />
          );
        }
        if (displayedNotes().length === 0) {
          return (
            <CardMindEmptyState
              icon="search"
              title="没有匹配结果"
              message={
                isSearching() ? "试试更短的关键词。" : "当前标签下没有笔记。"
              }
            />
          );
        }
        // 虚拟列表（施工 2.7）：`nsh` 导出的 virtual_list 只创建视口附近的行。
        return (
          <List
            each={displayedNotes()}
            keyExtractor={(n) => n.id}
            estimatedItemSize={estimatedRowHeight}
            style={{ flex: 1 }}
          >
            {(note, index) => (
              <NoteRow note={note} index={index} desktop={props.desktop} />
            )}
          </List>
        );
      }}
    </View>
  );
}

// ─── 桌面布局（三栏）─────────────────────────────────────────────────────────

function DesktopSidebar(): JSX.Element {
  return (
    <View
      style={{
        width: layout.sidebarWidth,
        backgroundColor: colors.surfaceLow,
        borderRightWidth: 1,
        borderRightColor: colors.border,
        padding: spacing.lg,
        gap: spacing.md,
      }}
    >
      <Text
        style={{
          fontSize: typography.titleMedium.fontSize,
          lineHeight: typography.titleMedium.lineHeight,
          fontWeight: "600",
          color: colors.ink,
        }}
      >
        CardMind
      </Text>
      <CardMindPrimaryButton
        label="新建笔记"
        icon="add"
        onPress={() => openEditor("new")}
        expanded
      />
      <View
        style={{
          flexDirection: "row",
          alignItems: "center",
          height: spacing.xl + spacing.md,
          paddingLeft: spacing.md,
          borderLeftWidth: 2,
          borderLeftColor: colors.accent,
          backgroundColor: colors.surfaceLow,
        }}
      >
        <Glyph name="notes" size={20} tint={colors.accent} />
        <View style={{ width: spacing.md }} />
        <Text
          style={{
            flex: 1,
            color: colors.accent,
            fontWeight: "600",
            fontSize: typography.bodyMedium.fontSize,
          }}
        >
          笔记
        </Text>
        <Text style={{ color: colors.mutedInk, fontSize: typography.bodyMedium.fontSize - 3 }}>
          {notes().length}
        </Text>
      </View>
      <View style={{ flex: 1 }} />
      <CardMindListItem title="回收站" onPress={() => nav.push(routes.trash)} />
      <CardMindListItem title="设备" onPress={() => nav.push(routes.devices)} />
      <CardMindListItem title="设置" onPress={() => nav.push(routes.settings)} />
      <CardMindSyncStatus label="本地已就绪" pendingCount={0} />
    </View>
  );
}

function DesktopListPane(): JSX.Element {
  return (
    <View
      style={{
        width: layout.listWidth,
        backgroundColor: colors.paper,
        borderRightWidth: 1,
        borderRightColor: colors.border,
      }}
    >
      <View style={{ padding: spacing.lg }}>
        <View style={{ flexDirection: "row", alignItems: "center" }}>
          <Text
            style={{
              flex: 1,
              fontSize: typography.titleMedium.fontSize,
              lineHeight: typography.titleMedium.lineHeight,
              fontWeight: "600",
              color: colors.ink,
            }}
          >
            {listHeader()}
          </Text>
          <Text
            style={{
              color: colors.mutedInk,
              fontSize: typography.bodyMedium.fontSize - 3,
            }}
          >
            {displayedNotes().length}
          </Text>
        </View>
        <View style={{ height: spacing.lg }} />
        <CardMindSearchField
          value={searchText}
          onChanged={onSearchChanged}
          onClear={clearSearch}
        />
        <If when={!isSearching() && allTags().length > 0}>
          <View style={{ height: spacing.md }} />
          <TagFilterBar />
        </If>
      </View>
      <View style={{ height: 1, backgroundColor: colors.border }} />
      <ListBody desktop />
    </View>
  );
}

function DesktopEditorPane(props: { status?: JSX.Element }): JSX.Element {
  return (
    <View
      style={{
        flex: 1,
        backgroundColor: colors.paper,
        padding: spacing.lg,
        gap: spacing.sm,
      }}
    >
      {() => {
        const id = selectedNoteId();
        return id === undefined ? (
          <CardMindEmptyState
            icon="edit"
            title="选择一篇笔记"
            message="在左侧列表选择笔记，或创建一篇新笔记。"
          />
        ) : (
          <Text
            style={{
              color: colors.mutedInk,
              fontSize: typography.bodyMedium.fontSize,
            }}
          >
            编辑器占位（2.x 实现）—— noteId：{id}
          </Text>
        );
      }}
      <If when={props.status !== undefined}>{props.status}</If>
    </View>
  );
}

function DesktopLayout(props: { status?: JSX.Element }): JSX.Element {
  return (
    <View
      style={{
        flex: 1,
        flexDirection: "row",
        backgroundColor: colors.paper,
      }}
    >
      <DesktopSidebar />
      <DesktopListPane />
      <DesktopEditorPane status={props.status} />
    </View>
  );
}

// ─── 移动布局（堆叠 + 双 Tab）─────────────────────────────────────────────────

function MobileNotesTab(): JSX.Element {
  return (
    <View style={{ flex: 1, backgroundColor: colors.paper }}>
      <View style={{ padding: spacing.lg, paddingBottom: spacing.md }}>
        <CardMindSearchField
          value={searchText}
          onChanged={onSearchChanged}
          onClear={clearSearch}
          mobile
        />
        <If when={!isSearching() && allTags().length > 0}>
          <View style={{ height: spacing.md }} />
          <TagFilterBar comfortable />
        </If>
      </View>
      <ListBody desktop={false} />
    </View>
  );
}

function MobileDevicesTab(props: { status?: JSX.Element }): JSX.Element {
  return (
    <View
      style={{
        flex: 1,
        backgroundColor: colors.paper,
        padding: spacing.lg,
        gap: spacing.sm,
      }}
    >
      <Text style={{ color: colors.mutedInk }}>设备页在「设备」页（2.5 实现）。</Text>
      <CardMindPrimaryButton
        label="打开设备页"
        icon="devices"
        onPress={() => nav.push(routes.devices)}
      />
      <If when={props.status !== undefined}>{props.status}</If>
    </View>
  );
}

function MobileLayout(props: { status?: JSX.Element }): JSX.Element {
  const tab = signal<"notes" | "devices">("notes");
  return (
    <View style={{ flex: 1, backgroundColor: colors.paper }}>
      <View
        style={{
          flexDirection: "row",
          alignItems: "center",
          minHeight: layout.mobileTouchTarget,
          paddingHorizontal: spacing.lg,
          borderBottomWidth: 1,
          borderBottomColor: colors.border,
          gap: spacing.sm,
        }}
      >
        <Text
          style={{
            flex: 1,
            fontSize: typography.titleMedium.fontSize,
            lineHeight: typography.titleMedium.lineHeight,
            fontWeight: "600",
            color: colors.ink,
          }}
        >
          {tab() === "notes" ? "CardMind" : "设备"}
        </Text>
        <CardMindIconButton
          icon="settings"
          tooltip="设置"
          onPress={() => nav.push(routes.settings)}
        />
        <CardMindIconButton
          icon="trash"
          tooltip="回收站"
          onPress={() => nav.push(routes.trash)}
        />
        <CardMindSyncStatus label="已就绪" pendingCount={0} />
      </View>
      <If when={tab() === "notes"} else={<MobileDevicesTab status={props.status} />}>
        <MobileNotesTab />
      </If>
      {/* 双 Tab 底栏（规范：恰好「笔记」「设备」两个入口）。 */}
      <View
        style={{
          flexDirection: "row",
          borderTopWidth: 1,
          borderTopColor: colors.border,
          backgroundColor: colors.surfaceRaised,
        }}
      >
        <View
          onPress={() => tab.set("notes")}
          role="button"
          accessibilityLabel="笔记"
          accessibilityState={{ selected: tab() === "notes" }}
          style={{
            flex: 1,
            minHeight: layout.mobileTouchTarget,
            alignItems: "center",
            justifyContent: "center",
            borderTopWidth: tab() === "notes" ? 2 : 0,
            borderTopColor: colors.accent,
          }}
        >
          <Glyph name="notes" size={20} tint={tab() === "notes" ? colors.accent : colors.mutedInk} />
          <Text
            style={{
              fontSize: typography.bodyMedium.fontSize - 3,
              color: tab() === "notes" ? colors.accent : colors.mutedInk,
              fontWeight: "600",
              marginTop: spacing.xs,
            }}
          >
            笔记
          </Text>
        </View>
        <View
          onPress={() => tab.set("devices")}
          role="button"
          accessibilityLabel="设备"
          accessibilityState={{ selected: tab() === "devices" }}
          style={{
            flex: 1,
            minHeight: layout.mobileTouchTarget,
            alignItems: "center",
            justifyContent: "center",
            borderTopWidth: tab() === "devices" ? 2 : 0,
            borderTopColor: colors.accent,
          }}
        >
          <Glyph name="devices" size={20} tint={tab() === "devices" ? colors.accent : colors.mutedInk} />
          <Text
            style={{
              fontSize: typography.bodyMedium.fontSize - 3,
              color: tab() === "devices" ? colors.accent : colors.mutedInk,
              fontWeight: "600",
              marginTop: spacing.xs,
            }}
          >
            设备
          </Text>
        </View>
      </View>
    </View>
  );
}

// ─── 页面根 ─────────────────────────────────────────────────────────────────

/**
 * 笔记列表页：双布局 + 搜索 + 标签过滤 + 软删除 + 空态 + 虚拟化。
 *
 * 桌面 ≥960：侧栏 | 列表 | 编辑器；移动 <960：搜索 + 标签 + 列表 + 双 Tab。
 *
 * `status` 插槽：调用方传入的状态面板（App.tsx 的 Phase 1 后端证据行 +
 * Bridge 事件监听），桌面渲染在编辑器占位栏、移动渲染在「设备」Tab。
 */
export function NoteListPage(props: { status?: JSX.Element }): JSX.Element {
  // 首次装载：读一次列表 + 标签（Dart _loadNotes + _initSyncStatus 合并）；
  // store 可能与 App 层 createNoteStore 并发未开，重试三次。
  effect(() => {
    void loadNotesWithRetry();
  });
  // 键盘删除入口（桌面）：选中态 + Delete 键 → 弹同一个确认对话框。
  // 移动端无物理键盘，这条绑定自然不触发（`nsh` 的 keymap 在非桌面只保留注册）。
  const unbindDelete = keymap.bind("delete", () => {
    const id = selectedNoteId();
    if (id === undefined) return;
    const target = notes().find((n) => n.id === id);
    if (target) requestDelete(target);
  });
  cleanup(unbindDelete);
  return (
    <View style={{ flex: 1, backgroundColor: colors.paper }}>
      <If when={isDesktop()} else={<MobileLayout status={props.status} />}>
        <DesktopLayout status={props.status} />
      </If>
      <CardMindConfirmDialog
        visible={deleteTarget() !== undefined}
        title="删除笔记"
        message={`「${deleteTarget()?.title ?? "无标题"}」会移入回收站，30 天内可恢复。`}
        confirmLabel="删除"
        onConfirm={confirmDelete}
        onCancel={cancelDelete}
        danger
      />
    </View>
  );
}

/** 兼容命名：App.tsx 三栏骨架里占位的名字。 */
export { NoteListPage as NoteList };
export { goBack };
