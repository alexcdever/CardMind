use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Mutex;
use std::time::Duration;

use anyhow::{Context, Result};
use atomic_write_file::AtomicWriteFile;
use chrono::{DateTime, Utc};
use iroh::{endpoint::presets, Endpoint, EndpointAddr, RelayMode, SecretKey, TransportAddr};
use loro::{Container, ExportMode, LoroDoc, LoroValue, ValueOrContainer};
use rand::Rng;
use uuid::Uuid;

use crate::discovery::{DiscoveryService, PeerInfo};
use crate::store::NoteStore;

/// 同步服务 — 管理笔记集合并通过 iroh 与对端同步
pub struct SyncService {
    notes: HashMap<String, NoteCrdt>,
    /// 已彻底删除的笔记 id 集合（墓碑）。删除信息随快照传播，防止
    /// `sync_notes_to_store` 从 Loro 快照重建被删笔记（复活）。
    tombstones: HashSet<String>,
    endpoint: Endpoint,
    /// 构造时使用的 relay 模式（任务 K 配置化：默认 Disabled 仅局域网；
    /// 持久化版读取 `<数据目录>/relay.txt` 可配置 Custom）
    relay_mode: RelayMode,
    persistent_path: Option<PathBuf>,
    /// 当前配对码会话（内存态；10 分钟有效，重启失效可接受——用户重新发起）
    pairing_session: Mutex<Option<PairingSession>>,
    /// 确认方已接收、等待用户确认的配对请求及其连接（确认时回复握手响应）
    pending_pairing: Mutex<Option<PendingPairing>>,
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
}

/// NoteCrdt — LoroDoc 笔记模型
///
/// 每个笔记一个独立的 LoroDoc，支持创建/读写/快照/增量同步。
/// 正文存于 `content` Text 容器；元数据（tags/created_at/updated_at）存于 `meta` Map 容器。
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
        let key = load_or_create_secret_key(None)?;
        let relay_mode = RelayMode::Disabled;
        let endpoint = Endpoint::builder(presets::N0)
            .secret_key(key)
            .alpns(vec![ALPN.to_vec()])
            .relay_mode(relay_mode.clone())
            .bind()
            .await
            .context("bind iroh endpoint")?;
        Ok(Self {
            notes: HashMap::new(),
            tombstones: HashSet::new(),
            endpoint,
            relay_mode,
            persistent_path: None,
            pairing_session: Mutex::new(None),
            pending_pairing: Mutex::new(None),
            device_name: Mutex::new(default_device_name()),
            sync_allowed: AtomicBool::new(true),
            pending_dirty: Mutex::new(HashSet::new()),
            last_pushed_at: Mutex::new(HashMap::new()),
            peer_ips: Mutex::new(HashMap::new()),
            discovery: tokio::sync::Mutex::new(None),
        })
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
        let path = loro_path(path.as_ref());
        let data_dir = path.parent().map(Path::to_path_buf);
        if let Some(parent) = &data_dir {
            std::fs::create_dir_all(parent)
                .with_context(|| format!("create data directory {}", parent.display()))?;
        }
        let key = load_or_create_secret_key(data_dir.as_deref())?;
        let relay_mode = load_relay_mode(data_dir.as_deref())?;
        let endpoint = Endpoint::builder(presets::N0)
            .secret_key(key)
            .alpns(vec![ALPN.to_vec()])
            .relay_mode(relay_mode.clone())
            .bind()
            .await
            .context("bind iroh endpoint")?;
        let mut service = Self {
            notes: HashMap::new(),
            tombstones: HashSet::new(),
            endpoint,
            relay_mode,
            persistent_path: Some(path.clone()),
            pairing_session: Mutex::new(None),
            pending_pairing: Mutex::new(None),
            device_name: Mutex::new(default_device_name()),
            sync_allowed: AtomicBool::new(true),
            pending_dirty: Mutex::new(HashSet::new()),
            last_pushed_at: Mutex::new(HashMap::new()),
            peer_ips: Mutex::new(HashMap::new()),
            discovery: tokio::sync::Mutex::new(None),
        };
        if path.exists() {
            let bytes = std::fs::read(&path)
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
                std::fs::copy(&path, &backup)
                    .with_context(|| format!("backup v1 file to {}", backup.display()))?;
                let now = chrono::Utc::now().to_rfc3339();
                let note_ids: Vec<String> = service.notes.keys().cloned().collect();
                for note_id in note_ids {
                    let note = &service.notes[&note_id];
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
                    service.notes.insert(id, note);
                }
                service.persist()?;
            }
        }
        Ok(service)
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
        let session = PairingSession {
            code: code.clone(),
            created_at: Utc::now(),
            failed_attempts: 0,
        };
        *self.pairing_session.lock().unwrap() = Some(session);
        // 新码产生时清除上一次未完成的待确认请求（避免旧连接回复错码）
        *self.pending_pairing.lock().unwrap() = None;
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
        let code = self.begin_pairing_accept()?;
        let port = self.endpoint_listen_port();
        let mut guard = self.discovery.lock().await;
        if guard.is_none() {
            *guard = Some(DiscoveryService::new()?);
        }
        guard
            .as_mut()
            .expect("discovery just ensured")
            .start_advertising(&self.device_id(), port)?;
        Ok(code)
    }

    /// 停止 mDNS 广播（弹窗关闭 / 配对完成 / 取消时调用；幂等）。
    ///
    /// DiscoveryService 实例保留（后续再组合调用时复用 daemon），仅注销注册。
    pub async fn stop_pairing_advertising(&self) -> Result<()> {
        let mut guard = self.discovery.lock().await;
        if let Some(disc) = guard.as_mut() {
            disc.stop_advertising()?;
        }
        Ok(())
    }

    /// 发起方：mDNS 扫描局域网内的 CardMind 设备（约 3 秒超时，任务 J）。
    ///
    /// 复用共享 DiscoveryService（惰性创建）；返回对端 device_id + ip:port，
    /// 供 UI 在设备 ID 留空时自动填充配对目标。扫描超时或通道断开返回
    /// 已收集的结果（可能为空），不报错。
    pub async fn discover_peers(&self) -> Result<Vec<PeerInfo>> {
        let mut guard = self.discovery.lock().await;
        if guard.is_none() {
            *guard = Some(DiscoveryService::new()?);
        }
        guard
            .as_mut()
            .expect("discovery just ensured")
            .discover_peers()
            .await
    }

    /// 当前配对会话（测试/诊断用）。
    pub fn current_pairing_session(&self) -> Option<PairingSession> {
        self.pairing_session.lock().unwrap().clone()
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
                        eprintln!(
                            "[sync] accept_pairing_request: import push failed (tolerated): {e:#}"
                        );
                    }
                }
                Ok(None) => {}
                Err(e) => {
                    eprintln!(
                        "[sync] accept_pairing_request: route incoming failed (tolerated): {e:#}"
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
        self.validate_pairing_code(code)?;

        // 请求携带的码必须与当前会话一致（防错配/重放请求）
        {
            let guard = self.pairing_session.lock().unwrap();
            if let Some(session) = guard.as_ref() {
                if !requester.code.is_empty() && session.code != requester.code {
                    anyhow::bail!("pairing code mismatch in request");
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
                eprintln!(
                    "[pairing] initial full sync to {} failed (tolerated): {e:#}",
                    requester.device_id
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
        let node_id: iroh::EndpointId = target
            .device_id
            .parse()
            .context("invalid target endpoint id")?;
        let addr = self.build_connect_addr(node_id, &target.ips)?;

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

    /// 添加/创建一条笔记
    pub fn create_note(&mut self, note_id: String, content: &str) -> Result<()> {
        let note = NoteCrdt::new();
        note.set_content(content);
        let previous = self.notes.remove(&note_id);
        self.notes.insert(note_id.clone(), note);
        if let Err(err) = self.persist() {
            self.notes.remove(&note_id);
            if let Some(previous) = previous {
                self.notes.insert(note_id, previous);
            }
            return Err(err);
        }
        // 编辑保存即推送：标记待同步（推送由调度器异步执行，不阻塞编辑）
        self.mark_sync_pending(&note_id);
        Ok(())
    }

    /// 遍历所有笔记（用于同步到 SQLite）  
    pub fn iter_notes(&self) -> impl Iterator<Item = (&String, &NoteCrdt)> {
        self.notes.iter()
    }

    /// 更新笔记内容
    pub fn update_note(&mut self, note_id: &str, content: &str) -> Result<()> {
        let previous = {
            let note = self
                .notes
                .get(note_id)
                .ok_or_else(|| anyhow::anyhow!("note not found: {}", note_id))?;
            let previous = note.get_content();
            note.set_content(content);
            previous
        };
        if let Err(err) = self.persist() {
            if let Some(note) = self.notes.get(note_id) {
                note.set_content(&previous);
            }
            return Err(err);
        }
        self.mark_sync_pending(note_id);
        Ok(())
    }

    /// 更新笔记元数据（meta tags）
    ///
    /// 更新 NoteCrdt 的 meta.tags list 并 persist；persist 失败时回滚内存态。
    pub fn update_metadata(&mut self, note_id: &str, tags: &[String]) -> Result<()> {
        let previous = {
            let note = self
                .notes
                .get(note_id)
                .ok_or_else(|| anyhow::anyhow!("note not found: {}", note_id))?;
            let previous = note.get_tags();
            note.set_tags(tags);
            previous
        };
        if let Err(err) = self.persist() {
            if let Some(note) = self.notes.get(note_id) {
                note.set_tags(&previous);
            }
            return Err(err);
        }
        self.mark_sync_pending(note_id);
        Ok(())
    }

    /// 获取笔记内容
    pub fn get_note(&self, note_id: &str) -> Option<String> {
        self.notes.get(note_id).map(|n| n.get_content())
    }

    /// 软删除：给笔记 meta 打 deleted_at 标记（进回收站），随快照传播。
    ///
    /// 笔记仍在 notes HashMap 中，仅 meta 标记；persist 失败时回滚内存态。
    pub fn soft_delete_note(&mut self, note_id: &str) -> Result<()> {
        let previous = {
            let note = self
                .notes
                .get(note_id)
                .ok_or_else(|| anyhow::anyhow!("note not found: {}", note_id))?;
            let previous = note.get_deleted_at();
            note.set_deleted_at(Some(Utc::now().to_rfc3339()));
            previous
        };
        if let Err(err) = self.persist() {
            if let Some(note) = self.notes.get(note_id) {
                note.set_deleted_at(previous);
            }
            return Err(err);
        }
        self.mark_sync_pending(note_id);
        Ok(())
    }

    /// 恢复：清除笔记 meta 的 deleted_at 标记，随快照传播。
    pub fn restore_note(&mut self, note_id: &str) -> Result<()> {
        let previous = {
            let note = self
                .notes
                .get(note_id)
                .ok_or_else(|| anyhow::anyhow!("note not found: {}", note_id))?;
            let previous = note.get_deleted_at();
            note.set_deleted_at(None);
            previous
        };
        if let Err(err) = self.persist() {
            if let Some(note) = self.notes.get(note_id) {
                note.set_deleted_at(previous);
            }
            return Err(err);
        }
        self.mark_sync_pending(note_id);
        Ok(())
    }

    /// 彻底删除：从 notes 移除并记入墓碑（删除信息随快照传播，防复活）。
    ///
    /// 已彻底删除的 id 幂等成功；persist 失败时回滚内存态。
    pub fn purge_note(&mut self, note_id: &str) -> Result<()> {
        let removed = self.notes.remove(note_id);
        if removed.is_none() && !self.tombstones.contains(note_id) {
            anyhow::bail!("note not found: {}", note_id);
        }
        self.tombstones.insert(note_id.to_string());
        if let Err(err) = self.persist() {
            if let Some(note) = removed {
                self.notes.insert(note_id.to_string(), note);
            }
            self.tombstones.remove(note_id);
            return Err(err);
        }
        self.mark_sync_pending(note_id);
        Ok(())
    }

    /// 过期清理：遍历 meta.deleted_at < cutoff 的软删笔记并 purge（入墓碑），
    /// 返回清理数。cutoff 为 RFC3339 时间字符串。
    pub fn purge_expired(&mut self, cutoff: &str) -> Result<usize> {
        let cutoff_dt = chrono::DateTime::parse_from_rfc3339(cutoff)
            .with_context(|| format!("invalid cutoff timestamp: {}", cutoff))?;
        let expired: Vec<String> = self
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
            if let Some(note) = self.notes.remove(id) {
                removed_notes.push((id.clone(), note));
            }
            self.tombstones.insert(id.clone());
        }
        if let Err(err) = self.persist() {
            for (id, note) in removed_notes {
                self.notes.insert(id, note);
            }
            for id in &expired {
                self.tombstones.remove(id);
            }
            return Err(err);
        }
        // 与 purge_note 一致：清理的墓碑标记待同步，随下一次全量推送传播给对端
        // （push 是全量快照含墓碑；不标记则墓碑只在有其他变更触发的推送中捎带）。
        for id in &expired {
            self.mark_sync_pending(id);
        }
        Ok(expired.len())
    }

    /// 墓碑集合（已彻底删除的 note id）只读引用
    pub fn tombstones(&self) -> &HashSet<String> {
        &self.tombstones
    }

    /// 导出所有笔记的全量快照（用于首次同步）
    ///
    /// v3 序列化格式：`墓碑 section + 笔记记录流`。
    /// 墓碑 section：`(墓碑数: u32 LE, (id_len: u32 LE, id)*)`
    /// 记录流：每条笔记连续拼接为
    ///   `(note_id_len: u32 LE, note_id, snapshot_len: u32 LE, snapshot)`
    pub fn export_all(&self) -> Result<Vec<u8>> {
        let mut buf = Vec::new();
        // 墓碑 section 前缀
        buf.extend_from_slice(&(self.tombstones.len() as u32).to_le_bytes());
        let mut sorted: Vec<&String> = self.tombstones.iter().collect();
        sorted.sort();
        for id in sorted {
            let id_bytes = id.as_bytes();
            buf.extend_from_slice(&(id_bytes.len() as u32).to_le_bytes());
            buf.extend_from_slice(id_bytes);
        }
        // 笔记记录流
        for (note_id, note) in &self.notes {
            let snapshot = note.export_snapshot()?;
            let id_bytes = note_id.as_bytes();
            buf.extend_from_slice(&(id_bytes.len() as u32).to_le_bytes());
            buf.extend_from_slice(id_bytes);
            buf.extend_from_slice(&(snapshot.len() as u32).to_le_bytes());
            buf.extend_from_slice(&snapshot);
        }
        Ok(buf)
    }

    /// 导入全量快照（v3 语义：墓碑 section + 记录流）
    pub fn import_all(&mut self, data: &[u8]) -> Result<()> {
        let previous = self.export_all()?;
        self.import_raw(LORO_VERSION, data)?;
        if let Err(err) = self.persist() {
            self.notes.clear();
            self.tombstones.clear();
            self.import_raw(LORO_VERSION, &previous)?;
            return Err(err);
        }
        Ok(())
    }

    /// 导入 payload。`version` 决定是否含墓碑 section：
    /// - v3：`墓碑 section + 记录流`（导入的墓碑与本地 tombstones union 合并；
    ///   记录流中遇到墓碑中的 id 跳过，不复活）
    /// - v1/v2：纯记录流（无墓碑 section，tombstones 为空，无损升级）
    fn import_raw(&mut self, version: u32, data: &[u8]) -> Result<()> {
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
                let id_len =
                    u32::from_le_bytes(data[offset..offset + 4].try_into().unwrap()) as usize;
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
            if imported_tombstones.contains(&note_id) || self.tombstones.contains(&note_id) {
                continue;
            }

            // 导入笔记
            let note = NoteCrdt::new();
            note.import_snapshot(&snapshot)?;
            self.notes.insert(note_id, note);
        }

        // 墓碑 union 合并
        self.tombstones.extend(imported_tombstones);
        Ok(())
    }

    fn persist(&self) -> Result<()> {
        let Some(path) = &self.persistent_path else {
            return Ok(());
        };
        let payload = self.export_all()?;
        let bytes = encode_envelope(&payload);
        let mut file = AtomicWriteFile::options()
            .open(path)
            .with_context(|| format!("open atomic Loro file {}", path.display()))?;
        std::io::Write::write_all(&mut file, &bytes)?;
        file.commit().context("commit Loro file")?;
        Ok(())
    }

    /// 向指定对端推送所有笔记的快照
    ///
    /// `peer_id`: iroh 节点 ID（字符串格式）
    /// `peer_ips`: 对端 IP 地址列表（`"ip:port"` 格式）。
    ///   非空时直连优先（同网段）；为空时仅凭 node id 经 relay/地址解析尝试连接
    ///   （跨网段，依赖 iroh 的 n0 DNS 地址查找或已配置 relay）。
    pub async fn push_to_peer(&self, peer_id: &str, peer_ips: Vec<String>) -> Result<()> {
        let node_id: iroh::EndpointId = peer_id.parse().context("invalid peer endpoint id")?;

        let addr = self.build_connect_addr(node_id, &peer_ips)?;

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
        let data = match self.export_all() {
            Ok(d) => d,
            Err(e) => {
                // 快照导出失败：所有设备都记为失败
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
                Ok(Ok(())) => results.push(DevicePushResult {
                    peer_id,
                    ok: true,
                    message: String::new(),
                }),
                Ok(Err(e)) => results.push(DevicePushResult {
                    peer_id,
                    ok: false,
                    message: format!("{e:#}"),
                }),
                Err(_) => results.push(DevicePushResult {
                    peer_id,
                    ok: false,
                    message: "push timeout after 10s".to_string(),
                }),
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
        let conn = incoming.accept()?.await.context("accept connection")?;
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
            return Ok(Some(data));
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
            *self.pending_pairing.lock().unwrap() = Some(PendingPairing {
                request: request.clone(),
                conn,
            });
            return Ok(None);
        }
        anyhow::bail!("unknown incoming frame marker: {:?}", marker);
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
        for id in self.notes.keys() {
            dirty.insert(id.clone());
        }
        for id in &self.tombstones {
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
        if !self.sync_allowed() {
            return Vec::new();
        }
        let devices = self.paired_devices_with_ips(store);
        if devices.is_empty() {
            return Vec::new();
        }
        let results = self.push_to_paired_devices(&devices).await;
        if results.iter().any(|r| r.ok) {
            self.mark_synced_all();
            for r in &results {
                if r.ok {
                    let _ = store.update_last_seen(&r.peer_id);
                }
            }
        } else {
            for r in &results {
                eprintln!(
                    "[sync] push to {} failed (silent): {}",
                    r.peer_id, r.message
                );
            }
        }
        results
    }

    /// 周期同步任务体（Flutter 侧 Timer 周期调用；测试直接调用）：
    /// 1. 同步开关关闭 → 跳过（决策 6）
    /// 2. push 给所有配对设备（对等推拉——pull 语义用 push 协议实现：
    ///    我方 push 即请求对端在各自周期里推回）
    /// 3. 短窗口 accept 对端 push（非阻塞）→ import → 刷新 SQLite 投影
    pub async fn run_sync_cycle(&mut self, store: &NoteStore) -> Result<SyncCycleResult> {
        if !self.sync_allowed() {
            return Ok(SyncCycleResult {
                pushed_count: 0,
                accepted_push: false,
                disabled: true,
            });
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
                    let _ = store.update_last_seen(&r.peer_id);
                }
            }
        } else if !results.is_empty() {
            for r in &results {
                eprintln!(
                    "[sync] periodic push to {} failed (silent): {}",
                    r.peer_id, r.message
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
        Ok(SyncCycleResult {
            pushed_count,
            accepted_push: accepted,
            disabled: false,
        })
    }

    /// 将所有 CRDT 笔记同步到 SQLite 存储（同时清理墓碑投影行，防被删笔记复活）。
    pub fn sync_notes_to_store(&self, store: &NoteStore) -> Result<()> {
        for (id, note) in self.iter_notes() {
            store.sync_note(id, note)?;
        }
        for id in self.tombstones() {
            store.purge_note(id)?;
        }
        Ok(())
    }
}

fn loro_path(path: &Path) -> PathBuf {
    if path.extension().is_some_and(|ext| ext == "loro") {
        path.to_path_buf()
    } else {
        path.join("cardmind.loro")
    }
}

/// 从数据目录读取 relay 配置（任务 K，`relay.txt` 极简配置）：
///
/// - 无文件 → `RelayMode::Disabled`（默认仅局域网，零配置）
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
    Ok(PairingRequest {
        code,
        device_id,
        device_name,
        relay_info,
        ips,
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
