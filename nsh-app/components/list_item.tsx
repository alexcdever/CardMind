// CardMind 组件库 — 列表项（P2-5 自 components.tsx 纯结构拆出，声明逐字未改）。
import type { JSX } from "nsh";
import { Text, View } from "nsh";
import { colors, layout, spacing, typography } from "../theme";
import { activeStripeWidth, tagFontSize } from "./constants";

/** 笔记/设备列表项：48 最小高、底部 hairline 分隔、选中加 2px 左 accent 线。
 *  列表项是施工 2.1「按钮/列表项/输入/空态/对话框」里的「列表项」；
 *  cardmind_widgets.dart 没有对应件，按 style-guide「笔记卡片：矩形 + 底部
 *  边框分隔线；激活时冷灰底或青色左强调线」新设计。 */
export function CardMindListItem(props: {
  title: string;
  subtitle?: string;
  selected?: boolean;
  onPress?: () => void;
  trailing?: JSX.Element;
}): JSX.Element {
  return (
    <View
      onPress={props.onPress}
      role="button"
      accessibilityState={{ selected: props.selected === true }}
      style={{
        minHeight: layout.mobileTouchTarget,
        flexDirection: "row",
        alignItems: "center",
        paddingLeft: props.selected ? spacing.lg - activeStripeWidth : spacing.lg,
        paddingRight: spacing.lg,
        paddingVertical: spacing.md,
        borderLeftWidth: props.selected ? activeStripeWidth : 0,
        borderLeftColor: colors.accent,
        borderBottomWidth: 1,
        borderBottomColor: colors.border,
        backgroundColor: props.selected ? colors.surfaceLow : "transparent",
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
              fontSize: tagFontSize.comfortable,
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
