// CardMind 组件库 — 搜索框（P2-5 自 components.tsx 纯结构拆出，声明逐字未改）。
import type { JSX } from "nsh";
import { View } from "nsh";
import { Input } from "nsh/base";
import { colors, layout, radii, spacing, typography } from "../theme";
import { glyphSize, searchPaddingY } from "./constants";
import { Glyph } from "./glyph";

/** 搜索框：完整边框容器 + 前缀搜索图标（48 命中区）+ 有内容时后缀清除钮。
 *  对照 CardMindSearchField（prefixIconConstraints / suffixIconConstraints 48）。 */
export function CardMindSearchField(props: {
  value: () => string;
  onChanged?: (text: string) => void;
  onClear?: () => void;
  mobile?: boolean;
  placeholder?: string;
}): JSX.Element {
  const hasText = () => props.value().length > 0;
  return (
    <View
      role="search"
      style={{
        flexDirection: "row",
        alignItems: "center",
        borderWidth: 1,
        borderColor: colors.border,
        borderRadius: radii.xl,
        backgroundColor: colors.surfaceRaised,
      }}
    >
      <View
        style={{
          width: layout.mobileTouchTarget,
          height: layout.mobileTouchTarget,
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        <Glyph name="search" size={glyphSize.lg} tint={colors.mutedInk} />
      </View>
      <Input
        value={props.value()}
        onChange={({ value }) => props.onChanged?.(value)}
        placeholder={props.placeholder ?? "搜索笔记"}
        accessibilityLabel="搜索笔记"
        style={{
          flex: 1,
          fontSize: props.mobile ? spacing.lg : typography.bodyMedium.fontSize,
          color: colors.ink,
          paddingVertical: props.mobile ? searchPaddingY.mobile : searchPaddingY.desktop,
        }}
      />
      <If when={hasText()}>
        <View
          onPress={props.onClear}
          role="button"
          accessibilityLabel="清除搜索"
          style={{
            width: layout.mobileTouchTarget,
            height: layout.mobileTouchTarget,
            alignItems: "center",
            justifyContent: "center",
            borderRadius: radii.md,
          }}
        >
          <Glyph name="close" size={glyphSize.md} tint={colors.mutedInk} />
        </View>
      </If>
    </View>
  );
}
