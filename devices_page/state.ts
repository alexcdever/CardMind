// 设备页状态与处理函数（自 devices_page.tsx 纯结构拆出）：source/makeBackendSource/
// setDevicesSource、map*、全部 module-level signals（单一创建点）、文本工具、数据加载/
// 后台刷新、设备管理、配对流程处理函数；另加卸载清理接缝 disposeDevicesPage。
// 声明顺序与函数体逐字保留，仅给对外使用的顶层声明加 export 前缀。
import { signal } from "nsh";
import { BackendPairing, BackendSync } from "app/native";
import type {
  DevicesSource,
  PairedDeviceDto,
  PairingRequestDto,
  PairingResultDto,
  PeerInfoDto,
} from "./types";
import {
  acceptPollMs,
  countdownTickMs,
  onlineWindowMs,
  pairingCodeTtlMs,
  refreshIntervalMs,
  sixDigitCode,
} from "./constants";

/** 0.2.0 起桥 DTO 已是 camelCase，直读即可（map* 收敛为恒等；入参宽化接收原生可空可选字段）。 */
function mapDevice(r: {
  peerId: string;
  name: string;
  lastSeen?: string | null;
  lastSyncAt?: string | null;
  pairedAt: string;
}): PairedDeviceDto {
  return {
    peerId: r.peerId,
    name: r.name,
    lastSeen: r.lastSeen ?? null,
    lastSyncAt: r.lastSyncAt ?? null,
    pairedAt: r.pairedAt,
  };
}

function mapPeer(p: PeerInfoDto): PeerInfoDto {
  return p;
}

function mapRequest(r: PairingRequestDto): PairingRequestDto {
  return r;
}

function mapResult(r: PairingResultDto): PairingResultDto {
  return r;
}

/** 默认源：BackendPairing / BackendSync 的 camelCase DTO 直读（0.2.0）。 */
function makeBackendSource(): DevicesSource {
  return {
    getDeviceId: () => BackendPairing.getDeviceId(),
    getDeviceName: () => BackendPairing.getDeviceName(),
    // 改名走「落盘 + 广播给已配对设备」路径（Dart NoteRepository.setDeviceName
    // 对应 sync.set_device_name_and_notify）。
    setDeviceName: (name) => BackendPairing.setDeviceNameAndNotify(name),
    localAddrs: () => BackendPairing.localAddrs(),
    listPairedDevices: async () =>
      (await BackendPairing.listPairedDevices()).map(mapDevice),
    removePairedDevice: async (peerId) => {
      await BackendPairing.removePairedDevice(peerId);
      return true;
    },
    checkDeviceConnectivity: (peerId) => BackendSync.checkDeviceConnectivity(peerId),
    syncDiscoverPeers: async () => (await BackendPairing.syncDiscoverPeers()).map(mapPeer),
    discoverPeers: async () => (await BackendPairing.discoverPeers()).map(mapPeer),
    // 生成 6 位配对码并同时启动 mDNS 广播（任务 J 组合 API；会话 nonce 随
    // 广播下发，6 位码发起方才能过 confirm 侧 nonce 校验）。返回纯 code。
    beginPairingAcceptWithAdvertising: () =>
      BackendPairing.beginPairingAcceptWithAdvertising(),
    // 生成签名配对凭证并启动 mDNS 广播（任务 Q 组合 API；凭证 = cm1. 前缀
    // + base64url，可渲染成二维码图片给对方识别）。camelCase 直读。
    beginPairingCredentialWithAdvertising: async () => {
      const r = await BackendPairing.beginPairingCredentialWithAdvertising();
      return { code: r.code, credential: r.credential, expiresAt: r.expiresAt };
    },
    stopPairingAdvertising: () => BackendPairing.stopPairingAdvertising(),
    acceptPairingRequestWithTimeout: async (timeoutMs) => {
      const r = await BackendPairing.acceptPairingRequestWithTimeout(timeoutMs);
      return r === null || r === undefined ? null : mapRequest(r);
    },
    confirmPairing: async (code, request) =>
      mapResult(
        await BackendPairing.confirmPairing(code, {
          code: request.code,
          deviceId: request.deviceId,
          deviceName: request.deviceName,
          relayInfo: request.relayInfo,
          ips: request.ips,
          nonce: request.nonce,
        }),
      ),
    beginPairingConnect: async (code, target) =>
      mapResult(
        await BackendPairing.beginPairingConnect(code, {
          deviceId: target.deviceId,
          ip: target.ip,
          port: target.port,
          nonce: target.nonce,
        }),
      ),
    parsePairingCredential: (credential) =>
      BackendPairing.parsePairingCredential(credential),
    beginPairingConnectWithCredential: async (credential) =>
      mapResult(await BackendPairing.beginPairingConnectWithCredential(credential)),
    // 二维码图片路径（QR 任务）：保存 = 渲染 cm1. 凭证 + rfd 保存框写 PNG；
    // 识别 = rfd 打开框选图 + rqrr 解码回 cm1. 凭证。空串 = 用户取消。
    // 0.2.0 非 async 模块函数生成同步签名（string 非 Promise），包成 Promise。
    savePairingQrPng: (credential) => Promise.resolve(BackendPairing.savePairingQrPng(credential)),
    decodePairingQrFile: () => Promise.resolve(BackendPairing.decodePairingQrFile()),
  };
}

let source: DevicesSource = makeBackendSource();

/** 替换数据源（测试/演示用）。 */
export function setDevicesSource(s: DevicesSource): void {
  source = s;
}

export const devices = signal<PairedDeviceDto[]>([]);
export const loading = signal(true);
export const loadError = signal<string | undefined>(undefined);
export const deviceName = signal("");
export const deviceId = signal("");
export const localAddrs = signal<string[]>([]);
export const actionMessage = signal<string | undefined>(undefined);
const busy = signal(false);

/** 连通检查状态：peerId → checking / latencyMs / failed。 */
export type Connectivity = { kind: "checking" } | { kind: "ok"; latencyMs: number } | { kind: "failed" };
export const connectivity = signal<Record<string, Connectivity>>({});

/** 解绑确认目标。 */
export const unpairTarget = signal<PairedDeviceDto | undefined>(undefined);

/** 设备名编辑。 */
export const editingName = signal(false);
export const nameDraft = signal("");
export const savingName = signal(false);

/** 配对流程：mode = 选方式弹窗 / 显示码 / 输入码。 */
export type PairSheet = "none" | "choose" | "show" | "enter";
export const pairSheet = signal<PairSheet>("none");

/** 显示码侧状态。 */
export const pairCode = signal<string | undefined>(undefined);
/** 当前配对会话的 cm1. 签名凭证（渲染二维码图片用；undefined = 未生成）。 */
const pairCredential = signal<string | undefined>(undefined);
/** 「保存二维码图片」成功后的落盘路径（mutedInk 提示，非错误）。 */
export const qrSavedPath = signal<string | undefined>(undefined);
/** 当前配对会话截止时间（epoch ms；用 Rust 返回的 expiresAt 绝对值，
 *  undefined = 未生成）。 */
export const pairDeadlineMs = signal<number | undefined>(undefined);
export const pairError = signal<string | undefined>(undefined);
export const pairRemainingMs = signal(0);
/** 显示码轮次 token：重新生成/关闭时递增，使挂起的 accept 轮判废。 */
let pairGeneration = 0;
let countdownTimer: ReturnType<typeof setInterval> | undefined;

/** 输入码侧状态。 */
export const enterInput = signal("");
export const enterError = signal<string | undefined>(undefined);
export const enterBusy = signal(false);

/** 「识别二维码图片」入口状态（choose 弹窗内展示：busy + 可读错误）。 */
export const scanBusy = signal(false);
export const scanError = signal<string | undefined>(undefined);

/** 发现对端。 */
export const peers = signal<PeerInfoDto[]>([]);
export const discovering = signal(false);
export const peersLoaded = signal(false);

export function isOnline(d: PairedDeviceDto): boolean {
  if (d.lastSeen === null) return false;
  const t = Date.parse(d.lastSeen);
  if (Number.isNaN(t)) return false;
  return Date.now() - t <= onlineWindowMs;
}

export function relativeTime(iso: string | null): string {
  if (iso === null) return "从未同步";
  const t = Date.parse(iso);
  if (Number.isNaN(t)) return "未知";
  const diff = Date.now() - t;
  const minutes = Math.floor(diff / 60000);
  if (minutes < 1) return "刚刚";
  if (minutes < 60) return `${minutes} 分钟前`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} 小时前`;
  return `${Math.floor(hours / 24)} 天前`;
}

export function formatCountdown(ms: number): string {
  if (ms <= 0) return "已过期，请重新生成";
  const totalSec = Math.ceil(ms / 1000);
  const m = Math.floor(totalSec / 60);
  const s = totalSec % 60;
  return `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
}

async function loadDevices(background = false): Promise<void> {
  if (!background) loading.set(true);
  try {
    const list = await source.listPairedDevices();
    devices.set(list);
    if (!background) loadError.set(undefined);
  } catch (error) {
    if (!background) loadError.set(`加载设备失败：${String(error)}`);
    // 后台刷新失败静默（下个周期重试）
  } finally {
    if (!background) loading.set(false);
  }
}

async function loadLocalInfo(): Promise<void> {
  try {
    const [name, id, addrs] = await Promise.all([
      source.getDeviceName(),
      source.getDeviceId(),
      source.localAddrs(),
    ]);
    deviceName.set(name);
    deviceId.set(id);
    localAddrs.set(addrs);
  } catch {
    // 本机信息读取失败不阻断列表（SyncService 可能尚未就绪）。
  }
}

async function loadAll(): Promise<void> {
  await Promise.all([loadDevices(), loadLocalInfo()]);
}

/** 首次装载重试：SyncService 可能与 App 层 createSyncService 并发未就绪。 */
export async function loadAllWithRetry(attempts = 3, delayMs = 250): Promise<void> {
  for (let i = 0; i < attempts; i += 1) {
    try {
      await loadAll();
      if (loadError() === undefined) return;
    } catch {
      // 下一轮重试
    }
    if (i + 1 < attempts) {
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }
}

/** 页面级周期刷新（对照 Dart _refreshTimer）：组件存活期间每 2s 重读列表。
 *  挂在 DevicesPage 的 effect 里并 cleanup。 */
export function startBackgroundRefresh(): () => void {
  const timer = setInterval(() => {
    if (!loading()) void loadDevices(true);
  }, refreshIntervalMs);
  return () => clearInterval(timer);
}

export async function checkConnectivity(d: PairedDeviceDto): Promise<void> {
  const cur = connectivity()[d.peerId];
  if (cur?.kind === "checking") return;
  connectivity.set({ ...connectivity(), [d.peerId]: { kind: "checking" } });
  try {
    const latencyMs = await source.checkDeviceConnectivity(d.peerId);
    connectivity.set({ ...connectivity(), [d.peerId]: { kind: "ok", latencyMs } });
    void loadDevices(true);
  } catch {
    connectivity.set({ ...connectivity(), [d.peerId]: { kind: "failed" } });
  }
}

export function requestUnpair(d: PairedDeviceDto): void {
  unpairTarget.set(d);
}

export async function confirmUnpair(): Promise<void> {
  const target = unpairTarget();
  unpairTarget.set(undefined);
  if (!target || busy()) return;
  busy.set(true);
  try {
    await source.removePairedDevice(target.peerId);
    actionMessage.set(`已解除与「${target.name}」的配对`);
    await loadDevices(true);
  } catch (error) {
    actionMessage.set(`解除配对失败：${String(error)}`);
  } finally {
    busy.set(false);
  }
}

export function cancelUnpair(): void {
  unpairTarget.set(undefined);
}

export function startEditName(): void {
  nameDraft.set(deviceName());
  editingName.set(true);
}

export function cancelEditName(): void {
  editingName.set(false);
  nameDraft.set(deviceName());
}

export async function saveDeviceName(): Promise<void> {
  const name = nameDraft().trim();
  if (name.length === 0 || savingName()) {
    if (name.length === 0) actionMessage.set("设备名不能为空");
    return;
  }
  savingName.set(true);
  try {
    await source.setDeviceName(name);
    deviceName.set(name);
    editingName.set(false);
    actionMessage.set(`设备名已更新：${name}`);
  } catch (error) {
    actionMessage.set(`保存失败：${String(error)}`);
  } finally {
    savingName.set(false);
  }
}

export async function refreshPeers(): Promise<void> {
  if (discovering()) return;
  discovering.set(true);
  try {
    // 优先 SyncService 侧发现（自动填充发起方 device id）；失败退回
    // DiscoveryService 直接扫描。
    let found: PeerInfoDto[];
    try {
      found = await source.syncDiscoverPeers();
    } catch {
      found = await source.discoverPeers();
    }
    peers.set(found);
    peersLoaded.set(true);
  } catch (error) {
    peers.set([]);
    peersLoaded.set(true);
    actionMessage.set(`发现对端失败：${String(error)}`);
  } finally {
    discovering.set(false);
  }
}

function stopCountdown(): void {
  if (countdownTimer !== undefined) {
    clearInterval(countdownTimer);
    countdownTimer = undefined;
  }
}

/** 启动倒计时：按截止时间绝对值每 tick 更新（组件卸载/弹窗关闭时清理）。 */
function startCountdown(deadline: number): void {
  stopCountdown();
  const tick = () => {
    const remaining = deadline - Date.now();
    pairRemainingMs.set(remaining > 0 ? remaining : 0);
  };
  tick();
  countdownTimer = setInterval(tick, countdownTickMs);
}

/** 生成一轮凭证并启动短窗口 accept 轮询（对照 Dart _runAcceptRounds）。
 *
 *  与 Dart 的差异：Rust 侧 accept_pairing_request_with_timeout 文档要求 UI
 *  「以短窗口（10s）轮询调用」，Dart 直接传 10 分钟整窗。这里每轮
 *  acceptPollMs 短窗，超时即重试直到凭证 TTL（pairingCodeTtlMs）到期；
 *  到期不报错——自动重新生成新凭证（Dart 静默重生成同语义）。 */
async function runAcceptLoop(gen: number): Promise<void> {
  const deadline = Date.now() + pairingCodeTtlMs;
  while (gen === pairGeneration && pairSheet() === "show") {
    if (Date.now() >= deadline) {
      // 凭证窗口到期：静默重生成（新 code + 新 nonce + 新广播）。
      await generatePairCode(gen);
      if (gen !== pairGeneration || pairSheet() !== "show") return;
      return runAcceptLoop(gen);
    }
    const window = Math.min(acceptPollMs, Math.max(0, deadline - Date.now()));
    let request: PairingRequestDto | null = null;
    try {
      request = await source.acceptPairingRequestWithTimeout(window);
    } catch {
      // 单轮失败：下一轮重试（有界窗口自然释放）。
      continue;
    }
    if (gen !== pairGeneration || pairSheet() !== "show") return;
    if (request === null) continue;
    const code = pairCode();
    if (code === undefined) return;
    try {
      const result = await source.confirmPairing(code, request);
      if (gen !== pairGeneration || pairSheet() !== "show") return;
      actionMessage.set(`配对成功：${result.peerName}`);
      closePairSheet();
      await loadDevices(true);
      return;
    } catch (error) {
      pairError.set(`配对失败：${String(error)}`);
      // 失败后继续等下一个请求（Dart 同样留在弹窗内）。
    }
  }
}

/** 生成并展示一轮配对凭证（任务 Q 组合 API：凭证 + mDNS 广播同一调用）。
 *  `beginPairingCredentialWithAdvertising` 返回 {code, credential, expiresAt}：
 *  `code` 继续作 6 位显示码；`credential`（cm1. 前缀签名凭证）存
 *  pairCredential，供「保存二维码图片」渲染；截止时间直接用 Rust 返回的
 *  expiresAt 绝对值（与凭证内嵌 TTL 一致，不再本地推导）。 */
async function generatePairCode(gen: number): Promise<void> {
  pairError.set(undefined);
  try {
    const cred = await source.beginPairingCredentialWithAdvertising();
    if (gen !== pairGeneration || pairSheet() !== "show") return;
    pairCode.set(cred.code);
    pairCredential.set(cred.credential);
    qrSavedPath.set(undefined);
    const parsed = Date.parse(cred.expiresAt);
    const deadline = Number.isNaN(parsed)
      ? Date.now() + pairingCodeTtlMs
      : parsed;
    pairDeadlineMs.set(deadline);
    startCountdown(deadline);
  } catch {
    if (gen !== pairGeneration || pairSheet() !== "show") return;
    pairError.set("生成配对信息失败，请关闭后重试");
  }
}

/** 打开「我显示配对码」面板：起一轮凭证 + accept 轮询。 */
export async function openShowCode(): Promise<void> {
  pairSheet.set("show");
  const gen = ++pairGeneration;
  await generatePairCode(gen);
  void runAcceptLoop(gen);
}

/** 重新生成（手动）：递增轮次 token → 旧 accept 轮判废退出 → 新轮次。 */
export async function regeneratePairCode(): Promise<void> {
  if (pairSheet() !== "show") return;
  const gen = ++pairGeneration;
  await generatePairCode(gen);
  void runAcceptLoop(gen);
}

/** 「保存二维码图片」：把当前 cm1. 凭证渲染成二维码 PNG 写用户自选路径。
 *  空串返回 = 用户取消（不提示）；真错误进 pairError（danger 色）；
 *  成功路径进 qrSavedPath（mutedInk 提示）。
 *  对话框挂起期间若弹窗被关/凭证被重新生成（gen 变化），结果直接丢弃。 */
export async function savePairingQrImage(): Promise<void> {
  const credential = pairCredential();
  if (credential === undefined) return;
  const gen = pairGeneration;
  pairError.set(undefined);
  try {
    const path = await source.savePairingQrPng(credential);
    if (gen !== pairGeneration || pairSheet() !== "show") return;
    if (path === "") return; // 用户取消：不提示。
    qrSavedPath.set(path);
  } catch (error) {
    if (gen !== pairGeneration || pairSheet() !== "show") return;
    pairError.set(`保存二维码失败：${String(error)}`);
  }
}

/** 关闭配对面板：判废 accept 轮 + 停倒计时 + 停广播（幂等，失败忽略）。 */
export function closePairSheet(): void {
  pairSheet.set("none");
  pairGeneration += 1;
  stopCountdown();
  pairCode.set(undefined);
  pairCredential.set(undefined);
  qrSavedPath.set(undefined);
  pairDeadlineMs.set(undefined);
  pairRemainingMs.set(0);
  pairError.set(undefined);
  void source.stopPairingAdvertising().catch(() => undefined);
}

export function openEnterCode(): void {
  pairSheet.set("enter");
  enterInput.set("");
  enterError.set(undefined);
}

/** 凭证路径：cm1 开头 → parsePairingCredential 验证 → beginPairingConnectWithCredential。 */
async function connectCredential(credential: string): Promise<PairingResultDto> {
  await source.parsePairingCredential(credential);
  return source.beginPairingConnectWithCredential(credential);
}

/** 「识别二维码图片」（发起方，QR 任务）：弹系统打开框选图 → rqrr 解出
 *  cm1. 凭证 → 复用现有凭证路径（parse + beginPairingConnectWithCredential）
 *  自动完成配对。空串 = 用户取消直接返回；非 cm1. 二维码/识别失败显示在
 *  choose 弹窗的 scanError；成功接标准完成态（actionMessage + 关弹窗 +
 *  刷新列表）。 */
export async function scanPairingQrImage(): Promise<void> {
  if (scanBusy()) return;
  scanError.set(undefined);
  scanBusy.set(true);
  try {
    const credential = await source.decodePairingQrFile();
    if (credential === "") return; // 用户取消：不动作。
    if (!credential.startsWith("cm1.")) {
      scanError.set("识别到的二维码不是 CardMind 配对凭证（应以 cm1. 开头）");
      return;
    }
    const result = await connectCredential(credential);
    actionMessage.set(`配对成功：${result.peerName}`);
    closePairSheet();
    await loadDevices(true);
  } catch (error) {
    scanError.set(`识别二维码失败：${String(error)}`);
  } finally {
    scanBusy.set(false);
  }
}

/** 6 位码路径：discoverPeers 找唯一目标 → beginPairingConnect。 */
async function connectWithSixDigitCode(code: string): Promise<PairingResultDto> {
  const found = await source.discoverPeers().catch(() => [] as PeerInfoDto[]);
  if (found.length === 0) {
    throw new Error("未在局域网发现对方设备，请确认两台设备在同一网络");
  }
  if (found.length > 1) {
    throw new Error("在局域网发现多台 CardMind 设备，无法自动确定配对对象");
  }
  return source.beginPairingConnect(code, found[0]);
}

/** 发起方提交：cm1 → 凭证路径；6 位数字 → mDNS 发现直连；其余 → 格式提示。 */
export async function submitPeerCode(): Promise<void> {
  const input = enterInput().trim();
  if (input.length === 0 || enterBusy()) return;
  enterError.set(undefined);
  enterBusy.set(true);
  try {
    let result: PairingResultDto;
    if (input.startsWith("cm1")) {
      result = await connectCredential(input);
    } else if (sixDigitCode.test(input)) {
      result = await connectWithSixDigitCode(input);
    } else {
      enterError.set("请输入 6 位配对码，或粘贴完整的配对信息（以 cm1 开头）");
      return;
    }
    actionMessage.set(`配对成功：${result.peerName}`);
    closePairSheet();
    await loadDevices(true);
  } catch (error) {
    enterError.set(
      input.startsWith("cm1")
        ? String(error)
        : "配对失败：无法连接到对方设备，请稍后重试",
    );
  } finally {
    enterBusy.set(false);
  }
}

/** 卸载清理（DevicesPage 的 cleanup 调用）：停倒计时 + 判废挂起的 accept 轮。
 *  跨模块 let 写回接缝：`pairGeneration += 1` 原在入口 cleanup，声明搬入本模块。 */
export function disposeDevicesPage(): void {
  stopCountdown();
  pairGeneration += 1;
}
