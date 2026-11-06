// `nsh test` 专用入口：用假 `EditorRepository` 挂载真实 `EditorScreen`。
//
// 不 import `App.tsx`（那里有顶层 IIFE：dataDir / createNoteStore / iroh，会碰
// 真实数据目录），也不碰真实 DB / 网络。场景经 `open(..., { storage })` 的
// `test.scenario` 注入（JSON），假的仓库把调用记录写回 storage 的 `test.calls`、
// `test.saved`、`test.savedId`、`test.tags`，测试用 `app.storage()` 断言。
import { effect, keymap, mount, signal, Storage, Text, View, type JSX } from "nsh";
import {
  NavPage,
  NavStack,
  setTextSelection,
  type EditorRef,
  type RichEditorSession,
  type RichNodeJSON,
} from "nsh/base";
import {
  DesktopEditorPane,
  EditorScreen,
  type EditorNoteRow,
  type EditorRepository,
} from "./editor_page";
import type { WikiCandidate } from "./editor_text";
import { nav } from "./navigation";

/** 一个测试场景：初始笔记 + 故障注入 + `[[` 候选 + 桌面三栏数据。 */
interface Scenario {
  /** "new"/"" = 新笔记；其余 = 已有笔记 id。桌面场景时为首个选中的 id。 */
  noteId: string;
  /** noteGet 返回的 markdown；null = 笔记不存在。 */
  note: string | null;
  tags?: string[];
  /** true = 每次都抛；"once" = 第一次抛；"hang" = 永不返回（触发加载超时）。 */
  failLoad?: boolean | "once" | "hang";
  /** true = 每次都抛；"once" = 第一次抛。 */
  failSave?: boolean | "once";
  candidates?: WikiCandidate[];
  /** `mod+shift+l` 时追加到文本末尾的内容（测试构造「最后输入」）。 */
  append?: string;
  /** "desktop"：三栏场景（侧栏列表 + DesktopEditorPane），不经 nav.push editor。 */
  mode?: string;
  /** 桌面场景多笔记内容表（noteGet 按 id 查）。 */
  notes?: { id: string; content: string; tags?: string }[];
  /** 桌面场景初始选中的笔记 id。 */
  selectedNoteId?: string;
}

const scenario = signal<Scenario | null>(null);
let repository: EditorRepository | null = null;
/** 源码模式最新挂载的 `Editor` ref（测试用：读全文 / 在末尾插入，做逐字节断言）。 */
let liveEditor: EditorRef | null = null;
/** WYSIWYG 模式当前会话（测试用：`getMarkdown()` 读全文 / `insertContent` 注入）。 */
let liveSession: RichEditorSession | null = null;
/** 当前活编辑器种类：`onEditorRef`→source，`onRichSession`→rich。 */
let liveKind: "source" | "rich" | null = null;
/** 上一个经 `onEditorRef`/`onRichSession` 上报的实例（判别「新建 vs 复用」）。 */
let lastEditorInstance: EditorRef | RichEditorSession | null = null;
/** 编辑器实例挂载次数（新 Editor ref 或新 RichEditorSession 出现即 +1）。 */
let editorMountCount = 0;
/** `f7`/`mod+shift+l` 要注入的文本（场景里的 `append`）。 */
let appendText: string | null = null;

function bumpMountCount(instance: EditorRef | RichEditorSession): void {
  if (instance !== lastEditorInstance) {
    lastEditorInstance = instance;
    editorMountCount += 1;
    // 新实例即 +1：切换笔记重建编辑器时 ref/session 是新建对象；
    // 若实现退化复用同一实例（key 失效/setValue 重载），计数不涨。
    void Storage.setItem("test.editorMountCount", String(editorMountCount));
  }
}

function recordEditorRef(ref: EditorRef): void {
  liveEditor = ref;
  liveKind = "source";
  bumpMountCount(ref);
}

function recordRichSession(session: RichEditorSession): void {
  liveSession = session;
  liveKind = "rich";
  bumpMountCount(session);
}

/** 把当前编辑器的全文写进 storage 的 `test.editorValue`（测试读全文用）：
 *  源码模式 `Editor.value()`；WYSIWYG `session.getMarkdown()`。
 *  同时自增 `test.editorDumpSeq`，让测试能区分「这次读的」与「上一次读的」。 */
async function dumpEditorValue(): Promise<void> {
  let value: string | null = null;
  if (liveKind === "rich" && liveSession !== null) {
    value = liveSession.getMarkdown();
  } else if (liveEditor !== null) {
    value = await liveEditor.value();
  }
  if (value === null) return;
  const seq = Number((await Storage.getItem("test.editorDumpSeq")) ?? "0") + 1;
  await Storage.setItem("test.editorValue", value);
  await Storage.setItem("test.editorDumpSeq", String(seq));
}

/** 注入 `text`（等价用户输入）：源码模式在文本末尾 `Editor.edit`；
 *  WYSIWYG 在当前选区 `session.insertContent`（RichEditor 的选区是文档位，
 *  测试断言用 `includes` 而非「末尾逐字节」）。 */
async function appendAtEnd(text: string): Promise<void> {
  if (liveKind === "rich" && liveSession !== null) {
    liveSession.insertContent(text, "markdown");
  } else if (liveEditor !== null) {
    const value = await liveEditor.value();
    const end = await liveEditor.offsetToPosition(value.length);
    liveEditor.edit([{ range: { start: end, end }, text }]);
  }
  await dumpEditorValue();
}

/** ProseMirror 节点尺寸：text = 文本长；原子块 = 1；其余容器 = 2 + 子节点。 */
function nodeSize(node: RichNodeJSON): number {
  if (node.type === "text") return node.text?.length ?? 0;
  if (
    node.type === "hardBreak" ||
    node.type === "image" ||
    node.type === "horizontalRule"
  ) {
    return 1;
  }
  let size = 2;
  for (const child of node.content ?? []) size += nodeSize(child);
  return size;
}

/** 文档里第一条带 `cardmind://note/` link mark 的文本的文档位范围。 */
function firstNoteLinkRange(doc: RichNodeJSON): { from: number; to: number } | null {
  let pos = 0;
  for (const block of doc.content ?? []) {
    let textPos = pos + 1;
    for (const inline of block.content ?? []) {
      if (inline.type === "text") {
        const length = inline.text?.length ?? 0;
        const href = (inline.marks ?? []).find((mark) => mark.type === "link")
          ?.attrs?.href;
        if (typeof href === "string" && href.startsWith("cardmind://note/")) {
          return { from: textPos, to: textPos + length };
        }
        textPos += length;
      } else {
        textPos += nodeSize(inline);
      }
    }
    pos += nodeSize(block);
  }
  return null;
}

/** `f9`：把选区放到文档第一条笔记链接上（等价于按下链接——`link` 的
 *  `enableClickSelection` 按下即选中整段；headless 无法真的点文本坐标）。 */
function selectFirstNoteLink(): void {
  if (liveKind !== "rich" || liveSession === null) return;
  const range = firstNoteLinkRange(liveSession.doc);
  if (range === null) return;
  liveSession.run(setTextSelection(range.from, range.to));
}

function parseScenario(raw: string | null): Scenario {
  if (raw === null || raw === "") return { noteId: "new", note: null };
  return JSON.parse(raw) as Scenario;
}

function createRepository(fake: Scenario): EditorRepository {
  const calls = {
    noteGet: 0,
    noteCreate: 0,
    noteUpdateMetadata: 0,
    syncNotesToStore: 0,
    generateNoteId: 0,
    autoCompleteLinks: [] as string[],
    searchByTag: [] as string[],
    order: [] as string[],
  };
  // 桌面场景：多笔记内容表；普通场景：单笔记 note。
  const store = new Map<string, string>();
  if (fake.notes !== undefined) {
    for (const n of fake.notes) store.set(n.id, n.content);
  } else if (fake.note !== null && fake.note !== undefined) {
    store.set(fake.noteId, fake.note);
  }
  const tagsById = new Map<string, string>();
  if (fake.notes !== undefined) {
    for (const n of fake.notes) if (n.tags !== undefined) tagsById.set(n.id, n.tags);
  }
  if (fake.tags !== undefined) tagsById.set(fake.noteId, fake.tags.join(","));
  let loadFailures = fake.failLoad === true ? -1 : fake.failLoad === "once" ? 1 : 0;
  let saveFailures = fake.failSave === true ? -1 : fake.failSave === "once" ? 1 : 0;
  let generated = 0;

  const flushCalls = (): void => {
    void Storage.setItem("test.calls", JSON.stringify(calls));
  };
  const rowFor = (id: string, content: string): EditorNoteRow => ({
    id,
    title: id,
    contentPreview: content.slice(0, 40),
    tags: tagsById.get(id) ?? "",
    updatedAt: "2026-01-01T00:00:00Z",
  });

  return {
    async noteGet(id: string): Promise<string | null> {
      calls.noteGet += 1;
      calls.order.push("noteGet");
      flushCalls();
      if (fake.failLoad === "hang") return await new Promise<string | null>(() => {});
      if (loadFailures !== 0) {
        if (loadFailures > 0) loadFailures -= 1;
        throw new Error("模拟加载失败");
      }
      return store.has(id) ? (store.get(id) ?? null) : null;
    },
    async noteCreate(id: string, text: string): Promise<boolean> {
      calls.noteCreate += 1;
      calls.order.push("noteCreate");
      flushCalls();
      if (saveFailures !== 0) {
        if (saveFailures > 0) saveFailures -= 1;
        throw new Error("模拟保存失败");
      }
      store.set(id, text);
      void Storage.setItem("test.saved", text);
      void Storage.setItem("test.savedId", id);
      // 桌面场景按笔记记录各自最新保存内容，测试断言「笔记 B 内容不混到 A」。
      void Storage.setItem(`test.saved.${id}`, text);
      return true;
    },
    async noteUpdateMetadata(_id: string, tags: string[]): Promise<boolean> {
      calls.noteUpdateMetadata += 1;
      calls.order.push("noteUpdateMetadata");
      flushCalls();
      void Storage.setItem("test.tags", JSON.stringify(tags));
      return true;
    },
    async syncNotesToStore(): Promise<boolean> {
      calls.syncNotesToStore += 1;
      calls.order.push("syncNotesToStore");
      flushCalls();
      return true;
    },
    async generateNoteId(): Promise<string> {
      calls.generateNoteId += 1;
      calls.order.push("generateNoteId");
      flushCalls();
      generated += 1;
      return `generated-${generated}`;
    },
    autoCompleteLinks(prefix: string): EditorNoteRow[] {
      calls.autoCompleteLinks.push(prefix);
      flushCalls();
      const matches = (fake.candidates ?? []).filter((candidate) =>
        candidate.title.toLowerCase().startsWith(prefix.toLowerCase()),
      );
      return matches.map((candidate) => ({
        id: candidate.id,
        title: candidate.title,
        contentPreview: "",
        tags: "",
        updatedAt: "2026-01-01T00:00:00Z",
      }));
    },
    searchByTag(tag: string): EditorNoteRow[] {
      calls.searchByTag.push(tag);
      flushCalls();
      if (fake.noteId === "" || fake.noteId === "new") return [];
      const rows: EditorNoteRow[] = [];
      if (fake.notes !== undefined) {
        for (const n of fake.notes) rows.push(rowFor(n.id, store.get(n.id) ?? n.content));
      } else {
        rows.push(rowFor(fake.noteId, store.get(fake.noteId) ?? ""));
      }
      return rows;
    },
  };
}

function Harness(): JSX.Element {
  const parsed = signal<Scenario | null>(null);
  const selected = signal<string | undefined>(undefined);

  effect(() => {
    void (async () => {
      const raw = await Storage.getItem("test.scenario");
      const p = parseScenario(raw);
      repository = createRepository(p);
      appendText = p.append ?? null;
      parsed.set(p);
      scenario.set(p);
      if (p.mode === "desktop") {
        // 桌面三栏：不走 nav.push editor；初始选中（或第一篇）。
        selected.set(p.selectedNoteId ?? p.notes?.[0]?.id);
      } else {
        nav.push({ name: "editor", noteId: p.noteId });
      }
    })();
  });

  // 测试探针（只经公开 API，不碰私有状态）：
  //   f6 / mod+shift+e → 全文 dump 写入 `test.editorValue`（kind-aware）
  //   f7 / mod+shift+l → 注入 `test.append` 的内容（rich=选区插入，source=末尾）
  //   f8 → 全选（rich=session.run selectAll；source=Editor 内建 mod+a 更准，
  //        但 f8 统一接口；RichEditor headless 下 mod+a 不生效——0.4.0 实测）
  //   f9 → 选区落到第一条 `cardmind://note/` 链接（WYSIWYG 链接气泡菜单）
  //   f* 双键位：RichEditor 聚焦时吞 mod+shift+*（0.4.0 实测），f 键照常到达。
  effect(() => {
    const unbind = keymap.bind({
      f6: () => void dumpEditorValue(),
      f7: () => void appendAtEnd(appendText ?? ""),
      f8: () => {
        if (liveKind === "rich" && liveSession !== null) {
          liveSession.run({ command: "selectAll" });
        }
      },
      f9: () => selectFirstNoteLink(),
      "mod+shift+e": () => void dumpEditorValue(),
      "mod+shift+l": () => void appendAtEnd(appendText ?? ""),
    });
    return () => unbind();
  });

  const desktop = () => parsed()?.mode === "desktop";

  // 桌面三栏场景：左侧模拟列表（点选切 selectedNoteId）+ 右侧真实 DesktopEditorPane。
  function renderDesktop(): JSX.Element {
    return (
      <View testID="desktop-notes" style={{ flex: 1, flexDirection: "row" }}>
        <View testID="note-list" style={{ width: 300, borderRightWidth: 1 }}>
          {() =>
            (parsed()?.notes ?? []).map((n) => (
              <View
                testID={`note-item-${n.id}`}
                role="button"
                accessibilityLabel={`选择 ${n.id}`}
                onPress={() => selected.set(n.id)}
                style={{ minHeight: 48, justifyContent: "center", padding: 8 }}
              >
                <Text>{n.id}</Text>
              </View>
            ))
          }
        </View>
        <View style={{ flex: 1 }}>
          <DesktopEditorPane
            noteId={selected}
            repository={repository ?? undefined}
            onEditorRef={recordEditorRef}
            onRichSession={recordRichSession}
            onNavigateNote={(id: string) => selected.set(id)}
          />
        </View>
      </View>
    );
  }

  return (
    <View style={{ flex: 1 }}>
      <If when={desktop()} else={
        <NavStack state={nav} style={{ flex: 1 }} testID="editor-harness">
          {(route: { name: string; noteId?: string }) =>
            route.name === "editor" ? (
              <EditorScreen
                noteId={route.noteId ?? ""}
                repository={repository ?? undefined}
                onEditorRef={recordEditorRef}
                onRichSession={recordRichSession}
              />
            ) : (
              <NavPage title="笔记" testID="notes-page">
                <View testID="notes-stub" style={{ flex: 1, gap: 8, padding: 16 }}>
                  <Text>notes stub</Text>
                  <View
                    testID="open-editor"
                    role="button"
                    accessibilityLabel="打开编辑页"
                    onPress={() => {
                      const current = scenario();
                      if (current !== null) {
                        nav.push({ name: "editor", noteId: current.noteId });
                      }
                    }}
                    style={{ minHeight: 48, justifyContent: "center" }}
                  >
                    <Text>打开编辑页</Text>
                  </View>
                </View>
              </NavPage>
            )
          }
        </NavStack>
      }>
        {renderDesktop()}
      </If>
    </View>
  );
}

mount(Harness);
