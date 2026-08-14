use std::collections::HashMap;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use atomic_write_file::AtomicWriteFile;
use iroh::{endpoint::presets, Endpoint, EndpointAddr, RelayMode, SecretKey, TransportAddr};
use loro::{Container, ExportMode, LoroDoc, LoroValue, ValueOrContainer};
use uuid::Uuid;

use crate::store::NoteStore;

/// 同步服务 — 管理笔记集合并通过 iroh 与对端同步
pub struct SyncService {
    notes: HashMap<String, NoteCrdt>,
    endpoint: Endpoint,
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
const LORO_VERSION: u32 = 2;
const LORO_HEADER_LEN: usize = 8 + 4 + 8;

// ━━━ SyncService ━━━

impl SyncService {
    /// 创建同步服务，绑定随机的 iroh 端点
    pub async fn new() -> Result<Self> {
        let key = SecretKey::generate();
        let endpoint = Endpoint::builder(presets::N0)
            .secret_key(key)
            .alpns(vec![ALPN.to_vec()])
            .relay_mode(RelayMode::Disabled)
            .bind()
            .await
            .context("bind iroh endpoint")?;
        Ok(Self {
            notes: HashMap::new(),
            endpoint,
            persistent_path: None,
        })
    }

    /// 创建持久化同步服务。`path` 可以是数据目录，也可以直接是 `.loro` 文件路径。
    pub async fn new_persistent(path: impl AsRef<Path>) -> Result<Self> {
        let path = loro_path(path.as_ref());
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)
                .with_context(|| format!("create data directory {}", parent.display()))?;
        }
        let mut service = Self::new().await?;
        service.persistent_path = Some(path.clone());
        if path.exists() {
            let bytes = std::fs::read(&path)
                .with_context(|| format!("read Loro file {}", path.display()))?;
            let (version, payload) = decode_envelope(&bytes)?;
            service.import_raw(&payload)?;
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
                // 迁移全部完成后再以 v2 写回
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

    /// 导出所有笔记的全量快照（用于首次同步）
    ///
    /// 序列化格式：每条笔记连续拼接为
    ///   `(note_id_len: u32 LE, note_id, snapshot_len: u32 LE, snapshot)`
    pub fn export_all(&self) -> Result<Vec<u8>> {
        let mut buf = Vec::new();
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

    /// 导入全量快照
    pub fn import_all(&mut self, data: &[u8]) -> Result<()> {
        let previous = self.export_all()?;
        self.import_raw(data)?;
        if let Err(err) = self.persist() {
            self.notes.clear();
            self.import_raw(&previous)?;
            return Err(err);
        }
        Ok(())
    }

    fn import_raw(&mut self, data: &[u8]) -> Result<()> {
        let mut offset = 0;
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

            // 导入笔记
            let note = NoteCrdt::new();
            note.import_snapshot(&snapshot)?;
            self.notes.insert(note_id, note);
        }
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
    /// `peer_ips`: 对端 IP 地址列表（`"ip:port"` 格式）
    pub async fn push_to_peer(&self, peer_id: &str, peer_ips: Vec<String>) -> Result<()> {
        let node_id: iroh::EndpointId = peer_id.parse().context("invalid peer endpoint id")?;

        let ips: Vec<TransportAddr> = peer_ips
            .iter()
            .filter_map(|ip| ip.parse::<std::net::SocketAddr>().ok())
            .map(TransportAddr::Ip)
            .collect();

        if ips.is_empty() {
            anyhow::bail!("no valid peer IPs provided");
        }

        let addr = EndpointAddr::from_parts(node_id, ips);
        let data = self.export_all()?;

        let conn = self
            .endpoint
            .connect(addr, ALPN)
            .await
            .context("connect to peer")?;
        let mut send = conn.open_uni().await.context("open uni stream")?;
        send.write_all(&data).await.context("write snapshot data")?;
        // Drop 发送端以发送 EOF，接收端 read_to_end 据此结束
        drop(send);

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
/// version = 1 时返回旧 payload 供迁移（不报错）；version = 2 正常载入；其他版本报错。
fn decode_envelope(bytes: &[u8]) -> Result<(u32, Vec<u8>)> {
    if bytes.len() < LORO_HEADER_LEN || &bytes[..8] != LORO_MAGIC {
        anyhow::bail!("invalid cardmind.loro magic or truncated header");
    }
    let version = u32::from_le_bytes(bytes[8..12].try_into().unwrap());
    if version != 1 && version != LORO_VERSION {
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
