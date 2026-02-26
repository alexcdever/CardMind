// input: 
// output: 
// pos: 
use crate::models::error::CardMindError;
use crate::models::pool::{Pool, PoolMember};
use crate::store::loro_store::{load_loro_doc, pool_doc_path, save_loro_doc};
use crate::store::path_resolver::DataPaths;
use crate::store::sqlite_store::SqliteStore;
use crate::utils::uuid_v7::new_uuid_v7;
use loro::LoroValue;
use std::collections::HashSet;
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

    /// 创建数据池
    pub fn create_pool(
        &self,
        pool_key: &str,
        peer_id: &str,
        public_key: &str,
        multiaddr: &str,
        os: &str,
        hostname: &str,
    ) -> Result<Pool, CardMindError> {
        if pool_key.trim().is_empty() {
            return Err(CardMindError::InvalidArgument(
                "pool_key empty".to_string(),
            ));
        }
        let pool = Pool {
            pool_id: new_uuid_v7(),
            pool_key: pool_key.to_string(),
            members: vec![PoolMember {
                peer_id: peer_id.to_string(),
                public_key: public_key.to_string(),
                multiaddr: multiaddr.to_string(),
                os: os.to_string(),
                hostname: hostname.to_string(),
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
            .any(|member| member.peer_id == new_member.peer_id)
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
    pub fn leave_pool(&self, pool_id: &Uuid, peer_id: &str) -> Result<Pool, CardMindError> {
        let mut pool = self.sqlite.get_pool(pool_id)?;
        pool.members.retain(|member| member.peer_id != peer_id);
        self.persist_pool(&pool)?;
        Ok(pool)
    }

    fn persist_pool(&self, pool: &Pool) -> Result<(), CardMindError> {
        let path = self.paths.base_path.join(pool_doc_path(&pool.pool_id));
        let doc = load_loro_doc(&path)?;
        let map = doc.get_map("pool");
        map.insert("pool_id", pool.pool_id.to_string())
            .map_err(|e| CardMindError::Loro(e.to_string()))?;
        map.insert("pool_key", pool.pool_key.as_str())
            .map_err(|e| CardMindError::Loro(e.to_string()))?;

        let members_list = doc.get_list("members");
        if members_list.len() > 0 {
            members_list
                .delete(0, members_list.len())
                .map_err(|e| CardMindError::Loro(e.to_string()))?;
        }
        for member in &pool.members {
            let values = vec![
                LoroValue::from(member.peer_id.as_str()),
                LoroValue::from(member.public_key.as_str()),
                LoroValue::from(member.multiaddr.as_str()),
                LoroValue::from(member.os.as_str()),
                LoroValue::from(member.hostname.as_str()),
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
