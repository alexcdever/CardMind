use cardmind_rust::api::{
    PoolInviteDto, PoolInvitesViewDto, PoolMemberRuntimeDto, PoolMembersRuntimeViewDto,
    PoolRuntimeSummaryDto,
};
use cardmind_rust::models::pool::PoolMember;
use cardmind_rust::models::pool_runtime::{MemberRuntimeStatus, PoolMemberRuntime};
use cardmind_rust::net::endpoint::build_test_endpoints;
use cardmind_rust::net::pool_network::PoolNetwork;
use cardmind_rust::store::card_store::CardNoteRepository;
use cardmind_rust::store::pool_store::{PoolInviteRecord, PoolStore};
use std::future::{Future, poll_fn};
use std::pin::Pin;
use std::task::Poll;
use tempfile::TempDir;
use tokio::time::Duration;

#[test]
fn member_runtime_status_should_render_connected_syncing_offline() {
    assert_eq!(
        MemberRuntimeStatus::from_signals(true, false).as_str(),
        "connected"
    );
    assert_eq!(
        MemberRuntimeStatus::from_signals(true, true).as_str(),
        "syncing"
    );
    assert_eq!(
        MemberRuntimeStatus::from_signals(false, false).as_str(),
        "offline"
    );
}

#[test]
fn current_device_flag_should_be_true_only_for_matching_endpoint() {
    let member = PoolMember {
        endpoint_id: "owner-endpoint".to_string(),
        nickname: "Owner".to_string(),
        os: "macOS".to_string(),
        is_admin: true,
    };

    let current = PoolMemberRuntime::from_member(
        &member,
        "owner-endpoint",
        MemberRuntimeStatus::Connected,
        Some(1_713_700_000),
    );
    let other = PoolMemberRuntime::from_member(
        &member,
        "joiner-endpoint",
        MemberRuntimeStatus::Connected,
        Some(1_713_700_000),
    );

    assert!(current.is_current_device);
    assert!(!other.is_current_device);
    assert_eq!(current.role, "admin");
    assert_eq!(other.role, "admin");
}

fn create_network_with_endpoint(
    base_path: &str,
    endpoint: cardmind_rust::net::endpoint::PoolEndpoint,
) -> PoolNetwork {
    let pool_store = PoolStore::new(base_path).unwrap();
    let card_repo = CardNoteRepository::new(base_path).unwrap();
    PoolNetwork::new(endpoint, pool_store, card_repo)
}

#[tokio::test]
async fn pool_network_should_report_syncing_state_during_active_sync() {
    let (network_a, network_b) = build_test_endpoints().await.unwrap();
    let sender_temp = TempDir::new().unwrap();
    let receiver_temp = TempDir::new().unwrap();
    let sender_base = sender_temp.path().to_str().unwrap();
    let receiver_base = receiver_temp.path().to_str().unwrap();

    let sender = create_network_with_endpoint(sender_base, network_a);
    let receiver = create_network_with_endpoint(receiver_base, network_b);

    let sender_store = PoolStore::new(sender_base).unwrap();
    sender_store
        .create_pool(&sender.endpoint_id().to_string(), "sender", "macOS")
        .unwrap();

    receiver.start().await.unwrap();
    let receiver_addr = receiver
        .wait_for_addr(Duration::from_secs(5))
        .await
        .unwrap();

    let sync_future = sender.connect_and_sync(receiver_addr);
    tokio::pin!(sync_future);

    poll_once_until_pending(sync_future.as_mut()).await;

    assert!(sender.is_syncing());

    sync_future.await.unwrap();

    assert!(!sender.is_syncing());
    assert!(!sender.has_live_connection());
}

#[tokio::test]
async fn pool_network_should_expose_last_active_timestamp_after_sync_event() {
    let (network_a, network_b) = build_test_endpoints().await.unwrap();
    let sender_temp = TempDir::new().unwrap();
    let receiver_temp = TempDir::new().unwrap();
    let sender_base = sender_temp.path().to_str().unwrap();
    let receiver_base = receiver_temp.path().to_str().unwrap();

    let sender = create_network_with_endpoint(sender_base, network_a);
    let receiver = create_network_with_endpoint(receiver_base, network_b);

    let sender_store = PoolStore::new(sender_base).unwrap();
    sender_store
        .create_pool(&sender.endpoint_id().to_string(), "sender", "macOS")
        .unwrap();

    receiver.start().await.unwrap();
    let receiver_addr = receiver
        .wait_for_addr(Duration::from_secs(5))
        .await
        .unwrap();

    assert_eq!(sender.last_active_at(), None);

    sender.connect_and_sync(receiver_addr).await.unwrap();

    assert!(sender.last_active_at().is_some());
}

#[tokio::test]
async fn pool_network_should_clear_live_connection_after_sync_finishes() {
    let (network_a, network_b) = build_test_endpoints().await.unwrap();
    let sender_temp = TempDir::new().unwrap();
    let receiver_temp = TempDir::new().unwrap();
    let sender_base = sender_temp.path().to_str().unwrap();
    let receiver_base = receiver_temp.path().to_str().unwrap();

    let sender = create_network_with_endpoint(sender_base, network_a);
    let receiver = create_network_with_endpoint(receiver_base, network_b);

    let sender_store = PoolStore::new(sender_base).unwrap();
    sender_store
        .create_pool(&sender.endpoint_id().to_string(), "sender", "macOS")
        .unwrap();

    receiver.start().await.unwrap();
    let receiver_addr = receiver
        .wait_for_addr(Duration::from_secs(5))
        .await
        .unwrap();

    assert!(!sender.has_live_connection());

    sender.connect_and_sync(receiver_addr).await.unwrap();

    assert!(!sender.has_live_connection());
    assert!(sender.last_active_at().is_some());
}

async fn poll_once_until_pending<F>(future: Pin<&mut F>)
where
    F: Future,
{
    let mut future = future;
    poll_fn(move |cx| match future.as_mut().poll(cx) {
        Poll::Pending => Poll::Ready(()),
        Poll::Ready(_) => Poll::Ready(()),
    })
    .await;
}

#[test]
fn runtime_view_dto_should_mark_current_device() {
    let runtime = PoolMemberRuntime {
        endpoint_id: "owner-endpoint".to_string(),
        nickname: "Owner".to_string(),
        os: "macOS".to_string(),
        role: "admin".to_string(),
        status: MemberRuntimeStatus::Connected,
        last_active_at: Some(1_713_700_000),
        is_current_device: true,
    };

    let row = PoolMemberRuntimeDto::from_runtime(&runtime);
    let view = PoolMembersRuntimeViewDto::new(vec![row.clone()]);

    assert!(row.is_current_device);
    assert_eq!(row.status, "connected");
    assert_eq!(view.rows.len(), 1);
    assert!(view.rows[0].is_current_device);
}

#[test]
fn summary_dto_should_return_expected_text_fields() {
    let summary = PoolRuntimeSummaryDto::from_counts(3, 1, 1, 1);

    assert_eq!(summary.member_count_text, "3 members");
    assert_eq!(
        summary.runtime_status_text,
        "1 connected, 1 syncing, 1 offline"
    );
}

#[test]
fn invite_view_dto_should_exclude_revoked_invites() {
    let active = PoolInviteRecord {
        invite_id: uuid::Uuid::now_v7(),
        invite_code: "active-code".to_string(),
        created_by_endpoint_id: "owner-endpoint".to_string(),
        created_at: 1_713_700_000,
        revoked_at: None,
    };
    let revoked = PoolInviteRecord {
        invite_id: uuid::Uuid::now_v7(),
        invite_code: "revoked-code".to_string(),
        created_by_endpoint_id: "owner-endpoint".to_string(),
        created_at: 1_713_700_001,
        revoked_at: Some(1_713_700_100),
    };

    let dto = PoolInvitesViewDto::from_records(vec![active.clone(), revoked]);

    assert_eq!(dto.invites.len(), 1);
    assert_eq!(dto.active_count, 1);
    assert_eq!(dto.invites[0], PoolInviteDto::from_record(&active));
}
