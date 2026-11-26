// CardMind 组件库 — 空态（P2-5 自 components.tsx 纯结构拆出，声明逐字未改）。
import type { JSX } from "nsh";
import { Text, View } from "nsh";
import { colors, spacing, typography } from "../theme";
import { emptyIconSize, emptyStateMaxWidth } from "./constants";
import { Glyph } from "./glyph";
import type { IconGlyph } from "./types";

/** 空态：居中，最大宽 320，图标占位 + titleMedium 标题 + mutedInk 正文。
 *  对照 CardMindEmptyState（ConstrainedBox 320 + padding xl + icon 42）。 */
export function CardMindEmptyState(props: {
  icon?: IconGlyph;
  title: string;
  message: string;
}): JSX.Element {
  return (
    <View
      style={{
        flex: 1,
        alignItems: "center",
        justifyContent: "center",
        padding: spacing.xl,
      }}
    >
      <View style={{ maxWidth: emptyStateMaxWidth, alignItems: "center" }}>
        <Glyph name={props.icon ?? "notes"} size={emptyIconSize} tint={colors.border} />
        <View style={{ height: spacing.lg }} />
        <Text
          style={{
            fontSize: typography.titleMedium.fontSize,
            lineHeight: typography.titleMedium.lineHeight,
            fontWeight: "600",
            color: colors.ink,
            textAlign: "center",
          }}
        >
          {props.title}
        </Text>
        <View style={{ height: spacing.sm }} />
        <Text
          style={{
            fontSize: typography.bodyMedium.fontSize,
            lineHeight: typography.bodyMedium.lineHeight,
            color: colors.mutedInk,
            textAlign: "center",
          }}
        >
          {props.message}
        </Text>
      </View>
    </View>
  );
}
