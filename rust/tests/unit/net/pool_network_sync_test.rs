// input: PoolNetwork 结构体的同步状态管理功能。
// output: sync_state、sync_join_pool、sync_push、sync_pull 等方法的单元测试。
// pos: pool_network 结构体方法测试文件。修改本文件需同步更新所属 DIR.md。
// 中文注释: 本文件测试 PoolNetwork 的同步状态管理功能。

use cardmind_rust::models::error::CardMindError;
use cardmind_rust::models::pool::{Pool, PoolMember};
use cardmind_rust::net::endpoint::build_test_endpoints;
use cardmind_rust::net::pool_network::PoolNetwork;
use cardmind_rust::store::card_store::CardNoteRepository;
use cardmind_rust::store::pool_store::PoolStore;
use tempfile::TempDir;
use tokio::time::{Duration, sleep};

// ==================== 辅助函数 ====================

async fn create_test_pool_network() -> (PoolNetwork, TempDir) {
    let temp_dir = TempDir::new().unwrap();
    let base_path = temp_dir.path().to_str().unwrap();

    // 创建 store
    let pool_store = PoolStore::new(base_path).unwrap();
    let card_repo = CardNoteRepository::new(base_path).unwrap();

    // 创建 endpoint
    let (endpoint, _) = build_test_endpoints().await.unwrap();

    let network = PoolNetwork::new(endpoint, pool_store, card_repo);
    (network, temp_dir)
}

fn create_network_with_endpoint(
    base_path: &str,
    endpoint: cardmind_rust::net::endpoint::PoolEndpoint,
) -> PoolNetwork {
    let pool_store = PoolStore::new(base_path).unwrap();
    let card_repo = CardNoteRepository::new(base_path).unwrap();
    PoolNetwork::new(endpoint, pool_store, card_repo)
}

// ==================== sync_state 测试 ====================

#[tokio::test]
async fn test_sync_state_idle_when_no_error() {
    let (network, _temp) = create_test_pool_network().await;

    // 初始状态应该是 idle
    assert_eq!(network.sync_state(), "idle");
}

#[tokio::test]
async fn test_sync_state_failed_when_error() {
    let (mut network, _temp) = create_test_pool_network().await;

    // 模拟同步错误：尝试 push 但未连接
    let _ = network.sync_push();

    // 状态应该是 sync_failed
    assert_eq!(network.sync_state(), "sync_failed");
}

#[tokio::test]
async fn test_sync_state_connected() {
    let (mut network, _temp) = create_test_pool_network().await;

    // 连接到目标
    network.sync_connect("test-target".to_string()).unwrap();

    // 状态应该是 connected
    assert_eq!(network.sync_state(), "connected");
}

// ==================== last_sync_error_code 测试 ====================

#[tokio::test]
async fn test_last_sync_error_code_none_initially() {
    let (network, _temp) = create_test_pool_network().await;

    // 初始应该没有错误代码
    assert_eq!(network.last_sync_error_code(), None);
}

#[tokio::test]
async fn test_last_sync_error_code_after_push_failure() {
    let (mut network, _temp) = create_test_pool_network().await;

    // 尝试 push 但未连接，应该设置错误
    let _ = network.sync_push();

    // 应该有错误代码
    assert_eq!(network.last_sync_error_code(), Some("REQUEST_TIMEOUT"));
}

#[tokio::test]
async fn test_last_sync_error_code_cleared_after_connect() {
    let (mut network, _temp) = create_test_pool_network().await;

    // 先产生错误
    let _ = network.sync_push();
    assert_eq!(network.last_sync_error_code(), Some("REQUEST_TIMEOUT"));

    // 连接后错误应该被清除
    network.sync_connect("target".to_string()).unwrap();
    assert_eq!(network.last_sync_error_code(), None);
}

#[tokio::test]
async fn test_last_sync_error_code_cleared_after_disconnect() {
    let (mut network, _temp) = create_test_pool_network().await;

    // 先产生错误
    let _ = network.sync_push();
    assert_eq!(network.last_sync_error_code(), Some("REQUEST_TIMEOUT"));

    // 断开后错误应该被清除
    network.sync_disconnect();
    assert_eq!(network.last_sync_error_code(), None);
}

// ==================== sync_join_pool 测试 ====================

#[tokio::test]
async fn test_sync_join_pool_empty_id_fails() {
    let (mut network, _temp) = create_test_pool_network().await;

    // 先连接
    network.sync_connect("target".to_string()).unwrap();

    // 空 pool_id 应该失败
    let result = network.sync_join_pool("");
    assert!(result.is_err());
    match result {
        Err(CardMindError::InvalidArgument(msg)) => {
            assert!(msg.contains("empty"));
        }
        _ => panic!("Expected InvalidArgument error"),
    }
}

#[tokio::test]
async fn test_sync_join_pool_whitespace_only_fails() {
    let (mut network, _temp) = create_test_pool_network().await;

    // 先连接
    network.sync_connect("target".to_string()).unwrap();

    // 仅空白字符应该失败
    let result = network.sync_join_pool("   ");
    assert!(result.is_err());
}

#[tokio::test]
async fn test_sync_join_pool_not_connected_fails() {
    let (network, _temp) = create_test_pool_network().await;

    // 未连接时应该失败
    let result = network.sync_join_pool("pool-123");
    assert!(result.is_err());
    match result {
        Err(CardMindError::InvalidArgument(msg)) => {
            assert!(msg.contains("not connected"));
        }
        _ => panic!("Expected InvalidArgument error"),
    }
}

#[tokio::test]
async fn test_sync_join_pool_success() {
    let (mut network, _temp) = create_test_pool_network().await;

    // 先连接
    network.sync_connect("target".to_string()).unwrap();

    // 有效 pool_id 应该成功
    let result = network.sync_join_pool("pool-123");
    assert!(result.is_ok());
}

#[tokio::test]
async fn test_sync_join_pool_valid_uuid_format() {
    let (mut network, _temp) = create_test_pool_network().await;

    // 先连接
    network.sync_connect("target".to_string()).unwrap();

    // UUID 格式应该成功
    let result = network.sync_join_pool("550e8400-e29b-41d4-a716-446655440000");
    assert!(result.is_ok());
}

// ==================== sync_push 测试 ====================

#[tokio::test]
async fn test_sync_push_not_connected_fails() {
    let (mut network, _temp) = create_test_pool_network().await;

    // 未连接时 push 应该失败
    let result = network.sync_push();
    assert!(result.is_err());
    match result {
        Err(CardMindError::InvalidArgument(msg)) => {
            assert!(msg.contains("not connected"));
        }
        _ => panic!("Expected InvalidArgument error"),
    }
}

#[tokio::test]
async fn test_sync_push_sets_error_code() {
    let (mut network, _temp) = create_test_pool_network().await;

    // push 失败后应该设置错误代码
    let _ = network.sync_push();
    assert_eq!(network.last_sync_error_code(), Some("REQUEST_TIMEOUT"));
}

#[tokio::test]
async fn test_sync_push_success_when_connected() {
    let (mut network, _temp) = create_test_pool_network().await;

    // 先连接
    network.sync_connect("target".to_string()).unwrap();

    // 连接后 push 应该成功
    let result = network.sync_push();
    assert!(result.is_ok());
}

#[tokio::test]
async fn test_sync_push_clears_error_code_on_success() {
    let (mut network, _temp) = create_test_pool_network().await;

    // 先产生错误
    let _ = network.sync_push();
    assert_eq!(network.last_sync_error_code(), Some("REQUEST_TIMEOUT"));

    // 连接
    network.sync_connect("target".to_string()).unwrap();

    // 成功的 push 应该清除错误
    let _ = network.sync_push();
    assert_eq!(network.last_sync_error_code(), None);
}

// ==================== sync_pull 测试 ====================

#[tokio::test]
async fn test_sync_pull_not_connected_fails() {
    let (mut network, _temp) = create_test_pool_network().await;

    // 未连接时 pull 应该失败
    let result = network.sync_pull();
    assert!(result.is_err());
    match result {
        Err(CardMindError::InvalidArgument(msg)) => {
            assert!(msg.contains("not connected"));
        }
        _ => panic!("Expected InvalidArgument error"),
    }
}

#[tokio::test]
async fn test_sync_pull_sets_error_code() {
    let (mut network, _temp) = create_test_pool_network().await;

    // pull 失败后应该设置错误代码
    let _ = network.sync_pull();
    assert_eq!(network.last_sync_error_code(), Some("REQUEST_TIMEOUT"));
}

#[tokio::test]
async fn test_sync_pull_success_when_connected() {
    let (mut network, _temp) = create_test_pool_network().await;

    // 先连接
    network.sync_connect("target".to_string()).unwrap();

    // 连接后 pull 应该成功
    let result = network.sync_pull();
    assert!(result.is_ok());
}

#[tokio::test]
async fn test_sync_pull_clears_error_code_on_success() {
    let (mut network, _temp) = create_test_pool_network().await;

    // 先产生错误
    let _ = network.sync_pull();
    assert_eq!(network.last_sync_error_code(), Some("REQUEST_TIMEOUT"));

    // 连接
    network.sync_connect("target".to_string()).unwrap();

    // 成功的 pull 应该清除错误
    let _ = network.sync_pull();
    assert_eq!(network.last_sync_error_code(), None);
}

// ==================== sync_connect / disconnect 测试 ====================

#[tokio::test]
async fn test_sync_connect_empty_target_fails() {
    let (mut network, _temp) = create_test_pool_network().await;

    let result = network.sync_connect("".to_string());
    assert!(result.is_err());
}

#[tokio::test]
async fn test_sync_connect_success() {
    let (mut network, _temp) = create_test_pool_network().await;

    let result = network.sync_connect("test-target".to_string());
    assert!(result.is_ok());
    assert_eq!(network.sync_state(), "connected");
}

#[tokio::test]
async fn test_sync_disconnect_changes_state() {
    let (mut network, _temp) = create_test_pool_network().await;

    // 连接
    network.sync_connect("target".to_string()).unwrap();
    assert_eq!(network.sync_state(), "connected");

    // 断开
    network.sync_disconnect();
    assert_eq!(network.sync_state(), "idle");
}

#[tokio::test]
async fn test_sync_disconnect_clears_error() {
    let (mut network, _temp) = create_test_pool_network().await;

    // 产生错误
    let _ = network.sync_push();
    assert_eq!(network.last_sync_error_code(), Some("REQUEST_TIMEOUT"));

    // 断开清除错误
    network.sync_disconnect();
    assert_eq!(network.last_sync_error_code(), None);
}

// ==================== 边界组合测试 ====================

#[tokio::test]
async fn test_sync_full_lifecycle() {
    let (mut network, _temp) = create_test_pool_network().await;

    // 1. 初始状态
    assert_eq!(network.sync_state(), "idle");
    assert_eq!(network.last_sync_error_code(), None);

    // 2. 尝试操作未连接 - 应该失败
    assert!(network.sync_push().is_err());
    assert_eq!(network.sync_state(), "sync_failed");
    assert_eq!(network.last_sync_error_code(), Some("REQUEST_TIMEOUT"));

    // 3. 连接
    network.sync_connect("target".to_string()).unwrap();
    assert_eq!(network.sync_state(), "connected");
    assert_eq!(network.last_sync_error_code(), None);

    // 4. 连接后操作 - 应该成功
    assert!(network.sync_push().is_ok());
    assert!(network.sync_pull().is_ok());
    assert!(network.sync_join_pool("pool-1").is_ok());

    // 5. 断开
    network.sync_disconnect();
    assert_eq!(network.sync_state(), "idle");
    assert_eq!(network.last_sync_error_code(), None);

    // 6. 断开后操作 - 应该失败
    assert!(network.sync_push().is_err());
    assert_eq!(network.sync_state(), "sync_failed");
}

#[tokio::test]
async fn test_multiple_connect_disconnect_cycles() {
    let (mut network, _temp) = create_test_pool_network().await;

    for i in 0..3 {
        // 连接
        network.sync_connect(format!("target-{}", i)).unwrap();
        assert_eq!(network.sync_state(), "connected");

        // 操作
        assert!(network.sync_push().is_ok());

        // 断开
        network.sync_disconnect();
        assert_eq!(network.sync_state(), "idle");
    }
}

#[tokio::test]
async fn test_sync_state_priority_over_session_state() {
    let (mut network, _temp) = create_test_pool_network().await;

    // 连接
    network.sync_connect("target".to_string()).unwrap();
    assert_eq!(network.sync_state(), "connected");

    // 产生错误
    network.sync_disconnect();
    let _ = network.sync_push(); // 这会设置 last_sync_error

    // sync_state 应该优先返回 sync_failed（如果有错误）
    assert_eq!(network.sync_state(), "sync_failed");
}

#[tokio::test]
async fn test_sync_failure_keeps_same_data_path_semantics() {
    let (mut network, _temp) = create_test_pool_network().await;

    let _ = network.sync_push();

    assert_eq!(network.sync_state(), "sync_failed");
    assert_eq!(network.last_sync_error_code(), Some("REQUEST_TIMEOUT"));
}

#[tokio::test]
async fn test_sync_success_restores_safe_continuity_semantics() {
    let (mut network, _temp) = create_test_pool_network().await;

    let _ = network.sync_push();
    assert_eq!(network.last_sync_error_code(), Some("REQUEST_TIMEOUT"));

    network.sync_connect("target".to_string()).unwrap();
    let result = network.sync_push();

    assert!(result.is_ok());
    assert_eq!(network.sync_state(), "connected");
    assert_eq!(network.last_sync_error_code(), None);
}

#[tokio::test]
async fn test_sync_reconnect_clears_failure_before_next_action_changes() {
    let (mut network, _temp) = create_test_pool_network().await;

    let _ = network.sync_push();
    assert_eq!(network.sync_state(), "sync_failed");
    assert_eq!(network.last_sync_error_code(), Some("REQUEST_TIMEOUT"));

    network.sync_connect("target".to_string()).unwrap();

    assert_eq!(network.sync_state(), "connected");
    assert_eq!(network.last_sync_error_code(), None);
}

// ==================== 实际同步流程测试 ====================

#[tokio::test]
async fn test_has_card_returns_true_after_create() {
    let (network, temp_dir) = create_test_pool_network().await;
    let repo = CardNoteRepository::new(temp_dir.path().to_str().unwrap()).unwrap();
    let card = repo.create_card("title", "content").unwrap();

    let result = network.has_card(&card.id).unwrap();

    assert!(result);
}

#[tokio::test]
async fn test_has_card_returns_false_when_missing() {
    let (network, _temp_dir) = create_test_pool_network().await;
    let missing = uuid::Uuid::new_v4();

    let result = network.has_card(&missing).unwrap();

    assert!(!result);
}

#[tokio::test]
async fn test_connect_and_sync_fails_when_no_pool_exists() {
    let (network_a, network_b) = build_test_endpoints().await.unwrap();
    let sender_temp = TempDir::new().unwrap();
    let receiver_temp = TempDir::new().unwrap();
    let sender = create_network_with_endpoint(sender_temp.path().to_str().unwrap(), network_a);
    let receiver = create_network_with_endpoint(receiver_temp.path().to_str().unwrap(), network_b);
    receiver.start().await.unwrap();
    let receiver_addr = receiver
        .wait_for_addr(Duration::from_secs(5))
        .await
        .unwrap();

    let result = sender.connect_and_sync(receiver_addr).await;

    assert!(result.is_err());
    match result.unwrap_err() {
        CardMindError::NotFound(msg) => assert!(msg.contains("pool not found")),
        other => panic!("unexpected error: {:?}", other),
    }
}

#[tokio::test]
async fn test_connect_and_sync_transfers_pool_snapshot_without_cards() {
    let (network_a, network_b) = build_test_endpoints().await.unwrap();
    let sender_temp = TempDir::new().unwrap();
    let receiver_temp = TempDir::new().unwrap();
    let sender_base = sender_temp.path().to_str().unwrap();
    let receiver_base = receiver_temp.path().to_str().unwrap();

    let sender = create_network_with_endpoint(sender_base, network_a);
    let receiver = create_network_with_endpoint(receiver_base, network_b);

    let sender_store = PoolStore::new(sender_base).unwrap();
    let sender_pool = sender_store
        .create_pool(&sender.endpoint_id().to_string(), "sender", "macOS")
        .unwrap();

    receiver.start().await.unwrap();
    let receiver_addr = receiver
        .wait_for_addr(Duration::from_secs(5))
        .await
        .unwrap();

    sender.connect_and_sync(receiver_addr).await.unwrap();
    sleep(Duration::from_millis(500)).await;

    let receiver_store = PoolStore::new(receiver_base).unwrap();
    let synced_pool = receiver_store.get_pool(&sender_pool.pool_id).unwrap();

    assert_eq!(synced_pool.pool_id, sender_pool.pool_id);
    assert_eq!(synced_pool.members.len(), 1);
    assert!(synced_pool.card_ids.is_empty());
}

#[tokio::test]
async fn test_connect_and_sync_transfers_pool_and_cards() {
    let (network_a, network_b) = build_test_endpoints().await.unwrap();
    let sender_temp = TempDir::new().unwrap();
    let receiver_temp = TempDir::new().unwrap();
    let sender_base = sender_temp.path().to_str().unwrap();
    let receiver_base = receiver_temp.path().to_str().unwrap();

    let sender = create_network_with_endpoint(sender_base, network_a);
    let receiver = create_network_with_endpoint(receiver_base, network_b);

    let sender_store = PoolStore::new(sender_base).unwrap();
    let sender_repo = CardNoteRepository::new(sender_base).unwrap();
    let sender_pool = sender_store
        .create_pool(&sender.endpoint_id().to_string(), "sender", "macOS")
        .unwrap();
    let card = sender_repo
        .create_card("sync title", "sync content")
        .unwrap();
    sender_store
        .attach_note_references(&sender_pool.pool_id, vec![card.id])
        .unwrap();

    receiver.start().await.unwrap();
    let receiver_addr = receiver
        .wait_for_addr(Duration::from_secs(5))
        .await
        .unwrap();

    sender.connect_and_sync(receiver_addr).await.unwrap();
    sleep(Duration::from_millis(800)).await;

    let receiver_store = PoolStore::new(receiver_base).unwrap();
    let receiver_repo = CardNoteRepository::new(receiver_base).unwrap();
    let synced_pool = receiver_store.get_pool(&sender_pool.pool_id).unwrap();
    let synced_card = receiver_repo.get_card(&card.id).unwrap();

    assert_eq!(synced_pool.pool_id, sender_pool.pool_id);
    assert_eq!(synced_pool.card_ids, vec![card.id]);
    assert_eq!(synced_card.id, card.id);
    assert_eq!(synced_card.title, "sync title");
    assert_eq!(synced_card.content, "sync content");
}

#[tokio::test]
async fn test_connect_and_sync_uses_first_member_when_endpoint_not_in_pool() {
    let (network_a, network_b) = build_test_endpoints().await.unwrap();
    let sender_temp = TempDir::new().unwrap();
    let receiver_temp = TempDir::new().unwrap();
    let sender_base = sender_temp.path().to_str().unwrap();
    let receiver_base = receiver_temp.path().to_str().unwrap();

    let sender = create_network_with_endpoint(sender_base, network_a);
    let receiver = create_network_with_endpoint(receiver_base, network_b);

    let sender_store = PoolStore::new(sender_base).unwrap();
    let sender_pool = sender_store
        .create_pool("different-endpoint", "fallback-admin", "Linux")
        .unwrap();

    receiver.start().await.unwrap();
    let receiver_addr = receiver
        .wait_for_addr(Duration::from_secs(5))
        .await
        .unwrap();

    sender.connect_and_sync(receiver_addr).await.unwrap();
    sleep(Duration::from_millis(500)).await;

    let receiver_store = PoolStore::new(receiver_base).unwrap();
    let synced_pool = receiver_store.get_pool(&sender_pool.pool_id).unwrap();

    assert_eq!(synced_pool.members[0].nickname, "fallback-admin");
}

#[tokio::test]
async fn test_connect_and_sync_rejects_sender_not_in_existing_receiver_pool() {
    let (network_a, network_b) = build_test_endpoints().await.unwrap();
    let sender_temp = TempDir::new().unwrap();
    let receiver_temp = TempDir::new().unwrap();
    let sender_base = sender_temp.path().to_str().unwrap();
    let receiver_base = receiver_temp.path().to_str().unwrap();

    let sender = create_network_with_endpoint(sender_base, network_a);
    let receiver = create_network_with_endpoint(receiver_base, network_b);

    let sender_store = PoolStore::new(sender_base).unwrap();
    let sender_pool = sender_store
        .create_pool(&sender.endpoint_id().to_string(), "sender", "macOS")
        .unwrap();

    let receiver_store = PoolStore::new(receiver_base).unwrap();
    let foreign_pool = Pool {
        pool_id: sender_pool.pool_id,
        members: vec![PoolMember {
            endpoint_id: "someone-else".to_string(),
            nickname: "receiver".to_string(),
            os: "Windows".to_string(),
            is_admin: true,
        }],
        card_ids: vec![],
    };
    receiver_store
        .join_pool(&foreign_pool, foreign_pool.members[0].clone(), vec![])
        .unwrap();

    receiver.start().await.unwrap();
    let receiver_addr = receiver
        .wait_for_addr(Duration::from_secs(5))
        .await
        .unwrap();

    sender.connect_and_sync(receiver_addr).await.unwrap();
    sleep(Duration::from_millis(500)).await;

    let result = receiver_store.get_pool(&sender_pool.pool_id).unwrap();

    assert_eq!(result.members.len(), 1);
    assert_eq!(result.members[0].endpoint_id, "someone-else");
}
