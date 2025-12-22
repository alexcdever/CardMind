// 存储层测试用例

use cardmind_rust::storage::Storage;
use cardmind_rust::models::card::ActiveModel as CardActiveModel;
use cardmind_rust::models::network::ActiveModel as NetworkActiveModel;
use cardmind_rust::models::device::ActiveModel as DeviceActiveModel;
use sea_orm::Set;
use uuid::Uuid;

// 测试数据库连接和迁移
#[tokio::test]
async fn test_database_initialization() {
    // 使用内存数据库进行测试
    let storage = Storage::new(":memory:").await;
    assert!(storage.is_ok(), "数据库初始化失败");
}

// 测试卡片CRUD操作
#[tokio::test]
async fn test_card_crud() {
    // 使用内存数据库进行测试
    let storage = Storage::new(":memory:").await.unwrap();
    
    // 创建测试卡片
    let id = Uuid::now_v7();
    let now = 1234567890;
    
    let card = CardActiveModel {
        id: Set(id),
        title: Set("测试卡片".to_string()),
        content: Set("测试内容".to_string()),
        created_at: Set(now),
        updated_at: Set(now),
        loro_doc: Set(vec![]),
    };
    
    // 创建卡片
    let created_card = storage.create_card(card).await;
    assert!(created_card.is_ok(), "创建卡片失败");
    
    let created_card = created_card.unwrap();
    assert_eq!(created_card.id, id, "卡片ID不匹配");
    assert_eq!(created_card.title, "测试卡片", "卡片标题不匹配");
    assert_eq!(created_card.content, "测试内容", "卡片内容不匹配");
    
    // 获取所有卡片
    let cards = storage.get_cards().await;
    assert!(cards.is_ok(), "获取卡片列表失败");
    assert_eq!(cards.unwrap().len(), 1, "卡片数量不匹配");
    
    // 获取单个卡片
    let card = storage.get_card(id).await;
    assert!(card.is_ok(), "获取单个卡片失败");
    assert!(card.unwrap().is_some(), "卡片不存在");
    
    // 更新卡片
    let updated_card = CardActiveModel {
        id: Set(id),
        title: Set("更新后的卡片".to_string()),
        content: Set("更新后的内容".to_string()),
        created_at: Set(now),
        updated_at: Set(now + 1),
        loro_doc: Set(vec![]),
    };
    
    let updated_result = storage.update_card(updated_card).await;
    assert!(updated_result.is_ok(), "更新卡片失败");
    
    let updated_card = updated_result.unwrap();
    assert_eq!(updated_card.title, "更新后的卡片", "更新后的卡片标题不匹配");
    assert_eq!(updated_card.content, "更新后的内容", "更新后的卡片内容不匹配");
    
    // 删除卡片
    let delete_result = storage.delete_card(id).await;
    assert!(delete_result.is_ok(), "删除卡片失败");
    
    // 验证卡片已删除
    let cards = storage.get_cards().await;
    assert!(cards.is_ok(), "获取卡片列表失败");
    assert_eq!(cards.unwrap().len(), 0, "卡片删除失败");
}

// 测试网络CRUD操作
#[tokio::test]
async fn test_network_crud() {
    // 使用内存数据库进行测试
    let storage = Storage::new(":memory:").await.unwrap();
    
    // 创建测试网络
    let id = Uuid::now_v7();
    let now = 1234567890;
    
    let network = NetworkActiveModel {
        id: Set(id),
        name: Set("测试网络".to_string()),
        password: Set("test_password".to_string()),
        created_at: Set(now),
        updated_at: Set(now),
        loro_doc: Set(vec![]),
    };
    
    // 创建网络
    let created_network = storage.create_network(network).await;
    assert!(created_network.is_ok(), "创建网络失败");
    
    let created_network = created_network.unwrap();
    assert_eq!(created_network.id, id, "网络ID不匹配");
    assert_eq!(created_network.name, "测试网络", "网络名称不匹配");
    assert_eq!(created_network.password, "test_password", "网络密码不匹配");
    
    // 获取所有网络
    let networks = storage.get_networks().await;
    assert!(networks.is_ok(), "获取网络列表失败");
    assert_eq!(networks.unwrap().len(), 1, "网络数量不匹配");
    
    // 获取单个网络
    let network = storage.get_network(id).await;
    assert!(network.is_ok(), "获取单个网络失败");
    assert!(network.unwrap().is_some(), "网络不存在");
}

// 测试设备CRUD操作
#[tokio::test]
async fn test_device_crud() {
    // 使用内存数据库进行测试
    let storage = Storage::new(":memory:").await.unwrap();
    
    // 创建测试设备
    let device_id = "test_device_id".to_string();
    let now = 1234567890;
    
    let device = DeviceActiveModel {
        id: Set(device_id.clone()),
        name: Set("测试设备".to_string()),
        created_at: Set(now),
        updated_at: Set(now),
    };
    
    // 创建设备
    let created_device = storage.create_device(device).await;
    assert!(created_device.is_ok(), "创建设备失败");
    
    let created_device = created_device.unwrap();
    assert_eq!(created_device.id, device_id, "设备ID不匹配");
    assert_eq!(created_device.name, "测试设备", "设备名称不匹配");
    
    // 获取所有设备
    let devices = storage.get_devices().await;
    assert!(devices.is_ok(), "获取设备列表失败");
    assert_eq!(devices.unwrap().len(), 1, "设备数量不匹配");
}

// 测试卡片-网络关系
#[tokio::test]
async fn test_card_network_relation() {
    // 使用内存数据库进行测试
    let storage = Storage::new(":memory:").await.unwrap();
    
    // 创建测试卡片
    let card_id = Uuid::now_v7();
    let now = 1234567890;
    
    let card = CardActiveModel {
        id: Set(card_id),
        title: Set("测试卡片".to_string()),
        content: Set("测试内容".to_string()),
        created_at: Set(now),
        updated_at: Set(now),
        loro_doc: Set(vec![]),
    };
    
    let created_card = storage.create_card(card).await.unwrap();
    
    // 创建测试网络
    let network_id = Uuid::now_v7();
    
    let network = NetworkActiveModel {
        id: Set(network_id),
        name: Set("测试网络".to_string()),
        password: Set("test_password".to_string()),
        created_at: Set(now),
        updated_at: Set(now),
        loro_doc: Set(vec![]),
    };
    
    let created_network = storage.create_network(network).await.unwrap();
    
    // 添加卡片到网络
    let add_result = storage.add_card_to_network(created_card.id, created_network.id).await;
    assert!(add_result.is_ok(), "添加卡片到网络失败");
    
    // 从网络中移除卡片
    let remove_result = storage.remove_card_from_network(created_card.id, created_network.id).await;
    assert!(remove_result.is_ok(), "从网络中移除卡片失败");
}

// 测试常驻网络设置
#[tokio::test]
async fn test_resident_network() {
    // 使用内存数据库进行测试
    let storage = Storage::new(":memory:").await.unwrap();
    
    // 创建测试网络
    let network_id = Uuid::now_v7();
    let now = 1234567890;
    
    let network = NetworkActiveModel {
        id: Set(network_id),
        name: Set("测试网络".to_string()),
        password: Set("test_password".to_string()),
        created_at: Set(now),
        updated_at: Set(now),
        loro_doc: Set(vec![]),
    };
    
    let created_network = storage.create_network(network).await.unwrap();
    
    // 设置常驻网络
    let device_id = "test_device_id".to_string();
    
    let set_result = storage.set_resident_network(created_network.id, device_id.clone()).await;
    assert!(set_result.is_ok(), "设置常驻网络失败");
    
    // 取消常驻网络
    let unset_result = storage.unset_resident_network(device_id).await;
    assert!(unset_result.is_ok(), "取消常驻网络失败");
}

// 测试网络-设备关系
#[tokio::test]
async fn test_network_device_relation() {
    // 使用内存数据库进行测试
    let storage = Storage::new(":memory:").await.unwrap();
    
    // 创建测试网络
    let network_id = Uuid::now_v7();
    let now = 1234567890;
    
    let network = NetworkActiveModel {
        id: Set(network_id),
        name: Set("测试网络".to_string()),
        password: Set("test_password".to_string()),
        created_at: Set(now),
        updated_at: Set(now),
        loro_doc: Set(vec![]),
    };
    
    let created_network = storage.create_network(network).await.unwrap();
    
    // 创建测试设备
    let device_id = "test_device_id".to_string();
    
    let device = DeviceActiveModel {
        id: Set(device_id.clone()),
        name: Set("测试设备".to_string()),
        created_at: Set(now),
        updated_at: Set(now),
    };
    
    let created_device = storage.create_device(device).await.unwrap();
    
    // 加入网络
    let join_result = storage.join_network(created_network.id, created_device.id).await;
    assert!(join_result.is_ok(), "加入网络失败");
    
    // 退出网络
    let leave_result = storage.leave_network(created_network.id, created_device.id).await;
    assert!(leave_result.is_ok(), "退出网络失败");
}
