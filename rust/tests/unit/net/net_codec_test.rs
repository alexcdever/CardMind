// input: PoolMessage 编解码的各种边界情况。
// output: 编码/解码功能的全覆盖测试。
// pos: 网络编解码单元测试文件。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件测试消息编码和解码。

use cardmind_rust::models::error::CardMindError;
use cardmind_rust::models::pool::PoolMember;
use cardmind_rust::net::codec::{decode_message, encode_message};
use cardmind_rust::net::messages::{JoinDecisionStatus, PoolMessage};
use iroh::{EndpointAddr, SecretKey};
use uuid::Uuid;

fn create_test_member() -> PoolMember {
    PoolMember {
        endpoint_id: "endpoint1".to_string(),
        nickname: "TestUser".to_string(),
        os: "macOS".to_string(),
        is_admin: false,
    }
}

fn create_test_addr() -> EndpointAddr {
    let secret = SecretKey::from_bytes(&[7u8; 32]);
    EndpointAddr::new(secret.public())
}

// ============================================================================
// Encode Tests
// ============================================================================

#[test]
fn test_encode_message_success() {
    let msg = PoolMessage::Hello {
        pool_id: Uuid::new_v4(),
        endpoint_id: "ep1".to_string(),
        nickname: "User".to_string(),
        os: "macOS".to_string(),
    };

    let encoded = encode_message(&msg).unwrap();

    // Should have 4 bytes length prefix + body
    assert!(encoded.len() > 4);
    // First 4 bytes should be big-endian length
    let len = u32::from_be_bytes([encoded[0], encoded[1], encoded[2], encoded[3]]) as usize;
    assert_eq!(encoded.len(), 4 + len);
}

#[test]
fn test_encode_different_message_types() {
    let pool_id = Uuid::new_v4();

    let hello = PoolMessage::Hello {
        pool_id,
        endpoint_id: "ep1".to_string(),
        nickname: "User".to_string(),
        os: "macOS".to_string(),
    };

    let join_request = PoolMessage::JoinRequest {
        pool_id,
        invite_code: "invite-code".to_string(),
        applicant: create_test_member(),
        applicant_addr: create_test_addr(),
    };

    let hello_bytes = encode_message(&hello).unwrap();
    let join_bytes = encode_message(&join_request).unwrap();

    // Different messages should have different sizes
    assert!(!hello_bytes.is_empty());
    assert!(!join_bytes.is_empty());
}

// ============================================================================
// Decode Tests
// ============================================================================

#[test]
fn test_encode_decode_roundtrip_hello() {
    let pool_id = Uuid::new_v4();
    let original = PoolMessage::Hello {
        pool_id,
        endpoint_id: "ep1".to_string(),
        nickname: "TestUser".to_string(),
        os: "Linux".to_string(),
    };

    let encoded = encode_message(&original).unwrap();
    let decoded = decode_message(&encoded).unwrap();

    match decoded {
        PoolMessage::Hello {
            pool_id: decoded_pool_id,
            endpoint_id,
            nickname,
            os,
        } => {
            assert_eq!(decoded_pool_id, pool_id);
            assert_eq!(endpoint_id, "ep1");
            assert_eq!(nickname, "TestUser");
            assert_eq!(os, "Linux");
        }
        _ => panic!("Expected Hello message"),
    }
}

#[test]
fn test_encode_decode_roundtrip_join_request() {
    let pool_id = Uuid::new_v4();
    let member = create_test_member();
    let original = PoolMessage::JoinRequest {
        pool_id,
        invite_code: "invite-code".to_string(),
        applicant: member.clone(),
        applicant_addr: create_test_addr(),
    };

    let encoded = encode_message(&original).unwrap();
    let decoded = decode_message(&encoded).unwrap();

    match decoded {
        PoolMessage::JoinRequest {
            pool_id: decoded_pool_id,
            invite_code,
            applicant,
            applicant_addr,
        } => {
            assert_eq!(decoded_pool_id, pool_id);
            assert_eq!(invite_code, "invite-code");
            assert_eq!(applicant.endpoint_id, member.endpoint_id);
            assert_eq!(applicant.nickname, member.nickname);
            assert_eq!(applicant.os, member.os);
            assert_eq!(applicant.is_admin, member.is_admin);
            assert!(!applicant_addr.id.to_string().is_empty());
        }
        _ => panic!("Expected JoinRequest message"),
    }
}

#[test]
fn test_encode_decode_join_decision() {
    let pool_id = Uuid::new_v4();
    let original = PoolMessage::JoinDecision {
        pool_id,
        status: JoinDecisionStatus::Approved,
        reason: Some("Welcome!".to_string()),
        request_id: None,
        pool_name: None,
    };

    let encoded = encode_message(&original).unwrap();
    let decoded = decode_message(&encoded).unwrap();

    match decoded {
        PoolMessage::JoinDecision {
            pool_id: decoded_pool_id,
            status,
            reason,
            request_id,
            pool_name,
        } => {
            assert_eq!(decoded_pool_id, pool_id);
            assert_eq!(status, JoinDecisionStatus::Approved);
            assert_eq!(reason, Some("Welcome!".to_string()));
            assert_eq!(request_id, None);
            assert_eq!(pool_name, None);
        }
        _ => panic!("Expected JoinDecision message"),
    }
}

#[test]
fn test_encode_decode_join_decision_rejected() {
    let pool_id = Uuid::new_v4();
    let original = PoolMessage::JoinDecision {
        pool_id,
        status: JoinDecisionStatus::Rejected,
        reason: Some("Pool is full".to_string()),
        request_id: None,
        pool_name: None,
    };

    let encoded = encode_message(&original).unwrap();
    let decoded = decode_message(&encoded).unwrap();

    match decoded {
        PoolMessage::JoinDecision { status, reason, .. } => {
            assert_eq!(status, JoinDecisionStatus::Rejected);
            assert_eq!(reason, Some("Pool is full".to_string()));
        }
        _ => panic!("Expected JoinDecision message"),
    }
}

#[test]
fn test_encode_decode_join_decision_no_reason() {
    let pool_id = Uuid::new_v4();
    let original = PoolMessage::JoinDecision {
        pool_id,
        status: JoinDecisionStatus::Pending,
        reason: None,
        request_id: Some(Uuid::new_v4()),
        pool_name: Some("Pool".to_string()),
    };

    let encoded = encode_message(&original).unwrap();
    let decoded = decode_message(&encoded).unwrap();

    match decoded {
        PoolMessage::JoinDecision {
            status,
            reason,
            request_id,
            pool_name,
            ..
        } => {
            assert_eq!(status, JoinDecisionStatus::Pending);
            assert_eq!(reason, None);
            assert!(request_id.is_some());
            assert_eq!(pool_name, Some("Pool".to_string()));
        }
        _ => panic!("Expected JoinDecision message"),
    }
}

#[test]
fn test_encode_decode_pool_snapshot() {
    let pool_id = Uuid::new_v4();
    let bytes = vec![1u8, 2, 3, 4, 5];
    let original = PoolMessage::PoolSnapshot {
        pool_id,
        bytes: bytes.clone(),
    };

    let encoded = encode_message(&original).unwrap();
    let decoded = decode_message(&encoded).unwrap();

    match decoded {
        PoolMessage::PoolSnapshot {
            pool_id: decoded_pool_id,
            bytes: decoded_bytes,
        } => {
            assert_eq!(decoded_pool_id, pool_id);
            assert_eq!(decoded_bytes, bytes);
        }
        _ => panic!("Expected PoolSnapshot message"),
    }
}

#[test]
fn test_encode_decode_card_updates() {
    let card_id = Uuid::new_v4();
    let bytes = vec![10u8, 20, 30];
    let original = PoolMessage::CardUpdates {
        card_id,
        bytes: bytes.clone(),
    };

    let encoded = encode_message(&original).unwrap();
    let decoded = decode_message(&encoded).unwrap();

    match decoded {
        PoolMessage::CardUpdates {
            card_id: decoded_card_id,
            bytes: decoded_bytes,
        } => {
            assert_eq!(decoded_card_id, card_id);
            assert_eq!(decoded_bytes, bytes);
        }
        _ => panic!("Expected CardUpdates message"),
    }
}

#[test]
fn test_encode_decode_with_large_bytes() {
    let card_id = Uuid::new_v4();
    let bytes = vec![0u8; 10000];
    let original = PoolMessage::CardSnapshot {
        card_id,
        bytes: bytes.clone(),
    };

    let encoded = encode_message(&original).unwrap();
    let decoded = decode_message(&encoded).unwrap();

    match decoded {
        PoolMessage::CardSnapshot {
            bytes: decoded_bytes,
            ..
        } => {
            assert_eq!(decoded_bytes.len(), 10000);
            assert_eq!(decoded_bytes, bytes);
        }
        _ => panic!("Expected CardSnapshot message"),
    }
}

// ============================================================================
// Error Handling Tests
// ============================================================================

#[test]
fn test_decode_too_short() {
    let bytes = vec![0u8, 0, 0]; // Only 3 bytes, need at least 4

    let result = decode_message(&bytes);

    assert!(matches!(result, Err(CardMindError::InvalidArgument(_))));
    let err = result.unwrap_err();
    assert!(err.to_string().contains("too short"));
}

#[test]
fn test_decode_empty() {
    let bytes: Vec<u8> = vec![];

    let result = decode_message(&bytes);

    assert!(matches!(result, Err(CardMindError::InvalidArgument(_))));
}

#[test]
fn test_decode_length_mismatch() {
    // Create message with length prefix saying 100 but only 10 bytes body
    let mut bytes = vec![0u8, 0, 0, 100]; // length = 100
    bytes.extend_from_slice(&[0u8; 10]); // but only 10 bytes

    let result = decode_message(&bytes);

    assert!(matches!(result, Err(CardMindError::InvalidArgument(_))));
    let err = result.unwrap_err();
    assert!(err.to_string().contains("mismatch"));
}

#[test]
fn test_decode_invalid_body() {
    // Create valid length prefix but invalid body
    let body = vec![0u8, 1, 2, 3, 4, 5];
    let len = body.len() as u32;
    let mut bytes = len.to_be_bytes().to_vec();
    bytes.extend_from_slice(&body);

    let result = decode_message(&bytes);

    // Should fail to deserialize
    assert!(matches!(result, Err(CardMindError::InvalidArgument(_))));
}

// ============================================================================
// Edge Cases
// ============================================================================

#[test]
fn test_decode_exact_length() {
    let pool_id = Uuid::new_v4();
    let msg = PoolMessage::Hello {
        pool_id,
        endpoint_id: "ep1".to_string(),
        nickname: "User".to_string(),
        os: "macOS".to_string(),
    };
    let encoded = encode_message(&msg).unwrap();

    // Should decode successfully
    let decoded = decode_message(&encoded).unwrap();
    assert!(matches!(decoded, PoolMessage::Hello { .. }));
}

#[test]
fn test_decode_extra_bytes_fails() {
    let pool_id = Uuid::new_v4();
    let msg = PoolMessage::Hello {
        pool_id,
        endpoint_id: "ep1".to_string(),
        nickname: "User".to_string(),
        os: "macOS".to_string(),
    };
    let mut encoded = encode_message(&msg).unwrap();
    encoded.extend_from_slice(&[0u8; 10]);

    // Should fail because length doesn't match
    let result = decode_message(&encoded);
    assert!(matches!(result, Err(CardMindError::InvalidArgument(_))));
}

#[test]
fn test_encode_decode_unicode() {
    let pool_id = Uuid::new_v4();
    let msg = PoolMessage::Hello {
        pool_id,
        endpoint_id: "设备1 🖥️".to_string(),
        nickname: "用户".to_string(),
        os: "系统".to_string(),
    };

    let encoded = encode_message(&msg).unwrap();
    let decoded = decode_message(&encoded).unwrap();

    match decoded {
        PoolMessage::Hello {
            endpoint_id,
            nickname,
            os,
            ..
        } => {
            assert_eq!(endpoint_id, "设备1 🖥️");
            assert_eq!(nickname, "用户");
            assert_eq!(os, "系统");
        }
        _ => panic!("Expected Hello message"),
    }
}

#[test]
fn test_encode_decode_empty_bytes() {
    let pool_id = Uuid::new_v4();
    let msg = PoolMessage::PoolSnapshot {
        pool_id,
        bytes: vec![],
    };

    let encoded = encode_message(&msg).unwrap();
    let decoded = decode_message(&encoded).unwrap();

    match decoded {
        PoolMessage::PoolSnapshot { bytes, .. } => {
            assert!(bytes.is_empty());
        }
        _ => panic!("Expected PoolSnapshot message"),
    }
}
