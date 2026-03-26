//! # 池网络同步模块
//!
//! 实现 CardMind 的池（Pool）网络同步主流程，负责池成员之间的点对点数据同步。
//!
//! ## 架构说明
//!
//! 该模块是网络层的核心编排组件，协调以下功能：
//!
//! - **连接处理**: 通过 `PoolEndpoint` 建立和管理点对点连接
//! - **消息分发**: 处理 `PoolMessage` 类型的各类同步消息
//! - **数据合并**: 将接收到的快照和增量更新合并到本地存储
//! - **持久化**: 将同步后的数据写入 Loro 文档和 SQLite 数据库
//!
//! ## 同步流程
//!
//! 1. **主动同步** (`connect_and_sync`):
//!    - 连接到目标端点
//!    - 发送 Hello 消息进行身份验证
//!    - 发送池快照和所有卡片快照
//!
//! 2. **被动接收** (`handle_connection`):
//!    - 接受传入连接
//!    - 处理 Hello 消息验证成员身份
//!    - 接收并应用池和卡片快照
//!    - 接收并应用增量更新
//!
//! ## 数据格式
//!
//! 所有数据使用 Loro CRDT 格式存储，支持：
//! - 完整快照 (`build_pool_snapshot`, `build_card_snapshot`)
//! - 增量更新 (`apply_pool_updates`, `apply_card_updates`)

use crate::models::card::Card;
use crate::models::error::CardMindError;
use crate::models::pool::{Pool, PoolMember};
use crate::net::codec::{decode_message, encode_message};
use crate::net::endpoint::PoolEndpoint;
use crate::net::messages::PoolMessage;
use crate::net::session::SyncSession;
use crate::net::sync::{export_snapshot, import_updates};
use crate::store::card_store::CardNoteRepository;
use crate::store::loro_store::{load_loro_doc, note_doc_path, pool_doc_path, save_loro_doc};
use crate::store::path_resolver::DataPaths;
use crate::store::pool_store::PoolStore;
use crate::store::sqlite_store::SqliteStore;
use iroh::{EndpointAddr, endpoint::Connection};
use loro::{LoroDoc, LoroMap, LoroValue};
use std::collections::HashSet;
use tokio::time::{Duration, timeout};
use uuid::Uuid;

const MESSAGE_LIMIT: usize = 10_000_000;

/// 池网络管理器。
///
/// 负责管理池成员之间的点对点网络连接，处理同步消息的分发和数据交换。
/// 协调连接建立、消息处理和数据同步的完整生命周期。
pub struct PoolNetwork {
    endpoint: PoolEndpoint,
    base_path: String,
    pool_store: PoolStore,
    card_repository: CardNoteRepository,
    sync_session: SyncSession,
    last_sync_error: Option<String>,
}

impl PoolNetwork {
    pub fn new(
        endpoint: PoolEndpoint,
        pool_store: PoolStore,
        card_repository: CardNoteRepository,
    ) -> Self {
        let base_path = pool_store.base_path().to_string_lossy().to_string();
        let card_base = card_repository.base_path();
        if card_base != pool_store.base_path() {
            // 保底使用 pool_store 路径，避免潜在路径不一致
        }
        Self {
            endpoint,
            base_path,
            pool_store,
            card_repository,
            sync_session: SyncSession::new(),
            last_sync_error: None,
        }
    }

    /// 获取端点 ID。
    pub fn endpoint_id(&self) -> iroh::EndpointId {
        self.endpoint.endpoint_id()
    }

    /// 获取端点地址。
    pub fn endpoint_addr(&self) -> EndpointAddr {
        self.endpoint.endpoint_addr()
    }

    /// 获取基础路径。
    pub fn base_path(&self) -> &str {
        &self.base_path
    }

    pub async fn wait_for_addr(&self, timeout: Duration) -> Result<EndpointAddr, CardMindError> {
        self.endpoint.wait_for_addr(timeout).await
    }

    pub async fn start(&self) -> Result<(), CardMindError> {
        let endpoint = self.endpoint.inner().clone();
        let base_path = self.base_path.clone();
        tokio::spawn(async move {
            loop {
                let incoming = match endpoint.accept().await {
                    Some(incoming) => incoming,
                    None => break,
                };
                let accepting = match incoming.accept() {
                    Ok(accepting) => accepting,
                    Err(_) => continue,
                };
                let conn = match accepting.await {
                    Ok(conn) => conn,
                    Err(_) => continue,
                };
                let base_path = base_path.clone();
                tokio::spawn(async move {
                    let _ = handle_connection(conn, base_path).await;
                });
            }
        });
        Ok(())
    }

    pub async fn connect_and_sync(
        &self,
        peer: impl Into<EndpointAddr>,
    ) -> Result<(), CardMindError> {
        let pool = self.pool_store.get_any_pool()?;
        let endpoint_id = self.endpoint_id().to_string();
        let local_member = pool
            .members
            .iter()
            .find(|member| member.endpoint_id == endpoint_id)
            .cloned()
            .or_else(|| pool.members.first().cloned())
            .ok_or_else(|| CardMindError::NotFound("member not found".to_string()))?;

        let conn = self
            .endpoint
            .connect(peer)
            .await
            .map_err(|e| CardMindError::Internal(format!("connect failed: {}", e)))?;
        let hello = PoolMessage::Hello {
            pool_id: pool.pool_id,
            endpoint_id,
            nickname: local_member.nickname.clone(),
            os: local_member.os.clone(),
        };
        send_message(&conn, &hello).await?;

        let pool_snapshot = build_pool_snapshot(&self.base_path, &pool.pool_id)?;
        send_message(
            &conn,
            &PoolMessage::PoolSnapshot {
                pool_id: pool.pool_id,
                bytes: pool_snapshot,
            },
        )
        .await?;

        for card_id in &pool.card_ids {
            let bytes = build_card_snapshot(&self.base_path, card_id)?;
            send_message(
                &conn,
                &PoolMessage::CardSnapshot {
                    card_id: *card_id,
                    bytes,
                },
            )
            .await?;
        }

        let _ = timeout(Duration::from_secs(5), conn.closed()).await;
        Ok(())
    }

    /// 检查卡片是否存在。
    ///
    /// # Arguments
    /// - `card_id` - 卡片 ID
    ///
    /// # Returns
    /// - `Ok(true)` - 卡片存在
    /// - `Ok(false)` - 卡片不存在
    /// - `Err(CardMindError)` - 查询失败
    pub fn has_card(&self, card_id: &Uuid) -> Result<bool, CardMindError> {
        match self.card_repository.get_card(card_id) {
            Ok(_) => Ok(true),
            Err(CardMindError::NotFound(_)) => Ok(false),
            Err(err) => Err(err),
        }
    }

    /// 建立同步连接。
    ///
    /// # Arguments
    /// - `target` - 目标节点地址
    ///
    /// # Returns
    /// - `Ok(())` - 连接成功
    /// - `Err(CardMindError)` - 连接失败
    pub fn sync_connect(&mut self, target: String) -> Result<(), CardMindError> {
        self.last_sync_error = None;
        self.sync_session.connect(target)
    }

    /// 断开同步连接。
    pub fn sync_disconnect(&mut self) {
        self.sync_session.disconnect();
        self.last_sync_error = None;
    }

    /// 获取同步状态。
    ///
    /// # Returns
    /// - `"sync_failed"` - 上次同步失败
    /// - `"connected"` - 已连接
    /// - `"disconnected"` - 已断开
    pub fn sync_state(&self) -> &'static str {
        if self.last_sync_error.is_some() {
            "sync_failed"
        } else {
            self.sync_session.state()
        }
    }

    /// 获取上次同步错误码。
    ///
    /// # Returns
    /// - `Some(error_code)` - 上次同步失败的错误码
    /// - `None` - 没有错误
    pub fn last_sync_error_code(&self) -> Option<&str> {
        self.last_sync_error.as_deref()
    }

    /// 加入同步池。
    ///
    /// # Arguments
    /// - `pool_id` - 池 ID
    ///
    /// # Returns
    /// - `Ok(())` - 验证通过
    /// - `Err(CardMindError)` - 验证失败（pool_id 为空或同步未连接）
    pub fn sync_join_pool(&self, pool_id: &str) -> Result<(), CardMindError> {
        if pool_id.trim().is_empty() {
            return Err(CardMindError::InvalidArgument(
                "pool_id is empty".to_string(),
            ));
        }
        if self.sync_session.state() != "connected" {
            return Err(CardMindError::InvalidArgument(
                "sync not connected".to_string(),
            ));
        }
        Ok(())
    }

    /// 推送同步数据。
    ///
    /// # Returns
    /// - `Ok(())` - 推送请求已发送
    /// - `Err(CardMindError)` - 同步未连接
    pub fn sync_push(&mut self) -> Result<(), CardMindError> {
        if self.sync_session.state() != "connected" {
            self.last_sync_error = Some("REQUEST_TIMEOUT".to_string());
            return Err(CardMindError::InvalidArgument(
                "sync not connected".to_string(),
            ));
        }
        self.last_sync_error = None;
        Ok(())
    }

    /// 拉取同步数据。
    ///
    /// # Returns
    /// - `Ok(())` - 拉取请求已发送
    /// - `Err(CardMindError)` - 同步未连接
    pub fn sync_pull(&mut self) -> Result<(), CardMindError> {
        if self.sync_session.state() != "connected" {
            self.last_sync_error = Some("REQUEST_TIMEOUT".to_string());
            return Err(CardMindError::InvalidArgument(
                "sync not connected".to_string(),
            ));
        }
        self.last_sync_error = None;
        Ok(())
    }
}

/// 处理传入的同步连接。
///
/// 处理完整的同步会话生命周期：
/// - 接收并验证 Hello 消息
/// - 接收并应用池快照
/// - 接收并应用卡片快照
/// - 接收并应用增量更新
///
/// # Arguments
/// - `conn` - iroh 点对点连接
/// - `base_path` - 数据存储基础路径
///
/// # Returns
/// - `Ok(())` - 连接处理完成
/// - `Err(CardMindError)` - 处理失败
async fn handle_connection(conn: Connection, base_path: String) -> Result<(), CardMindError> {
    let mut hello: Option<(Uuid, String)> = None;
    let mut pool_snapshot: Option<(Uuid, Vec<u8>, Vec<Uuid>)> = None;
    let mut card_snapshots: Vec<(Uuid, Vec<u8>)> = Vec::new();
    let mut pool_updates: Vec<(Uuid, Vec<u8>)> = Vec::new();
    let mut card_updates: Vec<(Uuid, Vec<u8>)> = Vec::new();
    let mut expected_cards: Option<HashSet<Uuid>> = None;

    loop {
        let stream = conn.accept_bi().await;
        let (mut send, mut recv) = match stream {
            Ok(stream) => stream,
            Err(_) => break,
        };
        let bytes = recv
            .read_to_end(MESSAGE_LIMIT)
            .await
            .map_err(|e| CardMindError::Internal(format!("read failed: {}", e)))?;
        let _ = send.finish();
        let msg = decode_message(&bytes)?;
        match msg {
            PoolMessage::Hello {
                pool_id,
                endpoint_id,
                ..
            } => {
                hello = Some((pool_id, endpoint_id.clone()));
                if let Some(pool) = load_pool_if_exists(&base_path, &pool_id)?
                    && !pool
                        .members
                        .iter()
                        .any(|member| member.endpoint_id == endpoint_id)
                {
                    return Err(CardMindError::NotMember("not member".to_string()));
                }
            }
            PoolMessage::PoolSnapshot { pool_id, bytes } => {
                let pool = pool_from_snapshot(&bytes)?;
                expected_cards = Some(pool.card_ids.iter().cloned().collect());
                pool_snapshot = Some((pool_id, bytes, pool.card_ids));
            }
            PoolMessage::PoolUpdates { pool_id, bytes } => {
                pool_updates.push((pool_id, bytes));
            }
            PoolMessage::CardSnapshot { card_id, bytes } => {
                card_snapshots.push((card_id, bytes));
            }
            PoolMessage::CardUpdates { card_id, bytes } => {
                card_updates.push((card_id, bytes));
            }
            _ => {}
        }

        if let Some(expected) = &expected_cards
            && !expected.is_empty()
            && card_snapshots.len() >= expected.len()
        {
            break;
        }

        if pool_snapshot.is_some() && expected_cards.as_ref().is_none_or(|set| set.is_empty()) {
            break;
        }
    }

    if let Some((pool_id, bytes, _)) = pool_snapshot {
        let _pool = apply_pool_snapshot(&base_path, &pool_id, &bytes)?;
    }

    for (pool_id, bytes) in pool_updates {
        let _ = apply_pool_updates(&base_path, &pool_id, &bytes)?;
    }

    for (card_id, bytes) in card_snapshots {
        let _card = apply_card_snapshot(&base_path, &card_id, &bytes)?;
    }

    for (card_id, bytes) in card_updates {
        let _ = apply_card_updates(&base_path, &card_id, &bytes)?;
    }

    let _ = hello;
    conn.close(0u32.into(), b"done");
    Ok(())
}

async fn send_message(conn: &Connection, msg: &PoolMessage) -> Result<(), CardMindError> {
    let (mut send, _recv) = conn
        .open_bi()
        .await
        .map_err(|e| CardMindError::Internal(format!("open_bi failed: {}", e)))?;
    let bytes = encode_message(msg)?;
    send.write_all(&bytes)
        .await
        .map_err(|e| CardMindError::Internal(format!("write failed: {}", e)))?;
    send.finish()
        .map_err(|e| CardMindError::Internal(e.to_string()))?;
    Ok(())
}

/// 构建池的快照数据。
///
/// # Arguments
/// - `base_path` - 数据存储基础路径
/// - `pool_id` - 池 ID
///
/// # Returns
/// - `Ok(Vec<u8>)` - 快照字节数据
/// - `Err(CardMindError)` - 构建失败
fn build_pool_snapshot(base_path: &str, pool_id: &Uuid) -> Result<Vec<u8>, CardMindError> {
    let paths = DataPaths::new(base_path)?;
    let path = paths.base_path.join(pool_doc_path(pool_id));
    let doc = load_loro_doc(&path)?;
    export_snapshot(&doc)
}

/// 构建卡片的快照数据。
///
/// # Arguments
/// - `base_path` - 数据存储基础路径
/// - `card_id` - 卡片 ID
///
/// # Returns
/// - `Ok(Vec<u8>)` - 快照字节数据
/// - `Err(CardMindError)` - 构建失败
fn build_card_snapshot(base_path: &str, card_id: &Uuid) -> Result<Vec<u8>, CardMindError> {
    let paths = DataPaths::new(base_path)?;
    let path = paths.base_path.join(note_doc_path(card_id));
    let doc = load_loro_doc(&path)?;
    export_snapshot(&doc)
}

/// 应用池的快照数据并持久化。
///
/// # Arguments
/// - `base_path` - 数据存储基础路径
/// - `pool_id` - 池 ID
/// - `bytes` - 快照字节数据
///
/// # Returns
/// - `Ok(Pool)` - 应用成功，返回池对象
/// - `Err(CardMindError)` - 应用失败
fn apply_pool_snapshot(
    base_path: &str,
    pool_id: &Uuid,
    bytes: &[u8],
) -> Result<Pool, CardMindError> {
    let doc = LoroDoc::from_snapshot(bytes).map_err(|e| CardMindError::Loro(e.to_string()))?;
    let paths = DataPaths::new(base_path)?;
    let path = paths.base_path.join(pool_doc_path(pool_id));
    save_loro_doc(&path, &doc)?;
    let pool = pool_from_doc(&doc)?;
    let sqlite = SqliteStore::new(&paths.sqlite_path)?;
    sqlite.upsert_pool(&pool)?;
    Ok(pool)
}

/// 应用池的增量更新并持久化。
///
/// # Arguments
/// - `base_path` - 数据存储基础路径
/// - `pool_id` - 池 ID
/// - `bytes` - 增量更新字节数据
///
/// # Returns
/// - `Ok(Pool)` - 应用成功，返回池对象
/// - `Err(CardMindError)` - 应用失败
fn apply_pool_updates(
    base_path: &str,
    pool_id: &Uuid,
    bytes: &[u8],
) -> Result<Pool, CardMindError> {
    let paths = DataPaths::new(base_path)?;
    let path = paths.base_path.join(pool_doc_path(pool_id));
    let doc = load_loro_doc(&path)?;
    import_updates(&doc, bytes)?;
    doc.commit();
    save_loro_doc(&path, &doc)?;
    let pool = pool_from_doc(&doc)?;
    let sqlite = SqliteStore::new(&paths.sqlite_path)?;
    sqlite.upsert_pool(&pool)?;
    Ok(pool)
}

/// 应用卡片的快照数据并持久化。
///
/// # Arguments
/// - `base_path` - 数据存储基础路径
/// - `card_id` - 卡片 ID
/// - `bytes` - 快照字节数据
///
/// # Returns
/// - `Ok(Card)` - 应用成功，返回卡片对象
/// - `Err(CardMindError)` - 应用失败
fn apply_card_snapshot(
    base_path: &str,
    card_id: &Uuid,
    bytes: &[u8],
) -> Result<Card, CardMindError> {
    let doc = LoroDoc::from_snapshot(bytes).map_err(|e| CardMindError::Loro(e.to_string()))?;
    let paths = DataPaths::new(base_path)?;
    let path = paths.base_path.join(note_doc_path(card_id));
    save_loro_doc(&path, &doc)?;
    let card = card_from_doc(&doc)?;
    let sqlite = SqliteStore::new(&paths.sqlite_path)?;
    sqlite.upsert_card(&card)?;
    Ok(card)
}

/// 应用卡片的增量更新并持久化。
///
/// # Arguments
/// - `base_path` - 数据存储基础路径
/// - `card_id` - 卡片 ID
/// - `bytes` - 增量更新字节数据
///
/// # Returns
/// - `Ok(Card)` - 应用成功，返回卡片对象
/// - `Err(CardMindError)` - 应用失败
fn apply_card_updates(
    base_path: &str,
    card_id: &Uuid,
    bytes: &[u8],
) -> Result<Card, CardMindError> {
    let paths = DataPaths::new(base_path)?;
    let path = paths.base_path.join(note_doc_path(card_id));
    let doc = load_loro_doc(&path)?;
    import_updates(&doc, bytes)?;
    doc.commit();
    save_loro_doc(&path, &doc)?;
    let card = card_from_doc(&doc)?;
    let sqlite = SqliteStore::new(&paths.sqlite_path)?;
    sqlite.upsert_card(&card)?;
    Ok(card)
}

/// 加载池（如果不存在则返回 None）。
fn load_pool_if_exists(base_path: &str, pool_id: &Uuid) -> Result<Option<Pool>, CardMindError> {
    let store = PoolStore::new(base_path)?;
    match store.get_pool(pool_id) {
        Ok(pool) => Ok(Some(pool)),
        Err(CardMindError::NotFound(_)) => Ok(None),
        Err(err) => Err(err),
    }
}

/// 从快照字节创建 Pool。
fn pool_from_snapshot(bytes: &[u8]) -> Result<Pool, CardMindError> {
    let doc = LoroDoc::from_snapshot(bytes).map_err(|e| CardMindError::Loro(e.to_string()))?;
    pool_from_doc(&doc)
}

/// 从 Loro 文档解析 Pool。
fn pool_from_doc(doc: &LoroDoc) -> Result<Pool, CardMindError> {
    let map = doc.get_map("pool");
    let pool_id = parse_uuid(&map, "pool_id")?;
    let members_value = doc.get_list("members").get_deep_value();
    let card_ids_value = doc.get_list("card_ids").get_deep_value();
    let members = parse_members(members_value)?;
    let card_ids = parse_card_ids(card_ids_value)?;
    Ok(Pool {
        pool_id,
        members,
        card_ids,
    })
}

/// 从 Loro 文档解析 Card。
fn card_from_doc(doc: &LoroDoc) -> Result<Card, CardMindError> {
    let map = doc.get_map("card");
    let id = parse_uuid(&map, "id")?;
    let title = parse_string(&map, "title")?;
    let content = parse_string(&map, "content")?;
    let created_at = parse_i64(&map, "created_at")?;
    let updated_at = parse_i64(&map, "updated_at")?;
    let deleted = parse_bool(&map, "deleted")?;
    Ok(Card {
        id,
        title,
        content,
        created_at,
        updated_at,
        deleted,
    })
}

/// 解析成员列表。
fn parse_members(value: LoroValue) -> Result<Vec<PoolMember>, CardMindError> {
    let mut members = Vec::new();
    let list = match value {
        LoroValue::List(list) => list,
        LoroValue::Null => return Ok(members),
        _ => {
            return Err(CardMindError::InvalidArgument(
                "members invalid".to_string(),
            ));
        }
    };
    for item in list.iter() {
        let member_list = match item {
            LoroValue::List(list) => list,
            _ => return Err(CardMindError::InvalidArgument("member invalid".to_string())),
        };
        if member_list.len() != 4 {
            return Err(CardMindError::InvalidArgument(
                "member length invalid".to_string(),
            ));
        }
        let endpoint_id = parse_string_value(&member_list[0], "member.endpoint_id")?;
        let nickname = parse_string_value(&member_list[1], "member.nickname")?;
        let os = parse_string_value(&member_list[2], "member.os")?;
        let is_admin = parse_bool_value(&member_list[3], "member.is_admin")?;
        members.push(PoolMember {
            endpoint_id,
            nickname,
            os,
            is_admin,
        });
    }
    Ok(members)
}

/// 解析卡片 ID 列表。
fn parse_card_ids(value: LoroValue) -> Result<Vec<Uuid>, CardMindError> {
    let mut ids = Vec::new();
    let list = match value {
        LoroValue::List(list) => list,
        LoroValue::Null => return Ok(ids),
        _ => {
            return Err(CardMindError::InvalidArgument(
                "card_ids invalid".to_string(),
            ));
        }
    };
    for item in list.iter() {
        let id = parse_uuid_value(item, "card_id")?;
        ids.push(id);
    }
    Ok(ids)
}

/// 从 LoroMap 解析 UUID。
fn parse_uuid(map: &LoroMap, key: &str) -> Result<Uuid, CardMindError> {
    let value = map
        .get(key)
        .ok_or_else(|| CardMindError::NotFound(format!("{} missing", key)))?
        .get_deep_value();
    parse_uuid_value(&value, key)
}

/// 从 LoroMap 解析字符串。
fn parse_string(map: &LoroMap, key: &str) -> Result<String, CardMindError> {
    let value = map
        .get(key)
        .ok_or_else(|| CardMindError::NotFound(format!("{} missing", key)))?
        .get_deep_value();
    parse_string_value(&value, key)
}

/// 从 LoroMap 解析 i64。
fn parse_i64(map: &LoroMap, key: &str) -> Result<i64, CardMindError> {
    let value = map
        .get(key)
        .ok_or_else(|| CardMindError::NotFound(format!("{} missing", key)))?
        .get_deep_value();
    match value {
        LoroValue::I64(v) => Ok(v),
        _ => Err(CardMindError::InvalidArgument(format!("{} invalid", key))),
    }
}

/// 从 LoroMap 解析布尔值。
fn parse_bool(map: &LoroMap, key: &str) -> Result<bool, CardMindError> {
    let value = map
        .get(key)
        .ok_or_else(|| CardMindError::NotFound(format!("{} missing", key)))?
        .get_deep_value();
    parse_bool_value(&value, key)
}

/// 从 LoroValue 解析 UUID。
fn parse_uuid_value(value: &LoroValue, key: &str) -> Result<Uuid, CardMindError> {
    let text = parse_string_value(value, key)?;
    Uuid::parse_str(&text).map_err(|_| CardMindError::InvalidArgument(format!("{} invalid", key)))
}

/// 从 LoroValue 解析字符串。
fn parse_string_value(value: &LoroValue, key: &str) -> Result<String, CardMindError> {
    match value {
        LoroValue::String(v) => Ok(v.as_ref().to_string()),
        _ => Err(CardMindError::InvalidArgument(format!("{} invalid", key))),
    }
}

/// 从 LoroValue 解析布尔值。
fn parse_bool_value(value: &LoroValue, key: &str) -> Result<bool, CardMindError> {
    match value {
        LoroValue::Bool(v) => Ok(*v),
        _ => Err(CardMindError::InvalidArgument(format!("{} invalid", key))),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::net::sync::{export_snapshot, export_updates};
    use crate::store::card_store::CardNoteRepository;
    use crate::store::loro_store::{load_loro_doc, note_doc_path, pool_doc_path};
    use crate::store::pool_store::PoolStore;
    use tempfile::TempDir;

    #[test]
    fn parse_members_accepts_null() {
        let members = parse_members(LoroValue::Null).unwrap();
        assert!(members.is_empty());
    }

    #[test]
    fn parse_members_rejects_non_list() {
        let err = parse_members(LoroValue::I64(1)).unwrap_err();
        match err {
            CardMindError::InvalidArgument(msg) => assert!(msg.contains("members invalid")),
            other => panic!("unexpected error: {:?}", other),
        }
    }

    #[test]
    fn parse_members_rejects_invalid_member_length() {
        let value = LoroValue::List(
            vec![LoroValue::List(
                vec![LoroValue::String("only-one".into())].into(),
            )]
            .into(),
        );

        let err = parse_members(value).unwrap_err();

        match err {
            CardMindError::InvalidArgument(msg) => {
                assert!(msg.contains("member length invalid"))
            }
            other => panic!("unexpected error: {:?}", other),
        }
    }

    #[test]
    fn parse_card_ids_accepts_null() {
        let ids = parse_card_ids(LoroValue::Null).unwrap();
        assert!(ids.is_empty());
    }

    #[test]
    fn parse_card_ids_rejects_non_list() {
        let err = parse_card_ids(LoroValue::Bool(true)).unwrap_err();
        match err {
            CardMindError::InvalidArgument(msg) => assert!(msg.contains("card_ids invalid")),
            other => panic!("unexpected error: {:?}", other),
        }
    }

    #[test]
    fn load_pool_if_exists_returns_none_for_missing_pool() {
        let temp_dir = TempDir::new().unwrap();
        let pool_id = Uuid::new_v4();

        let pool = load_pool_if_exists(temp_dir.path().to_str().unwrap(), &pool_id).unwrap();

        assert!(pool.is_none());
    }

    #[test]
    fn apply_pool_snapshot_persists_pool_to_sqlite() {
        let source_dir = TempDir::new().unwrap();
        let target_dir = TempDir::new().unwrap();
        let source_base = source_dir.path().to_str().unwrap();
        let target_base = target_dir.path().to_str().unwrap();
        let source_store = PoolStore::new(source_base).unwrap();
        let pool = source_store.create_pool("ep1", "alice", "macOS").unwrap();
        let snapshot = build_pool_snapshot(source_base, &pool.pool_id).unwrap();

        let applied = apply_pool_snapshot(target_base, &pool.pool_id, &snapshot).unwrap();
        let target_store = PoolStore::new(target_base).unwrap();
        let persisted = target_store.get_pool(&pool.pool_id).unwrap();

        assert_eq!(applied.pool_id, pool.pool_id);
        assert_eq!(persisted.members[0].nickname, "alice");
    }

    #[test]
    fn apply_card_snapshot_persists_card_to_sqlite() {
        let source_dir = TempDir::new().unwrap();
        let target_dir = TempDir::new().unwrap();
        let source_base = source_dir.path().to_str().unwrap();
        let target_base = target_dir.path().to_str().unwrap();
        let source_repo = CardNoteRepository::new(source_base).unwrap();
        let card = source_repo.create_card("hello", "world").unwrap();
        let snapshot = build_card_snapshot(source_base, &card.id).unwrap();

        let applied = apply_card_snapshot(target_base, &card.id, &snapshot).unwrap();
        let target_repo = CardNoteRepository::new(target_base).unwrap();
        let persisted = target_repo.get_card(&card.id).unwrap();

        assert_eq!(applied.id, card.id);
        assert_eq!(persisted.title, "hello");
        assert_eq!(persisted.content, "world");
    }

    #[test]
    fn apply_pool_updates_imports_incremental_changes() {
        let source_dir = TempDir::new().unwrap();
        let target_dir = TempDir::new().unwrap();
        let source_base = source_dir.path().to_str().unwrap();
        let target_base = target_dir.path().to_str().unwrap();
        let source_store = PoolStore::new(source_base).unwrap();
        let pool = source_store.create_pool("ep1", "alice", "macOS").unwrap();
        let card_id = Uuid::new_v4();

        let source_paths = DataPaths::new(source_base).unwrap();
        let source_doc_path = source_paths.base_path.join(pool_doc_path(&pool.pool_id));
        let initial_doc = load_loro_doc(&source_doc_path).unwrap();
        let initial_snapshot = export_snapshot(&initial_doc).unwrap();
        apply_pool_snapshot(target_base, &pool.pool_id, &initial_snapshot).unwrap();

        source_store
            .attach_note_references(&pool.pool_id, vec![card_id])
            .unwrap();
        let updated_doc = load_loro_doc(&source_doc_path).unwrap();
        let updates = export_updates(&updated_doc, &initial_doc.oplog_vv()).unwrap();

        let updated = apply_pool_updates(target_base, &pool.pool_id, &updates).unwrap();

        assert_eq!(updated.card_ids, vec![card_id]);
    }

    #[test]
    fn apply_card_updates_imports_incremental_changes() {
        let source_dir = TempDir::new().unwrap();
        let target_dir = TempDir::new().unwrap();
        let source_base = source_dir.path().to_str().unwrap();
        let target_base = target_dir.path().to_str().unwrap();
        let source_repo = CardNoteRepository::new(source_base).unwrap();
        let card = source_repo.create_card("before", "content").unwrap();

        let source_paths = DataPaths::new(source_base).unwrap();
        let source_doc_path = source_paths.base_path.join(note_doc_path(&card.id));
        let initial_doc = load_loro_doc(&source_doc_path).unwrap();
        let initial_snapshot = export_snapshot(&initial_doc).unwrap();
        apply_card_snapshot(target_base, &card.id, &initial_snapshot).unwrap();

        source_repo
            .update_card(&card.id, "after", "changed")
            .unwrap();
        let updated_doc = load_loro_doc(&source_doc_path).unwrap();
        let updates = export_updates(&updated_doc, &initial_doc.oplog_vv()).unwrap();

        let updated = apply_card_updates(target_base, &card.id, &updates).unwrap();

        assert_eq!(updated.title, "after");
        assert_eq!(updated.content, "changed");
    }
}
