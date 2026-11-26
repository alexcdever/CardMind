// CardMind 组件库 — 按钮（P2-5 自 components.tsx 纯结构拆出，声明逐字未改）。
import type { JSX } from "nsh";
import { Text, View } from "nsh";
import { colors, layout, radii, spacing, typography } from "../theme";
import { disabledOpacity, glyphSize } from "./constants";
import { Glyph } from "./glyph";
import type { IconGlyph } from "./types";

/** 主按钮：accent 底 + 白字，48 高，lg 水平内边距，md 圆角。
 *  对照 CardMindPrimaryButton（FilledButton.icon + minimumSize 高 48 +
 *  padding horizontal lg + disabled 底 border 色）。 */
export function CardMindPrimaryButton(props: {
  label: string;
  icon?: IconGlyph;
  onPress?: () => void;
  expanded?: boolean;
  busy?: boolean;
  disabled?: boolean;
}): JSX.Element {
  const disabled = () => props.disabled === true || props.onPress === undefined;
  return (
    <View
      onPress={props.onPress}
      disabled={disabled()}
      role="button"
      accessibilityLabel={props.label}
      accessibilityState={{ disabled: disabled() }}
      style={{
        height: layout.mobileTouchTarget,
        minWidth: layout.mobileTouchTarget,
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "center",
        gap: spacing.sm,
        paddingHorizontal: spacing.lg,
        borderRadius: radii.md,
        backgroundColor: disabled() ? colors.border : colors.accent,
        opacity: disabled() ? disabledOpacity : 1,
        ...(props.expanded ? { alignSelf: "stretch" as const } : {}),
      }}
    >
      <If when={props.busy === true}>
        {/* busy 态：icon 槽位换占位进度圈（对照 SizedBox 18×18 进度环） */}
        <View
          style={{
            width: glyphSize.md,
            height: glyphSize.md,
            borderRadius: glyphSize.md / 2,
            borderWidth: 2,
            borderColor: colors.surfaceRaised,
            borderTopColor: colors.accent,
          }}
        />
      </If>
      <If when={props.busy !== true && props.icon !== undefined}>
        <Glyph name={props.icon ?? "add"} size={glyphSize.md} tint={colors.surfaceRaised} />
      </If>
      <Text
        style={{
          fontSize: typography.bodyMedium.fontSize,
          lineHeight: typography.bodyMedium.lineHeight,
          fontWeight: "600",
          color: colors.surfaceRaised,
        }}
      >
        {props.label}
      </Text>
    </View>
  );
}

/** 图标按钮：48×48 命中区，md 圆角；selected 时 accent 色 + 低透明底。
 *  对照 CardMindIconButton（IconButton fixedSize/minimumSize 48×48）。 */
export function CardMindIconButton(props: {
  icon: IconGlyph;
  tooltip: string;
  onPress?: () => void;
  selected?: boolean;
  busy?: boolean;
}): JSX.Element {
  const disabled = () => props.onPress === undefined;
  const tint = () => (props.selected ? colors.accent : colors.mutedInk);
  return (
    <View
      onPress={props.onPress}
      disabled={disabled()}
      role="button"
      accessibilityLabel={props.tooltip}
      accessibilityState={{ selected: props.selected === true, disabled: disabled() }}
      style={{
        width: layout.mobileTouchTarget,
        height: layout.mobileTouchTarget,
        alignItems: "center",
        justifyContent: "center",
        borderRadius: radii.md,
        backgroundColor: props.selected ? colors.surfaceLow : "transparent",
        opacity: disabled() ? disabledOpacity : 1,
      }}
    >
      <If when={props.busy === true}>
        <View
          style={{
            width: glyphSize.md,
            height: glyphSize.md,
            borderRadius: glyphSize.md / 2,
            borderWidth: 2,
            borderColor: tint(),
            borderTopColor: colors.border,
          }}
        />
      </If>
      <If when={props.busy !== true}>
        <Glyph name={props.icon} size={glyphSize.lg - 1} tint={tint()} />
      </If>
    </View>
  );
}
