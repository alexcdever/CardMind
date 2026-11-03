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
  TextView,
  type EditorRef,
  type EditorSelection,
  type TextViewCustomNode,
  type TextViewStyles,
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
  normalizeNewlines,
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
  preview: "预览",
  backToEdit: "编辑",
  closeCandidates: "关闭候选",
} as const;

/** 加载指示器（视觉常量，与 components.tsx 的模块级视觉常量同风格）。 */
const LOADING_SPINNER = { size: 20, stroke: 2 } as const;
/** 失焦后延迟清空候选：点候选 chip 会先失焦，立即清会让按下落空。 */
const CANDIDATE_BLUR_HIDE_MS = 150;
/** 关闭时最多 flush 两轮（保存期间又有输入时再存一次）。 */
const CLOSE_FLUSH_ATTEMPTS = 2;
/** 桌面编辑区并排预览的最小宽度：≥1280pt 才并排（C2，06 §6-7）；
 *  <1280 用单栏编辑↔预览切换（C1）。 */
const SIDE_BY_SIDE_WIDTH = 1280;
/** 预览去抖（ms）：预览可见时打字停止这么久才重解析（05 §3.3/R6）。 */
const PREVIEW_DEBOUNCE_MS = 450;

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
      <CardMindEmptyState icon="warning" title={COPY.loadFailed} message={props.message} />
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

/** `[[id|alias]]` 的 MarkdownExtension：把 wikilink 解析成自定义 inline 节点，
 *  `renderCustom` 渲染成 chip（显示 alias 或 target；点击跳转是 P4 增强）。
 *  pattern 是 Rust regex：`[[` 之后非 `]`/`|` 的 target，可选 `|alias`。 */
const WIKILINK_EXTENSION = {
  name: "wikilink",
  pattern: "\\[\\[([^\\]\\|]+)(?:\\|([^\\]]+))?\\]\\]",
} as const;

/** 预览的 TextView 部件样式：映射 theme 令牌（不裸值）。
 *  只覆盖高频 part（root/heading/link/code/blockquote），其余用默认。 */
const PREVIEW_STYLES: TextViewStyles = {
  root: {
    color: colors.ink,
    fontSize: typography.bodyMedium.fontSize,
    lineHeight: typography.bodyMedium.lineHeight + 4,
  },
  heading: { color: colors.ink, fontWeight: "600" },
  link: { color: colors.accent },
  code: {
    color: colors.ink,
    backgroundColor: colors.surfaceLow,
    fontSize: typography.bodyMedium.fontSize - 1,
  },
  codeBlock: {
    backgroundColor: colors.surfaceLow,
    borderRadius: radii.md,
  },
  blockquote: {
    borderLeftColor: colors.accent,
  },
};

/** 编辑区（`Editor` + 预览切换 + 候选行 + 标签行 + 保存态）。
 *  `embedded`：桌面第三栏内嵌时不套 NavPage/返回键。 */
export function EditorPage(props: {
  noteId: string;
  /** 桌面第三栏内嵌：不套 NavPage，无返回键；关闭改为通知父级清选中。 */
  embedded?: boolean;
  /** 测试接缝：不传则用真后端（`backendEditorRepository`）。 */
  repository?: EditorRepository;
  /** 测试接缝：Editor 挂载后把 ref 交给调用方（`nsh test` 读全文做逐字节断言）。 */
  onEditorRef?: (ref: EditorRef) => void;
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
  // 预览：`preview` 决定当前是否显示 TextView；`previewText` 是去抖后的预览文本
  // （绝不把每键变化的 text() 直接绑给 TextView，05 §3.3/R6）。
  const preview = signal(false);
  const previewText = signal("");

  let editor!: EditorRef;
  let currentId = newNote ? "" : initialId;
  let lastSaved = "";
  let saveTimer: ReturnType<typeof setTimeout> | null = null;
  let candidateTimer: ReturnType<typeof setTimeout> | null = null;
  let previewTimer: ReturnType<typeof setTimeout> | null = null;
  let loadTimer: ReturnType<typeof setTimeout> | null = null;
  let completionToken = 0;
  let idPromise: Promise<string> | null = null;
  let chain: Promise<boolean> = Promise.resolve(true);
  let disposed = false;

  const metrics = () =>
    windowSize().width >= layout.desktopBreakpoint
      ? editorTypography.desktop
      : editorTypography.mobile;
  /** ≥1280 桌面：`preview` 打开时 Editor|TextView 并排；否则单栏切换。 */
  const sideBySide = () => windowSize().width >= SIDE_BY_SIDE_WIDTH;

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

  function clearPreviewTimer(): void {
    if (previewTimer !== null) {
      clearTimeout(previewTimer);
      previewTimer = null;
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
    // 新笔记空内容不创建（不空建笔记）；已有笔记的空内容允许保存（修 01 R3）。
    // 同步 lastSaved，避免「未落盘但永远 dirty」的状态（第 1 轮关闭卡死的根因）。
    if (currentId === "" && snapshot.trim() === "") {
      lastSaved = snapshot;
      return true;
    }
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

  /** 关闭前以 `editor.value()` 取最新文本（0.3.0 只做 `\r\n`/`\r`→`\n` 归一），
   *  不只依赖 `onChange` 写下的 `text()` 信号；读失败时退回信号值。 */
  async function readLatestText(): Promise<string> {
    if (!editor) return text();
    try {
      const latest = await editor.value();
      if (latest !== text()) {
        text.set(latest);
        if (latest !== lastSaved) saveState.set(SAVE_STATE.dirty);
      }
      return latest;
    } catch {
      return text();
    }
  }

  /** 关闭：dirty 时先 flush 最新文本再返回；失败留在页面（错误条可重试）。
   *  新笔记且内容 trim 后为空：直接返回，不创建、不落盘（否则会卡在页面上）。 */
  async function closeEditor(): Promise<void> {
    clearSaveTimer();
    await readLatestText();
    if (currentId === "" && text().trim() === "") {
      goBack();
      return;
    }
    for (let attempt = 0; attempt < CLOSE_FLUSH_ATTEMPTS; attempt += 1) {
      if (text() === lastSaved) {
        goBack();
        return;
      }
      if (!(await saveNow())) return;
      await readLatestText();
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
        // 与 `Editor.value()` 同口径：仅 `\r\n`/`\r`→`\n` 归一（05 §1.2），
        // 其余逐字节保留；这样未编辑的 CRLF 笔记不会被误判为 dirty。
        const loaded = normalizeNewlines(value);
        loadedText.set(loaded);
        text.set(loaded);
        lastSaved = loaded;
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

  // 卸载：清 timer；桌面切笔记/离开时脏数据尽力 flush（06 §2.3「unmount 存快照」）。
  // 关闭按钮路径已先 saveNow；这里是「换 key 重建」等直接卸载的兜底。
  effect(() => () => {
    disposed = true;
    clearSaveTimer();
    clearCandidateTimer();
    clearPreviewTimer();
    clearLoadTimer();
    flushOnUnmount();
  });

  // 候选打开时 Escape 先关候选、不退出编辑页。
  // P2 实测 Editor 聚焦会消费 Escape，普通 keymap 绑不到；`when:"always"` 让绑定
  // 即使文本输入持有焦点也触发（0.3.0 KeyBindingOptions），这是唯一不改 Editor 的
  // 官方途径。没有候选时不绑，Escape 回落 NavPage 返回语义。
  effect(() => {
    if (candidates().length === 0) return;
    return keymap.bind(
      "escape",
      () => {
        clearCandidateTimer();
        setCandidates([]);
      },
      { when: "always" },
    );
  });

  function setCandidates(next: WikiCandidate[]): void {
    completionToken += 1;
    candidates.set(next);
  }

  /** 卸载时尽力把未保存内容写回（不读可能已拆的编辑器，用 `text()` 快照）。
   *  新笔记空内容不建；失败静默（页面已拆，无 UI 可报）。 */
  function flushOnUnmount(): void {
    const snapshot = text();
    const id = currentId;
    if (snapshot === lastSaved) return;
    if (id === "" && snapshot.trim() === "") return;
    void (async () => {
      try {
        let useId = id;
        if (useId === "") {
          useId = idPromise !== null ? await idPromise : await repo.generateNoteId();
        }
        await repo.noteCreate(useId, snapshot);
        await repo.noteUpdateMetadata(useId, tags());
        await repo.syncNotesToStore();
      } catch {
        // 卸载后无法呈现错误；保留数据已在编辑器/调用方快照中。
      }
    })();
  }

  /** 预览文本去抖刷新（预览可见时打字停止 PREVIEW_DEBOUNCE_MS 后重解析）。 */
  function schedulePreviewRefresh(): void {
    clearPreviewTimer();
    previewTimer = setTimeout(() => {
      previewTimer = null;
      previewText.set(text());
    }, PREVIEW_DEBOUNCE_MS);
  }

  /** 打开预览：以 `editor.value()` 取最新文本（不必等去抖）后切到预览。 */
  async function openPreview(): Promise<void> {
    const latest = await readLatestText();
    previewText.set(latest);
    preview.set(true);
  }

  /** 切回编辑：源码未变（预览只读）；Editor 以最新文本重挂载。 */
  function closePreview(): void {
    clearPreviewTimer();
    preview.set(false);
  }

  function togglePreview(): void {
    if (preview()) closePreview();
    else void openPreview();
  }

  function handleChange(value: unknown): void {
    const next = textOfChange(value);
    text.set(next);
    if (preview()) schedulePreviewRefresh();
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

  /** 预览面板（只读 TextView）。`[[id|alias]]` 经扩展渲染成 chip（显示 alias/target）。 */
  function renderPreview(): JSX.Element {
    return (
      <View
        testID="preview-pane"
        style={{
          flex: 1,
          backgroundColor: colors.paper,
          paddingHorizontal: spacing.lg,
          paddingVertical: spacing.sm,
        }}
      >
        <TextView
          testID="preview"
          markdown={previewText()}
          extensions={[WIKILINK_EXTENSION]}
          styles={PREVIEW_STYLES}
          selectable
          renderCustom={(node: TextViewCustomNode) => {
            const target = node.attributes?.["1"] ?? "";
            const alias = node.attributes?.["2"] ?? "";
            const label = alias.length > 0 ? alias : target.length > 0 ? target : (node.text ?? "");
            return (
              <CardMindTag testID={`wikilink-${target || "custom"}`} label={label} />
            );
          }}
        />
      </View>
    );
  }

  /** 编辑面板（`Editor`）。单独拆出便于并排/切换两种布局复用。 */
  function renderEditor(): JSX.Element {
    return (
      <Editor
        ref={(ref: EditorRef) => {
          editor = ref;
          props.onEditorRef?.(ref);
        }}
        testID="editor"
        defaultValue={text() || loadedText()}
        language="markdown"
        placeholder={COPY.placeholder}
        autoFocus
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
    );
  }

  /** 编辑区主体（供 NavPage / embedded 两种外壳复用）。 */
  function renderContent(): JSX.Element {
    return (
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
          /* 桌面编辑区最大宽 768 并居中（layout.editorMaxWidth）；窄屏自然 100%。 */
          <View
            testID="editor-area"
            style={{
              flex: 1,
              width: "100%",
              maxWidth: layout.editorMaxWidth,
              alignSelf: "center",
            }}
          >
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
              <View style={{ flex: 1 }} />
              {/* 预览切换：文字 + 状态（颜色不作唯一指示）；触摸目标 ≥48dp。 */}
              <View
                testID="preview-toggle"
                role="button"
                accessibilityLabel={preview() ? COPY.backToEdit : COPY.preview}
                accessibilityState={{ selected: preview() }}
                onPress={togglePreview}
                style={{
                  minHeight: layout.mobileTouchTarget,
                  minWidth: layout.mobileTouchTarget,
                  alignItems: "center",
                  justifyContent: "center",
                  paddingHorizontal: spacing.md,
                  borderRadius: radii.md,
                  borderWidth: 1,
                  borderColor: preview() ? colors.accent : colors.border,
                  backgroundColor: preview() ? colors.surfaceLow : "transparent",
                }}
              >
                <Text
                  style={{
                    color: preview() ? colors.accent : colors.mutedInk,
                    fontSize: typography.labelLarge.fontSize,
                    fontWeight: "600",
                  }}
                >
                  {preview() ? COPY.backToEdit : COPY.preview}
                </Text>
              </View>
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
                {/* 触摸/无硬件键盘的候选关闭入口（Escape 之外的显式关闭）。 */}
                <View style={{ flex: 1 }} />
                <CardMindIconButton
                  icon="close"
                  tooltip={COPY.closeCandidates}
                  onPress={() => setCandidates([])}
                />
              </View>
            </If>
            {/* 编辑/预览主体（响应式 thunk）：单栏预览时 Editor 卸载、以最新文本
                重挂载（切回源码字节不变；撤销栈随预览切换重置，P3 允许）；
                ≥1280 桌面并排时 Editor 保持挂载、TextView 同步显示。 */}
            {() => {
              if (!preview()) return renderEditor();
              if (sideBySide()) {
                return (
                  <View style={{ flex: 1, flexDirection: "row", gap: spacing.sm }}>
                    <View style={{ flex: 1 }}>{renderEditor()}</View>
                    {renderPreview()}
                  </View>
                );
              }
              return renderPreview();
            }}
          </View>
        ) : null}
      </View>
    );
  }

  if (props.embedded === true) {
    return renderContent();
  }
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
      {renderContent()}
    </NavPage>
  );
}

/** 兼容命名：`App.tsx` 的 `case "editor"` 仍渲染 `EditorScreen`（push 路由壳）。 */
export const EditorScreen = EditorPage;

/**
 * 桌面第三栏：选中笔记 → 内嵌 `EditorPage`（`embedded`，不套 NavPage/返回键）。
 *
 * 跨笔记状态隔离（06 §2.4）：`<Each>` 以 `noteId` 为 key，0.3.0 的 Each
 * 「rows are kept by key」（`globals.d.ts`）——key 变化即旧行移除、新行创建，
 * `Editor` 的撤销栈随之重建，切笔记后 Ctrl+Z 不会撤回上一篇内容。
 * 未选中时显示空态；新建入口由列表/侧栏的「新建笔记」负责（push 编辑路由）。
 */
export function DesktopEditorPane(props: {
  /** 选中笔记 id 的访问器（`note_list.tsx` 传 `selectedNoteId`，测试传 signal）。 */
  noteId: () => string | undefined;
  /** 测试接缝：不传则用真后端。 */
  repository?: EditorRepository;
  /** 测试接缝：把内嵌 Editor 的 ref 交给调用方。 */
  onEditorRef?: (ref: EditorRef) => void;
}): JSX.Element {
  return (
    <View style={{ flex: 1, backgroundColor: colors.paper }}>
      {() => {
        const id = props.noteId();
        if (id === undefined) {
          return (
            <CardMindEmptyState
              icon="edit"
              title="选择一篇笔记"
              message="在左侧列表选择笔记，或创建一篇新笔记。"
            />
          );
        }
        return (
          <Each of={[id]} key={(noteId: string) => noteId}>
            {(noteId: () => string) => (
              <EditorPage
                noteId={noteId()}
                embedded
                repository={props.repository}
                onEditorRef={props.onEditorRef}
              />
            )}
          </Each>
        );
      }}
    </View>
  );
}
