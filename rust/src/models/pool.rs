//! # 数据池模型
//!
//! 定义 CardMind 应用的数据池（Pool）领域模型，用于多设备间的数据同步和协作。
//!
//! ## 数据结构
//!
//! - `Pool` - 数据池元数据，包含池成员和关联卡片
//! - `PoolMember` - 数据池成员信息
//!
//! ## 设计说明
//!
//! 数据池是 CardMind 的核心协作单元：
//! - 一个数据池可包含多个成员（设备）
//! - 池内成员共享池中的卡片数据
//! - 支持管理员与普通成员的角色区分
//! - 通过 `endpoint_id` 标识不同设备实例
//!
//! ## 使用场景
//!
//! - **建池**: 创建新的数据池，初始成员自动成为管理员
//! - **入池**: 新设备通过邀请加入现有数据池
//! - **同步**: 池内成员间进行实时或异步数据同步
//!
//! ## 示例
//!
//! ```rust
//! use uuid::Uuid;
//! use cardmind_rust::models::pool::{Pool, PoolMember};
//!
//! // 创建成员
//! let member = PoolMember {
//!     endpoint_id: "desktop-abc123".to_string(),
//!     nickname: "我的工作电脑".to_string(),
//!     os: "macOS".to_string(),
//!     is_admin: true,
//! };
//!
//! // 创建数据池
//! let pool = Pool {
//!     pool_id: Uuid::now_v7(),
//!     members: vec![member],
//!     card_ids: vec![],
//! };
//! ```

use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// 数据池元数据
///
/// 表示一个协作数据池，包含池的唯一标识、成员列表和关联的卡片 ID。
/// 数据池是 CardMind 多设备同步的基本单元。
///
/// # 字段说明
///
/// - `pool_id`: 数据池唯一标识符（UUID v7）
/// - `members`: 池成员列表，包含所有加入该池的设备信息
/// - `card_ids`: 池内卡片 ID 列表，表示该池包含哪些卡片
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Pool {
    /// 数据池 ID（UUID v7）
    ///
    /// 全局唯一标识符，用于在网络中识别特定的数据池。
    /// 使用 UUID v7 生成，便于按时间排序。
    pub pool_id: Uuid,

    /// 成员列表
    ///
    /// 包含所有加入此数据池的设备成员信息。
    /// 每个成员通过 `endpoint_id` 唯一标识。
    /// 列表中必须至少有一个管理员成员。
    pub members: Vec<PoolMember>,

    /// 关联卡片 ID 列表
    ///
    /// 该数据池包含的所有卡片 ID 集合。
    /// 卡片本身存储在单独的存储中，此处仅保存引用关系。
    pub card_ids: Vec<Uuid>,
}

/// 数据池成员信息
///
/// 表示加入数据池的一个设备成员，包含设备标识、用户昵称、
/// 操作系统信息和权限角色。
///
/// # 字段说明
///
/// - `endpoint_id`: 成员设备的唯一端点标识
/// - `nickname`: 用户设置的设备昵称，便于识别
/// - `os`: 操作系统名称（如 "macOS", "Windows", "iOS"）
/// - `is_admin`: 管理员权限标记
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PoolMember {
    /// 成员应用 endpoint id
    ///
    /// 设备的唯一标识符，通常由应用实例在首次启动时生成并持久化。
    /// 用于在同步过程中识别特定的设备实例。
    pub endpoint_id: String,

    /// 成员昵称
    ///
    /// 用户为设备设置的友好名称，用于在成员列表中展示。
    /// 默认为设备型号或主机名，用户可随时修改。
    pub nickname: String,

    /// 操作系统平台名称
    ///
    /// 成员设备的操作系统类型，如 "macOS", "Windows", "Linux", "iOS", "Android"。
    /// 用于跨平台兼容性提示和 UI 适配。
    pub os: String,

    /// 是否管理员
    ///
    /// `true` 表示该成员拥有管理员权限，可以：
    /// - 批准新成员加入请求
    /// - 移除其他成员
    /// - 修改池配置
    ///
    /// 每个数据池必须至少保留一个管理员。
    pub is_admin: bool,
}

impl Pool {
    /// 创建新的数据池
    ///
    /// 创建空的数据池实例，不包含任何成员和卡片。
    /// 通常在建池流程中使用，创建后会立即添加初始管理员。
    ///
    /// # 返回
    ///
    /// 返回一个新的 `Pool` 实例，`members` 和 `card_ids` 均为空向量。
    ///
    /// # 示例
    ///
    /// ```rust
    /// use cardmind_rust::models::pool::Pool;
    ///
    /// let pool = Pool::new();
    /// assert!(pool.members.is_empty());
    /// assert!(pool.card_ids.is_empty());
    /// ```
    pub fn new() -> Self {
        Self {
            pool_id: Uuid::now_v7(),
            members: Vec::new(),
            card_ids: Vec::new(),
        }
    }

    /// 添加成员到数据池
    ///
    /// 将新成员加入池的成员列表。不检查重复，调用者应确保 `endpoint_id` 唯一。
    ///
    /// # 参数
    ///
    /// * `member` - 要添加的成员信息
    ///
    /// # 示例
    ///
    /// ```rust
    /// use cardmind_rust::models::pool::{Pool, PoolMember};
    ///
    /// let mut pool = Pool::new();
    /// let member = PoolMember {
    ///     endpoint_id: "device-1".to_string(),
    ///     nickname: "手机".to_string(),
    ///     os: "iOS".to_string(),
    ///     is_admin: false,
    /// };
    /// pool.add_member(member);
    /// assert_eq!(pool.members.len(), 1);
    /// ```
    pub fn add_member(&mut self, member: PoolMember) {
        self.members.push(member);
    }

    /// 从数据池移除成员
    ///
    /// 根据 `endpoint_id` 移除指定成员。如果成员不存在则静默返回。
    ///
    /// # 参数
    ///
    /// * `endpoint_id` - 要移除的成员端点 ID
    ///
    /// # 注意
    ///
    /// 调用者应确保移除后数据池仍至少保留一个管理员，
    /// 否则可能导致池无法管理。
    ///
    /// # 示例
    ///
    /// ```rust
    /// use cardmind_rust::models::pool::{Pool, PoolMember};
    ///
    /// let mut pool = Pool::new();
    /// let member = PoolMember {
    ///     endpoint_id: "device-1".to_string(),
    ///     nickname: "手机".to_string(),
    ///     os: "iOS".to_string(),
    ///     is_admin: false,
    /// };
    /// pool.add_member(member);
    /// pool.remove_member("device-1");
    /// assert!(pool.members.is_empty());
    /// ```
    pub fn remove_member(&mut self, endpoint_id: &str) {
        self.members.retain(|m| m.endpoint_id != endpoint_id);
    }

    /// 添加卡片到数据池
    ///
    /// 将卡片 ID 加入池的卡片列表。不检查重复。
    ///
    /// # 参数
    ///
    /// * `card_id` - 要添加的卡片 UUID
    ///
    /// # 示例
    ///
    /// ```rust
    /// use uuid::Uuid;
    /// use cardmind_rust::models::pool::Pool;
    ///
    /// let mut pool = Pool::new();
    /// let card_id = Uuid::now_v7();
    /// pool.add_card(card_id);
    /// assert_eq!(pool.card_ids.len(), 1);
    /// ```
    pub fn add_card(&mut self, card_id: Uuid) {
        self.card_ids.push(card_id);
    }

    /// 从数据池移除卡片
    ///
    /// 从卡片列表中移除指定的卡片 ID。如果 ID 不存在则静默返回。
    ///
    /// # 参数
    ///
    /// * `card_id` - 要移除的卡片 UUID
    ///
    /// # 示例
    ///
    /// ```rust
    /// use uuid::Uuid;
    /// use cardmind_rust::models::pool::Pool;
    ///
    /// let mut pool = Pool::new();
    /// let card_id = Uuid::now_v7();
    /// pool.add_card(card_id);
    /// pool.remove_card(&card_id);
    /// assert!(pool.card_ids.is_empty());
    /// ```
    pub fn remove_card(&mut self, card_id: &Uuid) {
        self.card_ids.retain(|id| id != card_id);
    }

    /// 获取管理员成员列表
    ///
    /// 返回池中所有具有管理员权限的成员。
    ///
    /// # 返回
    ///
    /// 返回管理员成员的引用切片。如果没有管理员则返回空切片。
    ///
    /// # 示例
    ///
    /// ```rust
    /// use cardmind_rust::models::pool::{Pool, PoolMember};
    ///
    /// let mut pool = Pool::new();
    /// let admin = PoolMember {
    ///     endpoint_id: "admin-device".to_string(),
    ///     nickname: "管理员".to_string(),
    ///     os: "macOS".to_string(),
    ///     is_admin: true,
    /// };
    /// pool.add_member(admin);
    /// let admins = pool.get_admins();
    /// assert_eq!(admins.len(), 1);
    /// ```
    pub fn get_admins(&self) -> Vec<&PoolMember> {
        self.members.iter().filter(|m| m.is_admin).collect()
    }

    /// 检查指定端点是否为成员
    ///
    /// # 参数
    ///
    /// * `endpoint_id` - 要检查的端点 ID
    ///
    /// # 返回
    ///
    /// 如果存在该成员返回 `true`，否则返回 `false`。
    ///
    /// # 示例
    ///
    /// ```rust
    /// use cardmind_rust::models::pool::{Pool, PoolMember};
    ///
    /// let mut pool = Pool::new();
    /// let member = PoolMember {
    ///     endpoint_id: "device-1".to_string(),
    ///     nickname: "手机".to_string(),
    ///     os: "iOS".to_string(),
    ///     is_admin: false,
    /// };
    /// pool.add_member(member);
    /// assert!(pool.is_member("device-1"));
    /// assert!(!pool.is_member("device-2"));
    /// ```
    pub fn is_member(&self, endpoint_id: &str) -> bool {
        self.members.iter().any(|m| m.endpoint_id == endpoint_id)
    }
}

impl Default for Pool {
    fn default() -> Self {
        Self::new()
    }
}

impl PoolMember {
    /// 创建新成员
    ///
    /// 便捷的构造函数，用于创建 `PoolMember` 实例。
    ///
    /// # 参数
    ///
    /// * `endpoint_id` - 设备端点 ID
    /// * `nickname` - 设备昵称
    /// * `os` - 操作系统名称
    /// * `is_admin` - 是否为管理员
    ///
    /// # 返回
    ///
    /// 返回配置好的 `PoolMember` 实例。
    ///
    /// # 示例
    ///
    /// ```rust
    /// use cardmind_rust::models::pool::PoolMember;
    ///
    /// let member = PoolMember::new(
    ///     "device-1".to_string(),
    ///     "手机".to_string(),
    ///     "iOS".to_string(),
    ///     false,
    /// );
    /// assert_eq!(member.endpoint_id, "device-1");
    /// assert!(!member.is_admin);
    /// ```
    pub fn new(endpoint_id: String, nickname: String, os: String, is_admin: bool) -> Self {
        Self {
            endpoint_id,
            nickname,
            os,
            is_admin,
        }
    }
}
