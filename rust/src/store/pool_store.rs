//! 数据池存储管理
//!
//! 本模块实现数据池的完整存储管理，包括 Loro CRDT 层和 SQLite 缓存层。
//!
//! # 架构设计
//!
//! 遵循双层架构原则：
//! - **`Loro` 层**: 源数据，每个数据池一个 `LoroDoc`
//! - **SQLite 层**: 查询缓存，快速读取
//! - **订阅机制**: Loro 变更自动同步到 SQLite
//!
//! # 文件组织
//!
//! ```text
//! data/
//! ├── pools/
//! │   ├── <pool_id_base64>/
//! │   │   ├── snapshot.loro
//! │   │   └── update.loro
//! └── cache.db (SQLite)
//! ```
//!
//! # 示例
//!
//! ```no_run
//! use cardmind_rust::store::pool_store::PoolStore;
//! use cardmind_rust::models::pool::Pool;
//!
//! # fn example() -> Result<(), Box<dyn std::error::Error>> {
//! // 创建 PoolStore
//! let store = PoolStore::new("data")?;
//!
//! // 创建数据池
//! let pool = Pool::new("pool-001", "工作笔记", "hashed_password");
//! store.create_pool(&pool)?;
//!
//! // 查询数据池
//! let pool = store.get_pool_by_id("pool-001")?;
//! # Ok(())
//! # }
//! ```

use crate::models::error::CardMindError;
use crate::models::pool::{Device, Pool};
use crate::store::sqlite_store::SqliteStore;
use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine};
use loro::event::DiffEvent;
use loro::{ExportMode, LoroDoc, LoroList, LoroMap, Subscription};
use rusqlite::params;
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use tracing::{debug, info, warn};

/// Type alias for pool update callback
type PoolUpdateCallback = Arc<Mutex<Option<Box<dyn Fn(&Pool) + Send + Sync>>>>;

/// 数据池存储管理器
///
/// 负责数据池的完整生命周期管理
///
/// # 字段
///
/// - `base_path`: 数据目录基础路径
/// - `sqlite_store`: SQLite 缓存层
/// - ``loro_docs``: 内存中的 `LoroDoc` 缓存
/// - ``on_pool_updated``: `Pool`更新回调（用于同步`SQLite` `card_pool_bindings`）
/// - ``loro_subscriptions``: Loro 订阅句柄（保持订阅活跃）
pub struct PoolStore {
    /// 数据目录基础路径
    base_path: PathBuf,

    /// SQLite 缓存层
    sqlite_store: Arc<Mutex<SqliteStore>>,

    /// 内存中的 `LoroDoc` 缓存（`pool_id` -> `LoroDoc`）
    loro_docs: Arc<Mutex<HashMap<String, LoroDoc>>>,

    /// Pool更新回调
    on_pool_updated: PoolUpdateCallback,

    /// Loro 订阅句柄（保持订阅活跃）
    loro_subscriptions: Arc<Mutex<HashMap<String, Subscription>>>,
}

impl PoolStore {
    /// 创建新的 `PoolStore`
    ///
    /// # 参数
    ///
    /// - `base_path`: 数据目录路径
    ///
    /// # Errors
    ///
    /// 如果初始化失败，返回错误
    ///
    /// # 示例
    ///
    /// ```no_run
    /// use cardmind_rust::store::pool_store::PoolStore;
    ///
    /// let store = PoolStore::new("data").unwrap();
    /// ```
    pub fn new<P: AsRef<Path>>(base_path: P) -> Result<Self, CardMindError> {
        let base_path = base_path.as_ref().to_path_buf();
        info!("初始化 PoolStore，路径: {:?}", base_path);

        // 创建必要的目录
        let pools_dir = base_path.join("pools");
        fs::create_dir_all(&pools_dir)?;

        // 初始化 SQLite
        let cache_path = base_path.join("cache.db");
        let sqlite_store = Arc::new(Mutex::new(SqliteStore::new(cache_path.to_str().unwrap())?));

        Ok(Self {
            base_path,
            sqlite_store,
            loro_docs: Arc::new(Mutex::new(HashMap::new())),
            on_pool_updated: Arc::new(Mutex::new(None)),
            loro_subscriptions: Arc::new(Mutex::new(HashMap::new())),
        })
    }

    /// 创建内存 PoolStore（用于测试）
    ///
    /// # Errors
    ///
    /// 如果初始化失败，返回错误
    #[cfg(test)]
    pub fn new_in_memory() -> Result<Self, CardMindError> {
        Ok(Self {
            base_path: PathBuf::from(":memory:"),
            sqlite_store: Arc::new(Mutex::new(SqliteStore::new_in_memory()?)),
            loro_docs: Arc::new(Mutex::new(HashMap::new())),
            on_pool_updated: Arc::new(Mutex::new(None)),
            loro_subscriptions: Arc::new(Mutex::new(HashMap::new())),
        })
    }

    /// 设置Pool更新回调
    ///
    /// # 参数
    ///
    /// - `callback`: 回调函数，接收更新后的Pool对象
    ///
    /// # 用途
    ///
    /// 当`Pool`的`Loro`文档更新后，自动同步`SQLite`的`card_pool_bindings`表
    ///
    /// # 示例
    ///
    /// ```no_run
    /// # use cardmind_rust::store::pool_store::PoolStore;
    /// # use cardmind_rust::models::pool::Pool;
    /// let store = PoolStore::new("data").unwrap();
    ///
    /// store.set_on_pool_updated(|pool| {
    ///     // 同步SQLite绑定表
    ///     println!("Pool updated: {}", pool.pool_id);
    /// });
    /// ```
    pub fn set_on_pool_updated<F>(&self, callback: F)
    where
        F: Fn(&Pool) + Send + Sync + 'static,
    {
        let mut cb = self.on_pool_updated.lock().unwrap();
        *cb = Some(Box::new(callback));
    }

    /// 触发Pool更新回调
    ///
    /// # 参数
    ///
    /// - `pool`: 更新后的Pool对象
    fn trigger_pool_update_callback(&self, pool: &Pool) {
        if let Some(cb) = self.on_pool_updated.lock().unwrap().as_ref() {
            cb(pool);
        }
    }

    /// 设置 Loro 订阅
    ///
    /// 为指定的 LoroDoc 注册订阅回调，当文档变更时自动同步到 SQLite
    ///
    /// # 参数
    ///
    /// - `pool_id`: 数据池 ID
    /// - `doc`: Loro 文档实例
    fn setup_loro_subscription(&self, pool_id: String, doc: LoroDoc) {
        let pool_id_clone = pool_id.clone();
        let subscriptions = self.loro_subscriptions.clone();

        let subscription = doc.subscribe_root(Arc::new(move |event| {
            if let Err(e) = Self::on_loro_change(&pool_id_clone, event) {
                warn!("Loro 订阅回调处理失败: {}", e);
            }
        }));

        // 保存订阅句柄以保持订阅活跃
        subscriptions
            .lock()
            .unwrap()
            .insert(pool_id.clone(), subscription);

        debug!("已为数据池 {} 设置 Loro 订阅", pool_id);
    }

    /// Loro 变更回调处理
    ///
    /// 当 Loro 文档变更时，将变更同步到 SQLite
    ///
    /// # 参数
    ///
    /// - `pool_id`: 数据池 ID
    /// - `event`: Loro 变更事件
    ///
    /// # Returns
    ///
    /// 如果处理成功返回 Ok(())，否则返回错误
    fn on_loro_change<'a>(pool_id: &str, _event: DiffEvent<'a>) -> Result<(), CardMindError> {
        debug!("收到 Loro 变更事件: pool_id={}", pool_id);

        // TODO: 实现卡片创建、更新、删除事件处理
        // 当前仅打印日志，后续将实现完整的同步逻辑

        Ok(())
    }

    /// 获取数据池的 Loro 文件路径
    fn get_pool_loro_path(&self, pool_id: &str) -> PathBuf {
        let encoded = URL_SAFE_NO_PAD.encode(pool_id.as_bytes());
        self.base_path.join("pools").join(encoded)
    }

    /// 加载或创建数据池的 `LoroDoc`
    fn get_or_create_loro_doc(&self, pool_id: &str) -> Result<LoroDoc, CardMindError> {
        let mut docs = self.loro_docs.lock().unwrap();

        if let Some(doc) = docs.get(pool_id) {
            return Ok(doc.clone());
        }

        // 尝试从文件加载
        let pool_path = self.get_pool_loro_path(pool_id);
        let snapshot_path = pool_path.join("snapshot.loro");

        let doc = if snapshot_path.exists() {
            debug!("从文件加载数据池 LoroDoc: {}", pool_id);
            let bytes = fs::read(&snapshot_path)?;
            let doc = LoroDoc::new();
            doc.import(&bytes)?;
            doc
        } else {
            debug!("创建新的数据池 LoroDoc: {}", pool_id);
            LoroDoc::new()
        };

        docs.insert(pool_id.to_string(), doc.clone());

        // 设置 Loro 订阅
        drop(docs);
        self.setup_loro_subscription(pool_id.to_string(), doc.clone());

        Ok(doc)
    }

    /// 持久化数据池 `LoroDoc`
    fn persist_loro_doc(&self, pool_id: &str, doc: &LoroDoc) -> Result<(), CardMindError> {
        if self.base_path == Path::new(":memory:") {
            return Ok(()); // 内存模式不持久化
        }

        let pool_path = self.get_pool_loro_path(pool_id);
        fs::create_dir_all(&pool_path)?;

        let snapshot_path = pool_path.join("snapshot.loro");
        let bytes = doc.export(ExportMode::Snapshot)?;
        fs::write(snapshot_path, bytes)?;

        debug!("持久化数据池 LoroDoc: {}", pool_id);
        Ok(())
    }

    /// 将 Pool 对象序列化到 `LoroDoc`
    fn serialize_pool_to_loro(pool: &Pool, doc: &LoroDoc) -> Result<(), CardMindError> {
        let map = doc.get_map("pool");

        map.insert("pool_id", pool.pool_id.clone())?;
        map.insert("name", pool.name.clone())?;
        map.insert("password_hash", pool.password_hash.clone())?;
        map.insert("created_at", pool.created_at)?;
        map.insert("updated_at", pool.updated_at)?;

        // 序列化成员列表
        let members_list = map.insert_container("members", LoroList::new())?;
        for device in &pool.members {
            let device_map = members_list.insert_container(members_list.len(), LoroMap::new())?;
            device_map.insert("device_id", device.device_id.clone())?;
            device_map.insert("device_name", device.device_name.clone())?;
            device_map.insert("joined_at", device.joined_at)?;
        }

        Ok(())
    }

    /// 从 `LoroDoc` 反序列化 Pool 对象
    fn deserialize_pool_from_loro(doc: &LoroDoc) -> Result<Pool, CardMindError> {
        let map = doc.get_map("pool");

        let pool_id = map
            .get("pool_id")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_string().map(|s| s.to_string()))
            .ok_or_else(|| CardMindError::Unknown("pool_id 字段缺失".to_string()))?;

        let name = map
            .get("name")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_string().map(|s| s.to_string()))
            .ok_or_else(|| CardMindError::Unknown("name 字段缺失".to_string()))?;

        let password_hash = map
            .get("password_hash")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_string().map(|s| s.to_string()))
            .ok_or_else(|| CardMindError::Unknown("password_hash 字段缺失".to_string()))?;

        let created_at = map
            .get("created_at")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_i64().copied())
            .ok_or_else(|| CardMindError::Unknown("created_at 字段缺失".to_string()))?;

        let updated_at = map
            .get("updated_at")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_i64().copied())
            .ok_or_else(|| CardMindError::Unknown("updated_at 字段缺失".to_string()))?;

        // 反序列化成员列表
        let mut members = Vec::new();
        if let Some(members_value) = map.get("members") {
            if let Ok(members_list) = members_value.into_container() {
                let members_loro_list = members_list.into_list().ok();
                if let Some(members_loro_list) = members_loro_list {
                    for i in 0..members_loro_list.len() {
                        if let Some(device_value) = members_loro_list.get(i) {
                            if let Ok(device_container) = device_value.into_container() {
                                if let Ok(device_map) = device_container.into_map() {
                                    let device_id = device_map
                                        .get("device_id")
                                        .and_then(|v| v.into_value().ok())
                                        .and_then(|v| v.as_string().map(|s| s.to_string()));

                                    let device_name = device_map
                                        .get("device_name")
                                        .and_then(|v| v.into_value().ok())
                                        .and_then(|v| v.as_string().map(|s| s.to_string()));

                                    let joined_at = device_map
                                        .get("joined_at")
                                        .and_then(|v| v.into_value().ok())
                                        .and_then(|v| v.as_i64().copied());

                                    if let (Some(device_id), Some(device_name), Some(joined_at)) =
                                        (device_id, device_name, joined_at)
                                    {
                                        members.push(Device {
                                            device_id,
                                            device_name,
                                            joined_at,
                                        });
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Ok(Pool {
            pool_id,
            name,
            password_hash,
            members,
            card_ids: Vec::new(),
            created_at,
            updated_at,
        })
    }

    /// 同步 Pool 到 SQLite
    fn sync_pool_to_sqlite(&self, pool: &Pool) -> Result<(), CardMindError> {
        let conn = &self.sqlite_store.lock().unwrap().conn;

        conn.execute(
            "INSERT OR REPLACE INTO pools (pool_id, name, password_hash, created_at, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5)",
            params![
                &pool.pool_id,
                &pool.name,
                &pool.password_hash,
                pool.created_at,
                pool.updated_at,
            ],
        )?;

        debug!("同步数据池到 SQLite: {}", pool.pool_id);
        Ok(())
    }

    // ==================== CRUD 操作 ====================

    /// 创建数据池
    ///
    /// # 参数
    ///
    /// - `pool`: 数据池对象
    ///
    /// # Errors
    ///
    /// 如果创建失败，返回错误
    ///
    /// # 示例
    ///
    /// ```no_run
    /// use cardmind_rust::store::pool_store::PoolStore;
    /// use cardmind_rust::models::pool::Pool;
    ///
    /// # fn example() -> Result<(), Box<dyn std::error::Error>> {
    /// let store = PoolStore::new("data")?;
    /// let pool = Pool::new("pool-001", "工作笔记", "hashed_password");
    /// store.create_pool(&pool)?;
    /// # Ok(())
    /// # }
    /// ```
    pub fn create_pool(&self, pool: &Pool) -> Result<(), CardMindError> {
        info!("创建数据池: {}", pool.pool_id);

        // 1. 写入 Loro
        let doc = self.get_or_create_loro_doc(&pool.pool_id)?;
        Self::serialize_pool_to_loro(pool, &doc)?;
        doc.commit();

        // 2. 持久化 Loro
        self.persist_loro_doc(&pool.pool_id, &doc)?;

        // 3. 同步到 SQLite
        self.sync_pool_to_sqlite(pool)?;

        // 4. 触发回调（同步 card_pool_bindings）
        self.trigger_pool_update_callback(pool);

        Ok(())
    }

    /// 根据 ID 查询数据池
    ///
    /// # 参数
    ///
    /// - `pool_id`: 数据池 ID
    ///
    /// # Errors
    ///
    /// 如果数据池不存在，返回错误
    ///
    /// # 示例
    ///
    /// ```no_run
    /// use cardmind_rust::store::pool_store::PoolStore;
    ///
    /// # fn example() -> Result<(), Box<dyn std::error::Error>> {
    /// let store = PoolStore::new("data")?;
    /// let pool = store.get_pool_by_id("pool-001")?;
    /// println!("数据池名称: {}", pool.name);
    /// # Ok(())
    /// # }
    /// ```
    pub fn get_pool_by_id(&self, pool_id: &str) -> Result<Pool, CardMindError> {
        debug!("查询数据池: {}", pool_id);

        // 从 Loro 读取（源数据）
        let doc = self.get_or_create_loro_doc(pool_id)?;
        Self::deserialize_pool_from_loro(&doc)
    }

    /// 查询所有数据池
    ///
    /// # Errors
    ///
    /// 如果查询失败，返回错误
    ///
    /// # 示例
    ///
    /// ```no_run
    /// use cardmind_rust::store::pool_store::PoolStore;
    ///
    /// # fn example() -> Result<(), Box<dyn std::error::Error>> {
    /// let store = PoolStore::new("data")?;
    /// let pools = store.get_all_pools()?;
    /// println!("共 {} 个数据池", pools.len());
    /// # Ok(())
    /// # }
    /// ```
    pub fn get_all_pools(&self) -> Result<Vec<Pool>, CardMindError> {
        debug!("查询所有数据池");

        let conn = &self.sqlite_store.lock().unwrap().conn;
        let mut stmt = conn.prepare("SELECT pool_id FROM pools ORDER BY updated_at DESC")?;

        let pool_ids: Vec<String> = stmt
            .query_map([], |row| row.get(0))?
            .collect::<Result<Vec<_>, _>>()?;

        let mut pools = Vec::new();
        for pool_id in pool_ids {
            if let Ok(pool) = self.get_pool_by_id(&pool_id) {
                pools.push(pool);
            }
        }

        Ok(pools)
    }

    /// 更新数据池信息
    ///
    /// # 参数
    ///
    /// - `pool`: 更新后的数据池对象
    ///
    /// # Errors
    ///
    /// 如果更新失败，返回错误
    ///
    /// # 示例
    ///
    /// ```no_run
    /// use cardmind_rust::store::pool_store::PoolStore;
    ///
    /// # fn example() -> Result<(), Box<dyn std::error::Error>> {
    /// let store = PoolStore::new("data")?;
    /// let mut pool = store.get_pool_by_id("pool-001")?;
    /// pool.name = "新名称".to_string();
    /// store.update_pool(&pool)?;
    /// # Ok(())
    /// # }
    /// ```
    pub fn update_pool(&self, pool: &Pool) -> Result<(), CardMindError> {
        info!("更新数据池: {}", pool.pool_id);

        // 1. 更新 Loro
        let doc = self.get_or_create_loro_doc(&pool.pool_id)?;
        Self::serialize_pool_to_loro(pool, &doc)?;
        doc.commit();

        // 2. 持久化 Loro
        self.persist_loro_doc(&pool.pool_id, &doc)?;

        // 3. 同步到 SQLite
        self.sync_pool_to_sqlite(pool)?;

        // 4. 触发回调（同步 card_pool_bindings）
        self.trigger_pool_update_callback(pool);

        Ok(())
    }

    /// 删除数据池
    ///
    /// # 参数
    ///
    /// - `pool_id`: 数据池 ID
    ///
    /// # Errors
    ///
    /// 如果删除失败，返回错误
    ///
    /// # 示例
    ///
    /// ```no_run
    /// use cardmind_rust::store::pool_store::PoolStore;
    ///
    /// # fn example() -> Result<(), Box<dyn std::error::Error>> {
    /// let store = PoolStore::new("data")?;
    /// store.delete_pool("pool-001")?;
    /// # Ok(())
    /// # }
    /// ```
    pub fn delete_pool(&self, pool_id: &str) -> Result<(), CardMindError> {
        info!("删除数据池: {}", pool_id);

        // 1. 从内存缓存移除
        self.loro_docs.lock().unwrap().remove(pool_id);

        // 2. 删除 Loro 文件
        if self.base_path != Path::new(":memory:") {
            let pool_path = self.get_pool_loro_path(pool_id);
            if pool_path.exists() {
                fs::remove_dir_all(pool_path)?;
            }
        }

        // 3. 从 SQLite 删除
        let conn = &self.sqlite_store.lock().unwrap().conn;
        conn.execute("DELETE FROM pools WHERE pool_id = ?1", params![pool_id])?;

        Ok(())
    }

    /// 添加成员到数据池
    ///
    /// # 参数
    ///
    /// - `pool_id`: 数据池 ID
    /// - `device`: 设备信息
    ///
    /// # Errors
    ///
    /// 如果操作失败，返回错误
    pub fn add_member(&self, pool_id: &str, device: Device) -> Result<(), CardMindError> {
        let mut pool = self.get_pool_by_id(pool_id)?;
        pool.add_member(device);
        self.update_pool(&pool)
    }

    /// 从数据池移除成员
    ///
    /// # 参数
    ///
    /// - `pool_id`: 数据池 ID
    /// - `device_id`: 设备 ID
    ///
    /// # Errors
    ///
    /// 如果操作失败，返回错误
    pub fn remove_member(&self, pool_id: &str, device_id: &str) -> Result<(), CardMindError> {
        let mut pool = self.get_pool_by_id(pool_id)?;
        pool.remove_member(device_id);
        self.update_pool(&pool)
    }

    /// 更新成员昵称
    ///
    /// # 参数
    ///
    /// - `pool_id`: 数据池 ID
    /// - `device_id`: 设备 ID
    /// - `new_name`: 新昵称
    ///
    /// # Errors
    ///
    /// 如果操作失败，返回错误
    pub fn update_member_name(
        &self,
        pool_id: &str,
        device_id: &str,
        new_name: &str,
    ) -> Result<(), CardMindError> {
        let mut pool = self.get_pool_by_id(pool_id)?;
        pool.update_member_name(device_id, new_name)
            .map_err(|e| CardMindError::Unknown(e.to_string()))?;
        self.update_pool(&pool)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pool_store_creation() {
        let store = PoolStore::new_in_memory();
        assert!(store.is_ok(), "应该能创建内存 PoolStore");
    }

    #[test]
    fn test_create_and_get_pool() {
        let store = PoolStore::new_in_memory().unwrap();

        let pool = Pool::new("pool-001", "工作笔记", "hashed_password");
        let pool_id = pool.pool_id.clone();

        // 创建数据池
        store.create_pool(&pool).unwrap();

        // 查询数据池
        let retrieved = store.get_pool_by_id(&pool_id).unwrap();
        assert_eq!(retrieved.pool_id, pool_id);
        assert_eq!(retrieved.name, "工作笔记");
        assert_eq!(retrieved.password_hash, "hashed_password");
    }

    #[test]
    fn test_update_pool() {
        let store = PoolStore::new_in_memory().unwrap();

        let pool = Pool::new("pool-001", "工作笔记", "hashed_password");
        store.create_pool(&pool).unwrap();

        // 更新数据池
        let mut updated_pool = store.get_pool_by_id("pool-001").unwrap();
        updated_pool.name = "个人笔记".to_string();
        store.update_pool(&updated_pool).unwrap();

        // 验证更新
        let retrieved = store.get_pool_by_id("pool-001").unwrap();
        assert_eq!(retrieved.name, "个人笔记");
    }

    #[test]
    fn test_delete_pool() {
        let store = PoolStore::new_in_memory().unwrap();

        let pool = Pool::new("pool-001", "工作笔记", "hashed_password");
        store.create_pool(&pool).unwrap();

        // 删除数据池
        store.delete_pool("pool-001").unwrap();

        // 验证删除（应该获取失败）
        let result = store.get_pool_by_id("pool-001");
        assert!(result.is_err(), "删除后不应该能获取数据池");
    }

    #[test]
    #[allow(clippy::similar_names)]
    fn test_get_all_pools() {
        let store = PoolStore::new_in_memory().unwrap();

        // 创建多个数据池
        let pool1 = Pool::new("pool-001", "工作笔记", "hash1");
        let pool2 = Pool::new("pool-002", "个人笔记", "hash2");
        store.create_pool(&pool1).unwrap();
        store.create_pool(&pool2).unwrap();

        // 查询所有数据池
        let pools = store.get_all_pools().unwrap();
        assert_eq!(pools.len(), 2);
    }

    #[test]
    fn test_add_member() {
        let store = PoolStore::new_in_memory().unwrap();

        let pool = Pool::new("pool-001", "工作笔记", "hashed");
        store.create_pool(&pool).unwrap();

        // 添加成员
        let device = Device::new("device-001", "我的手机");
        store.add_member("pool-001", device).unwrap();

        // 验证成员已添加
        let pool = store.get_pool_by_id("pool-001").unwrap();
        assert_eq!(pool.members.len(), 1);
        assert_eq!(pool.members[0].device_id, "device-001");
    }

    #[test]
    fn test_remove_member() {
        let store = PoolStore::new_in_memory().unwrap();

        let mut pool = Pool::new("pool-001", "工作笔记", "hashed");
        pool.add_member(Device::new("device-001", "我的手机"));
        store.create_pool(&pool).unwrap();

        // 移除成员
        store.remove_member("pool-001", "device-001").unwrap();

        // 验证成员已移除
        let pool = store.get_pool_by_id("pool-001").unwrap();
        assert_eq!(pool.members.len(), 0);
    }

    #[test]
    fn test_update_member_name() {
        let store = PoolStore::new_in_memory().unwrap();

        let mut pool = Pool::new("pool-001", "工作笔记", "hashed");
        pool.add_member(Device::new("device-001", "我的手机"));
        store.create_pool(&pool).unwrap();

        // 更新成员昵称
        store
            .update_member_name("pool-001", "device-001", "工作手机")
            .unwrap();

        // 验证昵称已更新
        let pool = store.get_pool_by_id("pool-001").unwrap();
        assert_eq!(pool.members[0].device_name, "工作手机");
    }

    #[test]
    fn test_pool_persistence_loro_serialization() {
        let _store = PoolStore::new_in_memory().unwrap();

        // 创建包含成员的数据池
        let mut pool = Pool::new("pool-001", "工作笔记", "hashed");
        pool.add_member(Device::new("device-001", "手机"));
        pool.add_member(Device::new("device-002", "电脑"));

        // 序列化到 Loro
        let doc = LoroDoc::new();
        PoolStore::serialize_pool_to_loro(&pool, &doc).unwrap();

        // 反序列化
        let deserialized = PoolStore::deserialize_pool_from_loro(&doc).unwrap();

        assert_eq!(deserialized.pool_id, pool.pool_id);
        assert_eq!(deserialized.name, pool.name);
        assert_eq!(deserialized.members.len(), 2);
        assert_eq!(deserialized.members[0].device_id, "device-001");
        assert_eq!(deserialized.members[1].device_id, "device-002");
    }

    #[test]
    fn test_loro_subscription_setup() {
        let store = PoolStore::new_in_memory().unwrap();

        let pool = Pool::new("pool-001", "测试池", "hashed");
        store.create_pool(&pool).unwrap();

        // 验证订阅已设置
        let subscriptions = store.loro_subscriptions.lock().unwrap();
        assert!(subscriptions.contains_key("pool-001"), "应该为池设置订阅");
    }

    #[test]
    fn test_loro_callback_on_change() {
        use std::time::Duration;

        let store = PoolStore::new_in_memory().unwrap();

        let pool = Pool::new("pool-001", "测试池", "hashed");
        store.create_pool(&pool).unwrap();

        // 修改数据池（触发 Loro 变更）
        std::thread::sleep(Duration::from_millis(100));

        let mut updated_pool = store.get_pool_by_id("pool-001").unwrap();
        updated_pool.name = "更新后的名称".to_string();
        store.update_pool(&updated_pool).unwrap();

        // 等待回调处理
        std::thread::sleep(Duration::from_millis(100));

        // 验证更新成功
        let retrieved = store.get_pool_by_id("pool-001").unwrap();
        assert_eq!(retrieved.name, "更新后的名称");
    }
}
