#![allow(clippy::similar_names)]

/// `CardStore集成测试`
///
/// 测试CardStore的双层架构实现：Loro CRDT + `SQLite缓存`
///
/// 测试内容:
/// - `CardStore创建和初始化`
/// - 卡片CRUD操作（create, get, update, delete）
/// - Loro→SQLite自动同步机制
/// - 数据一致性验证
/// - 文件持久化
use cardmind_rust::models::card::OwnerType;
use cardmind_rust::models::error::CardMindError;
use cardmind_rust::store::card_store::CardStore;
use tempfile::TempDir;

fn default_peer_id() -> String {
    "12D3KooWTestPeerId".to_string()
}

// ==================== 1. 初始化测试 ====================

/// 测试: `创建内存CardStore`
#[test]
fn it_should_create_in_memory_card_store() {
    // Given: 无需前置条件

    // When: 创建内存 CardStore
    let result = CardStore::new_in_memory();

    // Then: 应该成功创建
    assert!(result.is_ok(), "应该能创建内存CardStore");
}

/// 测试: `创建基于文件的CardStore`
#[test]
fn it_should_create_file_based_card_store() {
    // Given: 一个临时目录
    let temp_dir = TempDir::new().unwrap();
    let store_path = temp_dir.path().to_str().unwrap();

    // When: 创建基于文件的 CardStore
    let result = CardStore::new(store_path);

    // Then: 应该成功创建
    assert!(result.is_ok(), "应该能创建基于文件的CardStore");
}

/// 测试: `CardStore初始化后SQLite表存在`
#[test]
fn it_should_initialize_sqlite_tables_on_card_store_creation() {
    // Given: 一个新创建的内存 CardStore
    let store = CardStore::new_in_memory().unwrap();

    // When: 查询所有卡片
    let cards = store.get_all_cards();

    // Then: SQLite 表应该已创建，且初始为空
    assert!(cards.is_ok(), "SQLite表应该已创建");
    assert_eq!(cards.unwrap().len(), 0, "初始应该没有卡片");
}

// ==================== 2. 创建卡片测试 ====================

/// 测试: 创建卡片 - 基本功能
#[test]
fn it_should_create_card() {
    // Given: 一个空的内存 CardStore
    let mut store = CardStore::new_in_memory().unwrap();

    // When: 创建一张新卡片
    let result = store.create_card(
        "测试标题".to_string(),
        "测试内容".to_string(),
        OwnerType::Local,
        None,
        default_peer_id(),
    );

    // Then: 卡片应该创建成功，包含正确的标题、内容和时间戳
    assert!(result.is_ok(), "创建卡片应该成功");

    let card = result.unwrap();
    assert_eq!(card.title, "测试标题");
    assert_eq!(card.content, "测试内容");
    assert!(!card.deleted);
    assert!(card.created_at > 0);
    assert_eq!(card.created_at, card.updated_at);
}

/// 测试: 创建卡片后可以查询到
#[test]
fn it_should_retrieve_created_card() {
    // Given: 一个内存 CardStore 和已创建的卡片
    let mut store = CardStore::new_in_memory().unwrap();

    let card = store
        .create_card(
            "标题".to_string(),
            "内容".to_string(),
            OwnerType::Local,
            None,
            default_peer_id(),
        )
        .unwrap();
    let card_id = card.id;

    // When: 按 ID 查询卡片
    let retrieved = store.get_card_by_id(&card_id);

    // Then: 应该能查询到卡片，且内容正确
    assert!(retrieved.is_ok(), "应该能查询到刚创建的卡片");

    let retrieved_card = retrieved.unwrap();
    assert_eq!(retrieved_card.id, card_id);
    assert_eq!(retrieved_card.title, "标题");
    assert_eq!(retrieved_card.content, "内容");
}

/// 测试: 创建多个卡片
#[test]
fn it_should_create_multiple_cards() {
    // Given: 一个空的内存 CardStore
    let mut store = CardStore::new_in_memory().unwrap();

    // When: 创建三张卡片
    store
        .create_card(
            "卡片1".to_string(),
            "内容1".to_string(),
            OwnerType::Local,
            None,
            default_peer_id(),
        )
        .unwrap();
    store
        .create_card(
            "卡片2".to_string(),
            "内容2".to_string(),
            OwnerType::Local,
            None,
            default_peer_id(),
        )
        .unwrap();
    store
        .create_card(
            "卡片3".to_string(),
            "内容3".to_string(),
            OwnerType::Local,
            None,
            default_peer_id(),
        )
        .unwrap();

    // Then: 应该能查询到所有三张卡片
    let cards = store.get_all_cards().unwrap();
    assert_eq!(cards.len(), 3, "应该有3个卡片");
}

// ==================== 3. 查询卡片测试 ====================

/// 测试: 获取所有卡片（按创建时间倒序）
#[test]
fn it_should_get_all_cards_ordered_by_created_at() {
    // Given: 一个内存 CardStore 和两张按顺序创建的卡片
    let mut store = CardStore::new_in_memory().unwrap();

    let card1 = store
        .create_card(
            "第一个".to_string(),
            "内容1".to_string(),
            OwnerType::Local,
            None,
            default_peer_id(),
        )
        .unwrap();
    std::thread::sleep(std::time::Duration::from_millis(5));

    let card2 = store
        .create_card(
            "第二个".to_string(),
            "内容2".to_string(),
            OwnerType::Local,
            None,
            default_peer_id(),
        )
        .unwrap();

    // When: 获取所有卡片
    let cards = store.get_all_cards().unwrap();

    // Then: 卡片应该按创建时间倒序排列（最新的在前）
    assert_eq!(cards.len(), 2);
    assert_eq!(cards[0].id, card2.id);
    assert_eq!(cards[1].id, card1.id);
}

/// 测试: 获取活跃卡片（排除已删除）
#[test]
fn it_should_get_active_cards_excludes_deleted() {
    // Given: 一个内存 CardStore 和两张卡片，其中一张已软删除
    let mut store = CardStore::new_in_memory().unwrap();

    let card1 = store
        .create_card(
            "卡片1".to_string(),
            "内容1".to_string(),
            OwnerType::Local,
            None,
            default_peer_id(),
        )
        .unwrap();
    let card2 = store
        .create_card(
            "卡片2".to_string(),
            "内容2".to_string(),
            OwnerType::Local,
            None,
            default_peer_id(),
        )
        .unwrap();

    // When: 软删除 card1 并获取活跃卡片
    store.delete_card(&card1.id, default_peer_id()).unwrap();
    let active_cards = store.get_active_cards().unwrap();

    // Then: 应该只返回未删除的卡片
    assert_eq!(active_cards.len(), 1, "应该只有1个活跃卡片");
    assert_eq!(active_cards[0].id, card2.id);
}

/// 测试: 按ID查询不存在的卡片
#[test]
fn it_should_get_card_by_id_not_found() {
    // Given: 一个空的内存 CardStore
    let store = CardStore::new_in_memory().unwrap();

    // When: 查询一个不存在的卡片 ID
    let result = store.get_card_by_id("nonexistent-id");

    // Then: 应该返回 CardNotFound 错误
    assert!(result.is_err(), "查询不存在的卡片应该返回错误");

    match result {
        Err(CardMindError::CardNotFound(id)) => {
            assert_eq!(id, "nonexistent-id");
        }
        _ => panic!("应该返回CardNotFound错误"),
    }
}

// ==================== 4. 更新卡片测试 ====================

/// 测试: 更新卡片标题和内容
#[test]
fn it_should_update_card() {
    // Given: 一个内存 CardStore 和已创建的卡片
    let mut store = CardStore::new_in_memory().unwrap();

    let card = store
        .create_card(
            "旧标题".to_string(),
            "旧内容".to_string(),
            OwnerType::Local,
            None,
            default_peer_id(),
        )
        .unwrap();
    let card_id = card.id.clone();
    let old_updated_at = card.updated_at;

    std::thread::sleep(std::time::Duration::from_millis(10));

    // When: 更新卡片的标题和内容
    let result = store.update_card(
        &card_id,
        Some("新标题".to_string()),
        Some("新内容".to_string()),
        default_peer_id(),
    );

    // Then: 卡片应该更新成功，且 updated_at 应该更新
    assert!(result.is_ok(), "更新卡片应该成功");

    let updated_card = store.get_card_by_id(&card_id).unwrap();
    assert_eq!(updated_card.title, "新标题");
    assert_eq!(updated_card.content, "新内容");
    assert!(
        updated_card.updated_at > old_updated_at,
        "updated_at应该更新"
    );
}

/// 测试: 部分更新（只更新标题）
#[test]
fn it_should_update_card_title_only() {
    // Given: 一个内存 CardStore 和已创建的卡片
    let mut store = CardStore::new_in_memory().unwrap();

    let card = store
        .create_card(
            "旧标题".to_string(),
            "内容".to_string(),
            OwnerType::Local,
            None,
            default_peer_id(),
        )
        .unwrap();
    let card_id = card.id;

    // When: 只更新卡片的标题
    store
        .update_card(
            &card_id,
            Some("新标题".to_string()),
            None,
            default_peer_id(),
        )
        .unwrap();

    // Then: 标题应该更新，内容应该保持不变
    let updated_card = store.get_card_by_id(&card_id).unwrap();
    assert_eq!(updated_card.title, "新标题");
    assert_eq!(updated_card.content, "内容", "内容应该保持不变");
}

/// 测试: 更新不存在的卡片
#[test]
fn it_should_update_nonexistent_card() {
    // Given: 一个空的内存 CardStore
    let mut store = CardStore::new_in_memory().unwrap();

    // When: 尝试更新不存在的卡片
    let result = store.update_card(
        "nonexistent-id",
        Some("标题".to_string()),
        Some("内容".to_string()),
        default_peer_id(),
    );

    // Then: 应该返回错误
    assert!(result.is_err(), "更新不存在的卡片应该返回错误");
}

// ==================== 5. 删除卡片测试 ====================

/// 测试: 软删除卡片
#[test]
fn it_should_delete_card_soft_delete() {
    // Given: 一个内存 CardStore 和已创建的卡片
    let mut store = CardStore::new_in_memory().unwrap();

    let card = store
        .create_card(
            "标题".to_string(),
            "内容".to_string(),
            OwnerType::Local,
            None,
            default_peer_id(),
        )
        .unwrap();
    let card_id = card.id;

    // When: 软删除卡片
    let result = store.delete_card(&card_id, default_peer_id());

    // Then: 卡片应该被标记为删除，且不在活跃列表中
    assert!(result.is_ok(), "删除卡片应该成功");

    let deleted_card = store.get_card_by_id(&card_id).unwrap();
    assert!(deleted_card.deleted, "deleted应该为true");

    let active_cards = store.get_active_cards().unwrap();
    assert_eq!(active_cards.len(), 0, "活跃列表应该为空");
}

/// 测试: 删除不存在的卡片
#[test]
fn it_should_delete_nonexistent_card() {
    // Given: 一个空的内存 CardStore
    let mut store = CardStore::new_in_memory().unwrap();

    // When: 尝试删除不存在的卡片
    let result = store.delete_card("nonexistent-id", default_peer_id());

    // Then: 应该返回错误
    assert!(result.is_err(), "删除不存在的卡片应该返回错误");
}

// ==================== 6. Loro→SQLite同步测试 ====================

/// 测试: `创建卡片后Loro和SQLite数据一致`
#[test]
fn it_should_loro_sqlite_sync_on_create() {
    // Given: 一个内存 CardStore
    let mut store = CardStore::new_in_memory().unwrap();

    // When: 创建一张卡片
    let card = store
        .create_card(
            "标题".to_string(),
            "内容".to_string(),
            OwnerType::Local,
            None,
            default_peer_id(),
        )
        .unwrap();

    // Then: 从 SQLite 查询应该能获取到相同的数据（验证 Loro→SQLite 同步）
    let sqlite_card = store.get_card_by_id(&card.id).unwrap();
    assert_eq!(sqlite_card.id, card.id);
    assert_eq!(sqlite_card.title, card.title);
    assert_eq!(sqlite_card.content, card.content);
}

/// 测试: `更新卡片后Loro和SQLite数据一致`
#[test]
fn it_should_loro_sqlite_sync_on_update() {
    // Given: 一个内存 CardStore 和已创建的卡片
    let mut store = CardStore::new_in_memory().unwrap();

    let card = store
        .create_card(
            "旧标题".to_string(),
            "旧内容".to_string(),
            OwnerType::Local,
            None,
            default_peer_id(),
        )
        .unwrap();
    let card_id = card.id;

    // When: 更新卡片标题
    store
        .update_card(
            &card_id,
            Some("新标题".to_string()),
            None,
            default_peer_id(),
        )
        .unwrap();

    // Then: 从 SQLite 查询应该能获取到更新后的数据（验证 Loro→SQLite 同步）
    let updated_card = store.get_card_by_id(&card_id).unwrap();
    assert_eq!(updated_card.title, "新标题");
}

/// 测试: `删除卡片后Loro和SQLite数据一致`
#[test]
fn it_should_loro_sqlite_sync_on_delete() {
    // Given: 一个内存 CardStore 和已创建的卡片
    let mut store = CardStore::new_in_memory().unwrap();

    let card = store
        .create_card(
            "标题".to_string(),
            "内容".to_string(),
            OwnerType::Local,
            None,
            default_peer_id(),
        )
        .unwrap();
    let card_id = card.id;

    // When: 删除卡片
    store.delete_card(&card_id, default_peer_id()).unwrap();

    // Then: 从 SQLite 查询应该能获取到删除标记（验证 Loro→SQLite 同步）
    let deleted_card = store.get_card_by_id(&card_id).unwrap();
    assert!(deleted_card.deleted, "SQLite中的deleted应该为true");
}

// ==================== 7. 文件持久化测试 ====================

/// 测试: `CardStore持久化到文件后可以重新加载`
#[test]
fn it_should_card_store_persistence() {
    // Given: 一个临时目录和 CardStore 路径
    let temp_dir = TempDir::new().unwrap();
    let store_path = temp_dir.path().to_str().unwrap();
    let card_id;

    // When: 创建 store 并添加卡片后关闭（触发持久化）
    {
        let mut store = CardStore::new(store_path).unwrap();
        let card = store
            .create_card(
                "持久化测试".to_string(),
                "内容".to_string(),
                OwnerType::Local,
                None,
                default_peer_id(),
            )
            .unwrap();
        card_id = card.id;
    } // store dropped，应该自动保存

    // Then: 重新加载 store 应该能恢复之前的数据
    {
        let store = CardStore::new(store_path).unwrap();
        let loaded_card = store.get_card_by_id(&card_id);

        assert!(loaded_card.is_ok(), "应该能从文件重新加载卡片");
        let card = loaded_card.unwrap();
        assert_eq!(card.title, "持久化测试");
        assert_eq!(card.content, "内容");
    }
}

/// 测试: 多次修改后持久化
#[test]
fn it_should_card_store_persistence_after_updates() {
    // Given: 一个临时目录和 CardStore 路径
    let temp_dir = TempDir::new().unwrap();
    let store_path = temp_dir.path().to_str().unwrap();
    let card_id;

    // When: 创建卡片并多次更新后关闭
    {
        let mut store = CardStore::new(store_path).unwrap();
        let card = store
            .create_card(
                "初始标题".to_string(),
                "初始内容".to_string(),
                OwnerType::Local,
                None,
                default_peer_id(),
            )
            .unwrap();
        card_id = card.id;

        // 多次更新
        store
            .update_card(&card_id, Some("更新1".to_string()), None, default_peer_id())
            .unwrap();
        store
            .update_card(&card_id, Some("更新2".to_string()), None, default_peer_id())
            .unwrap();
        store
            .update_card(
                &card_id,
                Some("最终标题".to_string()),
                None,
                default_peer_id(),
            )
            .unwrap();
    }

    // Then: 重新加载 store 应该能恢复最新的数据
    {
        let store = CardStore::new(store_path).unwrap();
        let card = store.get_card_by_id(&card_id).unwrap();
        assert_eq!(card.title, "最终标题");
    }
}

// ==================== 8. 统计功能测试 ====================

/// 测试: 获取卡片数量统计
#[test]
fn it_should_get_card_count() {
    // Given: 一个空的内存 CardStore
    let mut store = CardStore::new_in_memory().unwrap();

    // When: 初始状态时获取卡片数量
    let (total, active, deleted) = store.get_card_count().unwrap();

    // Then: 应该返回 0, 0, 0
    assert_eq!(total, 0);
    assert_eq!(active, 0);
    assert_eq!(deleted, 0);

    // When: 创建 3 张卡片后获取数量
    let card1 = store
        .create_card(
            "卡片1".to_string(),
            "内容1".to_string(),
            OwnerType::Local,
            None,
            default_peer_id(),
        )
        .unwrap();
    store
        .create_card(
            "卡片2".to_string(),
            "内容2".to_string(),
            OwnerType::Local,
            None,
            default_peer_id(),
        )
        .unwrap();
    store
        .create_card(
            "卡片3".to_string(),
            "内容3".to_string(),
            OwnerType::Local,
            None,
            default_peer_id(),
        )
        .unwrap();

    let (total, active, deleted) = store.get_card_count().unwrap();

    // Then: 应该返回 3, 3, 0
    assert_eq!(total, 3);
    assert_eq!(active, 3);
    assert_eq!(deleted, 0);

    // When: 删除 1 张卡片后获取数量
    store.delete_card(&card1.id, default_peer_id()).unwrap();

    let (total, active, deleted) = store.get_card_count().unwrap();

    // Then: 应该返回 3, 2, 1
    assert_eq!(total, 3);
    assert_eq!(active, 2);
    assert_eq!(deleted, 1);
}
