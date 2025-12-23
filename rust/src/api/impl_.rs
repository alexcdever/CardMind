// API接口实现

use flutter_rust_bridge::frb;
use super::ir::*;
use super::error::{ApiError, ApiResult};
use crate::network::Network as NetworkService;
use crate::db::Storage;
use uuid::Uuid;
use log::{debug, info};

// API服务结构体
#[frb(opaque)]
pub struct ApiService {
    network: NetworkService,
    storage: Storage,
}

impl ApiService {
    // 创建新的API服务实例
    #[frb]
    pub async fn new(db_path: &str) -> Result<Self, String> {
        info!("创建新的API服务实例，数据库路径: {}", db_path);
        
        // 初始化网络服务
        debug!("初始化网络服务");
        let network = NetworkService::new()
            .await
            .map_err(|e| format!("Failed to initialize network: {}", e))?;
        info!("网络服务初始化成功");
        
        // 初始化存储服务
        debug!("初始化存储服务，数据库路径: {}", db_path);
        let storage = Storage::new(db_path)
            .await
            .map_err(|e| format!("Failed to initialize storage: {}", e))?;
        info!("存储服务初始化成功");
        
        Ok(Self {
            network,
            storage,
        })
    }
    
    // 卡片管理API
    
    // 创建卡片
    #[frb]
    pub async fn create_card(&self, request: CreateCardRequest) -> Result<Card, String> {
        self.create_card_impl(request).await.map_err(|e| e.into())
    }

    async fn create_card_impl(&self, request: CreateCardRequest) -> ApiResult<Card> {
        use crate::models::card::ActiveModel as CardActiveModel;
        use sea_orm::Set;

        debug!("创建卡片请求: title={}, content={}, device_id={}", request.title, request.content, request.device_id);

        // 输入验证
        if request.title.trim().is_empty() {
            return Err(ApiError::validation("卡片标题不能为空"));
        }
        if request.title.len() > 200 {
            return Err(ApiError::validation("卡片标题不能超过200个字符"));
        }
        if request.content.len() > 100000 {
            return Err(ApiError::validation("卡片内容不能超过100000个字符"));
        }
        if request.device_id.trim().is_empty() {
            return Err(ApiError::validation("设备ID不能为空"));
        }

        let id = Uuid::now_v7();
        let now = chrono::Utc::now().timestamp_millis();

        // 创建卡片活跃模型
        let card = CardActiveModel {
            id: Set(id),
            title: Set(request.title.trim().to_string()),
            content: Set(request.content.clone()),
            created_at: Set(now),
            updated_at: Set(now),
        };

        // 调用存储层创建卡片
        debug!("调用存储层创建卡片");
        let card_model = self.storage.create_card(card).await?;

        info!("卡片创建成功: id={}, title={}", card_model.id, card_model.title);

        // 获取当前设备的常驻网络列表
        debug!("获取设备 {} 的常驻网络列表", request.device_id);
        let resident_networks = self.storage.get_resident_networks(request.device_id.clone()).await?;

        // 自动将卡片加入所有常驻网络
        if !resident_networks.is_empty() {
            info!("将卡片 {} 加入 {} 个常驻网络", card_model.id, resident_networks.len());
            for network_id in resident_networks {
                debug!("将卡片 {} 加入网络 {}", card_model.id, network_id);
                self.storage.add_card_to_network(id, network_id).await?;
            }
        } else {
            debug!("设备 {} 没有常驻网络，跳过自动加入", request.device_id);
        }

        // 转换为IR卡片模型
        Ok(Card {
            id: card_model.id.to_string(),
            title: card_model.title,
            content: card_model.content,
            created_at: card_model.created_at,
            updated_at: card_model.updated_at,
        })
    }
    
    // 更新卡片
    #[frb]
    pub async fn update_card(&self, request: UpdateCardRequest) -> Result<Card, String> {
        self.update_card_impl(request).await.map_err(|e| e.into())
    }

    async fn update_card_impl(&self, request: UpdateCardRequest) -> ApiResult<Card> {
        use crate::models::card::ActiveModel as CardActiveModel;
        use sea_orm::Set;

        debug!("更新卡片请求: id={}, title={}, content={}", request.id, request.title, request.content);

        // 输入验证
        if request.title.trim().is_empty() {
            return Err(ApiError::validation("卡片标题不能为空"));
        }
        if request.title.len() > 200 {
            return Err(ApiError::validation("卡片标题不能超过200个字符"));
        }
        if request.content.len() > 100000 {
            return Err(ApiError::validation("卡片内容不能超过100000个字符"));
        }

        // 解析卡片ID
        let card_id = Uuid::parse_str(&request.id)?;

        let now = chrono::Utc::now().timestamp_millis();

        // 创建卡片活跃模型
        let card = CardActiveModel {
            id: Set(card_id),
            title: Set(request.title.trim().to_string()),
            content: Set(request.content.clone()),
            updated_at: Set(now),
            ..Default::default()
        };

        // 调用存储层更新卡片
        debug!("调用存储层更新卡片");
        let card_model = self.storage.update_card(card).await?;

        info!("卡片更新成功: id={}, title={}", card_model.id, card_model.title);

        // 转换为IR卡片模型
        Ok(Card {
            id: card_model.id.to_string(),
            title: card_model.title,
            content: card_model.content,
            created_at: card_model.created_at,
            updated_at: card_model.updated_at,
        })
    }

    // 删除卡片
    #[frb]
    pub async fn delete_card(&self, id: String) -> Result<(), String> {
        self.delete_card_impl(id).await.map_err(|e| e.into())
    }

    async fn delete_card_impl(&self, id: String) -> ApiResult<()> {
        debug!("删除卡片请求: id={}", id);

        // 解析卡片ID
        let card_id = Uuid::parse_str(&id)?;

        // 调用存储层删除卡片
        self.storage.delete_card(card_id).await?;

        info!("卡片删除成功: id={}", id);
        Ok(())
    }

    // 获取所有卡片
    #[frb]
    pub async fn get_cards(&self) -> Result<Vec<Card>, String> {
        self.get_cards_impl().await.map_err(|e| e.into())
    }

    async fn get_cards_impl(&self) -> ApiResult<Vec<Card>> {
        debug!("获取所有卡片请求");

        // 调用存储层获取所有卡片
        let cards = self.storage.get_cards().await?;

        // 转换为IR卡片模型列表
        let ir_cards: Vec<_> = cards.into_iter().map(|card| Card {
            id: card.id.to_string(),
            title: card.title,
            content: card.content,
            created_at: card.created_at,
            updated_at: card.updated_at,
        }).collect();

        info!("获取卡片成功，共 {} 张卡片", ir_cards.len());
        Ok(ir_cards)
    }
    
    // 网络管理API
    
    // 创建网络
    #[frb]
    pub async fn create_network(&self, request: CreateNetworkRequest) -> Result<Network, String> {
        self.create_network_impl(request).await.map_err(|e| e.into())
    }

    async fn create_network_impl(&self, request: CreateNetworkRequest) -> ApiResult<Network> {
        use crate::models::network::ActiveModel as NetworkActiveModel;
        use sea_orm::Set;

        debug!("创建网络请求: name={}", request.name);

        // 输入验证
        if request.name.trim().is_empty() {
            return Err(ApiError::validation("网络名称不能为空"));
        }
        if request.name.len() > 100 {
            return Err(ApiError::validation("网络名称不能超过100个字符"));
        }
        if request.password.is_empty() {
            return Err(ApiError::validation("网络密码不能为空"));
        }
        if request.password.len() < 6 {
            return Err(ApiError::validation("网络密码至少需要6个字符"));
        }
        if request.password.len() > 100 {
            return Err(ApiError::validation("网络密码不能超过100个字符"));
        }

        let id = Uuid::now_v7();
        let now = chrono::Utc::now().timestamp_millis();

        // 哈希密码
        let password_hash = self.storage.hash_password_public(&request.password)?;

        // 创建网络活跃模型
        let network = NetworkActiveModel {
            id: Set(id),
            name: Set(request.name.trim().to_string()),
            password: Set(password_hash),
            created_at: Set(now),
            updated_at: Set(now),
        };

        // 调用存储层创建网络
        debug!("调用存储层创建网络");
        let network_model = self.storage.create_network(network).await?;

        info!("网络创建成功: id={}, name={}", network_model.id, network_model.name);

        // 转换为IR网络模型 - 不返回密码哈希
        Ok(Network {
            id: network_model.id.to_string(),
            name: network_model.name,
            password: "***".to_string(),
            created_at: network_model.created_at,
            updated_at: network_model.updated_at,
        })
    }

    // 更新网络
    #[frb]
    pub async fn update_network(&self, request: UpdateNetworkRequest) -> Result<Network, String> {
        self.update_network_impl(request).await.map_err(|e| e.into())
    }

    async fn update_network_impl(&self, request: UpdateNetworkRequest) -> ApiResult<Network> {
        use crate::models::network::ActiveModel as NetworkActiveModel;
        use sea_orm::Set;

        debug!("更新网络请求: id={}, name={}", request.id, request.name);

        // 输入验证
        if request.name.trim().is_empty() {
            return Err(ApiError::validation("网络名称不能为空"));
        }
        if request.name.len() > 100 {
            return Err(ApiError::validation("网络名称不能超过100个字符"));
        }
        if request.password.is_empty() {
            return Err(ApiError::validation("网络密码不能为空"));
        }
        if request.password.len() < 6 {
            return Err(ApiError::validation("网络密码至少需要6个字符"));
        }
        if request.password.len() > 100 {
            return Err(ApiError::validation("网络密码不能超过100个字符"));
        }

        // 解析网络ID
        let network_id = Uuid::parse_str(&request.id)?;

        let now = chrono::Utc::now().timestamp_millis();

        // 哈希新密码
        let password_hash = self.storage.hash_password_public(&request.password)?;

        // 创建网络活跃模型
        let network = NetworkActiveModel {
            id: Set(network_id),
            name: Set(request.name.trim().to_string()),
            password: Set(password_hash),
            updated_at: Set(now),
            ..Default::default()
        };

        // 调用存储层更新网络
        debug!("调用存储层更新网络");
        let network_model = self.storage.update_network(network).await?;

        info!("网络更新成功: id={}", network_model.id);

        // 转换为IR网络模型 - 不返回密码哈希
        Ok(Network {
            id: network_model.id.to_string(),
            name: network_model.name,
            password: "***".to_string(),
            created_at: network_model.created_at,
            updated_at: network_model.updated_at,
        })
    }

    // 删除网络
    #[frb]
    pub async fn delete_network(&self, id: String) -> Result<(), String> {
        self.delete_network_impl(id).await.map_err(|e| e.into())
    }

    async fn delete_network_impl(&self, id: String) -> ApiResult<()> {
        debug!("删除网络请求: id={}", id);

        // 解析网络ID
        let network_id = Uuid::parse_str(&id)?;

        // 调用存储层删除网络
        self.storage.delete_network(network_id).await?;

        info!("网络删除成功: id={}", id);
        Ok(())
    }

    // 获取所有网络
    #[frb]
    pub async fn get_networks(&self) -> Result<Vec<Network>, String> {
        self.get_networks_impl().await.map_err(|e| e.into())
    }

    async fn get_networks_impl(&self) -> ApiResult<Vec<Network>> {
        debug!("获取所有网络请求");

        // 调用存储层获取所有网络
        let networks = self.storage.get_networks().await?;

        // 转换为IR网络模型列表 - 不返回密码哈希
        let ir_networks: Vec<_> = networks.into_iter().map(|network| Network {
            id: network.id.to_string(),
            name: network.name,
            password: "***".to_string(),
            created_at: network.created_at,
            updated_at: network.updated_at,
        }).collect();

        info!("获取网络成功，共 {} 个网络", ir_networks.len());
        Ok(ir_networks)
    }
    
    // 设备管理API
    
    // 创建设备
    #[frb]
    pub async fn create_device(&self, request: CreateDeviceRequest) -> Result<Device, String> {
        self.create_device_impl(request).await.map_err(|e| e.into())
    }

    async fn create_device_impl(&self, request: CreateDeviceRequest) -> ApiResult<Device> {
        use crate::models::device::ActiveModel as DeviceActiveModel;
        use sea_orm::Set;

        debug!("创建设备请求: name={}", request.name);

        // 输入验证
        if request.name.trim().is_empty() {
            return Err(ApiError::validation("设备名称不能为空"));
        }
        if request.name.len() > 100 {
            return Err(ApiError::validation("设备名称不能超过100个字符"));
        }

        // 使用设备指纹作为ID（从Flutter端传入）
        let device_id = request.name.trim().to_string();
        let now = chrono::Utc::now().timestamp_millis();

        // 创建设备活跃模型
        let device = DeviceActiveModel {
            id: Set(device_id.clone()),
            name: Set(request.name.trim().to_string()),
            created_at: Set(now),
            updated_at: Set(now),
        };

        // 调用存储层创建设备
        debug!("调用存储层创建设备");
        let device_model = self.storage.create_device(device).await?;

        info!("设备创建成功: id={}, name={}", device_model.id, device_model.name);

        // 转换为IR设备模型
        Ok(Device {
            id: device_model.id,
            name: device_model.name,
            created_at: device_model.created_at,
            updated_at: device_model.updated_at,
        })
    }

    // 获取所有设备
    #[frb]
    pub async fn get_devices(&self) -> Result<Vec<Device>, String> {
        self.get_devices_impl().await.map_err(|e| e.into())
    }

    async fn get_devices_impl(&self) -> ApiResult<Vec<Device>> {
        debug!("获取所有设备请求");

        // 调用存储层获取所有设备
        let devices = self.storage.get_devices().await?;

        // 转换为IR设备模型列表
        let ir_devices: Vec<_> = devices.into_iter().map(|device| Device {
            id: device.id,
            name: device.name,
            created_at: device.created_at,
            updated_at: device.updated_at,
        }).collect();

        info!("获取设备成功，共 {} 个设备", ir_devices.len());
        Ok(ir_devices)
    }
    
    // 网络连接API
    
    // 加入网络
    #[frb]
    pub async fn join_network(&self, request: JoinNetworkRequest) -> Result<(), String> {
        self.join_network_impl(request).await.map_err(|e| e.into())
    }

    async fn join_network_impl(&self, request: JoinNetworkRequest) -> ApiResult<()> {
        debug!("加入网络请求: network_id={}, device_id={}", request.network_id, request.device_id);

        // 解析网络ID
        let network_id = Uuid::parse_str(&request.network_id)?;

        // 获取网络信息以验证密码
        let network = self.storage.get_network(network_id).await?
            .ok_or_else(|| ApiError::not_found("网络不存在"))?;

        // 验证密码
        let password_valid = self.storage.verify_password_public(&request.password, &network.password)?;
        if !password_valid {
            return Err(ApiError::permission_denied("网络密码错误"));
        }

        // 调用存储层加入网络
        self.storage.join_network(network_id, request.device_id.clone()).await?;

        info!("设备加入网络成功: device_id={}, network_id={}", request.device_id, request.network_id);
        Ok(())
    }

    // 退出网络
    #[frb]
    pub async fn leave_network(&self, request: LeaveNetworkRequest) -> Result<(), String> {
        self.leave_network_impl(request).await.map_err(|e| e.into())
    }

    async fn leave_network_impl(&self, request: LeaveNetworkRequest) -> ApiResult<()> {
        debug!("退出网络请求: network_id={}, device_id={}", request.network_id, request.device_id);

        // 解析网络ID
        let network_id = Uuid::parse_str(&request.network_id)?;

        // 检查设备在该网络中的卡片数量
        let card_count = self.storage.count_device_cards_in_network(request.device_id.clone(), network_id).await?;

        // 如果有卡片，返回错误提示
        if card_count > 0 {
            return Err(ApiError::business(format!("该网络中有 {} 张卡片，请先移除这些卡片再退出网络", card_count)));
        }

        // 调用存储层退出网络
        self.storage.leave_network(network_id, request.device_id.clone()).await?;

        info!("设备退出网络成功: device_id={}, network_id={}", request.device_id, request.network_id);
        Ok(())
    }

    // 设置常驻网络
    #[frb]
    pub async fn set_resident_network(&self, request: SetResidentNetworkRequest) -> Result<(), String> {
        self.set_resident_network_impl(request).await.map_err(|e| e.into())
    }

    async fn set_resident_network_impl(&self, request: SetResidentNetworkRequest) -> ApiResult<()> {
        debug!("设置常驻网络请求: network_id={}, device_id={}", request.network_id, request.device_id);

        // 解析网络ID
        let network_id = Uuid::parse_str(&request.network_id)?;

        // 调用存储层设置常驻网络
        self.storage.set_resident_network(network_id, request.device_id.clone()).await?;

        info!("常驻网络设置成功: device_id={}, network_id={}", request.device_id, request.network_id);
        Ok(())
    }

    // 取消常驻网络
    #[frb]
    pub async fn unset_resident_network(&self, device_id: String) -> Result<(), String> {
        self.unset_resident_network_impl(device_id).await.map_err(|e| e.into())
    }

    async fn unset_resident_network_impl(&self, device_id: String) -> ApiResult<()> {
        debug!("取消常驻网络请求: device_id={}", device_id);

        // 调用存储层取消常驻网络
        self.storage.unset_resident_network(device_id.clone()).await?;

        info!("常驻网络取消成功: device_id={}", device_id);
        Ok(())
    }
    
    // 卡片-网络关系API
    
    // 将卡片添加到网络
    #[frb]
    pub async fn add_card_to_network(&self, request: AddCardToNetworkRequest) -> Result<(), String> {
        self.add_card_to_network_impl(request).await.map_err(|e| e.into())
    }

    async fn add_card_to_network_impl(&self, request: AddCardToNetworkRequest) -> ApiResult<()> {
        debug!("将卡片添加到网络请求: card_id={}, network_id={}", request.card_id, request.network_id);

        // 解析 UUID
        let card_id = Uuid::parse_str(&request.card_id)?;
        let network_id = Uuid::parse_str(&request.network_id)?;

        // 调用 storage 层
        self.storage.add_card_to_network(card_id, network_id).await?;

        info!("卡片添加到网络成功: card_id={}, network_id={}", request.card_id, request.network_id);
        Ok(())
    }

    // 将卡片从网络中移除
    #[frb]
    pub async fn remove_card_from_network(&self, request: RemoveCardFromNetworkRequest) -> Result<(), String> {
        self.remove_card_from_network_impl(request).await.map_err(|e| e.into())
    }

    async fn remove_card_from_network_impl(&self, request: RemoveCardFromNetworkRequest) -> ApiResult<()> {
        debug!("将卡片从网络中移除请求: card_id={}, network_id={}", request.card_id, request.network_id);

        // 解析卡片ID和网络ID
        let card_id = Uuid::parse_str(&request.card_id)?;
        let network_id = Uuid::parse_str(&request.network_id)?;

        // 调用存储层从网络中移除卡片
        self.storage.remove_card_from_network(card_id, network_id).await?;

        info!("卡片从网络中移除成功: card_id={}, network_id={}", request.card_id, request.network_id);
        Ok(())
    }
}