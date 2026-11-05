// CardMind 组件库 — 标签（P2-5 自 components.tsx 纯结构拆出，声明逐字未改）。
import type { JSX } from "nsh";
import { Text, View } from "nsh";
import { colors, layout, radii, spacing } from "../theme";
import { tagDeleteGlyph, tagFontSize, tagPaddingY } from "./constants";
import { Glyph } from "./glyph";

/** 标签：sm 水平内边距 + xs 垂直内边距（comfortable 时 14）+ md 圆角；
 *  selected 时 accent 边框/文字 + 低透明 accent 底。可挂删除 ×（danger 色）。
 *  对照 CardMindTag。 */
export function CardMindTag(props: {
  label: string;
  selected?: boolean;
  onTap?: () => void;
  onDelete?: () => void;
  showDelete?: boolean;
  comfortable?: boolean;
  /** 测试/自动化锚点（`nsh test` 用 `id:<testID>` 选候选 chip）。 */
  testID?: string;
  /** 测试/自动化锚点：内层 Text 的 testID（`spanStyle` 只能按文本节点 id 取样式）。 */
  textTestID?: string;
}): JSX.Element {
  const comfortable = () => props.comfortable === true;
  const showDeleteIcon = () => props.showDelete === true && props.onDelete !== undefined;
  return (
    <View
      testID={props.testID}
      onPress={props.onTap}
      role={props.onTap ? "button" : undefined}
      accessibilityLabel={props.label}
      accessibilityState={{ selected: props.selected === true }}
      style={{
        flexDirection: "row",
        alignItems: "center",
        minHeight: comfortable() ? layout.mobileTouchTarget : undefined,
        // 单字符标签（如「工」）也满足 ≥48dp 触摸宽度（comfortable 档）。
        minWidth: comfortable() ? layout.mobileTouchTarget : undefined,
        paddingLeft: spacing.sm,
        paddingRight: showDeleteIcon() ? radii.sm : spacing.sm,
        paddingVertical: comfortable() ? tagPaddingY.comfortable : tagPaddingY.compact,
        borderRadius: radii.md,
        borderWidth: 1,
        borderColor: props.selected ? colors.accent : colors.border,
        backgroundColor: colors.surfaceLow,
      }}
    >
      <Text
        style={{
          color: props.selected ? colors.accent : colors.mutedInk,
          fontSize: comfortable() ? tagFontSize.comfortable : tagFontSize.compact,
          fontWeight: "500",
        }}
      >
        {/* 嵌套 Text 让 testID 落在文本 span 上（nsh test 的 spanStyle 只能按 span 的 id 取样式）。 */}
        <Text testID={props.textTestID}>{props.label}</Text>
      </Text>
      <If when={showDeleteIcon()}>
        <View
          onPress={props.onDelete}
          role="button"
          accessibilityLabel={`删除标签 ${props.label}`}
          style={{
            marginLeft: radii.sm,
            width: tagDeleteGlyph.comfortable + spacing.xs,
            height: tagDeleteGlyph.comfortable + spacing.xs,
            alignItems: "center",
            justifyContent: "center",
          }}
        >
          <Glyph name="close" size={tagDeleteGlyph.compact} tint={colors.danger} />
        </View>
      </If>
    </View>
  );
}
