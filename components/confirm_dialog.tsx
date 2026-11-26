// CardMind 组件库 — 危险确认对话框（P2-5 自 components.tsx 纯结构拆出，声明逐字未改）。
import type { JSX } from "nsh";
import { Text, View } from "nsh";
import { Dialog } from "nsh/base";
import { colors, layout, radii, spacing, typography } from "../theme";
import { dialogWidth } from "./constants";

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
