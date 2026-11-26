// CardMind 组件库 — 同步状态（P2-5 自 components.tsx 纯结构拆出，声明逐字未改）。
import type { JSX } from "nsh";
import { Text, View } from "nsh";
import { colors, spacing } from "../theme";
import { statusDotSize, tagFontSize } from "./constants";

/** 同步状态：7px 圆点 + 12px 状态字；stale（>24h 未同步）时圆点换 stale 色
 *  并配「长时间未同步」文字（颜色不作唯一状态指示：圆点 + 文字双线索）。
 *  对照 CardMindSyncStatus。 */
export function CardMindSyncStatus(props: {
  label?: string;
  pendingCount?: number;
  stale?: boolean;
}): JSX.Element {
  const pending = () => props.pendingCount ?? 0;
  const text = () => {
    if (props.stale) {
      return pending() > 0 ? `长时间未同步 · ${pending()} 篇待同步` : "长时间未同步";
    }
    return pending() > 0 ? `${pending()} 篇待同步` : (props.label ?? "本地已就绪");
  };
  return (
    <View style={{ flexDirection: "row", alignItems: "center" }}>
      <View
        style={{
          width: statusDotSize,
          height: statusDotSize,
          borderRadius: statusDotSize / 2,
          backgroundColor: props.stale ? colors.stale : colors.accent,
        }}
      />
      <View style={{ width: spacing.sm }} />
      <Text
        style={{
          color: colors.mutedInk,
          fontSize: tagFontSize.compact,
          fontWeight: "500",
        }}
      >
        {text()}
      </Text>
    </View>
  );
}
