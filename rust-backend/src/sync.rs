use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use atomic_write_file::AtomicWriteFile;
use chrono::Utc;
use iroh::{endpoint::presets, Endpoint, EndpointAddr, RelayMode, SecretKey, TransportAddr};
use loro::{Container, ExportMode, LoroDoc, LoroValue, ValueOrContainer};
use uuid::Uuid;

use crate::store::NoteStore;

/// 同步服务 — 管理笔记集合并通过 iroh 与对端同步
pub struct SyncService {
    notes: HashMap<String, NoteCrdt>,
    /// 已彻底删除的笔记 id 集合（墓碑）。删除信息随快照传播，防止
    /// `sync_notes_to_store` 从 Loro 快照重建被删笔记（复活）。
    tombstones: HashSet<String>,
    endpoint: Endpoint,
    /// 构造时使用的 relay 模式（当前配置：RelayMode::Default = iroh 官方公共 relay）
    relay_mode: RelayMode,
    persistent_path: Option<PathBuf>,
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

impl SyncService {
    /// 创建同步服务，绑定随机的 iroh 端点（内存版：SecretKey 随机，测试用）
    pub async fn new() -> Result<Self> {
        let key = load_or_create_secret_key(None)?;
        let relay_mode = RelayMode::Default;
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
        })
    }

    /// 创建持久化同步服务。`path` 可以是数据目录，也可以直接是 `.loro` 文件路径。
    ///
    /// 设备身份持久化：在数据目录（path 父目录）加载/生成 `device.key`（32 字节
    /// hex），使 device_id 跨重启稳定。
    pub async fn new_persistent(path: impl AsRef<Path>) -> Result<Self> {
        let path = loro_path(path.as_ref());
        let data_dir = path.parent().map(Path::to_path_buf);
        if let Some(parent) = &data_dir {
            std::fs::create_dir_all(parent)
                .with_context(|| format!("create data directory {}", parent.display()))?;
        }
        let key = load_or_create_secret_key(data_dir.as_deref())?;
        let relay_mode = RelayMode::Default;
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
        };
        if path.exists() {
            let bytes = std::fs::read(&path)
                .with_context(|| format!("read Loro file {}", path.display()))?;
            let (version, payload) = decode_envelope(&bytes)?;
            service.import_raw(version, &payload)?;
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

    /// 构造时使用的 relay 模式（RelayMode::Default = 官方公共 relay，非 Disabled）
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

        let addr = if peer_ips.is_empty() {
            // 无直连地址：交给 iroh 经 relay/地址解析（EndpointAddr::new 仅有 node id）
            EndpointAddr::new(node_id)
        } else {
            let ips: Vec<TransportAddr> = peer_ips
                .iter()
                .filter_map(|ip| ip.parse::<std::net::SocketAddr>().ok())
                .map(TransportAddr::Ip)
                .collect();
            if ips.is_empty() {
                anyhow::bail!("no valid peer IPs provided");
            }
            EndpointAddr::from_parts(node_id, ips)
        };

        let data = self.export_all()?;

        let conn = self
            .endpoint
            .connect(addr, ALPN)
            .await
            .context("connect to peer")?;
        let mut send = conn.open_uni().await.context("open uni stream")?;
        send.write_all(&data).await.context("write snapshot data")?;
        // finish() 显式发送流结束（EOF），接收端 read_to_end 据此结束
        send.finish().context("finish uni stream")?;
        // 保持连接存活直到对端读完数据并关闭连接；避免对端未读完时本端
        // drop conn 导致连接被提前关闭（数据丢失）。超时保护防止对端不关闭。
        tokio::time::timeout(
            std::time::Duration::from_secs(10),
            conn.closed(),
        )
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
        let addr = match peer_ips {
            Some(ips) if !ips.is_empty() => {
                let ips: Vec<TransportAddr> = ips
                    .iter()
                    .filter_map(|ip| ip.parse::<std::net::SocketAddr>().ok())
                    .map(TransportAddr::Ip)
                    .collect();
                if ips.is_empty() {
                    anyhow::bail!("no valid peer IPs provided");
                }
                EndpointAddr::from_parts(node_id, ips)
            }
            _ => EndpointAddr::new(node_id),
        };

        let conn = self
            .endpoint
            .connect(addr, ALPN)
            .await
            .context("connect to peer")?;
        let mut send = conn.open_uni().await.context("open uni stream")?;
        send.write_all(data).await.context("write snapshot data")?;
        send.finish().context("finish uni stream")?;
        // 保持连接存活直到对端读完并关闭；超时保护（push_to_paired_devices 外层也有 10s 超时）
        tokio::time::timeout(
            std::time::Duration::from_secs(10),
            conn.closed(),
        )
        .await
        .ok();
        Ok(())
    }

    /// 监听并接受对端的推送，返回原始字节数据
    ///
    /// 调用方收到数据后应调用 `import_all` 导入。
    pub async fn accept_push(&self) -> Result<Vec<u8>> {
        let incoming = self
            .endpoint
            .accept()
            .await
            .ok_or_else(|| anyhow::anyhow!("no incoming connection"))?;
        let conn = incoming.accept()?.await.context("accept connection")?;
        let mut recv = conn.accept_uni().await.context("accept uni stream")?;
        let data = recv
            .read_to_end(usize::MAX)
            .await
            .context("read push data")?;
        // 数据已读入内存，主动关闭连接，通知发送端可释放
        conn.close(0u32.into(), b"done");
        Ok(data)
    }
}

fn loro_path(path: &Path) -> PathBuf {
    if path.extension().is_some_and(|ext| ext == "loro") {
        path.to_path_buf()
    } else {
        path.join("cardmind.loro")
    }
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
    if hex.len() % 2 != 0 {
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
                map.insert("deleted_at", v.as_str()).expect("set deleted_at");
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
