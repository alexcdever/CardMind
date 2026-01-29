//! 信任设备列表管理
//!
//! 本模块负责管理已配对的信任设备列表，使用 SQLite 存储。

use crate::models::error::CardMindError;
use rusqlite::Connection;
use serde::{Deserialize, Serialize};

/// 信任设备信息
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TrustedDevice {
    /// libp2p PeerId（设备唯一标识）
    pub peer_id: String,

    /// 设备名称
    pub device_name: String,

    /// 设备类型（phone/laptop/tablet）
    pub device_type: String,

    /// 配对时间（Unix 毫秒时间戳）
    pub paired_at: i64,

    /// 最后在线时间（Unix 毫秒时间戳）
    pub last_seen: i64,
}

/// 信任设备列表管理器
pub struct TrustListManager<'a> {
    conn: &'a Connection,
}

impl<'a> TrustListManager<'a> {
    /// 创建新的信任列表管理器
    ///
    /// # 参数
    ///
    /// - `conn`: SQLite 连接引用
    pub fn new(conn: &'a Connection) -> Self {
        Self { conn }
    }

    /// 添加信任设备
    ///
    /// 如果设备已存在，则更新设备信息。
    ///
    /// # 参数
    ///
    /// - `device`: 信任设备信息
    ///
    /// # Errors
    ///
    /// - 数据库操作失败
    pub fn add_device(&self, device: &TrustedDevice) -> Result<(), CardMindError> {
        self.conn.execute(
            "INSERT OR REPLACE INTO trusted_devices
             (peer_id, device_name, device_type, paired_at, last_seen)
             VALUES (?1, ?2, ?3, ?4, ?5)",
            rusqlite::params![
                &device.peer_id,
                &device.device_name,
                &device.device_type,
                device.paired_at,
                device.last_seen,
            ],
        )?;
        Ok(())
    }

    /// 移除信任设备
    ///
    /// # 参数
    ///
    /// - `peer_id`: 设备 PeerId
    ///
    /// # Errors
    ///
    /// - 数据库操作失败
    pub fn remove_device(&self, peer_id: &str) -> Result<(), CardMindError> {
        self.conn
            .execute("DELETE FROM trusted_devices WHERE peer_id = ?1", [peer_id])?;
        Ok(())
    }

    /// 查询所有信任设备
    ///
    /// 按最后在线时间倒序排列。
    ///
    /// # Errors
    ///
    /// - 数据库操作失败
    pub fn get_all_devices(&self) -> Result<Vec<TrustedDevice>, CardMindError> {
        let mut stmt = self.conn.prepare(
            "SELECT peer_id, device_name, device_type, paired_at, last_seen
             FROM trusted_devices
             ORDER BY last_seen DESC",
        )?;

        let devices = stmt
            .query_map([], |row| {
                Ok(TrustedDevice {
                    peer_id: row.get(0)?,
                    device_name: row.get(1)?,
                    device_type: row.get(2)?,
                    paired_at: row.get(3)?,
                    last_seen: row.get(4)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(devices)
    }

    /// 检查设备是否在信任列表中
    ///
    /// # 参数
    ///
    /// - `peer_id`: 设备 PeerId
    ///
    /// # Errors
    ///
    /// - 数据库操作失败
    pub fn is_trusted(&self, peer_id: &str) -> Result<bool, CardMindError> {
        let count: i64 = self.conn.query_row(
            "SELECT COUNT(*) FROM trusted_devices WHERE peer_id = ?1",
            [peer_id],
            |row| row.get(0),
        )?;
        Ok(count > 0)
    }

    /// 获取单个信任设备信息
    ///
    /// # 参数
    ///
    /// - `peer_id`: 设备 PeerId
    ///
    /// # Errors
    ///
    /// - 设备不存在
    /// - 数据库操作失败
    pub fn get_device(&self, peer_id: &str) -> Result<TrustedDevice, CardMindError> {
        let device = self.conn.query_row(
            "SELECT peer_id, device_name, device_type, paired_at, last_seen
             FROM trusted_devices
             WHERE peer_id = ?1",
            [peer_id],
            |row| {
                Ok(TrustedDevice {
                    peer_id: row.get(0)?,
                    device_name: row.get(1)?,
                    device_type: row.get(2)?,
                    paired_at: row.get(3)?,
                    last_seen: row.get(4)?,
                })
            },
        )?;
        Ok(device)
    }

    /// 更新设备最后在线时间
    ///
    /// # 参数
    ///
    /// - `peer_id`: 设备 PeerId
    /// - `last_seen`: 最后在线时间（Unix 毫秒时间戳）
    ///
    /// # Errors
    ///
    /// - 数据库操作失败
    pub fn update_last_seen(&self, peer_id: &str, last_seen: i64) -> Result<(), CardMindError> {
        self.conn.execute(
            "UPDATE trusted_devices SET last_seen = ?1 WHERE peer_id = ?2",
            rusqlite::params![last_seen, peer_id],
        )?;
        Ok(())
    }

    /// 获取信任设备数量
    ///
    /// # Errors
    ///
    /// - 数据库操作失败
    pub fn count(&self) -> Result<usize, CardMindError> {
        let count: i64 = self
            .conn
            .query_row("SELECT COUNT(*) FROM trusted_devices", [], |row| {
                row.get(0)
            })?;
        Ok(count as usize)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::store::sqlite_store::SqliteStore;

    fn create_test_device(peer_id: &str) -> TrustedDevice {
        TrustedDevice {
            peer_id: peer_id.to_string(),
            device_name: format!("Device {}", peer_id),
            device_type: "laptop".to_string(),
            paired_at: 1000,
            last_seen: 2000,
        }
    }

    #[test]
    fn test_add_and_get_device() {
        let store = SqliteStore::new_in_memory().unwrap();
        let manager = TrustListManager::new(&store.conn);

        let device = create_test_device("peer1");
        manager.add_device(&device).unwrap();

        let retrieved = manager.get_device("peer1").unwrap();
        assert_eq!(retrieved, device);
    }

    #[test]
    fn test_is_trusted() {
        let store = SqliteStore::new_in_memory().unwrap();
        let manager = TrustListManager::new(&store.conn);

        assert!(!manager.is_trusted("peer1").unwrap());

        let device = create_test_device("peer1");
        manager.add_device(&device).unwrap();

        assert!(manager.is_trusted("peer1").unwrap());
    }

    #[test]
    fn test_remove_device() {
        let store = SqliteStore::new_in_memory().unwrap();
        let manager = TrustListManager::new(&store.conn);

        let device = create_test_device("peer1");
        manager.add_device(&device).unwrap();
        assert!(manager.is_trusted("peer1").unwrap());

        manager.remove_device("peer1").unwrap();
        assert!(!manager.is_trusted("peer1").unwrap());
    }

    #[test]
    fn test_get_all_devices() {
        let store = SqliteStore::new_in_memory().unwrap();
        let manager = TrustListManager::new(&store.conn);

        let device1 = TrustedDevice {
            peer_id: "peer1".to_string(),
            device_name: "Device 1".to_string(),
            device_type: "laptop".to_string(),
            paired_at: 1000,
            last_seen: 2000,
        };

        let device2 = TrustedDevice {
            peer_id: "peer2".to_string(),
            device_name: "Device 2".to_string(),
            device_type: "phone".to_string(),
            paired_at: 1500,
            last_seen: 3000, // 更晚的时间
        };

        manager.add_device(&device1).unwrap();
        manager.add_device(&device2).unwrap();

        let devices = manager.get_all_devices().unwrap();
        assert_eq!(devices.len(), 2);
        // 应该按 last_seen 倒序排列
        assert_eq!(devices[0].peer_id, "peer2");
        assert_eq!(devices[1].peer_id, "peer1");
    }

    #[test]
    fn test_update_last_seen() {
        let store = SqliteStore::new_in_memory().unwrap();
        let manager = TrustListManager::new(&store.conn);

        let device = create_test_device("peer1");
        manager.add_device(&device).unwrap();

        manager.update_last_seen("peer1", 5000).unwrap();

        let updated = manager.get_device("peer1").unwrap();
        assert_eq!(updated.last_seen, 5000);
    }

    #[test]
    fn test_count() {
        let store = SqliteStore::new_in_memory().unwrap();
        let manager = TrustListManager::new(&store.conn);

        assert_eq!(manager.count().unwrap(), 0);

        manager.add_device(&create_test_device("peer1")).unwrap();
        assert_eq!(manager.count().unwrap(), 1);

        manager.add_device(&create_test_device("peer2")).unwrap();
        assert_eq!(manager.count().unwrap(), 2);

        manager.remove_device("peer1").unwrap();
        assert_eq!(manager.count().unwrap(), 1);
    }

    #[test]
    fn test_add_device_updates_existing() {
        let store = SqliteStore::new_in_memory().unwrap();
        let manager = TrustListManager::new(&store.conn);

        let device1 = TrustedDevice {
            peer_id: "peer1".to_string(),
            device_name: "Old Name".to_string(),
            device_type: "laptop".to_string(),
            paired_at: 1000,
            last_seen: 2000,
        };

        manager.add_device(&device1).unwrap();

        let device2 = TrustedDevice {
            peer_id: "peer1".to_string(),
            device_name: "New Name".to_string(),
            device_type: "phone".to_string(),
            paired_at: 1000,
            last_seen: 3000,
        };

        manager.add_device(&device2).unwrap();

        let retrieved = manager.get_device("peer1").unwrap();
        assert_eq!(retrieved.device_name, "New Name");
        assert_eq!(retrieved.device_type, "phone");
        assert_eq!(manager.count().unwrap(), 1); // 应该只有一个设备
    }
}
