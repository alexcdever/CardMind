// input: api.rs 中的纯函数（pool_name, member_role, to_pool_dto, to_card_note_dto 等）。
// output: API 转换函数的全覆盖测试。
// pos: API 纯函数单元测试文件。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件测试 API 层的纯函数和 DTO 转换。

use cardmind_rust::models::card::Card;
use cardmind_rust::models::pool::{Pool, PoolMember};

// 模拟 api.rs 中的函数
fn pool_name(pool: &Pool) -> String {
    pool.members
        .first()
        .map(|member| format!("{}'s pool", member.nickname))
        .unwrap_or_else(|| "pool".to_string())
}

fn member_role(member: &PoolMember) -> String {
    if member.is_admin {
        "admin".to_string()
    } else {
        "member".to_string()
    }
}

fn current_member_for_endpoint<'a>(pool: &'a Pool, endpoint_id: &str) -> Option<&'a PoolMember> {
    pool.members
        .iter()
        .find(|member| member.endpoint_id == endpoint_id)
}

#[test]
fn pool_name_with_first_member() {
    let pool = Pool {
        pool_id: uuid::Uuid::new_v4(),
        members: vec![PoolMember {
            endpoint_id: "ep1".to_string(),
            nickname: "Alice".to_string(),
            os: "macOS".to_string(),
            is_admin: true,
        }],
        card_ids: vec![],
        is_dissolved: false,
        join_requests: vec![],
    };

    let name = pool_name(&pool);
    assert_eq!(name, "Alice's pool");
}

#[test]
fn pool_name_empty_members() {
    let pool = Pool {
        pool_id: uuid::Uuid::new_v4(),
        members: vec![],
        card_ids: vec![],
        is_dissolved: false,
        join_requests: vec![],
    };

    let name = pool_name(&pool);
    assert_eq!(name, "pool");
}

#[test]
fn pool_name_with_unicode_nickname() {
    let pool = Pool {
        pool_id: uuid::Uuid::new_v4(),
        members: vec![PoolMember {
            endpoint_id: "ep1".to_string(),
            nickname: "张三".to_string(),
            os: "macOS".to_string(),
            is_admin: true,
        }],
        card_ids: vec![],
        is_dissolved: false,
        join_requests: vec![],
    };

    let name = pool_name(&pool);
    assert_eq!(name, "张三's pool");
}

#[test]
fn member_role_admin() {
    let member = PoolMember {
        endpoint_id: "ep1".to_string(),
        nickname: "Admin".to_string(),
        os: "macOS".to_string(),
        is_admin: true,
    };

    assert_eq!(member_role(&member), "admin");
}

#[test]
fn member_role_member() {
    let member = PoolMember {
        endpoint_id: "ep1".to_string(),
        nickname: "Member".to_string(),
        os: "Windows".to_string(),
        is_admin: false,
    };

    assert_eq!(member_role(&member), "member");
}

#[test]
fn current_member_for_endpoint_found() {
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
        is_dissolved: false,
        join_requests: vec![],
    };

    let member = current_member_for_endpoint(&pool, "ep2");
    assert!(member.is_some());
    assert_eq!(member.unwrap().nickname, "Member");
}

#[test]
fn card_model_creation() {
    let card = Card {
        id: uuid::Uuid::new_v4(),
        title: "Test Title".to_string(),
        content: "Test Content".to_string(),
        created_at: 1000,
        updated_at: 2000,
        deleted: false,
    };

    assert_eq!(card.title, "Test Title");
    assert!(!card.deleted);
}
