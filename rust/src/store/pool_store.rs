// input: 建池/入池/离池参数、成员与卡片集合、Loro 文档与 SQLite 读写返回。
// output: Pool 数据更新结果及其在 Loro 写模型和 SQLite 读模型中的持久化状态。
// pos: 数据池存储实现文件，负责池成员与卡片关联关系的本地维护，并遵守先写 Loro、再投影到 SQLite 的约束。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件实现数据池本地读写分离存储。
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

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum ProjectionMode {
    Normal,
    FailWrites,
}

/// 本地卡片池存储
pub struct PoolStore {
    paths: DataPaths,
    sqlite: SqliteStore,
    projection_mode: ProjectionMode,
}

/// 本地卡片池存储实现
impl PoolStore {
    const POOL_ENTITY: &'static str = "pool";
    const RETRY_PROJECTION: &'static str = "retry_projection";

    /// 创建数据池存储
    pub fn new(base_path: &str) -> Result<Self, CardMindError> {
        Self::new_with_projection_mode(base_path, ProjectionMode::Normal)
    }

    /// 创建一个注入投影失败的数据池存储（测试用）
    pub fn new_with_projection_failure(base_path: &str) -> Result<Self, CardMindError> {
        Self::new_with_projection_mode(base_path, ProjectionMode::FailWrites)
    }

    fn new_with_projection_mode(
        base_path: &str,
        projection_mode: ProjectionMode,
    ) -> Result<Self, CardMindError> {
        let paths = DataPaths::new(base_path)?;
        let sqlite = SqliteStore::new(&paths.sqlite_path)?;
        Ok(Self {
            paths,
            sqlite,
            projection_mode,
        })
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
        match self.sqlite.get_pool(pool_id) {
            Ok(pool) => Ok(pool),
            Err(CardMindError::NotFound(_)) => {
                if let Some(error) = self.projection_not_converged_for(pool_id)? {
                    return Err(error);
                }
                Err(CardMindError::NotFound("pool not found".to_string()))
            }
            Err(err) => Err(err),
        }
    }

    /// 获取任意一个数据池（默认第一个）
    pub fn get_any_pool(&self) -> Result<Pool, CardMindError> {
        let ids = self.sqlite.list_pool_ids()?;
        let pool_id = ids
            .first()
            .ok_or_else(|| CardMindError::NotFound("pool not found".to_string()))?;
        self.get_pool(pool_id)
    }

    /// 将 note 引用挂接到池元数据，已存在则去重保留
    pub fn attach_note_references(
        &self,
        pool_id: &Uuid,
        note_ids: Vec<Uuid>,
    ) -> Result<Pool, CardMindError> {
        let mut pool = self.get_pool(pool_id)?;
        pool.card_ids = merge_note_references(&pool.card_ids, note_ids);
        self.persist_pool(&pool)?;
        Ok(pool)
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
        updated.card_ids = merge_note_references(&updated.card_ids, local_card_ids);
        self.persist_pool(&updated)?;
        Ok(updated)
    }

    /// 通过加入码加入数据池
    pub fn join_by_code(
        &self,
        code: &str,
        new_member: PoolMember,
        local_card_ids: Vec<Uuid>,
    ) -> Result<Pool, CardMindError> {
        let pool_id = Uuid::parse_str(code)
            .map_err(|_| CardMindError::InvalidArgument("invalid join code".to_string()))?;
        let pool = self.get_pool(&pool_id)?;
        self.join_pool(&pool, new_member, local_card_ids)
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
        self.write_pool_to_loro(pool)?;
        self.project_pool_to_sqlite(pool)?;
        Ok(())
    }

    fn write_pool_to_loro(&self, pool: &Pool) -> Result<(), CardMindError> {
        let path = self.paths.base_path.join(pool_doc_path(&pool.pool_id));
        let doc = load_loro_doc(&path)?;
        let map = doc.get_map("pool");
        map.insert("pool_id", pool.pool_id.to_string())
            .map_err(|e| CardMindError::Loro(e.to_string()))?;

        let members_list = doc.get_list("members");
        if !members_list.is_empty() {
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
        if !card_list.is_empty() {
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
        save_loro_doc(&path, &doc)
    }

    fn project_pool_to_sqlite(&self, pool: &Pool) -> Result<(), CardMindError> {
        if self.projection_mode == ProjectionMode::FailWrites {
            self.sqlite.record_projection_failure(
                Self::POOL_ENTITY,
                &pool.pool_id.to_string(),
                Self::RETRY_PROJECTION,
            )?;
            return Err(Self::build_projection_error(
                pool.pool_id,
                Self::RETRY_PROJECTION.to_string(),
            ));
        }
        self.sqlite.upsert_pool(pool)?;
        self.sqlite
            .clear_projection_failure(Self::POOL_ENTITY, &pool.pool_id.to_string())?;
        Ok(())
    }

    fn projection_not_converged_for(
        &self,
        pool_id: &Uuid,
    ) -> Result<Option<CardMindError>, CardMindError> {
        Ok(self
            .sqlite
            .get_projection_retry_action(Self::POOL_ENTITY, &pool_id.to_string())?
            .map(|retry_action| Self::build_projection_error(*pool_id, retry_action)))
    }

    fn build_projection_error(pool_id: Uuid, retry_action: String) -> CardMindError {
        CardMindError::ProjectionNotConverged {
            entity: Self::POOL_ENTITY.to_string(),
            entity_id: pool_id.to_string(),
            retry_action,
        }
    }
}

fn merge_note_references(existing: &[Uuid], incoming: Vec<Uuid>) -> Vec<Uuid> {
    let mut card_set: HashSet<Uuid> = existing.iter().cloned().collect();
    for card_id in incoming {
        card_set.insert(card_id);
    }
    card_set.into_iter().collect()
}
