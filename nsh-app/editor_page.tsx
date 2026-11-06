// 编辑页（P4-3a）：编辑态换成 NSH 0.4.0 `RichEditor`（WYSIWYG）；原 `Editor`
// （Markdown 源码）保留为可切换的「源码模式」。
//
// 数据流（沿用 P2 骨架，序列化口径换成 getMarkdown）：
//   noteGet → legacyWikilinksToMarkdown(normalizeNewlines(markdown))
//   → WYSIWYG：createNoteRichSession(md) → session.on("update") → 700ms 去抖
//   → 保存时 session.getMarkdown() → generateNoteId（新笔记一次）→ noteCreate
//   → noteUpdateMetadata → syncNotesToStore
//   源码模式：Editor(defaultValue=最新 md) → onChange(value) → 同一去抖路径。
// 取消的旧机制：WebView/postMessage/8s 桥、soft↔hard 换行与方括号转义归一化；
// P4-3a 起 `TextView` 预览面板移除（WYSIWYG 即排版视图，预览无意义）。
//
// 状态机（06 §2.2）：loading / ready / load-error / saving / saved / dirty / save-error。
// 编辑器只在 ready 后挂载（修 01 R1：加载失败不得用空文档覆盖原内容）。
//
// 结构（P2-2b 纯结构拆分）：本文件仅保留页面根 `EditorPage`（控制器解构 +
// renderSource/renderRich/renderContent + 返回 JSX）与公共 API 的 re-export；
// 类型/常量/repository/加载态/控制器/桌面栏/WYSIWYG 接缝分别落在
// `./editor_page/` 子模块。
import { Text, View, type JSX } from "nsh";
import { Editor, NavPage, RichEditor, type EditorRef } from "nsh/base";
import { CardMindIconButton, CardMindPrimaryButton, CardMindTag } from "./components";
import { goBack, screenChrome } from "./navigation";
import { colors, layout, radii, spacing, typography } from "./theme";
import { createEditorController } from "./editor_page/controller";
import { EditorDesktopHeader, EditorLoadError, EditorLoading } from "./editor_page/loading";
import { COPY, SAVE_STATE } from "./editor_page/constants";
import { richEditorStyles } from "./editor_page/rich";
import type { EditorPageProps } from "./editor_page/types";

export type { EditorNoteRow, EditorPageProps, EditorRepository } from "./editor_page/types";
export { backendEditorRepository } from "./editor_page/repository";
export { DesktopEditorPane } from "./editor_page/desktop_pane";

/** 编辑区（WYSIWYG `RichEditor` + 源码切换 + 候选行 + 标签行 + 保存态）。
 *  `embedded`：桌面第三栏内嵌时不套 NavPage/返回键。 */
export function EditorPage(props: EditorPageProps): JSX.Element {
  const {
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
  } = createEditorController(props);

  /** 源码面板（原 `Editor`，显示 Markdown 原文）。`[[` 候选、标签高亮、
   *  撤销栈都按原 Editor 语义工作。 */
  function renderSource(): JSX.Element {
    return (
      <Editor
        ref={(ref: EditorRef) => {
          setEditor(ref);
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
        accessibilityLabel={COPY.sourceLabel}
        fontSize={metrics().fontSize}
        lineHeight={metrics().lineHeight}
        style={{
          flex: 1,
          backgroundColor: colors.paper,
          borderRadius: radii.md,
        }}
        onChange={({ value }) => handleChange(value)}
        onSelectionChange={({ selections }) =>
          handleSelection(selections)
        }
        onBlur={handleBlur}
        onFocus={handleFocus}
      />
    );
  }

  /** WYSIWYG 面板（`RichEditor`）。会话由 `ensureRichSession()` 惰性建立并
   *  在一次 WYSIWYG 存续期内复用；切走源码再切回时整体卸载/重挂（`editor`
   *  prop 只在视图创建时取一次），会话随之以最新 Markdown 重建——撤销栈随
   *  模式切换重置（沿用旧预览切换口径）。`style={flex:1}` 是 headless 挂载的
   *  必要条件（0.4.0 实测）。 */
  function renderRich(): JSX.Element {
    return (
      <RichEditor
        testID="rich-editor"
        editor={ensureRichSession()}
        placeholder={COPY.placeholder}
        autoFocus
        accessibilityLabel={COPY.richLabel}
        styles={richEditorStyles(metrics())}
        style={{
          flex: 1,
          backgroundColor: colors.paper,
          borderRadius: radii.md,
        }}
        onFocus={handleFocus}
        onBlur={handleBlur}
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
              {/* 源码/排版切换：文字 + 状态（颜色不作唯一指示）；触摸目标 ≥48dp。 */}
              <View
                testID="source-toggle"
                role="button"
                accessibilityLabel={sourceMode() ? COPY.richMode : COPY.sourceMode}
                accessibilityState={{ selected: sourceMode() }}
                onPress={toggleSourceMode}
                style={{
                  minHeight: layout.mobileTouchTarget,
                  minWidth: layout.mobileTouchTarget,
                  alignItems: "center",
                  justifyContent: "center",
                  paddingHorizontal: spacing.md,
                  borderRadius: radii.md,
                  borderWidth: 1,
                  borderColor: sourceMode() ? colors.accent : colors.border,
                  backgroundColor: sourceMode() ? colors.surfaceLow : "transparent",
                }}
              >
                <Text
                  style={{
                    color: sourceMode() ? colors.accent : colors.mutedInk,
                    fontSize: typography.labelLarge.fontSize,
                    fontWeight: "600",
                  }}
                >
                  {sourceMode() ? COPY.richMode : COPY.sourceMode}
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
                  style={{
                    flex: 1,
                    numberOfLines: 2,
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
            {/* 编辑主体（响应式 thunk）：默认 WYSIWYG；源码模式时 RichEditor
                卸载、Editor 以最新 Markdown 重挂载（两态撤销栈各自独立，随
                切换重置——沿用旧「预览切回源码字节不变」的口径）。 */}
            {() => (sourceMode() ? renderSource() : renderRich())}
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
