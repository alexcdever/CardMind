use crate::models::*;
use crate::db::Storage;
use crate::api::ir::{Card as IrCard, Network as IrNetwork, Device as IrDevice};
use uuid::Uuid;
use sea_orm::Set;
use flutter_rust_bridge::frb;

// API实现结构体
pub struct ApiImpl {
    storage: Storage,
}

impl ApiImpl {
    pub fn new(storage: Storage) -> Self {
        Self {
            storage,
        }
    }
}

// 实现IR中定义的API trait
#[frb(mirror(Api))]
impl ApiImpl {
    // 卡片管理
    
    // 创建一张新卡片
    pub async fn create_card(&self, title: String, content: String) -> IrCard {
        let id = Uuid::now_v7();
        let now = chrono::Utc::now().timestamp_millis();
        
        // 创建卡片活跃模型
        let card = card::ActiveModel {
            id: Set(id),
            title: Set(title.clone()),
            content: Set(content.clone()),
            created_at: Set(now),
            updated_at: Set(now),
            loro_doc: Set(vec![]),
        };
        
        // 调用存储层创建卡片
        let result = self.storage.create_card(card).await;
        let card_model = result.expect("创建卡片失败");
        
        // 转换为IR卡片模型
        IrCard {
            id: card_model.id,
            title: card_model.title,
            content: card_model.content,
            created_at: card_model.created_at,
            updated_at: card_model.updated_at,
        }
    }
    
    // 更新现有卡片
    pub async fn update_card(&self, id: String, title: String, content: String) -> IrCard {
        // 解析UUID
        let card_id = Uuid::parse_str(&id).expect("无效的卡片ID格式");
        
        // 获取当前卡片
        let current_card = self.storage.get_card(card_id).await
            .expect("获取卡片失败")
            .expect("卡片不存在");
        
        // 创建更新后的卡片活跃模型
        let card = card::ActiveModel {
            id: Set(card_id),
            title: Set(title.clone()),
            content: Set(content.clone()),
            created_at: Set(current_card.created_at),
            updated_at: Set(chrono::Utc::now().timestamp_millis()),
            loro_doc: Set(current_card.loro_doc),
        };
        
        // 调用存储层更新卡片
        let result = self.storage.update_card(card).await;
        let card_model = result.expect("更新卡片失败");
        
        // 转换为IR卡片模型
        IrCard {
            id: card_model.id,
            title: card_model.title,
            content: card_model.content,
            created_at: card_model.created_at,
            updated_at: card_model.updated_at,
        }
    }
    
    // 删除卡片
    pub async fn delete_card(&self, id: String) -> bool {
        // 解析UUID
        let card_id = Uuid::parse_str(&id).expect("无效的卡片ID格式");
        
        // 调用存储层删除卡片
        let result = self.storage.delete_card(card_id).await;
        result.is_ok()
    }
    
    // 获取所有卡片
    pub async fn get_cards(&self) -> Vec<IrCard> {
        // 调用存储层获取所有卡片
        let result = self.storage.get_cards().await;
        let cards = result.expect("获取卡片列表失败");
        
        // 转换为IR卡片模型列表
        cards.into_iter().map(|card| IrCard {
            id: card.id,
            title: card.title,
            content: card.content,
            created_at: card.created_at,
            updated_at: card.updated_at,
        }).collect()
    }
    
    // 通过ID获取单个卡片
    pub async fn get_card(&self, id: String) -> Option<IrCard> {
        // 解析UUID
        let card_id = Uuid::parse_str(&id).expect("无效的卡片ID格式");
        
        // 调用存储层获取卡片
        let result = self.storage.get_card(card_id).await;
        let card_option = result.expect("获取卡片失败");
        
        // 转换为IR卡片模型
        card_option.map(|card| IrCard {
            id: card.id,
            title: card.title,
            content: card.content,
            created_at: card.created_at,
            updated_at: card.updated_at,
        })
    }
    
    // 将卡片添加到网络
    pub async fn add_card_to_network(&self, card_id: String, network_id: String) -> bool {
        // 解析UUID
        let card_uuid = Uuid::parse_str(&card_id).expect("无效的卡片ID格式");
        let network_uuid = Uuid::parse_str(&network_id).expect("无效的网络ID格式");
        
        // 调用存储层添加卡片到网络
        let result = self.storage.add_card_to_network(card_uuid, network_uuid).await;
        result.is_ok()
    }
    
    // 将卡片从网络中移除
    pub async fn remove_card_from_network(&self, card_id: String, network_id: String) -> bool {
        // 解析UUID
        let card_uuid = Uuid::parse_str(&card_id).expect("无效的卡片ID格式");
        let network_uuid = Uuid::parse_str(&network_id).expect("无效的网络ID格式");
        
        // 调用存储层将卡片从网络中移除
        let result = self.storage.remove_card_from_network(card_uuid, network_uuid).await;
        result.is_ok()
    }
    
    // 网络管理
    
    // 创建新网络
    pub async fn create_network(&self, name: String, password: String) -> IrNetwork {
        let id = Uuid::now_v7();
        let now = chrono::Utc::now().timestamp_millis();
        
        // 创建网络活跃模型
        let network = network::ActiveModel {
            id: Set(id),
            name: Set(name.clone()),
            password: Set(password.clone()),
            created_at: Set(now),
            updated_at: Set(now),
            loro_doc: Set(vec![]),
        };
        
        // 调用存储层创建网络
        let result = self.storage.create_network(network).await;
        let network_model = result.expect("创建网络失败");
        
        // 转换为IR网络模型
        IrNetwork {
            id: network_model.id,
            name: network_model.name,
            password: network_model.password,
            created_at: network_model.created_at,
            updated_at: network_model.updated_at,
            device_ids: vec![], // 初始设备列表为空
        }
    }
    
    // 加入现有网络
    pub async fn join_network(&self, id: String, password: String) -> IrNetwork {
        // 解析UUID
        let network_id = Uuid::parse_str(&id).expect("无效的网络ID格式");
        
        // 获取网络
        let network_model = self.storage.get_network(network_id).await
            .expect("获取网络失败")
            .expect("网络不存在");
        
        // 验证密码
        if network_model.password != password {
            panic!("密码错误");
        }
        
        // TODO: 实现设备加入网络的逻辑
        
        // 转换为IR网络模型
        IrNetwork {
            id: network_model.id,
            name: network_model.name,
            password: network_model.password,
            created_at: network_model.created_at,
            updated_at: network_model.updated_at,
            device_ids: vec![], // TODO: 获取真实的设备列表
        }
    }
    
    // 退出网络
    pub async fn leave_network(&self, id: String) -> bool {
        // 解析UUID
        let network_id = Uuid::parse_str(&id).expect("无效的网络ID格式");
        
        // TODO: 实现设备退出网络的逻辑
        
        true
    }
    
    // 获取所有网络
    pub async fn get_networks(&self) -> Vec<IrNetwork> {
        // 调用存储层获取所有网络
        let result = self.storage.get_networks().await;
        let networks = result.expect("获取网络列表失败");
        
        // 转换为IR网络模型列表
        networks.into_iter().map(|network| IrNetwork {
            id: network.id,
            name: network.name,
            password: network.password,
            created_at: network.created_at,
            updated_at: network.updated_at,
            device_ids: vec![], // TODO: 获取真实的设备列表
        }).collect()
    }
    
    // 重命名网络
    pub async fn rename_network(&self, id: String, name: String) -> IrNetwork {
        // 解析UUID
        let network_id = Uuid::parse_str(&id).expect("无效的网络ID格式");
        
        // 获取当前网络
        let current_network = self.storage.get_network(network_id).await
            .expect("获取网络失败")
            .expect("网络不存在");
        
        // 创建更新后的网络活跃模型
        let network = network::ActiveModel {
            id: Set(network_id),
            name: Set(name.clone()),
            password: Set(current_network.password),
            created_at: Set(current_network.created_at),
            updated_at: Set(chrono::Utc::now().timestamp_millis()),
            loro_doc: Set(current_network.loro_doc),
        };
        
        // 调用存储层更新网络
        let result = self.storage.update_network(network).await;
        let network_model = result.expect("更新网络失败");
        
        // 转换为IR网络模型
        IrNetwork {
            id: network_model.id,
            name: network_model.name,
            password: network_model.password,
            created_at: network_model.created_at,
            updated_at: network_model.updated_at,
            device_ids: vec![], // TODO: 获取真实的设备列表
        }
    }
    
    // 设置网络为常驻网络或取消
    pub async fn set_resident_network(&self, network_id: String, is_resident: bool) -> bool {
        // 解析UUID
        let network_uuid = Uuid::parse_str(&network_id).expect("无效的网络ID格式");
        
        // TODO: 获取当前设备ID
        let device_id = "test_device_id".to_string();
        
        if is_resident {
            // 设置为常驻网络
            let result = self.storage.set_resident_network(network_uuid, device_id).await;
            result.is_ok()
        } else {
            // 取消常驻网络
            let result = self.storage.unset_resident_network(device_id).await;
            result.is_ok()
        }
    }
    
    // 设备管理
    
    // 获取所有设备
    pub async fn get_devices(&self) -> Vec<IrDevice> {
        // 调用存储层获取所有设备
        let result = self.storage.get_devices().await;
        let devices = result.expect("获取设备列表失败");
        
        // 转换为IR设备模型列表
        devices.into_iter().map(|device| IrDevice {
            id: device.id,
            name: device.name,
            created_at: device.created_at,
            updated_at: device.updated_at,
        }).collect()
    }
    
    // 更新设备名称
    pub async fn update_device_name(&self, id: String, name: String) -> IrDevice {
        // 获取当前设备
        let current_device = self.storage.get_device(id.clone()).await
            .expect("获取设备失败")
            .expect("设备不存在");
        
        // 创建更新后的设备活跃模型
        let device = device::ActiveModel {
            id: Set(id.clone()),
            name: Set(name.clone()),
            created_at: Set(current_device.created_at),
            updated_at: Set(chrono::Utc::now().timestamp_millis()),
        };
        
        // 调用存储层更新设备
        let result = self.storage.update_device(device).await;
        let device_model = result.expect("更新设备失败");
        
        // 转换为IR设备模型
        IrDevice {
            id: device_model.id,
            name: device_model.name,
            created_at: device_model.created_at,
            updated_at: device_model.updated_at,
        }
    }
}