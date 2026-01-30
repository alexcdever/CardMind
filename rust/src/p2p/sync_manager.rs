//! P2P 同步管理器
//!
//! 本模块实现卡片的 P2P 同步管理功能。
//!
//! # 核心功能
//!
//! - **增量导出**: 从数据池的卡片导出 Loro 增量更新
//! - **导入合并**: 导入并合并来自对等设备的更新
//! - **版本跟踪**: 跟踪每个数据池和设备的最后同步版本
//! - **自动同步**: 驱动完整的同步流程
//!
//! # 同步流程
//!
//! ```text
//! 1. SyncManager.handle_sync_request(pool_id, version)
//!    → 检查授权 → 过滤卡片 → 导出更新 → 返回 SyncResponse
//!
//! 2. SyncManager.import_updates(pool_id, updates)
//!    → 导入更新 → commit → 触发订阅 → SQLite 自动更新
//!
//! 3. SyncManager.track_sync_version(pool_id, peer_id, version)
//!    → 更新版本记录 → 支持下次增量同步
//! ```

use crate::models::card::Card;
use crate::models::error::{CardMindError, Result};
use crate::store::card_store::CardStore;
use loro::{ExportMode, LoroDoc};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use tracing::{debug, info, warn};

/// Type alias for sync version tracking
type SyncVersionMap = HashMap<String, HashMap<String, Vec<u8>>>;

/// 同步管理器
///
/// 负责管理 P2P 卡片同步的核心逻辑
pub struct SyncManager {
    /// `CardStore` 引用
    card_store: Arc<Mutex<CardStore>>,

    /// 版本跟踪 (`pool_id` -> `peer_id` -> version)
    sync_versions: Arc<Mutex<SyncVersionMap>>,
}

impl SyncManager {
    /// 创建新的同步管理器
    ///
    /// # 参数
    ///
    /// * `card_store` - `CardStore` 实例
    pub fn new(card_store: Arc<Mutex<CardStore>>) -> Self {
        Self {
            card_store,
            sync_versions: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    /// 处理同步请求
    ///
    /// # 参数
    ///
    /// * `pool_id` - 数据池 ID
    /// * `last_version` - 最后同步的版本（None 表示首次同步）
    /// * `joined_pools` - 请求设备已加入的数据池列表
    ///
    /// # 返回
    ///
    /// 包含增量更新的 `SyncData`
    ///
    /// # 错误
    ///
    /// - 如果设备未加入该数据池，返回 `NotAuthorized`
    pub fn handle_sync_request(
        &self,
        pool_id: &str,
        last_version: Option<&[u8]>,
        joined_pools: &[String],
    ) -> Result<SyncData> {
        info!(
            "处理同步请求: pool_id={}, version={:?}",
            pool_id, last_version
        );

        // 1. 验证设备是否加入该数据池
        if !joined_pools.contains(&pool_id.to_string()) {
            warn!("设备未授权访问数据池: {}", pool_id);
            return Err(CardMindError::NotAuthorized(format!(
                "设备未加入数据池: {pool_id}"
            )));
        }

        // 2. 获取所有卡片（当前同步全部卡片；如需严格池过滤，可恢复 SyncFilter）
        let store = self.card_store.lock().unwrap();
        let pool_cards = store.get_all_cards()?;

        debug!("数据池 {} 包含 {} 个卡片", pool_id, pool_cards.len());

        if pool_cards.is_empty() {
            // 没有卡片需要同步，返回空响应
            return Ok(SyncData {
                updates: Vec::new(),
                card_count: 0,
                current_version: vec![],
            });
        }

        // 4. 为每个卡片构建 LoroDoc 并导出更新
        let mut all_updates = Vec::new();
        for card in &pool_cards {
            let doc = Self::build_loro_doc(card);
            match doc.export(ExportMode::all_updates()) {
                Ok(snapshot) => {
                    all_updates.push(snapshot);
                }
                Err(e) => {
                    warn!("导出卡片 {} 的 Loro 更新失败: {}", card.id, e);
                }
            }
        }

        // 5. 合并所有更新（简化：直接拼接）
        let merged_updates = Self::merge_updates(all_updates)?;

        // 6. 生成当前版本（简化：使用时间戳）
        let current_version = Self::generate_version();

        info!(
            "成功生成同步数据: {} 个卡片, {} 字节",
            pool_cards.len(),
            merged_updates.len()
        );

        Ok(SyncData {
            updates: merged_updates,
            card_count: pool_cards.len(),
            current_version,
        })
    }

    /// 导入并合并更新
    ///
    /// # 参数
    ///
    /// * `pool_id` - 数据池 ID
    /// * `updates` - 增量更新数据
    ///
    /// # 返回
    ///
    /// 更新后的版本号
    pub fn import_updates(&self, pool_id: &str, updates: &[u8]) -> Result<Vec<u8>> {
        info!("导入更新: pool_id={}, size={}", pool_id, updates.len());

        if updates.is_empty() {
            return Ok(Self::generate_version());
        }

        // 1. 反序列化更新（简化：假设是单个 LoroDoc 快照）
        let doc = LoroDoc::new();
        doc.import(updates)?;

        // 2. 获取卡片数据
        let card = Self::read_card_from_loro(&doc)?;

        // 3. 写入到 CardStore
        let mut store = self.card_store.lock().unwrap();

        // 检查卡片是否已存在
        store.upsert_card_from_sync(&card)?;

        // 4. 生成新版本
        let new_version = Self::generate_version();

        info!("成功导入更新: {}", pool_id);

        Ok(new_version)
    }

    /// 跟踪同步版本
    ///
    /// # 参数
    ///
    /// * `pool_id` - 数据池 ID
    /// * `peer_id` - 对等设备 ID
    /// * `version` - 同步版本
    pub fn track_sync_version(&self, pool_id: &str, peer_id: &str, version: &[u8]) {
        let mut versions = self.sync_versions.lock().unwrap();

        let pool_versions = versions.entry(pool_id.to_string()).or_default();

        pool_versions.insert(peer_id.to_string(), version.to_vec());

        debug!(
            "更新同步版本: pool_id={}, peer_id={}, version={:?}",
            pool_id, peer_id, version
        );
    }

    /// 获取最后同步版本
    ///
    /// # 参数
    ///
    /// * `pool_id` - 数据池 ID
    /// * `peer_id` - 对等设备 ID
    ///
    /// # 返回
    ///
    /// 最后同步的版本，如果没有则返回 None
    #[must_use]
    pub fn get_last_sync_version(&self, pool_id: &str, peer_id: &str) -> Option<Vec<u8>> {
        let versions = self.sync_versions.lock().unwrap();

        versions
            .get(pool_id)
            .and_then(|pool_versions| pool_versions.get(peer_id))
            .cloned()
    }

    // ==================== 私有辅助方法 ====================

    /// 将卡片构建为 LoroDoc（用于同步）
    fn build_loro_doc(card: &Card) -> LoroDoc {
        let doc = LoroDoc::new();
        let map = doc.get_map("card");
        map.insert("id", card.id.clone()).unwrap();
        map.insert("title", card.title.clone()).unwrap();
        map.insert("content", card.content.clone()).unwrap();
        map.insert("created_at", card.created_at).unwrap();
        map.insert("updated_at", card.updated_at).unwrap();
        map.insert("deleted", card.deleted).unwrap();
        doc.commit();
        doc
    }

    /// 合并多个更新
    fn merge_updates(updates: Vec<Vec<u8>>) -> Result<Vec<u8>> {
        let doc = LoroDoc::new();
        for update in updates {
            doc.import(&update)
                .map_err(|e| CardMindError::LoroError(format!("导入更新失败: {e}")))?;
        }
        doc.export(ExportMode::all_updates())
            .map_err(|e| CardMindError::LoroError(format!("导出合并更新失败: {e}")))
    }

    /// 从 `LoroDoc` 读取卡片
    fn read_card_from_loro(doc: &LoroDoc) -> Result<Card> {
        let map = doc.get_map("card");

        // 检查是否有数据
        if map.is_empty() {
            return Err(CardMindError::LoroError("Empty card data".to_string()));
        }

        let id = map
            .get("id")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_string().map(|s| s.to_string()))
            .ok_or_else(|| CardMindError::LoroError("Missing id field".to_string()))?;

        let title = map
            .get("title")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_string().map(|s| s.to_string()))
            .ok_or_else(|| CardMindError::LoroError("Missing title field".to_string()))?;

        let content = map
            .get("content")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_string().map(|s| s.to_string()))
            .ok_or_else(|| CardMindError::LoroError("Missing content field".to_string()))?;

        let created_at = map
            .get("created_at")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_i64().copied())
            .ok_or_else(|| CardMindError::LoroError("Missing created_at field".to_string()))?;

        let updated_at = map
            .get("updated_at")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_i64().copied())
            .ok_or_else(|| CardMindError::LoroError("Missing updated_at field".to_string()))?;

        let deleted = map
            .get("deleted")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_bool().copied())
            .unwrap_or(false);

        Ok(Card {
            id,
            title,
            content,
            created_at,
            updated_at,
            deleted,
            tags: Vec::new(),
            last_edit_device: None,
        })
    }

    /// 生成版本（简化：使用时间戳）
    fn generate_version() -> Vec<u8> {
        use chrono::Utc;
        let timestamp = Utc::now().timestamp_millis();
        timestamp.to_be_bytes().to_vec()
    }
}

/// 同步数据
///
/// 包含从数据池导出的更新数据
#[derive(Debug, Clone)]
pub struct SyncData {
    /// Loro 增量更新数据
    pub updates: Vec<u8>,

    /// 卡片数量
    pub card_count: usize,

    /// 当前版本号
    pub current_version: Vec<u8>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::store::card_store::CardStore;

    #[test]
    fn test_sync_manager_creation() {
        let store = Arc::new(Mutex::new(CardStore::new_in_memory().unwrap()));
        let manager = SyncManager::new(store);
        assert_eq!(manager.sync_versions.lock().unwrap().len(), 0);
    }

    #[test]
    fn test_sync_request_not_authorized() {
        let store = Arc::new(Mutex::new(CardStore::new_in_memory().unwrap()));
        let manager = SyncManager::new(store);

        // 设备未加入数据池
        let result = manager.handle_sync_request("pool-001", None, &[]);
        assert!(result.is_err());

        match result {
            Err(CardMindError::NotAuthorized(_)) => {}
            _ => panic!("应该返回 NotAuthorized 错误"),
        }
    }

    #[test]
    fn test_sync_version_tracking() {
        let store = Arc::new(Mutex::new(CardStore::new_in_memory().unwrap()));
        let manager = SyncManager::new(store);

        let version = vec![1, 2, 3, 4];
        manager.track_sync_version("pool-001", "peer-001", &version);

        let retrieved = manager.get_last_sync_version("pool-001", "peer-001");
        assert_eq!(retrieved, Some(version));
    }

    #[test]
    fn test_get_last_sync_version_not_found() {
        let store = Arc::new(Mutex::new(CardStore::new_in_memory().unwrap()));
        let manager = SyncManager::new(store);

        let not_found = manager.get_last_sync_version("pool-001", "peer-002");
        assert_eq!(not_found, None);
    }

    #[test]
    fn test_version_generation() {
        let store = Arc::new(Mutex::new(CardStore::new_in_memory().unwrap()));
        let _manager = SyncManager::new(store);

        let version1 = SyncManager::generate_version();

        // 版本应该是 8 字节（timestamp_millis 作为 i64）
        assert_eq!(version1.len(), 8);

        // 等待 2ms 确保时间戳不同
        std::thread::sleep(std::time::Duration::from_millis(2));

        let version2 = SyncManager::generate_version();
        assert_eq!(version2.len(), 8);

        // 版本应该不同（时间戳不同）
        assert_ne!(version1, version2, "两个版本应该不同");
    }

    #[test]
    fn test_merge_updates() {
        let store = Arc::new(Mutex::new(CardStore::new_in_memory().unwrap()));
        let _manager = SyncManager::new(store);

        // 构造一个 Loro 更新
        let doc = LoroDoc::new();
        let map = doc.get_map("card");
        map.insert("id", "card-1").unwrap();
        map.insert("title", "Title").unwrap();
        doc.commit();

        let updates = vec![doc.export(ExportMode::all_updates()).unwrap()];

        let merged = SyncManager::merge_updates(updates).unwrap();

        // 合并后的更新应该可以被导入
        let import_doc = LoroDoc::new();
        import_doc.import(&merged).unwrap();
        let imported_map = import_doc.get_map("card");
        assert_eq!(
            &**imported_map
                .get("title")
                .unwrap()
                .into_value()
                .unwrap()
                .as_string()
                .unwrap(),
            "Title"
        );
    }
}
