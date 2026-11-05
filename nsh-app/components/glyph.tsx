// CardMind 组件库 — Glyph 几何图标（P2-5 自 components.tsx 纯结构拆出，声明逐字未改）。
import type { JSX } from "nsh";
import { View } from "nsh";
import { colors, radii } from "../theme";
import { glyphSize } from "./constants";
import type { IconGlyph } from "./types";

/**
 * 极简几何图标：一个 View 画线性风格占位（描边方块），不用 emoji。
 * `glyph` 决定画什么；全部为 1.5–2px 描边风的简单形状。
 */
export function Glyph(props: {
  name: IconGlyph;
  size?: number;
  tint?: string;
}): JSX.Element {
  const size = props.size ?? glyphSize.md;
  const tint = props.tint ?? colors.mutedInk;
  const stroke = 2;
  switch (props.name) {
    case "add":
      // 十字：两条 2px 描边线。
      return (
        <View style={{ width: size, height: size, alignItems: "center", justifyContent: "center" }}>
          <View style={{ position: "absolute", width: size, height: stroke, backgroundColor: tint }} />
          <View style={{ position: "absolute", width: stroke, height: size, backgroundColor: tint }} />
        </View>
      );
    case "back":
      // 左箭头：旋转的折角（两条边）。
      return (
        <View
          style={{
            width: size,
            height: size,
            borderLeftWidth: stroke,
            borderBottomWidth: stroke,
            borderColor: tint,
            transform: [{ rotate: "45deg" }],
            marginLeft: size / 4,
          }}
        />
      );
    case "close":
    case "delete":
      // 叉：两条旋转 45° 的线。
      return (
        <View style={{ width: size, height: size, alignItems: "center", justifyContent: "center" }}>
          <View
            style={{
              position: "absolute",
              width: size,
              height: stroke,
              backgroundColor: tint,
              transform: [{ rotate: "45deg" }],
            }}
          />
          <View
            style={{
              position: "absolute",
              width: size,
              height: stroke,
              backgroundColor: tint,
              transform: [{ rotate: "-45deg" }],
            }}
          />
        </View>
      );
    case "search":
      // 圆 + 短柄。
      return (
        <View style={{ width: size, height: size }}>
          <View
            style={{
              width: size * 0.62,
              height: size * 0.62,
              borderRadius: size / 2,
              borderWidth: stroke,
              borderColor: tint,
            }}
          />
          <View
            style={{
              position: "absolute",
              right: 0,
              bottom: 0,
              width: size * 0.4,
              height: stroke,
              backgroundColor: tint,
              transform: [{ rotate: "45deg" }],
            }}
          />
        </View>
      );
    case "tag":
      // 标签轮廓（菱形感）：旋转正方形。
      return (
        <View
          style={{
            width: size * 0.7,
            height: size * 0.7,
            borderWidth: stroke,
            borderColor: tint,
            transform: [{ rotate: "45deg" }],
          }}
        />
      );
    case "warning":
      // 错误/警告语义图标：竖条 + 圆点（感叹号），不用 emoji。
      return (
        <View style={{ width: size, height: size, alignItems: "center", justifyContent: "center" }}>
          <View
            style={{
              width: stroke,
              height: size * 0.55,
              backgroundColor: tint,
              borderRadius: stroke / 2,
            }}
          />
          <View
            style={{
              width: stroke,
              height: stroke,
              marginTop: size * 0.12,
              borderRadius: stroke / 2,
              backgroundColor: tint,
            }}
          />
        </View>
      );
    case "trash":
    case "restore":
    case "edit":
    case "devices":
    case "notes":
    case "settings":
    default:
      // 通用占位：描边方块（线性图标风）。
      return (
        <View
          style={{
            width: size,
            height: size,
            borderWidth: stroke,
            borderColor: tint,
            borderRadius: radii.sm,
          }}
        />
      );
  }
}
