// CardMind 设置页（施工方案 2.4）：对照 lib/pages/settings_page.dart。
//
// 功能：
//  ① 设备名（BackendPairing.getDeviceName 显示 + Input 编辑 +
//     setDeviceName 保存）；
//  ② 同步开关（BackendSync.getSyncAllowed / setSyncAllowed，自绘 48 命中区
//     开关：轨道 + 滑块，role="switch"）；
//  ③ 日志目录（显示路径 + 说明；NSH 侧无打开目录 API —— 平台能力缺口，
//     本页只显示，executor.md 记为 R3 类缺口）；
//  ④ 更新检查（UI 入口：当前版本 + 检查按钮占位；真下载/安装是 Phase 4）；
//  ⑤ 紧凑断点 600：windowSize().width < compactBreakpoint(600) 时页边距
//     lg(16)，否则 xl(24)（对照 Dart `MediaQuery.sizeOf().width < 600`）。
//
// 令牌纪律：所有颜色 / 间距 / 圆角 / 触摸目标全部来自 ./theme，禁止裸值。
import { computed, effect, signal, Input, Scroll, Text, View } from "nsh";
import type { JSX } from "nsh";
import { windowSize } from "nsh/device";
import { BackendPairing, BackendSync } from "app/native";
import {
  CardMindIconButton,
  CardMindPrimaryButton,
  CardMindSyncStatus,
  Glyph,
} from "./components";
import { colors, layout, radii, spacing, typography } from "./theme";

// ─── 常量 ────────────────────────────────────────────────────────────────────

/** 面板紧凑断点（px）：<600 页边距收紧到 lg(16)，≥600 用 xl(24)。
 *  对照 settings_page.dart `MediaQuery.sizeOf(context).width < 600`；
 *  与 note_list 的 desktopBreakpoint=960（窗宽分栏）不同层级。 */
const compactBreakpoint = 600;

/** 开关轨道尺寸（视觉件，命中区由外层 48 高行保证）。 */
const switchTrack = { width: 44, height: 26, knob: 20 } as const;
/** 应用版本（nsh.json version；包构建版本由 Phase 4 `nsh package` 注入）。 */
const appVersion = "0.1.0";

// ─── 设置后端表面（可注入替代；默认值走真后端）────────────────────────────────

export interface SettingsSource {
  getDeviceName(): Promise<string>;
  setDeviceName(name: string): Promise<boolean>;
  getSyncAllowed(): Promise<boolean>;
  setSyncAllowed(allowed: boolean): Promise<boolean>;
}

function makeBackendSource(): SettingsSource {
  return {
    getDeviceName: () => BackendPairing.getDeviceName(),
    setDeviceName: (name) => BackendPairing.setDeviceName(name),
    getSyncAllowed: () => BackendSync.getSyncAllowed(),
    setSyncAllowed: (allowed) => BackendSync.setSyncAllowed(allowed),
  };
}

let source: SettingsSource = makeBackendSource();

/** 替换数据源（测试/演示用）。 */
export function setSettingsSource(s: SettingsSource): void {
  source = s;
}

// ─── 页面状态 ────────────────────────────────────────────────────────────────

const deviceName = signal("");
const deviceNameDraft = signal("");
const editingName = signal(false);
const savingName = signal(false);
const syncAllowed = signal(true);
const loading = signal(true);
const actionMessage = signal<string | undefined>(undefined);
const checkingUpdate = signal(false);
/** 日志目录：NSH 侧无解析 API，只显示平台约定路径说明。 */
const logDirNote = signal("日志写入应用支持目录 logs/cardmind.log");

const compact = computed(() => windowSize().width < compactBreakpoint);
const pagePadding = computed(() => (compact() ? spacing.lg : spacing.xl));

// ─── 数据加载 ────────────────────────────────────────────────────────────────

async function loadSettings(): Promise<void> {
  loading.set(true);
  try {
    const [name, allowed] = await Promise.all([
      source.getDeviceName(),
      source.getSyncAllowed(),
    ]);
    deviceName.set(name);
    deviceNameDraft.set(name);
    syncAllowed.set(allowed);
  } catch {
    actionMessage.set("读取设置失败");
  } finally {
    loading.set(false);
  }
}

/** 首次装载重试：SyncService 可能与 App 层初始化并发未就绪，重试三次。 */
async function loadSettingsWithRetry(attempts = 3, delayMs = 250): Promise<void> {
  for (let i = 0; i < attempts; i += 1) {
    try {
      await loadSettings();
      return;
    } catch {
      if (i + 1 < attempts) {
        await new Promise((resolve) => setTimeout(resolve, delayMs));
      }
    }
  }
}

// ─── 操作 ────────────────────────────────────────────────────────────────────

function startEditName(): void {
  deviceNameDraft.set(deviceName());
  editingName.set(true);
}

function cancelEditName(): void {
  editingName.set(false);
  deviceNameDraft.set(deviceName());
}

async function saveDeviceName(): Promise<void> {
  const name = deviceNameDraft().trim();
  if (name.length === 0 || savingName()) {
    if (name.length === 0) actionMessage.set("设备名不能为空");
    return;
  }
  savingName.set(true);
  try {
    await source.setDeviceName(name);
    deviceName.set(name);
    editingName.set(false);
    actionMessage.set(`设备名已保存：${name}`);
  } catch (error) {
    actionMessage.set(`保存失败：${String(error)}`);
  } finally {
    savingName.set(false);
  }
}

async function toggleSync(): Promise<void> {
  const next = !syncAllowed();
  try {
    await source.setSyncAllowed(next);
    syncAllowed.set(next);
    actionMessage.set(next ? "同步已开启" : "同步已暂停");
  } catch (error) {
    actionMessage.set(`切换失败：${String(error)}`);
  }
}

/** 更新检查：Phase 4 才接真下载/安装，这里只做 UI 反馈。 */
function checkUpdate(): void {
  checkingUpdate.set(true);
  actionMessage.set("当前已是最新版本（更新检查在 Phase 4 接入）");
  checkingUpdate.set(false);
}

// ─── 区块组件 ────────────────────────────────────────────────────────────────

function SectionTitle(props: { text: string }): JSX.Element {
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

/** 设置项行：标题 + 副标题 + 尾部控件（48 最小高，hairline 底部分隔）。 */
function SettingRow(props: {
  title: string;
  subtitle?: string;
  trailing?: JSX.Element;
}): JSX.Element {
  return (
    <View
      style={{
        minHeight: layout.mobileTouchTarget,
        flexDirection: "row",
        alignItems: "center",
        paddingVertical: spacing.sm,
        borderBottomWidth: 1,
        borderBottomColor: colors.border,
        gap: spacing.md,
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
              fontSize: typography.bodyMedium.fontSize - 3,
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

/** 同步开关：自绘轨道 + 滑块（role="switch"，命中区 48 行高）。 */
function SyncSwitch(props: {
  value: () => boolean;
  onToggle: () => void;
}): JSX.Element {
  const on = props.value;
  return (
    <View
      onPress={props.onToggle}
      role="switch"
      accessibilityLabel="同步"
      accessibilityState={{ checked: on() }}
      style={{
        width: layout.mobileTouchTarget,
        height: layout.mobileTouchTarget,
        alignItems: "center",
        justifyContent: "center",
        borderRadius: radii.md,
      }}
    >
      <View
        style={{
          width: switchTrack.width,
          height: switchTrack.height,
          borderRadius: switchTrack.height / 2,
          backgroundColor: on() ? colors.accent : colors.border,
          justifyContent: "center",
          padding: (switchTrack.height - switchTrack.knob) / 2,
        }}
      >
        <View
          style={{
            width: switchTrack.knob,
            height: switchTrack.knob,
            borderRadius: switchTrack.knob / 2,
            backgroundColor: colors.surfaceRaised,
            alignSelf: on() ? "flex-end" : "flex-start",
          }}
        />
      </View>
    </View>
  );
}

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
                    onChange={(t: string) => deviceNameDraft.set(t)}
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
                  NSH 侧暂无打开目录 API；排查时按平台约定路径（应用支持目录/logs/cardmind.log）访问。
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