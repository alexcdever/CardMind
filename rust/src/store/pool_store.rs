//! # PoolStore 模块
//!
//! 本地数据池存储实现，负责池成员与卡片关联关系的本地维护。
//!
//! ## 架构说明
//! 本模块采用双引擎架构：
//! - **Loro CRDT**：作为写模型，负责数据的最终一致性和协作同步
//! - **SQLite**：作为读模型，提供高效的查询和检索能力
//!
//! 数据流向：业务逻辑 → Loro 写模型 → 投影到 SQLite 读模型 → 查询返回
//!
//! ## 调用约束
//! - 必须先完成 Loro 写入，再执行 SQLite 投影
//! - 投影失败时会记录重试标记，需调用方重试
//! - 所有数据操作都通过 `PoolStore` 结构体进行
//!
//! ## 主要功能
//! - 创建和管理数据池（Pool）
//! - 池成员的加入/离开管理
//! - 笔记引用与数据池的关联
//! - 投影失败的检测与恢复
//!
//! ## 示例
//! ```rust,ignore
//! use rust::store::pool_store::PoolStore;
//!
//! // 创建存储实例
//! let store = PoolStore::new("/path/to/data")?;
//!
//! // 创建数据池
//! let pool = store.create_pool("endpoint-1", "My Device", "macOS")?;
//!
//! // 加入数据池
//! let updated_pool = store.join_pool(&pool, new_member, local_cards)?;
//! ```
use crate::models::error::CardMindError;
use crate::models::pool::{JoinRequest, JoinRequestStatus, Pool, PoolMember};
use crate::store::loro_store::{load_loro_doc, pool_doc_path, save_loro_doc};
use crate::store::path_resolver::DataPaths;
use crate::store::sqlite_store::SqliteStore;
use crate::utils::uuid_v7::new_uuid_v7;
use loro::LoroValue;
use std::collections::HashSet;
use std::path::Path;
use uuid::Uuid;

/// 投影模式枚举，用于控制数据从 Loro 到 SQLite 的投影行为
///
/// 主要用于测试场景模拟投影失败
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum ProjectionMode {
    /// 正常模式，正常执行投影
    Normal,
    /// 模拟投影失败模式，用于测试错误处理
    FailWrites,
}

/// 本地数据池存储结构体
///
/// 负责管理数据池的完整生命周期，包括创建、查询、成员管理以及
/// 笔记引用的关联。采用 Loro 作为写模型，SQLite 作为读模型的架构。
///
/// ## 字段说明
pub struct PoolStore {
    /// 数据路径配置，包含 base_path、Loro 目录和 SQLite 路径
    paths: DataPaths,
    /// SQLite 读模型存储实例
    sqlite: SqliteStore,
    /// 投影模式，控制数据从 Loro 到 SQLite 的投影行为
    projection_mode: ProjectionMode,
}

impl PoolStore {
    /// 实体类型常量 - 数据池
    const POOL_ENTITY: &'static str = "pool";
    /// 重试动作常量 - 重新执行投影
    const RETRY_PROJECTION: &'static str = "retry_projection";

    /// 创建数据池存储实例
    ///
    /// # 参数
    /// * `base_path` - 数据存储根目录路径
    ///
    /// # 返回
    /// 初始化后的 [`PoolStore`] 实例
    ///
    /// # Errors
    /// - 当 `base_path` 为空时返回 [`CardMindError::InvalidArgument`]
    /// - 当目录创建失败时返回 `CardMindError::Io`
    /// - 当 SQLite 初始化失败时返回 [`CardMindError::Sqlite`]
    ///
    /// # Examples
    /// ```rust,ignore
    /// use rust::store::pool_store::PoolStore;
    ///
    /// let store = PoolStore::new("/home/user/.cardmind")?;
    /// ```
    pub fn new(base_path: &str) -> Result<Self, CardMindError> {
        Self::new_with_projection_mode(base_path, ProjectionMode::Normal)
    }

    /// 创建一个注入投影失败的数据池存储（仅用于测试）
    ///
    /// # 参数
    /// * `base_path` - 数据存储根目录路径
    ///
    /// # 返回
    /// 初始化后的 [`PoolStore`] 实例，投影操作将总是失败
    ///
    /// # Errors
    /// 同 [`PoolStore::new`]
    ///
    /// # Note
    /// 此方法仅用于测试错误处理逻辑，不应在生产代码中使用
    pub fn new_with_projection_failure(base_path: &str) -> Result<Self, CardMindError> {
        Self::new_with_projection_mode(base_path, ProjectionMode::FailWrites)
    }

    /// 内部方法：使用指定投影模式创建存储实例
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
    ///
    /// # 返回
    /// 数据存储根目录的 [`Path`] 引用
    pub fn base_path(&self) -> &Path {
        &self.paths.base_path
    }

    /// 创建新的数据池
    ///
    /// 自动创建池 ID，并将调用方设置为管理员成员。
    ///
    /// # 参数
    /// * `endpoint_id` - 设备端点 ID
    /// * `nickname` - 设备昵称
    /// * `os` - 操作系统信息
    ///
    /// # 返回
    /// 创建成功的 [`Pool`] 实例
    ///
    /// # Errors
    /// - 当 Loro 写入失败时返回 [`CardMindError::Loro`]
    /// - 当 SQLite 投影失败时返回 [`CardMindError::ProjectionNotConverged`]
    ///
    /// # Examples
    /// ```rust,ignore
    /// let pool = store.create_pool("device-001", "My MacBook", "macOS")?;
    /// println!("Created pool: {}", pool.pool_id);
    /// ```
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
            is_dissolved: false,
            join_requests: Vec::new(),
        };
        self.persist_pool(&pool)?;
        Ok(pool)
    }

    /// 获取指定 ID 的数据池
    ///
    /// 优先从 SQLite 读模型查询。如果未找到，会检查是否存在投影失败标记。
    ///
    /// # 参数
    /// * `pool_id` - 数据池 UUID
    ///
    /// # 返回
    /// 查询到的 [`Pool`] 实例
    ///
    /// # Errors
    /// - 当数据池不存在时返回 [`CardMindError::NotFound`]
    /// - 当存在投影失败时返回 [`CardMindError::ProjectionNotConverged`]
    /// - 当数据库查询失败时返回 [`CardMindError::Sqlite`]
    pub fn get_pool(&self, pool_id: &Uuid) -> Result<Pool, CardMindError> {
        match self.sqlite.get_pool(pool_id) {
            Ok(mut pool) => {
                pool.join_requests = self.load_join_requests_from_loro(pool_id)?;
                Ok(pool)
            }
            Err(CardMindError::NotFound(_)) => {
                if let Some(error) = self.projection_not_converged_for(pool_id)? {
                    return Err(error);
                }
                Err(CardMindError::NotFound("pool not found".to_string()))
            }
            Err(err) => Err(err),
        }
    }

    /// 获取任意一个数据池
    ///
    /// 返回存储中的第一个数据池。适用于只有一个数据池的常见场景。
    ///
    /// # 返回
    /// 查询到的 [`Pool`] 实例
    ///
    /// # Errors
    /// - 当没有数据池时返回 [`CardMindError::NotFound`]
    /// - 当数据库查询失败时返回 [`CardMindError::Sqlite`]
    pub fn get_any_pool(&self) -> Result<Pool, CardMindError> {
        let ids = self.sqlite.list_pool_ids()?;
        let pool_id = ids
            .first()
            .ok_or_else(|| CardMindError::NotFound("pool not found".to_string()))?;
        self.get_pool(pool_id)
    }

    /// 将笔记引用挂接到数据池元数据
    ///
    /// 将指定的笔记 ID 列表关联到数据池。已存在的引用会被保留（去重）。
    ///
    /// # 参数
    /// * `pool_id` - 数据池 UUID
    /// * `note_ids` - 要关联的笔记 ID 列表
    ///
    /// # 返回
    /// 更新后的 [`Pool`] 实例
    ///
    /// # Errors
    /// - 当数据池不存在时返回 [`CardMindError::NotFound`]
    /// - 当持久化失败时返回相应的错误类型
    pub fn attach_note_references(
        &self,
        pool_id: &Uuid,
        note_ids: Vec<Uuid>,
    ) -> Result<Pool, CardMindError> {
        let mut pool = self.get_pool(pool_id)?;
        if pool.is_dissolved {
            return Err(CardMindError::InvalidArgument(
                "dissolved pool cannot be modified".to_string(),
            ));
        }
        pool.card_ids = merge_note_references(&pool.card_ids, note_ids);
        self.persist_pool(&pool)?;
        Ok(pool)
    }

    /// 加入数据池
    ///
    /// 将新成员添加到数据池，同时合并本地卡片引用。
    ///
    /// # 参数
    /// * `pool` - 要加入的数据池
    /// * `new_member` - 新成员信息
    /// * `local_card_ids` - 要共享的本地卡片 ID 列表
    ///
    /// # 返回
    /// 更新后的 [`Pool`] 实例
    ///
    /// # Errors
    /// - 当持久化失败时返回相应的错误类型
    ///
    /// # Note
    /// 如果成员已存在（通过 endpoint_id 判断），则不会重复添加
    pub fn join_pool(
        &self,
        pool: &Pool,
        new_member: PoolMember,
        local_card_ids: Vec<Uuid>,
    ) -> Result<Pool, CardMindError> {
        if pool.is_dissolved {
            return Err(CardMindError::InvalidArgument(
                "dissolved pool cannot be modified".to_string(),
            ));
        }
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
    ///
    /// 加入码即数据池的 UUID 字符串。
    ///
    /// # 参数
    /// * `code` - 加入码（UUID 字符串）
    /// * `new_member` - 新成员信息
    /// * `local_card_ids` - 要共享的本地卡片 ID 列表
    ///
    /// # 返回
    /// 更新后的 [`Pool`] 实例
    ///
    /// # Errors
    /// - 当加入码格式无效时返回 [`CardMindError::InvalidArgument`]
    /// - 当数据池不存在时返回 [`CardMindError::NotFound`]
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
    ///
    /// 从数据池中移除指定端点的成员。
    ///
    /// # 参数
    /// * `pool_id` - 数据池 UUID
    /// * `endpoint_id` - 要离开的端点 ID
    ///
    /// # 返回
    /// 更新后的 [`Pool`] 实例
    ///
    /// # Errors
    /// - 当数据池不存在时返回 [`CardMindError::NotFound`]
    /// - 当持久化失败时返回相应的错误类型
    pub fn leave_pool(&self, pool_id: &Uuid, endpoint_id: &str) -> Result<Pool, CardMindError> {
        let mut pool = self.sqlite.get_pool(pool_id)?;

        if pool.is_dissolved {
            return Err(CardMindError::InvalidArgument(
                "dissolved pool cannot be modified".to_string(),
            ));
        }

        if let Some(leaving_member) = pool
            .members
            .iter()
            .find(|member| member.endpoint_id == endpoint_id)
            && leaving_member.is_admin
        {
            let remaining_admins = pool
                .members
                .iter()
                .filter(|member| member.endpoint_id != endpoint_id && member.is_admin)
                .count();

            if remaining_admins == 0 {
                return Err(CardMindError::InvalidArgument(
                    "last admin cannot leave pool".to_string(),
                ));
            }
        }

        pool.members
            .retain(|member| member.endpoint_id != endpoint_id);
        self.persist_pool(&pool)?;
        Ok(pool)
    }

    pub fn dissolve_pool(&self, pool_id: &Uuid, endpoint_id: &str) -> Result<Pool, CardMindError> {
        let mut pool = self.get_pool(pool_id)?;

        if pool.is_dissolved {
            return Err(CardMindError::InvalidArgument(
                "pool already dissolved".to_string(),
            ));
        }

        let acting_member = pool
            .members
            .iter()
            .find(|member| member.endpoint_id == endpoint_id)
            .ok_or_else(|| CardMindError::NotFound("member not found".to_string()))?;

        if !acting_member.is_admin {
            return Err(CardMindError::InvalidArgument(
                "only admin can dissolve pool".to_string(),
            ));
        }

        if pool.members.len() > 1 {
            return Err(CardMindError::InvalidArgument(
                "pool still has other members".to_string(),
            ));
        }

        pool.is_dissolved = true;
        self.persist_pool(&pool)?;
        Ok(pool)
    }

    pub fn submit_join_request(
        &self,
        pool_id: &Uuid,
        applicant: PoolMember,
    ) -> Result<Pool, CardMindError> {
        let mut pool = self.get_pool(pool_id)?;

        if pool.is_dissolved {
            return Err(CardMindError::InvalidArgument(
                "dissolved pool cannot be modified".to_string(),
            ));
        }

        if pool
            .members
            .iter()
            .any(|member| member.endpoint_id == applicant.endpoint_id)
        {
            return Err(CardMindError::InvalidArgument(
                "applicant is already a member".to_string(),
            ));
        }

        if pool.join_requests.iter().any(|request| {
            request.applicant.endpoint_id == applicant.endpoint_id
                && request.status == JoinRequestStatus::Pending
        }) {
            return Err(CardMindError::InvalidArgument(
                "duplicate pending join request".to_string(),
            ));
        }

        pool.join_requests.push(JoinRequest {
            request_id: new_uuid_v7(),
            applicant,
            status: JoinRequestStatus::Pending,
        });
        self.persist_pool(&pool)?;
        Ok(pool)
    }

    pub fn approve_join_request(
        &self,
        pool_id: &Uuid,
        request_id: &Uuid,
        approver_endpoint_id: &str,
    ) -> Result<Pool, CardMindError> {
        let mut pool = self.get_pool(pool_id)?;

        if pool.is_dissolved {
            return Err(CardMindError::InvalidArgument(
                "dissolved pool cannot be modified".to_string(),
            ));
        }

        let approver = pool
            .members
            .iter()
            .find(|member| member.endpoint_id == approver_endpoint_id)
            .ok_or_else(|| CardMindError::NotFound("member not found".to_string()))?;
        if !approver.is_admin {
            return Err(CardMindError::InvalidArgument(
                "only admin can approve join request".to_string(),
            ));
        }

        let request = pool
            .join_requests
            .iter_mut()
            .find(|request| request.request_id == *request_id)
            .ok_or_else(|| CardMindError::NotFound("join request not found".to_string()))?;

        if request.status != JoinRequestStatus::Pending {
            return Err(CardMindError::InvalidArgument(
                "join request is not pending".to_string(),
            ));
        }

        request.status = JoinRequestStatus::Approved;
        if !pool
            .members
            .iter()
            .any(|member| member.endpoint_id == request.applicant.endpoint_id)
        {
            pool.members.push(request.applicant.clone());
        }
        self.persist_pool(&pool)?;
        Ok(pool)
    }

    pub fn reject_join_request(
        &self,
        pool_id: &Uuid,
        request_id: &Uuid,
        approver_endpoint_id: &str,
    ) -> Result<Pool, CardMindError> {
        let mut pool = self.get_pool(pool_id)?;

        let approver = pool
            .members
            .iter()
            .find(|member| member.endpoint_id == approver_endpoint_id)
            .ok_or_else(|| CardMindError::NotFound("member not found".to_string()))?;
        if !approver.is_admin {
            return Err(CardMindError::InvalidArgument(
                "only admin can reject join request".to_string(),
            ));
        }

        let request = pool
            .join_requests
            .iter_mut()
            .find(|request| request.request_id == *request_id)
            .ok_or_else(|| CardMindError::NotFound("join request not found".to_string()))?;

        if request.status != JoinRequestStatus::Pending {
            return Err(CardMindError::InvalidArgument(
                "join request is not pending".to_string(),
            ));
        }

        request.status = JoinRequestStatus::Rejected;
        self.persist_pool(&pool)?;
        Ok(pool)
    }

    pub fn cancel_join_request(
        &self,
        pool_id: &Uuid,
        request_id: &Uuid,
        applicant_endpoint_id: &str,
    ) -> Result<Pool, CardMindError> {
        let mut pool = self.get_pool(pool_id)?;

        let request = pool
            .join_requests
            .iter_mut()
            .find(|request| request.request_id == *request_id)
            .ok_or_else(|| CardMindError::NotFound("join request not found".to_string()))?;

        if request.applicant.endpoint_id != applicant_endpoint_id {
            return Err(CardMindError::InvalidArgument(
                "only applicant can cancel join request".to_string(),
            ));
        }

        if request.status != JoinRequestStatus::Pending {
            return Err(CardMindError::InvalidArgument(
                "join request is not pending".to_string(),
            ));
        }

        request.status = JoinRequestStatus::Cancelled;
        self.persist_pool(&pool)?;
        Ok(pool)
    }

    /// 持久化数据池
    ///
    /// 内部方法：先写入 Loro，再投影到 SQLite。
    fn persist_pool(&self, pool: &Pool) -> Result<(), CardMindError> {
        self.write_pool_to_loro(pool)?;
        self.project_pool_to_sqlite(pool)?;
        Ok(())
    }

    /// 将数据池写入 Loro 文档
    ///
    /// 内部方法：序列化数据池到 Loro CRDT 格式。
    fn write_pool_to_loro(&self, pool: &Pool) -> Result<(), CardMindError> {
        let path = self.paths.base_path.join(pool_doc_path(&pool.pool_id));
        let doc = load_loro_doc(&path)?;
        let map = doc.get_map("pool");
        map.insert("pool_id", pool.pool_id.to_string())
            .map_err(|e| CardMindError::Loro(e.to_string()))?;
        map.insert("is_dissolved", pool.is_dissolved)
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

        let request_list = doc.get_list("join_requests");
        if !request_list.is_empty() {
            request_list
                .delete(0, request_list.len())
                .map_err(|e| CardMindError::Loro(e.to_string()))?;
        }
        for request in &pool.join_requests {
            let status = match request.status {
                JoinRequestStatus::Pending => "pending",
                JoinRequestStatus::Approved => "approved",
                JoinRequestStatus::Rejected => "rejected",
                JoinRequestStatus::Cancelled => "cancelled",
            };
            let values = vec![
                LoroValue::from(request.request_id.to_string()),
                LoroValue::from(request.applicant.endpoint_id.as_str()),
                LoroValue::from(request.applicant.nickname.as_str()),
                LoroValue::from(request.applicant.os.as_str()),
                LoroValue::from(request.applicant.is_admin),
                LoroValue::from(status),
            ];
            request_list
                .push(LoroValue::from(values))
                .map_err(|e| CardMindError::Loro(e.to_string()))?;
        }

        doc.commit();
        save_loro_doc(&path, &doc)
    }

    fn load_join_requests_from_loro(
        &self,
        pool_id: &Uuid,
    ) -> Result<Vec<JoinRequest>, CardMindError> {
        let path = self.paths.base_path.join(pool_doc_path(pool_id));
        let doc = load_loro_doc(&path)?;
        let requests_value = doc.get_list("join_requests").get_deep_value();
        parse_join_requests(requests_value)
    }

    /// 将数据池从 Loro 投影到 SQLite
    ///
    /// 内部方法：根据投影模式决定是否模拟失败。
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

    /// 检查数据池是否存在投影失败
    ///
    /// 内部方法：查询 projection_failures 表。
    fn projection_not_converged_for(
        &self,
        pool_id: &Uuid,
    ) -> Result<Option<CardMindError>, CardMindError> {
        Ok(self
            .sqlite
            .get_projection_retry_action(Self::POOL_ENTITY, &pool_id.to_string())?
            .map(|retry_action| Self::build_projection_error(*pool_id, retry_action)))
    }

    /// 构建投影错误
    ///
    /// 内部方法：创建标准化的投影失败错误。
    fn build_projection_error(pool_id: Uuid, retry_action: String) -> CardMindError {
        CardMindError::ProjectionNotConverged {
            entity: Self::POOL_ENTITY.to_string(),
            entity_id: pool_id.to_string(),
            retry_action,
        }
    }
}

/// 合并笔记引用
///
/// 将新的笔记 ID 合并到现有列表中，自动去重。
///
/// # 参数
/// * `existing` - 现有的笔记 ID 列表
/// * `incoming` - 要合并的新笔记 ID 列表
///
/// # 返回
/// 合并后的笔记 ID 列表（去重）
fn merge_note_references(existing: &[Uuid], incoming: Vec<Uuid>) -> Vec<Uuid> {
    let mut card_set: HashSet<Uuid> = existing.iter().cloned().collect();
    for card_id in incoming {
        card_set.insert(card_id);
    }
    card_set.into_iter().collect()
}

fn parse_join_requests(value: LoroValue) -> Result<Vec<JoinRequest>, CardMindError> {
    let list = match value {
        LoroValue::List(list) => list,
        LoroValue::Null => return Ok(Vec::new()),
        _ => {
            return Err(CardMindError::InvalidArgument(
                "join_requests invalid".to_string(),
            ));
        }
    };

    let mut requests = Vec::new();
    for item in list.iter() {
        let values = match item {
            LoroValue::List(values) => values,
            _ => {
                return Err(CardMindError::InvalidArgument(
                    "join_request invalid".to_string(),
                ));
            }
        };
        if values.len() != 6 {
            return Err(CardMindError::InvalidArgument(
                "join_request length invalid".to_string(),
            ));
        }

        let request_id = match &values[0] {
            LoroValue::String(text) => Uuid::parse_str(text).map_err(|_| {
                CardMindError::InvalidArgument("join_request id invalid".to_string())
            })?,
            _ => {
                return Err(CardMindError::InvalidArgument(
                    "join_request id invalid".to_string(),
                ));
            }
        };
        let endpoint_id = match &values[1] {
            LoroValue::String(text) => text.to_string(),
            _ => {
                return Err(CardMindError::InvalidArgument(
                    "join_request endpoint invalid".to_string(),
                ));
            }
        };
        let nickname = match &values[2] {
            LoroValue::String(text) => text.to_string(),
            _ => {
                return Err(CardMindError::InvalidArgument(
                    "join_request nickname invalid".to_string(),
                ));
            }
        };
        let os = match &values[3] {
            LoroValue::String(text) => text.to_string(),
            _ => {
                return Err(CardMindError::InvalidArgument(
                    "join_request os invalid".to_string(),
                ));
            }
        };
        let is_admin = match &values[4] {
            LoroValue::Bool(flag) => *flag,
            _ => {
                return Err(CardMindError::InvalidArgument(
                    "join_request admin invalid".to_string(),
                ));
            }
        };
        let status = match &values[5] {
            LoroValue::String(text) if text.to_string() == "pending" => JoinRequestStatus::Pending,
            LoroValue::String(text) if text.to_string() == "approved" => {
                JoinRequestStatus::Approved
            }
            LoroValue::String(text) if text.to_string() == "rejected" => {
                JoinRequestStatus::Rejected
            }
            LoroValue::String(text) if text.to_string() == "cancelled" => {
                JoinRequestStatus::Cancelled
            }
            _ => {
                return Err(CardMindError::InvalidArgument(
                    "join_request status invalid".to_string(),
                ));
            }
        };

        requests.push(JoinRequest {
            request_id,
            applicant: PoolMember {
                endpoint_id,
                nickname,
                os,
                is_admin,
            },
            status,
        });
    }

    Ok(requests)
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    /// 创建临时存储用于测试
    fn create_store() -> (PoolStore, TempDir) {
        let temp = TempDir::new().unwrap();
        let store = PoolStore::new(temp.path().to_str().unwrap()).unwrap();
        (store, temp)
    }

    /// 测试获取池时 SQLite 错误是否正确传播
    #[test]
    fn get_pool_propagates_sqlite_errors() {
        let (store, _temp) = create_store();
        let conn = rusqlite::Connection::open(&store.paths.sqlite_path).unwrap();
        conn.execute("DROP TABLE pools", []).unwrap();

        let result = store.get_pool(&Uuid::new_v4()).unwrap_err();

        match result {
            CardMindError::Sqlite(_) => {}
            other => panic!("unexpected error: {:?}", other),
        }
    }
}
