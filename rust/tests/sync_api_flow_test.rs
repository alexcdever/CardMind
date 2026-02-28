// input: rust/tests/sync_api_flow_test.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 测试模块，验证关键行为、边界条件与错误路径。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 测试模块，验证关键行为、边界条件与错误路径。
use cardmind_rust::api::*;
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
