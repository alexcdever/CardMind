// input: 来自 api.rs 的纯函数，用于错误映射、DTO 转换和辅助逻辑。
// output: 可独立测试的纯函数集合。
// pos: api/utils.rs - API 纯函数工具模块。修改本文件需同步更新所属 DIR.md。
// 中文注释: 本文件包含 api.rs 中的纯函数，便于单元测试。

use crate::models::api_error::{ApiError, ApiErrorCode};
use crate::models::card::Card;
use crate::models::pool::{Pool, PoolMember};
use uuid::Uuid;

/// 将 CardMindError 映射为 ApiError
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
        CardMindError::Loro(msg) => {
            ApiError::new(ApiErrorCode::Internal, &format!("loro: {}", msg))
        }
        _ => ApiError::new(ApiErrorCode::Internal, "internal error"),
    }
}

/// 解析 UUID 字符串
pub fn parse_uuid(raw: &str, field: &str) -> Result<Uuid, ApiError> {
    Uuid::parse_str(raw)
        .map_err(|_| ApiError::new(ApiErrorCode::InvalidArgument, &format!("invalid {}", field)))
}

/// 根据 pool 成员生成 pool 名称
pub fn pool_name(pool: &Pool) -> String {
    pool.members
        .first()
        .map(|member| format!("{}'s pool", member.nickname))
        .unwrap_or_else(|| "pool".to_string())
}

/// 根据成员角色返回角色字符串
pub fn member_role(member: &PoolMember) -> String {
    if member.is_admin {
        "admin".to_string()
    } else {
        "member".to_string()
    }
}

/// 在 pool 中查找指定 endpoint_id 的成员
pub fn current_member_for_endpoint<'a>(
    pool: &'a Pool,
    endpoint_id: &str,
) -> Option<&'a PoolMember> {
    pool.members
        .iter()
        .find(|member| member.endpoint_id == endpoint_id)
}

/// 获取指定 endpoint_id 在当前 pool 中的角色
pub fn current_member_role_for_endpoint(
    pool: &Pool,
    endpoint_id: &str,
) -> Result<String, ApiError> {
    current_member_for_endpoint(pool, endpoint_id)
        .map(member_role)
        .ok_or_else(|| ApiError::new(ApiErrorCode::NotMember, "caller is not a pool member"))
}

/// 将 Card 转换为 CardNoteDto
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

/// 将 Pool 转换为 PoolDto
pub fn to_pool_dto(pool: &Pool, endpoint_id: &str) -> Result<crate::api::PoolDto, ApiError> {
    Ok(crate::api::PoolDto {
        id: pool.pool_id.to_string(),
        name: pool_name(pool),
        is_dissolved: false,
        current_user_role: current_member_role_for_endpoint(pool, endpoint_id)?,
        member_count: pool.members.len(),
    })
}

/// 将 Pool 转换为 PoolDetailDto
pub fn to_pool_detail_dto(
    pool: &Pool,
    endpoint_id: &str,
) -> Result<crate::api::PoolDetailDto, ApiError> {
    Ok(crate::api::PoolDetailDto {
        id: pool.pool_id.to_string(),
        name: pool_name(pool),
        is_dissolved: false,
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
    })
}
