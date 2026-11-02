// CardMind TSX 组件库（施工方案 2.1）：对照 lib/ui/design_system/cardmind_widgets.dart
// 移植 6 个组件，另补「列表项 / 确认对话框」两个规范组件。
//
// 令牌纪律：所有颜色 / 间距 / 圆角 / 触摸目标全部来自 ./theme，禁止裸值。
//
// 按压反馈：View 的 `underlayColor`（nsh 原生按压高亮，见 nsh examples
// gallery/ui.tsx 的 Row）——按下变色但不改布局尺寸，不会引起内容抖动。
import type { JSX, ViewStyle } from "nsh";
import { Text, View } from "nsh";
import { Dialog, Input } from "nsh/base";
import { colors, layout, radii, spacing, typography } from "./theme";

/** 小写图标集：占位 glyph 用线性几何图形而非 emoji（规范：不用 emoji 当图标）。 */
export type IconGlyph =
  | "add"
  | "back"
  | "close"
  | "delete"
  | "devices"
  | "edit"
  | "notes"
  | "restore"
  | "search"
  | "settings"
  | "tag"
  | "trash";

/** 图标的视觉尺寸（px）。18/19/20 档对照 Flutter 侧 Icon size；非触摸目标。 */
const glyphSize = {
  md: 18,
  lg: 20,
} as const;

/** 同步状态圆点直径（px，对照 Flutter Container width/height: 7）。 */
const statusDotSize = 7;
/** 空态图标占位尺寸（px，对照 Flutter Icon size: 42）。 */
const emptyIconSize = 42;
/** 搜索框垂直内边距（px，对照 contentPadding vertical: mobile 12 / desktop 10）。 */
const searchPaddingY = { mobile: 12, desktop: 10 } as const;
/** 标签文字字号（px，对照 fontSize: comfortable 13 / default 12）。 */
const tagFontSize = { comfortable: 13, compact: 12 } as const;
/** 标签垂直内边距（px，对照 top/bottom: comfortable 14 / default 4=spacing.xs）。 */
const tagPaddingY = { comfortable: 14, compact: spacing.xs } as const;
/** 标签删除图标视觉尺寸（px，对照 size: comfortable 16 / default 14）。 */
const tagDeleteGlyph = { comfortable: 16, compact: 14 } as const;
/** 空态说明区最大宽度（px，对照 ConstrainedBox maxWidth: 320）。 */
const emptyStateMaxWidth = 320;
/** 对话框内容宽度（px，高对比模态框的固定栏宽）。 */
const dialogWidth = 340;
/** 标签垂直内边距（px，对照 top/bottom: comfortable 14 / default 4=spacing.xs）。 */
const activeStripeWidth = 2;

/** disabled 态透明度（对照 nsh 惯例 `disabled:opacity-40`，即 0.4）。 */
const disabledOpacity = 0.4;

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
        onChange={props.onChanged}
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

/** 危险确认对话框：高对比模态，danger 确认钮（对照 style-guide「确认对话框：
 *  删除/彻底删除/解除配对用高对比模态框，确认按钮 danger-red」）。 */
export function CardMindConfirmDialog(props: {
  visible?: boolean;
  title: string;
  message: string;
  confirmLabel: string;
  cancelLabel?: string;
  danger?: boolean;
  onConfirm?: () => void;
  onCancel?: () => void;
}): JSX.Element {
  return (
    <Dialog open={props.visible !== false}>
      <View
        style={{
          flex: 1,
          alignItems: "center",
          justifyContent: "center",
          padding: spacing.xl,
          backgroundColor: colors.paper,
        }}
      >
        <View
          style={{
            width: dialogWidth,
            borderRadius: radii.lg,
            borderWidth: 1,
            borderColor: colors.border,
            backgroundColor: colors.surfaceRaised,
            padding: spacing.lg,
          }}
        >
          <Text
            style={{
              fontSize: typography.titleMedium.fontSize,
              lineHeight: typography.titleMedium.lineHeight,
              fontWeight: "600",
              color: colors.ink,
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
            }}
          >
            {props.message}
          </Text>
          <View style={{ height: spacing.lg }} />
          <View style={{ flexDirection: "row", justifyContent: "flex-end", gap: spacing.sm }}>
            <View
              onPress={props.onCancel}
              role="button"
              accessibilityLabel={props.cancelLabel ?? "取消"}
              style={{
                minHeight: layout.mobileTouchTarget,
                paddingHorizontal: spacing.lg,
                alignItems: "center",
                justifyContent: "center",
                borderRadius: radii.md,
                borderWidth: 1,
                borderColor: colors.border,
              }}
            >
              <Text style={{ color: colors.mutedInk, fontSize: typography.bodyMedium.fontSize }}>
                {props.cancelLabel ?? "取消"}
              </Text>
            </View>
            <View
              onPress={props.onConfirm}
              role="button"
              accessibilityLabel={props.confirmLabel}
              style={{
                minHeight: layout.mobileTouchTarget,
                paddingHorizontal: spacing.lg,
                alignItems: "center",
                justifyContent: "center",
                borderRadius: radii.md,
                backgroundColor: props.danger !== false ? colors.danger : colors.accent,
              }}
            >
              <Text
                style={{
                  color: colors.surfaceRaised,
                  fontSize: typography.bodyMedium.fontSize,
                  fontWeight: "600",
                }}
              >
                {props.confirmLabel}
              </Text>
            </View>
          </View>
        </View>
      </View>
    </Dialog>
  );
}

/** 供页面复用的面板底色集合（paper 画布 / surfaceLow 侧栏 / surfaceRaised 卡片）。 */
export const panel = {
  canvas: colors.paper,
  sidebar: colors.surfaceLow,
  card: colors.surfaceRaised,
} as const satisfies Record<string, string>;

/** 供 JSX style 展开的类型别名（保持与 nsh ViewStyle 一致）。 */
export type { ViewStyle };