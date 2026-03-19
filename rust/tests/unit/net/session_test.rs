// input: SyncSession 和 PoolSession 的各种场景。
// output: 会话状态管理和成员验证的全覆盖测试。
// pos: 网络会话单元测试文件。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件测试同步会话和池会话管理。

use cardmind_rust::models::error::CardMindError;
use cardmind_rust::models::pool::PoolMember;
use cardmind_rust::net::session::{PoolSession, SyncSession};
use uuid::Uuid;

// ============================================================================
// SyncSession Tests
// ============================================================================

#[test]
fn sync_session_new_is_idle() {
    let session = SyncSession::new();

    assert_eq!(session.state(), "idle");
}

#[test]
fn sync_session_default_is_idle() {
    let session: SyncSession = Default::default();

    assert_eq!(session.state(), "idle");
}

#[test]
fn sync_session_connect_changes_state() {
    let mut session = SyncSession::new();

    session.connect("192.168.1.1:8080".to_string()).unwrap();

    assert_eq!(session.state(), "connected");
}

#[test]
fn sync_session_connect_empty_target_fails() {
    let mut session = SyncSession::new();

    let result = session.connect("".to_string());

    assert!(result.is_err());
    match result {
        Err(CardMindError::InvalidArgument(msg)) => {
            assert!(msg.contains("empty"));
        }
        _ => panic!("Expected InvalidArgument error"),
    }
}

#[test]
fn sync_session_connect_whitespace_only_fails() {
    let mut session = SyncSession::new();

    let result = session.connect("   ".to_string());

    assert!(result.is_err());
}

#[test]
fn sync_session_disconnect_changes_state() {
    let mut session = SyncSession::new();

    session.connect("target".to_string()).unwrap();
    assert_eq!(session.state(), "connected");

    session.disconnect();
    assert_eq!(session.state(), "idle");
}

#[test]
fn sync_session_multiple_connects() {
    let mut session = SyncSession::new();

    // 第一次连接
    session.connect("target1".to_string()).unwrap();
    assert_eq!(session.state(), "connected");

    // 第二次连接（覆盖）
    session.connect("target2".to_string()).unwrap();
    assert_eq!(session.state(), "connected");
}

#[test]
fn sync_session_disconnect_when_already_idle() {
    let mut session = SyncSession::new();

    // 断开空闲会话不应出错
    session.disconnect();
    assert_eq!(session.state(), "idle");
}

// ============================================================================
// PoolSession Tests
// ============================================================================

#[test]
fn pool_session_new_with_members() {
    let pool_id = Uuid::new_v4();
    let members = vec![
        PoolMember {
            endpoint_id: "ep1".to_string(),
            nickname: "User1".to_string(),
            os: "macOS".to_string(),
            is_admin: true,
        },
        PoolMember {
            endpoint_id: "ep2".to_string(),
            nickname: "User2".to_string(),
            os: "Windows".to_string(),
            is_admin: false,
        },
    ];

    let session = PoolSession::new(pool_id, &members);

    assert_eq!(session.pool_id(), &pool_id);
}

#[test]
fn pool_session_validate_peer_success() {
    let pool_id = Uuid::new_v4();
    let members = vec![PoolMember {
        endpoint_id: "ep1".to_string(),
        nickname: "User1".to_string(),
        os: "macOS".to_string(),
        is_admin: true,
    }];

    let session = PoolSession::new(pool_id, &members);

    let result = session.validate_peer("ep1");
    assert!(result.is_ok());
}

#[test]
fn pool_session_validate_peer_not_member() {
    let pool_id = Uuid::new_v4();
    let members = vec![PoolMember {
        endpoint_id: "ep1".to_string(),
        nickname: "User1".to_string(),
        os: "macOS".to_string(),
        is_admin: true,
    }];

    let session = PoolSession::new(pool_id, &members);

    let result = session.validate_peer("ep2");
    assert!(result.is_err());
    match result {
        Err(CardMindError::NotMember(_)) => {}
        _ => panic!("Expected NotMember error"),
    }
}

#[test]
fn pool_session_validate_peer_empty() {
    let pool_id = Uuid::new_v4();
    let members = vec![];

    let session = PoolSession::new(pool_id, &members);

    let result = session.validate_peer("ep1");
    assert!(result.is_err());
}

#[test]
fn pool_session_empty_members() {
    let pool_id = Uuid::new_v4();
    let session = PoolSession::new(pool_id, &[]);

    assert_eq!(session.pool_id(), &pool_id);
}

#[test]
fn pool_session_multiple_members_validation() {
    let pool_id = Uuid::new_v4();
    let members: Vec<PoolMember> = (0..10)
        .map(|i| PoolMember {
            endpoint_id: format!("ep{}", i),
            nickname: format!("User{}", i),
            os: "Linux".to_string(),
            is_admin: false,
        })
        .collect();

    let session = PoolSession::new(pool_id, &members);

    // 验证所有成员
    for i in 0..10 {
        assert!(session.validate_peer(&format!("ep{}", i)).is_ok());
    }

    // 验证非成员
    assert!(session.validate_peer("ep999").is_err());
}

#[test]
fn pool_session_member_case_sensitive() {
    let pool_id = Uuid::new_v4();
    let members = vec![PoolMember {
        endpoint_id: "EP1".to_string(),
        nickname: "User1".to_string(),
        os: "macOS".to_string(),
        is_admin: true,
    }];

    let session = PoolSession::new(pool_id, &members);

    // 大小写敏感
    assert!(session.validate_peer("EP1").is_ok());
    assert!(session.validate_peer("ep1").is_err());
    assert!(session.validate_peer("Ep1").is_err());
}
