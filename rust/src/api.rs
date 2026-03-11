// input: 来自 FRB/上层的句柄与字符串参数，以及 store/network 操作返回的领域错误。
// output: 初始化与关闭句柄结果、后端用例 DTO、同步状态 DTO 与统一 ApiError 映射。
// pos: Rust API 门面模块，负责句柄生命周期管理、后端用例编排与跨层错误转换。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件承接对外 API、组装稳定 DTO 并做错误码映射。
use crate::models::api_error::{ApiError, ApiErrorCode};
use crate::models::card::Card;
use crate::models::error::CardMindError;
use crate::models::pool::{Pool, PoolMember};
use crate::net::endpoint::{build_endpoint, PoolEndpoint};
use crate::net::pool_network::PoolNetwork;
use crate::store::card_store::CardStore;
use crate::store::pool_store::PoolStore;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Mutex, OnceLock};
use uuid::Uuid;

static CARD_STORE_SEQ: AtomicU64 = AtomicU64::new(1);
static CARD_STORES: OnceLock<Mutex<HashMap<u64, CardStore>>> = OnceLock::new();
static POOL_NETWORK_SEQ: AtomicU64 = AtomicU64::new(1);
static POOL_NETWORKS: OnceLock<Mutex<HashMap<u64, PoolNetwork>>> = OnceLock::new();

fn card_store_map() -> &'static Mutex<HashMap<u64, CardStore>> {
    CARD_STORES.get_or_init(|| Mutex::new(HashMap::new()))
}

fn pool_network_map() -> &'static Mutex<HashMap<u64, PoolNetwork>> {
    POOL_NETWORKS.get_or_init(|| Mutex::new(HashMap::new()))
}

fn map_err(err: CardMindError) -> ApiError {
    match err {
        CardMindError::InvalidArgument(msg) => ApiError::new(ApiErrorCode::InvalidArgument, &msg),
        CardMindError::NotFound(msg) => ApiError::new(ApiErrorCode::NotFound, &msg),
        CardMindError::ProjectionNotConverged { retry_action, .. } => {
            ApiError::new(ApiErrorCode::ProjectionNotConverged, &retry_action)
        }
        CardMindError::NotImplemented(msg) => ApiError::new(ApiErrorCode::NotImplemented, &msg),
        CardMindError::NotMember(msg) => ApiError::new(ApiErrorCode::NotMember, &msg),
        CardMindError::Io(msg) => ApiError::new(ApiErrorCode::IoError, &msg),
        CardMindError::Sqlite(msg) => ApiError::new(ApiErrorCode::SqliteError, &msg),
        _ => ApiError::new(ApiErrorCode::Internal, "internal error"),
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PoolDto {
    pub id: String,
    pub name: String,
    pub is_dissolved: bool,
    pub current_user_role: String,
    pub member_count: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PoolMemberDto {
    pub endpoint_id: String,
    pub nickname: String,
    pub os: String,
    pub role: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PoolDetailDto {
    pub id: String,
    pub name: String,
    pub is_dissolved: bool,
    pub current_user_role: String,
    pub member_count: usize,
    pub note_ids: Vec<String>,
    pub members: Vec<PoolMemberDto>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CardNoteDto {
    pub id: String,
    pub title: String,
    pub content: String,
    pub created_at: i64,
    pub updated_at: i64,
    pub deleted: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncStatusDto {
    pub state: String,
    pub write_state: String,
    pub projection_state: String,
    pub sync_state: String,
    pub code: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncResultDto {
    pub state: String,
    pub write_state: String,
    pub projection_state: String,
    pub sync_state: String,
    pub code: Option<String>,
}

fn build_sync_status_dto(state: &str) -> SyncStatusDto {
    SyncStatusDto {
        state: state.to_string(),
        write_state: "write_saved".to_string(),
        projection_state: "ready".to_string(),
        sync_state: state.to_string(),
        code: None,
    }
}

fn build_sync_result_dto(sync_state: &str) -> SyncResultDto {
    SyncResultDto {
        state: "ok".to_string(),
        write_state: "write_saved".to_string(),
        projection_state: "ready".to_string(),
        sync_state: sync_state.to_string(),
        code: None,
    }
}

fn parse_uuid(raw: &str, field: &str) -> Result<Uuid, ApiError> {
    Uuid::parse_str(raw)
        .map_err(|_| ApiError::new(ApiErrorCode::InvalidArgument, &format!("invalid {field}")))
}

fn with_card_store<T>(
    store_id: u64,
    f: impl FnOnce(&CardStore) -> Result<T, ApiError>,
) -> Result<T, ApiError> {
    let map = card_store_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    let store = map
        .get(&store_id)
        .ok_or_else(|| ApiError::new(ApiErrorCode::InvalidHandle, "card store handle invalid"))?;
    f(store)
}

fn with_pool_store<T>(
    store_id: u64,
    f: impl FnOnce(&PoolStore) -> Result<T, ApiError>,
) -> Result<T, ApiError> {
    with_card_store(store_id, |card_store| {
        let base_path = card_store.base_path().to_string_lossy().to_string();
        let pool_store = PoolStore::new(&base_path).map_err(map_err)?;
        f(&pool_store)
    })
}

fn list_all_card_ids(card_store: &CardStore) -> Result<Vec<Uuid>, ApiError> {
    let cards = card_store.list_cards(10_000, 0).map_err(map_err)?;
    Ok(cards.into_iter().map(|card| card.id).collect())
}

fn parse_pool_id(pool_id: &str) -> Result<Uuid, ApiError> {
    parse_uuid(pool_id, "pool_id")
}

fn parse_card_id(card_id: &str) -> Result<Uuid, ApiError> {
    parse_uuid(card_id, "card_id")
}

fn pool_name(pool: &Pool) -> String {
    pool.members
        .first()
        .map(|member| format!("{}'s pool", member.nickname))
        .unwrap_or_else(|| "pool".to_string())
}

fn member_role(member: &PoolMember) -> String {
    if member.is_admin {
        "admin".to_string()
    } else {
        "member".to_string()
    }
}

fn current_user_role(pool: &Pool) -> String {
    pool.members
        .first()
        .map(member_role)
        .unwrap_or_else(|| "member".to_string())
}

fn to_pool_dto(pool: &Pool) -> PoolDto {
    PoolDto {
        id: pool.pool_id.to_string(),
        name: pool_name(pool),
        is_dissolved: false,
        current_user_role: current_user_role(pool),
        member_count: pool.members.len(),
    }
}

fn to_pool_detail_dto(pool: &Pool) -> PoolDetailDto {
    PoolDetailDto {
        id: pool.pool_id.to_string(),
        name: pool_name(pool),
        is_dissolved: false,
        current_user_role: current_user_role(pool),
        member_count: pool.members.len(),
        note_ids: pool.card_ids.iter().map(Uuid::to_string).collect(),
        members: pool
            .members
            .iter()
            .map(|member| PoolMemberDto {
                endpoint_id: member.endpoint_id.clone(),
                nickname: member.nickname.clone(),
                os: member.os.clone(),
                role: member_role(member),
            })
            .collect(),
    }
}

fn to_card_note_dto(card: &Card) -> CardNoteDto {
    CardNoteDto {
        id: card.id.to_string(),
        title: card.title.clone(),
        content: card.content.clone(),
        created_at: card.created_at,
        updated_at: card.updated_at,
        deleted: card.deleted,
    }
}

/// 初始化 CardStore
pub fn init_card_store(base_path: String) -> Result<u64, ApiError> {
    let store = CardStore::new(&base_path).map_err(map_err)?;
    let store_id = CARD_STORE_SEQ.fetch_add(1, Ordering::SeqCst);
    let mut map = card_store_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    map.insert(store_id, store);
    Ok(store_id)
}

/// 关闭 CardStore
pub fn close_card_store(store_id: u64) -> Result<(), ApiError> {
    let mut map = card_store_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    if map.remove(&store_id).is_none() {
        return Err(ApiError::new(
            ApiErrorCode::NotFound,
            "card store not found",
        ));
    }
    Ok(())
}

pub fn create_pool(
    store_id: u64,
    endpoint_id: String,
    nickname: String,
    os: String,
) -> Result<PoolDto, ApiError> {
    with_pool_store(store_id, |pool_store| {
        let pool = pool_store
            .create_pool(&endpoint_id, &nickname, &os)
            .map_err(map_err)?;
        Ok(to_pool_dto(&pool))
    })
}

pub fn join_pool(
    store_id: u64,
    pool_id: String,
    endpoint_id: String,
    nickname: String,
    os: String,
) -> Result<PoolDto, ApiError> {
    with_card_store(store_id, |card_store| {
        let pool_id = parse_pool_id(&pool_id)?;
        let local_card_ids = list_all_card_ids(card_store)?;
        let base_path = card_store.base_path().to_string_lossy().to_string();
        let pool_store = PoolStore::new(&base_path).map_err(map_err)?;
        let pool = pool_store.get_pool(&pool_id).map_err(map_err)?;
        let updated = pool_store
            .join_pool(
                &pool,
                PoolMember {
                    endpoint_id,
                    nickname,
                    os,
                    is_admin: false,
                },
                local_card_ids,
            )
            .map_err(map_err)?;
        Ok(to_pool_dto(&updated))
    })
}

pub fn list_pools(store_id: u64) -> Result<Vec<PoolDto>, ApiError> {
    with_pool_store(store_id, |pool_store| {
        let pools = pool_store
            .get_any_pool()
            .map(|pool| vec![pool])
            .or_else(|err| match err {
                CardMindError::NotFound(_) => Ok(Vec::new()),
                other => Err(other),
            })
            .map_err(map_err)?;
        Ok(pools.iter().map(to_pool_dto).collect())
    })
}

pub fn get_pool_detail(store_id: u64, pool_id: String) -> Result<PoolDetailDto, ApiError> {
    with_pool_store(store_id, |pool_store| {
        let pool_id = parse_pool_id(&pool_id)?;
        let pool = pool_store.get_pool(&pool_id).map_err(map_err)?;
        Ok(to_pool_detail_dto(&pool))
    })
}

pub fn create_card_note(
    store_id: u64,
    title: String,
    content: String,
) -> Result<CardNoteDto, ApiError> {
    with_card_store(store_id, |card_store| {
        let card = card_store.create_card(&title, &content).map_err(map_err)?;
        Ok(to_card_note_dto(&card))
    })
}

pub fn create_card_note_in_pool(
    store_id: u64,
    pool_id: String,
    title: String,
    content: String,
) -> Result<CardNoteDto, ApiError> {
    with_card_store(store_id, |card_store| {
        let pool_id = parse_pool_id(&pool_id)?;
        let card = card_store.create_card(&title, &content).map_err(map_err)?;
        let base_path = card_store.base_path().to_string_lossy().to_string();
        let pool_store = PoolStore::new(&base_path).map_err(map_err)?;
        pool_store
            .attach_note_references(&pool_id, vec![card.id])
            .map_err(map_err)?;
        Ok(to_card_note_dto(&card))
    })
}

pub fn update_card_note(
    store_id: u64,
    card_id: String,
    title: String,
    content: String,
) -> Result<CardNoteDto, ApiError> {
    with_card_store(store_id, |card_store| {
        let card_id = parse_card_id(&card_id)?;
        let card = card_store
            .update_card(&card_id, &title, &content)
            .map_err(map_err)?;
        Ok(to_card_note_dto(&card))
    })
}

pub fn list_card_notes(store_id: u64) -> Result<Vec<CardNoteDto>, ApiError> {
    with_card_store(store_id, |card_store| {
        let cards = card_store.list_cards(10_000, 0).map_err(map_err)?;
        Ok(cards.iter().map(to_card_note_dto).collect())
    })
}

pub fn get_card_note_detail(store_id: u64, card_id: String) -> Result<CardNoteDto, ApiError> {
    with_card_store(store_id, |card_store| {
        let card_id = parse_card_id(&card_id)?;
        let card = card_store.get_card(&card_id).map_err(map_err)?;
        Ok(to_card_note_dto(&card))
    })
}

/// 初始化 PoolNetwork
pub fn init_pool_network(base_path: String) -> Result<u64, ApiError> {
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .map_err(|e| ApiError::new(ApiErrorCode::Internal, &e.to_string()))?;
    let endpoint = runtime.block_on(build_endpoint()).map_err(map_err)?;
    let pool_store = PoolStore::new(&base_path).map_err(map_err)?;
    let card_store = CardStore::new(&base_path).map_err(map_err)?;
    let network = PoolNetwork::new(PoolEndpoint::new(endpoint), pool_store, card_store);
    let network_id = POOL_NETWORK_SEQ.fetch_add(1, Ordering::SeqCst);
    let mut map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    map.insert(network_id, network);
    Ok(network_id)
}

/// 关闭 PoolNetwork
pub fn close_pool_network(network_id: u64) -> Result<(), ApiError> {
    let mut map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    if map.remove(&network_id).is_none() {
        return Err(ApiError::new(
            ApiErrorCode::NotFound,
            "pool network not found",
        ));
    }
    Ok(())
}

pub fn sync_status(network_id: u64) -> Result<SyncStatusDto, ApiError> {
    let map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    let network = map
        .get(&network_id)
        .ok_or_else(|| ApiError::new(ApiErrorCode::InvalidHandle, "pool network handle invalid"))?;
    Ok(build_sync_status_dto(network.sync_state()))
}

pub fn sync_connect(network_id: u64, target: String) -> Result<(), ApiError> {
    let mut map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    let network = map
        .get_mut(&network_id)
        .ok_or_else(|| ApiError::new(ApiErrorCode::InvalidHandle, "pool network handle invalid"))?;
    network.sync_connect(target).map_err(map_err)
}

pub fn sync_disconnect(network_id: u64) -> Result<(), ApiError> {
    let mut map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    let network = map
        .get_mut(&network_id)
        .ok_or_else(|| ApiError::new(ApiErrorCode::InvalidHandle, "pool network handle invalid"))?;
    network.sync_disconnect();
    Ok(())
}

pub fn sync_join_pool(network_id: u64, pool_id: String) -> Result<(), ApiError> {
    let map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    let network = map
        .get(&network_id)
        .ok_or_else(|| ApiError::new(ApiErrorCode::InvalidHandle, "pool network handle invalid"))?;
    network.sync_join_pool(&pool_id).map_err(map_err)
}

pub fn sync_push(network_id: u64) -> Result<SyncResultDto, ApiError> {
    let map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    let network = map
        .get(&network_id)
        .ok_or_else(|| ApiError::new(ApiErrorCode::InvalidHandle, "pool network handle invalid"))?;
    network.sync_push().map_err(|err| match err {
        CardMindError::InvalidArgument(msg) if msg == "sync not connected" => {
            ApiError::new(ApiErrorCode::RequestTimeout, "sync not connected")
        }
        other => map_err(other),
    })?;
    Ok(build_sync_result_dto("connected"))
}

pub fn sync_pull(network_id: u64) -> Result<SyncResultDto, ApiError> {
    let map = pool_network_map()
        .lock()
        .map_err(|_| ApiError::new(ApiErrorCode::Internal, "store lock poisoned"))?;
    let network = map
        .get(&network_id)
        .ok_or_else(|| ApiError::new(ApiErrorCode::InvalidHandle, "pool network handle invalid"))?;
    network.sync_pull().map_err(|err| match err {
        CardMindError::InvalidArgument(msg) if msg == "sync not connected" => {
            ApiError::new(ApiErrorCode::RequestTimeout, "sync not connected")
        }
        other => map_err(other),
    })?;
    Ok(build_sync_result_dto("connected"))
}
