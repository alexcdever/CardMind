// input: 双端点网络、双端临时存储、预置 pool/card 数据与同步连接请求。
// output: 断言 connect_and_sync 后对端节点成功接收并可查询同步卡片。
// pos: 覆盖组网跨节点池与卡片同步主流程场景的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::api;
use cardmind_rust::models::pool::PoolMember;
use cardmind_rust::net::endpoint::build_test_endpoints;
use cardmind_rust::net::pool_network::PoolNetwork;
use cardmind_rust::store::card_store::CardNoteRepository;
use cardmind_rust::store::pool_store::PoolStore;
use serial_test::serial;
use std::time::Duration;
use tempfile::tempdir;

#[tokio::test]
async fn it_should_sync_pool_and_cards() -> Result<(), Box<dyn std::error::Error>> {
    let (endpoint_a, endpoint_b) = build_test_endpoints().await?;
    let dir_a = tempdir()?;
    let dir_b = tempdir()?;

    let pool_store_a = PoolStore::new(dir_a.path().to_string_lossy().as_ref())?;
    let card_store_a = CardNoteRepository::new(dir_a.path().to_string_lossy().as_ref())?;
    let pool_store_b = PoolStore::new(dir_b.path().to_string_lossy().as_ref())?;
    let card_store_b = CardNoteRepository::new(dir_b.path().to_string_lossy().as_ref())?;

    let endpoint_id_a = endpoint_a.endpoint_id().to_string();
    let endpoint_id_b = endpoint_b.endpoint_id().to_string();
    let pool = pool_store_a.create_pool(&endpoint_id_a, "nick_a", "os_a")?;
    let card = card_store_a.create_card("title", "content")?;
    let _pool = pool_store_a.join_pool(
        &pool,
        PoolMember {
            endpoint_id: endpoint_id_b,
            nickname: "nick_b".to_string(),
            os: "os_b".to_string(),
            is_admin: false,
        },
        vec![card.id],
    )?;

    let net_a = PoolNetwork::new(endpoint_a, pool_store_a, card_store_a);
    let net_b = PoolNetwork::new(endpoint_b, pool_store_b, card_store_b);
    net_a.start().await?;
    net_b.start().await?;
    let addr = net_b.wait_for_addr(Duration::from_secs(10)).await?;
    net_a.connect_and_sync(addr).await?;

    assert!(net_b.has_card(&card.id)?);
    Ok(())
}

#[tokio::test]
async fn it_should_sync_card_crud_across_two_endpoints() -> Result<(), Box<dyn std::error::Error>> {
    let (endpoint_a, endpoint_b) = build_test_endpoints().await?;
    let dir_a = tempdir()?;
    let dir_b = tempdir()?;

    let pool_store_a = PoolStore::new(dir_a.path().to_string_lossy().as_ref())?;
    let card_store_a = CardNoteRepository::new(dir_a.path().to_string_lossy().as_ref())?;
    let pool_store_b = PoolStore::new(dir_b.path().to_string_lossy().as_ref())?;
    let card_store_b = CardNoteRepository::new(dir_b.path().to_string_lossy().as_ref())?;

    let endpoint_id_a = endpoint_a.endpoint_id().to_string();
    let endpoint_id_b = endpoint_b.endpoint_id().to_string();
    let pool = pool_store_a.create_pool(&endpoint_id_a, "nick_a", "os_a")?;
    let created = card_store_a.create_card("title-v1", "content-v1")?;
    let _pool = pool_store_a.join_pool(
        &pool,
        PoolMember {
            endpoint_id: endpoint_id_b,
            nickname: "nick_b".to_string(),
            os: "os_b".to_string(),
            is_admin: false,
        },
        vec![created.id],
    )?;

    let net_a = PoolNetwork::new(endpoint_a, pool_store_a, card_store_a);
    let net_b = PoolNetwork::new(endpoint_b, pool_store_b, card_store_b);
    net_a.start().await?;
    net_b.start().await?;
    let addr = net_b.wait_for_addr(Duration::from_secs(10)).await?;

    net_a.connect_and_sync(addr.clone()).await?;
    let created_on_b = net_b.get_card(&created.id)?;
    assert_eq!(created_on_b.title, "title-v1");
    assert_eq!(created_on_b.content, "content-v1");
    assert!(!created_on_b.deleted);

    net_a.update_card(&created.id, "title-v2", "content-v2")?;
    net_a.connect_and_sync(addr.clone()).await?;
    let updated_on_b = net_b.get_card(&created.id)?;
    assert_eq!(updated_on_b.title, "title-v2");
    assert_eq!(updated_on_b.content, "content-v2");
    assert!(!updated_on_b.deleted);

    net_a.delete_card(&created.id)?;
    net_a.connect_and_sync(addr.clone()).await?;
    let deleted_on_b = net_b.get_card(&created.id)?;
    assert!(deleted_on_b.deleted);

    net_a.restore_card(&created.id)?;
    net_a.connect_and_sync(addr).await?;
    let restored_on_b = net_b.get_card(&created.id)?;
    assert_eq!(restored_on_b.title, "title-v2");
    assert_eq!(restored_on_b.content, "content-v2");
    assert!(!restored_on_b.deleted);

    Ok(())
}

#[tokio::test]
async fn it_should_join_by_invite_code_and_sync_card_crud() -> Result<(), Box<dyn std::error::Error>>
{
    let (endpoint_a, endpoint_b) = build_test_endpoints().await?;
    let dir_a = tempdir()?;
    let dir_b = tempdir()?;

    let pool_store_a = PoolStore::new(dir_a.path().to_string_lossy().as_ref())?;
    let card_store_a = CardNoteRepository::new(dir_a.path().to_string_lossy().as_ref())?;
    let pool_store_b = PoolStore::new(dir_b.path().to_string_lossy().as_ref())?;
    let card_store_b = CardNoteRepository::new(dir_b.path().to_string_lossy().as_ref())?;

    let endpoint_id_a = endpoint_a.endpoint_id().to_string();
    let pool = pool_store_a.create_pool(&endpoint_id_a, "nick_a", "os_a")?;
    let created = card_store_a.create_card("title-v1", "content-v1")?;
    let _pool = pool_store_a.attach_note_references(&pool.pool_id, vec![created.id])?;

    let net_a = PoolNetwork::new(endpoint_a, pool_store_a, card_store_a);
    let net_b = PoolNetwork::new(endpoint_b, pool_store_b, card_store_b);
    net_a.start().await?;
    net_b.start().await?;

    let addr_b = net_b.wait_for_addr(Duration::from_secs(10)).await?;
    let _addr_a = net_a.wait_for_addr(Duration::from_secs(10)).await?;
    let invite_code = net_a.create_invite_code(&pool.pool_id)?;

    let joined_on_b = net_b
        .request_join_and_sync(&invite_code, "nick_b", "os_b")
        .await?;
    assert_eq!(joined_on_b.pool_id, pool.pool_id);
    assert_eq!(joined_on_b.members.len(), 2);
    assert!(
        joined_on_b
            .members
            .iter()
            .any(|member| member.endpoint_id == net_b.endpoint_id().to_string())
    );

    net_a.connect_and_sync(addr_b.clone()).await?;
    let created_on_b = net_b.get_card(&created.id)?;
    assert_eq!(created_on_b.title, "title-v1");
    assert_eq!(created_on_b.content, "content-v1");
    assert!(!created_on_b.deleted);

    net_a.update_card(&created.id, "title-v2", "content-v2")?;
    net_a.connect_and_sync(addr_b.clone()).await?;
    let updated_on_b = net_b.get_card(&created.id)?;
    assert_eq!(updated_on_b.title, "title-v2");
    assert_eq!(updated_on_b.content, "content-v2");
    assert!(!updated_on_b.deleted);

    net_a.delete_card(&created.id)?;
    net_a.connect_and_sync(addr_b.clone()).await?;
    let deleted_on_b = net_b.get_card(&created.id)?;
    assert!(deleted_on_b.deleted);

    net_a.restore_card(&created.id)?;
    net_a.connect_and_sync(addr_b).await?;
    let restored_on_b = net_b.get_card(&created.id)?;
    assert_eq!(restored_on_b.title, "title-v2");
    assert_eq!(restored_on_b.content, "content-v2");
    assert!(!restored_on_b.deleted);

    Ok(())
}

#[tokio::test]
async fn it_should_sync_card_created_via_store_after_invite_join()
-> Result<(), Box<dyn std::error::Error>> {
    let (endpoint_a, endpoint_b) = build_test_endpoints().await?;
    let dir_a = tempdir()?;
    let dir_b = tempdir()?;

    let pool_store_a = PoolStore::new(dir_a.path().to_string_lossy().as_ref())?;
    let card_store_a = CardNoteRepository::new(dir_a.path().to_string_lossy().as_ref())?;
    let pool_store_b = PoolStore::new(dir_b.path().to_string_lossy().as_ref())?;
    let card_store_b = CardNoteRepository::new(dir_b.path().to_string_lossy().as_ref())?;

    let endpoint_id_a = endpoint_a.endpoint_id().to_string();
    let pool = pool_store_a.create_pool(&endpoint_id_a, "nick_a", "os_a")?;

    let net_a = PoolNetwork::new(endpoint_a, pool_store_a, card_store_a);
    let net_b = PoolNetwork::new(endpoint_b, pool_store_b, card_store_b);
    net_a.start().await?;
    net_b.start().await?;

    let addr_b = net_b.wait_for_addr(Duration::from_secs(10)).await?;
    let invite_code = net_a.create_invite_code(&pool.pool_id)?;

    let joined_on_b = net_b
        .request_join_and_sync(&invite_code, "nick_b", "os_b")
        .await?;
    assert_eq!(joined_on_b.pool_id, pool.pool_id);

    let fresh_card_store_a = CardNoteRepository::new(dir_a.path().to_string_lossy().as_ref())?;
    let fresh_pool_store_a = PoolStore::new(dir_a.path().to_string_lossy().as_ref())?;
    let created = fresh_card_store_a.create_card("late-title", "late-content")?;
    let updated_pool =
        fresh_pool_store_a.attach_note_references(&pool.pool_id, vec![created.id])?;
    assert!(updated_pool.card_ids.contains(&created.id));

    net_a.connect_and_sync(addr_b).await?;

    let created_on_b = net_b.get_card(&created.id)?;
    assert_eq!(created_on_b.title, "late-title");
    assert_eq!(created_on_b.content, "late-content");
    assert!(!created_on_b.deleted);

    Ok(())
}

#[test]
#[serial]
fn it_should_capture_invite_join_trace_on_failure() -> Result<(), Box<dyn std::error::Error>> {
    let owner_dir = tempdir()?;
    let joiner_dir = tempdir()?;

    api::reset_app_config_for_tests()?;
    api::init_app_config(owner_dir.path().to_string_lossy().to_string())?;
    api::setup_app_lock("1234".to_string(), true)?;
    api::verify_app_lock_with_pin("1234".to_string())?;

    let owner_network = api::init_pool_network(owner_dir.path().to_string_lossy().to_string())?;
    let owner_endpoint = api::get_pool_network_endpoint_id(owner_network)?;
    let pool = api::create_pool(owner_endpoint, "owner".to_string(), "macos".to_string())?;
    let invite = api::create_pool_invite(owner_network, pool.id.clone())?;
    api::close_pool_network(owner_network)?;

    api::reset_app_config_for_tests()?;
    api::init_app_config(joiner_dir.path().to_string_lossy().to_string())?;
    api::setup_app_lock("1234".to_string(), true)?;
    api::verify_app_lock_with_pin("1234".to_string())?;

    let joiner_network = api::init_pool_network(joiner_dir.path().to_string_lossy().to_string())?;
    let err = api::join_pool_by_invite(
        joiner_network,
        invite,
        "joiner".to_string(),
        "android".to_string(),
        true,
    )
    .expect_err("join should fail after owner network is closed");
    assert!(err.message.contains("pool_debug.join.invite_parsed:"));
    assert!(err.message.contains("pool_debug.join.target_addrs:"));
    assert!(err.message.contains("pool_debug.join.attempt_start:"));
    assert!(err.message.contains("pool_debug.join.attempt_end:"));
    assert!(err.message.contains("pool_debug.join.final:"));

    api::close_pool_network(joiner_network)?;
    api::reset_app_config_for_tests()?;
    Ok(())
}

#[test]
#[serial]
fn it_should_sync_card_via_api_across_switched_app_configs()
-> Result<(), Box<dyn std::error::Error>> {
    let owner_dir = tempdir()?;
    let joiner_dir = tempdir()?;

    api::reset_app_config_for_tests()?;
    api::init_app_config(owner_dir.path().to_string_lossy().to_string())?;
    api::setup_app_lock("1234".to_string(), true)?;
    api::verify_app_lock_with_pin("1234".to_string())?;

    let owner_network = api::init_pool_network(owner_dir.path().to_string_lossy().to_string())?;
    let owner_endpoint = api::get_pool_network_endpoint_id(owner_network)?;
    let pool = api::create_pool(
        owner_endpoint.clone(),
        "owner".to_string(),
        "macos".to_string(),
    )?;
    let joiner_target = api::get_pool_network_sync_target(owner_network)?;
    let invite = api::create_pool_invite(owner_network, pool.id.clone())?;

    api::reset_app_config_for_tests()?;
    api::init_app_config(joiner_dir.path().to_string_lossy().to_string())?;
    api::setup_app_lock("1234".to_string(), true)?;
    api::verify_app_lock_with_pin("1234".to_string())?;

    let joiner_network = api::init_pool_network(joiner_dir.path().to_string_lossy().to_string())?;
    let owner_target = api::get_pool_network_sync_target(joiner_network)?;
    let joined = api::join_pool_by_invite(
        joiner_network,
        invite,
        "joiner".to_string(),
        "android".to_string(),
        false,
    )?;
    assert_eq!(joined.id, pool.id);

    api::reset_app_config_for_tests()?;
    api::init_app_config(owner_dir.path().to_string_lossy().to_string())?;
    api::setup_app_lock("1234".to_string(), true)?;
    api::verify_app_lock_with_pin("1234".to_string())?;
    api::sync_connect(owner_network, owner_target)?;
    api::sync_join_pool(owner_network, pool.id.clone())?;
    let created = api::create_card_note_in_pool(
        pool.id.clone(),
        "api-title".to_string(),
        "api-content".to_string(),
    )?;
    let pushed = api::sync_push(owner_network)?;
    assert_eq!(pushed.state, "ok");

    api::reset_app_config_for_tests()?;
    api::init_app_config(joiner_dir.path().to_string_lossy().to_string())?;
    api::setup_app_lock("1234".to_string(), true)?;
    api::verify_app_lock_with_pin("1234".to_string())?;
    api::sync_connect(joiner_network, joiner_target)?;
    api::sync_join_pool(joiner_network, pool.id.clone())?;

    let mut last_error = None;
    for _ in 0..20 {
        match api::get_card_note_detail(created.id.clone()) {
            Ok(detail) => {
                assert_eq!(detail.id, created.id);
                api::close_pool_network(owner_network)?;
                api::close_pool_network(joiner_network)?;
                api::reset_app_config_for_tests()?;
                return Ok(());
            }
            Err(error) => {
                last_error = Some(error);
                std::thread::sleep(Duration::from_millis(200));
            }
        }
    }

    api::close_pool_network(owner_network)?;
    api::close_pool_network(joiner_network)?;
    api::reset_app_config_for_tests()?;
    Err(format!("api sync card not visible on joiner: {:?}", last_error).into())
}
