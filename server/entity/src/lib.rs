// 导出所有实体模块
pub mod card;

// 重新导出所有实体
pub mod entities {
    pub use super::card::Entity as Card;
    pub use super::card;
}
