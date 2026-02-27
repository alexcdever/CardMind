// input: 数据池与卡片存储、端点连接
// output: 组网同步主流程
// pos: 组网同步编排（修改本文件需同步更新文件头与所属 DIR.md）
use crate::models::card::Card;
use crate::models::error::CardMindError;
use crate::models::pool::{Pool, PoolMember};
use crate::net::codec::{decode_message, encode_message};
use crate::net::endpoint::PoolEndpoint;
use crate::net::messages::PoolMessage;
use crate::net::session::SyncSession;
use crate::net::sync::{export_snapshot, import_updates};
use crate::store::card_store::CardStore;
use crate::store::loro_store::{load_loro_doc, note_doc_path, pool_doc_path, save_loro_doc};
use crate::store::path_resolver::DataPaths;
use crate::store::pool_store::PoolStore;
use crate::store::sqlite_store::SqliteStore;
use iroh::{endpoint::Connection, EndpointAddr};
use loro::{LoroDoc, LoroMap, LoroValue};
use std::collections::HashSet;
use tokio::time::{timeout, Duration};
use uuid::Uuid;

const MESSAGE_LIMIT: usize = 10_000_000;

pub struct PoolNetwork {
    endpoint: PoolEndpoint,
    base_path: String,
    pool_store: PoolStore,
    card_store: CardStore,
    sync_session: SyncSession,
}

impl PoolNetwork {
    pub fn new(endpoint: PoolEndpoint, pool_store: PoolStore, card_store: CardStore) -> Self {
        let base_path = pool_store.base_path().to_string_lossy().to_string();
        let card_base = card_store.base_path();
        if card_base != pool_store.base_path() {
            // 保底使用 pool_store 路径，避免潜在路径不一致
        }
        Self {
            endpoint,
            base_path,
            pool_store,
            card_store,
            sync_session: SyncSession::new(),
        }
    }

    pub fn endpoint_id(&self) -> iroh::EndpointId {
        self.endpoint.endpoint_id()
    }

    pub fn endpoint_addr(&self) -> EndpointAddr {
        self.endpoint.endpoint_addr()
    }

    pub async fn wait_for_addr(
        &self,
        timeout: Duration,
    ) -> Result<EndpointAddr, CardMindError> {
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

    pub fn has_card(&self, card_id: &Uuid) -> Result<bool, CardMindError> {
        match self.card_store.get_card(card_id) {
            Ok(_) => Ok(true),
            Err(CardMindError::NotFound(_)) => Ok(false),
            Err(err) => Err(err),
        }
    }

    pub fn sync_connect(&mut self, target: String) -> Result<(), CardMindError> {
        self.sync_session.connect(target)
    }

    pub fn sync_disconnect(&mut self) {
        self.sync_session.disconnect();
    }

    pub fn sync_state(&self) -> &'static str {
        self.sync_session.state()
    }

    pub fn sync_join_pool(&self, pool_id: &str) -> Result<(), CardMindError> {
        if pool_id.trim().is_empty() {
            return Err(CardMindError::InvalidArgument("pool_id is empty".to_string()));
        }
        if self.sync_session.state() != "connected" {
            return Err(CardMindError::InvalidArgument("sync not connected".to_string()));
        }
        Ok(())
    }

    pub fn sync_push(&self) -> Result<(), CardMindError> {
        if self.sync_session.state() != "connected" {
            return Err(CardMindError::InvalidArgument("sync not connected".to_string()));
        }
        Ok(())
    }

    pub fn sync_pull(&self) -> Result<(), CardMindError> {
        if self.sync_session.state() != "connected" {
            return Err(CardMindError::InvalidArgument("sync not connected".to_string()));
        }
        Ok(())
    }
}

async fn handle_connection(
    conn: Connection,
    base_path: String,
) -> Result<(), CardMindError> {
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
                if let Some(pool) = load_pool_if_exists(&base_path, &pool_id)? {
                    if !pool
                        .members
                        .iter()
                        .any(|member| member.endpoint_id == endpoint_id)
                    {
                        return Err(CardMindError::NotMember("not member".to_string()));
                    }
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

        if let Some(expected) = &expected_cards {
            if !expected.is_empty() && card_snapshots.len() >= expected.len() {
                break;
            }
        }

        if pool_snapshot.is_some() && expected_cards.as_ref().map_or(true, |set| set.is_empty()) {
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

fn build_pool_snapshot(base_path: &str, pool_id: &Uuid) -> Result<Vec<u8>, CardMindError> {
    let paths = DataPaths::new(base_path)?;
    let path = paths.base_path.join(pool_doc_path(pool_id));
    let doc = load_loro_doc(&path)?;
    export_snapshot(&doc)
}

fn build_card_snapshot(base_path: &str, card_id: &Uuid) -> Result<Vec<u8>, CardMindError> {
    let paths = DataPaths::new(base_path)?;
    let path = paths.base_path.join(note_doc_path(card_id));
    let doc = load_loro_doc(&path)?;
    export_snapshot(&doc)
}

fn apply_pool_snapshot(
    base_path: &str,
    pool_id: &Uuid,
    bytes: &[u8],
) -> Result<Pool, CardMindError> {
    let doc = LoroDoc::from_snapshot(bytes)
        .map_err(|e| CardMindError::Loro(e.to_string()))?;
    let paths = DataPaths::new(base_path)?;
    let path = paths.base_path.join(pool_doc_path(pool_id));
    save_loro_doc(&path, &doc)?;
    let pool = pool_from_doc(&doc)?;
    let sqlite = SqliteStore::new(&paths.sqlite_path)?;
    sqlite.upsert_pool(&pool)?;
    Ok(pool)
}

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

fn apply_card_snapshot(
    base_path: &str,
    card_id: &Uuid,
    bytes: &[u8],
) -> Result<Card, CardMindError> {
    let doc = LoroDoc::from_snapshot(bytes)
        .map_err(|e| CardMindError::Loro(e.to_string()))?;
    let paths = DataPaths::new(base_path)?;
    let path = paths.base_path.join(note_doc_path(card_id));
    save_loro_doc(&path, &doc)?;
    let card = card_from_doc(&doc)?;
    let sqlite = SqliteStore::new(&paths.sqlite_path)?;
    sqlite.upsert_card(&card)?;
    Ok(card)
}

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

fn load_pool_if_exists(base_path: &str, pool_id: &Uuid) -> Result<Option<Pool>, CardMindError> {
    let store = PoolStore::new(base_path)?;
    match store.get_pool(pool_id) {
        Ok(pool) => Ok(Some(pool)),
        Err(CardMindError::NotFound(_)) => Ok(None),
        Err(err) => Err(err),
    }
}

fn pool_from_snapshot(bytes: &[u8]) -> Result<Pool, CardMindError> {
    let doc = LoroDoc::from_snapshot(bytes)
        .map_err(|e| CardMindError::Loro(e.to_string()))?;
    pool_from_doc(&doc)
}

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

fn parse_members(value: LoroValue) -> Result<Vec<PoolMember>, CardMindError> {
    let mut members = Vec::new();
    let list = match value {
        LoroValue::List(list) => list,
        LoroValue::Null => return Ok(members),
        _ => {
            return Err(CardMindError::InvalidArgument(
                "members invalid".to_string(),
            ))
        }
    };
    for item in list.iter() {
        let member_list = match item {
            LoroValue::List(list) => list,
            _ => {
                return Err(CardMindError::InvalidArgument(
                    "member invalid".to_string(),
                ))
            }
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

fn parse_card_ids(value: LoroValue) -> Result<Vec<Uuid>, CardMindError> {
    let mut ids = Vec::new();
    let list = match value {
        LoroValue::List(list) => list,
        LoroValue::Null => return Ok(ids),
        _ => {
            return Err(CardMindError::InvalidArgument(
                "card_ids invalid".to_string(),
            ))
        }
    };
    for item in list.iter() {
        let id = parse_uuid_value(item, "card_id")?;
        ids.push(id);
    }
    Ok(ids)
}

fn parse_uuid(map: &LoroMap, key: &str) -> Result<Uuid, CardMindError> {
    let value = map
        .get(key)
        .ok_or_else(|| CardMindError::NotFound(format!("{} missing", key)))?
        .get_deep_value();
    parse_uuid_value(&value, key)
}

fn parse_string(map: &LoroMap, key: &str) -> Result<String, CardMindError> {
    let value = map
        .get(key)
        .ok_or_else(|| CardMindError::NotFound(format!("{} missing", key)))?
        .get_deep_value();
    parse_string_value(&value, key)
}

fn parse_i64(map: &LoroMap, key: &str) -> Result<i64, CardMindError> {
    let value = map
        .get(key)
        .ok_or_else(|| CardMindError::NotFound(format!("{} missing", key)))?
        .get_deep_value();
    match value {
        LoroValue::I64(v) => Ok(v),
        _ => Err(CardMindError::InvalidArgument(format!(
            "{} invalid",
            key
        ))),
    }
}

fn parse_bool(map: &LoroMap, key: &str) -> Result<bool, CardMindError> {
    let value = map
        .get(key)
        .ok_or_else(|| CardMindError::NotFound(format!("{} missing", key)))?
        .get_deep_value();
    parse_bool_value(&value, key)
}

fn parse_uuid_value(value: &LoroValue, key: &str) -> Result<Uuid, CardMindError> {
    let text = parse_string_value(value, key)?;
    Uuid::parse_str(&text)
        .map_err(|_| CardMindError::InvalidArgument(format!("{} invalid", key)))
}

fn parse_string_value(value: &LoroValue, key: &str) -> Result<String, CardMindError> {
    match value {
        LoroValue::String(v) => Ok(v.as_ref().to_string()),
        _ => Err(CardMindError::InvalidArgument(format!("{} invalid", key))),
    }
}

fn parse_bool_value(value: &LoroValue, key: &str) -> Result<bool, CardMindError> {
    match value {
        LoroValue::Bool(v) => Ok(*v),
        _ => Err(CardMindError::InvalidArgument(format!("{} invalid", key))),
    }
}
