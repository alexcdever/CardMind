// input: 模拟两个客户端（A和B）通过数据池进行协作。
// output: 断言客户端A创建池、客户端B加入、数据同步等核心流程。
// pos: 覆盖多客户端数据池协作的核心场景，确保后端逻辑正确。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::api::*;
use serial_test::serial;
use tempfile::tempdir;

fn setup_test(test_name: &str) -> String {
    // 每次测试前重置全局状态
    let _ = close_all_pool_networks_for_tests();
    let _ = reset_app_config_for_tests();

    let dir = tempdir().expect("Failed to create temp dir");
    let test_path = dir.path().join(test_name);
    std::fs::create_dir_all(&test_path).expect("Failed to create test dir");

    let app_data_dir = test_path.to_string_lossy().to_string();

    init_app_config(app_data_dir.clone()).expect("Failed to init app config");
    setup_app_lock("1234".to_string(), true).expect("Failed to setup app lock");
    verify_app_lock_with_pin("1234".to_string()).expect("Failed to unlock app lock");
    init_pool_network(app_data_dir.clone()).expect("Failed to init pool network");

    app_data_dir
}

/// 模拟两个客户端的数据池协作场景
///
/// 场景：
/// 1. 客户端A创建数据池
/// 2. 客户端B通过邀请码加入
/// 3. 客户端A创建卡片
/// 4. 验证客户端B能看到同步的数据
#[test]
#[serial]
fn test_two_clients_pool_collaboration() {
    let _app_data_dir = setup_test("collaboration");

    // 客户端A创建数据池
    let pool = create_pool(
        "endpoint-a".to_string(),
        "Alice".to_string(),
        "macos".to_string(),
    )
    .expect("Failed to create pool");

    println!("Pool created with ID: {}", pool.id);
    println!("Invite code: {}", pool.id);

    // 客户端A创建一张卡片
    let card = create_card_note("测试卡片".to_string(), "这是测试内容".to_string())
        .expect("Failed to create card");

    println!("Card created with ID: {}", card.id);

    // 客户端B通过邀请码加入数据池（使用不同的 endpoint）
    let joined_pool = join_by_code(
        pool.id.clone(),
        "endpoint-b".to_string(),
        "Bob".to_string(),
        "ios".to_string(),
    )
    .expect("Failed to join pool");

    println!("Client B joined pool: {}", joined_pool.id);

    // 验证客户端B能看到数据池详情
    let pool_detail = get_pool_detail(pool.id.clone(), "endpoint-b".to_string())
        .expect("Failed to get pool detail");

    println!(
        "Pool detail retrieved: {} members",
        pool_detail.members.len()
    );

    // 断言：池中有两个成员（A和B）
    assert_eq!(pool_detail.members.len(), 2, "Pool should have 2 members");

    // 断言：客户端B能看到客户端A创建的卡片
    assert!(!pool_detail.note_ids.is_empty(), "Pool should have notes");
    assert!(
        pool_detail.note_ids.contains(&card.id),
        "Pool should contain the card created by A"
    );

    println!("✅ Two clients pool collaboration test passed!");
}

/// 测试加入不存在的池会失败
#[test]
#[serial]
fn test_join_nonexistent_pool_fails() {
    let _app_data_dir = setup_test("nonexistent");

    // 尝试加入不存在的池
    let result = join_by_code(
        "invalid-pool-id".to_string(),
        "endpoint-c".to_string(),
        "Charlie".to_string(),
        "android".to_string(),
    );

    // 应该失败
    assert!(result.is_err(), "Joining nonexistent pool should fail");
    let err = result.unwrap_err();
    // 错误码可能是 INVALID_POOL_HASH 或 REQUEST_TIMEOUT
    assert!(
        err.code == "INVALID_POOL_HASH" || err.code == "REQUEST_TIMEOUT",
        "Should get appropriate error for invalid pool, got: {}",
        err.code
    );

    println!(
        "✅ Join nonexistent pool correctly failed with code: {}",
        err.code
    );
}

/// 测试创建池和加入池的完整流程
#[test]
#[serial]
fn test_create_and_join_pool() {
    let _app_data_dir = setup_test("create_join");

    // 创建池
    let pool = create_pool(
        "endpoint-creator".to_string(),
        "Creator".to_string(),
        "macos".to_string(),
    )
    .expect("Failed to create pool");

    println!("Created pool: {}", pool.id);

    // 另一个用户加入池
    let joined = join_by_code(
        pool.id.clone(),
        "endpoint-joiner".to_string(),
        "Joiner".to_string(),
        "ios".to_string(),
    )
    .expect("Failed to join pool");

    println!("Joined pool: {}", joined.id);

    // 列出加入者可见的池
    let pools = list_pools("endpoint-joiner".to_string()).expect("Failed to list pools");

    println!("Listed {} pools for joiner", pools.len());

    // 加入者应该能看到 1 个池
    assert_eq!(
        pools.len(),
        1,
        "Joiner should see 1 pool, got {}",
        pools.len()
    );
    assert_eq!(pools[0].id, pool.id, "Pool ID should match");

    println!("✅ Create and join pool test passed!");
}

/// 测试最后一个管理员退出会被拒绝
#[test]
#[serial]
fn test_last_admin_leave_pool_fails() {
    let _app_data_dir = setup_test("last_admin_leave");

    let pool = create_pool(
        "endpoint-admin".to_string(),
        "Admin".to_string(),
        "macos".to_string(),
    )
    .expect("Failed to create pool");

    let _joined = join_by_code(
        pool.id.clone(),
        "endpoint-member".to_string(),
        "Member".to_string(),
        "ios".to_string(),
    )
    .expect("Failed to join pool");

    let err = leave_pool(pool.id, "endpoint-admin".to_string())
        .expect_err("last admin leave should fail");

    assert_eq!(err.code, "INVALID_ARGUMENT");
    assert!(err.message.contains("last admin"));
}

#[test]
#[serial]
fn test_dissolve_pool_marks_pool_as_dissolved() {
    let _app_data_dir = setup_test("dissolve_pool_success");

    let pool = create_pool(
        "endpoint-admin".to_string(),
        "Admin".to_string(),
        "macos".to_string(),
    )
    .expect("Failed to create pool");

    let dissolved = dissolve_pool(pool.id.clone(), "endpoint-admin".to_string())
        .expect("Failed to dissolve pool");
    let detail = get_pool_detail(pool.id, "endpoint-admin".to_string())
        .expect("Failed to fetch dissolved pool detail");

    assert!(dissolved.is_dissolved);
    assert!(detail.is_dissolved);
}

#[test]
#[serial]
fn test_dissolved_pool_rejects_join() {
    let _app_data_dir = setup_test("dissolved_pool_rejects_join");

    let pool = create_pool(
        "endpoint-admin".to_string(),
        "Admin".to_string(),
        "macos".to_string(),
    )
    .expect("Failed to create pool");

    dissolve_pool(pool.id.clone(), "endpoint-admin".to_string()).expect("Failed to dissolve pool");

    let err = join_by_code(
        pool.id,
        "endpoint-member".to_string(),
        "Member".to_string(),
        "ios".to_string(),
    )
    .expect_err("joining dissolved pool should fail");

    assert_eq!(err.code, "INVALID_ARGUMENT");
    assert!(err.message.contains("dissolved"));
}
