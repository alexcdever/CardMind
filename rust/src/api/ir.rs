// API接口和数据模型定义

use flutter_rust_bridge::frb;

// 卡片相关数据模型

#[frb]
pub struct Card {
    pub id: String,
    pub title: String,
    pub content: String,
    pub created_at: i64,
    pub updated_at: i64,
}


#[frb]
pub struct CreateCardRequest {
    pub title: String,
    pub content: String,
}


#[frb]
pub struct UpdateCardRequest {
    pub id: String,
    pub title: String,
    pub content: String,
}

// 网络相关数据模型

#[frb]
pub struct Network {
    pub id: String,
    pub name: String,
    pub password: String,
    pub created_at: i64,
    pub updated_at: i64,
}


#[frb]
pub struct CreateNetworkRequest {
    pub name: String,
    pub password: String,
}


#[frb]
pub struct UpdateNetworkRequest {
    pub id: String,
    pub name: String,
    pub password: String,
}

// 设备相关数据模型

#[frb]
pub struct Device {
    pub id: String,
    pub name: String,
    pub created_at: i64,
    pub updated_at: i64,
}


#[frb]
pub struct CreateDeviceRequest {
    pub name: String,
}


#[frb]
pub struct UpdateDeviceRequest {
    pub id: String,
    pub name: String,
}

// 网络连接相关请求

#[frb]
pub struct JoinNetworkRequest {
    pub network_id: String,
    pub device_id: String,
}


#[frb]
pub struct LeaveNetworkRequest {
    pub network_id: String,
    pub device_id: String,
}


#[frb]
pub struct SetResidentNetworkRequest {
    pub network_id: String,
    pub device_id: String,
}


#[frb]
pub struct AddCardToNetworkRequest {
    pub card_id: String,
    pub network_id: String,
}


#[frb]
pub struct RemoveCardFromNetworkRequest {
    pub card_id: String,
    pub network_id: String,
}

// API响应封装

#[frb]
pub struct ApiResponse<T> {
    pub success: bool,
    pub message: String,
    pub data: Option<T>,
}

// API服务结构体在impl_模块中定义

