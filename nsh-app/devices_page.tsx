// 设备页入口（P2-2c 纯结构拆分）：仅保留 `DevicesPage`（从 state 解构 + 原 render 段）
// 与公共 API 的 re-export。类型/常量/状态与处理函数/区块组件/配对弹窗分别落在
// `./devices_page/` 子模块。render 段 JSX 与交互逐字不变；signals 仍是 state.ts 模块
// 顶层单例（单一创建点）。唯一改写：cleanup 里 `stopCountdown(); pairGeneration += 1;`
// 收进 state 的 `disposeDevicesPage()`（跨模块 let 写回接缝）。
import { cleanup, effect, Scroll, Text, View } from "nsh";
import type { JSX } from "nsh";
import {
  CardMindConfirmDialog,
  CardMindEmptyState,
  CardMindListItem,
  CardMindPrimaryButton,
} from "./components";
import { colors, layout, radii, spacing, typography } from "./theme";
import { DeviceRow, LocalInfoCard, Panel, SectionTitle } from "./devices_page/sections";
import { PairChooseSheet, PairEnterSheet, PairShowSheet } from "./devices_page/pair_sheets";
import * as devicesState from "./devices_page/state";

export type {
  DevicesSource,
  PairedDeviceDto,
  PairingCredentialDisplayDto,
  PairingRequestDto,
  PairingResultDto,
  PeerInfoDto,
} from "./devices_page/types";
export { setDevicesSource } from "./devices_page/state";

/**
 * 设备页：本机信息 + 「添加设备」+ 已配对列表 + 发现对端。
 *
 * `status` 插槽：调用方传入的状态面板（App.tsx 的 Phase 1 后端证据行）。
 */
export function DevicesPage(props: { status?: JSX.Element }): JSX.Element {
  const {
    loading,
    loadError,
    devices,
    actionMessage,
    pairSheet,
    unpairTarget,
    discovering,
    peersLoaded,
    peers,
    loadAllWithRetry,
    startBackgroundRefresh,
    disposeDevicesPage,
    refreshPeers,
    confirmUnpair,
    cancelUnpair,
  } = devicesState;
  effect(() => {
    void loadAllWithRetry();
  });
  // 后台周期刷新（在线状态）+ 倒计时定时器都在 cleanup 里释放。
  const stopRefresh = startBackgroundRefresh();
  cleanup(() => {
    stopRefresh();
    disposeDevicesPage();
  });
  return (
    <View style={{ flex: 1, backgroundColor: colors.paper }}>
      <Scroll style={{ flex: 1 }}>
        {() => (
          <View style={{ padding: spacing.lg, gap: spacing.lg }}>
            <LocalInfoCard />
            <CardMindPrimaryButton
              label="添加设备"
              icon="add"
              expanded
              onPress={() => pairSheet.set("choose")}
            />

            {/* 已配对设备 */}
            <View style={{ gap: spacing.sm }}>
              <SectionTitle text="已配对设备" />
              {() => {
                if (loading()) {
                  return (
                    <View
                      style={{
                        minHeight: layout.mobileTouchTarget,
                        alignItems: "center",
                        justifyContent: "center",
                      }}
                    >
                      <Text style={{ color: colors.mutedInk }}>加载中…</Text>
                    </View>
                  );
                }
                if (loadError() !== undefined) {
                  return (
                    <CardMindEmptyState
                      icon="devices"
                      title="设备页加载失败"
                      message={loadError() ?? ""}
                    />
                  );
                }
                if (devices().length === 0) {
                  return (
                    <CardMindEmptyState
                      icon="devices"
                      title="还没有配对设备"
                      message="点击「添加设备」，在另一台设备上显示配对码并互相确认，即可开始同步。"
                    />
                  );
                }
                return (
                  <Panel>
                    {devices().map((d) => (
                      <DeviceRow device={() => d} />
                    ))}
                  </Panel>
                );
              }}
            </View>

            {/* 发现对端 */}
            <View style={{ gap: spacing.sm }}>
              <View
                style={{
                  flexDirection: "row",
                  alignItems: "center",
                  gap: spacing.sm,
                }}
              >
                <SectionTitle text="附近设备" />
                <View style={{ flex: 1 }} />
                <View
                  onPress={() => void refreshPeers()}
                  role="button"
                  accessibilityLabel="刷新附近设备"
                  accessibilityState={{ disabled: discovering() }}
                  style={{
                    minHeight: layout.mobileTouchTarget,
                    paddingHorizontal: spacing.md,
                    alignItems: "center",
                    justifyContent: "center",
                    borderRadius: radii.md,
                    borderWidth: 1,
                    borderColor: colors.border,
                    opacity: discovering() ? 0.4 : 1,
                  }}
                >
                  <Text
                    style={{
                      fontSize: typography.bodyMedium.fontSize - 3,
                      color: colors.accent,
                      fontWeight: "600",
                    }}
                  >
                    {() => (discovering() ? "搜索中…" : "搜索附近设备")}
                  </Text>
                </View>
              </View>
              {() => {
                if (!peersLoaded() && !discovering()) {
                  return (
                    <Text
                      style={{
                        color: colors.mutedInk,
                        fontSize: typography.bodyMedium.fontSize - 3,
                      }}
                    >
                      点击「搜索附近设备」扫描局域网内的 CardMind 对端。
                    </Text>
                  );
                }
                if (peers().length === 0) {
                  return (
                    <Text
                      style={{
                        color: colors.mutedInk,
                        fontSize: typography.bodyMedium.fontSize - 3,
                      }}
                    >
                      {discovering() ? "正在搜索…" : "未发现附近设备（同一局域网下对方需在设备页显示配对码）。"}
                    </Text>
                  );
                }
                return (
                  <Panel>
                    {peers().map((p) => (
                      <CardMindListItem
                        title={`${p.deviceId.slice(0, 8)}…`}
                        subtitle={`${p.ip}:${p.port}`}
                      />
                    ))}
                  </Panel>
                );
              }}
            </View>

            {/* 操作反馈 */}
            <If when={actionMessage() !== undefined}>
              <Text
                style={{
                  fontSize: typography.bodyMedium.fontSize - 3,
                  color: colors.mutedInk,
                }}
              >
                {() => actionMessage() ?? ""}
              </Text>
            </If>

            <If when={props.status !== undefined}>{props.status}</If>
          </View>
        )}
      </Scroll>

      {/* 配对面板（选择方式 / 显示码 / 输入码） */}
      <PairChooseSheet />
      <PairShowSheet />
      <PairEnterSheet />

      {/* 解绑确认（危险态） */}
      <CardMindConfirmDialog
        visible={unpairTarget() !== undefined}
        title="解除配对"
        message={`解除后不再同步，已有笔记保留。确定解除与「${unpairTarget()?.name ?? ""}」的配对？`}
        confirmLabel="解除"
        onConfirm={confirmUnpair}
        onCancel={cancelUnpair}
        danger
      />
    </View>
  );
}
