use cardmind_rust::store::pool_store::PoolStore;
use tempfile::TempDir;

fn setup_pool_store() -> (PoolStore, TempDir) {
    let temp_dir = TempDir::new().unwrap();
    let store = PoolStore::new(temp_dir.path().to_str().unwrap()).unwrap();
    (store, temp_dir)
}

#[test]
fn active_invites_should_include_newly_created_invite() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("owner-endpoint", "Owner", "macOS").unwrap();

    let invite = store
        .record_invite(&pool.pool_id, "invite-code-1", "owner-endpoint")
        .unwrap();
    let invites = store.list_active_invites(&pool.pool_id).unwrap();

    assert_eq!(invites.len(), 1);
    assert_eq!(invites[0].invite_id, invite.invite_id);
    assert_eq!(invites[0].invite_code, "invite-code-1");
    assert_eq!(invites[0].created_by_endpoint_id, "owner-endpoint");
    assert!(invites[0].revoked_at.is_none());
}

#[test]
fn revoked_invite_should_not_appear_in_active_invites() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("owner-endpoint", "Owner", "macOS").unwrap();

    let invite = store
        .record_invite(&pool.pool_id, "invite-code-1", "owner-endpoint")
        .unwrap();
    store.revoke_invite(&pool.pool_id, &invite.invite_id).unwrap();

    let invites = store.list_active_invites(&pool.pool_id).unwrap();

    assert!(invites.is_empty());
}
