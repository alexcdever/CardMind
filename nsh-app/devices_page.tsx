// CardMind 设备页（施工方案 2.5）：对照 lib/pages/devices_page.dart（1504 行）。
//
// 功能：
//  ① 本机信息（BackendPairing.getDeviceId / getDeviceName / localAddrs）+
//    设备改名（setDeviceNameAndNotify）；
//  ② 已配对设备列表（listPairedDevices）：设备名 / 在线状态 / 最后连接，
//    操作：连通检查（BackendSync.checkDeviceConnectivity）、解绑
//    （removePairedDevice，走 CardMindConfirmDialog 危险确认）、改名；
//  ③ 配对流程：
//    - 显示方：beginPairingCredentialWithAdvertising 生成 6 位配对码 + cm1.
//      签名凭证 + mDNS 广播（任务 Q 组合 API）+ 短窗口轮询
//      acceptPairingRequestWithTimeout + confirmPairing；凭证可经
//      「保存二维码图片」（savePairingQrPng → rfd 系统保存框）存为 PNG；
//    - 发起方：「识别二维码图片」（decodePairingQrFile → rfd 打开框 + rqrr
//      识别）解出 cm1. 凭证后自动 connectCredential 完成配对；或手动输入
//      配对码/凭证——cm1 开头经 parsePairingCredential 验证后走
//      beginPairingConnectWithCredential；纯 6 位码经 discoverPeers
//      发现唯一目标后走 beginPairingConnect；
//    - 真扫码（相机直扫）仍属 R3 平台能力缺口，仅保留说明；
//  ④ 发现对端（discoverPeers / syncDiscoverPeers）；
//  ⑤ 空态（CardMindEmptyState）。
//
// R3 诚实标注：NSH 无相机 API（docs/migration-nsh.md R3）——相机直扫仍
// 不可用；「识别二维码图片」是图片级替代路径（无需相机），入口可用不假报。
//
// 令牌纪律：所有颜色 / 间距 / 圆角 / 触摸目标全部来自 ./theme，禁止裸值。
import { cleanup, effect, signal, Input, Scroll, Text, View } from "nsh";
import type { JSX } from "nsh";
import { Dialog } from "nsh/base";
import { BackendPairing, BackendSync } from "app/native";
import {
  CardMindConfirmDialog,
  CardMindEmptyState,
  CardMindIconButton,
  CardMindListItem,
  CardMindPrimaryButton,
  Glyph,
  panel,
} from "./components";
import { colors, layout, radii, spacing, typography } from "./theme";

// ─── 常量 ────────────────────────────────────────────────────────────────────

/** 配对码有效期：与 Rust 侧 PAIRING_CODE_TTL_MINUTES = 10 分钟严格对齐
 *  （sync.rs；accept 轮询总时限即会话窗口，过期后重新生成）。
 *  `beginPairingAcceptWithAdvertising` 只返回 6 位码不返回过期时间，
 *  倒计时按「生成时刻 + 本常量」本地推导。 */
const pairingCodeTtlMs = 10 * 60 * 1000;

/** accept 单轮短窗口（ms）：Rust 端要求有界调用，UI 用短窗口轮询，
 *  弹窗关闭/重新生成后旧轮次随窗口结束自然释放。 */
const acceptPollMs = 10 * 1000;

/** 倒计时刻度（ms）。 */
const countdownTickMs = 250;

/** 在线判定窗口：lastSeen 距今 ≤5 分钟视为在线（Dart onlineWindow）。 */
const onlineWindowMs = 5 * 60 * 1000;

/** 设备列表自动刷新间隔（Dart _refreshInterval ≈2s 周期重读在线状态）。 */
const refreshIntervalMs = 2000;

/** 6 位数字配对码（旧路径；cm1 开头走凭证路径）。 */
const sixDigitCode = /^\d{6}$/;

/** 本机头像图标视觉尺寸（对照 Dart Icon size:22）。 */
const localIconSize = 22;

// ─── 数据层（可注入替代；默认值走真后端）─────────────────────────────────────

/** 已配对设备行（与 nsh-app/src/lib.rs 的 PairedDeviceDto 镜像一致）。 */
export interface PairedDeviceDto {
  peerId: string;
  name: string;
  lastSeen: string | null;
  lastSyncAt: string | null;
  pairedAt: string;
}

/** mDNS 发现的对端（PeerInfoDto 镜像）。 */
export interface PeerInfoDto {
  deviceId: string;
  ip: string;
  port: number;
  nonce: string;
}

/** 待确认的配对请求（PairingRequestDto 镜像）。 */
export interface PairingRequestDto {
  code: string;
  deviceId: string;
  deviceName: string;
  relayInfo: string;
  ips: string[];
  nonce: string;
}

/** 配对结果（PairingResultDto 镜像）。 */
export interface PairingResultDto {
  peerId: string;
  peerName: string;
}

/** 显示方配对凭证展示（PairingCredentialDisplayDto 镜像）。 */
export interface PairingCredentialDisplayDto {
  code: string;
  credential: string;
  expiresAt: string;
}

/** 设备页后端表面（TSX 侧能注入假实现）。 */
export interface DevicesSource {
  getDeviceId(): Promise<string>;
  getDeviceName(): Promise<string>;
  setDeviceName(name: string): Promise<boolean>;
  localAddrs(): Promise<string[]>;
  listPairedDevices(): Promise<PairedDeviceDto[]>;
  removePairedDevice(peerId: string): Promise<boolean>;
  checkDeviceConnectivity(peerId: string): Promise<number>;
  syncDiscoverPeers(): Promise<PeerInfoDto[]>;
  discoverPeers(): Promise<PeerInfoDto[]>;
  beginPairingAcceptWithAdvertising(): Promise<string>;
  beginPairingCredentialWithAdvertising(): Promise<PairingCredentialDisplayDto>;
  stopPairingAdvertising(): Promise<boolean>;
  acceptPairingRequestWithTimeout(timeoutMs: number): Promise<PairingRequestDto | null>;
  confirmPairing(code: string, request: PairingRequestDto): Promise<PairingResultDto>;
  beginPairingConnect(code: string, target: PeerInfoDto): Promise<PairingResultDto>;
  parsePairingCredential(credential: string): Promise<unknown>;
  beginPairingConnectWithCredential(credential: string): Promise<PairingResultDto>;
  /** 保存配对二维码 PNG：弹系统保存框写文件；返回保存路径，空串 = 用户取消。 */
  savePairingQrPng(credential: string): Promise<string>;
  /** 识别二维码图片：弹系统打开框选图；返回 cm1. 凭证，空串 = 用户取消。 */
  decodePairingQrFile(): Promise<string>;
}

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

// ─── 页面状态 ────────────────────────────────────────────────────────────────

const devices = signal<PairedDeviceDto[]>([]);
const loading = signal(true);
const loadError = signal<string | undefined>(undefined);
const deviceName = signal("");
const deviceId = signal("");
const localAddrs = signal<string[]>([]);
const actionMessage = signal<string | undefined>(undefined);
const busy = signal(false);

/** 连通检查状态：peerId → checking / latencyMs / failed。 */
type Connectivity = { kind: "checking" } | { kind: "ok"; latencyMs: number } | { kind: "failed" };
const connectivity = signal<Record<string, Connectivity>>({});

/** 解绑确认目标。 */
const unpairTarget = signal<PairedDeviceDto | undefined>(undefined);

/** 设备名编辑。 */
const editingName = signal(false);
const nameDraft = signal("");
const savingName = signal(false);

/** 配对流程：mode = 选方式弹窗 / 显示码 / 输入码。 */
type PairSheet = "none" | "choose" | "show" | "enter";
const pairSheet = signal<PairSheet>("none");

/** 显示码侧状态。 */
const pairCode = signal<string | undefined>(undefined);
/** 当前配对会话的 cm1. 签名凭证（渲染二维码图片用；undefined = 未生成）。 */
const pairCredential = signal<string | undefined>(undefined);
/** 「保存二维码图片」成功后的落盘路径（mutedInk 提示，非错误）。 */
const qrSavedPath = signal<string | undefined>(undefined);
/** 当前配对会话截止时间（epoch ms；用 Rust 返回的 expiresAt 绝对值，
 *  undefined = 未生成）。 */
const pairDeadlineMs = signal<number | undefined>(undefined);
const pairError = signal<string | undefined>(undefined);
const pairRemainingMs = signal(0);
/** 显示码轮次 token：重新生成/关闭时递增，使挂起的 accept 轮判废。 */
let pairGeneration = 0;
let countdownTimer: ReturnType<typeof setInterval> | undefined;

/** 输入码侧状态。 */
const enterInput = signal("");
const enterError = signal<string | undefined>(undefined);
const enterBusy = signal(false);

/** 「识别二维码图片」入口状态（choose 弹窗内展示：busy + 可读错误）。 */
const scanBusy = signal(false);
const scanError = signal<string | undefined>(undefined);

/** 发现对端。 */
const peers = signal<PeerInfoDto[]>([]);
const discovering = signal(false);
const peersLoaded = signal(false);

// ─── 文本工具（对照 Dart _isOnline/_relativeTime）───────────────────────────

function isOnline(d: PairedDeviceDto): boolean {
  if (d.lastSeen === null) return false;
  const t = Date.parse(d.lastSeen);
  if (Number.isNaN(t)) return false;
  return Date.now() - t <= onlineWindowMs;
}

function relativeTime(iso: string | null): string {
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

function formatCountdown(ms: number): string {
  if (ms <= 0) return "已过期，请重新生成";
  const totalSec = Math.ceil(ms / 1000);
  const m = Math.floor(totalSec / 60);
  const s = totalSec % 60;
  return `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
}

// ─── 数据加载 ────────────────────────────────────────────────────────────────

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
async function loadAllWithRetry(attempts = 3, delayMs = 250): Promise<void> {
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
function startBackgroundRefresh(): () => void {
  const timer = setInterval(() => {
    if (!loading()) void loadDevices(true);
  }, refreshIntervalMs);
  return () => clearInterval(timer);
}

// ─── 设备管理操作 ────────────────────────────────────────────────────────────

async function checkConnectivity(d: PairedDeviceDto): Promise<void> {
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

function requestUnpair(d: PairedDeviceDto): void {
  unpairTarget.set(d);
}

async function confirmUnpair(): Promise<void> {
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

function cancelUnpair(): void {
  unpairTarget.set(undefined);
}

function startEditName(): void {
  nameDraft.set(deviceName());
  editingName.set(true);
}

function cancelEditName(): void {
  editingName.set(false);
  nameDraft.set(deviceName());
}

async function saveDeviceName(): Promise<void> {
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

// ─── 发现对端 ────────────────────────────────────────────────────────────────

async function refreshPeers(): Promise<void> {
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

// ─── 配对：显示码（确认方）───────────────────────────────────────────────────

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
async function openShowCode(): Promise<void> {
  pairSheet.set("show");
  const gen = ++pairGeneration;
  await generatePairCode(gen);
  void runAcceptLoop(gen);
}

/** 重新生成（手动）：递增轮次 token → 旧 accept 轮判废退出 → 新轮次。 */
async function regeneratePairCode(): Promise<void> {
  if (pairSheet() !== "show") return;
  const gen = ++pairGeneration;
  await generatePairCode(gen);
  void runAcceptLoop(gen);
}

/** 「保存二维码图片」：把当前 cm1. 凭证渲染成二维码 PNG 写用户自选路径。
 *  空串返回 = 用户取消（不提示）；真错误进 pairError（danger 色）；
 *  成功路径进 qrSavedPath（mutedInk 提示）。
 *  对话框挂起期间若弹窗被关/凭证被重新生成（gen 变化），结果直接丢弃。 */
async function savePairingQrImage(): Promise<void> {
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
function closePairSheet(): void {
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

// ─── 配对：输入对方码（发起方）───────────────────────────────────────────────

function openEnterCode(): void {
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
async function scanPairingQrImage(): Promise<void> {
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
async function submitPeerCode(): Promise<void> {
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

/** 面板容器：surfaceRaised 卡 + border + md 圆角。 */
function Panel(props: { children?: JSX.Element | JSX.Element[] }): JSX.Element {
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
function LocalInfoCard(): JSX.Element {
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
                onChange={(t: string) => nameDraft.set(t)}
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
function checkLabel(c: Connectivity | undefined): string {
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
function DeviceRow(props: { device: () => PairedDeviceDto }): JSX.Element {
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
function PairModeRow(props: {
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

/** 「添加设备」弹窗：选配对方式（显示码 / 识别二维码图片 / 输入码）。 */
function PairChooseSheet(): JSX.Element {
  return (
    <Dialog open={pairSheet() === "choose"}>
      <View
        style={{
          flex: 1,
          alignItems: "center",
          justifyContent: "center",
          padding: spacing.xl,
          backgroundColor: colors.paper,
        }}
      >
        <Panel>
          <Text
            style={{
              fontSize: typography.titleMedium.fontSize,
              fontWeight: "600",
              color: colors.ink,
            }}
          >
            添加设备
          </Text>
          <Text style={{ fontSize: typography.bodyMedium.fontSize, color: colors.mutedInk }}>
            选择配对方式：
          </Text>
          <PairModeRow
            icon="add"
            title="我显示配对码"
            subtitle="对方扫码或输入我屏幕上的配对信息"
            onPress={() => void openShowCode()}
          />
          {/* 二维码图片路径（QR 任务）：选一张配对二维码图片自动完成配对；
              相机直扫仍需移动端平台能力（R3），本条不含直扫。 */}
          <PairModeRow
            icon="search"
            title="识别二维码图片"
            subtitle="选择一张配对二维码图片自动完成配对"
            onPress={() => void scanPairingQrImage()}
            disabled={scanBusy()}
          />
          {() =>
            scanBusy() ? (
              <Text style={{ color: colors.mutedInk, fontSize: typography.bodyMedium.fontSize }}>
                正在识别…
              </Text>
            ) : null
          }
          <If when={scanError() !== undefined}>
            <Text
              style={{
                color: colors.danger,
                fontSize: typography.bodyMedium.fontSize - 3,
              }}
            >
              {() => scanError() ?? ""}
            </Text>
          </If>
          <Text
            style={{
              fontSize: typography.bodyMedium.fontSize - 3,
              color: colors.mutedInk,
            }}
          >
            相机直扫需移动端平台能力（R3），暂不可用——请用上方的图片识别。
          </Text>
          <PairModeRow
            icon="edit"
            title="我输入对方的码"
            subtitle="输入或粘贴对方设备的配对码/配对信息"
            onPress={openEnterCode}
          />
          <View style={{ flexDirection: "row", justifyContent: "flex-end" }}>
            <View
              onPress={closePairSheet}
              role="button"
              accessibilityLabel="取消"
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
                取消
              </Text>
            </View>
          </View>
        </Panel>
      </View>
    </Dialog>
  );
}

/** 「我显示配对码」弹窗（对照 Dart _PairingAcceptDialog）：
 *  6 位码大字 + 倒计时（10 分钟有效）+ 等待/确认状态 + 重新生成 +
 *  「保存二维码图片」（QR 任务：cm1. 凭证 → PNG → 系统保存框，保存路径
 *  用 mutedInk 提示）。屏幕内不画 QR（NSH 无二维码绘制组件），二维码以
 *  图片文件形式交付给对方识别。 */
function PairShowSheet(): JSX.Element {
  const expiryText = () => {
    if (pairDeadlineMs() === undefined) return "";
    return formatCountdown(pairRemainingMs());
  };
  return (
    <Dialog open={pairSheet() === "show"}>
      <View
        style={{
          flex: 1,
          alignItems: "center",
          justifyContent: "center",
          padding: spacing.xl,
          backgroundColor: colors.paper,
        }}
      >
        <Panel>
          <Text
            style={{
              fontSize: typography.titleMedium.fontSize,
              fontWeight: "600",
              color: colors.ink,
            }}
          >
            配对信息
          </Text>
          {() => {
            if (pairCode() === undefined && pairError() === undefined) {
              return (
                <Text style={{ color: colors.mutedInk, fontSize: typography.bodyMedium.fontSize }}>
                  正在生成配对信息…
                </Text>
              );
            }
            return (
              <View style={{ gap: spacing.sm }}>
                <Text style={{ color: colors.mutedInk, fontSize: typography.bodyMedium.fontSize }}>
                  在对方设备「添加设备」中输入以下 6 位码（移动端也可扫码）：
                </Text>
                <Text
                  style={{
                    fontSize: typography.headlineSmall.fontSize,
                    lineHeight: typography.headlineSmall.lineHeight,
                    fontWeight: "600",
                    color: colors.accent,
                    letterSpacing: 4,
                    textAlign: "center",
                  }}
                >
                  {() => pairCode() ?? ""}
                </Text>
                <View
                  style={{
                    flexDirection: "row",
                    alignItems: "center",
                    gap: spacing.md,
                  }}
                >
                  <Text
                    style={{
                      fontSize: typography.bodyMedium.fontSize,
                      color:
                        pairRemainingMs() <= 0 ? colors.danger : colors.mutedInk,
                    }}
                  >
                    {() => expiryText()}
                  </Text>
                  <View style={{ flex: 1 }} />
                  <View
                    onPress={() => void regeneratePairCode()}
                    role="button"
                    accessibilityLabel="重新生成配对码"
                    style={{
                      minHeight: layout.mobileTouchTarget,
                      paddingHorizontal: spacing.md,
                      alignItems: "center",
                      justifyContent: "center",
                      borderRadius: radii.md,
                      borderWidth: 1,
                      borderColor: colors.border,
                    }}
                  >
                    <Text
                      style={{
                        fontSize: typography.bodyMedium.fontSize - 3,
                        color: colors.accent,
                        fontWeight: "600",
                      }}
                    >
                      重新生成
                    </Text>
                  </View>
                </View>
                {/* 保存二维码图片（QR 任务）：cm1. 凭证渲染成 PNG 写用户自选
                    路径；成功路径提示走 mutedInk，错误仍走 pairError 红字。 */}
                <View
                  onPress={() => void savePairingQrImage()}
                  role="button"
                  accessibilityLabel="保存二维码图片"
                  style={{
                    minHeight: layout.mobileTouchTarget,
                    paddingHorizontal: spacing.md,
                    alignItems: "center",
                    justifyContent: "center",
                    borderRadius: radii.md,
                    borderWidth: 1,
                    borderColor: colors.border,
                  }}
                >
                  <Text
                    style={{
                      fontSize: typography.bodyMedium.fontSize - 3,
                      color: colors.accent,
                      fontWeight: "600",
                    }}
                  >
                    保存二维码图片
                  </Text>
                </View>
                <If when={qrSavedPath() !== undefined}>
                  <Text
                    style={{
                      fontSize: typography.bodyMedium.fontSize - 3,
                      color: colors.mutedInk,
                    }}
                  >
                    {() => `已保存：${qrSavedPath() ?? ""}`}
                  </Text>
                </If>
                <Text
                  style={{
                    fontSize: typography.bodyMedium.fontSize - 3,
                    color: colors.mutedInk,
                  }}
                >
                  保存的图片可用对方设备「识别二维码图片」打开完成配对；相机直扫需移动端平台能力（R3）。
                </Text>
              </View>
            );
          }}
          <If when={pairError() !== undefined}>
            <Text
              style={{
                color: colors.danger,
                fontSize: typography.bodyMedium.fontSize - 3,
              }}
            >
              {() => pairError() ?? ""}
            </Text>
          </If>
          <If when={pairError() === undefined && pairCode() !== undefined}>
            <Text
              style={{
                color: colors.mutedInk,
                fontSize: typography.bodyMedium.fontSize - 3,
              }}
            >
              等待对方确认后自动完成配对…
            </Text>
          </If>
          <View style={{ flexDirection: "row", justifyContent: "flex-end" }}>
            <View
              onPress={closePairSheet}
              role="button"
              accessibilityLabel="关闭"
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
                关闭
              </Text>
            </View>
          </View>
        </Panel>
      </View>
    </Dialog>
  );
}

/** 「我输入对方的码」弹窗（对照 Dart _enterPeerCode）：单输入框 + 提交错误
 *  内联 + 提交中 busy。cm1 开头走凭证直连，6 位走 mDNS 发现。 */
function PairEnterSheet(): JSX.Element {
  return (
    <Dialog open={pairSheet() === "enter"}>
      <View
        style={{
          flex: 1,
          alignItems: "center",
          justifyContent: "center",
          padding: spacing.xl,
          backgroundColor: colors.paper,
        }}
      >
        <Panel>
          <Text
            style={{
              fontSize: typography.titleMedium.fontSize,
              fontWeight: "600",
              color: colors.ink,
            }}
          >
            输入对方配对信息
          </Text>
          <View
            style={{
              borderWidth: 1,
              borderColor: colors.border,
              borderRadius: radii.md,
              backgroundColor: colors.surfaceRaised,
            }}
          >
            <Input
              value={enterInput()}
              onChange={(t: string) => enterInput.set(t)}
              onSubmit={() => void submitPeerCode()}
              placeholder="输入 6 位配对码，或粘贴以 cm1 开头的配对信息"
              accessibilityLabel="配对码或配对信息"
              style={{
                minHeight: layout.mobileTouchTarget,
                fontSize: typography.bodyMedium.fontSize,
                color: colors.ink,
                paddingHorizontal: spacing.md,
              }}
            />
          </View>
          <If when={enterBusy()}>
            <Text style={{ color: colors.mutedInk, fontSize: typography.bodyMedium.fontSize }}>
              正在连接…
            </Text>
          </If>
          <If when={enterError() !== undefined}>
            <Text
              style={{
                color: colors.danger,
                fontSize: typography.bodyMedium.fontSize - 3,
              }}
            >
              {() => enterError() ?? ""}
            </Text>
          </If>
          <View style={{ flexDirection: "row", justifyContent: "flex-end", gap: spacing.sm }}>
            <View
              onPress={closePairSheet}
              role="button"
              accessibilityLabel="取消"
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
                取消
              </Text>
            </View>
            <View
              onPress={enterBusy() ? undefined : () => void submitPeerCode()}
              role="button"
              accessibilityLabel="确认配对"
              accessibilityState={{ disabled: enterBusy() }}
              style={{
                minHeight: layout.mobileTouchTarget,
                paddingHorizontal: spacing.lg,
                alignItems: "center",
                justifyContent: "center",
                borderRadius: radii.md,
                backgroundColor: colors.accent,
                opacity: enterBusy() ? 0.4 : 1,
              }}
            >
              <Text
                style={{
                  color: colors.surfaceRaised,
                  fontSize: typography.bodyMedium.fontSize,
                  fontWeight: "600",
                }}
              >
                确认配对
              </Text>
            </View>
          </View>
        </Panel>
      </View>
    </Dialog>
  );
}

// ─── 页面根 ─────────────────────────────────────────────────────────────────

/**
 * 设备页：本机信息 + 「添加设备」+ 已配对列表 + 发现对端。
 *
 * `status` 插槽：调用方传入的状态面板（App.tsx 的 Phase 1 后端证据行）。
 */
export function DevicesPage(props: { status?: JSX.Element }): JSX.Element {
  effect(() => {
    void loadAllWithRetry();
  });
  // 后台周期刷新（在线状态）+ 倒计时定时器都在 cleanup 里释放。
  const stopRefresh = startBackgroundRefresh();
  cleanup(() => {
    stopRefresh();
    stopCountdown();
    pairGeneration += 1;
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