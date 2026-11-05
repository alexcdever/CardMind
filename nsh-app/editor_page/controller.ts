// 编辑页控制器（自 editor_page.tsx 纯结构拆出）：`EditorPage` 体内「数据接缝 →
// 保存态颜色」的全部声明原样移入 `createEditorController`——signals、let 绑定、
// metrics/sideBySide、clear*Timer、persist/saveNow/scheduleSave/retrySave、
// readLatestText/closeEditor、加载门 effect、卸载 flush effect、Escape keymap
// effect、setCandidates/flushOnUnmount、预览去抖/开合、handleChange/Selection/
// Blur/Focus、acceptCandidate、saveStateColor。声明顺序与函数体逐字不变；
// 仅外层包一个 `function createEditorController(props)` + 末尾 return，缩进 +2。
//
// `editor` 是唯一「读+写」的 let 绑定：入口解构为 const 后无法写回，故控制器
// 额外暴露 `setEditor`（renderEditor 的 ref 回调由 `editor = ref` 改为
// `setEditor(ref)`，唯一改写点）；其余标识符名字不变，入口经解构按原名取用。
import { effect, keymap, signal, windowSize } from "nsh";
import { type EditorRef, type EditorSelection } from "nsh/base";
import {
  AUTOSAVE_DEBOUNCE_MS,
  LOAD_TIMEOUT_MS,
  TEXT_BEFORE_CHARS,
  completionOffsets,
  legacyWikilinksToMarkdown,
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
} from "../editor_text";
import { goBack } from "../navigation";
import { colors, editorTypography, layout } from "../theme";
import {
  CANDIDATE_BLUR_HIDE_MS,
  CLOSE_FLUSH_ATTEMPTS,
  COPY,
  PREVIEW_DEBOUNCE_MS,
  SAVE_STATE,
  SIDE_BY_SIDE_WIDTH,
  type SaveState,
} from "./constants";
import { backendEditorRepository, isNewNoteId } from "./repository";
import type { EditorPageProps } from "./types";

/** 一次 `EditorPage` 挂载的全部实例状态与逻辑；返回对象的键逐字等于入口
 *  `renderPreview`/`renderEditor`/`renderContent`/返回 JSX 使用的局部名。 */
export function createEditorController(props: EditorPageProps) {
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

  /** Editor ref 回写接缝（原 `editor = ref`；解构为 const 后只能经函数写回）。 */
  function setEditor(ref: EditorRef): void {
    editor = ref;
  }

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
        // 与 `Editor.value()` 同口径：仅 `\r\n`/`\r`→`\n` 归一（05 §1.2）；
        // 另把旧 `[[id|alias]]` 归一为新存储格式 `[alias](cardmind://note/id)`
        // （P4-2 惰性迁移：加载即显示新格式，lastSaved 同步取转换后文本，
        // 未编辑不 dirty、不回写；首次保存时自然写新格式）。
        const loaded = legacyWikilinksToMarkdown(normalizeNewlines(value));
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

  /** 点选候选：替换已输入的 `[[prefix`（一步撤销，修 01 R5），
   *  插入 `[title](cardmind://note/id) `（P4-2 新存储格式）。 */
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

  return {
    loadAttempt,
    loadError,
    phase,
    text,
    loadedText,
    tags,
    selectionHits,
    candidates,
    saveState,
    saveError,
    preview,
    previewText,
    metrics,
    sideBySide,
    setEditor,
    retrySave,
    closeEditor,
    setCandidates,
    togglePreview,
    handleChange,
    handleSelection,
    handleBlur,
    handleFocus,
    acceptCandidate,
    saveStateColor,
  };
}
