// CRDT管理模块 - 使用Loro实现冲突自由的数据复制
//
// 文件系统存储方案：
// 1. 每个卡片/网络对应一个独立的文件夹（UUID的base64编码）
// 2. snapshot.loro：保存完整的Loro文档快照
// 3. updates.loro：保存增量更新数据（追加写入）
// 4. SQLite只存储元数据（title、timestamps等），不存储Loro BLOB
//
// 优势：
// - 追加写入性能极高（官方推荐）
// - 易于备份和同步单个笔记
// - 避免SQLite BLOB的性能问题
// - 支持增量传输（只传输updates文件）

use loro::LoroDoc;
use uuid::Uuid;
use std::sync::Arc;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use tokio::sync::RwLock;
use tokio::fs;
use log::{debug, info, warn};
use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};

/// CRDT文档管理器
pub struct CrdtManager {
    // Loro数据根目录
    loro_root: PathBuf,

    // 内存中的活跃文档（用于快速访问）
    active_docs: Arc<RwLock<HashMap<Uuid, Arc<LoroDoc>>>>,

    // 更新文件大小阈值（字节，默认10MB）
    update_threshold: usize,
}

impl CrdtManager {
    /// 创建新的CRDT管理器
    pub async fn new(loro_root: PathBuf) -> Result<Self, String> {
        info!("初始化CRDT管理器，数据目录: {:?}", loro_root);

        // 确保loro根目录存在
        fs::create_dir_all(&loro_root)
            .await
            .map_err(|e| format!("创建loro根目录失败: {}", e))?;

        Ok(Self {
            loro_root,
            active_docs: Arc::new(RwLock::new(HashMap::new())),
            update_threshold: 10 * 1024 * 1024, // 10MB
        })
    }

    // ==================== 辅助方法 ====================

    /// 将UUID编码为base64文件夹名
    fn encode_uuid(uuid: Uuid) -> String {
        URL_SAFE_NO_PAD.encode(uuid.as_bytes())
    }

    /// 获取卡片/网络的数据目录
    fn get_doc_dir(&self, uuid: Uuid) -> PathBuf {
        let encoded = Self::encode_uuid(uuid);
        self.loro_root.join(encoded)
    }

    /// 获取快照文件路径
    fn get_snapshot_path(&self, uuid: Uuid) -> PathBuf {
        self.get_doc_dir(uuid).join("snapshot.loro")
    }

    /// 获取更新文件路径
    fn get_updates_path(&self, uuid: Uuid) -> PathBuf {
        self.get_doc_dir(uuid).join("updates.loro")
    }

    /// 获取更新文件大小
    async fn get_update_file_size(&self, uuid: Uuid) -> Result<u64, String> {
        let updates_path = self.get_updates_path(uuid);

        match fs::metadata(&updates_path).await {
            Ok(metadata) => Ok(metadata.len()),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(0),
            Err(e) => Err(format!("获取更新文件大小失败: {}", e)),
        }
    }

    // ==================== 文档加载和保存 ====================

    /// 从文件系统加载文档（snapshot + updates）
    async fn load_doc_from_fs(&self, uuid: Uuid) -> Result<LoroDoc, String> {
        debug!("从文件系统加载文档 {}", uuid);

        let snapshot_path = self.get_snapshot_path(uuid);
        let updates_path = self.get_updates_path(uuid);

        // 创建新文档（使用 Loro 自动生成的随机 peer ID）
        let doc = LoroDoc::new();

        // 1. 加载快照（如果存在）
        if snapshot_path.exists() {
            debug!("加载快照文件: {:?}", snapshot_path);
            let snapshot_bytes = fs::read(&snapshot_path)
                .await
                .map_err(|e| format!("读取快照文件失败: {}", e))?;

            doc.import(&snapshot_bytes)
                .map_err(|e| format!("导入快照失败: {:?}", e))?;
        } else {
            debug!("快照文件不存在，跳过: {:?}", snapshot_path);
        }

        // 2. 应用增量更新（如果存在）
        if updates_path.exists() {
            debug!("应用更新文件: {:?}", updates_path);
            let updates_bytes = fs::read(&updates_path)
                .await
                .map_err(|e| format!("读取更新文件失败: {}", e))?;

            if !updates_bytes.is_empty() {
                doc.import(&updates_bytes)
                    .map_err(|e| format!("应用更新失败: {:?}", e))?;
            }
        } else {
            debug!("更新文件不存在，跳过: {:?}", updates_path);
        }

        info!("文档 {} 加载成功", uuid);
        Ok(doc)
    }

    /// 追加更新数据到文件
    async fn append_update(&self, uuid: Uuid, update_bytes: &[u8]) -> Result<(), String> {
        debug!("追加更新到文档 {}，大小: {} bytes", uuid, update_bytes.len());

        let doc_dir = self.get_doc_dir(uuid);
        let updates_path = self.get_updates_path(uuid);

        // 确保目录存在
        fs::create_dir_all(&doc_dir)
            .await
            .map_err(|e| format!("创建文档目录失败: {}", e))?;

        // 追加写入更新数据
        use tokio::io::AsyncWriteExt;
        let mut file = fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(&updates_path)
            .await
            .map_err(|e| format!("打开更新文件失败: {}", e))?;

        file.write_all(update_bytes)
            .await
            .map_err(|e| format!("写入更新失败: {}", e))?;

        file.flush()
            .await
            .map_err(|e| format!("刷新更新文件失败: {}", e))?;

        info!("更新追加成功: {}", uuid);
        Ok(())
    }

    /// 合并快照并清空更新文件
    async fn merge_snapshot(&self, uuid: Uuid, doc: &LoroDoc) -> Result<(), String> {
        info!("合并快照: {}", uuid);

        let doc_dir = self.get_doc_dir(uuid);
        let snapshot_path = self.get_snapshot_path(uuid);
        let updates_path = self.get_updates_path(uuid);

        // 确保目录存在
        fs::create_dir_all(&doc_dir)
            .await
            .map_err(|e| format!("创建文档目录失败: {}", e))?;

        // 导出完整快照
        let snapshot_bytes = doc.export(loro::ExportMode::Snapshot)
            .map_err(|e| format!("导出快照失败: {:?}", e))?;

        // 写入新快照
        fs::write(&snapshot_path, &snapshot_bytes)
            .await
            .map_err(|e| format!("写入快照文件失败: {}", e))?;

        // 清空更新文件
        fs::write(&updates_path, &[])
            .await
            .map_err(|e| format!("清空更新文件失败: {}", e))?;

        info!("快照合并成功: {}，快照大小: {} bytes", uuid, snapshot_bytes.len());
        Ok(())
    }

    /// 检查并在需要时合并快照
    async fn merge_snapshot_if_needed(&self, uuid: Uuid) -> Result<(), String> {
        let update_size = self.get_update_file_size(uuid).await?;

        if update_size > self.update_threshold as u64 {
            info!("更新文件大小 {} 超过阈值 {}，触发快照合并",
                  update_size, self.update_threshold);

            // 获取文档
            let doc = self.get_or_load_doc(uuid).await?;

            // 合并快照
            self.merge_snapshot(uuid, &doc).await?;
        }

        Ok(())
    }

    /// 获取或加载文档到缓存
    async fn get_or_load_doc(&self, uuid: Uuid) -> Result<Arc<LoroDoc>, String> {
        // 先检查缓存
        {
            let docs = self.active_docs.read().await;
            if let Some(doc) = docs.get(&uuid) {
                debug!("从缓存获取文档 {}", uuid);
                return Ok(doc.clone());
            }
        }

        // 从文件系统加载
        let doc = self.load_doc_from_fs(uuid).await?;
        let doc_arc = Arc::new(doc);

        // 缓存文档
        self.active_docs.write().await.insert(uuid, doc_arc.clone());

        Ok(doc_arc)
    }

    // ==================== 卡片相关方法 ====================

    /// 为卡片创建新的Loro文档
    ///
    /// 参数：完整的卡片 Model，包含所有字段（id, title, content, created_at, updated_at）
    pub async fn create_card_doc(&self, card: &crate::models::card::Model) -> Result<(), String> {
        info!("为卡片 {} 创建Loro文档", card.id);

        // 创建新的LoroDoc（使用 Loro 自动生成的随机 peer ID）
        let doc = LoroDoc::new();

        // 获取根容器
        let map = doc.get_map("root");

        // 存储所有字段（包括 ID 和时间戳）
        // 注意：ID 存储在文档中用于分布式场景下的自描述和识别
        map.insert("id", card.id.to_string()).map_err(|e| format!("插入id失败: {:?}", e))?;
        map.insert("title", card.title.clone()).map_err(|e| format!("插入title失败: {:?}", e))?;
        map.insert("content", card.content.clone()).map_err(|e| format!("插入content失败: {:?}", e))?;
        map.insert("created_at", card.created_at).map_err(|e| format!("插入created_at失败: {:?}", e))?;
        map.insert("updated_at", card.updated_at).map_err(|e| format!("插入updated_at失败: {:?}", e))?;

        // 提交更改
        doc.commit();

        // 缓存文档
        let doc_arc = Arc::new(doc);
        self.active_docs.write().await.insert(card.id, doc_arc.clone());

        // 保存快照到文件系统
        self.merge_snapshot(card.id, &doc_arc).await?;

        info!("卡片 {} 的Loro文档创建成功", card.id);
        Ok(())
    }

    /// 更新卡片文档
    ///
    /// 参数：完整的卡片 Model，包含所有字段（包括更新后的 updated_at）
    pub async fn update_card_doc(&self, card: &crate::models::card::Model) -> Result<(), String> {
        debug!("更新卡片 {} 的Loro文档", card.id);

        // 获取文档
        let doc = self.get_or_load_doc(card.id).await?;

        let map = doc.get_map("root");

        // 更新所有字段（确保时间戳等元数据也被更新）
        map.insert("title", card.title.clone()).map_err(|e| format!("更新title失败: {:?}", e))?;
        map.insert("content", card.content.clone()).map_err(|e| format!("更新content失败: {:?}", e))?;
        map.insert("updated_at", card.updated_at).map_err(|e| format!("更新updated_at失败: {:?}", e))?;
        // 注意：id 和 created_at 不应该被更新，所以不需要重新插入

        // 提交更改
        doc.commit();

        // 导出增量更新
        let vv = doc.oplog_vv();
        let update_bytes = doc.export(loro::ExportMode::Updates {
            from: std::borrow::Cow::Borrowed(&vv)
        })
        .map_err(|e| format!("导出更新失败: {:?}", e))?;

        // 追加到文件
        self.append_update(card.id, &update_bytes).await?;

        // 检查是否需要合并快照
        self.merge_snapshot_if_needed(card.id).await?;

        info!("卡片 {} 的Loro文档更新成功", card.id);
        Ok(())
    }

    /// 从卡片文档读取完整内容，返回 card::Model 实例
    pub async fn read_card_from_doc(&self, card_id: Uuid) -> Result<crate::models::card::Model, String> {
        debug!("从Loro文档读取卡片 {} 的内容", card_id);

        // 获取文档
        let doc = self.get_or_load_doc(card_id).await?;

        let map = doc.get_map("root");

        // 读取 id
        let id_str = map
            .get("id")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_string().map(|s| s.to_string()))
            .ok_or_else(|| "Loro文档中未找到id字段".to_string())?;

        let id = Uuid::parse_str(&id_str)
            .map_err(|e| format!("解析UUID失败: {}", e))?;

        // 验证 ID 一致性
        if id != card_id {
            return Err(format!(
                "ID不匹配：文件路径ID为 {}，文档内ID为 {}",
                card_id, id
            ));
        }

        // 读取 title
        let title = map
            .get("title")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_string().map(|s| s.to_string()))
            .unwrap_or_default();

        // 读取 content
        let content = map
            .get("content")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_string().map(|s| s.to_string()))
            .unwrap_or_default();

        // 读取 created_at
        let created_at = map
            .get("created_at")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_i64().copied())
            .unwrap_or(0);

        // 读取 updated_at
        let updated_at = map
            .get("updated_at")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_i64().copied())
            .unwrap_or(0);

        Ok(crate::models::card::Model {
            id,
            title,
            content,
            created_at,
            updated_at,
        })
    }

    /// 删除卡片文档缓存和文件
    pub async fn remove_card_doc(&self, card_id: Uuid) -> Result<(), String> {
        info!("删除卡片 {} 的Loro文档", card_id);

        // 删除缓存
        self.active_docs.write().await.remove(&card_id);

        // 删除文件系统中的文档目录
        let doc_dir = self.get_doc_dir(card_id);
        if doc_dir.exists() {
            fs::remove_dir_all(&doc_dir)
                .await
                .map_err(|e| format!("删除文档目录失败: {}", e))?;
        }

        info!("卡片 {} 的Loro文档删除成功", card_id);
        Ok(())
    }

    // ==================== 网络相关方法 ====================

    /// 为网络创建新的Loro文档
    ///
    /// 参数：完整的网络 Model，包含所有字段（id, name, password, created_at, updated_at）
    pub async fn create_network_doc(&self, network: &crate::models::network::Model) -> Result<(), String> {
        info!("为网络 {} 创建Loro文档", network.id);

        // 创建新的LoroDoc（使用 Loro 自动生成的随机 peer ID）
        let doc = LoroDoc::new();

        // 获取根容器
        let map = doc.get_map("root");

        // 存储所有字段（包括 ID 和时间戳，但不包括密码哈希）
        // 注意：ID 存储在文档中用于分布式场景下的自描述和识别
        map.insert("id", network.id.to_string()).map_err(|e| format!("插入id失败: {:?}", e))?;
        map.insert("name", network.name.clone()).map_err(|e| format!("插入name失败: {:?}", e))?;
        map.insert("created_at", network.created_at).map_err(|e| format!("插入created_at失败: {:?}", e))?;
        map.insert("updated_at", network.updated_at).map_err(|e| format!("插入updated_at失败: {:?}", e))?;
        // 注意：密码哈希不存储在 Loro 文档中，只存在 SQLite 中

        // 提交更改
        doc.commit();

        // 缓存文档
        let doc_arc = Arc::new(doc);
        self.active_docs.write().await.insert(network.id, doc_arc.clone());

        // 保存快照到文件系统
        self.merge_snapshot(network.id, &doc_arc).await?;

        info!("网络 {} 的Loro文档创建成功", network.id);
        Ok(())
    }

    /// 更新网络文档
    ///
    /// 参数：完整的网络 Model，包含所有字段（包括更新后的 updated_at）
    pub async fn update_network_doc(&self, network: &crate::models::network::Model) -> Result<(), String> {
        debug!("更新网络 {} 的Loro文档", network.id);

        // 获取文档
        let doc = self.get_or_load_doc(network.id).await?;

        let map = doc.get_map("root");

        // 更新所有字段（确保时间戳等元数据也被更新）
        map.insert("name", network.name.clone()).map_err(|e| format!("更新name失败: {:?}", e))?;
        map.insert("updated_at", network.updated_at).map_err(|e| format!("更新updated_at失败: {:?}", e))?;
        // 注意：id 和 created_at 不应该被更新，密码也不在 Loro 文档中

        // 提交更改
        doc.commit();

        // 导出增量更新
        let vv = doc.oplog_vv();
        let update_bytes = doc.export(loro::ExportMode::Updates {
            from: std::borrow::Cow::Borrowed(&vv)
        })
        .map_err(|e| format!("导出更新失败: {:?}", e))?;

        // 追加到文件
        self.append_update(network.id, &update_bytes).await?;

        // 检查是否需要合并快照
        self.merge_snapshot_if_needed(network.id).await?;

        info!("网络 {} 的Loro文档更新成功", network.id);
        Ok(())
    }

    /// 删除网络文档缓存和文件
    pub async fn remove_network_doc(&self, network_id: Uuid) -> Result<(), String> {
        info!("删除网络 {} 的Loro文档", network_id);

        // 删除缓存
        self.active_docs.write().await.remove(&network_id);

        // 删除文件系统中的文档目录
        let doc_dir = self.get_doc_dir(network_id);
        if doc_dir.exists() {
            fs::remove_dir_all(&doc_dir)
                .await
                .map_err(|e| format!("删除文档目录失败: {}", e))?;
        }

        info!("网络 {} 的Loro文档删除成功", network_id);
        Ok(())
    }

    /// 从网络文档读取完整内容，返回 network::Model 实例（不包含密码）
    pub async fn read_network_from_doc(&self, network_id: Uuid) -> Result<crate::models::network::Model, String> {
        debug!("从Loro文档读取网络 {} 的内容", network_id);

        // 获取文档
        let doc = self.get_or_load_doc(network_id).await?;

        let map = doc.get_map("root");

        // 读取 id
        let id_str = map
            .get("id")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_string().map(|s| s.to_string()))
            .ok_or_else(|| "Loro文档中未找到id字段".to_string())?;

        let id = Uuid::parse_str(&id_str)
            .map_err(|e| format!("解析UUID失败: {}", e))?;

        // 验证 ID 一致性
        if id != network_id {
            return Err(format!(
                "ID不匹配：文件路径ID为 {}，文档内ID为 {}",
                network_id, id
            ));
        }

        // 读取 name
        let name = map
            .get("name")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_string().map(|s| s.to_string()))
            .unwrap_or_default();

        // 读取 created_at
        let created_at = map
            .get("created_at")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_i64().copied())
            .unwrap_or(0);

        // 读取 updated_at
        let updated_at = map
            .get("updated_at")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_i64().copied())
            .unwrap_or(0);

        // 注意：密码不存储在 Loro 中，返回空字符串
        // 调用方如需密码，应该从 SQLite 中读取
        Ok(crate::models::network::Model {
            id,
            name,
            password: String::new(),  // Loro 中不存储密码
            created_at,
            updated_at,
        })
    }

    // ==================== 合并和同步方法 ====================

    /// 从 Loro 文档数据中提取卡片 ID（用于分布式同步）
    ///
    /// 这个方法允许在只有 Loro 二进制数据的情况下识别卡片 ID
    pub fn extract_card_id_from_bytes(loro_bytes: &[u8]) -> Result<Uuid, String> {
        let doc = LoroDoc::new();
        doc.import(loro_bytes).map_err(|e| format!("导入Loro文档失败: {:?}", e))?;

        let map = doc.get_map("root");
        let id_str = map
            .get("id")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_string().map(|s| s.to_string()))
            .ok_or_else(|| "Loro文档中未找到id字段".to_string())?;

        Uuid::parse_str(&id_str).map_err(|e| format!("解析UUID失败: {}", e))
    }

    /// 从 Loro 文档数据中提取网络 ID（用于分布式同步）
    pub fn extract_network_id_from_bytes(loro_bytes: &[u8]) -> Result<Uuid, String> {
        // 网络和卡片的提取逻辑相同
        Self::extract_card_id_from_bytes(loro_bytes)
    }

    /// P2P 同步：从远程接收卡片数据并自动识别和合并
    ///
    /// 这个方法会自动从 Loro 数据中提取卡片 ID，然后合并到本地
    pub async fn sync_card_from_remote(&self, remote_bytes: &[u8]) -> Result<Uuid, String> {
        info!("从远程同步卡片数据，大小: {} bytes", remote_bytes.len());

        // 从文档中提取 ID
        let card_id = Self::extract_card_id_from_bytes(remote_bytes)?;
        info!("识别到卡片 ID: {}", card_id);

        // 合并到本地文档
        self.merge_card_docs(card_id, remote_bytes).await?;

        Ok(card_id)
    }

    /// P2P 同步：从远程接收网络数据并自动识别和合并
    pub async fn sync_network_from_remote(&self, remote_bytes: &[u8]) -> Result<Uuid, String> {
        info!("从远程同步网络数据，大小: {} bytes", remote_bytes.len());

        // 从文档中提取 ID
        let network_id = Self::extract_network_id_from_bytes(remote_bytes)?;
        info!("识别到网络 ID: {}", network_id);

        // 合并到本地文档
        self.merge_network_docs(network_id, remote_bytes).await?;

        Ok(network_id)
    }

    /// 导出卡片的完整 Loro 文档用于 P2P 传输
    ///
    /// 返回的数据包含完整的文档状态（包括 ID），可以直接发送给其他设备
    pub async fn export_card_for_sync(&self, card_id: Uuid) -> Result<Vec<u8>, String> {
        let doc = self.get_or_load_doc(card_id).await?;
        let bytes = doc.export(loro::ExportMode::Snapshot)
            .map_err(|e| format!("导出文档失败: {:?}", e))?;
        Ok(bytes)
    }

    /// 导出网络的完整 Loro 文档用于 P2P 传输
    pub async fn export_network_for_sync(&self, network_id: Uuid) -> Result<Vec<u8>, String> {
        let doc = self.get_or_load_doc(network_id).await?;
        let bytes = doc.export(loro::ExportMode::Snapshot)
            .map_err(|e| format!("导出文档失败: {:?}", e))?;
        Ok(bytes)
    }

    /// 合并两个卡片文档（用于P2P同步）
    pub async fn merge_card_docs(&self, card_id: Uuid, remote_bytes: &[u8]) -> Result<(), String> {
        info!("合并卡片 {} 的Loro文档", card_id);

        // 获取本地文档
        let local_doc = self.get_or_load_doc(card_id).await?;

        // 导入远程文档数据（Loro会自动合并）
        local_doc.import(remote_bytes).map_err(|e| format!("合并Loro文档失败: {:?}", e))?;

        // 提交更改
        local_doc.commit();

        // 导出增量更新
        let vv = local_doc.oplog_vv();
        let update_bytes = local_doc.export(loro::ExportMode::Updates {
            from: std::borrow::Cow::Borrowed(&vv)
        })
        .map_err(|e| format!("导出更新失败: {:?}", e))?;

        // 追加到文件
        self.append_update(card_id, &update_bytes).await?;

        // 检查是否需要合并快照
        self.merge_snapshot_if_needed(card_id).await?;

        info!("卡片 {} 的Loro文档合并成功", card_id);
        Ok(())
    }

    /// 合并两个网络文档（用于P2P同步）
    pub async fn merge_network_docs(&self, network_id: Uuid, remote_bytes: &[u8]) -> Result<(), String> {
        info!("合并网络 {} 的Loro文档", network_id);

        // 获取本地文档
        let local_doc = self.get_or_load_doc(network_id).await?;

        // 导入远程文档数据（Loro会自动合并）
        local_doc.import(remote_bytes).map_err(|e| format!("合并Loro文档失败: {:?}", e))?;

        // 提交更改
        local_doc.commit();

        // 导出增量更新
        let vv = local_doc.oplog_vv();
        let update_bytes = local_doc.export(loro::ExportMode::Updates {
            from: std::borrow::Cow::Borrowed(&vv)
        })
        .map_err(|e| format!("导出更新失败: {:?}", e))?;

        // 追加到文件
        self.append_update(network_id, &update_bytes).await?;

        // 检查是否需要合并快照
        self.merge_snapshot_if_needed(network_id).await?;

        info!("网络 {} 的Loro文档合并成功", network_id);
        Ok(())
    }

    /// 清空所有文档缓存
    pub async fn clear_all(&self) {
        info!("清空所有Loro文档缓存");
        self.active_docs.write().await.clear();
    }
}
