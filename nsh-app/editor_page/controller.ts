// 编辑页控制器（自 editor_page.tsx 纯结构拆出）：`EditorPage` 体内「数据接缝 →
// 保存态颜色」的全部声明原样移入 `createEditorController`——signals、let 绑定、
// metrics、clear*Timer、persist/saveNow/scheduleSave/retrySave、
// readLatestText/closeEditor、加载门 effect、卸载 flush effect、Escape keymap
// effect、setCandidates/flushOnUnmount、源码↔WYSIWYG 模式开合、handleChange/
// Selection/Blur/Focus、acceptCandidate、saveStateColor。
//
// P4-3a：编辑态从 `Editor`（Markdown 源码）换为 `RichEditor`（WYSIWYG），
// 原 `Editor` 保留为「源码模式」（`sourceMode` 信号；原 `preview` 语义反转且改名）。
// 关键结构变化：
//   - `text()` 仍持有「最近一次落盘的 Markdown 口径」；WYSIWYG 下**不**随每次
//     事务序列化（19k 字 getMarkdown≈22ms/次，逐键太贵），而是 update→dirty→
//     700ms 防抖→persist 时经 `currentContent()` 取当次快照。
//   - WYSIWYG 会话生命周期：默认（非源码模式）经 `ensureRichSession()` 惰性创建；
//     切源码时拆监听弃会话，切回时以最新 Markdown 重建（撤销栈随模式切换重置，
//     同旧「预览切换重置撤销」口径）。
//   - `[[` 候选只在源码模式启用（P4-3a 不做 WYSIWYG suggestion——selection 是
//     ProseMirror 位而非文本 offset，下轮再接）。
//   - `editor`（源码 `EditorRef`）与 `richSession` 是两个互斥的「活编辑器」；
//     `readLatestText`/`currentContent` 按 `sourceMode()` 选边。
import { effect, keymap, signal, windowSize } from "nsh";
import { type EditorRef, type EditorSelection, type RichEditorSession, type RichSelectionJSON } from "nsh/base";
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
  SAVE_STATE,
  type SaveState,
} from "./constants";
import { backendEditorRepository, isNewNoteId } from "./repository";
import { canonicalMarkdown, createNoteRichSession } from "./rich";
import type { EditorPageProps } from "./types";

/** 一次 `EditorPage` 挂载的全部实例状态与逻辑；返回对象的键逐字等于入口
 *  renderSource/renderRich/renderContent/返回 JSX 使用的局部名。 */
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
  /** 编辑模式：`false` = WYSIWYG（`RichEditor`，默认）；`true` = 源码
   *  （`Editor` 显示 Markdown 原文，可编辑）。P4-3a 由「预览开关」改语义。 */
  const sourceMode = signal(false);
  /** WYSIWYG 会话代际：每次 `ensureRichSession()` 新建会话时 +1；下面的
   *  effect 读它挂监听（监听必须挂在 effect 作用域——session.on() 绑
   *  「调用方组件上下文」，render thunk 重跑会把监听连带销毁，导致
   *  事务不再触发自动保存。实测见 P4-3a progress。） */
  const richEpoch = signal(0);

  let editor!: EditorRef;
  /** WYSIWYG 会话与其 update 监听（互斥于源码模式的 `editor`）。 */
  let richSession: RichEditorSession | null = null;
  let currentId = newNote ? "" : initialId;
  let lastSaved = "";
  let saveTimer: ReturnType<typeof setTimeout> | null = null;
  let candidateTimer: ReturnType<typeof setTimeout> | null = null;
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

  /** 当前编辑器内容的「当次 Markdown 快照」（同步）。WYSIWYG 下现场
   *  `getMarkdown()`（不写信号，调用方自取）；源码模式为 `text()`。 */
  function currentContent(): string {
    if (!sourceMode() && richSession !== null) return richSession.getMarkdown();
    return text();
  }

  /** 写一次（整篇替换）。返回 false 时 UI 停在「保存失败」，不谎报已保存。 */
  async function persist(): Promise<boolean> {
    const snapshot = currentContent();
    // 脏检测基线用 canonical（RichEditor 序列化形式）：多空行/语法重排在
    // WYSIWYG 往返下会塌缩，raw 比较会幻影 dirty（见 P4-3a progress）。
    const base = canonicalMarkdown(snapshot);
    // 新笔记空内容不创建（不空建笔记）；已有笔记的空内容允许保存（修 01 R3）。
    // 同步 lastSaved，避免「未落盘但永远 dirty」的状态（第 1 轮关闭卡死的根因）。
    if (currentId === "" && snapshot.trim() === "") {
      lastSaved = base;
      text.set(base);
      return true;
    }
    // 没有改动且已有 id：不需要再写；同时复位「已保存」——handleRichUpdate
    // 每次事务都标 dirty，等值内容必须在这里把状态拉回 saved。
    if (currentId !== "" && base === lastSaved) {
      text.set(base);
      saveState.set(SAVE_STATE.saved);
      return true;
    }
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
      if (canonicalMarkdown(currentContent()) === base) {
        lastSaved = base;
        text.set(base);
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

  /** 关闭前取最新文本并归一到 canonical 基线：源码模式走 `editor.value()`
   *  → canonical；WYSIWYG 走 `getMarkdown()` → canonical（getMarkdown 的
   *  原文与 canonical 可能差尾随空行，统一 canonical 才能与 lastSaved
   *  逐字节比较，否则「等值即返回」判定失效、关闭卡死——P4-3a 实测）。 */
  async function readLatestText(): Promise<string> {
    if (sourceMode()) {
      if (!editor) return text();
      try {
        const latest = canonicalMarkdown(await editor.value());
        if (latest !== text()) {
          text.set(latest);
          if (latest !== lastSaved) saveState.set(SAVE_STATE.dirty);
        }
        return latest;
      } catch {
        return text();
      }
    }
    if (richSession !== null) {
      const latest = canonicalMarkdown(richSession.getMarkdown());
      if (latest !== text()) {
        text.set(latest);
        if (latest !== lastSaved) saveState.set(SAVE_STATE.dirty);
      }
      return latest;
    }
    return text();
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

  // 加载门：noteGet 完成前不挂编辑器；失败/超时显示错误态，重试重新加载。
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
        // 未编辑不 dirty、不回写；首次保存时自然写新格式）。WYSIWYG 首次
        // 渲染时才真正 parse 成 ProseMirror 文档。
        const loaded = canonicalMarkdown(
          legacyWikilinksToMarkdown(normalizeNewlines(value)),
        );
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

  // 卸载：清 timer + WYSIWYG 会话监听；桌面切笔记/离开时脏数据尽力 flush
  // （06 §2.3「unmount 存快照」）。关闭按钮路径已先 saveNow；这里是「换 key
  // 重建」等直接卸载的兜底。
  effect(() => () => {
    disposed = true;
    clearSaveTimer();
    clearCandidateTimer();
    clearLoadTimer();
    // flush 先于 detachRich：currentContent() 需要活着的 session 取最新快照。
    flushOnUnmount();
    detachRich();
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

  /** 卸载时尽力把未保存内容写回：先等在飞的 `persist` 落定（closeEditor 的
   *  flush 可能还在跑——不直接开写，否则会产生重复 noteCreate 竞态，旧快照
   *  反而盖住新内容）；再按 canonical 基线判断要不要补一次。WYSIWYG 快照
   *  直接 `getMarkdown()`（不读可能已拆的编辑器视图）。新笔记空内容不建；
   *  失败静默（页面已拆，无 UI 可报）。 */
  function flushOnUnmount(): void {
    const rs = richSession;
    const inSource = sourceMode();
    const id = currentId;
    void (async () => {
      // 等在飞 persist 收尾：它的快照可能落后于最新输入（post-check 在
      // disposed 时会跳过 lastSaved 更新），用落定后的 latest 再判。
      await chain.then(
        () => true,
        () => false,
      );
      const snapshot =
        !inSource && rs !== null ? rs.getMarkdown() : text();
      if (canonicalMarkdown(snapshot) === lastSaved) return;
      if (id === "" && snapshot.trim() === "") return;
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

  /** WYSIWYG 会话的脏标记：事务落地即标 dirty + 排防抖保存（不做当次序列化；
   *  19k 字 getMarkdown≈22ms，逐键太贵；persist/readLatestText/模式切换时才
   *  序列化当次快照）。 */
  function handleRichUpdate(): void {
    if (disposed || sourceMode()) return;
    saveError.set("");
    saveState.set(SAVE_STATE.dirty);
    scheduleSave();
  }

  /** WYSIWYG 选区变化：标签命中只看「选中文本与标签全等」（`[[` 候选本轮不接，
   *  不用 textBefore 前缀路径）。 */
  function handleRichSelection(selection: RichSelectionJSON): void {
    if (richSession === null) return;
    const anchor = selection.anchor ?? 0;
    const head = selection.head ?? anchor;
    const from = Math.min(anchor, head);
    const to = Math.max(anchor, head);
    if (from === to) {
      selectionHits.set([]);
      return;
    }
    const selected = richSession.textBetween(from, to).trim();
    selectionHits.set(
      selected === "" ? [] : tags().filter((tag) => tag === selected),
    );
  }

  /** 惰性建立 WYSIWYG 会话（视图 thunk 在 `!sourceMode()` 时调用；同一会话在
   *  一次 WYSIWYG 存续期内复用）。内容取「当前 Markdown 快照」：首次 =
   *  loadedText/text（含 legacy 归一），源码模式切回时 = 源码编辑后的文本。
   *  会话建立后 bump `richEpoch`，由下面的 effect 挂监听。 */
  function ensureRichSession(): RichEditorSession {
    if (richSession === null) {
      const session = createNoteRichSession(text());
      richSession = session;
      props.onRichSession?.(session);
      richEpoch.update((n) => n + 1);
    }
    return richSession;
  }

  /** WYSIWYG 会话监听挂载点：随 `richEpoch` 重建——`session.on()` 的返回停止
   *  函数绑在「调用它的响应式作用域」上，render thunk 重跑会把监听连带销毁；
   *  effect 的作用域在 epoch 变化前稳定，因此监听放这里。 */
  effect(() => {
    richEpoch();
    const session = richSession;
    if (session === null) return;
    const stopUpdate = session.on("update", () => handleRichUpdate());
    const stopSel = session.on("selectionUpdate", () => {
      if (richSession !== null) handleRichSelection(richSession.selection);
    });
    return () => {
      stopUpdate();
      stopSel();
    };
  });

  /** 拆 WYSIWYG 会话：弃引用（不 dispose——GC 收；dispose 会赶在
   *  正在卸载的视图解绑之前让 Rust 端报错）。监听由 richEpoch effect 的
   *  cleanup 在视图重建时释放（render thunk 会先跑 ensureRichSession 建
   *  新会话再 bump epoch——effect 清理旧监听）。 */
  function detachRich(): void {
    richSession = null;
  }

  /** 切到源码模式：先经 `currentContent()` 取最新 Markdown（归一到 canonical，
   *  与 lastSaved 同口径——getMarkdown 可能多尾随 \n，raw 放进 text() 会让
   *  关闭比较多吃一次 persist 循环），再拆 WYSIWYG 会话并翻开 `sourceMode`。 */
  function enterSourceMode(): void {
    const latest = canonicalMarkdown(currentContent());
    detachRich();
    if (latest !== text()) text.set(latest);
    setCandidates([]);
    sourceMode.set(true);
  }

  /** 切回 WYSIWYG：源码 `Editor.value()` 取最新文本（等价于 onChange 的信号值，
   *  但关闭路径不依赖信号时序），再拆源码引用让 thunk 重建会话。 */
  async function exitSourceMode(): Promise<void> {
    await readLatestText();
    sourceMode.set(false);
  }

  function toggleSourceMode(): void {
    if (sourceMode()) void exitSourceMode();
    else enterSourceMode();
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

  /** 点选候选：替换已输入的 `[[prefix`（一步撤销，修 01 R5），
   *  插入 `[title](cardmind://note/id) `（P4-2 新存储格式）。仅源码模式。 */
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
    sourceMode,
    metrics,
    setEditor,
    ensureRichSession,
    retrySave,
    closeEditor,
    setCandidates,
    toggleSourceMode,
    handleChange,
    handleSelection,
    handleBlur,
    handleFocus,
    acceptCandidate,
    saveStateColor,
  };
}
