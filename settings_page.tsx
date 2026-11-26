// CardMind 设置页（施工方案 2.4）：对照 lib/pages/settings_page.dart。
//
// 功能：
//  ① 设备名（BackendPairing.getDeviceName 显示 + Input 编辑 +
//     setDeviceName 保存）；
//  ② 同步开关（BackendSync.getSyncAllowed / setSyncAllowed，自绘 48 命中区
//     开关：轨道 + 滑块，role="switch"）；
//  ③ 日志说明（显示当前日志输出方式：debug_log 只写进程 stderr + tracing，
//     暂无文件落盘；NSH 侧无打开目录 API —— 平台能力缺口，本页只显示，
//     executor.md 记为 R3 类缺口）；
//  ④ 更新检查（UI 入口：当前版本 + 检查按钮占位；真下载/安装是 Phase 4）；
//  ⑤ 紧凑断点 600：windowSize().width < compactBreakpoint(600) 时页边距
//     lg(16)，否则 xl(24)（对照 Dart `MediaQuery.sizeOf().width < 600`）。
//
// 令牌纪律：所有颜色 / 间距 / 圆角 / 触摸目标全部来自 ./theme，禁止裸值。
//
// 结构（P2-4 纯结构拆分）：本文件仅保留页面根 `SettingsPage` 与公共 API 的
// re-export；类型/常量/状态与处理函数/区块组件分别落在 `./settings_page/`
// 子模块。render 段 JSX 与交互逐字不变；signals 仍是 state.ts 模块顶层单例
// （单一创建点）。唯一有意改动：日志区块两处文案（state.ts 的 logDirNote
// 值与本文件日志区块说明行）——按 handover §6 #10，NSH debug_log 无文件
// 落盘，旧「写入 logs/cardmind.log」描述的是已删除的 Flutter 版行为。
import { effect, Scroll, Text, View } from "nsh";
import type { JSX } from "nsh";
import { Input } from "nsh/base";
import {
  CardMindIconButton,
  CardMindPrimaryButton,
  CardMindSyncStatus,
  Glyph,
} from "./components";
import { colors, layout, radii, spacing, typography } from "./theme";
import { appVersion } from "./settings_page/constants";
import { SectionTitle, SettingRow, SyncSwitch } from "./settings_page/sections";
import {
  actionMessage,
  cancelEditName,
  checkingUpdate,
  checkUpdate,
  deviceName,
  deviceNameDraft,
  editingName,
  loadSettingsWithRetry,
  logDirNote,
  pagePadding,
  saveDeviceName,
  savingName,
  startEditName,
  syncAllowed,
  toggleSync,
} from "./settings_page/state";

export type { SettingsSource } from "./settings_page/types";
export { setSettingsSource } from "./settings_page/state";

// ─── 页面根 ─────────────────────────────────────────────────────────────────

/**
 * 设置页：设备名 / 同步开关 / 日志目录 / 更新检查。
 * 紧凑断点 600：<600 页边距 lg(16)，≥600 xl(24)；内容限宽 editorMaxWidth。
 *
 * `status` 插槽：调用方传入的状态面板（App.tsx 的 Phase 1 后端证据行）。
 */
export function SettingsPage(props: { status?: JSX.Element }): JSX.Element {
  effect(() => {
    void loadSettingsWithRetry();
  });
  return (
    <Scroll style={{ flex: 1, backgroundColor: colors.paper }}>
      {() => (
        <View
          style={{
            padding: pagePadding(),
            alignItems: "center",
          }}
        >
          <View
            style={{
              width: "100%",
              maxWidth: layout.editorMaxWidth,
              gap: spacing.xl,
            }}
          >
            {/* 设备名 */}
            <View style={{ gap: spacing.sm }}>
              <SectionTitle text="设备" />
              <SettingRow
                title="设备名"
                subtitle={
                  editingName()
                    ? "输入新名称后保存"
                    : `${deviceName()}（配对时显示给其他设备）`
                }
                trailing={
                  editingName() ? (
                    <View
                      style={{
                        flexDirection: "row",
                        alignItems: "center",
                        gap: spacing.xs,
                      }}
                    >
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
                  ) : (
                    <CardMindIconButton
                      icon="edit"
                      tooltip="编辑设备名"
                      onPress={startEditName}
                    />
                  )
                }
              />
              <If when={editingName()}>
                <View
                  style={{
                    flexDirection: "row",
                    alignItems: "center",
                    borderWidth: 1,
                    borderColor: colors.border,
                    borderRadius: radii.md,
                    backgroundColor: colors.surfaceRaised,
                  }}
                >
                  <Input
                    value={deviceNameDraft()}
                    onChange={({ value }) => deviceNameDraft.set(value)}
                    onSubmit={() => void saveDeviceName()}
                    placeholder="设备名"
                    accessibilityLabel="设备名"
                    style={{
                      flex: 1,
                      minHeight: layout.mobileTouchTarget,
                      fontSize: typography.bodyMedium.fontSize,
                      color: colors.ink,
                      paddingHorizontal: spacing.md,
                    }}
                  />
                </View>
              </If>
            </View>

            {/* 同步 */}
            <View style={{ gap: spacing.sm }}>
              <SectionTitle text="同步" />
              <SettingRow
                title="允许同步"
                subtitle={syncAllowed() ? "已开启：与配对设备交换笔记" : "已暂停：不发送也不接收"}
                trailing={<SyncSwitch value={syncAllowed} onToggle={() => void toggleSync()} />}
              />
              <CardMindSyncStatus
                label={syncAllowed() ? "本地已就绪" : "同步已暂停"}
                pendingCount={0}
              />
            </View>

            {/* 日志目录 */}
            <View style={{ gap: spacing.sm }}>
              <SectionTitle text="日志目录" />
              <View
                style={{
                  borderWidth: 1,
                  borderColor: colors.border,
                  borderRadius: radii.md,
                  backgroundColor: colors.surfaceRaised,
                  padding: spacing.md,
                  gap: spacing.xs,
                }}
              >
                <View
                  style={{
                    flexDirection: "row",
                    alignItems: "center",
                    gap: spacing.sm,
                  }}
                >
                  <Glyph name="notes" size={18} tint={colors.mutedInk} />
                  <Text
                    style={{
                      flex: 1,
                      fontSize: typography.bodyMedium.fontSize - 3,
                      color: colors.mutedInk,
                    }}
                  >
                    {() => logDirNote()}
                  </Text>
                </View>
                <Text
                  style={{
                    fontSize: typography.bodyMedium.fontSize - 3,
                    color: colors.mutedInk,
                  }}
                >
                  NSH 侧暂无打开目录 API；应用日志暂无文件落盘，排查时查看进程 stderr 的 [cardmind:log] 行。
                </Text>
              </View>
            </View>

            {/* 更新检查 */}
            <View style={{ gap: spacing.sm }}>
              <SectionTitle text="更新" />
              <SettingRow
                title="应用版本"
                subtitle={`当前版本 ${appVersion}`}
              />
              <CardMindPrimaryButton
                label={checkingUpdate() ? "检查中…" : "检查更新"}
                icon="search"
                onPress={checkUpdate}
                busy={checkingUpdate()}
              />
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
        </View>
      )}
    </Scroll>
  );
}
