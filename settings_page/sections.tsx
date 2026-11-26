// 设置页区块组件（自 settings_page.tsx 纯结构拆出，JSX 逐字保留）。
import { Text, View, type JSX } from "nsh";
import { colors, layout, radii, spacing, typography } from "../theme";
import { switchTrack } from "./constants";

// ─── 区块组件 ────────────────────────────────────────────────────────────────

export function SectionTitle(props: { text: string }): JSX.Element {
  return (
    <Text
      style={{
        fontSize: typography.titleMedium.fontSize,
        lineHeight: typography.titleMedium.lineHeight,
        fontWeight: "600",
        color: colors.ink,
      }}
    >
      {props.text}
    </Text>
  );
}

/** 设置项行：标题 + 副标题 + 尾部控件（48 最小高，hairline 底部分隔）。 */
export function SettingRow(props: {
  title: string;
  subtitle?: string;
  trailing?: JSX.Element;
}): JSX.Element {
  return (
    <View
      style={{
        minHeight: layout.mobileTouchTarget,
        flexDirection: "row",
        alignItems: "center",
        paddingVertical: spacing.sm,
        borderBottomWidth: 1,
        borderBottomColor: colors.border,
        gap: spacing.md,
      }}
    >
      <View style={{ flex: 1 }}>
        <Text
          style={{
            fontSize: typography.bodyMedium.fontSize,
            lineHeight: typography.bodyMedium.lineHeight,
            color: colors.ink,
            fontWeight: "600",
          }}
        >
          {props.title}
        </Text>
        <If when={props.subtitle !== undefined}>
          <Text
            style={{
              fontSize: typography.bodyMedium.fontSize - 3,
              color: colors.mutedInk,
              marginTop: spacing.xs,
            }}
          >
            {props.subtitle ?? ""}
          </Text>
        </If>
      </View>
      <If when={props.trailing !== undefined}>{props.trailing}</If>
    </View>
  );
}

/** 同步开关：自绘轨道 + 滑块（role="switch"，命中区 48 行高）。 */
export function SyncSwitch(props: {
  value: () => boolean;
  onToggle: () => void;
}): JSX.Element {
  const on = props.value;
  return (
    <View
      onPress={props.onToggle}
      role="switch"
      accessibilityLabel="同步"
      accessibilityState={{ checked: on() }}
      style={{
        width: layout.mobileTouchTarget,
        height: layout.mobileTouchTarget,
        alignItems: "center",
        justifyContent: "center",
        borderRadius: radii.md,
      }}
    >
      <View
        style={{
          width: switchTrack.width,
          height: switchTrack.height,
          borderRadius: switchTrack.height / 2,
          backgroundColor: on() ? colors.accent : colors.border,
          justifyContent: "center",
          padding: (switchTrack.height - switchTrack.knob) / 2,
        }}
      >
        <View
          style={{
            width: switchTrack.knob,
            height: switchTrack.knob,
            borderRadius: switchTrack.knob / 2,
            backgroundColor: colors.surfaceRaised,
            alignSelf: on() ? "flex-end" : "flex-start",
          }}
        />
      </View>
    </View>
  );
}
