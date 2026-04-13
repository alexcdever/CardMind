//! # API 工具模块
//!
//! 提供 API 层的纯函数工具，包括错误映射、DTO 转换和辅助逻辑。
//!
//! ## 设计目标
//! - 将 `api.rs` 中的纯函数提取到独立模块，便于单元测试
//! - 所有函数无副作用，可独立测试
//!
//! ## 主要功能
//! - 错误类型转换（`CardMindError` → `ApiError`）
//! - UUID 字符串解析与验证
//! - Pool 相关辅助函数（名称生成、角色判断、成员查找）
//! - DTO 转换（Card/Pool → DTO）

use crate::models::api_error::{ApiError, ApiErrorCode};
use crate::models::card::Card;
use crate::models::pool::{JoinRequestStatus, Pool, PoolMember};
use uuid::Uuid;

/// 将 `CardMindError` 映射为 `ApiError`。
///
/// 根据错误类型转换为对应的 API 错误码，便于前端统一处理。
///
/// # 参数
/// * `err` - 内部错误类型。
///
/// # 返回
/// 对应的 `ApiError` 实例。
///
/// # 错误映射规则
/// - `InvalidArgument` → `InvalidArgument`
/// - `NotFound` → `NotFound`
/// - `ProjectionNotConverged` → `ProjectionNotConverged`
/// - `NotImplemented` → `NotImplemented`
/// - `NotMember` → `NotMember`
/// - `Io` → `IoError`
/// - `Loro` → `Internal`（带前缀信息）
/// - 其他 → `Internal`
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::models::error::CardMindError;
/// use cardmind_rust::api::utils::map_err;
///
/// let err = CardMindError::NotFound("card not found".to_string());
/// let api_err = map_err(err);
/// assert_eq!(api_err.code, "not_found");
/// ```
pub fn map_err(err: crate::models::error::CardMindError) -> ApiError {
    use crate::models::error::CardMindError;
    match err {
        CardMindError::InvalidArgument(msg) => ApiError::new(ApiErrorCode::InvalidArgument, &msg),
        CardMindError::NotFound(msg) => ApiError::new(ApiErrorCode::NotFound, &msg),
        CardMindError::ProjectionNotConverged { retry_action, .. } => {
            ApiError::new(ApiErrorCode::ProjectionNotConverged, &retry_action)
        }
        CardMindError::NotImplemented(msg) => ApiError::new(ApiErrorCode::NotImplemented, &msg),
        CardMindError::NotMember(msg) => ApiError::new(ApiErrorCode::NotMember, &msg),
        CardMindError::Io(msg) => ApiError::new(ApiErrorCode::IoError, &msg),
        CardMindError::Sqlite(msg) => ApiError::new(ApiErrorCode::SqliteError, &msg),
        CardMindError::Internal(msg) => ApiError::new(ApiErrorCode::Internal, &msg),
        CardMindError::Loro(msg) => {
            ApiError::new(ApiErrorCode::Internal, &format!("loro: {}", msg))
        }
    }
}

/// 解析 UUID 字符串。
///
/// 将字符串解析为 `Uuid` 类型，失败时返回格式化的错误信息。
///
/// # 参数
/// * `raw` - UUID 字符串。
/// * `field` - 字段名称，用于错误信息。
///
/// # 返回
/// - `Ok(Uuid)` - 解析成功。
/// - `Err(ApiError)` - 解析失败，`code` 为 `invalid_argument`。
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::api::utils::parse_uuid;
///
/// let uuid_str = "550e8400-e29b-41d4-a716-446655440000";
/// let result = parse_uuid(uuid_str, "card_id");
/// assert!(result.is_ok());
///
/// let bad_uuid = parse_uuid("not-a-uuid", "card_id");
/// assert!(bad_uuid.is_err());
/// ```
pub fn parse_uuid(raw: &str, field: &str) -> Result<Uuid, ApiError> {
    Uuid::parse_str(raw)
        .map_err(|_| ApiError::new(ApiErrorCode::InvalidArgument, &format!("invalid {}", field)))
}

/// 根据 Pool 成员生成 Pool 名称。
///
/// 使用第一个成员的昵称生成人性化名称，如无成员则返回默认名称。
///
/// # 参数
/// * `pool` - Pool 实例。
///
/// # 返回
/// Pool 的显示名称。
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::models::pool::{Pool, PoolMember};
/// use cardmind_rust::api::utils::pool_name;
///
/// // 示例用法
/// // let pool = Pool { ... };
/// // let name = pool_name(&pool);
/// ```
pub fn pool_name(pool: &Pool) -> String {
    pool.members
        .first()
        .map(|member| format!("{}'s pool", member.nickname))
        .unwrap_or_else(|| "pool".to_string())
}

/// 根据成员角色返回角色字符串。
///
/// # 参数
/// * `member` - Pool 成员实例。
///
/// # 返回
/// - `"admin"` - 管理员角色。
/// - `"member"` - 普通成员角色。
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::models::pool::PoolMember;
/// use cardmind_rust::api::utils::member_role;
///
/// let admin = PoolMember {
///     endpoint_id: "ep1".to_string(),
///     nickname: "Alice".to_string(),
///     os: "macOS".to_string(),
///     is_admin: true,
/// };
/// assert_eq!(member_role(&admin), "admin");
/// ```
pub fn member_role(member: &PoolMember) -> String {
    if member.is_admin {
        "admin".to_string()
    } else {
        "member".to_string()
    }
}

/// 在 Pool 中查找指定 `endpoint_id` 的成员。
///
/// # 参数
/// * `pool` - Pool 实例。
/// * `endpoint_id` - 端点标识符。
///
/// # 返回
/// - `Some(&PoolMember)` - 找到成员。
/// - `None` - 未找到成员。
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::models::pool::{Pool, PoolMember};
/// use cardmind_rust::api::utils::current_member_for_endpoint;
///
/// // let pool = Pool { ... };
/// // let member = current_member_for_endpoint(&pool, "ep1");
/// ```
pub fn current_member_for_endpoint<'a>(
    pool: &'a Pool,
    endpoint_id: &str,
) -> Option<&'a PoolMember> {
    pool.members
        .iter()
        .find(|member| member.endpoint_id == endpoint_id)
}

/// 获取指定 `endpoint_id` 在当前 Pool 中的角色。
///
/// 如果端点不是 Pool 成员，返回错误。
///
/// # 参数
/// * `pool` - Pool 实例。
/// * `endpoint_id` - 端点标识符。
///
/// # 返回
/// - `Ok(String)` - 角色字符串（"admin" 或 "member"）。
/// - `Err(ApiError)` - 端点不是成员，`code` 为 `not_member`。
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::models::pool::Pool;
/// use cardmind_rust::api::utils::current_member_role_for_endpoint;
///
/// // let pool = Pool { ... };
/// // match current_member_role_for_endpoint(&pool, "ep1") {
/// //     Ok(role) => println!("Role: {}", role),
/// //     Err(e) => println!("Not a member: {}", e.message),
/// // }
/// ```
pub fn current_member_role_for_endpoint(
    pool: &Pool,
    endpoint_id: &str,
) -> Result<String, ApiError> {
    current_member_for_endpoint(pool, endpoint_id)
        .map(member_role)
        .ok_or_else(|| ApiError::new(ApiErrorCode::NotMember, "caller is not a pool member"))
}

/// 将 `Card` 转换为 `CardNoteDto`。
///
/// 用于 API 响应中的卡片数据序列化。
///
/// # 参数
/// * `card` - 卡片实例。
///
/// # 返回
/// `CardNoteDto` 实例，包含卡片的所有可序列化字段。
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::models::card::Card;
/// use cardmind_rust::api::utils::to_card_note_dto;
///
/// // let card = Card { ... };
/// // let dto = to_card_note_dto(&card);
/// ```
pub fn to_card_note_dto(card: &Card) -> crate::api::CardNoteDto {
    crate::api::CardNoteDto {
        id: card.id.to_string(),
        title: card.title.clone(),
        content: card.content.clone(),
        created_at: card.created_at,
        updated_at: card.updated_at,
        deleted: card.deleted,
    }
}

/// 将 `Pool` 转换为 `PoolDto`。
///
/// 用于 API 响应中的 Pool 列表展示。
///
/// # 参数
/// * `pool` - Pool 实例。
/// * `endpoint_id` - 当前用户端点 ID，用于确定用户角色。
///
/// # 返回
/// - `Ok(PoolDto)` - 转换成功。
/// - `Err(ApiError)` - 用户不是 Pool 成员。
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::models::pool::Pool;
/// use cardmind_rust::api::utils::to_pool_dto;
///
/// // let pool = Pool { ... };
/// // let dto = to_pool_dto(&pool, "current_endpoint_id")?;
/// ```
pub fn to_pool_dto(pool: &Pool, endpoint_id: &str) -> Result<crate::api::PoolDto, ApiError> {
    Ok(crate::api::PoolDto {
        id: pool.pool_id.to_string(),
        name: pool_name(pool),
        is_dissolved: pool.is_dissolved,
        current_user_role: current_member_role_for_endpoint(pool, endpoint_id)?,
        member_count: pool.members.len(),
    })
}

/// 将 `Pool` 转换为 `PoolDetailDto`。
///
/// 用于 API 响应中的 Pool 详情展示，包含完整成员列表和卡片 ID。
///
/// # 参数
/// * `pool` - Pool 实例。
/// * `endpoint_id` - 当前用户端点 ID，用于确定用户角色。
///
/// # 返回
/// - `Ok(PoolDetailDto)` - 转换成功。
/// - `Err(ApiError)` - 用户不是 Pool 成员。
///
/// # Examples
/// ```rust,ignore
/// use cardmind_rust::models::pool::Pool;
/// use cardmind_rust::api::utils::to_pool_detail_dto;
///
/// // let pool = Pool { ... };
/// // let dto = to_pool_detail_dto(&pool, "current_endpoint_id")?;
/// ```
pub fn to_pool_detail_dto(
    pool: &Pool,
    endpoint_id: &str,
) -> Result<crate::api::PoolDetailDto, ApiError> {
    Ok(crate::api::PoolDetailDto {
        id: pool.pool_id.to_string(),
        name: pool_name(pool),
        is_dissolved: pool.is_dissolved,
        current_user_role: current_member_role_for_endpoint(pool, endpoint_id)?,
        member_count: pool.members.len(),
        note_ids: pool.card_ids.iter().map(Uuid::to_string).collect(),
        members: pool
            .members
            .iter()
            .map(|member| crate::api::PoolMemberDto {
                endpoint_id: member.endpoint_id.clone(),
                nickname: member.nickname.clone(),
                os: member.os.clone(),
                role: member_role(member),
            })
            .collect(),
        join_requests: pool
            .join_requests
            .iter()
            .map(|request| crate::api::JoinRequestDto {
                request_id: request.request_id.to_string(),
                applicant_endpoint_id: request.applicant.endpoint_id.clone(),
                applicant_nickname: request.applicant.nickname.clone(),
                applicant_os: request.applicant.os.clone(),
                status: match request.status {
                    JoinRequestStatus::Pending => "pending".to_string(),
                    JoinRequestStatus::Approved => "approved".to_string(),
                    JoinRequestStatus::Rejected => "rejected".to_string(),
                    JoinRequestStatus::Cancelled => "cancelled".to_string(),
                },
            })
            .collect(),
    })
}
