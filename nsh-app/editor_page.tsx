// 编辑页（P2）：NSH 0.3.0 原生 `Editor` 做 Markdown 源编辑，替换 WebView + Tiptap。
//
// 数据流（06 §2.3）：
//   noteGet → markdown 原样 → Editor(defaultValue) → onChange(value) → 700ms 去抖
//   → generateNoteId（新笔记一次）→ noteCreate → noteUpdateMetadata → syncNotesToStore
// 取消的旧机制：WebView/postMessage/8s 桥、soft↔hard 换行与方括号转义归一化。
//
// 状态机（06 §2.2）：loading / ready / load-error / saving / saved / dirty / save-error。
// `Editor` 只在 ready 后挂载（修 01 R1：加载失败不得用空文档覆盖原内容）。
//
// 结构（P2-2b 纯结构拆分）：本文件仅保留页面根 `EditorPage`（控制器解构 +
// renderPreview/renderEditor/renderContent + 返回 JSX）与公共 API 的 re-export；
// 类型/常量/repository/加载态/控制器/桌面栏分别落在 `./editor_page/` 子模块。
// render 段 JSX 与交互逐字不变，控制器内声明按原顺序整体搬移（token 级一致；
// 唯一改写：`editor = ref` → `setEditor(ref)`，let 绑定无法经解构写回）。
import { Text, View, type JSX } from "nsh";
import { Editor, NavPage, TextView, type EditorRef } from "nsh/base";
import { CardMindIconButton, CardMindPrimaryButton, CardMindTag } from "./components";
import { goBack, openEditor, screenChrome } from "./navigation";
import { noteIdFromLinkUrl } from "./editor_text";
import { colors, layout, radii, spacing, typography } from "./theme";
import { createEditorController } from "./editor_page/controller";
import { EditorDesktopHeader, EditorLoadError, EditorLoading } from "./editor_page/loading";
import { COPY, PREVIEW_STYLES, SAVE_STATE } from "./editor_page/constants";
import type { EditorPageProps } from "./editor_page/types";

export type { EditorNoteRow, EditorPageProps, EditorRepository } from "./editor_page/types";
export { backendEditorRepository } from "./editor_page/repository";
export { DesktopEditorPane } from "./editor_page/desktop_pane";

/** 编辑区（`Editor` + 预览切换 + 候选行 + 标签行 + 保存态）。
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
  } = createEditorController(props);

  /** 预览面板（只读 TextView）。笔记链接是标准 `[alias](cardmind://note/id)`：
   *  内建 link 渲染（PREVIEW_STYLES.link 近 chip 外观）；按下经 `onLinkPress`
   *  解析 id 后走 `props.onNavigateNote`（默认 openEditor；桌面内嵌换选中）。 */
  function renderPreview(): JSX.Element {
    const navigate = props.onNavigateNote ?? openEditor;
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
          styles={PREVIEW_STYLES}
          selectable
          onLinkPress={({ url }) => {
            const noteId = noteIdFromLinkUrl(url);
            if (noteId !== null) navigate(noteId);
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
        accessibilityLabel={COPY.editorLabel}
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
