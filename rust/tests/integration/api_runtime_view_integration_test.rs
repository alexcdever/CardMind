use cardmind_rust::api::{
    create_pool, create_pool_invite, get_pool_members_runtime_view, get_pool_network_endpoint_id,
    get_pool_runtime_summary, init_app_config, init_pool_network, list_active_invites,
    reset_app_config_for_tests, revoke_invite, setup_app_lock, sync_connect,
    verify_app_lock_with_pin,
};
use serial_test::serial;
use std::sync::{Mutex, OnceLock};
use tempfile::tempdir;

fn app_config_test_guard() -> &'static Mutex<()> {
    static GUARD: OnceLock<Mutex<()>> = OnceLock::new();
    GUARD.get_or_init(|| Mutex::new(()))
}

fn reset_app_config() -> Result<(), Box<dyn std::error::Error>> {
    reset_app_config_for_tests()?;
    Ok(())
}

fn unlock_app_lock() -> Result<(), Box<dyn std::error::Error>> {
    setup_app_lock("1234".to_string(), true)?;
    verify_app_lock_with_pin("1234".to_string())?;
    Ok(())
}

#[test]
#[serial]
fn get_pool_members_runtime_view_returns_member_runtime_rows()
-> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;
    unlock_app_lock()?;

    let network_id = init_pool_network(dir.path().to_string_lossy().to_string())?;
    let endpoint_id = get_pool_network_endpoint_id(network_id)?;
    let pool = create_pool(
        endpoint_id.clone(),
        "owner".to_string(),
        "macOS".to_string(),
    )?;
    cardmind_rust::api::join_by_code(
        pool.id.clone(),
        "joiner-endpoint".to_string(),
        "joiner".to_string(),
        "iOS".to_string(),
    )?;
    sync_connect(network_id, "local://peer".to_string())?;

    let view = get_pool_members_runtime_view(pool.id, endpoint_id)?;

    assert_eq!(view.rows.len(), 2);
    assert_eq!(
        view.rows.iter().filter(|row| row.is_current_device).count(),
        1
    );
    assert!(
        view.rows
            .iter()
            .any(|row| row.is_current_device && row.status == "connected")
    );
    assert!(
        view.rows
            .iter()
            .any(|row| !row.is_current_device && row.status == "offline")
    );

    reset_app_config()?;
    Ok(())
}

#[test]
#[serial]
fn get_pool_runtime_summary_returns_pool_summary_fields() -> Result<(), Box<dyn std::error::Error>>
{
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;
    unlock_app_lock()?;

    let network_id = init_pool_network(dir.path().to_string_lossy().to_string())?;
    let endpoint_id = get_pool_network_endpoint_id(network_id)?;
    let pool = create_pool(
        endpoint_id.clone(),
        "owner".to_string(),
        "macOS".to_string(),
    )?;
    cardmind_rust::api::join_by_code(
        pool.id.clone(),
        "joiner-endpoint".to_string(),
        "joiner".to_string(),
        "iOS".to_string(),
    )?;
    sync_connect(network_id, "local://peer".to_string())?;

    let summary = get_pool_runtime_summary(pool.id, endpoint_id)?;

    assert_eq!(summary.member_count, 2);
    assert_eq!(summary.connected_count, 1);
    assert_eq!(summary.syncing_count, 0);
    assert_eq!(summary.offline_count, 1);
    assert_eq!(summary.member_count_text, "2 members");
    assert_eq!(
        summary.runtime_status_text,
        "1 connected, 0 syncing, 1 offline"
    );

    reset_app_config()?;
    Ok(())
}

#[test]
#[serial]
fn list_active_invites_and_revoke_invite_form_a_closed_loop()
-> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;
    unlock_app_lock()?;

    let network_id = init_pool_network(dir.path().to_string_lossy().to_string())?;
    let endpoint_id = get_pool_network_endpoint_id(network_id)?;
    let pool = create_pool(endpoint_id, "owner".to_string(), "macOS".to_string())?;

    let _invite_code = create_pool_invite(network_id, pool.id.clone())?;
    let invites = list_active_invites(pool.id.clone())?;

    assert_eq!(invites.active_count, 1);
    assert_eq!(invites.invites.len(), 1);

    let after_revoke = revoke_invite(pool.id, invites.invites[0].invite_id.clone())?;

    assert_eq!(after_revoke.active_count, 0);
    assert!(after_revoke.invites.is_empty());

    reset_app_config()?;
    Ok(())
}
