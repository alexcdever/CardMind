// input: 临时目录初始化的 network handle 与 connect/join/push/pull/disconnect 调用序列。
// output: 断言同步状态按 idle->connected->idle 转换且 push/pull 返回 ok。
// pos: 覆盖同步 API 端到端状态流转场景的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::api::*;
use cardmind_rust::store::path_resolver::DataPaths;
use cardmind_rust::store::sqlite_store::SqliteStore;
use tempfile::tempdir;

#[test]
fn sync_flow_should_move_to_connected_and_back_to_idle() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let network_id = init_pool_network(dir.path().to_string_lossy().to_string())?;

    let initial = sync_status(network_id)?;
    assert_eq!(initial.state, "idle");

    sync_connect(network_id, "local://peer".to_string())?;
    let connected = sync_status(network_id)?;
    assert_eq!(connected.state, "connected");

    sync_join_pool(network_id, "pool-1".to_string())?;
    let push = sync_push(network_id)?;
    assert_eq!(push.state, "ok");
    let pull = sync_pull(network_id)?;
    assert_eq!(pull.state, "ok");

    sync_disconnect(network_id)?;
    let final_status = sync_status(network_id)?;
    assert_eq!(final_status.state, "idle");

    close_pool_network(network_id)?;
    Ok(())
}

#[test]
fn sync_status_should_separate_write_projection_and_sync_states()
-> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let network_id = init_pool_network(dir.path().to_string_lossy().to_string())?;
    let paths = DataPaths::new(dir.path().to_string_lossy().as_ref())?;
    let sqlite = SqliteStore::new(&paths.sqlite_path)?;
    sqlite.record_projection_failure("card", "card-1", "retry_projection")?;

    let status = sync_status(network_id)?;
    assert_eq!(status.state, "degraded");
    assert_eq!(status.write_state, "write_saved");
    assert_eq!(status.projection_state, "projection_pending");
    // Phase 2 契约: projection_pending 导致 has_error=true，sync_state 映射为 "blocked"
    assert_eq!(status.sync_state, "blocked");
    assert_eq!(status.code.as_deref(), Some("PROJECTION_NOT_CONVERGED"));

    let push = sync_push(network_id)?;
    assert_eq!(push.state, "degraded");
    assert_eq!(push.write_state, "write_saved");
    assert_eq!(push.projection_state, "projection_pending");
    // Phase 2 契约: sync_failed 映射为 "blocked"
    assert_eq!(push.sync_state, "blocked");
    assert_eq!(push.code.as_deref(), Some("REQUEST_TIMEOUT"));

    let failed_status = sync_status(network_id)?;
    assert_eq!(failed_status.state, "degraded");
    // Phase 2 契约: sync_failed 映射为 "blocked"
    assert_eq!(failed_status.sync_state, "blocked");
    assert_eq!(failed_status.code.as_deref(), Some("REQUEST_TIMEOUT"));

    close_pool_network(network_id)?;
    Ok(())
}
