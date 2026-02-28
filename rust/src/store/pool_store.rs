// input: 建池/入池/离池参数、成员与卡片集合、Loro 文档与 SQLite 读写返回。
// output: Pool 数据更新结果及其在 Loro 文档和 SQLite 缓存中的持久化状态。
// pos: 数据池存储实现文件，负责池成员与卡片关联关系的本地维护。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件实现数据池本地存储读写。
use crate::models::error::CardMindError;
use crate::models::pool::{Pool, PoolMember};
use crate::store::loro_store::{load_loro_doc, pool_doc_path, save_loro_doc};
use crate::store::path_resolver::DataPaths;
use crate::store::sqlite_store::SqliteStore;
use crate::utils::uuid_v7::new_uuid_v7;
use loro::LoroValue;
use std::collections::HashSet;
use std::path::Path;
use uuid::Uuid;

/// 本地卡片池存储
pub struct PoolStore {
    paths: DataPaths,
    sqlite: SqliteStore,
}

/// 本地卡片池存储实现
impl PoolStore {
    /// 创建数据池存储
    pub fn new(base_path: &str) -> Result<Self, CardMindError> {
        let paths = DataPaths::new(base_path)?;
        let sqlite = SqliteStore::new(&paths.sqlite_path)?;
        Ok(Self { paths, sqlite })
    }

    /// 获取存储根路径
    pub fn base_path(&self) -> &Path {
        &self.paths.base_path
    }

    /// 创建数据池
    pub fn create_pool(
        &self,
        endpoint_id: &str,
        nickname: &str,
        os: &str,
    ) -> Result<Pool, CardMindError> {
        let pool = Pool {
            pool_id: new_uuid_v7(),
            members: vec![PoolMember {
                endpoint_id: endpoint_id.to_string(),
                nickname: nickname.to_string(),
                os: os.to_string(),
                is_admin: true,
            }],
            card_ids: Vec::new(),
        };
        self.persist_pool(&pool)?;
        Ok(pool)
    }

    /// 获取数据池
    pub fn get_pool(&self, pool_id: &Uuid) -> Result<Pool, CardMindError> {
        self.sqlite.get_pool(pool_id)
    }

    /// 获取任意一个数据池（默认第一个）
    pub fn get_any_pool(&self) -> Result<Pool, CardMindError> {
        let ids = self.sqlite.list_pool_ids()?;
        let pool_id = ids
            .first()
            .ok_or_else(|| CardMindError::NotFound("pool not found".to_string()))?;
        self.get_pool(pool_id)
    }

    /// 加入数据池
    pub fn join_pool(
        &self,
        pool: &Pool,
        new_member: PoolMember,
        local_card_ids: Vec<Uuid>,
    ) -> Result<Pool, CardMindError> {
        let mut updated = pool.clone();
        if !updated
            .members
            .iter()
            .any(|member| member.endpoint_id == new_member.endpoint_id)
        {
            updated.members.push(new_member);
        }
        let mut card_set: HashSet<Uuid> = updated.card_ids.iter().cloned().collect();
        for card_id in local_card_ids {
            card_set.insert(card_id);
        }
        updated.card_ids = card_set.into_iter().collect();
        self.persist_pool(&updated)?;
        Ok(updated)
    }

    /// 离开数据池
    pub fn leave_pool(&self, pool_id: &Uuid, endpoint_id: &str) -> Result<Pool, CardMindError> {
        let mut pool = self.sqlite.get_pool(pool_id)?;
        pool.members
            .retain(|member| member.endpoint_id != endpoint_id);
        self.persist_pool(&pool)?;
        Ok(pool)
    }

    fn persist_pool(&self, pool: &Pool) -> Result<(), CardMindError> {
        let path = self.paths.base_path.join(pool_doc_path(&pool.pool_id));
        let doc = load_loro_doc(&path)?;
        let map = doc.get_map("pool");
        map.insert("pool_id", pool.pool_id.to_string())
            .map_err(|e| CardMindError::Loro(e.to_string()))?;

        let members_list = doc.get_list("members");
        if members_list.len() > 0 {
            members_list
                .delete(0, members_list.len())
                .map_err(|e| CardMindError::Loro(e.to_string()))?;
        }
        for member in &pool.members {
            let values = vec![
                LoroValue::from(member.endpoint_id.as_str()),
                LoroValue::from(member.nickname.as_str()),
                LoroValue::from(member.os.as_str()),
                LoroValue::from(member.is_admin),
            ];
            members_list
                .push(LoroValue::from(values))
                .map_err(|e| CardMindError::Loro(e.to_string()))?;
        }

        let card_list = doc.get_list("card_ids");
        if card_list.len() > 0 {
            card_list
                .delete(0, card_list.len())
                .map_err(|e| CardMindError::Loro(e.to_string()))?;
        }
        for card_id in &pool.card_ids {
            card_list
                .push(card_id.to_string())
                .map_err(|e| CardMindError::Loro(e.to_string()))?;
        }

        doc.commit();
        save_loro_doc(&path, &doc)?;
        self.sqlite.upsert_pool(pool)?;
        Ok(())
    }
}
