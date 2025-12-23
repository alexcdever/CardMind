// CRDT 管理器的集成测试

use cardmind_rust::crdt::CrdtManager;
use cardmind_rust::models::card;
use tempfile::TempDir;
use uuid::Uuid;

/// 创建测试用的 CRDT 管理器
async fn create_test_manager() -> (CrdtManager, TempDir) {
    let temp_dir = TempDir::new().unwrap();
    let loro_root = temp_dir.path().join("loro");
    let manager = CrdtManager::new(loro_root).await.unwrap();
    (manager, temp_dir)
}

/// 创建测试用的卡片模型
fn create_test_card(id: Uuid, title: &str, content: &str) -> card::Model {
    let now = chrono::Utc::now().timestamp_millis();
    card::Model {
        id,
        title: title.to_string(),
        content: content.to_string(),
        created_at: now,
        updated_at: now,
    }
}

#[tokio::test]
async fn test_create_and_read_card_doc() {
    let (manager, _temp_dir) = create_test_manager().await;
    let card_id = Uuid::now_v7();
    let card = create_test_card(card_id, "测试标题", "测试内容");

    // 创建文档
    manager.create_card_doc(&card).await.unwrap();

    // 读取文档
    let read_card = manager.read_card_from_doc(card_id).await.unwrap();
    assert_eq!(read_card.id, card_id);
    assert_eq!(read_card.title, "测试标题");
    assert_eq!(read_card.content, "测试内容");
    assert_eq!(read_card.created_at, card.created_at);
    assert_eq!(read_card.updated_at, card.updated_at);
}

#[tokio::test]
async fn test_update_card_doc() {
    let (manager, _temp_dir) = create_test_manager().await;
    let card_id = Uuid::now_v7();
    let card = create_test_card(card_id, "原标题", "原内容");

    // 创建文档
    manager.create_card_doc(&card).await.unwrap();

    // 等待一小段时间以确保时间戳不同
    tokio::time::sleep(tokio::time::Duration::from_millis(10)).await;

    // 更新文档
    let updated_card = card::Model {
        id: card_id,
        title: "新标题".to_string(),
        content: "新内容".to_string(),
        created_at: card.created_at,
        updated_at: chrono::Utc::now().timestamp_millis(),
    };
    manager.update_card_doc(&updated_card).await.unwrap();

    // 验证更新
    let read_card = manager.read_card_from_doc(card_id).await.unwrap();
    assert_eq!(read_card.id, card_id);
    assert_eq!(read_card.title, "新标题");
    assert_eq!(read_card.content, "新内容");
    assert_eq!(read_card.created_at, card.created_at); // created_at 应保持不变
    assert_eq!(read_card.updated_at, updated_card.updated_at); // updated_at 应该更新
}

#[tokio::test]
async fn test_file_persistence() {
    let temp_dir = TempDir::new().unwrap();
    let loro_root = temp_dir.path().join("loro");
    let card_id = Uuid::now_v7();
    let card = create_test_card(card_id, "持久化测试", "测试内容");

    // 第一个管理器：创建文档
    {
        let manager = CrdtManager::new(loro_root.clone()).await.unwrap();
        manager.create_card_doc(&card).await.unwrap();
    }

    // 第二个管理器：从文件加载
    {
        let manager = CrdtManager::new(loro_root.clone()).await.unwrap();
        let read_card = manager.read_card_from_doc(card_id).await.unwrap();
        assert_eq!(read_card.id, card_id);
        assert_eq!(read_card.title, "持久化测试");
        assert_eq!(read_card.content, "测试内容");
        assert_eq!(read_card.created_at, card.created_at);
        assert_eq!(read_card.updated_at, card.updated_at);
    }
}

#[tokio::test]
async fn test_extract_id_and_sync() {
    let (manager, _temp_dir) = create_test_manager().await;
    let card_id = Uuid::now_v7();
    let card = create_test_card(card_id, "分布式测试", "同步内容");

    // 创建文档
    manager.create_card_doc(&card).await.unwrap();

    // 导出文档数据（模拟发送到远程）
    let exported_bytes = manager.export_card_for_sync(card_id).await.unwrap();

    // 从导出的数据中提取 ID（模拟远程接收）
    let extracted_id = CrdtManager::extract_card_id_from_bytes(&exported_bytes).unwrap();
    assert_eq!(extracted_id, card_id);

    // 模拟远程设备同步（创建新的管理器）
    let temp_dir2 = tempfile::TempDir::new().unwrap();
    let loro_root2 = temp_dir2.path().join("loro");
    let remote_manager = CrdtManager::new(loro_root2).await.unwrap();

    // 使用 sync_card_from_remote 自动识别并合并
    let synced_id = remote_manager.sync_card_from_remote(&exported_bytes).await.unwrap();
    assert_eq!(synced_id, card_id);

    // 验证同步后的内容
    let read_card = remote_manager.read_card_from_doc(card_id).await.unwrap();
    assert_eq!(read_card.id, card_id);
    assert_eq!(read_card.title, "分布式测试");
    assert_eq!(read_card.content, "同步内容");
    assert_eq!(read_card.created_at, card.created_at);
    assert_eq!(read_card.updated_at, card.updated_at);
}
