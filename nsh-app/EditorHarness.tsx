// `nsh test` 专用入口：用假 `EditorRepository` 挂载真实 `EditorScreen`。
//
// 不 import `App.tsx`（那里有顶层 IIFE：dataDir / createNoteStore / iroh，会碰
// 真实数据目录），也不碰真实 DB / 网络。场景经 `open(..., { storage })` 的
// `test.scenario` 注入（JSON），假的仓库把调用记录写回 storage 的 `test.calls`、
// `test.saved`、`test.savedId`、`test.tags`，测试用 `app.storage()` 断言。
import { effect, mount, signal, Storage, Text, View, type JSX } from "nsh";
import { NavPage, NavStack } from "nsh/base";
import { EditorScreen, type EditorNoteRow, type EditorRepository } from "./editor_page";
import type { WikiCandidate } from "./editor_text";
import { nav } from "./navigation";

/** 一个测试场景：初始笔记 + 故障注入 + `[[` 候选。 */
interface Scenario {
  /** "new"/"" = 新笔记；其余 = 已有笔记 id。 */
  noteId: string;
  /** noteGet 返回的 markdown；null = 笔记不存在。 */
  note: string | null;
  tags?: string[];
  /** true = 每次都抛；"once" = 第一次抛；"hang" = 永不返回（触发加载超时）。 */
  failLoad?: boolean | "once" | "hang";
  /** true = 每次都抛；"once" = 第一次抛。 */
  failSave?: boolean | "once";
  candidates?: WikiCandidate[];
}

const scenario = signal<Scenario | null>(null);
let repository: EditorRepository | null = null;

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
  let content = fake.note;
  let loadFailures = fake.failLoad === true ? -1 : fake.failLoad === "once" ? 1 : 0;
  let saveFailures = fake.failSave === true ? -1 : fake.failSave === "once" ? 1 : 0;
  let generated = 0;

  const flushCalls = (): void => {
    void Storage.setItem("test.calls", JSON.stringify(calls));
  };
  const row = (): EditorNoteRow => ({
    id: fake.noteId,
    title: fake.noteId,
    contentPreview: "",
    tags: (fake.tags ?? []).join(","),
    updatedAt: "2026-01-01T00:00:00Z",
  });

  return {
    async noteGet(_id: string): Promise<string | null> {
      calls.noteGet += 1;
      calls.order.push("noteGet");
      flushCalls();
      if (fake.failLoad === "hang") return await new Promise<string | null>(() => {});
      if (loadFailures !== 0) {
        if (loadFailures > 0) loadFailures -= 1;
        throw new Error("模拟加载失败");
      }
      return content;
    },
    async noteCreate(id: string, text: string): Promise<boolean> {
      calls.noteCreate += 1;
      calls.order.push("noteCreate");
      flushCalls();
      if (saveFailures !== 0) {
        if (saveFailures > 0) saveFailures -= 1;
        throw new Error("模拟保存失败");
      }
      content = text;
      void Storage.setItem("test.saved", text);
      void Storage.setItem("test.savedId", id);
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
      return [row()];
    },
  };
}

function Harness(): JSX.Element {
  effect(() => {
    void (async () => {
      const raw = await Storage.getItem("test.scenario");
      const parsed = parseScenario(raw);
      repository = createRepository(parsed);
      scenario.set(parsed);
      nav.push({ name: "editor", noteId: parsed.noteId });
    })();
  });

  return (
    <NavStack state={nav} style={{ flex: 1 }} testID="editor-harness">
      {(route: { name: string; noteId?: string }) =>
        route.name === "editor" ? (
          <EditorScreen
            noteId={route.noteId ?? ""}
            repository={repository ?? undefined}
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
  );
}

mount(Harness);
