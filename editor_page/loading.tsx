// 编辑页加载/错误态与桌面应用内顶栏（自 editor_page.tsx 纯结构拆出，逐字保留）。
import { Text, View, type JSX } from "nsh";
import { CardMindEmptyState, CardMindIconButton, CardMindPrimaryButton } from "../components";
import { colors, layout, spacing, typography } from "../theme";
import { COPY, LOADING_SPINNER } from "./constants";

/** 加载中：居中占位（不是一行裸文字，也不是空文档）。 */
export function EditorLoading(): JSX.Element {
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
export function EditorLoadError(props: {
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
export function EditorDesktopHeader(props: { onBack: () => void }): JSX.Element {
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
