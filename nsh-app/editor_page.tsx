// 编辑页（P2）：NSH 0.3.0 原生 `Editor` 做 Markdown 源编辑，替换 WebView + Tiptap。
//
// 数据流（06 §2.3）：
//   noteGet → markdown 原样 → Editor(defaultValue) → onChange(value) → 700ms 去抖
//   → generateNoteId（新笔记一次）→ noteCreate → noteUpdateMetadata → syncNotesToStore
// 取消的旧机制：WebView/postMessage/8s 桥、soft↔hard 换行与方括号转义归一化。
//
// 状态机（06 §2.2）：loading / ready / load-error / saving / saved / dirty / save-error。
// `Editor` 只在 ready 后挂载（修 01 R1：加载失败不得用空文档覆盖原内容）。
import { effect, keymap, signal, Text, View, windowSize, type JSX } from "nsh";
import {
  Editor,
  NavPage,
  type EditorRef,
  type EditorSelection,
} from "nsh/base";
import { BackendNotes, BackendStore } from "app/native";
import {
  CardMindEmptyState,
  CardMindIconButton,
  CardMindPrimaryButton,
  CardMindTag,
} from "./components";
import {
  AUTOSAVE_DEBOUNCE_MS,
  LOAD_TIMEOUT_MS,
  NEW_NOTE_IDS,
  TEXT_BEFORE_CHARS,
  completionOffsets,
  linkPrefixFromContext,
  matchTags,
  positionToOffset,
  selectionContext,
  tagsFromCsv,
  textOfChange,
  wikilinkText,
  type TextPosition,
  type WikiCandidate,
} from "./editor_text";
import { goBack, screenChrome } from "./navigation";
import {
  colors,
  editorTypography,
  layout,
  radii,
  spacing,
  typography,
} from "./theme";

/** `searchByTag` / `autoCompleteLinks` 的行（只取编辑器需要的字段，兼容 NoteDto）。 */
export interface EditorNoteRow {
  id: string;
  title: string;
  contentPreview?: string;
  tags?: string;
  updatedAt?: string;
  deletedAt?: string | null;
}

/** 编辑页的数据接缝：默认实现走 `app/native`，`nsh test` 用假实现（不碰真实 DB/iroh）。 */
export interface EditorRepository {
  noteGet(id: string): Promise<string | null>;
  noteCreate(id: string, content: string): Promise<boolean>;
  noteUpdateMetadata(id: string, tags: string[]): Promise<boolean>;
  syncNotesToStore(): Promise<boolean>;
  autoCompleteLinks(prefix: string): EditorNoteRow[] | Promise<EditorNoteRow[]>;
  searchByTag(tag: string): EditorNoteRow[] | Promise<EditorNoteRow[]>;
  generateNoteId(): string | Promise<string>;
}

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
function isNewNoteId(noteId: string): boolean {
  return NEW_NOTE_IDS.includes(noteId);
}

/** 保存态文案（同时有文字，颜色不作唯一状态指示）。 */
const SAVE_STATE = {
  saved: "已保存",
  saving: "正在保存",
  dirty: "尚未保存",
  failed: "保存失败",
} as const;
type SaveState = (typeof SAVE_STATE)[keyof typeof SAVE_STATE];

/** 空态/提示文案。 */
const COPY = {
  editorLabel: "Markdown 编辑器",
  placeholder: "开始写 Markdown…",
  loading: "加载中…",
  loadFailed: "加载失败",
  retry: "重试",
  back: "返回",
  saveRetry: "重试",
} as const;

/** 加载指示器（视觉常量，与 components.tsx 的模块级视觉常量同风格）。 */
const LOADING_SPINNER = { size: 20, stroke: 2 } as const;
/** 失焦后延迟清空候选：点候选 chip 会先失焦，立即清会让按下落空。 */
const CANDIDATE_BLUR_HIDE_MS = 150;
/** 关闭时最多 flush 两轮（保存期间又有输入时再存一次）。 */
const CLOSE_FLUSH_ATTEMPTS = 2;

/** 加载中：居中占位（不是一行裸文字，也不是空文档）。 */
function EditorLoading(): JSX.Element {
  return (
    <View
      testID="editor-loading"
      style={{
        flex: 1,
        alignItems: "center",
        justifyContent: "center",
        gap: spacing.md,
        padding: spacing.xl,
      }}
    >
      <View
        style={{
          width: LOADING_SPINNER.size,
          height: LOADING_SPINNER.size,
          borderRadius: LOADING_SPINNER.size / 2,
          borderWidth: LOADING_SPINNER.stroke,
          borderColor: colors.border,
          borderTopColor: colors.accent,
        }}
      />
      <Text
        style={{
          color: colors.mutedInk,
          fontSize: typography.bodyMedium.fontSize,
          lineHeight: typography.bodyMedium.lineHeight,
        }}
      >
        {COPY.loading}
      </Text>
    </View>
  );
}

/** 加载失败：错误说明 + 重试/返回（可恢复动作，不落盘、不挂 Editor）。 */
function EditorLoadError(props: {
  message: string;
  onRetry: () => void;
  onBack: () => void;
}): JSX.Element {
  return (
    <View style={{ flex: 1 }}>
      <CardMindEmptyState icon="notes" title={COPY.loadFailed} message={props.message} />
      <View
        style={{
          flexDirection: "row",
          justifyContent: "center",
          gap: spacing.md,
          padding: spacing.lg,
        }}
      >
        <CardMindPrimaryButton label={COPY.retry} onPress={props.onRetry} />
        <CardMindPrimaryButton label={COPY.back} onPress={props.onBack} />
      </View>
    </View>
  );
}

/** 桌面（无系统 header）的应用内顶栏：48dp 返回钮 + 标题。 */
function EditorDesktopHeader(props: { onBack: () => void }): JSX.Element {
  return (
    <View
      style={{
        flexDirection: "row",
        alignItems: "center",
        minHeight: layout.mobileTouchTarget,
        paddingHorizontal: spacing.sm,
        gap: spacing.sm,
        borderBottomWidth: 1,
        borderBottomColor: colors.border,
        backgroundColor: colors.paper,
      }}
    >
      <CardMindIconButton icon="back" tooltip={COPY.back} onPress={props.onBack} />
      <Text
        style={{
          flex: 1,
          fontSize: typography.titleMedium.fontSize,
          lineHeight: typography.titleMedium.lineHeight,
          fontWeight: "600",
          color: colors.ink,
        }}
      >
        编辑
      </Text>
    </View>
  );
}

/** 编辑器页（push 路由；`App.tsx` 的 `case "editor"` 渲染本组件）。 */
export function EditorScreen(props: {
  noteId: string;
  /** 测试接缝：不传则用真后端（`backendEditorRepository`）。 */
  repository?: EditorRepository;
}): JSX.Element {
  const repo = props.repository ?? backendEditorRepository;
  const initialId = props.noteId;
  const newNote = isNewNoteId(initialId);

  const phase = signal<"loading" | "ready" | "error">(newNote ? "ready" : "loading");
  const loadError = signal("");
  const loadAttempt = signal(0);
  const text = signal("");
  const loadedText = signal("");
  const tags = signal<string[]>([]);
  const selectionHits = signal<string[]>([]);
  const candidates = signal<WikiCandidate[]>([]);
  const saveState = signal<SaveState>(newNote ? SAVE_STATE.dirty : SAVE_STATE.saved);
  const saveError = signal("");

  let editor!: EditorRef;
  let currentId = newNote ? "" : initialId;
  let lastSaved = "";
  let saveTimer: ReturnType<typeof setTimeout> | null = null;
  let candidateTimer: ReturnType<typeof setTimeout> | null = null;
  let loadTimer: ReturnType<typeof setTimeout> | null = null;
  let completionToken = 0;
  let idPromise: Promise<string> | null = null;
  let chain: Promise<boolean> = Promise.resolve(true);
  let disposed = false;

  const metrics = () =>
    windowSize().width >= layout.desktopBreakpoint
      ? editorTypography.desktop
      : editorTypography.mobile;

  function clearSaveTimer(): void {
    if (saveTimer !== null) {
      clearTimeout(saveTimer);
      saveTimer = null;
    }
  }

  function clearCandidateTimer(): void {
    if (candidateTimer !== null) {
      clearTimeout(candidateTimer);
      candidateTimer = null;
    }
  }

  function clearLoadTimer(): void {
    if (loadTimer !== null) {
      clearTimeout(loadTimer);
      loadTimer = null;
    }
  }

  /** 写一次（整篇替换）。返回 false 时 UI 停在「保存失败」，不谎报已保存。 */
  async function persist(): Promise<boolean> {
    const snapshot = text();
    // 新笔记空内容不创建；已有笔记的空内容也允许（修 01 R3）。
    if (currentId === "" && snapshot.trim() === "") return true;
    // 没有改动且已有 id：不需要再写。
    if (currentId !== "" && snapshot === lastSaved) return true;
    saveState.set(SAVE_STATE.saving);
    saveError.set("");
    try {
      if (currentId === "") {
        if (idPromise === null) {
          idPromise = Promise.resolve(repo.generateNoteId()).catch((error) => {
            idPromise = null;
            throw error;
          });
        }
        currentId = await idPromise; // 新笔记只生成一次 UUID
      }
      const id = currentId;
      await repo.noteCreate(id, snapshot);
      await repo.noteUpdateMetadata(id, tags());
      await repo.syncNotesToStore();
      if (disposed) return true;
      if (text() === snapshot) {
        lastSaved = snapshot;
        saveState.set(SAVE_STATE.saved);
      } else {
        // 保存期间又有输入：不覆盖 lastSaved，等下一轮去抖保存。
        saveState.set(SAVE_STATE.dirty);
        scheduleSave();
      }
      return true;
    } catch (error) {
      if (disposed) return false;
      saveState.set(SAVE_STATE.failed);
      saveError.set(`保存失败：${String(error)}`);
      return false;
    }
  }

  /** 串行化保存：后一次永远在前一次之后执行，避免旧快照覆盖新内容。 */
  function saveNow(): Promise<boolean> {
    const run = chain.then(() => persist());
    chain = run.then(
      (ok) => ok,
      () => false,
    );
    return run;
  }

  function scheduleSave(): void {
    clearSaveTimer();
    saveTimer = setTimeout(() => {
      saveTimer = null;
      void saveNow();
    }, AUTOSAVE_DEBOUNCE_MS);
  }

  function retrySave(): void {
    clearSaveTimer();
    void saveNow();
  }

  /** 关闭：dirty 时先 flush 最新文本再返回；失败留在页面（错误条可重试）。 */
  async function closeEditor(): Promise<void> {
    clearSaveTimer();
    for (let attempt = 0; attempt < CLOSE_FLUSH_ATTEMPTS; attempt += 1) {
      if (text() === lastSaved) {
        goBack();
        return;
      }
      if (!(await saveNow())) return;
    }
    if (text() === lastSaved) goBack();
  }

  // 加载门：noteGet 完成前不挂 Editor；失败/超时显示错误态，重试重新加载。
  effect(() => {
    const attempt = loadAttempt();
    if (newNote) {
      phase.set("ready");
      return;
    }
    phase.set("loading");
    loadError.set("");
    void (async () => {
      let timedOut = false;
      const timeout = new Promise<never>((_resolve, reject) => {
        loadTimer = setTimeout(() => {
          loadTimer = null;
          timedOut = true;
          reject(new Error(COPY.loading));
        }, LOAD_TIMEOUT_MS);
      });
      try {
        const value = await Promise.race([repo.noteGet(initialId), timeout]);
        clearLoadTimer();
        if (attempt !== loadAttempt()) return;
        if (value === null || value === undefined) {
          phase.set("error");
          loadError.set("笔记不存在或已删除");
          return;
        }
        loadedText.set(value);
        text.set(value);
        lastSaved = value;
        saveState.set(SAVE_STATE.saved);
        saveError.set("");
        try {
          const rows = await repo.searchByTag("");
          if (attempt !== loadAttempt()) return;
          const row = rows.find((item) => item.id === initialId);
          tags.set(tagsFromCsv(row?.tags ?? ""));
        } catch {
          tags.set([]);
        }
        if (attempt !== loadAttempt()) return;
        phase.set("ready");
      } catch (error) {
        clearLoadTimer();
        if (attempt !== loadAttempt()) return;
        phase.set("error");
        loadError.set(
          timedOut ? "加载超时，请检查后重试" : `读取笔记失败：${String(error)}`,
        );
      }
    })();
    return () => {
      clearLoadTimer();
    };
  });

  // 卸载：清 timer（不把未保存文本当成已保存）。
  effect(() => () => {
    disposed = true;
    clearSaveTimer();
    clearCandidateTimer();
    clearLoadTimer();
  });

  // 候选打开时 Escape 先关候选（最新绑定优先于 NavPage 的返回）。
  effect(() => {
    if (candidates().length === 0) return;
    return keymap.bind("escape", () => {
      clearCandidateTimer();
      setCandidates([]);
    });
  });

  function setCandidates(next: WikiCandidate[]): void {
    completionToken += 1;
    candidates.set(next);
  }

  function handleChange(value: unknown): void {
    const next = textOfChange(value);
    text.set(next);
    if (next === lastSaved) {
      saveError.set("");
      saveState.set(currentId === "" ? SAVE_STATE.dirty : SAVE_STATE.saved);
      return;
    }
    saveState.set(SAVE_STATE.dirty);
    scheduleSave();
  }

  async function loadCandidates(prefix: string): Promise<void> {
    completionToken += 1;
    const token = completionToken;
    try {
      const rows = await repo.autoCompleteLinks(prefix);
      if (token !== completionToken) return; // 过期结果丢弃
      candidates.set(
        rows
          .filter(
            (row) =>
              row.id.length > 0 &&
              row.title.length > 0 &&
              row.id !== currentId,
          )
          .map((row) => ({ id: row.id, title: row.title })),
      );
    } catch {
      if (token === completionToken) candidates.set([]);
    }
  }

  function handleSelection(selections: EditorSelection[]): void {
    const primary = selections[selections.length - 1];
    if (primary === undefined) {
      selectionHits.set([]);
      setCandidates([]);
      return;
    }
    const context = selectionContext(text(), primary.anchor, primary.head);
    selectionHits.set(
      matchTags(tags(), { text: context.selected, textBefore: context.textBefore }),
    );
    const prefix = linkPrefixFromContext(context.textBefore);
    if (prefix === null) {
      setCandidates([]);
      return;
    }
    void loadCandidates(prefix);
  }

  function handleBlur(): void {
    clearCandidateTimer();
    candidateTimer = setTimeout(() => {
      candidateTimer = null;
      setCandidates([]);
    }, CANDIDATE_BLUR_HIDE_MS);
  }

  function handleFocus(): void {
    clearCandidateTimer();
  }

  /** 点选候选：替换已输入的 `[[prefix`（一步撤销，修 01 R5），插入 `[[id|title]] `。 */
  async function acceptCandidate(candidate: WikiCandidate): Promise<void> {
    clearCandidateTimer();
    if (!editor) return;
    const value = await editor.value();
    const selections = await editor.selections();
    const primary = selections[selections.length - 1];
    const head: TextPosition = primary?.head ?? { line: 0, column: 0 };
    const offset = positionToOffset(value, head);
    const before = value.slice(Math.max(0, offset - TEXT_BEFORE_CHARS), offset);
    const prefix = linkPrefixFromContext(before) ?? "";
    const range = completionOffsets(offset, prefix);
    const start = await editor.offsetToPosition(range.start);
    const end = await editor.offsetToPosition(range.end);
    editor.edit([{ range: { start, end }, text: wikilinkText(candidate) }]);
    setCandidates([]);
    editor.focus();
  }

  const saveStateColor = () => {
    if (saveState() === SAVE_STATE.failed) return colors.danger;
    if (saveState() === SAVE_STATE.saving) return colors.accent;
    return colors.mutedInk;
  };

  return (
    <NavPage
      {...screenChrome("编辑")}
      popOnBack={false}
      onBackPress={() => void closeEditor()}
      header={<EditorDesktopHeader onBack={() => void closeEditor()} />}
      headerLeft={
        <CardMindIconButton
          icon="back"
          tooltip={COPY.back}
          onPress={() => void closeEditor()}
        />
      }
    >
      <View style={{ flex: 1, backgroundColor: colors.paper }}>
        {phase() === "loading" ? <EditorLoading /> : null}
        {phase() === "error" ? (
          <EditorLoadError
            message={loadError()}
            onRetry={() => loadAttempt.update((count) => count + 1)}
            onBack={goBack}
          />
        ) : null}
        {phase() === "ready" ? (
          <>
            <View
              style={{
                flexDirection: "row",
                alignItems: "center",
                gap: spacing.sm,
                paddingHorizontal: spacing.lg,
                paddingVertical: spacing.sm,
              }}
            >
              <Text
                testID="save-state"
                style={{
                  color: saveStateColor(),
                  fontSize: typography.labelLarge.fontSize,
                  fontWeight: "600",
                }}
              >
                {saveState()}
              </Text>
            </View>
            <If when={saveState() === SAVE_STATE.failed}>
              <View
                style={{
                  flexDirection: "row",
                  alignItems: "center",
                  gap: spacing.sm,
                  paddingHorizontal: spacing.lg,
                  paddingBottom: spacing.sm,
                }}
              >
                <Text
                  numberOfLines={2}
                  style={{
                    flex: 1,
                    color: colors.danger,
                    fontSize: typography.labelLarge.fontSize,
                  }}
                >
                  {saveError()}
                </Text>
                <CardMindPrimaryButton label={COPY.saveRetry} onPress={retrySave} />
              </View>
            </If>
            <If when={tags().length > 0}>
              <View
                style={{
                  flexDirection: "row",
                  flexWrap: "wrap",
                  gap: spacing.sm,
                  paddingHorizontal: spacing.lg,
                  paddingBottom: spacing.sm,
                }}
              >
                {() =>
                  tags().map((tag, index) => (
                    <CardMindTag
                      testID={`tag-${index}`}
                      textTestID={`tag-text-${index}`}
                      label={tag}
                      selected={selectionHits().includes(tag)}
                      comfortable
                    />
                  ))
                }
              </View>
            </If>
            <If when={candidates().length > 0}>
              <View
                testID="link-candidates"
                style={{
                  flexDirection: "row",
                  flexWrap: "wrap",
                  alignItems: "center",
                  gap: spacing.sm,
                  paddingHorizontal: spacing.lg,
                  paddingVertical: spacing.sm,
                  backgroundColor: colors.surfaceLow,
                  borderTopWidth: 1,
                  borderBottomWidth: 1,
                  borderColor: colors.border,
                }}
              >
                <Text
                  style={{
                    color: colors.mutedInk,
                    fontSize: typography.labelLarge.fontSize,
                  }}
                >
                  链接到：
                </Text>
                {() =>
                  candidates().map((candidate) => (
                    <CardMindTag
                      testID={`link-${candidate.id}`}
                      label={candidate.title}
                      comfortable
                      onTap={() => void acceptCandidate(candidate)}
                    />
                  ))
                }
              </View>
            </If>
            <Editor
              ref={editor}
              testID="editor"
              defaultValue={loadedText()}
              language="markdown"
              placeholder={COPY.placeholder}
              autoClose={false}
              autoIndent={false}
              softWrap
              lineNumbers={false}
              folding={false}
              indentGuides={false}
              activeLine
              accessibilityLabel={COPY.editorLabel}
              fontSize={metrics().fontSize}
              lineHeight={metrics().lineHeight}
              style={{
                flex: 1,
                backgroundColor: colors.paper,
                borderRadius: radii.md,
              }}
              onChange={(value: string) => handleChange(value)}
              onSelectionChange={(selections: EditorSelection[]) =>
                handleSelection(selections)
              }
              onBlur={handleBlur}
              onFocus={handleFocus}
            />
          </>
        ) : null}
      </View>
    </NavPage>
  );
}
