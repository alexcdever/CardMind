// 设备页区块组件（自 devices_page.tsx 纯结构拆出，JSX 逐字保留）。
import { Text, View, type JSX } from "nsh";
import { Input } from "nsh/base";
import { CardMindIconButton, CardMindListItem, Glyph, panel } from "../components";
import { colors, layout, radii, spacing, typography } from "../theme";
import { localIconSize } from "./constants";
import type { PairedDeviceDto } from "./types";
import {
  cancelEditName,
  checkConnectivity,
  connectivity,
  deviceId,
  deviceName,
  editingName,
  isOnline,
  localAddrs,
  nameDraft,
  requestUnpair,
  relativeTime,
  saveDeviceName,
  savingName,
  startEditName,
  type Connectivity,
} from "./state";

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

/** 面板容器：surfaceRaised 卡 + border + md 圆角。 */
export function Panel(props: { children?: JSX.Element | JSX.Element[] }): JSX.Element {
  return (
    <View
      style={{
        borderWidth: 1,
        borderColor: colors.border,
        borderRadius: radii.md,
        backgroundColor: panel.card,
        padding: spacing.lg,
        gap: spacing.sm,
      }}
    >
      {props.children}
    </View>
  );
}

/** 本机信息卡（对照 Dart _buildLocalInfo）：设备名 + 短 id + 地址数 + 改名钮。 */
export function LocalInfoCard(): JSX.Element {
  const shortId = () => {
    const id = deviceId();
    return id.length <= 8 ? id : `${id.slice(0, 8)}…`;
  };
  return (
    <View
      style={{
        flexDirection: "row",
        alignItems: "center",
        gap: spacing.md,
        padding: spacing.lg,
        borderRadius: radii.lg,
        backgroundColor: colors.surfaceLow,
      }}
    >
      <View
        style={{
          width: spacing.xxl + spacing.sm,
          height: spacing.xxl + spacing.sm,
          borderRadius: radii.md,
          backgroundColor: colors.accent,
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        <Glyph name="devices" size={localIconSize} tint={colors.surfaceRaised} />
      </View>
      <View style={{ flex: 1 }}>
        {() =>
          editingName() ? (
            <View style={{ gap: spacing.xs }}>
              <Input
                value={nameDraft()}
                onChange={({ value }) => nameDraft.set(value)}
                onSubmit={() => void saveDeviceName()}
                placeholder="设备名"
                accessibilityLabel="设备名"
                style={{
                  minHeight: layout.mobileTouchTarget,
                  fontSize: typography.bodyMedium.fontSize,
                  color: colors.ink,
                }}
              />
              <View style={{ flexDirection: "row", gap: spacing.xs }}>
                <CardMindIconButton
                  icon="close"
                  tooltip="取消"
                  onPress={cancelEditName}
                />
                <CardMindIconButton
                  icon="add"
                  tooltip="保存设备名"
                  onPress={() => void saveDeviceName()}
                  busy={savingName()}
                />
              </View>
            </View>
          ) : (
            <View>
              <Text
                style={{
                  fontSize: typography.bodyMedium.fontSize,
                  fontWeight: "600",
                  color: colors.ink,
                }}
              >
                {() => (deviceName().length > 0 ? deviceName() : "我的设备")}
              </Text>
              <Text
                style={{
                  fontSize: typography.bodyMedium.fontSize - 3,
                  color: colors.mutedInk,
                  marginTop: spacing.xs,
                }}
              >
                {() =>
                  `ID ${shortId()} · ${localAddrs().length} 个地址（配对时显示给其他设备）`
                }
              </Text>
            </View>
          )
        }
      </View>
      <If when={!editingName()}>
        <CardMindIconButton icon="edit" tooltip="修改设备名" onPress={startEditName} />
      </If>
    </View>
  );
}

/** 设备行尾连通检查按钮文案（对照 Dart checkLabel switch）。 */
export function checkLabel(c: Connectivity | undefined): string {
  if (c === undefined) return "测试连接";
  switch (c.kind) {
    case "checking":
      return "正在测试…";
    case "ok":
      return `连接可用 · ${c.latencyMs} ms`;
    case "failed":
      return "暂不可连接 · 重试";
  }
}

/** 已配对设备行（对照 Dart _buildDeviceItem）：名称 + 在线/离线 + 时间 +
 *  「测试连接」与「解除配对」按钮；离线/失败不只用颜色区分（有文字标签）。 */
export function DeviceRow(props: { device: () => PairedDeviceDto }): JSX.Element {
  const d = props.device;
  const online = () => isOnline(d());
  const check = () => connectivity()[d().peerId];
  return (
    <CardMindListItem
      title={d().name}
      subtitle={`${online() ? "在线" : "离线"} · 最近可连接：${relativeTime(d().lastSeen)} · 最近同步：${relativeTime(d().lastSyncAt)}`}
      trailing={
        <View style={{ alignItems: "flex-end", gap: spacing.xs }}>
          <View
            onPress={check()?.kind === "checking" ? undefined : () => void checkConnectivity(d())}
            role="button"
            accessibilityLabel={`${checkLabel(check())}，${d().name}`}
            accessibilityState={{ disabled: check()?.kind === "checking" }}
            style={{
              minHeight: layout.mobileTouchTarget,
              paddingHorizontal: spacing.md,
              alignItems: "center",
              justifyContent: "center",
              borderRadius: radii.md,
              opacity: check()?.kind === "checking" ? 0.4 : 1,
            }}
          >
            <Text
              style={{
                fontSize: typography.bodyMedium.fontSize - 3,
                color:
                  check()?.kind === "failed"
                    ? colors.danger
                    : check()?.kind === "ok"
                      ? colors.accent
                      : colors.mutedInk,
                fontWeight: "600",
              }}
            >
              {() => checkLabel(check())}
            </Text>
          </View>
          <View
            onPress={() => requestUnpair(d())}
            role="button"
            accessibilityLabel={`解除配对 ${d().name}`}
            style={{
              minHeight: layout.mobileTouchTarget,
              paddingHorizontal: spacing.md,
              alignItems: "center",
              justifyContent: "center",
              borderRadius: radii.md,
            }}
          >
            <Text
              style={{
                fontSize: typography.bodyMedium.fontSize - 3,
                color: colors.danger,
                fontWeight: "600",
              }}
            >
              解除配对
            </Text>
          </View>
        </View>
      }
    />
  );
}

// ─── 配对面板 ────────────────────────────────────────────────────────────────

/** 配对方式选择行（48 命中区 + 可 disabled）。 */
export function PairModeRow(props: {
  icon: "add" | "search" | "edit";
  title: string;
  subtitle: string;
  onPress?: () => void;
  disabled?: boolean;
}): JSX.Element {
  const disabled = () => props.disabled === true || props.onPress === undefined;
  return (
    <View
      onPress={disabled() ? undefined : props.onPress}
      role="button"
      accessibilityLabel={props.title}
      accessibilityState={{ disabled: disabled() }}
      style={{
        minHeight: layout.mobileTouchTarget,
        flexDirection: "row",
        alignItems: "center",
        gap: spacing.md,
        paddingVertical: spacing.sm,
        paddingHorizontal: spacing.md,
        borderRadius: radii.md,
        borderWidth: 1,
        borderColor: colors.border,
        opacity: disabled() ? 0.4 : 1,
      }}
    >
      <Glyph name={props.icon} size={20} tint={disabled() ? colors.mutedInk : colors.accent} />
      <View style={{ flex: 1 }}>
        <Text
          style={{
            fontSize: typography.bodyMedium.fontSize,
            fontWeight: "600",
            color: colors.ink,
          }}
        >
          {props.title}
        </Text>
        <Text
          style={{
            fontSize: typography.bodyMedium.fontSize - 3,
            color: colors.mutedInk,
            marginTop: spacing.xs,
          }}
        >
          {props.subtitle}
        </Text>
      </View>
    </View>
  );
}
