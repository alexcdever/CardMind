// input: api/utils.rs 模块的纯函数。
// output: 错误映射、DTO 转换和辅助函数的单元测试。
// pos: api/utils 单元测试文件。修改本文件需同步更新所属 DIR.md。
// 中文注释: 本文件测试 api/utils 模块的纯函数。

use cardmind_rust::api::utils::*;
use cardmind_rust::models::api_error::ApiErrorCode;
use cardmind_rust::models::card::Card;
use cardmind_rust::models::error::CardMindError;
use cardmind_rust::models::pool::{Pool, PoolMember};

// ============================================================================
// map_err 测试
// ============================================================================

#[test]
fn test_map_err_invalid_argument() {
    let err = CardMindError::InvalidArgument("test error".to_string());
    let api_err = map_err(err);
    assert_eq!(api_err.code, ApiErrorCode::InvalidArgument.as_str());
    assert!(api_err.message.contains("test error"));
}

#[test]
fn test_map_err_not_found() {
    let err = CardMindError::NotFound("item not found".to_string());
    let api_err = map_err(err);
    assert_eq!(api_err.code, ApiErrorCode::NotFound.as_str());
}

#[test]
fn test_map_err_not_member() {
    let err = CardMindError::NotMember("not a member".to_string());
    let api_err = map_err(err);
    assert_eq!(api_err.code, ApiErrorCode::NotMember.as_str());
}

#[test]
fn test_map_err_io() {
    let err = CardMindError::Io("io failed".to_string());
    let api_err = map_err(err);
    assert_eq!(api_err.code, ApiErrorCode::IoError.as_str());
}

#[test]
fn test_map_err_sqlite() {
    let err = CardMindError::Sqlite("db error".to_string());
    let api_err = map_err(err);
    assert_eq!(api_err.code, ApiErrorCode::SqliteError.as_str());
}

#[test]
fn test_map_err_loro() {
    let err = CardMindError::Loro("loro error".to_string());
    let api_err = map_err(err);
    assert_eq!(api_err.code, ApiErrorCode::Internal.as_str());
    assert!(api_err.message.contains("loro:"));
}

#[test]
fn test_map_err_not_implemented() {
    let err = CardMindError::NotImplemented("not ready".to_string());
    let api_err = map_err(err);
    assert_eq!(api_err.code, ApiErrorCode::NotImplemented.as_str());
}

#[test]
fn test_map_err_projection_not_converged() {
    let err = CardMindError::ProjectionNotConverged {
        entity: "test".to_string(),
        entity_id: "123".to_string(),
        retry_action: "retry_later".to_string(),
    };
    let api_err = map_err(err);
    assert_eq!(api_err.code, ApiErrorCode::ProjectionNotConverged.as_str());
    assert_eq!(api_err.message, "retry_later");
}

#[test]
fn test_map_err_unknown_variant() {
    // 测试通配符分支
    let err = CardMindError::Internal("unknown".to_string());
    let api_err = map_err(err);
    assert_eq!(api_err.code, ApiErrorCode::Internal.as_str());
}

// ============================================================================
// parse_uuid 测试
// ============================================================================

#[test]
fn test_parse_uuid_valid() {
    let uuid_str = "550e8400-e29b-41d4-a716-446655440000";
    let result = parse_uuid(uuid_str, "test_id");
    assert!(result.is_ok());
    assert_eq!(result.unwrap().to_string(), uuid_str);
}

#[test]
fn test_parse_uuid_invalid_format() {
    let result = parse_uuid("not-a-uuid", "card_id");
    assert!(result.is_err());
    let err = result.unwrap_err();
    assert_eq!(err.code, ApiErrorCode::InvalidArgument.as_str());
    assert!(err.message.contains("invalid card_id"));
}

#[test]
fn test_parse_uuid_empty() {
    let result = parse_uuid("", "pool_id");
    assert!(result.is_err());
    assert!(result.unwrap_err().message.contains("invalid pool_id"));
}

#[test]
fn test_parse_uuid_nil() {
    let result = parse_uuid("00000000-0000-0000-0000-000000000000", "test");
    assert!(result.is_ok());
}

#[test]
fn test_parse_uuid_max() {
    let result = parse_uuid("ffffffff-ffff-ffff-ffff-ffffffffffff", "test");
    assert!(result.is_ok());
}

// ============================================================================
// pool_name 测试
// ============================================================================

#[test]
fn test_pool_name_with_first_member() {
    let pool = Pool {
        pool_id: uuid::Uuid::new_v4(),
        members: vec![PoolMember {
            endpoint_id: "ep1".to_string(),
            nickname: "Alice".to_string(),
            os: "macOS".to_string(),
            is_admin: true,
        }],
        card_ids: vec![],
    };

    assert_eq!(pool_name(&pool), "Alice's pool");
}

#[test]
fn test_pool_name_empty_members() {
    let pool = Pool {
        pool_id: uuid::Uuid::new_v4(),
        members: vec![],
        card_ids: vec![],
    };

    assert_eq!(pool_name(&pool), "pool");
}

#[test]
fn test_pool_name_unicode() {
    let pool = Pool {
        pool_id: uuid::Uuid::new_v4(),
        members: vec![PoolMember {
            endpoint_id: "ep1".to_string(),
            nickname: "张三".to_string(),
            os: "macOS".to_string(),
            is_admin: true,
        }],
        card_ids: vec![],
    };

    assert_eq!(pool_name(&pool), "张三's pool");
}

// ============================================================================
// member_role 测试
// ============================================================================

#[test]
fn test_member_role_admin() {
    let member = PoolMember {
        endpoint_id: "ep1".to_string(),
        nickname: "Admin".to_string(),
        os: "macOS".to_string(),
        is_admin: true,
    };

    assert_eq!(member_role(&member), "admin");
}

#[test]
fn test_member_role_member() {
    let member = PoolMember {
        endpoint_id: "ep1".to_string(),
        nickname: "Member".to_string(),
        os: "Windows".to_string(),
        is_admin: false,
    };

    assert_eq!(member_role(&member), "member");
}

// ============================================================================
// current_member_for_endpoint 测试
// ============================================================================

#[test]
fn test_current_member_for_endpoint_found() {
    let pool = Pool {
        pool_id: uuid::Uuid::new_v4(),
        members: vec![
            PoolMember {
                endpoint_id: "ep1".to_string(),
                nickname: "Admin".to_string(),
                os: "macOS".to_string(),
                is_admin: true,
            },
            PoolMember {
                endpoint_id: "ep2".to_string(),
                nickname: "Member".to_string(),
                os: "Windows".to_string(),
                is_admin: false,
            },
        ],
        card_ids: vec![],
    };

    let member = current_member_for_endpoint(&pool, "ep2");
    assert!(member.is_some());
    assert_eq!(member.unwrap().nickname, "Member");
}

#[test]
fn test_current_member_for_endpoint_not_found() {
    let pool = Pool {
        pool_id: uuid::Uuid::new_v4(),
        members: vec![PoolMember {
            endpoint_id: "ep1".to_string(),
            nickname: "Admin".to_string(),
            os: "macOS".to_string(),
            is_admin: true,
        }],
        card_ids: vec![],
    };

    let member = current_member_for_endpoint(&pool, "ep999");
    assert!(member.is_none());
}

#[test]
fn test_current_member_for_endpoint_empty_pool() {
    let pool = Pool {
        pool_id: uuid::Uuid::new_v4(),
        members: vec![],
        card_ids: vec![],
    };

    let member = current_member_for_endpoint(&pool, "ep1");
    assert!(member.is_none());
}

// ============================================================================
// current_member_role_for_endpoint 测试
// ============================================================================

#[test]
fn test_current_member_role_for_endpoint_success() {
    let pool = Pool {
        pool_id: uuid::Uuid::new_v4(),
        members: vec![PoolMember {
            endpoint_id: "ep1".to_string(),
            nickname: "Admin".to_string(),
            os: "macOS".to_string(),
            is_admin: true,
        }],
        card_ids: vec![],
    };

    let role = current_member_role_for_endpoint(&pool, "ep1");
    assert!(role.is_ok());
    assert_eq!(role.unwrap(), "admin");
}

#[test]
fn test_current_member_role_for_endpoint_not_member() {
    let pool = Pool {
        pool_id: uuid::Uuid::new_v4(),
        members: vec![PoolMember {
            endpoint_id: "ep1".to_string(),
            nickname: "Admin".to_string(),
            os: "macOS".to_string(),
            is_admin: true,
        }],
        card_ids: vec![],
    };

    let result = current_member_role_for_endpoint(&pool, "ep2");
    assert!(result.is_err());
    assert_eq!(result.unwrap_err().code, ApiErrorCode::NotMember.as_str());
}

// ============================================================================
// to_card_note_dto 测试
// ============================================================================

#[test]
fn test_to_card_note_dto() {
    let card = Card {
        id: uuid::Uuid::new_v4(),
        title: "Test Title".to_string(),
        content: "Test Content".to_string(),
        created_at: 1000,
        updated_at: 2000,
        deleted: false,
    };

    let dto = to_card_note_dto(&card);
    assert_eq!(dto.id, card.id.to_string());
    assert_eq!(dto.title, "Test Title");
    assert_eq!(dto.content, "Test Content");
    assert_eq!(dto.created_at, 1000);
    assert_eq!(dto.updated_at, 2000);
    assert!(!dto.deleted);
}

#[test]
fn test_to_card_note_dto_deleted() {
    let card = Card {
        id: uuid::Uuid::new_v4(),
        title: "Deleted".to_string(),
        content: "Content".to_string(),
        created_at: 1000,
        updated_at: 2000,
        deleted: true,
    };

    let dto = to_card_note_dto(&card);
    assert!(dto.deleted);
}

// ============================================================================
// to_pool_dto 测试
// ============================================================================

#[test]
fn test_to_pool_dto_success() {
    let pool = Pool {
        pool_id: uuid::Uuid::new_v4(),
        members: vec![PoolMember {
            endpoint_id: "ep1".to_string(),
            nickname: "Admin".to_string(),
            os: "macOS".to_string(),
            is_admin: true,
        }],
        card_ids: vec![],
    };

    let dto = to_pool_dto(&pool, "ep1").unwrap();
    assert_eq!(dto.id, pool.pool_id.to_string());
    assert_eq!(dto.name, "Admin's pool");
    assert_eq!(dto.current_user_role, "admin");
    assert_eq!(dto.member_count, 1);
    assert!(!dto.is_dissolved);
}

#[test]
fn test_to_pool_dto_not_member() {
    let pool = Pool {
        pool_id: uuid::Uuid::new_v4(),
        members: vec![PoolMember {
            endpoint_id: "ep1".to_string(),
            nickname: "Admin".to_string(),
            os: "macOS".to_string(),
            is_admin: true,
        }],
        card_ids: vec![],
    };

    let result = to_pool_dto(&pool, "ep2");
    assert!(result.is_err());
}

// ============================================================================
// to_pool_detail_dto 测试
// ============================================================================

#[test]
fn test_to_pool_detail_dto_success() {
    let pool = Pool {
        pool_id: uuid::Uuid::new_v4(),
        members: vec![
            PoolMember {
                endpoint_id: "ep1".to_string(),
                nickname: "Admin".to_string(),
                os: "macOS".to_string(),
                is_admin: true,
            },
            PoolMember {
                endpoint_id: "ep2".to_string(),
                nickname: "Member".to_string(),
                os: "Windows".to_string(),
                is_admin: false,
            },
        ],
        card_ids: vec![uuid::Uuid::new_v4(), uuid::Uuid::new_v4()],
    };

    let dto = to_pool_detail_dto(&pool, "ep1").unwrap();
    assert_eq!(dto.id, pool.pool_id.to_string());
    assert_eq!(dto.name, "Admin's pool");
    assert_eq!(dto.current_user_role, "admin");
    assert_eq!(dto.member_count, 2);
    assert_eq!(dto.note_ids.len(), 2);
    assert_eq!(dto.members.len(), 2);
    assert!(!dto.is_dissolved);
}

#[test]
fn test_to_pool_detail_dto_not_member() {
    let pool = Pool {
        pool_id: uuid::Uuid::new_v4(),
        members: vec![PoolMember {
            endpoint_id: "ep1".to_string(),
            nickname: "Admin".to_string(),
            os: "macOS".to_string(),
            is_admin: true,
        }],
        card_ids: vec![],
    };

    let result = to_pool_detail_dto(&pool, "ep2");
    assert!(result.is_err());
}
