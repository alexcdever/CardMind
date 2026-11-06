// 设置页状态与处理函数（自 settings_page.tsx 纯结构拆出）：makeBackendSource/
// source/setSettingsSource、全部 module-level signals（单一创建点）、compact
// 与 pagePadding computed、数据加载与设备名/同步开关/更新检查处理函数。
// 声明顺序与函数体逐字保留，仅给对外使用的顶层声明加 export 前缀。
// 唯一有意文案改动：logDirNote 值——按 handover §6 #10 与 AGENTS.md「日志
// 与数据目录」，NSH 当前 debug_log 只输出进程 stderr + tracing，没有文件
// 落盘；旧文案「日志写入应用支持目录 logs/cardmind.log」描述的是 Flutter 版
// path_provider 行为，已不再成立。
import { computed, signal, windowSize } from "nsh";
import { BackendPairing, BackendSync } from "app/native";
import { spacing } from "../theme";
import { compactBreakpoint } from "./constants";
import type { SettingsSource } from "./types";

// ─── 设置后端表面（可注入替代；默认值走真后端）────────────────────────────────

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

export const deviceName = signal("");
export const deviceNameDraft = signal("");
export const editingName = signal(false);
export const savingName = signal(false);
export const syncAllowed = signal(true);
const loading = signal(true);
export const actionMessage = signal<string | undefined>(undefined);
export const checkingUpdate = signal(false);
/** 日志说明：debug_log 只写进程 stderr + tracing，无文件落盘（NSH 也无打开
 *  目录 API）。 */
export const logDirNote = signal("应用日志仅输出到进程 stderr（tracing），暂无文件落盘");

const compact = computed(() => windowSize().width < compactBreakpoint);
export const pagePadding = computed(() => (compact() ? spacing.lg : spacing.xl));

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
export async function loadSettingsWithRetry(attempts = 3, delayMs = 250): Promise<void> {
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

export function startEditName(): void {
  deviceNameDraft.set(deviceName());
  editingName.set(true);
}

export function cancelEditName(): void {
  editingName.set(false);
  deviceNameDraft.set(deviceName());
}

export async function saveDeviceName(): Promise<void> {
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

export async function toggleSync(): Promise<void> {
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
export function checkUpdate(): void {
  checkingUpdate.set(true);
  actionMessage.set("当前已是最新版本（更新检查在 Phase 4 接入）");
  checkingUpdate.set(false);
}
