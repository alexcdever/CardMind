use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use anyhow::{Context, Result};
use atomic_write_file::AtomicWriteFile;
use chrono::{DateTime, Utc};
use iroh::{
    endpoint::presets, Endpoint, EndpointAddr, PublicKey, RelayMode, SecretKey, Signature,
    TransportAddr,
};
use loro::{Container, ExportMode, LoroDoc, LoroValue, ValueOrContainer};
use rand::Rng;
use uuid::Uuid;

use crate::debug_log::{self, LogEvent, LogSink, PlatformSink};
use crate::discovery::{DiscoveryService, PeerInfo};
use crate::store::NoteStore;

/// 同步服务 — 管理笔记集合并通过 iroh 与对端同步
pub struct SyncService {
    /// 可变核心状态（notes/tombstones/持久化路径）。
    ///
    /// 以 `Arc<Mutex<...>>` 共享：后台接收任务（任务 O）与主服务都能安全访问，
    /// 实现"收到 push 立即 import + 投影 + last_seen"，不占用 FRB opaque 锁。
    core: Arc<Mutex<CoreState>>,
    endpoint: Endpoint,
    /// 构造时使用的 relay 模式（任务 K 配置化：默认 Disabled 仅局域网；
    /// 持久化版读取 `<数据目录>/relay.txt` 可配置 Custom）
    relay_mode: RelayMode,
    /// 本设备持久化 SecretKey（构造时克隆保留，供凭证签名；不暴露、不落库）
    secret_key: SecretKey,
    /// 当前配对码会话（内存态；10 分钟有效，重启失效可接受——用户重新发起）
    pairing_session: Mutex<Option<PairingSession>>,
    /// 确认方已接收、等待用户确认的配对请求及其连接（确认时回复握手响应）。
    /// Arc 共享：后台接收任务（任务 O）与主服务路由到同一 pending_pairing。
    pending_pairing: Arc<Mutex<Option<PendingPairing>>>,
    /// 本设备名（配对握手时发送给对端；默认取主机名）
    device_name: Mutex<String>,
    /// 同步开关（决策 6 能力）：false 时调度器暂停推送与拉取。
    /// 移动端由 Flutter 侧按网络类型（WiFi vs 蜂窝）设置；桌面端恒 true。
    sync_allowed: AtomicBool,
    /// 待同步笔记 id 集合（本地编辑成功后标记；成功推送后清空）。
    /// 内存态：不持久化（保守正确——重启后经持久化加载重标全部待同步）。
    pending_dirty: Mutex<HashSet<String>>,
    /// note_id → 最后成功推送时间（模块 5 待同步计数基础；内存态不持久化）
    last_pushed_at: Mutex<HashMap<String, DateTime<Utc>>>,
    /// peer_id → 最近已知直连 IP 列表（配对请求/配对目标时记录；供周期推送直连优先）
    peer_ips: Mutex<HashMap<String, Vec<String>>>,
    /// mDNS 发现服务（任务 J 惰性创建）：配对期间广播 + 发起方扫描。
    ///
    /// 用 tokio Mutex：`discover_peers` 需跨 await 持锁，FRB async 要求
    /// Send future（std MutexGuard 非 Send，跨 await 编译不过）。
    discovery: tokio::sync::Mutex<Option<DiscoveryService>>,
    /// 后台接收任务状态（任务 O：持续 accept 对端 push；start/stop 幂等）。
    receiver: Mutex<ReceiverHandle>,
    /// 调试日志 sink（实例级；测试注入收集/异常 sink 断言事件）。
    log: Arc<dyn LogSink>,
    /// verbose 日志开关（debug 提高详细程度；默认 false 只输出常规事件）。
    log_verbose: AtomicBool,
}

/// 可被主服务与后台接收任务共享的可变核心状态。
struct CoreState {
    notes: HashMap<String, NoteCrdt>,
    /// 已彻底删除的笔记 id 集合（墓碑）。删除信息随快照传播，防止
    /// `sync_notes_to_store` 从 Loro 快照重建被删笔记（复活）。
    tombstones: HashSet<String>,
    persistent_path: Option<PathBuf>,
}

/// 后台接收任务句柄（start/stop 幂等管理）。
#[derive(Default)]
struct ReceiverHandle {
    /// 停止信号（接收任务轮询；置 true 后任务在下一 accept 窗口结束前退出）
    cancel: Option<Arc<AtomicBool>>,
    /// 接收任务句柄（stop 时等待结束；有界 3 秒）
    join: Option<tokio::task::JoinHandle<()>>,
}

/// 后台接收任务的独立上下文（endpoint clone + 共享 core + store clone + 日志）。
///
/// 不持有 `&SyncService`：接收任务生命周期独立于 FRB opaque 锁，start 时拷贝所需
/// 全部引用（endpoint/core/log/store），停止/关闭后任务自然退出，不留下永久 task。
struct ReceiverContext {
    endpoint: Endpoint,
    core: Arc<Mutex<CoreState>>,
    /// 共享配对路由状态（与主服务同一 pending_pairing——配对帧不丢、不互抢）
    pending_pairing: Arc<Mutex<Option<PendingPairing>>>,
    store: NoteStore,
    log: Arc<dyn LogSink>,
    device_id: String,
    log_verbose: bool,
    cancel: Arc<AtomicBool>,
    /// 连续空闲窗口计数（健康检查/诊断日志用）
    idle_windows: u64,
}

/// 接收器单次 accept 窗口（任务 O：短窗口循环，与配对 accept 轮询同粒度）。
const RECEIVER_ACCEPT_WINDOW: Duration = Duration::from_millis(300);
/// 接收器处理单个 incoming（握手 + 读帧）的超时上限（防恶意/慢连接拖死任务）。
const RECEIVER_PROCESS_TIMEOUT: Duration = Duration::from_secs(10);
/// stop_receiver 等待接收任务结束的硬上限（验收：3 秒内返回）。
const RECEIVER_STOP_TIMEOUT: Duration = Duration::from_secs(3);

/// NoteCrdt — LoroDoc 笔记模型
///
/// 每个笔记一个独立的 LoroDoc，支持创建/读写/快照/增量同步。
/// 正文存于 `content` Text 容器；元数据（tags/created_at/updated_at）存于 `meta` Map 容器。
#[derive(Clone)]
pub struct NoteCrdt {
    doc: LoroDoc,
}

const ALPN: &[u8] = b"cardmind-v2";
const LORO_MAGIC: &[u8; 8] = b"CARDMIND";
/// envelope 版本：
/// - v1：旧纯文本格式（迁移路径）
/// - v2：记录流（无墓碑 section）
/// - v3：墓碑 section + 记录流
const LORO_VERSION: u32 = 3;
const LORO_HEADER_LEN: usize = 8 + 4 + 8;

// ━━━ SyncService ━━━

/// 单设备推送结果：peer_id + 成功/失败信息
#[derive(Debug, Clone)]
pub struct DevicePushResult {
    pub peer_id: String,
    pub ok: bool,
    /// 失败原因（成功时为空）
    pub message: String,
}

// ━━━ 自动同步调度（任务 H）━━━

/// 周期拉取间隔（秒）。决策 4 的实现参数：同网段约 30 秒、跨网段约 5 分钟；
/// 本实现为可调常量，默认 60 秒（任务单定稿）。
pub const SYNC_POLL_INTERVAL_SECS: u64 = 60;

/// 周期 accept 对端 push 的等待窗口（非阻塞拉取；到点返回 None，不长期占用
/// accept 通道——避免与配对 accept 争用）。
pub const SYNC_ACCEPT_WINDOW: Duration = Duration::from_secs(2);

/// 一次周期同步的结果（FRB 可序列化，供 Flutter 侧诊断/未来 UI 使用）
#[derive(Debug, Clone)]
pub struct SyncCycleResult {
    /// 成功推送的对端设备数（0 = 本轮无成功推送）
    pub pushed_count: u32,
    /// 本轮是否 accept 到对端 push 并导入
    pub accepted_push: bool,
    /// 同步开关关闭导致整轮跳过
    pub disabled: bool,
}

// ━━━ 配对（任务 G）━━━

/// 配对码会话（内存态；10 分钟有效）
///
/// 字段公开以便测试直接操纵状态（如拨回 created_at 验证过期）。
#[derive(Debug, Clone)]
pub struct PairingSession {
    /// 6 位数字配对码
    pub code: String,
    /// 创建时间（10 分钟有效窗口的起点）
    pub created_at: DateTime<Utc>,
    /// 同一码连续错误次数（≥5 时会话失效，防暴力猜测）
    pub failed_attempts: u32,
    /// 一次性会话标识（签名凭证与 6 位码共用；重新生成必须更换）
    pub nonce: [u8; 16],
}

/// 发起方配对请求（含本机身份与配对码，经网络发送给确认方）
#[derive(Debug, Clone)]
pub struct PairingRequest {
    /// 配对码（发起方从确认方展示处获得；请求携带以便确认方校验匹配）
    pub code: String,
    /// 发起方 iroh 节点 ID（device_id）
    pub device_id: String,
    /// 发起方设备名
    pub device_name: String,
    /// 发起方 relay 信息（配置的 relay URL 列表，逗号分隔）。
    ///
    /// 说明：N0 preset 已通过 PkarrPublisher 自动发布本端点地址（含 relay）到
    /// n0 DNS（iroh.link），此字段仅为协议完整性保留（信息性）。
    pub relay_info: String,
    /// 发起方 IPv4 地址列表（"ip:port"，供确认方直连/推送加速）
    pub ips: Vec<String>,
    /// 一次性会话 nonce（hex 字符串；凭证路径来自凭证；6 位码路径来自 mDNS TXT）。
    /// 确认方校验请求 nonce 必须与当前 PairingSession 一致。
    pub nonce: String,
}

/// 配对结果（对端身份）
#[derive(Debug, Clone)]
pub struct PairingResult {
    /// 对端 iroh 节点 ID
    pub peer_id: String,
    /// 对端设备名
    pub peer_name: String,
}

/// 发起方要连接的确认方目标（同网段配对场景由 mDNS 发现提供 device_id + ip:port）
#[derive(Debug, Clone)]
pub struct PairingTarget {
    /// 确认方 iroh 节点 ID（device_id）
    pub device_id: String,
    /// 确认方 IP 列表（"ip:port"）。空时经 n0 地址解析 + 公共 relay 连接
    /// （iroh 1.x N0 preset 的 DnsAddressLookup 机制）；非空时直连优先。
    pub ips: Vec<String>,
    /// 确认方当前会话 nonce（hex 字符串；凭证路径直接内嵌；6 位码路径来自 mDNS TXT）。
    /// 构造请求时写入 PairingRequest.nonce。
    pub nonce: String,
}

/// 确认方已接收、等待用户确认的配对请求 + 其连接（确认时在同一连接上回复握手响应）
struct PendingPairing {
    request: PairingRequest,
    conn: iroh::endpoint::Connection,
}

/// 确认方握手响应（确认方 → 发起方）
#[derive(Debug, Clone)]
struct PairingResponse {
    device_id: String,
    device_name: String,
}

/// 配对码有效期（分钟）
const PAIRING_CODE_TTL_MINUTES: i64 = 10;
/// 同一码允许的连续错误次数（超限会话失效）
const PAIRING_MAX_FAILED_ATTEMPTS: u32 = 5;

// 配对握手线协议标记（帧内首字节）
const PAIRING_FRAME_REQUEST: u8 = 0x01;
const PAIRING_FRAME_RESPONSE: u8 = 0x02;

impl SyncService {
    /// 创建同步服务，绑定随机的 iroh 端点（内存版：SecretKey 随机，测试用）。
    ///
    /// 内存版 relay 固定 `RelayMode::Disabled`（任务 K：不读 relay.txt，测试隔离）。
    pub async fn new() -> Result<Self> {
        Self::build(None, Arc::new(PlatformSink)).await
    }

    /// 创建持久化同步服务。`path` 可以是数据目录，也可以直接是 `.loro` 文件路径。
    ///
    /// 设备身份持久化：在数据目录（path 父目录）加载/生成 `device.key`（32 字节
    /// hex），使 device_id 跨重启稳定。
    ///
    /// relay 配置（任务 K）：读取数据目录下的 `relay.txt`（单行 relay URL）。
    /// 无文件/空内容 → `RelayMode::Disabled`（默认仅局域网，零配置）；有 URL →
    /// `RelayMode::Custom`；URL 无效 → 返回 Err（fail fast，配置错误显式报错）。
    pub async fn new_persistent(path: impl AsRef<Path>) -> Result<Self> {
        Self::build(Some(path.as_ref()), Arc::new(PlatformSink)).await
    }

    /// 测试钩子：持久化构造并注入日志 sink（断言事件用；生产不调用）。
    pub async fn new_persistent_with_log_sink(
        path: impl AsRef<Path>,
        log: Arc<dyn LogSink>,
    ) -> Result<Self> {
        Self::build(Some(path.as_ref()), log).await
    }

    /// 测试钩子：内存版构造并注入日志 sink（断言事件用；生产不调用）。
    pub async fn new_with_log_sink(log: Arc<dyn LogSink>) -> Result<Self> {
        Self::build(None, log).await
    }

    /// 统一构造：`path = None` → 内存版（隔离，不读文件）；`Some` → 持久化版。
    async fn build(path: Option<&Path>, log: Arc<dyn LogSink>) -> Result<Self> {
        let path = path.map(loro_path);
        let data_dir = path
            .as_ref()
            .and_then(|p| p.parent().map(Path::to_path_buf));
        if let Some(parent) = &data_dir {
            std::fs::create_dir_all(parent)
                .with_context(|| format!("create data directory {}", parent.display()))?;
        }
        let key = load_or_create_secret_key(data_dir.as_deref())?;
        let secret_key_for_signing = key.clone();
        let relay_mode = load_relay_mode(data_dir.as_deref())?;
        let endpoint = Endpoint::builder(presets::N0)
            .secret_key(key)
            .alpns(vec![ALPN.to_vec()])
            .relay_mode(relay_mode.clone())
            .bind()
            .await
            .context("bind iroh endpoint")?;
        let mut service = Self {
            core: Arc::new(Mutex::new(CoreState {
                notes: HashMap::new(),
                tombstones: HashSet::new(),
                persistent_path: path.clone(),
            })),
            endpoint,
            relay_mode,
            secret_key: secret_key_for_signing,
            pairing_session: Mutex::new(None),
            pending_pairing: Arc::new(Mutex::new(None)),
            device_name: Mutex::new(default_device_name()),
            sync_allowed: AtomicBool::new(true),
            pending_dirty: Mutex::new(HashSet::new()),
            last_pushed_at: Mutex::new(HashMap::new()),
            peer_ips: Mutex::new(HashMap::new()),
            discovery: tokio::sync::Mutex::new(None),
            receiver: Mutex::new(ReceiverHandle::default()),
            log,
            log_verbose: AtomicBool::new(false),
        };
        if let Some(path) = &path {
            if path.exists() {
                let bytes = std::fs::read(path)
                    .with_context(|| format!("read Loro file {}", path.display()))?;
                let (version, payload) = decode_envelope(&bytes)?;
                service.import_raw(version, &payload)?;
                // 重启后全部视为待同步（last_pushed_at 不持久化，保守正确——对端状态未知）
                service.mark_all_pending();
                if version == 1 {
                    // ━━━ v1 → v2 迁移 ━━━
                    // 先备份原始 v1 文件，再逐 note 迁移：
                    //   1. 提取 `<!--tags:...-->` 中的 tag 字符串 → split(',') 写入 meta tags
                    //   2. 正文去掉 `<!--tags:...-->` 行
                    //   3. meta.created_at / updated_at = 当前时间
                    let backup = path.with_extension("loro.v1.bak");
                    std::fs::copy(path, &backup)
                        .with_context(|| format!("backup v1 file to {}", backup.display()))?;
                    let now = chrono::Utc::now().to_rfc3339();
                    let note_ids: Vec<String> = {
                        let core = service.core.lock().unwrap();
                        core.notes.keys().cloned().collect()
                    };
                    for note_id in note_ids {
                        let core = service.core.lock().unwrap();
                        let Some(note) = core.notes.get(&note_id) else {
                            continue;
                        };
                        let content = note.get_content();
                        let tags_str = extract_tag_marker(&content);
                        if !tags_str.is_empty() {
                            let tags: Vec<String> = tags_str
                                .split(',')
                                .map(|s| s.trim().to_string())
                                .filter(|s| !s.is_empty())
                                .collect();
                            note.set_tags(&tags);
                        }
                        let clean = remove_tag_marker(&content);
                        if clean != content {
                            note.set_content(&clean);
                        }
                        note.set_created_at(&now);
                        note.set_updated_at(&now);
                    }
                    // 迁移全部完成后再以 v3 写回
                    service.persist()?;
                }
            } else if let Some(parent) = path.parent() {
                let legacy_db = parent.join("cardmind.db");
                if legacy_db.exists() {
                    let store = NoteStore::new(&legacy_db.to_string_lossy())?;
                    for (id, content) in store.legacy_notes()? {
                        let note = NoteCrdt::new();
                        note.set_content(&content);
                        service.core.lock().unwrap().notes.insert(id, note);
                    }
                    service.persist()?;
                }
            }
        }
        service.emit_startup_events();
        Ok(service)
    }

    /// 启动事件：初始化成功、relay 配置、本机身份（全部脱敏）。
    fn emit_startup_events(&self) {
        let device_id = self.device_id();
        let notes_loaded = self.core.lock().unwrap().notes.len();
        let mut startup = LogEvent::new("startup.sync_service", "sync.init")
            .with_id(&device_id)
            .with_field("action", "success")
            .with_field("notes_loaded", notes_loaded.to_string());
        let (relay_enabled, relay_host, relay_port) = relay_endpoint(&self.relay_mode);
        if relay_enabled {
            startup = startup
                .with_field("relay_enabled", "true")
                .with_field("relay_host", relay_host.clone().unwrap_or_default())
                .with_field(
                    "relay_port",
                    relay_port.map(|p| p.to_string()).unwrap_or_default(),
                );
        } else {
            startup = startup.with_field("relay_enabled", "false");
        }
        self.emit_log(startup);

        // 独立 relay.config 事件（host/port/enabled；绝不记录凭据/完整 URL）
        let mut relay_event = LogEvent::new("relay.config", "sync.init").with_id(&device_id);
        if relay_enabled {
            relay_event = relay_event
                .with_field("enabled", "true")
                .with_field("relay_host", relay_host.unwrap_or_default())
                .with_field(
                    "relay_port",
                    relay_port.map(|p| p.to_string()).unwrap_or_default(),
                );
        } else {
            relay_event = relay_event.with_field("enabled", "false");
        }
        self.emit_log(relay_event);

        // 本机身份（脱敏）
        self.emit_log(LogEvent::new("identity.device_id", "identity").with_id(&device_id));
    }

    /// 输出日志事件：verbose 开关过滤 + sink 异常兜底（绝不打断主流程）。
    fn emit_log(&self, event: LogEvent) {
        if event.verbose && !self.log_verbose.load(Ordering::Relaxed) {
            return;
        }
        debug_log::emit_to(&self.log, event);
    }

    /// 设置 verbose 日志开关（debug 提高详细程度；默认 false）。
    pub fn set_log_verbose(&self, verbose: bool) {
        self.log_verbose.store(verbose, Ordering::Relaxed);
    }

    /// 获取本设备 iroh 身份 ID
    pub fn device_id(&self) -> String {
        self.endpoint.id().to_string()
    }

    /// 构造时使用的 relay 模式（任务 K：默认 `Disabled` 仅局域网；
    /// 持久化版经 `relay.txt` 可配置 `Custom`）
    pub fn relay_mode(&self) -> &RelayMode {
        &self.relay_mode
    }

    /// 本端点当前绑定的 IPv4 地址（`"ip:port"` 格式，用于直连/mDNS 广播）
    pub fn local_addrs(&self) -> Vec<String> {
        self.endpoint
            .addr()
            .ip_addrs()
            .filter(|a| a.is_ipv4())
            .map(|a| a.to_string())
            .collect()
    }

    /// 本设备名（配对握手时发送给对端；默认取主机名）
    pub fn device_name(&self) -> String {
        self.device_name.lock().unwrap().clone()
    }

    /// 设置本设备名
    pub fn set_device_name(&self, name: &str) {
        *self.device_name.lock().unwrap() = name.to_string();
    }

    // ━━━ 配对码（任务 G）━━━

    /// 确认方：生成 6 位数字配对码（密码学随机），10 分钟有效。返回码。
    ///
    /// 配对码存内存态（`pairing_session`），同一 SyncService 实例跨调用保留；
    /// 重启失效可接受——用户重新发起。
    pub fn begin_pairing_accept(&self) -> Result<String> {
        let mut rng = rand::rngs::OsRng;
        let code_num: u32 = rng.gen_range(100000..=999999);
        let code = format!("{code_num:06}");
        let nonce: [u8; 16] = rng.gen();
        let session = PairingSession {
            code: code.clone(),
            created_at: Utc::now(),
            failed_attempts: 0,
            nonce,
        };
        *self.pairing_session.lock().unwrap() = Some(session);
        // 新码产生时清除上一次未完成的待确认请求（避免旧连接回复错码）
        *self.pending_pairing.lock().unwrap() = None;
        // 显示配对码：开始/成功（**绝不记录码本身**）
        self.emit_log(
            LogEvent::new("pairing.show_code", "pairing.show_code")
                .with_id(&self.device_id())
                .with_field("action", "success"),
        );
        Ok(code)
    }

    // ━━━ mDNS 自动发现接线（任务 J）━━━

    /// 本端点当前监听端口（mDNS 广播用；与 `local_addrs` 同源）。
    fn endpoint_listen_port(&self) -> u16 {
        self.endpoint
            .addr()
            .ip_addrs()
            .next()
            .map(|a| a.port())
            .unwrap_or(0)
    }

    /// 确认方：生成 6 位配对码并启动 mDNS 广播（组合 API，任务 J）。
    ///
    /// 码与广播在同一调用内完成——配对期间广播一定在，Flutter 侧无需自行
    /// 组合两个 API。port 用本端点实际监听端口（对端直连需要）；
    /// `start_advertising` 内部会先停旧广播再注册新广播。
    /// 停止广播由 [`Self::stop_pairing_advertising`] 负责（弹窗关闭等）。
    pub async fn begin_pairing_accept_with_advertising(&self) -> Result<String> {
        let started = std::time::Instant::now();
        let code = self.begin_pairing_accept()?;
        // 当前会话 nonce（hex），随 mDNS TXT 广播，供发起方回填 PairingTarget
        let nonce_hex = self
            .pairing_session
            .lock()
            .unwrap()
            .as_ref()
            .map(|s| nonce_to_hex(&s.nonce))
            .unwrap_or_default();
        let port = self.endpoint_listen_port();
        let mut guard = self.discovery.lock().await;
        if guard.is_none() {
            *guard = Some(DiscoveryService::new()?);
        }
        let result = guard
            .as_mut()
            .expect("discovery just ensured")
            .start_advertising(&self.device_id(), port, &nonce_hex);
        let duration = started.elapsed();
        match &result {
            Ok(()) => {
                // 广播启动（事件 #5：显示配对码：广播启动）
                self.emit_log(
                    LogEvent::new("pairing.advertise", "pairing.advertise")
                        .with_id(&self.device_id())
                        .with_field("action", "start")
                        .with_field("port", port.to_string())
                        .with_duration(duration),
                );
            }
            Err(e) => {
                self.emit_log(
                    LogEvent::new("pairing.advertise", "pairing.advertise")
                        .with_id(&self.device_id())
                        .with_field("action", "failed")
                        .with_error(&e.to_string())
                        .with_chain(&format!("{e:#}"))
                        .with_duration(duration),
                );
            }
        }
        result?;
        Ok(code)
    }

    /// 停止 mDNS 广播（弹窗关闭 / 配对完成 / 取消时调用；幂等）。
    ///
    /// DiscoveryService 实例保留（后续再组合调用时复用 daemon），仅注销注册。
    pub async fn stop_pairing_advertising(&self) -> Result<()> {
        let started = std::time::Instant::now();
        let result: Result<()> = (async {
            let mut guard = self.discovery.lock().await;
            if let Some(disc) = guard.as_mut() {
                disc.stop_advertising()?;
            }
            Ok(())
        })
        .await;
        let duration = started.elapsed();
        // 清理事件（事件 #11：mDNS/relay/socket 清理）
        match &result {
            Ok(()) => {
                self.emit_log(
                    LogEvent::new("cleanup.mdns", "cleanup")
                        .with_id(&self.device_id())
                        .with_field("action", "stop_advertising")
                        .with_field("ok", "true")
                        .with_duration(duration),
                );
            }
            Err(e) => {
                self.emit_log(
                    LogEvent::new("cleanup.mdns", "cleanup")
                        .with_id(&self.device_id())
                        .with_field("action", "stop_advertising")
                        .with_field("ok", "false")
                        .with_error(&e.to_string())
                        .with_chain(&format!("{e:#}"))
                        .with_duration(duration),
                );
            }
        }
        result
    }

    /// 发起方：mDNS 扫描局域网内的 CardMind 设备（约 3 秒超时，任务 J）。
    ///
    /// 复用共享 DiscoveryService（惰性创建）；返回对端 device_id + ip:port，
    /// 供 UI 在设备 ID 留空时自动填充配对目标。扫描超时或通道断开返回
    /// 已收集的结果（可能为空），不报错。
    pub async fn discover_peers(&self) -> Result<Vec<PeerInfo>> {
        let started = std::time::Instant::now();
        // 事件 #4：设备发现开始
        self.emit_log(
            LogEvent::new("discovery.mdns", "discovery.mdns")
                .with_id(&self.device_id())
                .with_field("action", "start"),
        );
        let result: Result<Vec<PeerInfo>> = (async {
            let mut guard = self.discovery.lock().await;
            if guard.is_none() {
                *guard = Some(DiscoveryService::new()?);
            }
            guard
                .as_mut()
                .expect("discovery just ensured")
                .discover_peers()
                .await
        })
        .await;
        let duration = started.elapsed();
        // 事件 #4：发现数量 + 耗时；verbose 时附候选 id（脱敏）
        match &result {
            Ok(peers) => {
                let mut ev = LogEvent::new("discovery.mdns", "discovery.mdns")
                    .with_id(&self.device_id())
                    .with_field("action", "result")
                    .with_field("count", peers.len().to_string())
                    .with_duration(duration);
                if self.log_verbose.load(Ordering::Relaxed) && !peers.is_empty() {
                    let candidates: Vec<String> = peers
                        .iter()
                        .map(|p| debug_log::redact_device_id(&p.device_id))
                        .collect();
                    ev = ev
                        .with_field("candidates", candidates.join(","))
                        .with_verbose();
                }
                self.emit_log(ev);
            }
            Err(e) => {
                self.emit_log(
                    LogEvent::new("discovery.mdns", "discovery.mdns")
                        .with_id(&self.device_id())
                        .with_field("action", "failed")
                        .with_error(&e.to_string())
                        .with_chain(&format!("{e:#}"))
                        .with_duration(duration),
                );
            }
        }
        result
    }

    /// 当前配对会话（测试/诊断用）。
    pub fn current_pairing_session(&self) -> Option<PairingSession> {
        self.pairing_session.lock().unwrap().clone()
    }

    /// 当前会话 nonce 的 hex 字符串（测试/广播用；无会话时为空串）。
    ///
    /// 6 位码路径发起方必须把该值回填到 `PairingTarget.nonce`，confirm 侧
    /// 强制校验（空/全零/不匹配均拒绝）。测试构造请求时用它取真实 nonce。
    pub fn session_nonce_hex(&self) -> String {
        self.pairing_session
            .lock()
            .unwrap()
            .as_ref()
            .map(|s| nonce_to_hex(&s.nonce))
            .unwrap_or_default()
    }

    /// 覆盖当前配对会话（测试用：注入过期时间等）。
    pub fn set_current_pairing_session(&self, session: Option<PairingSession>) {
        *self.pairing_session.lock().unwrap() = session;
    }

    /// 校验配对码：存在、未过期、未因连续错误超限。
    ///
    /// - 过期 → 清除会话，报 expired
    /// - 连续错误 ≥ 5 次 → 会话失效（后续任何码都失败，需重新发起）
    /// - 错误码 → 累计错误次数
    fn validate_pairing_code(&self, code: &str) -> Result<()> {
        let mut guard = self.pairing_session.lock().unwrap();
        let Some(session) = guard.as_mut() else {
            anyhow::bail!("no active pairing code: begin_pairing_accept first");
        };
        let age = Utc::now() - session.created_at;
        if age.num_minutes() >= PAIRING_CODE_TTL_MINUTES {
            *guard = None;
            anyhow::bail!("pairing code expired after {PAIRING_CODE_TTL_MINUTES} minutes");
        }
        if session.failed_attempts >= PAIRING_MAX_FAILED_ATTEMPTS {
            *guard = None;
            anyhow::bail!(
                "pairing code invalidated after {PAIRING_MAX_FAILED_ATTEMPTS} failed attempts"
            );
        }
        if session.code != code {
            session.failed_attempts += 1;
            if session.failed_attempts >= PAIRING_MAX_FAILED_ATTEMPTS {
                *guard = None;
            }
            anyhow::bail!("invalid pairing code");
        }
        Ok(())
    }

    /// 确认方：阻塞接收发起方的配对请求（等待发起方连接），存储待确认状态。
    ///
    /// 返回请求内容；调用方随后调 `confirm_pairing` 完成配对（在存储的连接上
    /// 回复握手响应）。持有 iroh 监听能力（已有 accept_push 同机制）。
    ///
    /// 周期同步的 accept 与配对共用同一 endpoint 通道：本方法内部轮询
    /// `pending_pairing`（可能被统一路由 accept_incoming_routed 填充），
    /// 并用短窗口 accept——配对请求被周期 accept 抢到时也能正确路由，不冲突。
    ///
    /// **推送帧不丢失**（M1 修复）：等待期间若抢到的是对端推送（非配对帧），
    /// 立即 `import_all` 导入（而不是丢弃）——否则对端 `push_to_peer` 因连接
    /// 被 accept 并关闭而判定成功、清空 pending，推送数据被静默吞掉。
    /// 导入失败仅记录日志（不中断配对等待），数据由对端下个周期兜底。
    ///
    /// 实现委托 [`Self::accept_pairing_request_with_timeout`]（有界核心）；此处
    /// 用 24 小时边界保持"无限等待"语义（任务 M 决策点 1：有界核心可安全释放）。
    pub async fn accept_pairing_request(&mut self) -> Result<PairingRequest> {
        match self
            .accept_pairing_request_with_timeout(Duration::from_secs(24 * 3600))
            .await?
        {
            Some(request) => Ok(request),
            None => anyhow::bail!("pairing accept timed out"),
        }
    }

    /// 确认方：在 [timeout] 内接收发起方配对请求（**有界等待**；超时返回 None）。
    ///
    /// 任务 M（显示码流程启动确认方接收器）决策点 1 的落点：FRB opaque 上的
    /// 阻塞等待无法被安全取消，必须有限界——UI 侧以短窗口（10s）轮询调用本方法，
    /// 弹窗关闭/取消后等待任务在窗口内释放，不留下永久阻塞任务、不占用
    /// SyncService 锁超过一个窗口。总时限由 Flutter 侧控制。
    ///
    /// 语义与 [`Self::accept_pairing_request`] 一致：内部以 500ms 粒度轮询
    /// `endpoint.accept()`（配对帧 → pending_pairing；推送帧 → 立即导入不丢失），
    /// 外层 deadline 到点返回 `Ok(None)`。每个 accept 窗口均被
    /// `tokio::time::timeout` 保护（阻塞网络操作两侧都限时）。
    pub async fn accept_pairing_request_with_timeout(
        &mut self,
        timeout: Duration,
    ) -> Result<Option<PairingRequest>> {
        let started = std::time::Instant::now();
        // 事件 #5：确认方 accept loop 启动
        self.emit_log(
            LogEvent::new("pairing.accept", "pairing.accept")
                .with_id(&self.device_id())
                .with_field("action", "start")
                .with_field("timeout_ms", timeout.as_millis().to_string()),
        );
        let result = self.accept_pairing_request_loop(timeout).await;
        let duration = started.elapsed();
        match &result {
            Ok(Some(request)) => {
                // 事件 #6：请求接收（脱敏对端 id）
                self.emit_log(
                    LogEvent::new("pairing.request", "pairing.request")
                        .with_id(&self.device_id())
                        .with_id(&request.device_id)
                        .with_field("action", "received")
                        .with_field("peer_name", request.device_name.clone())
                        .with_duration(duration),
                );
                self.emit_log(
                    LogEvent::new("pairing.accept", "pairing.accept")
                        .with_id(&self.device_id())
                        .with_field("action", "end")
                        .with_field("outcome", "request_received")
                        .with_duration(duration),
                );
            }
            Ok(None) => {
                // 事件 #5：超时
                self.emit_log(
                    LogEvent::new("pairing.accept", "pairing.accept")
                        .with_id(&self.device_id())
                        .with_field("action", "end")
                        .with_field("outcome", "timeout")
                        .with_duration(duration),
                );
            }
            Err(e) => {
                self.emit_log(
                    LogEvent::new("pairing.accept", "pairing.accept")
                        .with_id(&self.device_id())
                        .with_field("action", "end")
                        .with_field("outcome", "failed")
                        .with_error(&e.to_string())
                        .with_chain(&format!("{e:#}"))
                        .with_duration(duration),
                );
            }
        }
        result
    }

    /// accept 等待核心循环（有界；见 [`Self::accept_pairing_request_with_timeout`]）。
    async fn accept_pairing_request_loop(
        &mut self,
        timeout: Duration,
    ) -> Result<Option<PairingRequest>> {
        let deadline = tokio::time::Instant::now() + timeout;
        loop {
            // 统一路由可能已把配对请求存入 pending_pairing（被周期 accept 抢到）
            if let Some(pending) = self.pending_pairing.lock().unwrap().as_ref() {
                return Ok(Some(pending.request.clone()));
            }
            let now = tokio::time::Instant::now();
            if now >= deadline {
                return Ok(None);
            }
            // 短窗口 accept：配对帧 → 路由到 pending_pairing（下一轮返回）；
            // 推送帧 → 导入（不丢弃），继续等待配对请求。窗口取剩余时间与
            // 500ms 的较小值，保证每次网络等待都有界。
            let remaining = deadline.saturating_duration_since(now);
            let window = remaining.min(Duration::from_millis(500));
            let incoming = match tokio::time::timeout(window, self.endpoint.accept()).await {
                Ok(Some(incoming)) => incoming,
                _ => continue,
            };
            match self.accept_incoming_routed(incoming).await {
                Ok(Some(data)) => {
                    // 配对等待期间抢到推送帧：导入数据（勿丢弃——见方法文档）
                    if let Err(e) = self.import_all(&data) {
                        self.emit_log(
                            LogEvent::new("sync.import", "sync.import")
                                .with_field("action", "failed_tolerated")
                                .with_error(&e.to_string())
                                .with_chain(&format!("{e:#}")),
                        );
                    }
                }
                Ok(None) => {}
                Err(e) => {
                    self.emit_log(
                        LogEvent::new("sync.route", "sync.route")
                            .with_field("action", "failed_tolerated")
                            .with_error(&e.to_string())
                            .with_chain(&format!("{e:#}")),
                    );
                }
            }
            if let Some(pending) = self.pending_pairing.lock().unwrap().as_ref() {
                return Ok(Some(pending.request.clone()));
            }
        }
    }

    /// 确认方：校验配对码并完成配对。
    ///
    /// 成功路径：
    /// 1. 校验码有效未过期（错误码/过期/超限均失败）
    /// 2. upsert 发起方到 paired_devices（确认方持久化发起方）
    /// 3. 若存在待确认连接，在同一连接上回复本机身份（握手响应）
    /// 4. 首次全量同步（决策 8）：立即向发起方推送全量快照（失败容忍——配对已成功）
    /// 5. 返回发起方身份 (peer_id, peer_name)
    pub async fn confirm_pairing(
        &self,
        store: &NoteStore,
        code: &str,
        requester: &PairingRequest,
    ) -> Result<PairingResult> {
        let started = std::time::Instant::now();
        // 事件 #8：confirm 开始（脱敏双方 id；**绝不记录码**）
        self.emit_log(
            LogEvent::new("pairing.confirm", "pairing.confirm")
                .with_id(&self.device_id())
                .with_id(&requester.device_id)
                .with_field("action", "start"),
        );
        let result = self.confirm_pairing_inner(store, code, requester).await;
        let duration = started.elapsed();
        match &result {
            Ok(r) => {
                // 事件 #8：confirm 成功
                self.emit_log(
                    LogEvent::new("pairing.confirm", "pairing.confirm")
                        .with_id(&self.device_id())
                        .with_id(&r.peer_id)
                        .with_field("action", "success")
                        .with_field("peer_name", r.peer_name.clone())
                        .with_duration(duration),
                );
            }
            Err(e) => {
                // 事件 #8：confirm 失败（错误链 + 耗时）
                self.emit_log(
                    LogEvent::new("pairing.confirm", "pairing.confirm")
                        .with_id(&self.device_id())
                        .with_id(&requester.device_id)
                        .with_field("action", "failed")
                        .with_error(&e.to_string())
                        .with_chain(&format!("{e:#}"))
                        .with_duration(duration),
                );
            }
        }
        result
    }

    /// confirm 核心逻辑（校验/持久化/握手/首次推送）。
    async fn confirm_pairing_inner(
        &self,
        store: &NoteStore,
        code: &str,
        requester: &PairingRequest,
    ) -> Result<PairingResult> {
        self.validate_pairing_code(code)?;

        // 请求携带的码必须与当前会话一致（防错配/重放请求）
        {
            let mut guard = self.pairing_session.lock().unwrap();
            if let Some(session) = guard.as_mut() {
                if !requester.code.is_empty() && session.code != requester.code {
                    anyhow::bail!("pairing code mismatch in request");
                }
                // nonce 校验（设计裁决：强制）：凭证/6 位码路径都必须与会话 nonce 一致。
                // 空、全零、格式错误、不匹配一律拒绝并计入失败次数（防重放/错配）；
                // 满 PAIRING_MAX_FAILED_ATTEMPTS 清会话。
                {
                    let requester_nonce_bytes = match nonce_from_hex(&requester.nonce) {
                        Ok(n) => n,
                        Err(_) => {
                            session.failed_attempts += 1;
                            if session.failed_attempts >= PAIRING_MAX_FAILED_ATTEMPTS {
                                *guard = None;
                            }
                            anyhow::bail!("pairing nonce mismatch in request");
                        }
                    };
                    if session.nonce != requester_nonce_bytes {
                        session.failed_attempts += 1;
                        let failed = session.failed_attempts >= PAIRING_MAX_FAILED_ATTEMPTS;
                        if failed {
                            *guard = None;
                        }
                        anyhow::bail!("pairing nonce mismatch in request");
                    }
                }
            }
        }

        // 若存在待确认请求，校验其身份与本次确认的发起方一致（防错配连接/响应）
        {
            let guard = self.pending_pairing.lock().unwrap();
            if let Some(pending) = guard.as_ref() {
                if pending.request.device_id != requester.device_id {
                    anyhow::bail!("pairing requester mismatch with pending request");
                }
            }
        }

        // 配对码单次使用：成功后即清除会话
        *self.pairing_session.lock().unwrap() = None;

        // 确认方持久化发起方
        store.upsert_paired_device(&requester.device_id, &requester.device_name)?;
        // 配对握手成功 → 发起方立即进入"近期在线"（任务 O 验收 11：不能等下一次同步）
        self.touch_last_seen(store, &requester.device_id, "pairing");
        // 记录发起方直连 IP（供后续周期推送直连优先）
        self.peer_ips
            .lock()
            .unwrap()
            .insert(requester.device_id.clone(), requester.ips.clone());

        // 有真实握手（待确认连接）时：回复本机身份
        let pending = self.pending_pairing.lock().unwrap().take();
        let had_handshake = pending.is_some();
        if let Some(pending) = pending {
            let response = encode_pairing_response(&PairingResponse {
                device_id: self.device_id(),
                device_name: self.device_name(),
            });
            let mut send = pending
                .conn
                .open_uni()
                .await
                .context("open pairing response stream")?;
            send.write_all(&response)
                .await
                .context("write pairing response")?;
            send.finish().context("finish pairing response")?;
            // 保持连接存活直到发起方读完响应并关闭连接（与 push_to_peer 同模式）；
            // 避免本端立即 drop conn 导致响应未送达。超时保护防止对端不关闭。
            tokio::time::timeout(std::time::Duration::from_secs(10), pending.conn.closed())
                .await
                .ok();
        }

        // 决策 8：首次配对自动全量同步（仅真实握手后推送；失败容忍——配对已成功，
        // 快照可稍后由同步层重试）
        if had_handshake {
            if let Err(e) = self
                .push_to_peer(&requester.device_id, requester.ips.clone())
                .await
            {
                self.emit_log(
                    LogEvent::new("sync.push", "sync.initial")
                        .with_id(&self.device_id())
                        .with_id(&requester.device_id)
                        .with_field("direction", "push")
                        .with_field("action", "failed_tolerated")
                        .with_error(&e.to_string())
                        .with_chain(&format!("{e:#}")),
                );
            }
        }

        Ok(PairingResult {
            peer_id: requester.device_id.clone(),
            peer_name: requester.device_name.clone(),
        })
    }

    /// 构建连接目标地址（任务 L：跨网段连接缺陷修复）。
    ///
    /// - `ips` 非空 → 直连优先（确定性）：解析为 `TransportAddr::Ip`，行为不变。
    /// - `ips` 为空 → 仅凭 node id；若配置了 relay（任务 K `relay.txt` → Custom），
    ///   附加第一个 relay URL，使 iroh 经 relay 服务器的地址映射找到对端
    ///   （跨网段不依赖 n0 公共 DNS TXT 地址解析——中国大陆不可达）。
    ///   无 relay 配置（Disabled，`relay_map().urls()` 为空）→ 不附加，维持原有
    ///   DNS 地址解析路径，行为不变（局域网 mDNS/直连场景不受影响）。
    pub fn build_connect_addr(
        &self,
        node_id: iroh::EndpointId,
        ips: &[String],
    ) -> Result<EndpointAddr> {
        if ips.is_empty() {
            let mut addr = EndpointAddr::new(node_id);
            let urls: Vec<iroh::RelayUrl> = self.relay_mode.relay_map().urls();
            if let Some(u) = urls.into_iter().next() {
                addr = addr.with_relay_url(u);
            }
            Ok(addr)
        } else {
            let ips: Vec<TransportAddr> = ips
                .iter()
                .filter_map(|ip| ip.parse::<std::net::SocketAddr>().ok())
                .map(TransportAddr::Ip)
                .collect();
            if ips.is_empty() {
                anyhow::bail!("no valid IPs provided");
            }
            Ok(EndpointAddr::from_parts(node_id, ips))
        }
    }

    /// 发起方：连接确认方，发送配对请求，等待握手响应；成功后 upsert 确认方。
    ///
    /// `target` 由 mDNS 发现提供（同网段面对面配对）：device_id + ip:port 列表。
    /// ips 非空 → 直连优先（确定性）；ips 为空 → 仅凭 node id 经 n0 地址解析 +
    /// 公共 relay 连接（iroh 1.x N0 preset 自带 DnsAddressLookup）。
    pub async fn begin_pairing_connect(
        &self,
        store: &NoteStore,
        code: &str,
        target: PairingTarget,
    ) -> Result<PairingResult> {
        let started = std::time::Instant::now();
        let result = self.begin_pairing_connect_inner(store, code, target).await;
        let duration = started.elapsed();
        match &result {
            Ok(r) => {
                // 事件 #7：连接成功（transport + 耗时 + 脱敏对端 id）
                self.emit_log(
                    LogEvent::new("pairing.connect", "pairing.connect")
                        .with_id(&self.device_id())
                        .with_id(&r.peer_id)
                        .with_field("action", "success")
                        .with_field("transport", self.transport_label(&r.peer_id))
                        .with_field("peer_name", r.peer_name.clone())
                        .with_duration(duration),
                );
            }
            Err(e) => {
                // 事件 #7：连接失败（错误链 + 耗时）
                self.emit_log(
                    LogEvent::new("pairing.connect", "pairing.connect")
                        .with_id(&self.device_id())
                        .with_field("action", "failed")
                        .with_error(&e.to_string())
                        .with_chain(&format!("{e:#}"))
                        .with_duration(duration),
                );
            }
        }
        result
    }

    /// 发起方连接核心逻辑（发送请求 + 等待握手响应 + upsert 确认方）。
    async fn begin_pairing_connect_inner(
        &self,
        store: &NoteStore,
        code: &str,
        target: PairingTarget,
    ) -> Result<PairingResult> {
        let node_id: iroh::EndpointId = target
            .device_id
            .parse()
            .context("invalid target endpoint id")?;
        let addr = self.build_connect_addr(node_id, &target.ips)?;

        // 事件 #7：连接开始（transport 区分 direct / relay / dns）
        let transport = if !target.ips.is_empty() {
            "direct"
        } else if addr.relay_urls().next().is_some() {
            "relay"
        } else {
            "dns"
        };
        self.emit_log(
            LogEvent::new("pairing.connect", "pairing.connect")
                .with_id(&self.device_id())
                .with_id(&target.device_id)
                .with_field("action", "start")
                .with_field("transport", transport),
        );

        // 发起方请求：本机身份 + relay 信息（N0 preset 已自动发布地址到 n0 DNS）
        let relay_urls: Vec<iroh::RelayUrl> = self.relay_mode.relay_map().urls();
        let request = PairingRequest {
            code: code.to_string(),
            device_id: self.device_id(),
            device_name: self.device_name(),
            relay_info: relay_urls
                .iter()
                .map(|u| u.to_string())
                .collect::<Vec<_>>()
                .join(","),
            ips: self.local_addrs(),
            nonce: target.nonce,
        };

        let conn = self
            .endpoint
            .connect(addr, ALPN)
            .await
            .context("connect to confirmer")?;

        // 发送请求
        let payload = encode_pairing_request(&request);
        let mut send = conn
            .open_uni()
            .await
            .context("open pairing request stream")?;
        send.write_all(&payload)
            .await
            .context("write pairing request")?;
        send.finish().context("finish pairing request")?;

        // 等待确认方握手响应（同一连接新流）
        let mut recv = conn
            .accept_uni()
            .await
            .context("accept pairing response stream")?;
        let data = recv
            .read_to_end(usize::MAX)
            .await
            .context("read pairing response")?;
        let response = decode_pairing_response(&data)?;
        // 数据已读入内存，主动关闭连接，通知确认方可释放（与 accept_push 同模式）
        conn.close(0u32.into(), b"done");

        // 握手响应 → 发起方持久化确认方
        store.upsert_paired_device(&response.device_id, &response.device_name)?;
        // 配对握手成功 → 确认方立即进入"近期在线"（任务 O 验收 11）
        self.touch_last_seen(store, &response.device_id, "pairing");
        // 记录确认方直连 IP（供后续周期推送直连优先）
        self.peer_ips
            .lock()
            .unwrap()
            .insert(response.device_id.clone(), target.ips.clone());

        Ok(PairingResult {
            peer_id: response.device_id,
            peer_name: response.device_name,
        })
    }

    /// 传输方式标签（direct/relay/dns；对端已有直连 IP 记录 → direct）。
    fn transport_label(&self, peer_id: &str) -> String {
        if self
            .peer_ips
            .lock()
            .unwrap()
            .get(peer_id)
            .map(|ips| !ips.is_empty())
            .unwrap_or(false)
        {
            return "direct".to_string();
        }
        if self
            .relay_mode
            .relay_map()
            .urls::<Vec<iroh::RelayUrl>>()
            .into_iter()
            .next()
            .is_some()
        {
            return "relay".to_string();
        }
        "dns".to_string()
    }

    /// 添加/创建一条笔记
    pub fn create_note(&mut self, note_id: String, content: &str) -> Result<()> {
        let note = NoteCrdt::new();
        note.set_content(content);
        let mut core = self.core.lock().unwrap();
        let previous = core.notes.remove(&note_id);
        core.notes.insert(note_id.clone(), note);
        if let Err(err) = self.persist_locked(&core) {
            core.notes.remove(&note_id);
            if let Some(previous) = previous {
                core.notes.insert(note_id, previous);
            }
            return Err(err);
        }
        drop(core);
        // 编辑保存即推送：标记待同步（推送由调度器异步执行，不阻塞编辑）
        self.mark_sync_pending(&note_id);
        Ok(())
    }

    /// 遍历所有笔记（用于同步到 SQLite；任务 O 后返回 owned 快照，避免持锁借用）
    pub fn iter_notes(&self) -> Vec<(String, NoteCrdt)> {
        let core = self.core.lock().unwrap();
        core.notes.clone().into_iter().collect()
    }

    /// 更新笔记内容
    pub fn update_note(&mut self, note_id: &str, content: &str) -> Result<()> {
        {
            let core = self.core.lock().unwrap();
            let note = core
                .notes
                .get(note_id)
                .ok_or_else(|| anyhow::anyhow!("note not found: {}", note_id))?;
            let previous = note.get_content();
            note.set_content(content);
            if let Err(err) = self.persist_locked(&core) {
                if let Some(note) = core.notes.get(note_id) {
                    note.set_content(&previous);
                }
                return Err(err);
            }
        }
        self.mark_sync_pending(note_id);
        Ok(())
    }

    /// 更新笔记元数据（meta tags）
    ///
    /// 更新 NoteCrdt 的 meta.tags list 并 persist；persist 失败时回滚内存态。
    pub fn update_metadata(&mut self, note_id: &str, tags: &[String]) -> Result<()> {
        {
            let core = self.core.lock().unwrap();
            let note = core
                .notes
                .get(note_id)
                .ok_or_else(|| anyhow::anyhow!("note not found: {}", note_id))?;
            let previous = note.get_tags();
            note.set_tags(tags);
            if let Err(err) = self.persist_locked(&core) {
                if let Some(note) = core.notes.get(note_id) {
                    note.set_tags(&previous);
                }
                return Err(err);
            }
        }
        self.mark_sync_pending(note_id);
        Ok(())
    }

    /// 获取笔记内容
    pub fn get_note(&self, note_id: &str) -> Option<String> {
        let core = self.core.lock().unwrap();
        core.notes.get(note_id).map(|n| n.get_content())
    }

    /// 软删除：给笔记 meta 打 deleted_at 标记（进回收站），随快照传播。
    ///
    /// 笔记仍在 notes HashMap 中，仅 meta 标记；persist 失败时回滚内存态。
    pub fn soft_delete_note(&mut self, note_id: &str) -> Result<()> {
        {
            let core = self.core.lock().unwrap();
            let note = core
                .notes
                .get(note_id)
                .ok_or_else(|| anyhow::anyhow!("note not found: {}", note_id))?;
            let previous = note.get_deleted_at();
            note.set_deleted_at(Some(Utc::now().to_rfc3339()));
            if let Err(err) = self.persist_locked(&core) {
                if let Some(note) = core.notes.get(note_id) {
                    note.set_deleted_at(previous);
                }
                return Err(err);
            }
        }
        self.mark_sync_pending(note_id);
        Ok(())
    }

    /// 恢复：清除笔记 meta 的 deleted_at 标记，随快照传播。
    pub fn restore_note(&mut self, note_id: &str) -> Result<()> {
        {
            let core = self.core.lock().unwrap();
            let note = core
                .notes
                .get(note_id)
                .ok_or_else(|| anyhow::anyhow!("note not found: {}", note_id))?;
            let previous = note.get_deleted_at();
            note.set_deleted_at(None);
            if let Err(err) = self.persist_locked(&core) {
                if let Some(note) = core.notes.get(note_id) {
                    note.set_deleted_at(previous);
                }
                return Err(err);
            }
        }
        self.mark_sync_pending(note_id);
        Ok(())
    }

    /// 彻底删除：从 notes 移除并记入墓碑（删除信息随快照传播，防复活）。
    ///
    /// 已彻底删除的 id 幂等成功；persist 失败时回滚内存态。
    pub fn purge_note(&mut self, note_id: &str) -> Result<()> {
        let mut core = self.core.lock().unwrap();
        let removed = core.notes.remove(note_id);
        if removed.is_none() && !core.tombstones.contains(note_id) {
            anyhow::bail!("note not found: {}", note_id);
        }
        core.tombstones.insert(note_id.to_string());
        if let Err(err) = self.persist_locked(&core) {
            if let Some(note) = removed {
                core.notes.insert(note_id.to_string(), note);
            }
            core.tombstones.remove(note_id);
            return Err(err);
        }
        drop(core);
        self.mark_sync_pending(note_id);
        Ok(())
    }

    /// 过期清理：遍历 meta.deleted_at < cutoff 的软删笔记并 purge（入墓碑），
    /// 返回清理数。cutoff 为 RFC3339 时间字符串。
    pub fn purge_expired(&mut self, cutoff: &str) -> Result<usize> {
        let cutoff_dt = chrono::DateTime::parse_from_rfc3339(cutoff)
            .with_context(|| format!("invalid cutoff timestamp: {}", cutoff))?;
        let mut core = self.core.lock().unwrap();
        let expired: Vec<String> = core
            .notes
            .iter()
            .filter_map(|(id, note)| {
                let deleted_at = note.get_deleted_at()?;
                let dt = chrono::DateTime::parse_from_rfc3339(&deleted_at).ok()?;
                (dt < cutoff_dt).then(|| id.clone())
            })
            .collect();
        if expired.is_empty() {
            return Ok(0);
        }
        // 一次 persist：全部移除 + 入墓碑，失败则整体回滚
        let mut removed_notes = Vec::with_capacity(expired.len());
        for id in &expired {
            if let Some(note) = core.notes.remove(id) {
                removed_notes.push((id.clone(), note));
            }
            core.tombstones.insert(id.clone());
        }
        if let Err(err) = self.persist_locked(&core) {
            for (id, note) in removed_notes {
                core.notes.insert(id, note);
            }
            for id in &expired {
                core.tombstones.remove(id);
            }
            return Err(err);
        }
        drop(core);
        // 与 purge_note 一致：清理的墓碑标记待同步，随下一次全量推送传播给对端
        // （push 是全量快照含墓碑；不标记则墓碑只在有其他变更触发的推送中捎带）。
        for id in &expired {
            self.mark_sync_pending(id);
        }
        Ok(expired.len())
    }

    /// 墓碑集合快照（已彻底删除的 note id；任务 O 后改为 clone 快照，避免借用锁）
    pub fn tombstones(&self) -> HashSet<String> {
        self.core.lock().unwrap().tombstones.clone()
    }

    /// 导出所有笔记的全量快照（用于首次同步）
    ///
    /// v3 序列化格式：`墓碑 section + 笔记记录流`。
    /// 墓碑 section：`(墓碑数: u32 LE, (id_len: u32 LE, id)*)`
    /// 记录流：每条笔记连续拼接为
    ///   `(note_id_len: u32 LE, note_id, snapshot_len: u32 LE, snapshot)`
    pub fn export_all(&self) -> Result<Vec<u8>> {
        let core = self.core.lock().unwrap();
        export_core_all(&core)
    }

    /// 导入全量快照（v3 语义：墓碑 section + 记录流）
    pub fn import_all(&mut self, data: &[u8]) -> Result<()> {
        let started = std::time::Instant::now();
        let result = {
            let mut core = self.core.lock().unwrap();
            import_core_all(&mut core, data)
        };
        let duration = started.elapsed();
        // 事件 #9/#10：导入只记录数量/方向/耗时，绝不记录正文
        match &result {
            Ok(()) => {
                let core = self.core.lock().unwrap();
                let note_count = core.notes.len() + core.tombstones.len();
                drop(core);
                self.emit_log(
                    LogEvent::new("sync.import", "sync.import")
                        .with_id(&self.device_id())
                        .with_field("direction", "import")
                        .with_field("action", "success")
                        .with_field("note_count", note_count.to_string())
                        .with_field("bytes", data.len().to_string())
                        .with_duration(duration),
                );
            }
            Err(e) => {
                self.emit_log(
                    LogEvent::new("sync.import", "sync.import")
                        .with_id(&self.device_id())
                        .with_field("direction", "import")
                        .with_field("action", "failed")
                        .with_error(&e.to_string())
                        .with_chain(&format!("{e:#}"))
                        .with_duration(duration),
                );
            }
        }
        result
    }

    /// 持锁 persist（任务 O：persist 直接消费已持锁的 core，避免锁内重入）。
    fn persist_locked(&self, core: &CoreState) -> Result<()> {
        persist_core(core)
    }

    /// 全量快照导出（已持锁 core 的纯函数，接收任务/主服务共用）。
    fn persist(&self) -> Result<()> {
        let core = self.core.lock().unwrap();
        persist_core(&core)
    }

    /// 导入 payload。`version` 决定是否含墓碑 section：
    /// - v3：`墓碑 section + 记录流`（导入的墓碑与本地 tombstones union 合并；
    ///   记录流中遇到墓碑中的 id 跳过，不复活）
    /// - v1/v2：纯记录流（无墓碑 section，tombstones 为空，无损升级）
    fn import_raw(&mut self, version: u32, data: &[u8]) -> Result<()> {
        let mut core = self.core.lock().unwrap();
        import_core_raw(&mut core, version, data)
    }

    /// 向指定对端推送所有笔记的快照
    ///
    /// `peer_id`: iroh 节点 ID（字符串格式）
    /// `peer_ips`: 对端 IP 地址列表（`"ip:port"` 格式）。
    ///   非空时直连优先（同网段）；为空时仅凭 node id 经 relay/地址解析尝试连接
    ///   （跨网段，依赖 iroh 的 n0 DNS 地址查找或已配置 relay）。
    pub async fn push_to_peer(&self, peer_id: &str, peer_ips: Vec<String>) -> Result<()> {
        let started = std::time::Instant::now();
        let note_count = {
            let core = self.core.lock().unwrap();
            core.notes.len() + core.tombstones.len()
        };
        // 事件 #9：首次全量同步 push 开始（只记录数量，不记录正文）
        self.emit_log(
            LogEvent::new("sync.push", "sync.initial")
                .with_id(&self.device_id())
                .with_id(peer_id)
                .with_field("direction", "push")
                .with_field("action", "start")
                .with_field("note_count", note_count.to_string()),
        );
        let result = self.push_to_peer_inner(peer_id, &peer_ips).await;
        let duration = started.elapsed();
        match &result {
            Ok(()) => {
                self.emit_log(
                    LogEvent::new("sync.push", "sync.initial")
                        .with_id(&self.device_id())
                        .with_id(peer_id)
                        .with_field("direction", "push")
                        .with_field("action", "success")
                        .with_field("note_count", note_count.to_string())
                        .with_duration(duration),
                );
            }
            Err(e) => {
                self.emit_log(
                    LogEvent::new("sync.push", "sync.initial")
                        .with_id(&self.device_id())
                        .with_id(peer_id)
                        .with_field("direction", "push")
                        .with_field("action", "failed")
                        .with_error(&e.to_string())
                        .with_chain(&format!("{e:#}"))
                        .with_duration(duration),
                );
            }
        }
        result
    }

    /// push_to_peer 核心逻辑。
    async fn push_to_peer_inner(&self, peer_id: &str, peer_ips: &[String]) -> Result<()> {
        let node_id: iroh::EndpointId = peer_id.parse().context("invalid peer endpoint id")?;

        let addr = self.build_connect_addr(node_id, peer_ips)?;

        let data = self.export_all()?;
        // 网络线格式：8 字节 CARDMIND magic + export_all 输出（M2：识别推送帧，
        // 防止墓碑数=1 时 export_all 首字节 0x01 与配对帧标记冲突）
        let wire = encode_push_wire(&data);

        let conn = self
            .endpoint
            .connect(addr, ALPN)
            .await
            .context("connect to peer")?;
        let mut send = conn.open_uni().await.context("open uni stream")?;
        send.write_all(&wire).await.context("write snapshot data")?;
        // finish() 显式发送流结束（EOF），接收端 read_to_end 据此结束
        send.finish().context("finish uni stream")?;
        // 保持连接存活直到对端读完数据并关闭连接；避免对端未读完时本端
        // drop conn 导致连接被提前关闭（数据丢失）。超时保护防止对端不关闭。
        tokio::time::timeout(std::time::Duration::from_secs(10), conn.closed())
            .await
            .ok();

        Ok(())
    }

    /// 逐个向多台设备推送全量快照（含墓碑）。
    ///
    /// - 每台设备独立尝试，单台失败不中断整体
    /// - 单台连接/推送超时 10 秒，超时记为失败并继续下一台
    /// - `devices`: `(peer_id, Option<IP 列表>)`；IP 缺省（None/空）时经 relay/地址解析连接
    pub async fn push_to_paired_devices(
        &self,
        devices: &[(String, Option<Vec<String>>)],
    ) -> Vec<DevicePushResult> {
        let started = std::time::Instant::now();
        let note_count = {
            let core = self.core.lock().unwrap();
            core.notes.len() + core.tombstones.len()
        };
        let data = match self.export_all() {
            Ok(d) => d,
            Err(e) => {
                // 快照导出失败：所有设备都记为失败
                self.emit_log(
                    LogEvent::new("sync.push", "sync.push")
                        .with_id(&self.device_id())
                        .with_field("direction", "push")
                        .with_field("action", "failed")
                        .with_error(&e.to_string())
                        .with_chain(&format!("{e:#}")),
                );
                return devices
                    .iter()
                    .map(|(peer_id, _)| DevicePushResult {
                        peer_id: peer_id.clone(),
                        ok: false,
                        message: format!("export_all failed: {e}"),
                    })
                    .collect();
            }
        };

        let mut results = Vec::with_capacity(devices.len());
        for (peer_id, ips) in devices {
            let peer_id = peer_id.clone();
            let ips = ips.clone();
            let outcome = tokio::time::timeout(
                std::time::Duration::from_secs(10),
                self.push_to_peer_once(&peer_id, ips.as_deref(), &data),
            )
            .await;
            match outcome {
                Ok(Ok(())) => {
                    // 事件 #10：后续同步单台成功（只记录数量）
                    self.emit_log(
                        LogEvent::new("sync.push", "sync.push")
                            .with_id(&self.device_id())
                            .with_id(&peer_id)
                            .with_field("direction", "push")
                            .with_field("action", "success")
                            .with_field("note_count", note_count.to_string())
                            .with_field("transport", self.transport_label(&peer_id)),
                    );
                    results.push(DevicePushResult {
                        peer_id,
                        ok: true,
                        message: String::new(),
                    });
                }
                Ok(Err(e)) => {
                    // 事件 #10：后续同步单台失败（错误链 + 耗时；**不再打印完整 peer_id**）
                    self.emit_log(
                        LogEvent::new("sync.push", "sync.push")
                            .with_id(&self.device_id())
                            .with_id(&peer_id)
                            .with_field("direction", "push")
                            .with_field("action", "failed")
                            .with_error(&e.to_string())
                            .with_chain(&format!("{e:#}"))
                            .with_duration(started.elapsed()),
                    );
                    results.push(DevicePushResult {
                        peer_id,
                        ok: false,
                        message: format!("{e:#}"),
                    });
                }
                Err(_) => {
                    // 单台超时：包含耗时与"超时"错误
                    self.emit_log(
                        LogEvent::new("sync.push", "sync.push")
                            .with_id(&self.device_id())
                            .with_id(&peer_id)
                            .with_field("direction", "push")
                            .with_field("action", "failed")
                            .with_error("push timeout after 10s")
                            .with_chain("push timeout after 10s")
                            .with_duration(started.elapsed()),
                    );
                    results.push(DevicePushResult {
                        peer_id,
                        ok: false,
                        message: "push timeout after 10s".to_string(),
                    });
                }
            }
        }
        results
    }

    /// 单台设备的连接 + 发送（复用推送逻辑，data 为预导出的快照）
    async fn push_to_peer_once(
        &self,
        peer_id: &str,
        peer_ips: Option<&[String]>,
        data: &[u8],
    ) -> Result<()> {
        let node_id: iroh::EndpointId = peer_id.parse().context("invalid peer endpoint id")?;
        let addr = self.build_connect_addr(node_id, peer_ips.unwrap_or(&[]))?;

        let conn = self
            .endpoint
            .connect(addr, ALPN)
            .await
            .context("connect to peer")?;
        let mut send = conn.open_uni().await.context("open uni stream")?;
        // 网络线格式：8 字节 CARDMIND magic + export_all 输出（M2：识别推送帧）
        send.write_all(&encode_push_wire(data))
            .await
            .context("write snapshot data")?;
        send.finish().context("finish uni stream")?;
        // 保持连接存活直到对端读完并关闭；超时保护（push_to_paired_devices 外层也有 10s 超时）
        tokio::time::timeout(std::time::Duration::from_secs(10), conn.closed())
            .await
            .ok();
        Ok(())
    }

    /// 监听并接受对端的推送，返回原始字节数据
    ///
    /// 调用方收到数据后应调用 `import_all` 导入。
    pub async fn accept_push(&self) -> Result<Vec<u8>> {
        let started = std::time::Instant::now();
        let result: Result<Vec<u8>> = (async {
            loop {
                let incoming = self
                    .endpoint
                    .accept()
                    .await
                    .ok_or_else(|| anyhow::anyhow!("no incoming connection"))?;
                // 统一路由：配对帧交给配对流程（continue 等待真正的推送），推送帧返回
                if let Some(data) = self.accept_incoming_routed(incoming).await? {
                    return Ok(data);
                }
            }
        })
        .await;
        // 事件 #9：首次全量同步接收（只记录字节数/耗时，不记录正文）
        match &result {
            Ok(data) => {
                self.emit_log(
                    LogEvent::new("sync.receive", "sync.initial")
                        .with_id(&self.device_id())
                        .with_field("direction", "receive")
                        .with_field("action", "success")
                        .with_field("bytes", data.len().to_string())
                        .with_duration(started.elapsed()),
                );
            }
            Err(e) => {
                self.emit_log(
                    LogEvent::new("sync.receive", "sync.initial")
                        .with_id(&self.device_id())
                        .with_field("direction", "receive")
                        .with_field("action", "failed")
                        .with_error(&e.to_string())
                        .with_chain(&format!("{e:#}"))
                        .with_duration(started.elapsed()),
                );
            }
        }
        result
    }

    /// 统一 incoming 处理：接受连接并按帧标记路由（周期 accept 与配对 accept 共用）。
    ///
    /// 帧标记（M2 修复——不能用单字节判定，否则推送 payload 首字节 0x01 与配对帧
    /// 冲突）：
    /// - 前 8 字节 == `LORO_MAGIC`（"CARDMIND"）→ 推送帧：读完整 payload，
    ///   关闭连接通知发送端可释放，返回剥离 magic 后的 `Ok(Some(data))`
    ///   （data 即 `export_all` 输出，`import_all` 直接消费）。
    /// - 首字节 `PAIRING_FRAME_REQUEST (0x01)` → 配对请求帧：解析并存入
    ///   `pending_pairing`（供 `confirm_pairing` 在同一连接上回复握手响应），
    ///   返回 `Ok(None)`。
    /// - 其他 → 报错（未知帧标记）。
    async fn accept_incoming_routed(
        &self,
        incoming: iroh::endpoint::Incoming,
    ) -> Result<Option<Vec<u8>>> {
        // 统一路由自由函数（任务 O 后台接收器与主服务共用同一路由/同一
        // pending_pairing——配对帧与推送帧不丢帧、不互抢）
        let routed = route_incoming(incoming, &self.pending_pairing).await?;
        Ok(routed.map(|(_sender, data)| data))
    }

    /// 非阻塞接受对端推送（周期拉取用）：等待最多 `timeout`，超时返回 `Ok(None)`。
    ///
    /// 通过统一帧路由避免与配对流程争用 accept 通道；配对请求被本函数抢到时
    /// 会被正确存入 `pending_pairing`（`confirm_pairing` 仍可完成握手）。
    pub async fn try_accept_push(&self, timeout: Duration) -> Result<Option<Vec<u8>>> {
        let incoming = match tokio::time::timeout(timeout, self.endpoint.accept()).await {
            Ok(Some(incoming)) => incoming,
            _ => return Ok(None),
        };
        self.accept_incoming_routed(incoming).await
    }

    // ━━━ 自动同步调度（任务 H）━━━

    /// 设置同步开关（决策 6 能力）：false 时调度器暂停推送与拉取。
    /// 移动端由 Flutter 侧按网络类型调用；桌面端默认 true。
    pub fn set_sync_allowed(&self, allowed: bool) {
        self.sync_allowed.store(allowed, Ordering::Relaxed);
    }

    /// 当前同步开关状态。
    pub fn sync_allowed(&self) -> bool {
        self.sync_allowed.load(Ordering::Relaxed)
    }

    /// 待同步笔记计数（模块 5 基础）：本地编辑后待推送的笔记数。
    ///
    /// 内存态不持久化：重启后经持久化加载重标全部待同步（保守正确）。
    pub fn pending_sync_count(&self) -> u32 {
        self.pending_dirty.lock().unwrap().len() as u32
    }

    /// note_id → 最后成功推送时间（诊断/测试用快照）。
    pub fn last_pushed_at_snapshot(&self) -> HashMap<String, DateTime<Utc>> {
        self.last_pushed_at.lock().unwrap().clone()
    }

    /// 编辑保存即推送：标记笔记待同步（推送由调度器异步执行，不阻塞编辑）。
    fn mark_sync_pending(&self, note_id: &str) {
        self.pending_dirty
            .lock()
            .unwrap()
            .insert(note_id.to_string());
    }

    /// 重启后全部视为待同步（last_pushed_at 不持久化，保守正确——对端状态未知）。
    fn mark_all_pending(&self) {
        let mut dirty = self.pending_dirty.lock().unwrap();
        let core = self.core.lock().unwrap();
        for id in core.notes.keys() {
            dirty.insert(id.clone());
        }
        for id in &core.tombstones {
            dirty.insert(id.clone());
        }
    }

    /// 全量快照已成功推送给至少一台对端：清空待同步集并记录推送时间。
    fn mark_synced_all(&self) {
        let now = Utc::now();
        let mut dirty = self.pending_dirty.lock().unwrap();
        let mut pushed = self.last_pushed_at.lock().unwrap();
        for id in dirty.iter() {
            pushed.insert(id.clone(), now);
        }
        dirty.clear();
    }

    /// 从 store 读取配对设备，为每台附上最近已知直连 IP（有则直连优先，无则走
    /// relay/地址解析）。
    fn paired_devices_with_ips(&self, store: &NoteStore) -> Vec<(String, Option<Vec<String>>)> {
        let peer_ips = self.peer_ips.lock().unwrap();
        store
            .list_paired_devices()
            .map(|rows| {
                rows.into_iter()
                    .map(|d| (d.peer_id.clone(), peer_ips.get(&d.peer_id).cloned()))
                    .collect()
            })
            .unwrap_or_default()
    }

    /// 推送待办（编辑保存即推送 / 调度器触发）。
    ///
    /// - 同步开关关闭时跳过推送（移动端蜂窝场景），pending 保留。
    /// - 无配对设备时立即返回空结果。
    /// - 至少一台对端推送成功 → 全量快照已传播 → 清 pending + 记录 last_pushed_at。
    /// - 全部失败 → 静默（决策 18）：仅记录日志，pending 保留（下个周期兜底），
    ///   不向调用方返回错误。
    pub async fn push_pending(&self, store: &NoteStore) -> Vec<DevicePushResult> {
        let started = std::time::Instant::now();
        let pending_count = self.pending_sync_count();
        if !self.sync_allowed() {
            // 事件 #10：同步开关关闭 → 跳过
            self.emit_log(
                LogEvent::new("sync.push_pending", "sync.push_pending")
                    .with_id(&self.device_id())
                    .with_field("action", "skipped")
                    .with_field("reason", "sync_disabled")
                    .with_field("pending_count", pending_count.to_string()),
            );
            return Vec::new();
        }
        let devices = self.paired_devices_with_ips(store);
        if devices.is_empty() {
            // 事件 #10：无配对设备 → 跳过
            self.emit_log(
                LogEvent::new("sync.push_pending", "sync.push_pending")
                    .with_id(&self.device_id())
                    .with_field("action", "skipped")
                    .with_field("reason", "no_devices")
                    .with_field("pending_count", pending_count.to_string()),
            );
            return Vec::new();
        }
        let results = self.push_to_paired_devices(&devices).await;
        let duration = started.elapsed();
        if results.iter().any(|r| r.ok) {
            self.mark_synced_all();
            for r in &results {
                if r.ok {
                    self.touch_last_seen(store, &r.peer_id, "outbound_push");
                }
            }
        } else {
            // 全部失败 → 静默（决策 18）；逐台事件已在 push_to_paired_devices 内发出（脱敏）
            for r in &results {
                self.emit_log(
                    LogEvent::new("sync.push_pending", "sync.push_pending")
                        .with_id(&self.device_id())
                        .with_id(&r.peer_id)
                        .with_field("action", "all_failed_silent")
                        .with_field("pending_count", pending_count.to_string())
                        .with_duration(duration),
                );
            }
        }
        // 汇总事件：成功台数 + 待同步数 + 耗时
        let ok_count = results.iter().filter(|r| r.ok).count();
        self.emit_log(
            LogEvent::new("sync.push_pending", "sync.push_pending")
                .with_id(&self.device_id())
                .with_field("action", "end")
                .with_field("ok_count", ok_count.to_string())
                .with_field("pending_count", pending_count.to_string())
                .with_field("pending_after", self.pending_sync_count().to_string())
                .with_duration(duration),
        );
        results
    }

    /// 周期同步任务体（Flutter 侧 Timer 周期调用；测试直接调用）：
    /// 1. 同步开关关闭 → 跳过（决策 6）
    /// 2. push 给所有配对设备（对等推拉——pull 语义用 push 协议实现：
    ///    我方 push 即请求对端在各自周期里推回）
    /// 3. 短窗口 accept 对端 push（非阻塞）→ import → 刷新 SQLite 投影
    pub async fn run_sync_cycle(&mut self, store: &NoteStore) -> Result<SyncCycleResult> {
        let started = std::time::Instant::now();
        if !self.sync_allowed() {
            let result = SyncCycleResult {
                pushed_count: 0,
                accepted_push: false,
                disabled: true,
            };
            self.emit_log(
                LogEvent::new("sync.cycle", "sync.cycle")
                    .with_id(&self.device_id())
                    .with_field("action", "end")
                    .with_field("disabled", "true"),
            );
            return Ok(result);
        }
        let devices = self.paired_devices_with_ips(store);
        let results = if devices.is_empty() {
            Vec::new()
        } else {
            self.push_to_paired_devices(&devices).await
        };
        let any_ok = results.iter().any(|r| r.ok);
        if any_ok {
            self.mark_synced_all();
            for r in &results {
                if r.ok {
                    self.touch_last_seen(store, &r.peer_id, "outbound_push");
                }
            }
        } else if !results.is_empty() {
            // 逐台失败事件已在 push_to_paired_devices 内发出（脱敏）；汇总一次
            for r in &results {
                self.emit_log(
                    LogEvent::new("sync.cycle", "sync.cycle")
                        .with_id(&self.device_id())
                        .with_id(&r.peer_id)
                        .with_field("action", "push_failed_silent")
                        .with_field("ok", "false")
                        .with_duration(started.elapsed()),
                );
            }
        }
        let accepted = match self.try_accept_push(SYNC_ACCEPT_WINDOW).await? {
            Some(data) => {
                self.import_all(&data)?;
                self.sync_notes_to_store(store)?;
                true
            }
            None => false,
        };
        // 成功推送的对端设备数（真实计数，非 0/1 布尔）
        let pushed_count = results.iter().filter(|r| r.ok).count() as u32;
        // 事件 #10：周期同步汇总（触发原因由 Flutter 调度器记录；这里记录结果）
        self.emit_log(
            LogEvent::new("sync.cycle", "sync.cycle")
                .with_id(&self.device_id())
                .with_field("action", "end")
                .with_field("pushed_count", pushed_count.to_string())
                .with_field("accepted_push", accepted.to_string())
                .with_field("pending_after", self.pending_sync_count().to_string())
                .with_duration(started.elapsed()),
        );
        Ok(SyncCycleResult {
            pushed_count,
            accepted_push: accepted,
            disabled: false,
        })
    }

    /// 将所有 CRDT 笔记同步到 SQLite 存储（同时清理墓碑投影行，防被删笔记复活）。
    pub fn sync_notes_to_store(&self, store: &NoteStore) -> Result<()> {
        for (id, note) in self.iter_notes() {
            store.sync_note(&id, &note)?;
        }
        for id in self.tombstones() {
            store.purge_note(&id)?;
        }
        Ok(())
    }

    // ━━━ 后台持续接收器（任务 O）━━━

    /// 启动被动接收任务（幂等）：持续短窗口 accept 对端 push，收到即
    /// import → 刷新 SQLite 投影 → 更新发送方 last_seen。
    ///
    /// - **不占用 FRB opaque 锁**：接收任务只持有 `endpoint.clone()` + 共享
    ///   `core` + `store.clone()`，生命周期独立于主服务方法调用。
    /// - **幂等**：重复 start 不产生第二个接收器。
    /// - **有界窗口**：每窗口 300ms，空闲时持续轮询；stop 后 3 秒内退出。
    /// - 配对帧与推送帧统一路由（`route_incoming`），不丢帧、不互抢。
    pub async fn start_receiver(&self, store: NoteStore) -> Result<()> {
        let started = std::time::Instant::now();
        {
            let mut guard = self.receiver.lock().unwrap();
            if guard.join.is_some() {
                // 已在运行：幂等返回（不产生第二个 listener）
                self.emit_log(
                    LogEvent::new("receiver.start", "receiver")
                        .with_id(&self.device_id())
                        .with_field("action", "already_running"),
                );
                return Ok(());
            }
            let cancel = Arc::new(AtomicBool::new(false));
            let ctx = ReceiverContext {
                endpoint: self.endpoint.clone(),
                core: self.core.clone(),
                pending_pairing: self.pending_pairing.clone(),
                store: store.clone(),
                log: self.log.clone(),
                device_id: self.device_id(),
                log_verbose: self.log_verbose.load(Ordering::Relaxed),
                cancel: cancel.clone(),
                idle_windows: 0,
            };
            let join = tokio::spawn(receiver_loop(ctx));
            *guard = ReceiverHandle {
                cancel: Some(cancel),
                join: Some(join),
            };
        }
        self.emit_log(
            LogEvent::new("receiver.start", "receiver")
                .with_id(&self.device_id())
                .with_field("action", "success")
                .with_duration(started.elapsed()),
        );
        Ok(())
    }

    /// 停止被动接收任务（幂等；3 秒内返回）。
    ///
    /// 停止后接收任务不再处理新 push；已接受的连接处理完当前帧后退出。
    pub async fn stop_receiver(&self) -> Result<()> {
        let started = std::time::Instant::now();
        let (cancel, join) = {
            let mut guard = self.receiver.lock().unwrap();
            let handle = guard.join.take();
            let cancel = guard.cancel.take();
            (cancel, handle)
        };
        let was_running = join.is_some();
        if let Some(cancel) = cancel {
            cancel.store(true, Ordering::Relaxed);
        }
        if let Some(join) = join {
            // 有界等待：接收任务在 300ms accept 窗口结束前退出
            tokio::time::timeout(RECEIVER_STOP_TIMEOUT, join)
                .await
                .map_err(|_| {
                    anyhow::anyhow!(
                        "receiver task did not stop within {}s",
                        RECEIVER_STOP_TIMEOUT.as_secs()
                    )
                })?
                .map_err(|e| anyhow::anyhow!("receiver task panicked: {e}"))?;
        }
        self.emit_log(
            LogEvent::new("receiver.stop", "receiver")
                .with_id(&self.device_id())
                .with_field("action", "success")
                .with_field("was_running", was_running.to_string())
                .with_duration(started.elapsed()),
        );
        Ok(())
    }

    /// 接收任务是否运行中（诊断/测试用）。
    pub fn receiver_running(&self) -> bool {
        self.receiver.lock().unwrap().join.is_some()
    }

    /// 更新配对设备 last_seen 并输出结构化日志（触发原因配对/主动推送/被动接收）。
    ///
    /// 仅成功连接/同步后调用；失败路径不得调用（验收 14：失败不标记在线）。
    fn touch_last_seen(&self, store: &NoteStore, peer_id: &str, reason: &str) {
        match store.update_last_seen(peer_id) {
            Ok(()) => {
                self.emit_log(
                    LogEvent::new("device.last_seen", "device")
                        .with_id(&self.device_id())
                        .with_id(peer_id)
                        .with_field("reason", reason)
                        .with_field("action", "updated"),
                );
            }
            Err(e) => {
                self.emit_log(
                    LogEvent::new("device.last_seen", "device")
                        .with_id(&self.device_id())
                        .with_id(peer_id)
                        .with_field("reason", reason)
                        .with_field("action", "failed")
                        .with_error(&e.to_string())
                        .with_chain(&format!("{e:#}")),
                );
            }
        }
    }
}

// ━━━ 共享核心状态纯函数（任务 O：主服务与后台接收器共用）━━━

/// 全量快照导出（已持锁 core 的纯函数）。
fn export_core_all(core: &CoreState) -> Result<Vec<u8>> {
    let mut buf = Vec::new();
    // 墓碑 section 前缀
    buf.extend_from_slice(&(core.tombstones.len() as u32).to_le_bytes());
    let mut sorted: Vec<&String> = core.tombstones.iter().collect();
    sorted.sort();
    for id in sorted {
        let id_bytes = id.as_bytes();
        buf.extend_from_slice(&(id_bytes.len() as u32).to_le_bytes());
        buf.extend_from_slice(id_bytes);
    }
    // 笔记记录流
    for (note_id, note) in &core.notes {
        let snapshot = note.export_snapshot()?;
        let id_bytes = note_id.as_bytes();
        buf.extend_from_slice(&(id_bytes.len() as u32).to_le_bytes());
        buf.extend_from_slice(id_bytes);
        buf.extend_from_slice(&(snapshot.len() as u32).to_le_bytes());
        buf.extend_from_slice(&snapshot);
    }
    Ok(buf)
}

/// 导入全量快照（v3 语义：墓碑 section + 记录流；失败时整体回滚）。
fn import_core_all(core: &mut CoreState, data: &[u8]) -> Result<()> {
    let previous = export_core_all(core)?;
    import_core_raw(core, LORO_VERSION, data)?;
    if let Err(err) = persist_core(core) {
        core.notes.clear();
        core.tombstones.clear();
        import_core_raw(core, LORO_VERSION, &previous)?;
        return Err(err);
    }
    Ok(())
}

/// 导入 payload（已持锁 core）。`version` 决定是否含墓碑 section：
/// - v3：`墓碑 section + 记录流`（导入的墓碑与本地 tombstones union 合并；
///   记录流中遇到墓碑中的 id 跳过，不复活）
/// - v1/v2：纯记录流（无墓碑 section，tombstones 为空，无损升级）
fn import_core_raw(core: &mut CoreState, version: u32, data: &[u8]) -> Result<()> {
    let mut offset = 0;

    // ━━ 墓碑 section（仅 v3）━━
    let mut imported_tombstones: HashSet<String> = HashSet::new();
    if version >= 3 {
        if offset + 4 > data.len() {
            anyhow::bail!("truncated data: missing tombstone count");
        }
        let tombstone_count =
            u32::from_le_bytes(data[offset..offset + 4].try_into().unwrap()) as usize;
        offset += 4;
        for _ in 0..tombstone_count {
            if offset + 4 > data.len() {
                anyhow::bail!("truncated data: missing tombstone id length");
            }
            let id_len = u32::from_le_bytes(data[offset..offset + 4].try_into().unwrap()) as usize;
            offset += 4;
            if offset + id_len > data.len() {
                anyhow::bail!("truncated data: missing tombstone id");
            }
            let id = String::from_utf8(data[offset..offset + id_len].to_vec())
                .context("invalid UTF-8 in tombstone id")?;
            offset += id_len;
            imported_tombstones.insert(id);
        }
    }

    // ━━ 笔记记录流 ━━
    while offset < data.len() {
        // 读取 note_id_len (u32 LE)
        if offset + 4 > data.len() {
            anyhow::bail!("truncated data: missing note_id length");
        }
        let id_len = u32::from_le_bytes(data[offset..offset + 4].try_into().unwrap()) as usize;
        offset += 4;

        // 读取 note_id
        if offset + id_len > data.len() {
            anyhow::bail!("truncated data: missing note_id");
        }
        let note_id = String::from_utf8(data[offset..offset + id_len].to_vec())
            .context("invalid UTF-8 in note_id")?;
        offset += id_len;

        // 读取 snapshot_len (u32 LE)
        if offset + 4 > data.len() {
            anyhow::bail!("truncated data: missing snapshot length");
        }
        let snapshot_len =
            u32::from_le_bytes(data[offset..offset + 4].try_into().unwrap()) as usize;
        offset += 4;

        // 读取 snapshot
        if offset + snapshot_len > data.len() {
            anyhow::bail!("truncated data: missing snapshot body");
        }
        let snapshot = data[offset..offset + snapshot_len].to_vec();
        offset += snapshot_len;

        // 墓碑中的 id：跳过该记录（不复活）
        if imported_tombstones.contains(&note_id) || core.tombstones.contains(&note_id) {
            continue;
        }

        // 导入笔记
        let note = NoteCrdt::new();
        note.import_snapshot(&snapshot)?;
        core.notes.insert(note_id, note);
    }

    // 墓碑 union 合并
    core.tombstones.extend(imported_tombstones);
    Ok(())
}

/// 持久化（已持锁 core 的纯函数）。
fn persist_core(core: &CoreState) -> Result<()> {
    let Some(path) = &core.persistent_path else {
        return Ok(());
    };
    let payload = export_core_all(core)?;
    let bytes = encode_envelope(&payload);
    let mut file = AtomicWriteFile::options()
        .open(path)
        .with_context(|| format!("open atomic Loro file {}", path.display()))?;
    std::io::Write::write_all(&mut file, &bytes)?;
    file.commit().context("commit Loro file")?;
    Ok(())
}

// ━━━ 统一 incoming 路由（任务 O：接收器 / 配对 accept / 周期 accept 共用）━━━

/// 统一 incoming 处理：接受连接并按帧标记路由（后台接收器与主服务共用）。
///
/// 帧标记（M2 修复——不能用单字节判定，否则推送 payload 首字节 0x01 与配对帧
/// 冲突）：
/// - 前 8 字节 == `LORO_MAGIC`（"CARDMIND"）→ 推送帧：读完整 payload，
///   关闭连接通知发送端可释放，返回 `Ok(Some((sender_id, data)))`
///   （data 即 `export_all` 输出，`import_core_all` 直接消费；sender_id 取自
///   连接 TLS 证书——任务 O 据此更新发送方 last_seen，无需改协议）。
/// - 首字节 `PAIRING_FRAME_REQUEST (0x01)` → 配对请求帧：解析并存入
///   `pending_pairing`（供 `confirm_pairing` 在同一连接上回复握手响应），
///   返回 `Ok(None)`。
/// - 其他 → 报错（未知帧标记）。
///
/// 多个消费者（后台接收器 + 配对轮询 + 周期 accept）并发调用本函数安全：
/// 每个 `endpoint.accept()` 只取一个 incoming；路由目标（pending_pairing /
/// 返回的推送数据）互不冲突，不丢帧。
async fn route_incoming(
    incoming: iroh::endpoint::Incoming,
    pending_pairing: &Mutex<Option<PendingPairing>>,
) -> Result<Option<(iroh::EndpointId, Vec<u8>)>> {
    let conn = incoming.accept()?.await.context("accept connection")?;
    // 发送方身份：连接 TLS 证书中的 EndpointId（识别 inbound push 来源，
    // 用于精确更新 last_seen——无需在协议帧中带 sender_id）
    let sender_id = conn.remote_id();
    let mut recv = conn.accept_uni().await.context("accept uni stream")?;
    let mut marker = [0u8; LORO_MAGIC.len()];
    recv.read_exact(&mut marker)
        .await
        .context("read frame marker")?;
    if &marker == LORO_MAGIC {
        // 推送帧：剩余部分 = export_all 输出（[墓碑数][记录流]）
        let data = recv
            .read_to_end(usize::MAX)
            .await
            .context("read push data")?;
        // 数据已读入内存，主动关闭连接，通知发送端可释放
        conn.close(0u32.into(), b"done");
        return Ok(Some((sender_id, data)));
    }
    if marker[0] == PAIRING_FRAME_REQUEST {
        // 配对请求帧：marker(8) + 剩余 = 完整帧（从 0x01 开始）
        let mut rest = recv
            .read_to_end(usize::MAX)
            .await
            .context("read pairing request")?;
        let mut data = Vec::with_capacity(marker.len() + rest.len());
        data.extend_from_slice(&marker);
        data.append(&mut rest);
        let request = decode_pairing_request(&data)?;
        *pending_pairing.lock().unwrap() = Some(PendingPairing {
            request: request.clone(),
            conn,
        });
        return Ok(None);
    }
    anyhow::bail!("unknown incoming frame marker: {:?}", marker);
}

// ━━━ 后台接收任务循环（任务 O）━━━

/// 后台接收任务主体：持续短窗口 accept，收到推送帧立即 import + 投影 + last_seen。
///
/// - 停止信号（`cancel`）每窗口检查：stop 后 ≤1 窗口（300ms）内退出。
/// - 单次 accept/处理失败仅记录日志并继续下一窗口（验收 10：可恢复，不永久
///   退出、不 busy loop）。
/// - 同步开关不作用于接收：`sync_allowed` 只控制主动同步（push/sync cycle），
///   接收器始终接受连接（被动通道不阻塞编辑/推送）。
async fn receiver_loop(mut ctx: ReceiverContext) {
    loop {
        if ctx.cancel.load(Ordering::Relaxed) {
            receiver_log(&ctx, "receiver.end", "stopped", None);
            break;
        }
        // 注意：sync_allowed 存于 SyncService，接收任务不持有；由 start_receiver
        // 时快照。接收器始终接收（被动通道不阻塞编辑/推送），同步开关只由主服务
        // 在主动同步路径（run_sync_cycle/push）中检查。
        let incoming =
            match tokio::time::timeout(RECEIVER_ACCEPT_WINDOW, ctx.endpoint.accept()).await {
                Ok(Some(incoming)) => incoming,
                _ => {
                    // 窗口超时/无连接：正常空闲，继续下一窗口
                    ctx.idle_windows += 1;
                    if ctx.idle_windows.is_multiple_of(50) {
                        receiver_log(
                            &ctx,
                            "receiver.heartbeat",
                            "idle",
                            Some(&format!("windows={}", ctx.idle_windows)),
                        );
                    }
                    continue;
                }
            };
        ctx.idle_windows = 0;
        // 单帧处理：有界（握手 + 读帧 + import/投影/last_seen 全链路不超过 10s）
        let outcome = tokio::time::timeout(RECEIVER_PROCESS_TIMEOUT, async {
            receiver_handle_incoming(&mut ctx, incoming).await
        })
        .await;
        match outcome {
            Ok(Ok(())) => {}
            Ok(Err(e)) => {
                // 单次失败记录日志并继续（验收 10）
                receiver_log(
                    &ctx,
                    "sync.receive",
                    "failed_tolerated",
                    Some(&format!("error={e:#}")),
                );
            }
            Err(_) => {
                receiver_log(
                    &ctx,
                    "sync.receive",
                    "failed_timeout",
                    Some(&format!(
                        "timeout_ms={}",
                        RECEIVER_PROCESS_TIMEOUT.as_millis()
                    )),
                );
            }
        }
    }
}

/// 接收任务处理单个 incoming：统一路由 + 推送帧 import/投影/last_seen。
async fn receiver_handle_incoming(
    ctx: &mut ReceiverContext,
    incoming: iroh::endpoint::Incoming,
) -> Result<()> {
    let Some((sender_id, data)) = route_incoming(
        incoming,
        // 接收器也参与配对帧路由：配对请求被接收器抢到时正确存入
        // pending_pairing（confirm_pairing 仍可完成握手）——验收 9 统一路由
        &ctx.pending_pairing,
    )
    .await?
    else {
        // 配对帧：已路由到 pending_pairing，接收器继续等待
        return Ok(());
    };
    let started = std::time::Instant::now();
    let sender_str = sender_id.to_string();
    // sync.receive 成功日志（脱敏发送方）
    receiver_log(
        ctx,
        "sync.receive",
        "success",
        Some(&format!(
            "bytes={} sender={}",
            data.len(),
            redact_peer(&sender_str)
        )),
    );
    // 立即 import（共享 core）
    let import_result = {
        let mut core = ctx.core.lock().unwrap();
        import_core_all(&mut core, &data)
    };
    match import_result {
        Ok(()) => {
            let note_count = {
                let core = ctx.core.lock().unwrap();
                core.notes.len() + core.tombstones.len()
            };
            receiver_log(
                ctx,
                "sync.import",
                "success",
                Some(&format!(
                    "note_count={} bytes={} duration_ms={}",
                    note_count,
                    data.len(),
                    started.elapsed().as_millis()
                )),
            );
            // 刷新 SQLite 投影（收到 push 立即投影——设计目标 2）
            let core = ctx.core.lock().unwrap();
            let proj = sync_core_to_store(&core, &ctx.store);
            drop(core);
            proj?;
            // 更新发送方 last_seen（验收 12；触发原因 inbound_push）
            ctx.store
                .update_last_seen(&sender_str)
                .context("update sender last_seen")?;
            receiver_log(
                ctx,
                "device.last_seen",
                "updated",
                Some(&format!(
                    "peer={} reason=inbound_push",
                    redact_peer(&sender_str)
                )),
            );
        }
        Err(e) => {
            receiver_log(
                ctx,
                "sync.import",
                "failed_tolerated",
                Some(&format!("error={e:#}")),
            );
        }
    }
    Ok(())
}

/// 接收任务结构化日志（脱敏 device_id；verbose 事件过滤）。
fn receiver_log(ctx: &ReceiverContext, event: &str, action: &str, detail: Option<&str>) {
    if event.starts_with("receiver.heartbeat") && !ctx.log_verbose {
        return;
    }
    let mut ev = LogEvent::new(event, "receiver")
        .with_id(&ctx.device_id)
        .with_field("action", action);
    if let Some(d) = detail {
        for kv in d.split(' ') {
            if let Some((k, v)) = kv.split_once('=') {
                ev = ev.with_field(k, v);
            }
        }
    }
    debug_log::emit_to(&ctx.log, ev);
}

/// 脱敏 peer id（与 debug_log::redact_device_id 相同规则）。
fn redact_peer(id: &str) -> String {
    debug_log::redact_device_id(id)
}

/// 将 core 笔记投影到 SQLite（接收任务/主服务共用）。
fn sync_core_to_store(core: &CoreState, store: &NoteStore) -> Result<()> {
    for (id, note) in &core.notes {
        store.sync_note(id, note)?;
    }
    for id in &core.tombstones {
        store.purge_note(id)?;
    }
    Ok(())
}

fn loro_path(path: &Path) -> PathBuf {
    if path.extension().is_some_and(|ext| ext == "loro") {
        path.to_path_buf()
    } else {
        path.join("cardmind.loro")
    }
}

/// 从 RelayMode 提取 relay 端点（host + port），用于安全日志——
/// 只输出主机名与端口，绝不输出完整 URL 或凭据（user/password/token）。
fn relay_endpoint(mode: &RelayMode) -> (bool, Option<String>, Option<u16>) {
    let urls: Vec<iroh::RelayUrl> = mode.relay_map().urls();
    let Some(url) = urls.into_iter().next() else {
        return (false, None, None);
    };
    (true, url.host_str().map(str::to_string), url.port())
}

/// 从数据目录读取 relay 配置（任务 K，`relay.txt` 极简配置）：
/// - 文件存在但内容为空（trim 后）→ `RelayMode::Disabled`
/// - 内容为 relay URL → `RelayMode::Custom([url])`
/// - URL 解析失败 → 返回 Err（fail fast：配置错误要显式，不静默忽略）
///
/// `data_dir = None`（内存版）→ 恒 `Disabled`（测试隔离，不读文件）。
fn load_relay_mode(data_dir: Option<&Path>) -> Result<RelayMode> {
    let Some(dir) = data_dir else {
        return Ok(RelayMode::Disabled);
    };
    let relay_file = dir.join("relay.txt");
    if !relay_file.exists() {
        return Ok(RelayMode::Disabled);
    }
    let content = std::fs::read_to_string(&relay_file)
        .with_context(|| format!("read relay config {}", relay_file.display()))?;
    let url_str = content.trim();
    if url_str.is_empty() {
        return Ok(RelayMode::Disabled);
    }
    let url: iroh::RelayUrl = url_str
        .parse()
        .with_context(|| format!("invalid relay URL in {}: {url_str:?}", relay_file.display()))?;
    Ok(RelayMode::custom([url]))
}

/// 加载或创建设备身份密钥。
///
/// - `dir = Some(数据目录)`：读取 `device.key`（32 字节 hex）；不存在则生成并写入，
///   使持久化服务的 device_id 跨重启稳定。
/// - `dir = None`（内存版）：每次生成随机密钥，测试用。
fn load_or_create_secret_key(dir: Option<&Path>) -> Result<SecretKey> {
    let Some(dir) = dir else {
        return Ok(SecretKey::generate());
    };
    let key_path = dir.join("device.key");
    if key_path.exists() {
        let hex = std::fs::read_to_string(&key_path)
            .with_context(|| format!("read device key {}", key_path.display()))?;
        let bytes = decode_hex(hex.trim())
            .with_context(|| format!("invalid device key in {}", key_path.display()))?;
        let bytes: [u8; 32] = bytes
            .try_into()
            .map_err(|_| anyhow::anyhow!("device key must be 32 bytes"))?;
        Ok(SecretKey::from_bytes(&bytes))
    } else {
        let key = SecretKey::generate();
        let hex = encode_hex(key.to_bytes());
        std::fs::write(&key_path, hex)
            .with_context(|| format!("write device key {}", key_path.display()))?;
        Ok(key)
    }
}

/// 32 字节 → 64 字符小写 hex
fn encode_hex(bytes: [u8; 32]) -> String {
    let mut s = String::with_capacity(64);
    for b in bytes {
        s.push_str(&format!("{:02x}", b));
    }
    s
}

/// hex 字符串 → 字节（奇数长度或非法字符报错）
fn decode_hex(hex: &str) -> Result<Vec<u8>> {
    let hex = hex.trim();
    if !hex.len().is_multiple_of(2) {
        anyhow::bail!("odd hex length: {}", hex.len());
    }
    (0..hex.len())
        .step_by(2)
        .map(|i| {
            u8::from_str_radix(&hex[i..i + 2], 16)
                .map_err(|_| anyhow::anyhow!("invalid hex char at {}", i))
        })
        .collect()
}

fn encode_envelope(payload: &[u8]) -> Vec<u8> {
    let mut bytes = Vec::with_capacity(LORO_HEADER_LEN + payload.len());
    bytes.extend_from_slice(LORO_MAGIC);
    bytes.extend_from_slice(&LORO_VERSION.to_le_bytes());
    bytes.extend_from_slice(&(payload.len() as u64).to_le_bytes());
    bytes.extend_from_slice(payload);
    bytes
}

/// 网络推送线格式：8 字节 CARDMIND magic + `export_all` 输出。
///
/// M2 修复：接收端 `accept_incoming_routed` 以 magic 识别推送帧、以 0x01 识别
/// 配对帧。若无此前缀，`export_all` 输出首字节 = 墓碑数（u32 LE），墓碑数 = 1
/// （或 257/513…）时首字节恰为 0x01 = PAIRING_FRAME_REQUEST，推送帧会被误判为
/// 配对帧而数据丢失。
fn encode_push_wire(payload: &[u8]) -> Vec<u8> {
    let mut wire = Vec::with_capacity(LORO_MAGIC.len() + payload.len());
    wire.extend_from_slice(LORO_MAGIC);
    wire.extend_from_slice(payload);
    wire
}

/// 解码信封，返回 `(version, payload)`。
///
/// version = 1 时返回旧 payload 供迁移（不报错）；version = 2/3 正常载入
/// （v2 文件 = 纯记录流，v3 = 墓碑 section + 记录流，无损升级无需迁移数据）；
/// 其他版本报错。
fn decode_envelope(bytes: &[u8]) -> Result<(u32, Vec<u8>)> {
    if bytes.len() < LORO_HEADER_LEN || &bytes[..8] != LORO_MAGIC {
        anyhow::bail!("invalid cardmind.loro magic or truncated header");
    }
    let version = u32::from_le_bytes(bytes[8..12].try_into().unwrap());
    if version != 1 && version != 2 && version != LORO_VERSION {
        anyhow::bail!("unsupported cardmind.loro version: {}", version);
    }
    let length = u64::from_le_bytes(bytes[12..20].try_into().unwrap()) as usize;
    if length != bytes.len() - LORO_HEADER_LEN {
        anyhow::bail!("invalid cardmind.loro payload length");
    }
    Ok((version, bytes[LORO_HEADER_LEN..].to_vec()))
}

/// 默认设备名（主机名；无环境变量时回退固定名）
fn default_device_name() -> String {
    std::env::var("COMPUTERNAME")
        .or_else(|_| std::env::var("HOSTNAME"))
        .unwrap_or_else(|_| "CardMind Device".to_string())
}

// ━━━ 配对握手线协议编解码（二进制，length-prefixed）━━━
//
// 帧结构（请求）：
//   [0x01][code: u32 len + bytes][device_id: u32 len + bytes]
//   [device_name: u32 len + bytes][relay_info: u32 len + bytes]
//   [ips_count: u32][per ip: u32 len + bytes]
// 帧结构（响应）：
//   [0x02][device_id: u32 len + bytes][device_name: u32 len + bytes]

fn encode_pairing_request(request: &PairingRequest) -> Vec<u8> {
    let mut buf = Vec::new();
    buf.push(PAIRING_FRAME_REQUEST);
    push_str(&mut buf, &request.code);
    push_str(&mut buf, &request.device_id);
    push_str(&mut buf, &request.device_name);
    push_str(&mut buf, &request.relay_info);
    buf.extend_from_slice(&(request.ips.len() as u32).to_le_bytes());
    for ip in &request.ips {
        push_str(&mut buf, ip);
    }
    // v2 扩展：尾部追加 16 字节 nonce（hex String → 16 字节；旧实现解码时按缺省 [0;16] 处理）
    let nonce_bytes = nonce_from_hex(&request.nonce).unwrap_or([0u8; 16]);
    buf.extend_from_slice(&nonce_bytes);
    buf
}

fn decode_pairing_request(data: &[u8]) -> Result<PairingRequest> {
    let mut offset = 0;
    if data.is_empty() || data[0] != PAIRING_FRAME_REQUEST {
        anyhow::bail!("invalid pairing request frame");
    }
    offset += 1;
    let code = take_str(data, &mut offset, "code")?;
    let device_id = take_str(data, &mut offset, "device_id")?;
    let device_name = take_str(data, &mut offset, "device_name")?;
    let relay_info = take_str(data, &mut offset, "relay_info")?;
    if offset + 4 > data.len() {
        anyhow::bail!("truncated pairing request: missing ips count");
    }
    let ips_count = u32::from_le_bytes(data[offset..offset + 4].try_into().unwrap()) as usize;
    offset += 4;
    let mut ips = Vec::with_capacity(ips_count);
    for _ in 0..ips_count {
        ips.push(take_str(data, &mut offset, "ip")?);
    }
    // v2 扩展：尾部 16 字节 nonce；旧帧无该字段时按 [0;16]（兼容，confirm 侧仍校验）
    let nonce = if offset + 16 <= data.len() {
        let mut n = [0u8; 16];
        n.copy_from_slice(&data[offset..offset + 16]);
        n
    } else {
        [0u8; 16]
    };
    Ok(PairingRequest {
        code,
        device_id,
        device_name,
        relay_info,
        ips,
        nonce: nonce_to_hex(&nonce),
    })
}

fn encode_pairing_response(response: &PairingResponse) -> Vec<u8> {
    let mut buf = Vec::new();
    buf.push(PAIRING_FRAME_RESPONSE);
    push_str(&mut buf, &response.device_id);
    push_str(&mut buf, &response.device_name);
    buf
}

fn decode_pairing_response(data: &[u8]) -> Result<PairingResponse> {
    let mut offset = 0;
    if data.is_empty() || data[0] != PAIRING_FRAME_RESPONSE {
        anyhow::bail!("invalid pairing response frame");
    }
    offset += 1;
    let device_id = take_str(data, &mut offset, "device_id")?;
    let device_name = take_str(data, &mut offset, "device_name")?;
    Ok(PairingResponse {
        device_id,
        device_name,
    })
}

/// 写入 u32 长度前缀 + UTF-8 字符串
fn push_str(buf: &mut Vec<u8>, s: &str) {
    buf.extend_from_slice(&(s.len() as u32).to_le_bytes());
    buf.extend_from_slice(s.as_bytes());
}

/// 读取 u32 长度前缀 + UTF-8 字符串
fn take_str(data: &[u8], offset: &mut usize, field: &str) -> Result<String> {
    if *offset + 4 > data.len() {
        anyhow::bail!("truncated pairing frame: missing {field} length");
    }
    let len = u32::from_le_bytes(data[*offset..*offset + 4].try_into().unwrap()) as usize;
    *offset += 4;
    if *offset + len > data.len() {
        anyhow::bail!("truncated pairing frame: missing {field}");
    }
    let s = String::from_utf8(data[*offset..*offset + len].to_vec())
        .with_context(|| format!("invalid UTF-8 in {field}"))?;
    *offset += len;
    Ok(s)
}

/// 16 字节 nonce → 32 字符小写 hex 字符串（FRB 边界表示；测试取会话 nonce 用）。
pub fn nonce_to_hex(nonce: &[u8; 16]) -> String {
    let mut s = String::with_capacity(32);
    for b in nonce {
        s.push_str(&format!("{b:02x}"));
    }
    s
}

/// node_id bytes → base32 编码字符串（与 iroh EndpointId 显示一致，供 FRB/日志脱敏）。
fn base32_encode_node_id(bytes: &[u8; 32]) -> String {
    PublicKey::from_bytes(bytes)
        .map(|pk| pk.to_string())
        .unwrap_or_default()
}

/// 32 字符小写 hex 字符串 → 16 字节 nonce。长度或字符非法时返回错误。
pub(crate) fn nonce_from_hex(hex: &str) -> Result<[u8; 16]> {
    if hex.len() != 32 {
        anyhow::bail!("invalid nonce hex length");
    }
    let mut out = [0u8; 16];
    for (i, chunk) in hex.as_bytes().chunks(2).enumerate() {
        let hi = (chunk[0] as char)
            .to_digit(16)
            .context("invalid nonce hex")? as u8;
        let lo = (chunk[1] as char)
            .to_digit(16)
            .context("invalid nonce hex")? as u8;
        out[i] = (hi << 4) | lo;
    }
    Ok(out)
}

// ━━━ 签名配对凭证（任务 Q）━━━

/// 配对凭证 v1 协议常量。
const CREDENTIAL_MAGIC: &[u8; 2] = b"CM";
const CREDENTIAL_VERSION: u8 = 1;
const CREDENTIAL_PAYLOAD_LEN: usize = 2 + 1 + 8 + 8 + 16 + 32 + 4; // 71
const CREDENTIAL_SIGNATURE_LEN: usize = 64;
pub const CREDENTIAL_FINAL_LEN: usize = CREDENTIAL_PAYLOAD_LEN + CREDENTIAL_SIGNATURE_LEN; // 135
const CREDENTIAL_TTL_SECS: u64 = 10 * 60;
const CREDENTIAL_CLOCK_SKEW_SECS: u64 = 60;
const CREDENTIAL_PREFIX: &str = "cm1.";

/// 原始 v1 凭证字节 `canonical_payload || signature`。
pub type RawCredential = [u8; CREDENTIAL_FINAL_LEN];

/// 解析后的凭证字段（内部使用）。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ParsedCredentialFields {
    pub node_id_bytes: [u8; 32],
    pub pairing_code: u32,
    pub expires_at: u64,
    pub nonce: [u8; 16],
}

/// 构建 canonical payload（71 字节，全大端）。
fn build_canonical_payload(
    issued_at: u64,
    expires_at: u64,
    nonce: &[u8; 16],
    node_id: &[u8; 32],
    pairing_code: u32,
) -> Result<[u8; CREDENTIAL_PAYLOAD_LEN]> {
    if !(100000..=999999).contains(&pairing_code) {
        anyhow::bail!("pairing_code out of range: {pairing_code}");
    }
    let mut buf = [0u8; CREDENTIAL_PAYLOAD_LEN];
    buf[0..2].copy_from_slice(CREDENTIAL_MAGIC);
    buf[2] = CREDENTIAL_VERSION;
    buf[3..11].copy_from_slice(&issued_at.to_be_bytes());
    buf[11..19].copy_from_slice(&expires_at.to_be_bytes());
    buf[19..35].copy_from_slice(nonce);
    buf[35..67].copy_from_slice(node_id);
    buf[67..71].copy_from_slice(&pairing_code.to_be_bytes());
    Ok(buf)
}

/// 生成签名并拼装最终凭证字节（135 字节）。
pub fn encode_credential(
    secret_key: &SecretKey,
    issued_at: u64,
    expires_at: u64,
    nonce: &[u8; 16],
    node_id: &[u8; 32],
    pairing_code: u32,
) -> Result<RawCredential> {
    let payload = build_canonical_payload(issued_at, expires_at, nonce, node_id, pairing_code)?;
    let signature = secret_key.sign(&payload);
    let mut out = [0u8; CREDENTIAL_FINAL_LEN];
    out[..CREDENTIAL_PAYLOAD_LEN].copy_from_slice(&payload);
    out[CREDENTIAL_PAYLOAD_LEN..].copy_from_slice(&signature.to_bytes());
    Ok(out)
}

/// 解析并验证凭证字节（长度/magic/version/时间窗口/验签）。
pub fn parse_credential(raw: &[u8], now: u64) -> Result<ParsedCredentialFields> {
    let final_bytes: &[u8; CREDENTIAL_FINAL_LEN] = raw
        .try_into()
        .map_err(|_| anyhow::anyhow!("invalid credential length: {}", raw.len()))?;
    let (payload, signature_bytes) = final_bytes.split_at(CREDENTIAL_PAYLOAD_LEN);

    if &payload[0..2] != CREDENTIAL_MAGIC {
        anyhow::bail!("invalid credential magic");
    }
    if payload[2] != CREDENTIAL_VERSION {
        anyhow::bail!("unsupported credential version: {}", payload[2]);
    }

    let issued_at = u64::from_be_bytes(payload[3..11].try_into().unwrap());
    let expires_at = u64::from_be_bytes(payload[11..19].try_into().unwrap());
    let nonce: [u8; 16] = payload[19..35].try_into().unwrap();
    let node_id_bytes: [u8; 32] = payload[35..67].try_into().unwrap();
    let pairing_code = u32::from_be_bytes(payload[67..71].try_into().unwrap());

    if !(100000..=999999).contains(&pairing_code) {
        anyhow::bail!("pairing_code out of range: {pairing_code}");
    }
    if issued_at > now.saturating_add(CREDENTIAL_CLOCK_SKEW_SECS) {
        anyhow::bail!("credential issued_at too far in the future");
    }
    if expires_at <= issued_at {
        anyhow::bail!("credential expires_at must be after issued_at");
    }
    if expires_at - issued_at > CREDENTIAL_TTL_SECS {
        anyhow::bail!("credential ttl exceeds maximum");
    }
    if expires_at <= now {
        anyhow::bail!("credential expired");
    }

    let public_key = PublicKey::from_bytes(&node_id_bytes)
        .map_err(|_| anyhow::anyhow!("invalid node_id public key"))?;
    let signature = Signature::from_bytes(
        &<[u8; CREDENTIAL_SIGNATURE_LEN]>::try_from(signature_bytes)
            .expect("split_at yields 64-byte signature"),
    );
    public_key
        .verify(payload, &signature)
        .map_err(|_| anyhow::anyhow!("credential signature invalid"))?;

    Ok(ParsedCredentialFields {
        node_id_bytes,
        pairing_code,
        expires_at,
        nonce,
    })
}

/// 最终字符串：`cm1.` + base64url(无 padding)。
pub fn credential_to_string(raw: &RawCredential) -> String {
    use base64::Engine;
    let b64 = base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(raw);
    format!("{CREDENTIAL_PREFIX}{b64}")
}

/// 字符串 → 凭证字节（严格 `cm1.` 前缀 + base64url，无 padding）。
pub fn credential_from_string(s: &str) -> Result<RawCredential> {
    use base64::Engine;
    let Some(rest) = s.strip_prefix(CREDENTIAL_PREFIX) else {
        anyhow::bail!("invalid credential prefix");
    };
    if rest.is_empty()
        || !rest
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_')
    {
        anyhow::bail!("invalid credential base64url");
    }
    let decoded = base64::engine::general_purpose::URL_SAFE_NO_PAD
        .decode(rest)
        .map_err(|_| anyhow::anyhow!("invalid credential base64url"))?;
    let decoded_len = decoded.len();
    let arr: RawCredential = decoded
        .try_into()
        .map_err(|_| anyhow::anyhow!("invalid credential length: {}", decoded_len))?;
    Ok(arr)
}

// ━━━ FRB 边界凭证类型（任务 Q）━━━

/// 显示方生成的配对凭证展示对象（过 FRB）。
#[derive(Debug, Clone)]
pub struct PairingCredentialDisplay {
    /// 6 位数字配对码（局域网旧流程兼容）
    pub code: String,
    /// 完整凭证字符串（`cm1.` + base64url，二维码与复制文本逐字相同）
    pub credential: String,
    /// 过期时间 RFC3339 UTC（供 UI 倒计时）
    pub expires_at: String,
}

/// 发起方解析后的配对凭证字段（过 FRB；nonce 仅内部 FRB→握手传递）。
#[derive(Debug, Clone)]
pub struct ParsedPairingCredential {
    pub code: String,
    pub device_id: String,
    pub expires_at: String,
    pub nonce: String,
}

// ━━━ 配对凭证用户错误分类（任务 Q；FRB codegen 后 Dart 侧按 kind 映射中文文案）━━━

/// 用户可读的配对凭证错误分类（过 FRB；Dart 侧 match，避免字符串匹配）。
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PairingCredentialErrorKind {
    /// 凭证字符串格式无效（前缀/版本/长度/base64）
    InvalidFormat,
    /// 签名无效 / 载荷被篡改
    InvalidSignature,
    /// 凭证已过期
    Expired,
    /// 凭证已使用或被新凭证替代（会话已更换/清除）
    UsedOrReplaced,
    /// 目标设备不可达（连接失败/超时/无握手响应）
    Unreachable,
    /// 其它内部错误
    Internal,
}

/// 配对凭证错误（过 FRB；携带稳定 kind + 技术细节 message）。
#[derive(Debug, Clone)]
pub struct PairingCredentialError {
    pub kind: PairingCredentialErrorKind,
    pub message: String,
}

impl std::fmt::Display for PairingCredentialError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}: {}", error_kind_label(&self.kind), self.message)
    }
}

impl std::error::Error for PairingCredentialError {}

/// 把底层 anyhow 错误归类为稳定用户错误（凭证解析错误精确分类；
/// 连接类错误归类为 Unreachable）。
fn credential_error(err: anyhow::Error) -> PairingCredentialError {
    let msg = err.to_string();
    let kind = if msg.contains("expired")
        || msg.contains("future")
        || msg.contains("TTL")
        || msg.contains("issued")
    {
        PairingCredentialErrorKind::Expired
    } else if msg.contains("signature") {
        PairingCredentialErrorKind::InvalidSignature
    } else if msg.contains("credential")
        || msg.contains("base64")
        || msg.contains("length")
        || msg.contains("prefix")
        || msg.contains("version")
    {
        PairingCredentialErrorKind::InvalidFormat
    } else {
        PairingCredentialErrorKind::Internal
    };
    PairingCredentialError { kind, message: msg }
}

/// 凭证错误 kind 的稳定标签（Display 用）。
fn error_kind_label(kind: &PairingCredentialErrorKind) -> &'static str {
    match kind {
        PairingCredentialErrorKind::InvalidFormat => "invalidFormat",
        PairingCredentialErrorKind::InvalidSignature => "invalidSignature",
        PairingCredentialErrorKind::Expired => "expired",
        PairingCredentialErrorKind::UsedOrReplaced => "usedOrReplaced",
        PairingCredentialErrorKind::Unreachable => "unreachable",
        PairingCredentialErrorKind::Internal => "internal",
    }
}

impl SyncService {
    /// 显示方：生成签名配对凭证（新 code + 新 nonce，使旧凭证失效）。
    ///
    /// 原子地创建 `PairingSession`（含新 nonce），并用持久化 SecretKey 签名。
    pub fn begin_pairing_credential(&self) -> Result<PairingCredentialDisplay> {
        let mut rng = rand::rngs::OsRng;
        let code_num: u32 = rng.gen_range(100000..=999999);
        let code = format!("{code_num:06}");
        let nonce: [u8; 16] = rng.gen();

        let now = Utc::now();
        let issued_at = now.timestamp() as u64;
        let expires_at = issued_at + CREDENTIAL_TTL_SECS;
        let node_id = *self.endpoint.id().as_bytes();

        let raw = encode_credential(
            &self.secret_key,
            issued_at,
            expires_at,
            &nonce,
            &node_id,
            code_num,
        )?;
        let credential = credential_to_string(&raw);
        let expires_at_rfc3339 =
            (now + chrono::Duration::seconds(CREDENTIAL_TTL_SECS as i64)).to_rfc3339();

        // 原子进入同一配对会话：code + nonce 同时更新，清除旧 pending
        let session = PairingSession {
            code: code.clone(),
            created_at: now,
            failed_attempts: 0,
            nonce,
        };
        *self.pairing_session.lock().unwrap() = Some(session);
        *self.pending_pairing.lock().unwrap() = None;

        self.emit_log(
            LogEvent::new("pairing.show_code", "pairing.show_code")
                .with_id(&self.device_id())
                .with_field("action", "success"),
        );

        Ok(PairingCredentialDisplay {
            code,
            credential,
            expires_at: expires_at_rfc3339,
        })
    }

    /// 显示方：生成签名配对凭证并启动 mDNS 广播（组合 API，任务 Q）。
    ///
    /// 凭证/会话与广播在同一调用内完成（与 [`Self::begin_pairing_accept_with_advertising`]
    /// 同模式）——确认方显示凭证弹窗期间广播一定在，供 6 位码路径使用：
    /// 发起方输入弹窗中的 6 位码后经 mDNS 发现本机，TXT 中携带会话 nonce，
    /// 发起方回填 `PairingTarget.nonce` 才能通过 confirm 侧强制 nonce 校验。
    /// 停止广播由 [`Self::stop_pairing_advertising`] 负责（弹窗关闭等）。
    pub async fn begin_pairing_credential_with_advertising(
        &self,
    ) -> Result<PairingCredentialDisplay> {
        let started = std::time::Instant::now();
        let display = self.begin_pairing_credential()?;
        // 当前会话 nonce（hex），随 mDNS TXT 广播，供发起方回填 PairingTarget
        let nonce_hex = self.session_nonce_hex();
        let port = self.endpoint_listen_port();
        let mut guard = self.discovery.lock().await;
        if guard.is_none() {
            *guard = Some(DiscoveryService::new()?);
        }
        let result = guard
            .as_mut()
            .expect("discovery just ensured")
            .start_advertising(&self.device_id(), port, &nonce_hex);
        let duration = started.elapsed();
        match &result {
            Ok(()) => {
                self.emit_log(
                    LogEvent::new("pairing.advertise", "pairing.advertise")
                        .with_id(&self.device_id())
                        .with_field("action", "start")
                        .with_field("port", port.to_string())
                        .with_duration(duration),
                );
            }
            Err(e) => {
                self.emit_log(
                    LogEvent::new("pairing.advertise", "pairing.advertise")
                        .with_id(&self.device_id())
                        .with_field("action", "failed")
                        .with_error(&e.to_string())
                        .with_chain(&format!("{e:#}"))
                        .with_duration(duration),
                );
            }
        }
        result?;
        Ok(display)
    }

    /// 发起方：解析并验证凭证字符串（验签、时间窗口、长度）。
    ///
    /// 返回 `ParsedPairingCredential`（device_id 为 base32 编码，供 FRB 展示/日志脱敏）。
    /// 错误归类为稳定的 [`PairingCredentialError`]（Dart 侧按 kind 映射中文文案）。
    pub fn parse_pairing_credential(
        &self,
        credential: &str,
    ) -> Result<ParsedPairingCredential, PairingCredentialError> {
        let raw = credential_from_string(credential).map_err(credential_error)?;
        let now = Utc::now().timestamp() as u64;
        let parsed = parse_credential(&raw, now).map_err(credential_error)?;
        let device_id = base32_encode_node_id(&parsed.node_id_bytes);
        let expires_at = chrono::DateTime::<Utc>::from_timestamp(parsed.expires_at as i64, 0)
            .map(|dt| dt.to_rfc3339())
            .unwrap_or_default();
        Ok(ParsedPairingCredential {
            code: format!("{:06}", parsed.pairing_code),
            device_id,
            expires_at,
            nonce: nonce_to_hex(&parsed.nonce),
        })
    }

    /// 发起方：凭证垂直入口——parse/verify → 构造 PairingTarget → 直连/relay 连接。
    ///
    /// `ips=[]` 时沿用 `build_connect_addr`（发起端自己的可选 relay.txt）。
    /// 凭证解析错误精确分类；连接类错误归类为 `Unreachable`。
    pub async fn begin_pairing_connect_with_credential(
        &self,
        store: &NoteStore,
        credential: &str,
    ) -> Result<PairingResult, PairingCredentialError> {
        let parsed = self.parse_pairing_credential(credential)?;
        let target = PairingTarget {
            device_id: parsed.device_id,
            ips: vec![],
            nonce: parsed.nonce,
        };
        self.begin_pairing_connect(store, &parsed.code, target)
            .await
            .map_err(|err| PairingCredentialError {
                kind: PairingCredentialErrorKind::Unreachable,
                message: err.to_string(),
            })
    }
}

// ━━━ NoteCrdt ━━━

impl NoteCrdt {
    /// 创建新笔记
    pub fn new() -> Self {
        Self {
            doc: LoroDoc::new(),
        }
    }

    /// 设置完整内容（替换）
    ///
    /// 先删除已有内容，再在 0 位置插入新文本。
    pub fn set_content(&self, markdown: &str) {
        let text = self.doc.get_text("content");
        let len = text.len_unicode();
        if len > 0 {
            text.delete(0, len).unwrap();
        }
        text.insert(0, markdown).unwrap();
    }

    /// 获取当前内容
    pub fn get_content(&self) -> String {
        self.doc.get_text("content").to_string()
    }

    /// 获取首行作为标题（去除 `#` 前缀）
    ///
    /// 取第一行，去除开头的 `#` 及空白字符。
    pub fn get_title(&self) -> String {
        let content = self.get_content();
        remove_tag_marker(&content)
            .lines()
            .next()
            .map(|line| line.trim().trim_start_matches('#').trim())
            .unwrap_or_default()
            .to_string()
    }

    /// 生成一个新的笔记 ID（UUID v7）
    pub fn generate_note_id() -> String {
        Uuid::now_v7().to_string()
    }

    /// 读取 meta tags（Loro list）为 Vec<String>
    pub fn get_tags(&self) -> Vec<String> {
        match self.doc.get_map("meta").get("tags") {
            Some(ValueOrContainer::Container(Container::List(list))) => list
                .to_vec()
                .iter()
                .filter_map(|v| match v {
                    LoroValue::String(s) => Some(s.to_string()),
                    _ => None,
                })
                .collect(),
            _ => Vec::new(),
        }
    }

    /// 整组替换 meta tags（Loro list）
    pub fn set_tags(&self, tags: &[String]) {
        let map = self.doc.get_map("meta");
        let list = match map.get("tags") {
            Some(ValueOrContainer::Container(Container::List(list))) => list,
            _ => map
                .insert_container("tags", loro::LoroList::new())
                .expect("insert tags list container"),
        };
        list.clear().expect("clear tags list");
        for tag in tags {
            list.push(tag.as_str()).expect("push tag");
        }
    }

    /// 读取 meta.created_at
    pub fn get_created_at(&self) -> String {
        meta_string(&self.doc, "created_at")
    }

    /// 设置 meta.created_at
    pub fn set_created_at(&self, value: &str) {
        self.doc
            .get_map("meta")
            .insert("created_at", value)
            .expect("set created_at");
    }

    /// 读取 meta.updated_at
    pub fn get_updated_at(&self) -> String {
        meta_string(&self.doc, "updated_at")
    }

    /// 设置 meta.updated_at
    pub fn set_updated_at(&self, value: &str) {
        self.doc
            .get_map("meta")
            .insert("updated_at", value)
            .expect("set updated_at");
    }

    /// 读取 meta.deleted_at（软删时间；未删除 = None）
    pub fn get_deleted_at(&self) -> Option<String> {
        match self.doc.get_map("meta").get("deleted_at") {
            Some(ValueOrContainer::Value(LoroValue::String(s))) => Some(s.to_string()),
            _ => None,
        }
    }

    /// 设置/清除 meta.deleted_at：`Some(now)` 软删，`None` 恢复。
    pub fn set_deleted_at(&self, value: Option<String>) {
        let map = self.doc.get_map("meta");
        match value {
            Some(v) => {
                map.insert("deleted_at", v.as_str())
                    .expect("set deleted_at");
            }
            None => {
                map.delete("deleted_at").expect("delete deleted_at");
            }
        }
    }

    /// 解析正文中的 `[[target-id|alias]]` 链接 → `(target_id, alias)`
    ///
    /// alias 缺省时取 target_id。格式：`[[target|alias]]`，无 alias 时 `[[target]]`。
    pub fn parse_links(&self) -> Vec<(String, String)> {
        parse_links_from_content(&self.get_content())
    }

    /// 导出全量快照
    pub fn export_snapshot(&self) -> Result<Vec<u8>> {
        self.doc
            .export(ExportMode::snapshot())
            .map_err(|e| anyhow::anyhow!(e))
    }

    /// 导入全量快照
    pub fn import_snapshot(&self, data: &[u8]) -> Result<()> {
        self.doc.import(data).map_err(|e| anyhow::anyhow!(e))?;
        Ok(())
    }
}

fn remove_tag_marker(content: &str) -> String {
    const MARKER: &str = "<!--tags:";
    let Some(start) = content.find(MARKER) else {
        return content.to_string();
    };
    let after_marker = start + MARKER.len();
    let Some(relative_end) = content[after_marker..].find("-->") else {
        return content.to_string();
    };
    let end = after_marker + relative_end + 3;
    let mut clean = String::with_capacity(content.len() - (end - start));
    clean.push_str(&content[..start]);
    clean.push_str(&content[end..]);
    clean.trim_start_matches(['\r', '\n']).to_string()
}

/// 提取 `<!--tags:...-->` 中的 tag 字符串（不含前后缀）。
fn extract_tag_marker(content: &str) -> String {
    const MARKER: &str = "<!--tags:";
    let Some(start) = content.find(MARKER) else {
        return String::new();
    };
    let after_marker = start + MARKER.len();
    let Some(relative_end) = content[after_marker..].find("-->") else {
        return String::new();
    };
    content[after_marker..after_marker + relative_end]
        .trim()
        .to_string()
}

/// 解析正文中的 `[[target-id|alias]]` 链接
fn parse_links_from_content(content: &str) -> Vec<(String, String)> {
    let mut links = Vec::new();
    let mut rest = content;
    while let Some(start) = rest.find("[[") {
        let after = &rest[start + 2..];
        let Some(end_rel) = after.find("]]") else {
            break;
        };
        let inner = &after[..end_rel];
        let (target, alias) = match inner.split_once('|') {
            Some((t, a)) => (t.trim(), a.trim()),
            None => (inner.trim(), ""),
        };
        if !target.is_empty() {
            let alias = if alias.is_empty() { target } else { alias };
            links.push((target.to_string(), alias.to_string()));
        }
        rest = &after[end_rel + 2..];
    }
    links
}

/// 读取 meta Map 的字符串字段
fn meta_string(doc: &LoroDoc, key: &str) -> String {
    match doc.get_map("meta").get(key) {
        Some(ValueOrContainer::Value(LoroValue::String(s))) => s.to_string(),
        _ => String::new(),
    }
}

impl Default for NoteCrdt {
    fn default() -> Self {
        Self::new()
    }
}
